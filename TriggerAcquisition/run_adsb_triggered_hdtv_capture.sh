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
PREFLIGHT_ONLY=0

MODE="shadow"
OPPORTUNITY_POLICY="single"
WATCH_TIMEOUT_S="600"
POLL_PERIOD_S="5"
ADSB_ROTATION_S="5"
TAIL_SECONDS_S="5"
CAPTURE_DURATION_S="30"
CAPTURE_FILE="n320_hdtv_capture"
GAIN_SPEC="30,50"
SESSION_ID="$(date -u +%Y%m%dT%H%M%S)"
SESSION_ROOT="$REPO_ROOT/captures"
ADSB_STAGE_DIR=""
CONTROL_DIR=""
REFERENCE_CHAIN_PENALTY_DB="NaN"
REMOTE_WAIT_TIMEOUT_S="60"
FETCH_POLL_S="2"

RADIO_NAME="My USRP N320"
CENTER_FREQUENCY_HZ="540000000"
SAMPLE_RATE_HZ="6144000"
LO_OFFSET_HZ="200000"
SURVEILLANCE_BORESIGHT_AZIMUTH_DEG="270"
CORRIDOR_AZIMUTH_CENTER_DEG="270"

SSH_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SCP_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

REMOTE_LOGGER_STARTED=0
FETCHER_PID=""
STOP_REQUEST_PATH=""
ADSB_STOPPED_FLAG=""
STATUS_FILE=""
LOCAL_REMOTE_LOG=""
REMOTE_LOG_FILE=""
SESSION_ID_REGEX=""

usage() {
    cat <<EOF
Usage: bash TriggerAcquisition/run_adsb_triggered_hdtv_capture.sh [options]

Options:
  --mode <shadow|live>              Wrapper mode (default: shadow)
  --pi-host <host>                  Raspberry Pi host or IP (default: 192.168.10.131)
  --pi-user <user>                  Raspberry Pi SSH user (default: pi2)
  --watch-timeout <seconds>         Max watch duration before clean timeout (default: 600)
  --poll-period <seconds>           MATLAB poll period for new ADS-B files (default: 5)
  --adsb-rotation <seconds>         Pi ADS-B file rotation period (default: 5)
  --capture-duration <seconds>      Local radar capture duration (default: 30)
  --tail-seconds <seconds>          ADS-B tail after trigger/capture (default: 5)
  --center-frequency <hz>           Local SDR center frequency (default: 540000000)
  --lo-offset <hz>                  Local SDR LO offset (default: 200000)
  --surveillance-boresight-azimuth <deg>
                                     Surveillance boresight azimuth (default: 270)
  --corridor-azimuth-center <deg>   Corridor center azimuth (default: 270)
  --gain <g>                        Gain as N or N,M (default: 30,50)
  --session-id <id>                 Shared session ID (default: current UTC timestamp)
  --session-root <path>             Packaged-session root (default: <repo>/captures)
  --adsb-stage-dir <path>           Local ADS-B staging folder (default: runtime folder)
  --control-dir <path>              Local coordinator control folder (default: runtime folder)
  --reference-chain-penalty <db>    Enables proxy Pd output when finite
  --preflight-only                  Run Pi plus local MATLAB preflight and exit
  --matlab-bin <path>               MATLAB executable (default: matlab)
  --ssh-bin <path>                  SSH executable (default: ssh)
  --scp-bin <path>                  SCP executable (default: scp)
  --remote-wait-timeout <seconds>   Max wait for remote logger stop (default: 60)
  --fetch-poll <seconds>            Local remote-file fetch polling (default: 2)
  -h, --help                        Show this help text
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

is_nonnegative_number() {
    [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

validate_nonnegative_number() {
    local label="$1"
    local value="$2"
    if ! is_nonnegative_number "$value"; then
        die "$label must be numeric."
    fi
    if awk -v x="$value" 'BEGIN { exit !(x >= 0) }'; then
        return
    fi
    die "$label must be nonnegative."
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

validate_number() {
    local label="$1"
    local value="$2"
    if [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        return
    fi
    die "$label must be numeric."
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
    local count=0

    normalized="$(normalize_gain_spec "$1")"
    IFS=',' read -r -a parts <<< "$normalized"
    for part in "${parts[@]}"; do
        [[ -n "$part" ]] || continue
        count=$((count + 1))
        if [[ $count -gt 2 ]]; then
            die "Gain must be a scalar or two comma-separated values."
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

write_status() {
    local status="$1"
    local message="$2"

    cat > "$STATUS_FILE" <<EOF
TIMESTAMP_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATUS=$status
MESSAGE=$message
REMOTE_LOG_LOCAL_PATH=$LOCAL_REMOTE_LOG
ADSB_STAGE_DIR=$ADSB_STAGE_DIR
SESSION_ID=$SESSION_ID
EOF
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
        sleep "$FETCH_POLL_S"
    done
}

list_remote_adsb_files() {
    local remote_body

    remote_body="find $(quote_posix_arg "$PI_WORKDIR") -maxdepth 1 -type f -name $(quote_posix_arg "*adsb_${SESSION_ID}*.txt.gz") -print | sort"
    run_ssh_body "$remote_body"
}

fetch_remote_files_once() {
    local scp_status=0
    local remote_file=""
    local local_path=""

    mapfile -t remote_files < <(list_remote_adsb_files || true)
    for remote_file in "${remote_files[@]}"; do
        [[ -n "$remote_file" ]] || continue
        local_path="$ADSB_STAGE_DIR/$(basename "$remote_file")"
        if [[ -f "$local_path" ]]; then
            continue
        fi
        set +e
        "$SCP_BIN" "${SCP_OPTIONS[@]}" "$PI_USER@$PI_HOST:$remote_file" "$ADSB_STAGE_DIR/"
        scp_status=$?
        set -e
        if [[ $scp_status -ne 0 ]]; then
            return 1
        fi
    done

    return 0
}

copy_remote_log_once() {
    set +e
    "$SCP_BIN" "${SCP_OPTIONS[@]}" "$PI_USER@$PI_HOST:$REMOTE_LOG_FILE" "$LOCAL_REMOTE_LOG" >/dev/null 2>&1
    set -e
}

background_fetch_loop() {
    local warning_count=0

    while true; do
        if ! fetch_remote_files_once; then
            warning_count=$((warning_count + 1))
            write_status "warning" "ADS-B file fetch warning during live watch."
        fi

        if [[ -f "$STOP_REQUEST_PATH" ]]; then
            if [[ "$(remote_logger_running)" == "RUNNING" ]]; then
                signal_remote_logger INT >/dev/null 2>&1 || true
                if ! wait_for_remote_logger; then
                    signal_remote_logger TERM >/dev/null 2>&1 || true
                    if ! wait_for_remote_logger; then
                        warning_count=$((warning_count + 1))
                        write_status "warning" "Remote logger did not stop cleanly within timeout."
                    fi
                fi
            fi

            fetch_remote_files_once || warning_count=$((warning_count + 1))
            copy_remote_log_once || true
            if (( warning_count > 0 )); then
                write_status "stopped_with_warnings" "ADS-B logger stopped and staged with warnings."
            else
                write_status "stopped" "ADS-B logger stopped and fully staged."
            fi
            touch "$ADSB_STOPPED_FLAG"
            return 0
        fi

        if [[ "$(remote_logger_running)" != "RUNNING" ]]; then
            fetch_remote_files_once || warning_count=$((warning_count + 1))
            copy_remote_log_once || true
            write_status "stopped_unexpected" "Remote ADS-B logger stopped before MATLAB requested shutdown."
            touch "$ADSB_STOPPED_FLAG"
            return 0
        fi

        sleep "$FETCH_POLL_S"
    done
}

cleanup_on_exit() {
    local exit_code=$?
    trap - EXIT

    if [[ $REMOTE_LOGGER_STARTED -eq 1 ]]; then
        if [[ ! -f "$STOP_REQUEST_PATH" ]]; then
            printf "STOP_REQUEST_UTC=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STOP_REQUEST_PATH" || true
        fi
        if [[ -n "$FETCHER_PID" ]]; then
            wait "$FETCHER_PID" >/dev/null 2>&1 || true
        else
            signal_remote_logger TERM >/dev/null 2>&1 || true
        fi
    fi

    exit "$exit_code"
}

trap cleanup_on_exit EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            MODE="$2"
            shift 2
            ;;
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
        --watch-timeout)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            WATCH_TIMEOUT_S="$2"
            shift 2
            ;;
        --poll-period)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            POLL_PERIOD_S="$2"
            shift 2
            ;;
        --adsb-rotation)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            ADSB_ROTATION_S="$2"
            shift 2
            ;;
        --capture-duration)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            CAPTURE_DURATION_S="$2"
            shift 2
            ;;
        --tail-seconds)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            TAIL_SECONDS_S="$2"
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
        --surveillance-boresight-azimuth)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SURVEILLANCE_BORESIGHT_AZIMUTH_DEG="$2"
            shift 2
            ;;
        --corridor-azimuth-center)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            CORRIDOR_AZIMUTH_CENTER_DEG="$2"
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
        --session-root)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SESSION_ROOT="$2"
            shift 2
            ;;
        --adsb-stage-dir)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            ADSB_STAGE_DIR="$2"
            shift 2
            ;;
        --control-dir)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            CONTROL_DIR="$2"
            shift 2
            ;;
        --reference-chain-penalty)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REFERENCE_CHAIN_PENALTY_DB="$2"
            shift 2
            ;;
        --preflight-only)
            PREFLIGHT_ONLY=1
            shift
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
        --fetch-poll)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            FETCH_POLL_S="$2"
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

[[ "$MODE" == "shadow" || "$MODE" == "live" ]] || die "--mode must be shadow or live."
validate_positive_number "watch timeout" "$WATCH_TIMEOUT_S"
validate_positive_number "poll period" "$POLL_PERIOD_S"
validate_positive_number "ADS-B rotation" "$ADSB_ROTATION_S"
validate_positive_number "capture duration" "$CAPTURE_DURATION_S"
validate_nonnegative_number "tail seconds" "$TAIL_SECONDS_S"
validate_positive_number "center frequency" "$CENTER_FREQUENCY_HZ"
validate_nonnegative_number "LO offset" "$LO_OFFSET_HZ"
validate_number "surveillance boresight azimuth" "$SURVEILLANCE_BORESIGHT_AZIMUTH_DEG"
validate_number "corridor azimuth center" "$CORRIDOR_AZIMUTH_CENTER_DEG"
validate_nonnegative_number "remote wait timeout" "$REMOTE_WAIT_TIMEOUT_S"
validate_positive_number "fetch poll" "$FETCH_POLL_S"

RUNTIME_ROOT="$REPO_ROOT/TriggerAcquisition/runtime/$SESSION_ID"
if [[ -z "$ADSB_STAGE_DIR" ]]; then
    ADSB_STAGE_DIR="$RUNTIME_ROOT/adsb_stage"
fi
if [[ -z "$CONTROL_DIR" ]]; then
    CONTROL_DIR="$RUNTIME_ROOT/control"
fi
mkdir -p "$ADSB_STAGE_DIR" "$CONTROL_DIR" "$RUNTIME_ROOT/logs"

STATUS_FILE="$CONTROL_DIR/coordinator_status.txt"
STOP_REQUEST_PATH="$CONTROL_DIR/stop_request.flag"
ADSB_STOPPED_FLAG="$CONTROL_DIR/adsb_stopped.flag"
LOCAL_REMOTE_LOG="$RUNTIME_ROOT/logs/adsb_capture_${SESSION_ID}.log"
REMOTE_LOG_FILE="$PI_WORKDIR/adsb_capture_${SESSION_ID}.log"
SESSION_ID_REGEX="$(printf "%s" "$SESSION_ID" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g')"
MATLAB_GAIN_EXPR="$(gain_to_matlab_expr "$GAIN_SPEC")"

write_status "starting" "Preparing remote ADS-B logger and local staging folders."

set +e
probe_output="$(run_ssh_body "cd $(quote_posix_arg "$PI_WORKDIR") && test -f $(quote_posix_arg "$PI_LOGGER_SCRIPT") && command -v python3 >/dev/null 2>&1 && printf READY" 2>&1)"
probe_status=$?
set -e

if [[ $probe_status -eq 0 && "$probe_output" == "READY" ]]; then
    if [[ $PREFLIGHT_ONLY -eq 1 ]]; then
        echo "Preflight: Pi SSH/logger check passed for $PI_USER@$PI_HOST."
        write_status "preflight_pi_ready" "Pi SSH/logger check passed."
    else
        echo "Preflight: starting rotating ADS-B logger on $PI_USER@$PI_HOST ..."
        remote_logger_body="cd $(quote_posix_arg "$PI_WORKDIR") && exec python3 $(quote_posix_arg "$PI_LOGGER_SCRIPT") --session-id $(quote_posix_arg "$SESSION_ID") --time-per-file $(quote_posix_arg "$ADSB_ROTATION_S") > $(quote_posix_arg "$REMOTE_LOG_FILE") 2>&1 < /dev/null"
        remote_start_body="cd $(quote_posix_arg "$PI_WORKDIR") && if command -v setsid >/dev/null 2>&1; then setsid -f bash -lc $(quote_posix_arg "$remote_logger_body"); else nohup bash -lc $(quote_posix_arg "$remote_logger_body") >/dev/null 2>&1 & fi; printf STARTED"

        set +e
        start_output="$(run_ssh_body "$remote_start_body" 2>&1)"
        start_status=$?
        set -e

        if [[ $start_status -eq 0 && "$start_output" == *"STARTED"* ]]; then
            REMOTE_LOGGER_STARTED=1
            write_status "running" "Remote ADS-B logger is active and staging will continue until MATLAB requests stop."
            background_fetch_loop &
            FETCHER_PID=$!
        else
            write_status "start_failed" "Remote ADS-B logger could not be started: ${start_output//$'\n'/ }"
        fi
    fi
else
    if [[ $PREFLIGHT_ONLY -eq 1 ]]; then
        write_status "preflight_pi_failed" "SSH preflight failed: ${probe_output//$'\n'/ }"
        exit 1
    else
        write_status "start_failed" "SSH preflight failed: ${probe_output//$'\n'/ }"
    fi
fi

if [[ $PREFLIGHT_ONLY -eq 1 ]]; then
    PREFLIGHT_PREVIEW_PATH="$RUNTIME_ROOT/logs/trigger_candidate_map.png"
    PREFLIGHT_SUMMARY_PATH="$RUNTIME_ROOT/logs/trigger_preflight_summary.txt"
    matlab_cmd="cd($(quote_matlab_string "$SCRIPT_DIR")); result = runADSBTriggerPreflight('RadioName', $(quote_matlab_string "$RADIO_NAME"), 'PreviewOutputPath', $(quote_matlab_string "$PREFLIGHT_PREVIEW_PATH"), 'SummaryOutputPath', $(quote_matlab_string "$PREFLIGHT_SUMMARY_PATH"), 'Verbose', true); if ~result.overall_passed, error('run_adsb_triggered_hdtv_capture:preflightFailed', 'Trigger preflight reported one or more failures.'); end"

    set +e
    "$MATLAB_BIN" -batch "$matlab_cmd"
    MATLAB_STATUS=$?
    set -e

    if [[ $MATLAB_STATUS -ne 0 ]]; then
        write_status "preflight_failed" "Local MATLAB preflight failed."
        exit "$MATLAB_STATUS"
    fi

    write_status "preflight_passed" "Trigger preflight passed."
    echo "ADS-B trigger preflight complete for session $SESSION_ID."
    exit 0
fi

matlab_cmd="cd($(quote_matlab_string "$SCRIPT_DIR")); result = runADSBTriggeredCaptureSession('SessionID', $(quote_matlab_string "$SESSION_ID"), 'Mode', $(quote_matlab_string "$MODE"), 'OpportunityPolicy', $(quote_matlab_string "$OPPORTUNITY_POLICY"), 'WatchTimeout_s', $WATCH_TIMEOUT_S, 'PollPeriod_s', $POLL_PERIOD_S, 'ADSBRotation_s', $ADSB_ROTATION_S, 'TailSeconds_s', $TAIL_SECONDS_S, 'CaptureDuration_s', $CAPTURE_DURATION_S, 'CaptureFile', $(quote_matlab_string "$CAPTURE_FILE"), 'RadioName', $(quote_matlab_string "$RADIO_NAME"), 'CenterFrequency_Hz', $CENTER_FREQUENCY_HZ, 'SampleRate_Hz', $SAMPLE_RATE_HZ, 'LOOffset_Hz', $LO_OFFSET_HZ, 'Gain', $MATLAB_GAIN_EXPR, 'SessionRoot', $(quote_matlab_string "$SESSION_ROOT"), 'ADSBStageDir', $(quote_matlab_string "$ADSB_STAGE_DIR"), 'CoordinatorControlDir', $(quote_matlab_string "$CONTROL_DIR"), 'CoordinatorStatusFile', $(quote_matlab_string "$STATUS_FILE"), 'RemoteLogLocalPath', $(quote_matlab_string "$LOCAL_REMOTE_LOG"), 'PiUser', $(quote_matlab_string "$PI_USER"), 'PiHost', $(quote_matlab_string "$PI_HOST"), 'PiWorkingDir', $(quote_matlab_string "$PI_WORKDIR"), 'PiLoggerScript', $(quote_matlab_string "$PI_LOGGER_SCRIPT"), 'RemoteLogFile', $(quote_matlab_string "$REMOTE_LOG_FILE"), 'CorridorAzimuthCenter_deg', $CORRIDOR_AZIMUTH_CENTER_DEG, 'SurveillanceBoresightAzimuth_deg', $SURVEILLANCE_BORESIGHT_AZIMUTH_DEG, 'ReferenceChainPenalty_dB', $REFERENCE_CHAIN_PENALTY_DB, 'Verbose', true);"

set +e
"$MATLAB_BIN" -batch "$matlab_cmd"
MATLAB_STATUS=$?
set -e

if [[ ! -f "$STOP_REQUEST_PATH" ]]; then
    printf "STOP_REQUEST_UTC=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STOP_REQUEST_PATH"
fi

FETCH_STATUS=0
if [[ -n "$FETCHER_PID" ]]; then
    set +e
    wait "$FETCHER_PID"
    FETCH_STATUS=$?
    set -e
fi

if [[ $MATLAB_STATUS -ne 0 ]]; then
    exit "$MATLAB_STATUS"
fi
if [[ $FETCH_STATUS -ne 0 ]]; then
    exit "$FETCH_STATUS"
fi

echo "ADS-B triggered capture wrapper complete for session $SESSION_ID."
