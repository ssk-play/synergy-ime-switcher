#!/bin/bash
# Watch synergy.log for screen transitions and switch macOS IME accordingly.
#   leaving screen  -> save current IME, set to ENGLISH_IME
#   entering screen -> restore saved IME (skipped if NO_RESTORE is set)

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
SWITCH_IME="$DIR/switch-ime"
LOG_FILE="${SYNERGY_LOG:-$HOME/Library/Logs/Synergy/synergy.log}"
STATE_FILE="${STATE_FILE:-$HOME/Library/Caches/synergy-ime-switcher.last}"
ENGLISH_IME="${ENGLISH_IME:-com.apple.keylayout.ABC}"
NO_RESTORE="${NO_RESTORE:-}"

mkdir -p "$(dirname "$STATE_FILE")"

if [[ ! -x "$SWITCH_IME" ]]; then
    echo "switch-ime binary not found or not executable at $SWITCH_IME" >&2
    exit 1
fi

# Wait for log file to exist (Synergy may not be running yet).
while [[ ! -f "$LOG_FILE" ]]; do
    echo "waiting for $LOG_FILE ..."
    sleep 5
done

echo "watching $LOG_FILE"

# -F: follow even if rotated.  -n0: only new lines.
tail -n 0 -F "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"leaving screen"*)
            current="$("$SWITCH_IME" get 2>/dev/null || true)"
            printf '%s' "${current:-}" > "$STATE_FILE"
            "$SWITCH_IME" set "$ENGLISH_IME" || echo "failed to set $ENGLISH_IME" >&2
            echo "$(date '+%H:%M:%S') leaving (was: ${current:-?}) -> $ENGLISH_IME"
            ;;
        *"entering screen"*)
            if [[ -n "$NO_RESTORE" ]]; then
                echo "$(date '+%H:%M:%S') entering -> (NO_RESTORE, kept as-is)"
            elif [[ -s "$STATE_FILE" ]]; then
                prev="$(cat "$STATE_FILE")"
                "$SWITCH_IME" set "$prev" || echo "failed to restore $prev" >&2
                echo "$(date '+%H:%M:%S') entering -> $prev"
            else
                echo "$(date '+%H:%M:%S') entering -> (no saved IME)"
            fi
            ;;
    esac
done
