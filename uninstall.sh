#!/usr/bin/env bash
# Remove the Stop hook line and the installed files. Leaves your other settings.json hooks intact.
set -euo pipefail
DEST="$HOME/.claude"; SETTINGS="$DEST/settings.json"; CMD="bash ~/.claude/wc3_complete.sh"
if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
  CMD="$CMD" python3 - "$SETTINGS" <<'PY'
import json,os,sys
p=sys.argv[1]; cmd=os.environ["CMD"]
try: d=json.load(open(p))
except Exception: d={}
st=d.get("hooks",{}).get("Stop",[])
st=[g for g in st if not any(x.get("command")==cmd for x in g.get("hooks",[]))]
if "hooks" in d: d["hooks"]["Stop"]=st
json.dump(d,open(p,"w"),indent=2)
PY
  echo "Removed Stop hook from $SETTINGS"
fi
rm -f "$DEST/wc3_complete.sh"
rm -rf "$DEST/sounds"
rm -rf "$DEST/.sound_pack_cache"
echo "Uninstalled (sounds + hook removed)."
