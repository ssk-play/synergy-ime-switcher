#!/bin/bash
# Stop and remove the synergy-ime-switcher launchd job and its runtime state.
# Compiled binary and source files are NOT removed.
# Pass --purge to also remove the compiled binary and run logs.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.sskplay.synergy-ime-switcher"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_FILE="$HOME/Library/Caches/synergy-ime-switcher.last"

PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help)
            echo "usage: $0 [--purge]"
            echo "  (default)  unload launchd job, remove plist + state file"
            echo "  --purge    additionally remove compiled binary and run.log/run.err.log"
            exit 0
            ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

removed_anything=0

if launchctl list "$LABEL" >/dev/null 2>&1; then
    launchctl unload "$PLIST_DST" 2>/dev/null || \
        launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    echo "unloaded $LABEL"
    removed_anything=1
fi

if [[ -f "$PLIST_DST" ]]; then
    rm -f "$PLIST_DST"
    echo "removed $PLIST_DST"
    removed_anything=1
fi

if [[ -e "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
    echo "removed $STATE_FILE"
    removed_anything=1
fi

if [[ "$PURGE" -eq 1 ]]; then
    for f in "$DIR/switch-ime" "$DIR/run.log" "$DIR/run.err.log"; do
        if [[ -e "$f" ]]; then
            rm -f "$f"
            echo "removed $f"
            removed_anything=1
        fi
    done
fi

if [[ "$removed_anything" -eq 0 ]]; then
    echo "nothing to remove (not installed)"
fi
