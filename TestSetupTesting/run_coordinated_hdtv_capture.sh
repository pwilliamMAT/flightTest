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

CAPTURE_DURATION_S="30"
LEAD_SECONDS_S="15"
TAIL_SECONDS_S="5"
CAPTURE_FILE="n320_hdtv_capture"
GAIN_SPEC="30,50"
SESSION_ID="$(date +%Y%m%dT%H%M%S)"
ADSB_DIR="$REPO_ROOT/adsb_capture"
REMOTE_WAIT_TIMEOUT_S="60"
REMOTE_POLL_PERIOD_S="2"

SSH_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SCP_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

usage() {
    cat <<EOF
Usage: bash TestSetupTesting/run_coordinated_hdtv_capture.sh [options]

Options:
  --pi-host <host>                 Raspberry Pi host or IP (default: 192.168.10.131)
  --pi-user <user>                 Raspberry Pi SSH user (default: pi2)
  --capture-duration <seconds>     Local SDR capture duration (default: 30)
  --lead-seconds <seconds>         ADS-B lead time before SDR capture (default: 15)
  --tail-seconds <seconds>         ADS-B tail time after SDR capture (default: 5)
  --capture-file <base>            Base name for local SDR files (default: n320_hdtv_capture)
  --gain <g>                       Gain as N or N,M (default: 30,50)
  --session-id <id>                Shared session ID (default: current timestamp)
  --adsb-dir <path>                Local folder for copied ADS-B files
  --matlab-bin <path>              MATLAB executable (default: matlab)
  --ssh-bin <path>                 SSH executable (default: ssh)
  --scp-bin <path>                 SCP executable (default: scp)
  --remote-wait-timeout <seconds>  Max wait for Pi logger to stop (default: 60)
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

remote_logger_running() {
    local output
    local status
    local remote_body

    remote_body="pgrep -f $(quote_posix_arg "gatherTCPcompress.py.*$SESSION_ID") >/dev/null && printf RUNNING || printf STOPPED"

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

    remote_body="find $(quote_posix_arg "$PI_WORKDIR") -maxdepth 1 -type f -name $(quote_posix_arg "*adsb_${SESSION_ID}*.txt.gz") -printf '%p\n' | sort"
    run_ssh_body "$remote_body"
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
        --adsb-dir)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            ADSB_DIR="$2"
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
validate_nonnegative_number "lead seconds" "$LEAD_SECONDS_S"
validate_nonnegative_number "tail seconds" "$TAIL_SECONDS_S"
validate_nonnegative_number "remote wait timeout" "$REMOTE_WAIT_TIMEOUT_S"
validate_positive_number "remote poll period" "$REMOTE_POLL_PERIOD_S"

ADSB_RUN_SECONDS_S="$(sum_seconds "$LEAD_SECONDS_S" "$CAPTURE_DURATION_S" "$TAIL_SECONDS_S")"
MATLAB_GAIN_EXPR="$(gain_to_matlab_expr "$GAIN_SPEC")"
REMOTE_LOG_FILE="$PI_WORKDIR/adsb_capture_${SESSION_ID}.log"
MATLAB_STATUS=0
FETCH_STATUS=0
REMOTE_WAIT_STATUS=0

echo "Preflight: verifying non-interactive SSH access to $PI_USER@$PI_HOST ..."
set +e
probe_output="$(run_ssh_body "cd $(quote_posix_arg "$PI_WORKDIR") && test -f $(quote_posix_arg "$PI_LOGGER_SCRIPT") && command -v python3 >/dev/null 2>&1 && printf READY")"
probe_status=$?
set -e
if [[ $probe_status -ne 0 || "$probe_output" != "READY" ]]; then
    die "SSH preflight failed. Verify key-based SSH access and that $PI_LOGGER_SCRIPT exists on the Pi."
fi

echo "[1/5] Starting ADS-B logger on $PI_USER@$PI_HOST for $ADSB_RUN_SECONDS_S s ..."
remote_logger_body="exec python3 $(quote_posix_arg "$PI_LOGGER_SCRIPT") --session-id $(quote_posix_arg "$SESSION_ID") --run-seconds $(quote_posix_arg "$ADSB_RUN_SECONDS_S") > $(quote_posix_arg "$REMOTE_LOG_FILE") 2>&1 < /dev/null"
remote_start_body="cd $(quote_posix_arg "$PI_WORKDIR") && if command -v setsid >/dev/null 2>&1; then setsid -f bash -lc $(quote_posix_arg "$remote_logger_body"); else nohup bash -lc $(quote_posix_arg "$remote_logger_body") >/dev/null 2>&1 & fi; printf STARTED"
set +e
start_output="$(run_ssh_body "$remote_start_body")"
start_status=$?
set -e
if [[ $start_status -ne 0 || "$start_output" != *"STARTED"* ]]; then
    die "Could not start gatherTCPcompress.py on the Pi. Check $REMOTE_LOG_FILE after a manual start attempt."
fi

echo "[2/5] Waiting $LEAD_SECONDS_S s before the local SDR capture ..."
sleep "$LEAD_SECONDS_S"

echo "[3/5] Running local SDR capture for $CAPTURE_DURATION_S s (session $SESSION_ID) ..."
matlab_cmd="cd($(quote_matlab_string "$SCRIPT_DIR")); info = runLocalHDTVCapture('SessionID', $(quote_matlab_string "$SESSION_ID"), 'CaptureDuration_s', $CAPTURE_DURATION_S, 'CaptureFile', $(quote_matlab_string "$CAPTURE_FILE"), 'Gain', $MATLAB_GAIN_EXPR);"
set +e
"$MATLAB_BIN" -batch "$matlab_cmd"
MATLAB_STATUS=$?
set -e
if [[ $MATLAB_STATUS -ne 0 ]]; then
    echo "Warning: local MATLAB SDR capture failed with status $MATLAB_STATUS." >&2
fi

echo "[4/5] Waiting for ADS-B tail coverage and Pi logger shutdown ..."
sleep "$TAIL_SECONDS_S"
if ! wait_for_remote_logger; then
    REMOTE_WAIT_STATUS=1
    echo "Warning: Pi ADS-B logger still appears to be running after $REMOTE_WAIT_TIMEOUT_S s." >&2
fi

echo "[5/5] Copying ADS-B files for session $SESSION_ID ..."
mkdir -p "$ADSB_DIR"
mapfile -t remote_files < <(list_remote_adsb_files)
if [[ ${#remote_files[@]} -eq 0 ]]; then
    FETCH_STATUS=1
    echo "Warning: no remote ADS-B files matched session $SESSION_ID." >&2
else
    for remote_file in "${remote_files[@]}"; do
        set +e
        "$SCP_BIN" "${SCP_OPTIONS[@]}" "$PI_USER@$PI_HOST:$remote_file" "$ADSB_DIR/"
        scp_status=$?
        set -e
        if [[ $scp_status -ne 0 ]]; then
            FETCH_STATUS=1
            echo "Warning: failed to copy $remote_file from the Pi." >&2
        fi
    done
fi

echo "SESSION_ID=$SESSION_ID"
echo "REMOTE_LOG_FILE=$REMOTE_LOG_FILE"
echo "LOCAL_ADSB_DIR=$ADSB_DIR"

if [[ $MATLAB_STATUS -ne 0 ]]; then
    exit "$MATLAB_STATUS"
fi
if [[ $REMOTE_WAIT_STATUS -ne 0 || $FETCH_STATUS -ne 0 ]]; then
    exit 1
fi

echo "Coordinated capture complete."
