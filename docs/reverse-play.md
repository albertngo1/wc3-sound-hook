# Reverse-play over SSH

If you run Claude Code on a remote host over SSH, the hook can play the sound on the machine you
connected from (your laptop) instead of the remote's speakers.

## How it works

When `$SSH_CONNECTION` is set, the hook takes the client IP from it and runs
`afplay ~/.claude/sounds/...` on that machine over SSH. It uses a dedicated key,
`~/.ssh/wc3_reverse_play`. The call runs in the background, so the hook returns right away.

Before calling `ssh`, the hook checks that port 22 on the client answers (a 1-second `nc` probe).
This avoids waiting out the 3-second SSH timeout when the laptop is asleep. The terminal bell
fires either way.

## Setup

1. Put the same `~/.claude/sounds/` on the client. The hook sends a path relative to `~`, so file
   names must match on both machines.
2. Create the key `~/.ssh/wc3_reverse_play` on the remote host.
3. Add its public half to `authorized_keys` on the client.
4. If your username on the client is different, set `WC3_SSH_USER` or write the name to
   `~/.claude/.wc3_ssh_user`. Otherwise the hook uses your current username.

If the key isn't set up, the SSH call fails fast (`BatchMode=yes`) and only the terminal bell fires.

Volume (`WC3_VOLUME`) applies only to local playback. The remote command is a plain
`afplay <path>`, so set volume on the client if you need it there.

## Locking the key to afplay

The key can be restricted with a forced command in the client's `authorized_keys`:

```
command="/path/to/afplay-only-wrapper.sh",no-pty,no-port-forwarding ssh-ed25519 …
```

The hook only ever sends `afplay ~/.claude/sounds/…`, so a wrapper that allows just that shape is enough.

## Doctor

```bash
~/.claude/wc3_complete.sh --doctor                         # over SSH, or:
WC3_DOCTOR_HOST=<client-ip> ~/.claude/wc3_complete.sh --doctor
```

It prints one line per check:

- clips present under `~/.claude/sounds`
- reverse-play key present
- time since the last successful reverse-play
- client reachable on port 22
- whether the key can play audio (it plays one clip), and whether it is locked to afplay

It runs `id` over the key to test the lock. If that succeeds, the key is unrestricted and you get a WARN.

Failed reverse-plays are logged to `~/.claude/logs/wc3.log`.
