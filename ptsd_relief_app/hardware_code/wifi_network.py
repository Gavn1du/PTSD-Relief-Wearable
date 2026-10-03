"""NetworkManager (nmcli) helpers for the VitalLink companion's Wi-Fi.

The companion can either join a normal Wi-Fi network ("client" mode, used at
home where it has internet) or host its own hotspot ("hotspot" mode, used
outdoors so the phone can still reach the Ollama server on the Pi).

In hotspot mode NetworkManager's "shared" IPv4 method gives the Pi the fixed
address HOTSPOT_ADDRESS and runs DHCP for the phone, so the app always knows
where to find Ollama without any configuration.
"""

import json
import secrets
import string
import subprocess
from pathlib import Path
from typing import List, Tuple

HOTSPOT_CONNECTION = "vitallink-hotspot"
HOTSPOT_ADDRESS = "10.42.0.1"


def _run(command: List[str], timeout: float = 30) -> Tuple[bool, str]:
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return True, (result.stdout or "").strip()
    except subprocess.CalledProcessError as error:
        return False, (error.stderr or error.stdout or str(error)).strip()
    except Exception as error:  # pragma: no cover - system dependent
        return False, str(error)


def _default_ssid_suffix(interface: str) -> str:
    try:
        mac = Path(f"/sys/class/net/{interface}/address").read_text().strip()
        return mac.replace(":", "")[-4:].upper()
    except OSError:
        return secrets.token_hex(2).upper()


def load_hotspot_credentials(
    path: Path, interface: str, ssid: str = "", password: str = ""
) -> Tuple[str, str]:
    """Return (ssid, password), generating and persisting any missing value.

    Explicit values (from CLI/env) win. Otherwise the first generated values
    are saved so the hotspot name and password stay the same across reboots
    and can be printed on a label on the case.
    """
    saved = {}
    if path.exists():
        try:
            saved = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            saved = {}

    ssid = ssid or saved.get("ssid") or f"VitalLink-{_default_ssid_suffix(interface)}"
    if not password:
        password = saved.get("password") or "".join(
            secrets.choice(string.ascii_letters + string.digits) for _ in range(12)
        )
    if len(password) < 8:
        raise ValueError("Hotspot password must be at least 8 characters (WPA2).")

    if saved.get("ssid") != ssid or saved.get("password") != password:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps({"ssid": ssid, "password": password}, indent=2),
            encoding="utf-8",
        )
        try:
            path.chmod(0o600)
        except OSError:
            pass
    return ssid, password


class WifiNetwork:
    """Thin wrapper around nmcli for one Wi-Fi interface."""

    def __init__(self, nmcli: str, interface: str, ssid: str, password: str):
        self.nmcli = nmcli
        self.interface = interface
        self.hotspot_ssid = ssid
        self.hotspot_password = password

    def status(self) -> Tuple[str, str, str]:
        """Return (mode, connection_name, ipv4) for the interface.

        mode is "hotspot", "client" or "disconnected".
        """
        ok, output = _run(
            [
                self.nmcli,
                "-t",
                "-f",
                "GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS",
                "device",
                "show",
                self.interface,
            ],
            timeout=10,
        )
        if not ok:
            return "disconnected", "", ""

        state = connection = address = ""
        for line in output.splitlines():
            key, _, value = line.partition(":")
            if key == "GENERAL.STATE":
                state = value
            elif key == "GENERAL.CONNECTION":
                connection = value
            elif key.startswith("IP4.ADDRESS") and not address:
                address = value.split("/", 1)[0]

        if not state.startswith("100"):
            return "disconnected", connection, ""
        if connection == HOTSPOT_CONNECTION:
            return "hotspot", connection, address or HOTSPOT_ADDRESS
        return "client", connection, address

    def _ensure_hotspot_profile(self) -> Tuple[bool, str]:
        settings = [
            "802-11-wireless.ssid",
            self.hotspot_ssid,
            "wifi-sec.psk",
            self.hotspot_password,
        ]
        exists, _ = _run(
            [self.nmcli, "connection", "show", HOTSPOT_CONNECTION], timeout=10
        )
        if exists:
            return _run([self.nmcli, "connection", "modify", HOTSPOT_CONNECTION, *settings])

        return _run(
            [
                self.nmcli,
                "connection",
                "add",
                "type",
                "wifi",
                "ifname",
                self.interface,
                "con-name",
                HOTSPOT_CONNECTION,
                # The runtime decides when to start the hotspot; NetworkManager
                # should only auto-join saved client networks.
                "autoconnect",
                "no",
                "802-11-wireless.mode",
                "ap",
                "802-11-wireless.band",
                "bg",
                "802-11-wireless.channel",
                "6",
                "ipv4.method",
                "shared",
                "ipv4.addresses",
                f"{HOTSPOT_ADDRESS}/24",
                "ipv6.method",
                "disabled",
                "wifi-sec.key-mgmt",
                "wpa-psk",
                "wifi-sec.proto",
                "rsn",
                "wifi-sec.pairwise",
                "ccmp",
                "wifi-sec.group",
                "ccmp",
                # Protected management frames stop some phones from joining a
                # Pi-hosted hotspot.
                "wifi-sec.pmf",
                "disable",
                *settings,
            ]
        )

    def start_hotspot(self) -> Tuple[bool, str]:
        ok, detail = self._ensure_hotspot_profile()
        if not ok:
            return False, f"Could not create hotspot profile: {detail}"
        ok, detail = _run([self.nmcli, "connection", "up", HOTSPOT_CONNECTION])
        if not ok:
            return False, f"Could not start hotspot: {detail}"
        return True, f"Hosting Wi-Fi hotspot '{self.hotspot_ssid}'."

    def stop_hotspot(self) -> None:
        _run([self.nmcli, "connection", "down", HOTSPOT_CONNECTION], timeout=15)

    def connect_client(self, ssid: str, password: str) -> Tuple[bool, str]:
        # The radio cannot scan for the home network while it is hosting the
        # hotspot, so drop the hotspot first.
        self.stop_hotspot()
        _run([self.nmcli, "device", "wifi", "rescan", "ifname", self.interface], timeout=15)

        command = [self.nmcli, "device", "wifi", "connect", ssid, "ifname", self.interface]
        if password:
            command.extend(["password", password])
        ok, detail = _run(command, timeout=45)
        if ok:
            return True, f"Connected to Wi-Fi network '{ssid}'."
        return False, f"Failed to connect Wi-Fi: {detail}"
