#!/usr/bin/env bash
# Installer for the multi-game Claude Code "done" sound hook.
# Copies the sound packs + hook into ~/.claude and wires the Stop hook into settings.json.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude"
SETTINGS="$DEST/settings.json"
CMD="bash ~/.claude/wc3_complete.sh"

command -v afplay >/dev/null 2>&1 || { echo "This hook uses macOS 'afplay' for playback — macOS only for now."; }

echo "Installing sound packs -> $DEST/sounds ..."
mkdir -p "$DEST/sounds"
cp -R "$REPO/sounds/." "$DEST/sounds/"
cp "$REPO/wc3_complete.sh" "$DEST/wc3_complete.sh"
chmod +x "$DEST/wc3_complete.sh"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq --arg cmd "$CMD" '
    .hooks //= {} | .hooks.Stop //= [] |
    if any(.hooks.Stop[]?; any(.hooks[]?; (.command // "") == $cmd)) then .
    else .hooks.Stop += [{"hooks":[{"type":"command","command":$cmd,"async":true}]}] end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "Wired Stop hook in $SETTINGS (via jq)."
elif command -v python3 >/dev/null 2>&1; then
  CMD="$CMD" python3 - "$SETTINGS" <<'PY'
import json, os, sys
p = sys.argv[1]; cmd = os.environ["CMD"]
try: d = json.load(open(p))
except Exception: d = {}
st = d.setdefault("hooks", {}).setdefault("Stop", [])
found = any(any(x.get("command") == cmd for x in g.get("hooks", [])) for g in st)
if not found:
    st.append({"hooks": [{"type": "command", "command": cmd, "async": True}]})
json.dump(d, open(p, "w"), indent=2)
PY
  echo "Wired Stop hook in $SETTINGS (via python3)."
else
  echo "!! Neither jq nor python3 found. Add this Stop hook to $SETTINGS yourself:"
  echo '   {"hooks":{"Stop":[{"hooks":[{"type":"command","command":"bash ~/.claude/wc3_complete.sh","async":true}]}]}}'
fi

echo
echo "Done. Finish a Claude Code turn to hear it."
echo "Pick a pack:  SOUND_PACK=wc3 | starcraft | hearthstone | all   (default: a random pack per session)"
