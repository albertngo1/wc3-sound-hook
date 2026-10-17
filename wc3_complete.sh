#!/bin/bash
# Claude Code "done" sound — plays a random game voice line when Claude Code finishes a turn.
#
# Multi-game sound-pack library. Choose the active pack with SOUND_PACK:
#   (unset) or "random" -> one random pack per Claude session (sticky for that session)
#   wc3 | starcraft | hearthstone | <any folder under sounds/> -> always that pack
#   all                 -> every clip from every pack, fresh random each turn
# Packs live under ~/.claude/sounds/<pack>/complete/ (any subdir layout below that); a clip
# is picked uniformly at random across every file in the active pack.
#
#   - Local (sitting at this machine / Happy / launchd):  afplay here.
#   - Over SSH:  play on the machine you connected FROM (it has identical sounds via chezmoi),
#                so you hear it at your desk instead of out of the remote host's speakers.
#
# Reverse-play auth: a dedicated key (~/.ssh/wc3_reverse_play) whose public half is in the
# SSH client's authorized_keys. If it's not set up the ssh call fails fast (BatchMode) and
# nothing plays remotely — no hangs.
#
# Wired to the Stop hook in ~/.claude/settings.json. WC3 sounds: github.com/warmwind/warcraft3-claude-code-sound-hook.

SOUNDS_DIR="$HOME/.claude/sounds"
SSH_USER="${WC3_SSH_USER:-$(cat "$HOME/.claude/.wc3_ssh_user" 2>/dev/null || id -un)}"  # reverse-play user: env > ~/.claude/.wc3_ssh_user > current user
SSH_KEY="$HOME/.ssh/wc3_reverse_play"
# Local-playback volume (env > ~/.claude/.wc3_volume > unset). Empty = afplay default (1.0).
# Reverse-play sends a plain `afplay <path>` so it works with an afplay-only forced-command key;
# set volume on the SSH client side if you need it there.
WC3_VOLUME="${WC3_VOLUME:-$(cat "$HOME/.claude/.wc3_volume" 2>/dev/null | tr -d '[:space:]')}"

# --- reliability / observability (the reverse-play path is the only one that can silently die) -
LOG_DIR="$HOME/.claude/logs"
WC3_LOG="$LOG_DIR/wc3.log"
LAST_OK="$HOME/.claude/.wc3-last-ok"     # touched on a successful reverse-play

wc3_log() {  # append a timestamped line to wc3.log, never fatal
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >> "$WC3_LOG" 2>/dev/null || true
}
wc3_fail() {  # log a failure (reverse-play is fire-and-forget, so this is the only trace)
    wc3_log "FAIL: $1"
}

_file_age_secs() {  # seconds since mtime of $1, or empty if missing
    [ -f "$1" ] || return 1
    local now mt; now="$(date +%s)"; mt="$(stat -f %m "$1" 2>/dev/null)" || return 1
    printf '%s' "$((now - mt))"
}

wc3_doctor() {  # print PASS/FAIL per rung; exit 0 always (diagnostic)
    local host="${WC3_DOCTOR_HOST:-${SSH_CONNECTION%% *}}"
    printf 'wc3 reverse-play doctor\n'
    # file presence
    local n; n="$(find "$SOUNDS_DIR" -type f \( -iname '*.wav' -o -iname '*.mp3' \) 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${n:-0}" -gt 0 ]; then printf '  PASS  sounds present (%s clips)\n' "$n"; else printf '  FAIL  no sound clips under %s\n' "$SOUNDS_DIR"; fi
    # key
    if [ -f "$SSH_KEY" ]; then printf '  PASS  reverse-play key present (%s)\n' "$SSH_KEY"; else printf '  FAIL  missing key %s\n' "$SSH_KEY"; fi
    # last success freshness
    local age; if age="$(_file_age_secs "$LAST_OK")"; then printf '  INFO  last successful reverse-play: %sh ago\n' "$((age/3600))"; else printf '  INFO  no successful reverse-play recorded yet\n'; fi
    # liveness + auth (need a target host)
    if [ -n "$host" ]; then
        if command -v nc >/dev/null 2>&1 && nc -z -G1 -w1 "$host" 22 >/dev/null 2>&1; then
            printf '  PASS  liveness: %s:22 reachable\n' "$host"
            # Behavioral probe: a legit afplay must be allowed; if the key is locked to afplay with a
            # forced command in the client's authorized_keys, an arbitrary command must be denied.
            local sopts=(-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -i "$SSH_KEY" -o IdentitiesOnly=yes)
            local clip rel pos_rc neg_rc
            # positive: a legit afplay of a real clip must be ALLOWED (also audibly confirms the channel)
            clip="$(find "$SOUNDS_DIR" -type f \( -iname '*.wav' -o -iname '*.mp3' \) 2>/dev/null | head -1)"
            if [ -n "$clip" ]; then
                rel="~/.claude/${clip#"$HOME/.claude/"}"
                ssh "${sopts[@]}" "$SSH_USER@$host" "afplay $rel" >/dev/null 2>&1; pos_rc=$?
            else
                pos_rc=1
            fi
            # negative: does a non-afplay command run? (yes = key is unrestricted)
            ssh "${sopts[@]}" "$SSH_USER@$host" "id" >/dev/null 2>&1; neg_rc=$?
            if [ "$pos_rc" -ne 0 ] && [ "$neg_rc" -ne 0 ]; then
                printf '  FAIL  auth: client refused the key, or afplay/sound path missing on the client\n'
            elif [ "$pos_rc" -ne 0 ]; then
                printf '  FAIL  auth: key works but afplay failed — sounds missing on the client?\n'
            elif [ "$neg_rc" -eq 0 ]; then
                printf '  PASS  auth: afplay works (played one clip)\n'
                printf '  WARN  key is unrestricted: `id` ran over it — consider a forced command in the client authorized_keys (see README)\n'
            else
                printf '  PASS  auth: afplay allowed, shell command denied — forced command enforced (played one clip)\n'
            fi
        else
            printf '  FAIL  liveness: %s:22 unreachable\n' "$host"
        fi
    else
        printf '  SKIP  liveness/auth: no target host (run over SSH or set WC3_DOCTOR_HOST=<client-ip>)\n'
    fi
    exit 0
}

case "${1:-}" in
    --doctor)           wc3_doctor ;;
esac

# --- read the hook's stdin JSON (Claude passes session_id etc.); skip if run interactively ----
sid=""
if [ ! -t 0 ]; then
    _in="$(cat)"
    sid="$(printf '%s' "$_in" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)"
fi

# --- resolve the active pack ----------------------------------------------------------------
# SOUND_PACK: unset/"random" -> one random pack per session (sticky); <name> -> that pack;
#             "all" -> every clip from every pack, fresh each turn.
PACK="${SOUND_PACK:-random}"
if [ "$PACK" = "random" ]; then
    cache_dir="$HOME/.claude/.sound_pack_cache"
    mkdir -p "$cache_dir" 2>/dev/null
    find "$cache_dir" -type f -mtime +7 -delete 2>/dev/null   # prune stale sessions
    cache="$cache_dir/${sid:-nosession}"
    [ -r "$cache" ] && PACK="$(cat "$cache" 2>/dev/null)"
    if [ -z "$PACK" ] || [ "$PACK" = "random" ] || [ ! -d "$SOUNDS_DIR/$PACK/complete" ]; then
        packs=()
        for d in "$SOUNDS_DIR"/*/complete; do [ -d "$d" ] && packs+=("$(basename "$(dirname "$d")")"); done
        [ ${#packs[@]} -eq 0 ] && exit 0
        PACK="${packs[$((RANDOM % ${#packs[@]}))]}"
        printf '%s' "$PACK" > "$cache" 2>/dev/null
    fi
fi

# --- collect candidate clips for the active pack -------------------------------------------
# Filenames are identical on every machine via chezmoi, so the chosen ~-relative path
# resolves whether we afplay locally or over ssh.
if [ "$PACK" = "all" ]; then
    search_dirs=("$SOUNDS_DIR"/*/complete)
else
    search_dirs=("$SOUNDS_DIR/$PACK/complete")
fi

FILES=()
while IFS= read -r f; do
    [ -n "$f" ] && FILES+=("$f")
done < <(find "${search_dirs[@]}" -type f \( -iname '*.wav' -o -iname '*.mp3' \) 2>/dev/null)
[ ${#FILES[@]} -eq 0 ] && exit 0

ABS="${FILES[$((RANDOM % ${#FILES[@]}))]}"
REL="${ABS#"$HOME/.claude/"}"                  # e.g. sounds/wc3/complete/human/PaladinReady1.wav

# --- play it -------------------------------------------------------------------------------
if [ -n "${SSH_CONNECTION:-}" ]; then
    # Reverse-play on the SSH client (first field of SSH_CONNECTION is the client IP)
    CLIENT_IP="${SSH_CONNECTION%% *}"
    ssh_opts=(-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new)
    [ -f "$SSH_KEY" ] && ssh_opts+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)
    # Backgrounded so the Stop hook returns instantly; the subshell owns the fallback ladder.
    {
        # Rung 1: sub-second liveness gate — don't pay the 3s ssh timeout on a sleeping/absent client.
        if command -v nc >/dev/null 2>&1 && ! nc -z -G1 -w1 "$CLIENT_IP" 22 >/dev/null 2>&1; then
            wc3_fail "client $CLIENT_IP:22 unreachable (liveness gate)"
        elif ssh "${ssh_opts[@]}" "$SSH_USER@$CLIENT_IP" "afplay ~/.claude/$REL" >/dev/null 2>&1; then
            touch "$LAST_OK" 2>/dev/null   # success — shown by --doctor
        else
            wc3_fail "reverse-play to $SSH_USER@$CLIENT_IP failed (ssh/afplay)"
        fi
    } &
else
    # Local playback
    if [ -n "$WC3_VOLUME" ]; then
        afplay -v "$WC3_VOLUME" "$HOME/.claude/$REL" >/dev/null 2>&1 &
    else
        afplay "$HOME/.claude/$REL" >/dev/null 2>&1 &
    fi
fi

# --- terminal nudge ------------------------------------------------------------------------
# A hook subprocess has no controlling /dev/tty, so target the live SSH pty directly when set.
if [ -n "${SSH_TTY:-}" ]; then
    { printf '\a' > "$SSH_TTY"; } 2>/dev/null || true
else
    { printf '\a' > /dev/tty; } 2>/dev/null || true
fi

exit 0
