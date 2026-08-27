#!/usr/bin/env python3
"""Read Keychron V6 Max Bluetooth status from bluetoothctl output."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

DEVICE_RE = re.compile(
    r"^Device\s+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)$"
)
ADDRESS_RE = re.compile(r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
BATTERY_RE = re.compile(r"Battery Percentage:\s*(?:0x[0-9A-Fa-f]+\s*)?\((\d+)\)")


def run_bluetoothctl(*args: str, timeout: float = 4.0) -> str:
    try:
        completed = subprocess.run(
            ["bluetoothctl", *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("bluetoothctl is not installed") from exc
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"bluetoothctl {' '.join(args)} timed out") from exc
    if completed.returncode != 0:
        err = (completed.stderr or completed.stdout or "").strip()
        raise RuntimeError(err or f"bluetoothctl {' '.join(args)} failed")
    return completed.stdout


def parse_device_list(text: str) -> list[dict]:
    devices = []
    for raw_line in text.splitlines():
        match = DEVICE_RE.match(raw_line.strip())
        if not match:
            continue
        devices.append(
            {
                "address": match.group(1).upper(),
                "name": match.group(3).strip(),
            }
        )
    return devices


def parse_info(text: str, address: str = "") -> dict:
    info = {
        "address": normalize_address(address),
        "name": "",
        "alias": "",
        "icon": "",
        "paired": False,
        "bonded": False,
        "trusted": False,
        "connected": False,
        "battery": None,
    }
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("Device ") and ADDRESS_RE.match(line.split()[1].rstrip("()")):
            info["address"] = normalize_address(line.split()[1])
        elif line.startswith("Name:"):
            info["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("Alias:"):
            info["alias"] = line.split(":", 1)[1].strip()
        elif line.startswith("Icon:"):
            info["icon"] = line.split(":", 1)[1].strip()
        elif line.startswith("Paired:"):
            info["paired"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Bonded:"):
            info["bonded"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Trusted:"):
            info["trusted"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Connected:"):
            info["connected"] = line.split(":", 1)[1].strip().lower() == "yes"
        else:
            battery = BATTERY_RE.search(line)
            if battery:
                info["battery"] = int(battery.group(1))
    if not info["name"] and info["alias"]:
        info["name"] = info["alias"]
    return info


def parse_adapter(text: str) -> dict:
    powered = None
    name = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("Powered:"):
            powered = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Name:"):
            name = line.split(":", 1)[1].strip()
    return {"powered": powered, "name": name}


def normalize_address(value: str) -> str:
    text = str(value or "").strip().upper()
    if ADDRESS_RE.match(text):
        return text
    return ""


def name_matches(device_name: str, match: str) -> bool:
    needle = str(match or "").strip().lower()
    if needle == "":
        return False
    return needle in str(device_name or "").lower()


def choose_device(devices: list[dict], match: str, address: str) -> dict | None:
    pinned = normalize_address(address)
    if pinned:
        for device in devices:
            if device["address"] == pinned:
                return device
        return {"address": pinned, "name": ""}
    matches = [device for device in devices if name_matches(device["name"], match)]
    if not matches:
        return None
    return matches[0]


def build_status(
    devices_text: str,
    info_text: str | None,
    adapter_text: str | None,
    match: str,
    address: str,
) -> dict:
    devices = parse_device_list(devices_text)
    chosen = choose_device(devices, match, address)
    adapter = parse_adapter(adapter_text or "")
    payload = {
        "ok": True,
        "adapterPowered": adapter.get("powered"),
        "adapterName": adapter.get("name") or "",
        "match": match,
        "pinnedAddress": normalize_address(address),
        "candidates": devices,
        "device": None,
        "lastError": "",
    }
    if chosen is None:
        payload["lastError"] = f"No Bluetooth device matching {match!r}"
        return payload
    if info_text is None:
        payload["device"] = {
            "address": chosen["address"],
            "name": chosen["name"],
            "alias": chosen["name"],
            "icon": "",
            "paired": False,
            "bonded": False,
            "trusted": False,
            "connected": False,
            "battery": None,
        }
        return payload
    info = parse_info(info_text, chosen["address"])
    if not info["name"]:
        info["name"] = chosen["name"]
    payload["device"] = info
    return payload


def live_status(match: str, address: str) -> dict:
    devices_text = run_bluetoothctl("devices")
    adapter_text = ""
    try:
        adapter_text = run_bluetoothctl("show")
    except RuntimeError:
        adapter_text = ""
    chosen = choose_device(parse_device_list(devices_text), match, address)
    info_text = None
    if chosen and chosen.get("address"):
        try:
            info_text = run_bluetoothctl("info", chosen["address"])
        except RuntimeError as exc:
            return {
                "ok": False,
                "adapterPowered": None,
                "adapterName": "",
                "match": match,
                "pinnedAddress": normalize_address(address),
                "candidates": parse_device_list(devices_text),
                "device": None,
                "lastError": str(exc),
            }
    return build_status(devices_text, info_text, adapter_text, match, address)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Keychron V6 Max Bluetooth status")
    parser.add_argument("--match", default="Keychron V6 Max")
    parser.add_argument("--address", default="")
    parser.add_argument("--devices-text", default="")
    parser.add_argument("--info-text", default="")
    parser.add_argument("--adapter-text", default="")
    args = parser.parse_args(argv)
    try:
        if args.devices_text:
            status = build_status(
                args.devices_text,
                args.info_text or None,
                args.adapter_text or None,
                args.match,
                args.address,
            )
        else:
            status = live_status(args.match, args.address)
    except Exception as exc:  # noqa: BLE001 — helper returns JSON errors
        json.dump(
            {
                "ok": False,
                "adapterPowered": None,
                "adapterName": "",
                "match": args.match,
                "pinnedAddress": normalize_address(args.address),
                "candidates": [],
                "device": None,
                "lastError": str(exc),
            },
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
        return 1
    json.dump(status, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0 if status.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
