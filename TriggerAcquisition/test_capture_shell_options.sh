#!/usr/bin/env bash

# Offline parser checks. These commands must fail before opening an SSH
# connection or starting ADS-B/RF capture when live provenance is omitted.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TRIGGER_SCRIPT="$SCRIPT_DIR/run_adsb_triggered_hdtv_capture.sh"
LOCAL_SCRIPT="$REPO_ROOT/TestSetupTesting/run_coordinated_hdtv_capture.sh"
OUTPUT_FILE="$(mktemp)"

trap 'rm -f "$OUTPUT_FILE"' EXIT

assert_help_contains() {
    local script_path="$1"
    local expected_text="$2"
    local help_text

    help_text="$(bash "$script_path" --help)"
    grep -F -- "$expected_text" <<< "$help_text" >/dev/null
}

assert_live_notes_required() {
    local script_path="$1"
    local mode_arguments=("${@:2}")
    local exit_status

    set +e
    bash "$script_path" "${mode_arguments[@]}" >"$OUTPUT_FILE" 2>&1
    exit_status=$?
    set -e

    if [[ $exit_status -eq 0 ]]; then
        echo "Expected missing operator setup notes to fail: $script_path" >&2
        return 1
    fi

    grep -F -- "Operator setup notes are required" "$OUTPUT_FILE" >/dev/null
}

assert_help_contains "$TRIGGER_SCRIPT" "--operator-setup-notes"
assert_help_contains "$TRIGGER_SCRIPT" "--antenna-ports"
assert_help_contains "$TRIGGER_SCRIPT" "--channel-roles"
assert_help_contains "$LOCAL_SCRIPT" "--operator-setup-notes"

assert_live_notes_required "$TRIGGER_SCRIPT" --mode live --session-id shell_parser_trigger_test
assert_live_notes_required "$LOCAL_SCRIPT" --session-id shell_parser_local_test

echo "Capture shell parser/help tests passed."
