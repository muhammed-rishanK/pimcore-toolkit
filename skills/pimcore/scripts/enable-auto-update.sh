#!/usr/bin/env bash
# Turns on Claude Code's own plugin auto-update for the pimcore-toolkit marketplace, so every
# new release is installed for you without running "claude plugin update".
# Claude Code keeps auto-update off for marketplaces other than the official one, and a plugin
# cannot switch it on by itself: you run this once (or use /plugin, Marketplaces, pimcore-toolkit,
# "Enable auto-update"). It edits only your own user settings file and keeps a backup.
# Usage: enable-auto-update.sh [--check | --off]
#   --check   print the current state, change nothing
#   --off     turn auto-update off again
# Output: one JSON object {"status":"on|off|blocked|changed|failed","note":"...","settings":"<path>"}
set -u
MODE="on"
case "${1:-}" in
  --check) MODE="check" ;;
  --off) MODE="off" ;;
  -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
  "") ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
command -v python3 >/dev/null 2>&1 || {
  printf '{"status":"failed","note":"python3 is needed to edit the JSON safely; use /plugin, Marketplaces, pimcore-toolkit, Enable auto-update instead","settings":"%s"}\n' "$SETTINGS"; exit 1; }

python3 - "$MODE" "$SETTINGS" <<'PY'
import json, os, shutil, sys, time
mode, path = sys.argv[1], sys.argv[2]
NAME = "pimcore-toolkit"
SOURCE = {"source": "github", "repo": "muhammed-rishanK/pimcore-toolkit"}

def out(status, note, code=0):
    print(json.dumps({"status": status, "note": note, "settings": path}))
    sys.exit(code)

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            text = f.read()
        data = json.loads(text) if text.strip() else {}
    except (OSError, ValueError) as e:
        out("failed", f"cannot read {path}: {e}. Fix the file or use /plugin instead", 1)
if not isinstance(data, dict):
    out("failed", f"{path} is not a JSON object", 1)

entry = (data.get("extraKnownMarketplaces") or {}).get(NAME) or {}
is_on = entry.get("autoUpdate") is True
off_vars = [v for v in ("DISABLE_AUTOUPDATER", "DISABLE_UPDATES", "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC")
            if os.environ.get(v) or (data.get("env") or {}).get(v)]
forced = os.environ.get("FORCE_AUTOUPDATE_PLUGINS") or (data.get("env") or {}).get("FORCE_AUTOUPDATE_PLUGINS")

if mode == "check":
    if is_on and off_vars and not forced:
        out("blocked", "autoUpdate is on, but " + ", ".join(off_vars) + " turns all updates off")
    out("on" if is_on else "off", "auto-update is " + ("on" if is_on else "off") + " for " + NAME)

want = mode == "on"
if is_on == want:
    out("on" if want else "off", "nothing to change, auto-update is already " + ("on" if want else "off"))

if os.path.exists(path):
    backup = f"{path}.bak-{time.strftime('%Y%m%d%H%M%S')}"
    shutil.copy2(path, backup)
else:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    backup = ""
mk = data.setdefault("extraKnownMarketplaces", {})
e = mk.setdefault(NAME, {})
e.setdefault("source", SOURCE)
e["autoUpdate"] = want
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
note = ("auto-update is now " + ("on" if want else "off") + " for " + NAME +
        ". Claude Code checks at startup; a new version applies after /reload-plugins or the next launch")
if backup:
    note += ". Backup: " + backup
if want and off_vars and not forced:
    note += ". Warning: " + ", ".join(off_vars) + " still turns all updates off; set FORCE_AUTOUPDATE_PLUGINS=1 to keep plugin updates"
out("changed", note)
PY
