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
- Optional NetworkManager (`nmcli`) to join Wi-Fi from BLE provisioning and to
  host the device's own hotspot when no known network is in range

Example:
    python production.py \
        --database-url https://your-project-default-rtdb.firebaseio.com/ \
        --service-account /home/pi/service_account.json
"""

import argparse
import json
import math
import os
import queue
import socket
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import firebase_admin
from firebase_admin import credentials, db

try:
    import adafruit_ads1x15.ads1115 as ADS
    import board
    import busio
    from adafruit_ads1x15.analog_in import AnalogIn
    from adafruit_lsm6ds.lsm6dsox import LSM6DSOX

    HARDWARE_IMPORT_ERROR = None
except Exception as error:  # pragma: no cover - platform dependent
    ADS = None
    board = None
    busio = None
    AnalogIn = None
    LSM6DSOX = None
    HARDWARE_IMPORT_ERROR = error

try:
    from bluezero import adapter, peripheral

    BLE_IMPORT_ERROR = None
except Exception as error:  # pragma: no cover - platform dependent
    adapter = None
    peripheral = None
    BLE_IMPORT_ERROR = error

from motion_detection import MotionDetector
from wifi_network import WifiNetwork, load_hotspot_credentials

# ADS1115 full-scale voltage for each gain setting (matches adafruit_ads1x15).
ADS_FULL_SCALE_V = {2 / 3: 6.144, 1: 4.096, 2: 2.048, 4: 1.024, 8: 0.512, 16: 0.256}

# Two-letter codes keep BLE notifications within the default 20-byte payload.
MOTION_EVENT_CODES = {
    "tremor_up_down": "TU",
    "tremor_left_right": "TL",
    "real_tumbling": "TB",
    "real_tripping": "TR",
    "real_slipping": "SL",
    "fake_jumping": "FJ",
    "fake_trip_recover": "FT",
    "fake_slip_recover": "FS",
}
NETWORK_MODE_CODES = {"hotspot": "A", "client": "C"}


def _server_timestamp():
    return {".sv": "timestamp"}


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _timestamp_ms() -> int:
    return time.time_ns() // 1_000_000


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
        debug_telemetry: bool,
        network_mode: str,
        wifi_interface: str,
        hotspot_config_path: str,
        hotspot_ssid: str,
        hotspot_password: str,
        client_grace_secs: float,
    ) -> None:
        self.database_url = database_url
        self.service_account = str(Path(service_account).expanduser())
        self.config_path = Path(config_path).expanduser()
        self.device_id = _sanitize_device_id(device_id)
        self.device_name = device_name
        self.axis_map = axis_map
        self.skip_wifi_apply = skip_wifi_apply
        self.debug_telemetry = debug_telemetry
        self.network_mode = network_mode
        self.client_grace_secs = client_grace_secs
        self.session_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

        self.stop_event = threading.Event()
        self.sensor_lock = threading.Lock()
        self.config_lock = threading.Lock()
        self.ble_notify_lock = threading.Lock()
        self.network_lock = threading.Lock()
        self.wifi_join_lock = threading.Lock()

        self._rx_buffer = bytearray()
        self._tx_obj = None
        self._ble_peripheral = None
        self._last_fall_kind = None
        self._last_fall_at_ms = None

        # Firebase writes go through a queue so a slow or missing internet
        # connection never stalls sensor sampling.
        self._upload_queue = queue.Queue(maxsize=256)  # type: queue.Queue
        self._net_mode = "unknown"
        self._net_address = ""
        self.wifi = self._init_wifi(
            wifi_interface,
            Path(hotspot_config_path).expanduser(),
            hotspot_ssid,
            hotspot_password,
        )

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

        self.i2c = None
        self.sox = None
        self.ads = None
        self.heartrate_sensor = None
        self.ads_full_scale_v = ADS_FULL_SCALE_V[1]
        self.sensor_error = self._init_sensors()

    def _log(self, message: str) -> None:
        print(f"[{_utc_now_iso()}] {message}", flush=True)

    def _init_wifi(
        self,
        interface: str,
        hotspot_config_path: Path,
        hotspot_ssid: str,
        hotspot_password: str,
    ) -> Optional[WifiNetwork]:
        if self.skip_wifi_apply:
            return None
        nmcli = shutil_which("nmcli")
        if not nmcli:
            self._log("nmcli not available; Wi-Fi and hotspot management disabled.")
            return None

        ssid, password = load_hotspot_credentials(
            hotspot_config_path, interface, hotspot_ssid, hotspot_password
        )
        self._log(
            f"Hotspot credentials: SSID '{ssid}' "
            f"(password stored in {hotspot_config_path})"
        )
        return WifiNetwork(nmcli, interface, ssid, password)

    def _init_firebase(self):
        cred_path = Path(self.service_account)
        if not cred_path.exists():
            raise FileNotFoundError(
                f"Firebase service account file not found: {cred_path}"
            )
        if not self.database_url:
            inferred_url = self._infer_database_url(cred_path)
            if inferred_url:
                self.database_url = inferred_url
            else:
                raise ValueError("A Firebase Realtime Database URL is required.")

        try:
            return firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(str(cred_path))
            return firebase_admin.initialize_app(
                cred,
                {"databaseURL": self.database_url},
            )

    def _infer_database_url(self, cred_path: Path) -> str:
        try:
            payload = json.loads(cred_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return ""

        project_id = str(payload.get("project_id", "")).strip()
        if not project_id:
            return ""
        return f"https://{project_id}-default-rtdb.firebaseio.com/"

    def _init_sensors(self) -> Optional[str]:
        if HARDWARE_IMPORT_ERROR is not None:
            return f"hardware imports unavailable: {HARDWARE_IMPORT_ERROR}"

        try:
            self.i2c = busio.I2C(board.SCL, board.SDA)
            self.sox = LSM6DSOX(self.i2c)
            self.ads = ADS.ADS1115(self.i2c)
            self.ads.gain = 1
            self.ads.data_rate = 250
            self.ads_full_scale_v = ADS_FULL_SCALE_V[self.ads.gain]
            self.heartrate_sensor = AnalogIn(self.ads, ADS.P3)
            return None
        except Exception as error:  # pragma: no cover - hardware dependent
            self.i2c = None
            self.sox = None
            self.ads = None
            self.heartrate_sensor = None
            return str(error)

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
            with self.ble_notify_lock:
                self._tx_obj.set_value(list(message.encode("utf-8")))
        except Exception as error:  # pragma: no cover - hardware callback path
            self._log(f"BLE notify failed: {error}")

    def _notify_fall_status(self, event_kind=None, timestamp_ms=None) -> None:
        """Send one MTU-sized fall update over the BLE UART channel."""
        code_by_kind = {
            "real_tumbling": "TB",
            "real_tripping": "TR",
            "real_slipping": "SL",
        }
        code = code_by_kind.get(event_kind, "OK")
        recorded_at_ms = timestamp_ms or _timestamp_ms()
        self._notify_client(f"FALL:{code}:{recorded_at_ms:x}\n")

    def _notify_network_status(self) -> None:
        """Tell the app how to reach Ollama: NET:<A|C|N>:<IPv4 as 8 hex digits>."""
        with self.network_lock:
            mode, address = self._net_mode, self._net_address
        if self.wifi is None:
            return
        try:
            packed = socket.inet_aton(address).hex() if address else "00000000"
        except OSError:
            packed = "00000000"
        self._notify_client(f"NET:{NETWORK_MODE_CODES.get(mode, 'N')}:{packed}\n")

    def _log_motion_event(self, event_payload: Dict[str, Any]) -> None:
        kind = event_payload["kind"]
        count = event_payload.get("counts")
        score = event_payload.get("score")
        detail = event_payload.get("detail") or {}

        parts = [f"Motion event: {kind}"]
        if count is not None:
            parts.append(f"count={count}")
        if score is not None:
            try:
                parts.append(f"score={float(score):.3f}")
            except (TypeError, ValueError):
                parts.append(f"score={score}")
        if detail:
            parts.append(f"detail={json.dumps(detail, sort_keys=True)}")
        self._log(" | ".join(parts))

    def _cloud_reachable(self) -> bool:
        if self.wifi is None:
            # Wi-Fi isn't managed here, so assume the OS has internet.
            return True
        with self.network_lock:
            return self._net_mode == "client"

    def _queue_upload(self, op: str, ref, payload, label: str) -> None:
        # The hotspot has no internet. The phone relays BPM and motion events
        # (received over BLE) to Firebase instead, so drop device-side writes.
        if not self._cloud_reachable():
            return
        try:
            self._upload_queue.put_nowait((op, ref, payload, label))
        except queue.Full:
            self._log(f"Upload queue full; dropped {label}")

    def _safe_set(self, ref, payload, label: str) -> None:
        self._queue_upload("set", ref, payload, label)

    def _safe_push(self, ref, payload, label: str) -> None:
        self._queue_upload("push", ref, payload, label)

    def upload_worker(self) -> None:
        while True:
            item = self._upload_queue.get()
            if item is None:
                return
            op, ref, payload, label = item
            try:
                if op == "set":
                    ref.set(payload)
                else:
                    ref.push(payload)
            except Exception as error:
                self._log(f"{label} {op} failed: {error}")

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

    def _refresh_network_status(self) -> str:
        if self.wifi is None:
            return "unmanaged"

        mode, _, address = self.wifi.status()
        with self.network_lock:
            changed = (mode, address) != (self._net_mode, self._net_address)
            self._net_mode, self._net_address = mode, address

        if changed:
            self._log(f"Network is now {mode}{f' at {address}' if address else ''}.")
            self._notify_network_status()
            if mode == "client":
                self._update_runtime_status("online", network="client", ip=address)
        return mode

    def _start_hotspot(self) -> None:
        ok, detail = self.wifi.start_hotspot()
        self._log(detail)
        self._refresh_network_status()

    def network_worker(self, poll_secs: float = 5.0) -> None:
        """Fall back to hosting a hotspot when no known Wi-Fi is in range."""
        if self.network_mode == "hotspot" and self._refresh_network_status() != "hotspot":
            self._start_hotspot()

        grace_secs = 0.0 if self.network_mode == "hotspot" else self.client_grace_secs
        last_connected = time.monotonic()
        while not self.stop_event.wait(poll_secs):
            if self.wifi_join_lock.locked():
                # A BLE-provisioned join is in progress; let it finish.
                last_connected = time.monotonic()
                continue

            mode = self._refresh_network_status()
            now = time.monotonic()
            if mode != "disconnected":
                last_connected = now
            elif self.network_mode != "client" and now - last_connected >= grace_secs:
                self._log("No Wi-Fi connection; starting the device hotspot.")
                self._start_hotspot()
                last_connected = now

    def _join_wifi(self, ssid: str, password: str, uid: str) -> None:
        with self.wifi_join_lock:
            mode, connection, _ = self.wifi.status()
            if mode == "client" and connection == ssid:
                # nmcli names client profiles after their SSID.
                ok, detail = True, f"Already connected to Wi-Fi network '{ssid}'."
            else:
                ok, detail = self.wifi.connect_client(ssid, password)
            self._log(detail)
            if not ok and self.network_mode == "auto":
                self._start_hotspot()
            self._refresh_network_status()

        self._update_provisioning_status(
            "ready",
            ssid=ssid,
            uid=uid,
            wifi_applied=ok,
            detail=detail,
        )

    def _handle_config(self, payload) -> None:
        ssid = str(payload.get("ssid", "")).strip()
        password = str(payload.get("password", "")).strip()
        uid = str(payload.get("uid", "")).strip()

        if not uid:
            self._log("Invalid BLE provisioning payload: missing uid")
            self._notify_client("ERR: missing uid\n")
            self._update_provisioning_status(
                "invalid",
                ssid=ssid or None,
                detail="Provisioning payload missing uid.",
            )
            return

        # A phone that is already on the device hotspot (or sends no SSID) only
        # needs to link its account; keep the saved home network.
        link_only = not ssid or (
            self.wifi is not None and ssid == self.wifi.hotspot_ssid
        )
        join_wifi = False
        if link_only:
            with self.config_lock:
                ssid, password = self.provisioning.ssid, self.provisioning.password
            detail = "Linked account; kept current network settings."
        elif self.skip_wifi_apply:
            detail = "Saved Wi-Fi details; Wi-Fi apply skipped by configuration."
        elif self.wifi is None:
            detail = "Saved configuration locally; nmcli not available."
        elif self.network_mode == "hotspot":
            detail = "Saved Wi-Fi details; device is set to hotspot-only mode."
        else:
            join_wifi = True
            detail = f"Saved. Joining Wi-Fi '{ssid}'."

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

        self._log(f"Received provisioning config for uid={uid} on SSID={ssid}")
        self._update_runtime_status("online", last_provisioned_at=config.updated_at)
        if join_wifi:
            # Joining can take longer than the app waits for a reply and this
            # runs on the BLE callback, so connect in the background. The app
            # learns the outcome from the NET: notification.
            threading.Thread(
                target=self._join_wifi,
                args=(ssid, password, uid),
                daemon=True,
            ).start()
        else:
            self._update_provisioning_status(
                "ready",
                ssid=ssid or None,
                uid=uid,
                wifi_applied=False,
                detail=detail,
            )
        self._notify_client(f"OK: {detail}\n")
        self._notify_network_status()

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
        if notifying:
            self._notify_fall_status(
                self._last_fall_kind,
                self._last_fall_at_ms,
            )
            self._notify_network_status()

    def _uart_write_cb(self, value, options) -> None:
        del options
        self._rx_buffer.extend(bytes(value))
        self._try_parse_json_from_buffer()

    def ble_worker(self) -> None:
        ble = None
        try:
            if BLE_IMPORT_ERROR is not None:
                raise RuntimeError(f"BLE unavailable: {BLE_IMPORT_ERROR}")

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
            self._log("BLE UART service published and waiting for client connection.")
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
            # Reading .voltage would trigger a second ADC conversion, so derive
            # it from the single raw reading.
            with self.sensor_lock:
                raw_value = int(self.heartrate_sensor.value)
            voltage = raw_value * self.ads_full_scale_v / 32767

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

            if self.debug_telemetry:
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
                self._notify_client(f"BPM:{current_bpm}\n")
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
                    # The gyro only feeds the debug telemetry below.
                    gx, gy, gz = self.sox.gyro if self.debug_telemetry else (0, 0, 0)

                now_ms = _timestamp_ms()
                if self.debug_telemetry:
                    live_payload = {
                        "x": ax,
                        "y": ay,
                        "z": az,
                        "gx": gx,
                        "gy": gy,
                        "gz": gz,
                        "mag": math.sqrt(ax * ax + ay * ay + az * az),
                        "ts_client_ms": now_ms,
                        "ts_server": _server_timestamp(),
                    }
                    self._safe_set(
                        self.accel_ref.child("live"), live_payload, "accel live"
                    )

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
                    self._log_motion_event(event_payload)
                    code = MOTION_EVENT_CODES.get(event["kind"])
                    if code:
                        self._notify_client(f"ADM:{code}\n")
                    if event["kind"] in {
                        "real_tumbling",
                        "real_tripping",
                        "real_slipping",
                    }:
                        self._last_fall_kind = event["kind"]
                        self._last_fall_at_ms = now_ms
                        self._notify_fall_status(event["kind"], now_ms)

                if (
                    self.debug_telemetry
                    and (now_ms - last_counts_upload_ms) >= counts_every_ms
                ):
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
        # Learn the current network first so startup status writes are only
        # queued when the device can actually reach Firebase.
        self._refresh_network_status()
        uploader = threading.Thread(target=self.upload_worker, daemon=True)
        uploader.start()
        self._update_runtime_status("online", started_at=_utc_now_iso())
        self._update_provisioning_status(
            "ready" if self.provisioning.uid else "awaiting_provisioning",
            ssid=self.provisioning.ssid or None,
            uid=self.provisioning.uid or None,
            wifi_applied=None,
            detail="Loaded saved config." if self.provisioning.uid else None,
        )

        workers = []
        degraded_reasons = []

        if self.sensor_error:
            degraded_reasons.append(f"sensors unavailable: {self.sensor_error}")
            self._log(f"Sensors unavailable; sensor workers disabled: {self.sensor_error}")
        else:
            workers.extend(
                [
                    threading.Thread(target=self.heartbeat_worker, daemon=True),
                    threading.Thread(target=self.accel_worker, daemon=True),
                ]
            )

        if self.wifi is not None:
            workers.append(threading.Thread(target=self.network_worker, daemon=True))

        if BLE_IMPORT_ERROR is not None:
            degraded_reasons.append(f"BLE unavailable: {BLE_IMPORT_ERROR}")
            self._log(f"BLE unavailable; BLE worker disabled: {BLE_IMPORT_ERROR}")
        else:
            workers.append(threading.Thread(target=self.ble_worker, daemon=True))

        if degraded_reasons:
            self._update_runtime_status(
                "degraded",
                started_at=_utc_now_iso(),
                detail="; ".join(degraded_reasons),
            )

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
            try:
                self._upload_queue.put(None, timeout=1)
            except queue.Full:
                pass
            uploader.join(timeout=10)
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
        help=(
            "Only persist BLE provisioning config; do not join Wi-Fi or host "
            "the hotspot."
        ),
    )
    parser.add_argument(
        "--network-mode",
        choices=["auto", "hotspot", "client"],
        default=os.getenv("VITALLINK_NETWORK_MODE", "auto"),
        help=(
            "auto: join the saved Wi-Fi when in range, otherwise host a hotspot. "
            "hotspot: always host the hotspot. client: never host it."
        ),
    )
    parser.add_argument(
        "--wifi-interface",
        default=os.getenv("VITALLINK_WIFI_INTERFACE", "wlan0"),
        help="Wi-Fi interface used for both client and hotspot modes.",
    )
    parser.add_argument(
        "--hotspot-config-path",
        default=os.getenv(
            "VITALLINK_HOTSPOT_CONFIG_PATH",
            str(hardware_dir / "hotspot_config.json"),
        ),
        help="Where the generated hotspot SSID/password are stored.",
    )
    parser.add_argument(
        "--hotspot-ssid",
        default=os.getenv("VITALLINK_HOTSPOT_SSID", ""),
        help="Hotspot name. Defaults to VitalLink-<last 4 of the Wi-Fi MAC>.",
    )
    parser.add_argument(
        "--hotspot-password",
        default=os.getenv("VITALLINK_HOTSPOT_PASSWORD", ""),
        help="Hotspot WPA2 password (8+ chars). Generated once if omitted.",
    )
    parser.add_argument(
        "--client-grace-secs",
        type=float,
        default=float(os.getenv("VITALLINK_CLIENT_GRACE_SECS", "45")),
        help="In auto mode, seconds without Wi-Fi before starting the hotspot.",
    )
    parser.add_argument(
        "--debug-telemetry",
        action="store_true",
        default=os.getenv("VITALLINK_DEBUG_TELEMETRY", "").lower() in {"1", "true"},
        help=(
            "Also upload raw heart-rate samples and live accelerometer/gyro data. "
            "Costs significant Wi-Fi power; the app does not use this data."
        ),
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
        debug_telemetry=args.debug_telemetry,
        network_mode=args.network_mode,
        wifi_interface=args.wifi_interface,
        hotspot_config_path=args.hotspot_config_path,
        hotspot_ssid=args.hotspot_ssid,
        hotspot_password=args.hotspot_password,
        client_grace_secs=args.client_grace_secs,
    )
    runtime.start()


if __name__ == "__main__":
    main()
