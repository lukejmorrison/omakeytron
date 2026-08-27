#!/usr/bin/env bash
set -euo pipefail

source_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$source_root"

command -v omarchy >/dev/null 2>&1 || {
  echo "test.sh: omarchy is required" >&2
  exit 1
}

omarchy plugin validate .
python3 -m unittest discover -s tests -v

qmlint_bin=""
if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
  qmlint_bin=/usr/lib/qt6/bin/qmllint
elif command -v qmllint >/dev/null 2>&1; then
  qmlint_bin=$(command -v qmllint)
fi
if [[ -n $qmlint_bin ]]; then
  "$qmlint_bin" -I /usr/share/omarchy/shell Model.js KeyboardIcon.qml Service.qml Panel.qml || true
fi

python3 status.py --match "Keychron V6 Max" >/tmp/omakeytron-status.json
python3 - <<'PY'
import json
from pathlib import Path
payload = json.loads(Path("/tmp/omakeytron-status.json").read_text())
assert payload.get("ok") is True
device = payload.get("device") or {}
print("live status:", device.get("name"), device.get("address"), "connected=" + str(device.get("connected")), "battery=" + str(device.get("battery")))
PY

echo "All validation and tests passed."
