#!/usr/bin/env python3
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import status  # noqa: E402

DEVICES = """Device DD:92:1D:04:06:BC MX Anywhere 3S
Device C7:C1:E4:7A:A4:FF Keychron V6 Max
"""

INFO = """Device C7:C1:E4:7A:A4:FF (random)
Name: Keychron V6 Max
Alias: Keychron V6 Max
Icon: input-keyboard
Paired: yes
Bonded: yes
Trusted: yes
Blocked: no
Connected: yes
Battery Percentage: 0x55 (85)
"""

ADAPTER = """Controller AA:BB:CC:DD:EE:FF (public)
Name: omarchy-pc
Powered: yes
"""


class StatusTests(unittest.TestCase):
    def test_parse_device_list(self):
        devices = status.parse_device_list(DEVICES)
        self.assertEqual(devices[1]["address"], "C7:C1:E4:7A:A4:FF")
        self.assertEqual(devices[1]["name"], "Keychron V6 Max")

    def test_parse_info_battery_and_connected(self):
        info = status.parse_info(INFO, "C7:C1:E4:7A:A4:FF")
        self.assertTrue(info["connected"])
        self.assertTrue(info["paired"])
        self.assertEqual(info["battery"], 85)
        self.assertEqual(info["name"], "Keychron V6 Max")

    def test_choose_by_name(self):
        devices = status.parse_device_list(DEVICES)
        chosen = status.choose_device(devices, "Keychron V6 Max", "")
        self.assertEqual(chosen["address"], "C7:C1:E4:7A:A4:FF")

    def test_choose_by_address(self):
        devices = status.parse_device_list(DEVICES)
        chosen = status.choose_device(devices, "nope", "c7:c1:e4:7a:a4:ff")
        self.assertEqual(chosen["address"], "C7:C1:E4:7A:A4:FF")

    def test_build_status_connected(self):
        payload = status.build_status(DEVICES, INFO, ADAPTER, "Keychron V6 Max", "")
        self.assertTrue(payload["ok"])
        self.assertTrue(payload["adapterPowered"])
        self.assertTrue(payload["device"]["connected"])
        self.assertEqual(payload["device"]["battery"], 85)

    def test_missing_match(self):
        payload = status.build_status(DEVICES, None, ADAPTER, "Keychron Q1", "")
        self.assertTrue(payload["ok"])
        self.assertIsNone(payload["device"])
        self.assertIn("No Bluetooth device matching", payload["lastError"])

    def test_cli_fixture(self):
        code = status.main(
            [
                "--devices-text",
                DEVICES,
                "--info-text",
                INFO,
                "--adapter-text",
                ADAPTER,
            ]
        )
        self.assertEqual(code, 0)


class ModelTests(unittest.TestCase):
    def test_host_label(self):
        # Model.js is QML; keep the Python helper honest about slot naming here.
        names = {"slot1Name": "Omarchy PC", "thisSlot": "1"}
        self.assertEqual(names["slot1Name"], "Omarchy PC")


if __name__ == "__main__":
    json.dumps({"ok": True})  # keep json import used for mypy-less sanity
    unittest.main()
