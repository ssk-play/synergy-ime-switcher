# synergy-ime-switcher

Auto-switch the macOS input source to English when the Synergy server's
cursor leaves to another host, and restore the previous IME on return.

Useful for anyone whose primary input method is not English — Korean,
Japanese, Chinese, Cyrillic, Arabic, Vietnamese, and so on. When Synergy
forwards keystrokes to another host while your Mac IME is still in
non-English mode, the receiving host gets garbled or composed input.
This keeps that boundary clean.

## How it works

It tails `~/Library/Logs/Synergy/synergy.log` and reacts to these lines:

- `leaving screen`  → save the current IME, switch to English (`com.apple.keylayout.ABC`)
- `entering screen` → restore the saved IME

No mouse polling, no edge detection — Synergy itself logs every screen
transition, so the trigger is exact and effectively free.

## Requirements

- macOS, Synergy 3 (Synergy 1 / Barrier should also work if the log
  format is the same)
- Xcode Command Line Tools (for `swiftc`)

## Install

```bash
./install.sh                # default: switch to English on leave, restore IME on return
./install.sh --no-restore   # switch to English on leave, stay English on return
```

What it does:
1. Compiles `switch-ime.swift` → `./switch-ime`
2. Installs `~/Library/LaunchAgents/com.sskplay.synergy-ime-switcher.plist`
3. `launchctl load`s the job

## Uninstall

```bash
./uninstall.sh           # unload launchd job, remove plist and state file
./uninstall.sh --purge   # also remove the compiled binary, run.log, run.err.log
```

## Configuration (environment variables)

These are read by `watch.sh`. Add them to the `EnvironmentVariables`
dict in the installed plist
(`~/Library/LaunchAgents/com.sskplay.synergy-ime-switcher.plist`) and reload
the job (`launchctl unload && load`) for changes to take effect.

| Variable | Default |
|---|---|
| `ENGLISH_IME` | `com.apple.keylayout.ABC` |
| `SYNERGY_LOG` | `~/Library/Logs/Synergy/synergy.log` |
| `STATE_FILE`  | `~/Library/Caches/synergy-ime-switcher.last` |
| `NO_RESTORE`  | (unset) — if set to any value, do not restore on `entering` (same as `--no-restore`) |

To discover the ID of an IME you use, switch to it manually and run
`./switch-ime get`. Common ones:

- `com.apple.keylayout.ABC` — English (ABC)
- `com.apple.inputmethod.Korean.2SetKorean` — Korean (2-set)

## Debugging

```bash
tail -f run.log       # normal operation log (leaving / entering events)
tail -f run.err.log   # errors
./switch-ime get      # print current IME ID
./switch-ime set <id> # switch manually
```

To sanity-check that Synergy is actually logging the transitions:

```bash
grep -E "(leaving|entering) screen" ~/Library/Logs/Synergy/synergy.log | tail
```

## Files

```
switch-ime.swift                    # IME CLI built on Carbon TIS APIs
watch.sh                            # tails synergy.log and switches IME
com.sskplay.synergy-ime-switcher.plist  # launchd job template
install.sh                          # compile + install plist + load
uninstall.sh                        # unload + clean up (supports --purge)
```

## License

MIT — see [LICENSE](LICENSE).
