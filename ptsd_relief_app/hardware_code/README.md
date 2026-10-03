# VitalLink Helper (Raspberry Pi 5) runtime

`production.py` runs on the wearable. It reads the heart-rate and motion
sensors, talks to the app over BLE, and manages Wi-Fi so the app can reach the
Ollama server on the Pi both at home and outdoors.

## Networking

| Where | Pi's Wi-Fi | Phone | Ollama address | Firebase |
|---|---|---|---|---|
| Home | Joins the Wi-Fi sent from the app's Connect screen | Same home Wi-Fi | Pi's LAN IP, reported over BLE | Pi and phone both write |
| Outdoors | Hosts hotspot `VitalLink-XXXX` | Joins the hotspot; mobile data stays on | Always `10.42.0.1` | Phone relays over mobile data |

With the default `--network-mode auto`, the Pi starts its hotspot when it has
had no Wi-Fi connection for `--client-grace-secs` (45 s). It goes back to the
home network after a reboot, or when the app sends home Wi-Fi details again.
Use `--network-mode hotspot` to always host the hotspot, or `client` to never
host it.

The hotspot has no internet, so in hotspot mode the Pi doesn't write to
Firebase. The app receives BPM and motion events over BLE and writes
`users/<uid>/BPM` and `users/<uid>/ADM` itself over mobile data. Nurse views
keep updating while the patient's phone is connected to the device over BLE.

**Hotspot credentials.** These are generated on first run and saved to
`hotspot_config.json` (mode 600). The SSID and file path are printed at
startup. Put the SSID and password on a label on the case. Override them with
`--hotspot-ssid` / `--hotspot-password` or the `VITALLINK_HOTSPOT_*` env vars.

**Android.** The app reaches the Pi through a small native bridge
(`LocalNetworkBridge.kt`) that binds only Ollama traffic to the hotspot, so
Firebase stays on mobile data. If Android asks whether to stay connected to a
network without internet, choose to stay connected.

## BLE messages (device → app)

| Message | Meaning |
|---|---|
| `BPM:<n>` | Heart rate every 15 s |
| `FALL:<OK\|TB\|TR\|SL>:<ms hex>` | Fall status |
| `ADM:<code>` | Any motion event (`TU`, `TL`, `TB`, `TR`, `SL`, `FJ`, `FT`, `FS`); the app relays it to Firebase |
| `NET:<A\|C\|N>:<IPv4 hex>` | Hotspot / Wi-Fi client / no network, plus the Pi's address |

Provisioning (app → device) is JSON `{"ssid", "password", "uid"}`. `ssid` may
be empty, or the hotspot's own SSID, to only link the signed-in account.

## Pi setup

1. Make Ollama listen on all interfaces so phones can reach it:
   ```bash
   sudo systemctl edit ollama
   ```
   Add the following, then run `sudo systemctl restart ollama`:
   ```ini
   [Service]
   Environment="OLLAMA_HOST=0.0.0.0:11434"
   ```
2. Run `production.py` as root (for example from a systemd service). Changing
   Wi-Fi with `nmcli` and advertising over BLE both need it.
3. If the Pi is powered from a battery board through pogo pins or GPIO, set
   `PSU_MAX_CURRENT=5000` with `sudo rpi-eeprom-config -e`. Then check for
   undervoltage under an Ollama load with `vcgencmd get_throttled` (it should
   print `0x0`).

## Power

By default the runtime uploads only what the app uses: BPM every 15 s, motion
events, and status. `--debug-telemetry` (or `VITALLINK_DEBUG_TELEMETRY=1`)
also uploads raw heart-rate samples and 50 Hz accelerometer/gyro data, which
keeps the Wi-Fi radio busy and costs significant battery. Firebase writes run
on a background queue, so network delays don't stall sensor sampling.
