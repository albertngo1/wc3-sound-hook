# wc3-sound-hook

A Claude Code hook that plays a Blizzard game voice line ("Job's done!") each time Claude finishes a turn.
It's for macOS users who want an audible cue when Claude is waiting on them.

## Install

```bash
git clone https://github.com/albertngo1/wc3-sound-hook.git
cd wc3-sound-hook
./install.sh
```

The installer copies the sounds to `~/.claude/sounds/` and the hook to `~/.claude/wc3_complete.sh`.
It then adds a `Stop` hook to `~/.claude/settings.json` (using `jq` or `python3`), and won't add it twice.
Finish a turn in Claude Code to hear it.

**macOS only.** Playback uses `afplay`.

## Choosing a pack

There are three packs: Warcraft III, StarCraft and Hearthstone. By default, each Claude Code session
picks one at random and keeps it for the whole session.

Set `SOUND_PACK` to change this:

| `SOUND_PACK` | behavior |
|---|---|
| unset or `random` | one random pack per session |
| `wc3`, `starcraft`, `hearthstone` | always that pack |
| `all` | any clip from any pack, picked fresh each turn |

For example, `SOUND_PACK=starcraft claude`, or add `"env": {"SOUND_PACK": "all"}` to `settings.json`.

## Packs

| pack | clips | contents |
|---|---:|---|
| `wc3` | 91 | Reign of Chaos and Frozen Throne unit and hero "Ready" lines |
| `starcraft` | 107 | Terran, Protoss and Zerg ready and acknowledgement lines |
| `hearthstone` | 29 | One short or funny line per well-known card |

To add your own, put `.wav` or `.mp3` files in `~/.claude/sounds/<name>/complete/`. The folder name
becomes the pack name. More detail in [docs/packs.md](docs/packs.md).

## Volume

Set `WC3_VOLUME` (e.g. `0.4`) or write the number to `~/.claude/.wc3_volume`. It's passed to
`afplay -v`. Unset means afplay's default of 1.0.

## Running Claude Code over SSH

If Claude Code runs on a remote host, the hook can play the sound on the laptop you connected from.
This needs a dedicated SSH key and the same sounds on both machines. Setup, hardening and the
`--doctor` check are in [docs/reverse-play.md](docs/reverse-play.md).

## Uninstall

```bash
./uninstall.sh
```

This removes the hook, the sounds and the pack cache from `~/.claude`. It removes the `Stop` hook
from `settings.json` only if `python3` is available, and leaves your other hooks alone.

## Credits and license

The hook code is MIT-licensed (see `LICENSE`). The original WC3 hook idea is from
[warmwind/warcraft3-claude-code-sound-hook](https://github.com/warmwind/warcraft3-claude-code-sound-hook).
Sounds came from [The Sounds Resource](https://www.sounds-resource.com/).

**The voice clips are © Blizzard Entertainment.** They are included for personal, non-commercial use
only and are not covered by the MIT license. If you are Blizzard and want them removed, open an issue.
