"""Production runtime for the VitalLink hardware companion.

This script consolidates the prototype capabilities that were previously split
across:

- companion.py: BLE provisioning + sensor streaming
- server.py: heartbeat batching + accelerometer event detection
- heartbeat.py: BPM estimation for the app-facing user record
- motion_detection.py: fall/tremor classification

Expected setup:
- Raspberry Pi-compatible I2C hardware
- ADS1115 heart-rate sensor connected on ADS.P3
- LSM6DSOX accelerometer/gyro
- Firebase Admin credentials available locally
- Optional NetworkManager (`nmcli`) if you want BLE provisioning to apply Wi-Fi

Example:
    python production.py \
        --database-url https://your-project-default-rtdb.firebaseio.com/ \
        --service-account /home/pi/service_account.json
"""

import argparse
import json
import math
import os
import socket
import subprocess
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import adafruit_ads1x15.ads1115 as ADS
import board
import busio
import firebase_admin
from adafruit_ads1x15.analog_in import AnalogIn
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX
from bluezero import adapter, peripheral
from firebase_admin import credentials, db

from motion_detection import MotionDetector


def _server_timestamp():
    return {".sv": "timestamp"}


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _timestamp_ms() -> int:
    return int(time.time() * 1000)


def _sanitize_device_id(value: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in "-_." else "-" for ch in value)
    return safe.strip("-") or "vitallink-device"


class ProvisioningConfig(object):
    def __init__(self, ssid="", password="", uid="", updated_at=""):
        self.ssid = ssid
        self.password = password
        self.uid = uid
        self.updated_at = updated_at

    @classmethod
    def from_dict(cls, payload):
        return cls(
            ssid=str(payload.get("ssid", "")).strip(),
            password=str(payload.get("password", "")).strip(),
            uid=str(payload.get("uid", "")).strip(),
            updated_at=str(payload.get("updated_at", "")).strip(),
        )

    def to_dict(self):
        return {
            "ssid": self.ssid,
            "password": self.password,
            "uid": self.uid,
            "updated_at": self.updated_at,
        }


class ProductionRuntime:
    NUS_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    NUS_RX_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    NUS_TX_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    def __init__(
        self,
        *,
        database_url: str,
        service_account: str,
        config_path: str,
        device_id: str,
        device_name: str,
        sensor_root: str,
        axis_map: Dict[str, str],
        skip_wifi_apply: bool,
    ) -> None:
        self.database_url = database_url
        self.service_account = str(Path(service_account).expanduser())
        self.config_path = Path(config_path).expanduser()
        self.device_id = _sanitize_device_id(device_id)
        self.device_name = device_name
        self.axis_map = axis_map
        self.skip_wifi_apply = skip_wifi_apply
        self.session_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

        self.stop_event = threading.Event()
        self.sensor_lock = threading.Lock()
        self.config_lock = threading.Lock()

        self._rx_buffer = bytearray()
        self._tx_obj = None
        self._ble_peripheral = None

        self.firebase_app = self._init_firebase()

        formatted_root = sensor_root.format(device_id=self.device_id)
        self.root_ref = db.reference(formatted_root)
        self.runtime_ref = self.root_ref.child("runtime")
        self.provisioning_ref = self.root_ref.child("provisioning")
        self.heartbeat_session_ref = self.root_ref.child("heartbeat").child(
            self.session_id
        )
        self.heartbeat_live_ref = self.root_ref.child("heartbeat").child("live")
        self.accel_ref = self.root_ref.child("accel")
        self.accel_events_ref = self.accel_ref.child("events").child(self.session_id)
        self.accel_counts_ref = self.accel_ref.child("event_counts").child(
            self.session_id
        )

        self.provisioning = self._load_config()

        self.i2c = busio.I2C(board.SCL, board.SDA)
        self.sox = LSM6DSOX(self.i2c)
        self.ads = ADS.ADS1115(self.i2c)
        self.ads.gain = 1
        self.ads.data_rate = 250
        self.heartrate_sensor = AnalogIn(self.ads, ADS.P3)

    def _log(self, message: str) -> None:
        print(f"[{_utc_now_iso()}] {message}", flush=True)

    def _init_firebase(self):
        cred_path = Path(self.service_account)
        if not cred_path.exists():
            raise FileNotFoundError(
                f"Firebase service account file not found: {cred_path}"
            )
        if not self.database_url:
            raise ValueError("A Firebase Realtime Database URL is required.")

        try:
            return firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(str(cred_path))
            return firebase_admin.initialize_app(
                cred,
                {"databaseURL": self.database_url},
            )

    def _load_config(self) -> ProvisioningConfig:
        if not self.config_path.exists():
            return ProvisioningConfig()

        try:
            payload = json.loads(self.config_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            self._log(f"Failed to load saved provisioning config: {error}")
            return ProvisioningConfig()

        if not isinstance(payload, dict):
            return ProvisioningConfig()
        return ProvisioningConfig.from_dict(payload)

    def _save_config(self, config: ProvisioningConfig) -> None:
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        self.config_path.write_text(
            json.dumps(config.to_dict(), indent=2, sort_keys=True),
            encoding="utf-8",
        )
        try:
            os.chmod(self.config_path, 0o600)
        except OSError:
            pass

    def _current_uid(self) -> str:
        with self.config_lock:
            return self.provisioning.uid

    def _notify_client(self, message: str) -> None:
        if not self._tx_obj:
            return
        try:
            self._tx_obj.set_value(list(message.encode("utf-8")))
        except Exception as error:  # pragma: no cover - hardware callback path
            self._log(f"BLE notify failed: {error}")

    def _safe_set(self, ref, payload, label: str) -> bool:
        try:
            ref.set(payload)
            return True
        except Exception as error:
            self._log(f"{label} set failed: {error}")
            return False

    def _safe_push(self, ref, payload, label: str) -> bool:
        try:
            ref.push(payload)
            return True
        except Exception as error:
            self._log(f"{label} push failed: {error}")
            return False

    def _update_runtime_status(self, status: str, **extra: Any) -> None:
        payload = {
            "status": status,
            "device_id": self.device_id,
            "device_name": self.device_name,
            "session_id": self.session_id,
            "uid": self._current_uid(),
            "updated_at": _utc_now_iso(),
            "ts_client_ms": _timestamp_ms(),
            "ts_server": _server_timestamp(),
        }
        payload.update(extra)
        self._safe_set(self.runtime_ref, payload, "runtime status")

    def _update_provisioning_status(
        self,
        status: str,
        *,
        ssid: Optional[str] = None,
        uid: Optional[str] = None,
        wifi_applied: Optional[bool] = None,
        detail: Optional[str] = None,
    ) -> None:
        payload = {
            "status": status,
            "device_id": self.device_id,
            "updated_at": _utc_now_iso(),
            "ts_client_ms": _timestamp_ms(),
            "ts_server": _server_timestamp(),
        }
        if ssid is not None:
            payload["ssid"] = ssid
        if uid is not None:
            payload["uid"] = uid
        if wifi_applied is not None:
            payload["wifi_applied"] = wifi_applied
        if detail:
            payload["detail"] = detail
        self._safe_set(self.provisioning_ref, payload, "provisioning status")

    def _set_user_bpm(self, bpm: int) -> None:
        uid = self._current_uid()
        if not uid:
            return
        self._safe_set(db.reference(f"users/{uid}/BPM"), bpm, "user BPM")

    def _set_user_motion(self, event_kind: str) -> None:
        uid = self._current_uid()
        if not uid:
            return
        self._safe_set(
            db.reference(f"users/{uid}/ADM"),
            event_kind,
            "user motion event",
        )

    def _apply_wifi_credentials(self, ssid: str, password: str) -> Tuple[bool, str]:
        if self.skip_wifi_apply:
            return False, "Wi-Fi apply skipped by configuration."

        nmcli = shutil_which("nmcli")
        if not nmcli:
            return False, "Saved configuration locally; nmcli not available."

        command = [nmcli, "device", "wifi", "connect", ssid]
        if password:
            command.extend(["password", password])

        try:
            subprocess.run(
                command,
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            )
            return True, f"Connected to Wi-Fi network '{ssid}'."
        except subprocess.CalledProcessError as error:
            detail = (error.stderr or error.stdout or str(error)).strip()
            return False, f"Saved config, but failed to connect Wi-Fi: {detail}"
        except Exception as error:  # pragma: no cover - hardware/system dependent
            return False, f"Saved config, but Wi-Fi apply failed: {error}"

    def _handle_config(self, payload) -> None:
        ssid = str(payload.get("ssid", "")).strip()
        password = str(payload.get("password", "")).strip()
        uid = str(payload.get("uid", "")).strip()

        if not ssid or not uid:
            self._notify_client("ERR: missing ssid/uid\n")
            self._update_provisioning_status(
                "invalid",
                ssid=ssid or None,
                uid=uid or None,
                detail="Provisioning payload missing ssid or uid.",
            )
            return

        config = ProvisioningConfig(
            ssid=ssid,
            password=password,
            uid=uid,
            updated_at=_utc_now_iso(),
        )

        try:
            with self.config_lock:
                self.provisioning = config
                self._save_config(config)
        except OSError as error:
            detail = f"Failed to save config locally: {error}"
            self._log(detail)
            self._update_provisioning_status(
                "error",
                ssid=ssid,
                uid=uid,
                detail=detail,
            )
            self._notify_client("ERR: unable to save config\n")
            return

        wifi_applied, detail = self._apply_wifi_credentials(ssid, password)
        self._update_provisioning_status(
            "ready",
            ssid=ssid,
            uid=uid,
            wifi_applied=wifi_applied,
            detail=detail,
        )
        self._update_runtime_status("online", last_provisioned_at=config.updated_at)

        self._log(f"Received provisioning config for uid={uid} on SSID={ssid}")
        self._notify_client(f"OK: {detail}\n")

    def _try_parse_json_from_buffer(self) -> None:
        if len(self._rx_buffer) > 8192:
            self._rx_buffer = bytearray()
            self._notify_client("ERR: buffer overflow\n")
            return

        try:
            decoded = self._rx_buffer.decode("utf-8")
            payload = json.loads(decoded)
        except UnicodeError:
            return
        except json.JSONDecodeError:
            return

        self._rx_buffer = bytearray()
        if not isinstance(payload, dict):
            self._notify_client("ERR: invalid JSON format\n")
            return

        self._handle_config(payload)

    def _uart_notify_cb(self, notifying, characteristic) -> None:
        self._tx_obj = characteristic if notifying else None
        self._log(f"BLE notifications {'enabled' if notifying else 'disabled'}")

    def _uart_write_cb(self, value, options) -> None:
        del options
        self._rx_buffer.extend(bytes(value))
        self._try_parse_json_from_buffer()

    def ble_worker(self) -> None:
        ble = None
        try:
            adapters = list(adapter.Adapter.available())
            if not adapters:
                raise RuntimeError("No Bluetooth adapters available.")

            ble = peripheral.Peripheral(
                adapter_address=adapters[0].address,
                local_name=self.device_name,
                appearance=0x0000,
            )
            self._ble_peripheral = ble

            ble.add_service(srv_id=1, uuid=self.NUS_SERVICE_UUID, primary=True)
            ble.add_characteristic(
                srv_id=1,
                chr_id=1,
                uuid=self.NUS_RX_UUID,
                value=[],
                notifying=False,
                flags=["write", "write-without-response"],
                write_callback=self._uart_write_cb,
                read_callback=None,
                notify_callback=None,
            )
            ble.add_characteristic(
                srv_id=1,
                chr_id=2,
                uuid=self.NUS_TX_UUID,
                value=[],
                notifying=False,
                flags=["notify"],
                write_callback=None,
                read_callback=None,
                notify_callback=self._uart_notify_cb,
            )

            self._log(f"Advertising BLE name: {self.device_name}")
            ble.publish()
            while not self.stop_event.wait(0.5):
                pass
        except Exception as error:  # pragma: no cover - hardware dependent
            self._log(f"BLE worker stopped: {error}")
            self._update_runtime_status("degraded", ble_error=str(error))
        finally:
            if ble is not None:
                try:
                    ble.stop()
                except Exception:
                    pass

    def heartbeat_worker(
        self,
        *,
        target_sps: int = 250,
        batch_window_secs: float = 5.0,
        bpm_window_secs: float = 15.0,
        refractory_secs: float = 0.3,
        alpha_baseline: float = 0.01,
        alpha_noise: float = 0.01,
        threshold_multiplier: float = 1.5,
    ) -> None:
        dt = 1.0 / float(target_sps)
        batch_started = time.monotonic()
        bpm_window_started = time.monotonic()
        warmup_end = time.monotonic() + 5.0
        next_tick = time.monotonic()

        baseline = None
        noise = 0.0
        beats_in_window = 0
        last_cross_up = False
        last_beat_time = -1e9
        samples = []  # type: List[Dict[str, Any]]
        current_bpm = 0

        while not self.stop_event.is_set():
            with self.sensor_lock:
                raw_value = int(self.heartrate_sensor.value)
                voltage = float(self.heartrate_sensor.voltage)

            if baseline is None:
                baseline = raw_value

            now_mono = time.monotonic()
            now_ms = _timestamp_ms()

            baseline = (1 - alpha_baseline) * baseline + alpha_baseline * raw_value
            deviation = abs(raw_value - baseline)
            noise = (1 - alpha_noise) * noise + alpha_noise * deviation

            threshold = baseline + threshold_multiplier * max(noise, 1.0)
            is_above = raw_value > threshold
            rising_cross = (not last_cross_up) and is_above
            if (
                rising_cross
                and (now_mono - last_beat_time) >= refractory_secs
                and now_mono >= warmup_end
            ):
                beats_in_window += 1
                last_beat_time = now_mono
            last_cross_up = is_above

            samples.append({"t": now_ms, "raw": raw_value, "v": voltage})

            if (now_mono - bpm_window_started) >= bpm_window_secs:
                current_bpm = int(round((beats_in_window / bpm_window_secs) * 60))
                self._set_user_bpm(current_bpm)
                self._safe_set(
                    self.heartbeat_live_ref,
                    {
                        "bpm": current_bpm,
                        "raw": raw_value,
                        "voltage": voltage,
                        "ts_client_ms": now_ms,
                        "ts_server": _server_timestamp(),
                    },
                    "heartbeat live",
                )
                self._log(f"Heart rate: {current_bpm} BPM")
                beats_in_window = 0
                bpm_window_started = now_mono

            if (now_mono - batch_started) >= batch_window_secs and samples:
                payload = {
                    "meta": {
                        "session": self.session_id,
                        "device_id": self.device_id,
                        "uid": self._current_uid(),
                        "fs_target": target_sps,
                        "ads_data_rate": getattr(self.ads, "data_rate", None),
                        "ads_gain": getattr(self.ads, "gain", None),
                        "n": len(samples),
                        "bpm": current_bpm,
                    },
                    "samples": samples,
                    "ts_client_ms": now_ms,
                    "ts_server": _server_timestamp(),
                }
                self._safe_push(self.heartbeat_session_ref, payload, "heartbeat batch")

                samples = []
                batch_started = now_mono

            next_tick += dt
            sleep_for = next_tick - time.monotonic()
            if sleep_for > 0:
                self.stop_event.wait(sleep_for)
            else:
                next_tick = time.monotonic()

    def accel_worker(
        self,
        *,
        poll_ms: int = 20,
        history_every_ms: int = 2000,
        counts_every_ms: int = 1500,
    ) -> None:
        detector = MotionDetector(session_id=self.session_id, axis_map=self.axis_map)
        last_history_ms = 0
        last_counts_upload_ms = 0
        fs_hz = 1000.0 / float(poll_ms)

        while not self.stop_event.is_set():
            try:
                with self.sensor_lock:
                    ax, ay, az = self.sox.acceleration
                    gx, gy, gz = self.sox.gyro

                now_ms = _timestamp_ms()
                mag = math.sqrt(ax * ax + ay * ay + az * az)
                live_payload = {
                    "x": ax,
                    "y": ay,
                    "z": az,
                    "gx": gx,
                    "gy": gy,
                    "gz": gz,
                    "mag": mag,
                    "ts_client_ms": now_ms,
                    "ts_server": _server_timestamp(),
                }

                self._safe_set(self.accel_ref.child("live"), live_payload, "accel live")

                if (now_ms - last_history_ms) >= history_every_ms:
                    self._safe_push(
                        self.accel_ref.child("history"),
                        live_payload,
                        "accel history",
                    )
                    last_history_ms = now_ms

                event = detector.update(now_ms, ax, ay, az, fs_hz)
                if event:
                    event_payload = {
                        "kind": event["kind"],
                        "detail": event.get("detail", {}),
                        "score": event.get("score"),
                        "counts": detector.counts.get(event["kind"]),
                        "ts_client_ms": now_ms,
                        "ts_server": _server_timestamp(),
                    }
                    self._safe_push(
                        self.accel_events_ref,
                        event_payload,
                        "accel event",
                    )
                    self._safe_set(
                        self.accel_ref.child("last_event"),
                        event_payload,
                        "accel last event",
                    )
                    self._set_user_motion(event["kind"])
                    self._log(f"Motion event: {event['kind']}")

                if (now_ms - last_counts_upload_ms) >= counts_every_ms:
                    self._safe_set(
                        self.accel_counts_ref,
                        {
                            **detector.counts_payload(),
                            "ts_client_ms": now_ms,
                            "ts_server": _server_timestamp(),
                        },
                        "accel counts",
                    )
                    last_counts_upload_ms = now_ms
            except Exception as error:
                self._log(f"Accel update error: {error}")

            self.stop_event.wait(poll_ms / 1000.0)

    def start(self) -> None:
        self._log("Starting production runtime.")
        self._update_runtime_status("online", started_at=_utc_now_iso())
        self._update_provisioning_status(
            "ready" if self.provisioning.uid else "awaiting_provisioning",
            ssid=self.provisioning.ssid or None,
            uid=self.provisioning.uid or None,
            wifi_applied=None,
            detail="Loaded saved config." if self.provisioning.uid else None,
        )

        workers = [
            threading.Thread(target=self.heartbeat_worker, daemon=True),
            threading.Thread(target=self.accel_worker, daemon=True),
            threading.Thread(target=self.ble_worker, daemon=True),
        ]

        for worker in workers:
            worker.start()

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self._log("Stopping runtime.")
            self.stop_event.set()
            for worker in workers:
                worker.join(timeout=5)
            self._update_runtime_status("offline", stopped_at=_utc_now_iso())
            self._log("Stopped.")


def shutil_which(command: str) -> Optional[str]:
    for base in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(base) / command
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def parse_axis_map(value: str) -> Dict[str, str]:
    mapping = {"forward": "y", "lateral": "x", "vertical": "z"}
    if not value:
        return mapping

    for pair in value.split(","):
        if "=" not in pair:
            raise ValueError(
                "Axis map must look like 'forward=y,lateral=x,vertical=z'."
            )
        key, axis = pair.split("=", 1)
        key = key.strip()
        axis = axis.strip().lower()
        if key not in mapping:
            raise ValueError(f"Unsupported axis role: {key}")
        if axis not in {"x", "y", "z"}:
            raise ValueError(f"Unsupported axis value for {key}: {axis}")
        mapping[key] = axis
    return mapping


def build_arg_parser() -> argparse.ArgumentParser:
    hardware_dir = Path(__file__).resolve().parent
    default_service_account = os.getenv("VITALLINK_FIREBASE_CREDENTIALS", "")
    if not default_service_account:
        default_service_account = str(hardware_dir / "service_account.json")

    parser = argparse.ArgumentParser(
        description="Run the production VitalLink hardware runtime."
    )
    parser.add_argument(
        "--database-url",
        default=os.getenv("VITALLINK_DATABASE_URL", ""),
        help="Firebase Realtime Database URL.",
    )
    parser.add_argument(
        "--service-account",
        default=default_service_account,
        help="Path to the Firebase Admin service account JSON file.",
    )
    parser.add_argument(
        "--config-path",
        default=os.getenv(
            "VITALLINK_CONFIG_PATH",
            str(hardware_dir / "device_config.json"),
        ),
        help="Path used to persist BLE provisioning data.",
    )
    parser.add_argument(
        "--device-id",
        default=os.getenv("VITALLINK_DEVICE_ID", socket.gethostname()),
        help="Stable device identifier used in Firebase paths.",
    )
    parser.add_argument(
        "--device-name",
        default=os.getenv("VITALLINK_DEVICE_NAME", "VitalLink Helper"),
        help="BLE advertised device name.",
    )
    parser.add_argument(
        "--sensor-root",
        default=os.getenv(
            "VITALLINK_SENSOR_ROOT",
            "devices/{device_id}/telemetry",
        ),
        help="Firebase root path for device telemetry. Supports {device_id}.",
    )
    parser.add_argument(
        "--axis-map",
        default=os.getenv("VITALLINK_AXIS_MAP", "forward=y,lateral=x,vertical=z"),
        help="Axis roles for motion detection, e.g. forward=y,lateral=x,vertical=z",
    )
    parser.add_argument(
        "--skip-wifi-apply",
        action="store_true",
        default=os.getenv("VITALLINK_SKIP_WIFI_APPLY", "").lower() in {"1", "true"},
        help="Only persist BLE provisioning config; do not attempt to join Wi-Fi.",
    )
    return parser


def main() -> None:
    parser = build_arg_parser()
    args = parser.parse_args()

    runtime = ProductionRuntime(
        database_url=args.database_url,
        service_account=args.service_account,
        config_path=args.config_path,
        device_id=args.device_id,
        device_name=args.device_name,
        sensor_root=args.sensor_root,
        axis_map=parse_axis_map(args.axis_map),
        skip_wifi_apply=args.skip_wifi_apply,
    )
    runtime.start()


if __name__ == "__main__":
    main()
