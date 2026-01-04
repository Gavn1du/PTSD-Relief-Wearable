import time
import board
import busio
import json

import math
import threading
from datetime import datetime

from adafruit_lsm6ds.lsm6dsox import LSM6DSOX

import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn

import firebase_admin
from firebase_admin import credentials
from firebase_admin import db

from bluezero import peripheral

# ----- Bluetooth setup -----
DEVICE_NAME = "VitalLink Helper"
NUS_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
NUS_RX_UUID      = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  # phone writes here
NUS_TX_UUID      = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  # pi notifies here
_rx_buffer = bytearray()


# ----- Sensor setup -----
i2c = busio.I2C(board.SCL, board.SDA)
sox = LSM6DSOX(i2c)

ads = ADS.ADS1115(i2c)
ads.gain = 1
ads.data_rate = 250
heartrate_sensor = AnalogIn(ads, ADS.P3)


# ----- Firebase DB paths -----
cred = credentials.Certificate("codingmindstest-firebase-adminsdk-6vyr9-731d2a7086.json")
firebase_admin.initialize_app(
	cred,
	{'databaseURL':'https://codingmindstest-default-rtdb.firebaseio.com/'}
)

root_ref   = db.reference("gavin/sensors")
session_id = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")  # groups heartbeat batches
hb_ref     = root_ref.child("heartbeat").child(session_id) # batched windows
acc_ref    = root_ref.child("accel")                       # live stream + history

stop_event = threading.Event()

def send_notify(periph: peripheral.Peripheral, text: str):
    try:
        periph.characteristics[1].set_value(list(text.encode("utf-8")))
        periph.characteristics[1].notify()
        print("Sent notification:", text.strip())
    except Exception as e:
        print("Notification error:", e)


def handle_config(periph: peripheral.Peripheral, cfg: dict):
    ssid: cfg.get("ssid", "")
    password: cfg.get("password", "")
    uid = cfg.get("uid", "")

    if not ssid or uid:
        send_notify(periph, "ERR: missing ssid/uid\n")
        return

    print(f"Received WiFi config: SSID={ssid}, PASSWORD={password}, UID={uid}")

    send_notify(periph, "OK: config received\n")


def try_parse_json_from_buffer(periph: peripheral.Peripheral):
    global _rx_buffer

    if len(_rx_buffer) > 8192:
        _rx_buffer = bytearray()
        send_notify(periph, "ERR: buffer overflow\n")
        return
    
    try:
        text = _rx_buffer.decode("utf-8")
        cfg = json.loads(text)
    except UnicodeError:
        return
    except json.JSONDecodeError:
        return

    _rx_buffer = bytearray()
    if isinstance(cfg, dict):
        handle_config(periph, cfg)
    else:
        send_notify(periph, "ERR: invalid JSON format\n")


def ble_server():
    periph = peripheral.Peripheral(
        adapter_addr=None,
        local_name=DEVICE_NAME,
        appearance= 0x0000,
        services=[]
    )

    write_char = peripheral.Characteristic(
        uuid=NUS_RX_UUID,
        properties=["write", "write-without-response"],
        value=[],
    )

    notify_char = peripheral.Characteristic(
        uuid=NUS_TX_UUID,
        properties=["notify"],
        value=[],
    )

    nus_service = peripheral.Service(
        uuid=NUS_SERVICE_UUID,
        primary=True,
        characteristics = [write_char, notify_char]
    )

    periph.add_service(nus_service)

    def on_write(value):
        global _rx_buffer
        chunk = bytes(value)
        _rx_buffer.extend(chunk)
        try_parse_json_from_buffer(periph)

    write_char.add_callback = on_write

    print(f"Advertising BLE name: {DEVICE_NAME}")
    periph.publish()

    try:
        while True:
            time.sleep(0.2)
    except KeyboardInterrupt:
        print("Stopping BLE server...")
        periph.stop()
    finally:
        periph.stop()


def heartbeat_worker(
    window_secs=5.0,
    target_sps=200,          # target sampling rate (sleep-based pacing)
    upload_interval_secs=6.0 # upload each window; any remainder time is fine
):
    """
    Collect a short window of heartbeat samples (timestamped voltage) and push as batches.
    """
    # Pace setup
    dt = 1.0 / float(target_sps)
    # (Metadata only) capture ADC config actually used
    try:
        data_rate = getattr(ads, "data_rate", None)
        gain      = getattr(ads, "gain", None)
    except Exception:
        data_rate = None
        gain = None

    while not stop_event.is_set():
        t_start = time.time()
        samples = []  # list of {t_ms, v}

        # Collect a fixed window
        while (time.time() - t_start) < window_secs and not stop_event.is_set():
            t_ms = int(time.time() * 1000)
            v    = heartrate_sensor.voltage  # float volts
            samples.append({"t": t_ms, "v": v})
            # Try to maintain target rate
            time.sleep(dt)

        if samples:
            payload = {
                "meta": {
                    "session": session_id,
                    "fs_target": target_sps,
                    "ads_data_rate": data_rate,
                    "ads_gain": gain,
                    "n": len(samples),
                },
                "samples": samples,              # ~5s chunk
                "ts_client_ms": int(time.time()*1000),
                # Server timestamp (canonical ordering in Realtime DB)
                "ts_server": {".sv": "timestamp"},
            }
            try:
                hb_ref.push(payload)  # unique key under /sensors/heartbeat/<session_id>/
            except Exception as e:
                print("Heartbeat upload error:", e)

        # small gap before next window (optional)
        remaining = max(0.0, upload_interval_secs - (time.time() - t_start))
        if remaining > 0:
            time.sleep(remaining)

def accel_worker(
    poll_ms=100,
    also_log_history_every_ms=2000
):
    """
    Stream current acceleration (x,y,z,magnitude) to /sensors/accel/live and
    also push a throttled history entry.
    """
    last_history_ms = 0
    while not stop_event.is_set():
        try:
            ax, ay, az = sox.acceleration  # m/s^2
            mag = math.sqrt(ax*ax + ay*ay + az*az)
            now_ms = int(time.time() * 1000)

            live_payload = {
                "x": ax, "y": ay, "z": az, "mag": mag,
                "ts_client_ms": now_ms,
                "ts_server": {".sv": "timestamp"},
            }
            # Overwrite live location so clients can read the latest quickly
            acc_ref.child("live").set(live_payload)

            # Also write a lighter history point occasionally
            if (now_ms - last_history_ms) >= also_log_history_every_ms:
                acc_ref.child("history").push(live_payload)
                last_history_ms = now_ms

        except Exception as e:
            print("Accel update error:", e)

        time.sleep(poll_ms / 1000.0)

def main():
    # Optional: set your ADS configuration here
    try:
        ads.gain = getattr(ads, "gain", 1)           # keep current if already set
        ads.data_rate = getattr(ads, "data_rate", 250)
    except Exception:
        pass

    th_hb = threading.Thread(target=heartbeat_worker, daemon=True)
    th_ax = threading.Thread(target=accel_worker, daemon=True)
    th_hb.start()
    th_ax.start()

    # Start BLE server (blocking)
    ble_thread = threading.Thread(target=ble_server, daemon=True)
    ble_thread.start()

    print("Running. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopping…")
        stop_event.set()
        th_hb.join(timeout=2)
        th_ax.join(timeout=2)
        ble_thread.join(timeout=2)
        print("Stopped.")

if __name__ == "__main__":
    main()
