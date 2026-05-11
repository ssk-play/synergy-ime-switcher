#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.sskplay.synergy-ime-switcher"
PLIST_SRC="$DIR/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

NO_RESTORE=0
for arg in "$@"; do
    case "$arg" in
        --no-restore) NO_RESTORE=1 ;;
        -h|--help)
            cat <<EOF
usage: $0 [--no-restore]
  --no-restore   leaving screen 시 영문 전환만 하고, entering 시 복원하지 않음
EOF
            exit 0
            ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

cd "$DIR"

echo "==> compiling switch-ime"
swiftc switch-ime.swift -o switch-ime -framework Carbon

echo "==> writing plist to $PLIST_DST"
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__DIR__|$DIR|g" "$PLIST_SRC" > "$PLIST_DST"

# Detect Synergy log path so Synergy 1 works out of the box.
# Synergy 3 writes to ~/Library/Logs/Synergy/synergy.log by default, which is
# what watch.sh falls back to. Synergy 1 only writes to a log file when the
# "Save log to file" preference is on, and the path is user-configurable —
# so we discover it here and inject SYNERGY_LOG into the launchd plist.
#   1) running synergy-server --log <path>  (most accurate)
#   2) Synergy 1 prefs: logFilename when logToFile=1
SYNERGY_LOG_PATH=""
running_synergy="$(ps -axo command 2>/dev/null | grep -i synergy | grep -v grep || true)"
if [[ -n "$running_synergy" ]]; then
    SYNERGY_LOG_PATH="$(printf '%s\n' "$running_synergy" \
        | grep -oE -- '--log[ =][^ ]+' \
        | sed -E 's/^--log[ =]//' \
        | head -1)"
fi
if [[ -z "$SYNERGY_LOG_PATH" ]] && defaults read com.symless.synergy logFilename >/dev/null 2>&1; then
    log_to_file="$(defaults read com.symless.synergy logToFile 2>/dev/null || echo 0)"
    if [[ "$log_to_file" == "1" ]]; then
        SYNERGY_LOG_PATH="$(defaults read com.symless.synergy logFilename 2>/dev/null || true)"
    else
        cat >&2 <<'EOF'
WARNING: Synergy file logging is disabled (defaults: logToFile=0).
The IME switcher reads Synergy's log file to detect screen transitions.
If you are on Synergy 1, enable file logging:
  - Synergy → Settings → check "Save log to file"
  - or:  defaults write com.symless.synergy logToFile -bool true
Then relaunch Synergy and re-run ./install.sh so the log path is picked up.
EOF
    fi
fi
if [[ -n "$SYNERGY_LOG_PATH" ]]; then
    echo "==> detected Synergy log: $SYNERGY_LOG_PATH"
fi

# Build EnvironmentVariables block from any flags/detections that apply.
ENV_KEYS=()
ENV_VALS=()
if [[ "$NO_RESTORE" -eq 1 ]]; then
    echo "==> mode: --no-restore (entering screen 시 IME 복원 안 함)"
    ENV_KEYS+=("NO_RESTORE")
    ENV_VALS+=("1")
fi
if [[ -n "$SYNERGY_LOG_PATH" ]]; then
    ENV_KEYS+=("SYNERGY_LOG")
    ENV_VALS+=("$SYNERGY_LOG_PATH")
fi

if [[ ${#ENV_KEYS[@]} -gt 0 ]]; then
    {
        echo "    <key>EnvironmentVariables</key>"
        echo "    <dict>"
        for i in "${!ENV_KEYS[@]}"; do
            echo "        <key>${ENV_KEYS[$i]}</key>"
            echo "        <string>${ENV_VALS[$i]}</string>"
        done
        echo "    </dict>"
        echo ""
    } > "$PLIST_DST.env"
    awk -v envf="$PLIST_DST.env" '
        /^<\/dict>$/ && !done {
            while ((getline line < envf) > 0) print line
            close(envf)
            done = 1
        }
        { print }
    ' "$PLIST_DST" > "$PLIST_DST.tmp"
    mv "$PLIST_DST.tmp" "$PLIST_DST"
    rm -f "$PLIST_DST.env"
fi

echo "==> reloading launchd job"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"

echo "==> done"
echo "    log:   tail -f $DIR/run.log"
echo "    err:   tail -f $DIR/run.err.log"
echo "    stop:  launchctl unload $PLIST_DST"
