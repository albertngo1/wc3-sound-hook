# wc3-sound-hook

Play a classic RTS/Blizzard voice line every time **Claude Code** finishes a turn — *"Job's done!"*

Started as Warcraft III "Ready" lines; now a small **multi-game sound-pack library** that rotates
across **Warcraft III**, **StarCraft**, and **Hearthstone**.

## Install

```bash
git clone https://github.com/albertngo1/wc3-sound-hook.git
cd wc3-sound-hook
./install.sh
```

The installer copies the sound packs to `~/.claude/sounds/`, drops the hook at
`~/.claude/wc3_complete.sh`, and idempotently wires a `Stop` hook into `~/.claude/settings.json`.
Finish a turn in Claude Code and you'll hear it. (macOS — playback uses `afplay`.)

## Choosing a pack

Set the `SOUND_PACK` environment variable:

| `SOUND_PACK` | behaviour |
|---|---|
| *(unset)* or `random` | **pick one random pack per Claude session** (stays consistent for that session) |
| `wc3` / `starcraft` / `hearthstone` | always that game |
| `all` | every clip from every pack, fresh random each turn |

e.g. `SOUND_PACK=starcraft claude`, or add `"env": {"SOUND_PACK": "all"}` to your `settings.json`.

## Packs

| pack | clips | what |
|---|---:|---|
| `wc3` | 77 | Reign of Chaos unit/hero "Ready" lines (all 4 races + neutral) |
| `starcraft` | 107 | Terran / Protoss / Zerg unit ready + acknowledgement lines |
| `hearthstone` | 44 | hero emotes — Greetings / Thanks / Well-Played / Threaten |

Drop your own `~/.claude/sounds/<anything>/complete/*.wav` and it becomes a selectable pack too.

## Advanced: reverse-play over SSH

If you run Claude Code on a remote host over SSH, the hook can play the sound on the machine you
**connected from** (your laptop) instead of the remote's speakers. When `$SSH_CONNECTION` is set it
runs `afplay` on the SSH client via a dedicated key `~/.ssh/wc3_reverse_play` — the client needs the
same `~/.claude/sounds/` and that key's public half in its `authorized_keys`. If it isn't set up the
SSH call fails fast and only the terminal bell fires. Set `WC3_SSH_USER` if your client username differs.

## Uninstall

```bash
./uninstall.sh
```

## Credits & license

Hook code is MIT-licensed (see `LICENSE`). Original WC3 hook idea:
[warmwind/warcraft3-claude-code-sound-hook](https://github.com/warmwind/warcraft3-claude-code-sound-hook).
Sounds were ripped from [The Sounds Resource](https://www.sounds-resource.com/).

**Audio note:** the voice clips are © Blizzard Entertainment, included here for personal,
non-commercial use only. They are not covered by the MIT license. If you are Blizzard and would like
them removed, open an issue.
