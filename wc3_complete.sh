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
    ssh "${ssh_opts[@]}" "$SSH_USER@$CLIENT_IP" "afplay ~/.claude/$REL" >/dev/null 2>&1 &
else
    # Local playback
    afplay "$HOME/.claude/$REL" >/dev/null 2>&1 &
fi

# --- terminal nudge ------------------------------------------------------------------------
# A hook subprocess has no controlling /dev/tty, so target the live SSH pty directly when set.
if [ -n "${SSH_TTY:-}" ]; then
    { printf '\a' > "$SSH_TTY"; } 2>/dev/null || true
else
    { printf '\a' > /dev/tty; } 2>/dev/null || true
fi

exit 0
