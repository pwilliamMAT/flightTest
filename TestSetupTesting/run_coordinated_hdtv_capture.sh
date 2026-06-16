#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PI_USER="pi2"
PI_HOST="192.168.10.131"
PI_WORKDIR="/home/pi2/flightTest/ADSB_GPS"
PI_LOGGER_SCRIPT="/home/pi2/flightTest/ADSB_GPS/gatherTCPcompress.py"
SSH_BIN="ssh"
SCP_BIN="scp"
MATLAB_BIN="matlab"
ANNOUNCE_HOST=""
ANNOUNCE_USER=""

CAPTURE_DURATION_S="30"
REPETITIONS="1"
REPETITION_SPACING_S="1.0"
LEAD_SECONDS_S="15"
TAIL_SECONDS_S="5"
CAPTURE_FILE="n320_hdtv_capture"
GAIN_SPEC="30,50"
SESSION_ID="$(date +%Y%m%dT%H%M%S)"
ADSB_STAGE_DIR="$REPO_ROOT/adsb_capture"
SESSION_ROOT="$REPO_ROOT/captures"
REMOTE_WAIT_TIMEOUT_S="60"
REMOTE_POLL_PERIOD_S="2"

RADIO_NAME="My USRP N320"
CENTER_FREQUENCY_HZ="540000000"
SAMPLE_RATE_HZ="6144000"
LO_OFFSET_HZ="200000"

SSH_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SCP_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

REMOTE_LOGGER_STARTED=0
SESSION_ID_REGEX=""
ADSB_TARGET_WINDOW_S="0.0"
RADAR_ACTIVE_WINDOW_S="0.0"
ADSB_START_WALLCLOCK_S=""
ADSB_STOP_WALLCLOCK_S=""
ADSB_ACTUAL_RUN_SECONDS_S=""

usage() {
    cat <<EOF
Usage: bash TestSetupTesting/run_coordinated_hdtv_capture.sh [options]

Options:
  --pi-host <host>                 Raspberry Pi host or IP (default: 192.168.10.131)
  --pi-user <user>                 Raspberry Pi SSH user (default: pi2)
  --capture-duration <seconds>     Local SDR capture duration per repetition (default: 30)
  --repetitions <count>            Number of local SDR repetitions/files (default: 1)
  --repetition-spacing <seconds>   Gap between repetitions (default: 1.0)
  --center-frequency <hz>          Local SDR center frequency in Hz (default: 540000000)
  --lo-offset <hz>                 Local SDR LO offset in Hz (default: 200000)
  --lead-seconds <seconds>         ADS-B lead time before SDR capture (default: 15)
  --tail-seconds <seconds>         ADS-B tail time after SDR capture (default: 5)
  --capture-file <base>            Base name for local SDR files (default: n320_hdtv_capture)
  --gain <g>                       Gain as N or N,M (default: 30,50)
  --session-id <id>                Shared session ID (default: current timestamp)
  --announce-host <host>           Hostname/IP to print in the development-machine sync command
  --adsb-stage-dir <path>          Local staging folder for fetched ADS-B files
  --session-root <path>            Root folder for packaged session outputs
  --matlab-bin <path>              MATLAB executable (default: matlab)
  --ssh-bin <path>                 SSH executable (default: ssh)
  --scp-bin <path>                 SCP executable (default: scp)
  --remote-wait-timeout <seconds>  Max wait for Pi logger to stop after shutdown request (default: 60)
  --remote-poll-period <seconds>   Polling period while waiting for Pi logger (default: 2)
  -h, --help                       Show this help text
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

quote_posix_arg() {
    printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\"'\"'/g")"
}

quote_matlab_string() {
    printf "'%s'" "$(printf "%s" "$1" | sed "s/'/''/g")"
}

sum_seconds() {
    awk -v a="$1" -v b="$2" -v c="$3" 'BEGIN { printf "%.1f", a + b + c }'
}

diff_seconds() {
    awk -v start="$1" -v finish="$2" 'BEGIN { printf "%.1f", finish - start }'
}

product_seconds() {
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.1f", a * b }'
}

capture_window_seconds() {
    awk -v dur="$1" -v reps="$2" -v gap="$3" 'BEGIN { printf "%.1f", reps * dur + ((reps > 1) ? (reps - 1) * gap : 0) }'
}

is_nonnegative_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

validate_nonnegative_number() {
    local label="$1"
    local value="$2"
    if ! is_nonnegative_number "$value"; then
        die "$label must be a nonnegative number."
    fi
}

validate_positive_number() {
    local label="$1"
    local value="$2"
    validate_nonnegative_number "$label" "$value"
    if awk -v x="$value" 'BEGIN { exit !(x > 0) }'; then
        return
    fi
    die "$label must be greater than zero."
}

validate_positive_integer() {
    local label="$1"
    local value="$2"

    if [[ ! "$value" =~ ^[0-9]+$ ]] || ! ((10#$value > 0)); then
        die "$label must be a positive integer."
    fi
}

normalize_gain_spec() {
    local raw="$1"
    raw="${raw// /,}"
    while [[ "$raw" == *",,"* ]]; do
        raw="${raw//,,/,}"
    done
    raw="${raw#,}"
    raw="${raw%,}"
    printf "%s" "$raw"
}

gain_to_matlab_expr() {
    local normalized
    local parts
    local count

    normalized="$(normalize_gain_spec "$1")"
    IFS=',' read -r -a parts <<< "$normalized"
    count=0

    for part in "${parts[@]}"; do
        [[ -n "$part" ]] || continue
        count=$((count + 1))
        if [[ $count -gt 2 ]]; then
            die "Gain must be a scalar or two comma-separated values, for example 30 or 30,50."
        fi
        if [[ ! "$part" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
            die "Gain value '$part' is not numeric."
        fi
    done

    if [[ $count -eq 0 ]]; then
        die "Gain must not be empty."
    fi

    if [[ $count -eq 1 ]]; then
        printf "%s" "${parts[0]}"
        return
    fi

    printf "[%s %s]" "${parts[0]}" "${parts[1]}"
}

run_ssh_body() {
    local remote_body="$1"
    "$SSH_BIN" "${SSH_OPTIONS[@]}" "$PI_USER@$PI_HOST" "bash -lc $(quote_posix_arg "$remote_body")"
}

remote_logger_pattern() {
    printf "%s" "gatherTCPcompress.py.*${SESSION_ID_REGEX}"
}

remote_logger_running() {
    local output
    local status
    local remote_body

    remote_body="pgrep -f $(quote_posix_arg "$(remote_logger_pattern)") >/dev/null && printf RUNNING || printf STOPPED"

    set +e
    output="$(run_ssh_body "$remote_body" 2>/dev/null)"
    status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        printf "STOPPED"
        return
    fi

    printf "%s" "$output"
}

signal_remote_logger() {
    local signal_name="${1:-INT}"
    local remote_body

    remote_body="pids=\$(pgrep -f $(quote_posix_arg "$(remote_logger_pattern)") || true); if [[ -z \"\$pids\" ]]; then printf STOPPED; else kill -s $signal_name \$pids && printf SIGNALED; fi"
    run_ssh_body "$remote_body"
}

wait_for_remote_logger() {
    local deadline
    local state

    deadline=$((SECONDS + ${REMOTE_WAIT_TIMEOUT_S%.*}))
    while true; do
        state="$(remote_logger_running)"
        if [[ "$state" == "STOPPED" ]]; then
            return 0
        fi

        if (( SECONDS >= deadline )); then
            return 1
        fi

        sleep "$REMOTE_POLL_PERIOD_S"
    done
}

list_remote_adsb_files() {
    local remote_body

    remote_body="
remote_log=$(quote_posix_arg "$REMOTE_LOG_FILE")
pi_workdir=$(quote_posix_arg "$PI_WORKDIR")
session_glob=$(quote_posix_arg "*adsb_${SESSION_ID}*.txt.gz")
declare -a hits=()

if [[ -f \$remote_log ]]; then
    while IFS= read -r artifact; do
        [[ -n \$artifact ]] || continue
        [[ \$artifact == '(none)' ]] && continue
        if [[ \$artifact != /* ]]; then
            artifact=\"\$pi_workdir/\$artifact\"
        fi
        if [[ -f \$artifact ]]; then
            hits+=(\"\$artifact\")
        fi
    done < <(sed -n 's/^[[:space:]]*final artifact[[:space:]]*:[[:space:]]*//p' \"\$remote_log\")
fi

if [[ \${#hits[@]} -eq 0 ]]; then
    while IFS= read -r path; do
        [[ -n \$path ]] || continue
        hits+=(\"\$path\")
    done < <(find \"\$pi_workdir\" -maxdepth 1 -type f -name \"\$session_glob\" -print | sort)
fi

if [[ \${#hits[@]} -eq 0 ]]; then
    while IFS= read -r path; do
        [[ -n \$path ]] || continue
        hits+=(\"\$path\")
    done < <(find \"\$HOME\" -maxdepth 4 -type f -name \"\$session_glob\" -print | sort)
fi

if [[ \${#hits[@]} -gt 0 ]]; then
    printf '%s\n' \"\${hits[@]}\" | awk '!seen[\$0]++'
fi
"
    run_ssh_body "$remote_body"
}

cleanup_remote_logger_on_exit() {
    local exit_code=$?
    local remote_state=""
    trap - EXIT

    if [[ $REMOTE_LOGGER_STARTED -eq 1 ]]; then
        set +e
        remote_state="$(remote_logger_running)"
        if [[ "$remote_state" == "RUNNING" ]]; then
            echo "Cleanup: stopping remote ADS-B logger for session $SESSION_ID ..."
            signal_remote_logger TERM >/dev/null 2>&1
            wait_for_remote_logger >/dev/null 2>&1
        fi
        set -e
    fi

    exit "$exit_code"
}

trap cleanup_remote_logger_on_exit EXIT

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf "%s" "$value"
}

write_json_array() {
    local item
    local sep=""

    printf "["
    for item in "$@"; do
        printf '%s"%s"' "$sep" "$(json_escape "$item")"
        sep=", "
    done
    printf "]"
}

append_if_exists() {
    local path="$1"
    local -n target_array="$2"
    if [[ -f "$path" ]]; then
        target_array+=("$path")
    fi
}

resolve_local_user() {
    local resolved=""

    if [[ -n "${USER:-}" ]]; then
        printf "%s" "$USER"
        return 0
    fi

    if resolved="$(id -un 2>/dev/null)" && [[ -n "$resolved" ]]; then
        printf "%s" "$resolved"
        return 0
    fi

    if resolved="$(whoami 2>/dev/null)" && [[ -n "$resolved" ]]; then
        printf "%s" "$resolved"
        return 0
    fi

    return 1
}

resolve_announce_host() {
    local resolved=""

    if [[ -n "$ANNOUNCE_HOST" ]]; then
        printf "%s" "$ANNOUNCE_HOST"
        return 0
    fi

    if resolved="$(hostname -f 2>/dev/null)" && [[ -n "$resolved" ]]; then
        printf "%s" "$resolved"
        return 0
    fi

    if resolved="$(hostname 2>/dev/null)" && [[ -n "$resolved" ]]; then
        printf "%s" "$resolved"
        return 0
    fi

    return 1
}

print_development_handoff() {
    local sync_cmd=""

    sync_cmd+="bash TestSetupTesting/sync_capture_session.sh"
    sync_cmd+=" --host $(printf '%q' "$ANNOUNCE_HOST")"
    sync_cmd+=" --user $(printf '%q' "$ANNOUNCE_USER")"
    sync_cmd+=" --session-id $(printf '%q' "$SESSION_ID")"
    sync_cmd+=" --remote-root $(printf '%q' "$SESSION_ROOT")"
    sync_cmd+=" --ask-analysis"

    printf "\nNext on the development machine (run from the repo root):\n"
    printf "  %s\n" "$sync_cmd"
    printf "Manual MATLAB analysis after sync:\n"
    printf "  cd BistaticDataAnalysis\n"
    printf "  out = runBistaticAnalysisSession(%s);\n" "$(quote_matlab_string "$SESSION_ID")"

    if [[ "$ANNOUNCE_HOST" == "<testing-machine>" || "$ANNOUNCE_USER" == "<testing-user>" ]]; then
        printf "Review the printed host/user placeholders before running the sync command.\n"
    fi
}

fallback_find_capture_files() {
    find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*${SESSION_ID}*" \
        ! -name '*.m' ! -name '*.asv' ! -name '*.sh' ! -name '*.py' ! -name '*.log' \
        ! -name '*.txt' ! -name '*.txt.gz' ! -name '*.json' | sort
}

move_into_subdir() {
    local src_path="$1"
    local dest_dir="$2"
    local rel_prefix="$3"
    local dest_path

    mkdir -p "$dest_dir"
    dest_path="$dest_dir/$(basename "$src_path")"
    mv -f "$src_path" "$dest_path"
    printf "%s/%s" "$rel_prefix" "$(basename "$dest_path")"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pi-host)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            PI_HOST="$2"
            shift 2
            ;;
        --pi-user)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            PI_USER="$2"
            shift 2
            ;;
        --capture-duration)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            CAPTURE_DURATION_S="$2"
            shift 2
            ;;
        --repetitions)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REPETITIONS="$2"
            shift 2
            ;;
        --repetition-spacing)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REPETITION_SPACING_S="$2"
            shift 2
            ;;
        --center-frequency)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            CENTER_FREQUENCY_HZ="$2"
            shift 2
            ;;
        --lo-offset)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            LO_OFFSET_HZ="$2"
            shift 2
            ;;
        --lead-seconds)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            LEAD_SECONDS_S="$2"
            shift 2
            ;;
        --tail-seconds)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            TAIL_SECONDS_S="$2"
            shift 2
            ;;
        --capture-file)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            CAPTURE_FILE="$2"
            shift 2
            ;;
        --gain)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            GAIN_SPEC="$2"
            shift 2
            ;;
        --session-id)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SESSION_ID="$2"
            shift 2
            ;;
        --announce-host)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            ANNOUNCE_HOST="$2"
            shift 2
            ;;
        --adsb-stage-dir)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            ADSB_STAGE_DIR="$2"
            shift 2
            ;;
        --session-root)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SESSION_ROOT="$2"
            shift 2
            ;;
        --matlab-bin)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            MATLAB_BIN="$2"
            shift 2
            ;;
        --ssh-bin)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SSH_BIN="$2"
            shift 2
            ;;
        --scp-bin)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SCP_BIN="$2"
            shift 2
            ;;
        --remote-wait-timeout)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REMOTE_WAIT_TIMEOUT_S="$2"
            shift 2
            ;;
        --remote-poll-period)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REMOTE_POLL_PERIOD_S="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

validate_positive_number "capture duration" "$CAPTURE_DURATION_S"
validate_positive_integer "repetitions" "$REPETITIONS"
validate_nonnegative_number "repetition spacing" "$REPETITION_SPACING_S"
validate_positive_number "center frequency" "$CENTER_FREQUENCY_HZ"
validate_nonnegative_number "LO offset" "$LO_OFFSET_HZ"
validate_nonnegative_number "lead seconds" "$LEAD_SECONDS_S"
validate_nonnegative_number "tail seconds" "$TAIL_SECONDS_S"
validate_nonnegative_number "remote wait timeout" "$REMOTE_WAIT_TIMEOUT_S"
validate_positive_number "remote poll period" "$REMOTE_POLL_PERIOD_S"

ANNOUNCE_USER="$(resolve_local_user || true)"
ANNOUNCE_HOST="$(resolve_announce_host || true)"
[[ -n "$ANNOUNCE_USER" ]] || ANNOUNCE_USER="<testing-user>"
[[ -n "$ANNOUNCE_HOST" ]] || ANNOUNCE_HOST="<testing-machine>"

SESSION_ID_REGEX="$(printf "%s" "$SESSION_ID" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g')"
RADAR_ACTIVE_WINDOW_S="$(capture_window_seconds "$CAPTURE_DURATION_S" "$REPETITIONS" "$REPETITION_SPACING_S")"
TOTAL_RADAR_CAPTURE_S="$(product_seconds "$CAPTURE_DURATION_S" "$REPETITIONS")"
ADSB_TARGET_WINDOW_S="$(sum_seconds "$LEAD_SECONDS_S" "$RADAR_ACTIVE_WINDOW_S" "$TAIL_SECONDS_S")"
MATLAB_GAIN_EXPR="$(gain_to_matlab_expr "$GAIN_SPEC")"
REMOTE_LOG_FILE="$PI_WORKDIR/adsb_capture_${SESSION_ID}.log"

MATLAB_STATUS=0
FETCH_STATUS=0
REMOTE_WAIT_STATUS=0
REMOTE_LOG_STATUS=0

capture_files=()
staged_adsb_files=()
packaged_radar_files=()
packaged_adsb_files=()
packaged_log_files=()

SESSION_DIR="$SESSION_ROOT/$SESSION_ID"
RADAR_DIR="$SESSION_DIR/radar"
TRUTH_DIR="$SESSION_DIR/truth"
LOG_DIR="$SESSION_DIR/logs"
MANIFEST_PATH="$SESSION_DIR/session_manifest.json"

MATLAB_OUTPUT_LOG="$(mktemp "${TMPDIR:-/tmp}/flighttest_capture_${SESSION_ID}_XXXX.log")"
LOCAL_REMOTE_LOG="$LOG_DIR/adsb_capture_${SESSION_ID}.log"
REPORTED_RECORDING_UTC=""

echo "Preflight: verifying non-interactive SSH access to $PI_USER@$PI_HOST ..."
set +e
probe_output="$(run_ssh_body "cd $(quote_posix_arg "$PI_WORKDIR") && test -f $(quote_posix_arg "$PI_LOGGER_SCRIPT") && command -v python3 >/dev/null 2>&1 && printf READY")"
probe_status=$?
set -e
if [[ $probe_status -ne 0 || "$probe_output" != "READY" ]]; then
    die "SSH preflight failed. Verify key-based SSH access and that $PI_LOGGER_SCRIPT exists on the Pi."
fi

echo "[1/5] Starting ADS-B logger on $PI_USER@$PI_HOST until the SDR capture completes ..."
remote_logger_body="cd $(quote_posix_arg "$PI_WORKDIR") && exec python3 $(quote_posix_arg "$PI_LOGGER_SCRIPT") --session-id $(quote_posix_arg "$SESSION_ID") > $(quote_posix_arg "$REMOTE_LOG_FILE") 2>&1 < /dev/null"
remote_start_body="cd $(quote_posix_arg "$PI_WORKDIR") && if command -v setsid >/dev/null 2>&1; then setsid -f bash -lc $(quote_posix_arg "$remote_logger_body"); else nohup bash -lc $(quote_posix_arg "$remote_logger_body") >/dev/null 2>&1 & fi; printf STARTED"
set +e
start_output="$(run_ssh_body "$remote_start_body")"
start_status=$?
set -e
if [[ $start_status -ne 0 || "$start_output" != *"STARTED"* ]]; then
    die "Could not start gatherTCPcompress.py on the Pi. Check $REMOTE_LOG_FILE after a manual start attempt."
fi
REMOTE_LOGGER_STARTED=1
ADSB_START_WALLCLOCK_S="$(date +%s.%N)"

echo "[2/5] Waiting $LEAD_SECONDS_S s before the local SDR capture ..."
sleep "$LEAD_SECONDS_S"

echo "[3/5] Running local SDR capture: $REPETITIONS repetition(s) x $CAPTURE_DURATION_S s with $REPETITION_SPACING_S s spacing (active window $RADAR_ACTIVE_WINDOW_S s, recorded IQ $TOTAL_RADAR_CAPTURE_S s, session $SESSION_ID) ..."
matlab_cmd="cd($(quote_matlab_string "$SCRIPT_DIR")); info = runLocalHDTVCapture('SessionID', $(quote_matlab_string "$SESSION_ID"), 'CaptureDuration_s', $CAPTURE_DURATION_S, 'CaptureFile', $(quote_matlab_string "$CAPTURE_FILE"), 'CenterFrequency_Hz', $CENTER_FREQUENCY_HZ, 'LOOffset_Hz', $LO_OFFSET_HZ, 'Gain', $MATLAB_GAIN_EXPR, 'Repetitions', $REPETITIONS, 'RepetitionSpacing_s', $REPETITION_SPACING_S);"
set +e
"$MATLAB_BIN" -batch "$matlab_cmd" > >(tee "$MATLAB_OUTPUT_LOG") 2>&1
MATLAB_STATUS=$?
set -e

while IFS= read -r line; do
    capture_files+=("${line#*=}")
done < <(grep '^CAPTURE_FILE_' "$MATLAB_OUTPUT_LOG" || true)

reported_session_id="$(grep '^CAPTURE_SESSION_ID=' "$MATLAB_OUTPUT_LOG" | tail -n 1 | cut -d= -f2- || true)"
REPORTED_RECORDING_UTC="$(grep '^CAPTURE_RECORDING_UTC=' "$MATLAB_OUTPUT_LOG" | tail -n 1 | cut -d= -f2- || true)"

if [[ -n "$reported_session_id" && "$reported_session_id" != "$SESSION_ID" ]]; then
    echo "Warning: MATLAB reported session $reported_session_id but the coordinator requested $SESSION_ID." >&2
fi

if [[ ${#capture_files[@]} -eq 0 ]]; then
    mapfile -t capture_files < <(fallback_find_capture_files)
fi

if [[ $MATLAB_STATUS -ne 0 ]]; then
    echo "Warning: local MATLAB SDR capture failed with status $MATLAB_STATUS." >&2
fi

echo "[4/5] Waiting for ADS-B tail coverage, then stopping the Pi logger ..."
sleep "$TAIL_SECONDS_S"
set +e
stop_output="$(signal_remote_logger INT 2>/dev/null)"
stop_status=$?
set -e
if [[ $stop_status -ne 0 ]]; then
    REMOTE_WAIT_STATUS=1
    echo "Warning: failed to send a graceful stop request to the Pi ADS-B logger." >&2
else
    if ! wait_for_remote_logger; then
        echo "Warning: Pi ADS-B logger did not stop after SIGINT; retrying with SIGTERM." >&2
        set +e
        term_output="$(signal_remote_logger TERM 2>/dev/null)"
        term_status=$?
        set -e
        if [[ $term_status -ne 0 || "$term_output" == "STOPPED" ]]; then
            :
        fi
        if ! wait_for_remote_logger; then
            REMOTE_WAIT_STATUS=1
            echo "Warning: Pi ADS-B logger still appears to be running after $REMOTE_WAIT_TIMEOUT_S s." >&2
        fi
    fi
fi
ADSB_STOP_WALLCLOCK_S="$(date +%s.%N)"
if [[ -n "$ADSB_START_WALLCLOCK_S" && -n "$ADSB_STOP_WALLCLOCK_S" ]]; then
    ADSB_ACTUAL_RUN_SECONDS_S="$(diff_seconds "$ADSB_START_WALLCLOCK_S" "$ADSB_STOP_WALLCLOCK_S")"
fi

echo "[5/5] Fetching ADS-B outputs and packaging session $SESSION_ID ..."
mkdir -p "$ADSB_STAGE_DIR" "$RADAR_DIR" "$TRUTH_DIR" "$LOG_DIR"

mapfile -t remote_files < <(list_remote_adsb_files)
if [[ ${#remote_files[@]} -eq 0 ]]; then
    FETCH_STATUS=1
    echo "Warning: no remote ADS-B files matched session $SESSION_ID under $PI_WORKDIR, and no final artifact was recovered from $REMOTE_LOG_FILE." >&2
else
    echo "Found ${#remote_files[@]} remote ADS-B artifact(s) for session $SESSION_ID."
    for remote_file in "${remote_files[@]}"; do
        local_stage_path="$ADSB_STAGE_DIR/$(basename "$remote_file")"
        set +e
        "$SCP_BIN" "${SCP_OPTIONS[@]}" "$PI_USER@$PI_HOST:$remote_file" "$ADSB_STAGE_DIR/"
        scp_status=$?
        set -e
        if [[ $scp_status -ne 0 ]]; then
            FETCH_STATUS=1
            echo "Warning: failed to copy $remote_file from the Pi." >&2
            continue
        fi
        append_if_exists "$local_stage_path" staged_adsb_files
    done
fi

set +e
"$SCP_BIN" "${SCP_OPTIONS[@]}" "$PI_USER@$PI_HOST:$REMOTE_LOG_FILE" "$LOG_DIR/"
remote_log_copy_status=$?
set -e
if [[ $remote_log_copy_status -ne 0 ]]; then
    REMOTE_LOG_STATUS=1
    echo "Warning: failed to copy remote Pi log $REMOTE_LOG_FILE." >&2
fi

for capture_file in "${capture_files[@]}"; do
    if [[ ! -f "$capture_file" ]]; then
        echo "Warning: local capture file not found for packaging: $capture_file" >&2
        continue
    fi
    packaged_radar_files+=("$(move_into_subdir "$capture_file" "$RADAR_DIR" "radar")")
done

for staged_adsb in "${staged_adsb_files[@]}"; do
    if [[ ! -f "$staged_adsb" ]]; then
        echo "Warning: staged ADS-B file not found for packaging: $staged_adsb" >&2
        continue
    fi
    packaged_adsb_files+=("$(move_into_subdir "$staged_adsb" "$TRUTH_DIR" "truth")")
done

local_matlab_log_rel="$(move_into_subdir "$MATLAB_OUTPUT_LOG" "$LOG_DIR" "logs")"
packaged_log_files+=("$local_matlab_log_rel")

if [[ -f "$LOCAL_REMOTE_LOG" ]]; then
    packaged_log_files+=("logs/$(basename "$LOCAL_REMOTE_LOG")")
fi

if [[ ${#packaged_adsb_files[@]} -eq 0 ]]; then
    echo "Warning: no ADS-B truth files were packaged for session $SESSION_ID. Review the Pi log $REMOTE_LOG_FILE and the copied session logs before syncing to the development machine." >&2
fi

if [[ ${#packaged_radar_files[@]} -eq 0 ]]; then
    echo "Error: no radar files were packaged for session $SESSION_ID. The session manifest was not written." >&2
    if [[ $MATLAB_STATUS -ne 0 ]]; then
        exit "$MATLAB_STATUS"
    fi
    exit 1
fi

{
    printf "{\n"
    printf '  "manifest_version": 1,\n'
    printf '  "session_id": "%s",\n' "$(json_escape "$SESSION_ID")"
    printf '  "session_folder": "%s",\n' "$(json_escape "$SESSION_ID")"
    printf '  "session_created_utc": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "capture_duration_s": %s,\n' "$CAPTURE_DURATION_S"
    printf '  "capture_repetitions": %s,\n' "$REPETITIONS"
    printf '  "capture_repetition_spacing_s": %s,\n' "$REPETITION_SPACING_S"
    printf '  "radar_active_window_s": %s,\n' "$RADAR_ACTIVE_WINDOW_S"
    printf '  "radar_recorded_iq_seconds_s": %s,\n' "$TOTAL_RADAR_CAPTURE_S"
    printf '  "lead_seconds_s": %s,\n' "$LEAD_SECONDS_S"
    printf '  "tail_seconds_s": %s,\n' "$TAIL_SECONDS_S"
    printf '  "adsb_target_window_s": %s,\n' "$ADSB_TARGET_WINDOW_S"
    if [[ -n "$ADSB_ACTUAL_RUN_SECONDS_S" ]]; then
        printf '  "adsb_run_seconds_s": %s,\n' "$ADSB_ACTUAL_RUN_SECONDS_S"
    else
        printf '  "adsb_run_seconds_s": null,\n'
    fi
    printf '  "adsb_stop_mode": "signal_after_capture",\n'
    printf '  "capture_file_base": "%s",\n' "$(json_escape "$CAPTURE_FILE")"
    printf '  "gain_spec": "%s",\n' "$(json_escape "$(normalize_gain_spec "$GAIN_SPEC")")"
    printf '  "pi_host": "%s",\n' "$(json_escape "$PI_HOST")"
    printf '  "pi_user": "%s",\n' "$(json_escape "$PI_USER")"
    printf '  "remote_log_file": "%s",\n' "$(json_escape "$REMOTE_LOG_FILE")"
    if [[ -n "$REPORTED_RECORDING_UTC" ]]; then
        printf '  "radar_epoch_utc": %s,\n' "$REPORTED_RECORDING_UTC"
    else
        printf '  "radar_epoch_utc": null,\n'
    fi
    printf '  "sdr_defaults": {\n'
    printf '    "radio_name": "%s",\n' "$(json_escape "$RADIO_NAME")"
    printf '    "center_frequency_hz": %s,\n' "$CENTER_FREQUENCY_HZ"
    printf '    "sample_rate_hz": %s,\n' "$SAMPLE_RATE_HZ"
    printf '    "lo_offset_hz": %s\n' "$LO_OFFSET_HZ"
    printf '  },\n'
    printf '  "radar_files": %s,\n' "$(write_json_array "${packaged_radar_files[@]}")"
    printf '  "adsb_files": %s,\n' "$(write_json_array "${packaged_adsb_files[@]}")"
    printf '  "log_files": %s\n' "$(write_json_array "${packaged_log_files[@]}")"
    printf "}\n"
} > "$MANIFEST_PATH"

echo "SESSION_ID=$SESSION_ID"
echo "SESSION_DIR=$SESSION_DIR"
echo "SESSION_MANIFEST=$MANIFEST_PATH"
echo "REMOTE_LOG_FILE=$REMOTE_LOG_FILE"
print_development_handoff

if [[ $MATLAB_STATUS -ne 0 ]]; then
    exit "$MATLAB_STATUS"
fi
if [[ $REMOTE_WAIT_STATUS -ne 0 || $FETCH_STATUS -ne 0 || $REMOTE_LOG_STATUS -ne 0 ]]; then
    exit 1
fi

echo "Coordinated capture complete."
