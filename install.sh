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

if [[ "$NO_RESTORE" -eq 1 ]]; then
    echo "==> mode: --no-restore (entering screen 시 IME 복원 안 함)"
    awk '
        /^<\/dict>$/ {
            print "    <key>EnvironmentVariables</key>"
            print "    <dict>"
            print "        <key>NO_RESTORE</key>"
            print "        <string>1</string>"
            print "    </dict>"
            print ""
        }
        { print }
    ' "$PLIST_DST" > "$PLIST_DST.tmp"
    mv "$PLIST_DST.tmp" "$PLIST_DST"
fi

echo "==> reloading launchd job"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"

echo "==> done"
echo "    log:   tail -f $DIR/run.log"
echo "    err:   tail -f $DIR/run.err.log"
echo "    stop:  launchctl unload $PLIST_DST"
