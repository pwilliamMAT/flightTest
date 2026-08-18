#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_CAPTURE_SECONDS=300
DEFAULT_INTERVAL_SECONDS=1800
DEFAULT_CAMPAIGN_SECONDS=259200
DEFAULT_PI_HOST="192.168.10.131"
DEFAULT_PI_USER="pi2"
DEFAULT_PI_WORKDIR="/home/pi2/flightTest/ADSB_GPS"
DEFAULT_PI_LOGGER_SCRIPT="start_adsb_gps_loggers.sh"
DEFAULT_OUTPUT_ROOT="$SCRIPT_DIR/campaigns"
DEFAULT_ADSB_STAGE_DIR="$REPO_ROOT/adsb_capture"
DEFAULT_SESSION_ROOT="$REPO_ROOT/captures"
DEFAULT_REMOTE_WAIT_TIMEOUT=60
DEFAULT_FETCH_POLL=2
DEFAULT_RECEIVER_ORIGIN_LLA="42.2999333,-71.349333,15.0"
MAX_CONSECUTIVE_START_FAILURES=3

CAPTURE_SECONDS="$DEFAULT_CAPTURE_SECONDS"
INTERVAL_SECONDS="$DEFAULT_INTERVAL_SECONDS"
CAMPAIGN_SECONDS="$DEFAULT_CAMPAIGN_SECONDS"
CAMPAIGN_ID=""
PI_HOST="$DEFAULT_PI_HOST"
PI_USER="$DEFAULT_PI_USER"
PI_WORKDIR="$DEFAULT_PI_WORKDIR"
PI_LOGGER_SCRIPT="$DEFAULT_PI_LOGGER_SCRIPT"
SSH_BIN="ssh"
SCP_BIN="scp"
OUTPUT_ROOT="$DEFAULT_OUTPUT_ROOT"
ADSB_STAGE_DIR="$DEFAULT_ADSB_STAGE_DIR"
SESSION_ROOT="$DEFAULT_SESSION_ROOT"
REMOTE_WAIT_TIMEOUT="$DEFAULT_REMOTE_WAIT_TIMEOUT"
FETCH_POLL="$DEFAULT_FETCH_POLL"
RECEIVER_ORIGIN_LLA="$DEFAULT_RECEIVER_ORIGIN_LLA"
RECEIVER_LAT=""
RECEIVER_LON=""
RECEIVER_ALT_M=""
MAX_WINDOWS=0
DRY_RUN=0
PREFLIGHT_ONLY=0

SSH_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SCP_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

CAMPAIGN_DIR=""
STATUS_FILE=""
STOP_REQUESTED=0
ACTIVE_SESSION_ID=""
ACTIVE_SIGNAL=""
PACKAGED_ADSB_FILES=()
PACKAGED_LOG_FILES=()

usage() {
    cat <<EOF
Usage: bash adsbForTracking/piCaptureCampaign/$(basename "$0") [options]

Run bounded ADS-B-only capture windows from the Ubuntu testing machine. The
script SSHes to the Raspberry Pi, starts the existing ADS-B/GPS logger wrapper,
fetches the gzip truth logs, and packages each window under captures/<session_id>/.

Options:
  --pi-host <host>                 Raspberry Pi host or IP (default: $DEFAULT_PI_HOST)
  --pi-user <user>                 Raspberry Pi SSH user (default: $DEFAULT_PI_USER)
  --pi-workdir <path>              Pi ADS-B work directory (default: $DEFAULT_PI_WORKDIR)
  --pi-logger-script <path>        Pi logger wrapper path/name (default: $DEFAULT_PI_LOGGER_SCRIPT)
  --ssh-bin <path>                 SSH executable (default: ssh)
  --scp-bin <path>                 SCP executable (default: scp)
  --adsb-stage-dir <path>          Local staging folder for fetched ADS-B files
  --session-root <path>            Local packaged-session root (default: captures under repo root)
  --remote-wait-timeout <seconds>  Extra wait for Pi logger stop after capture duration (default: $DEFAULT_REMOTE_WAIT_TIMEOUT)
  --fetch-poll <seconds>           Polling period while waiting for Pi logger (default: $DEFAULT_FETCH_POLL)
  --receiver-origin-lla <lat,lon,alt_m>
                                   Receiver origin metadata for manifests (default: $DEFAULT_RECEIVER_ORIGIN_LLA)
  --capture-seconds <seconds>      ADS-B capture duration per window (default: $DEFAULT_CAPTURE_SECONDS)
  --interval-seconds <seconds>     Start-to-start interval between windows (default: $DEFAULT_INTERVAL_SECONDS)
  --campaign-seconds <seconds>     Total campaign planning duration (default: $DEFAULT_CAMPAIGN_SECONDS)
  --campaign-id <token>            Campaign ID (default: stage4B_<UTC timestamp>)
  --output-root <path>             Campaign metadata output root
  --max-windows <count>            Cap planned windows; 0 means no cap (default: 0)
  --dry-run                        Print planned windows without SSH or package writes
  --preflight-only                 Run dependency checks and exit without starting capture
  -h, --help                       Show this help text

Default remote command per window:
  cd $DEFAULT_PI_WORKDIR && sudo -n bash $DEFAULT_PI_LOGGER_SCRIPT --adsb-only --adsb-session-id <session_id> --adsb-run-seconds $DEFAULT_CAPTURE_SECONDS
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

is_positive_integer() { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }
is_nonnegative_integer() { [[ "$1" =~ ^[0-9]+$ ]]; }
is_number() { [[ "$1" =~ ^[-+]?[0-9]+([.][0-9]+)?$ ]]; }

require_value() {
    [[ -n "${2:-}" && "${2:-}" != --* ]] || die "Missing value for $1"
}

trim_value() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf "%s" "$value"
}

quote_posix_arg() {
    printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\"'\"'/g")"
}

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

utc_token_now() { date -u +"%Y%m%dT%H%M%SZ"; }
utc_iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
utc_token_from_epoch() { date -u -d "@$1" +"%Y%m%dT%H%M%SZ"; }
utc_iso_from_epoch() { date -u -d "@$1" +"%Y-%m-%dT%H:%M:%SZ"; }
window_id_for_index() { printf "w%03d" "$1"; }

parse_receiver_origin_lla() {
    local raw="$1"
    local lat
    local lon
    local alt_m
    local extra

    IFS=',' read -r lat lon alt_m extra <<< "$raw"
    lat="$(trim_value "${lat:-}")"
    lon="$(trim_value "${lon:-}")"
    alt_m="$(trim_value "${alt_m:-}")"

    [[ -z "${extra:-}" && -n "$lat" && -n "$lon" && -n "$alt_m" ]] || \
        die "--receiver-origin-lla must contain exactly three comma-separated numeric values"
    is_number "$lat" || die "--receiver-origin-lla latitude must be numeric"
    is_number "$lon" || die "--receiver-origin-lla longitude must be numeric"
    is_number "$alt_m" || die "--receiver-origin-lla altitude must be numeric"
    awk -v x="$lat" 'BEGIN { exit !(x >= -90 && x <= 90) }' || \
        die "--receiver-origin-lla latitude must be between -90 and 90 degrees"
    awk -v x="$lon" 'BEGIN { exit !(x >= -180 && x <= 180) }' || \
        die "--receiver-origin-lla longitude must be between -180 and 180 degrees"

    RECEIVER_LAT="$lat"
    RECEIVER_LON="$lon"
    RECEIVER_ALT_M="$alt_m"
    RECEIVER_ORIGIN_LLA="$lat,$lon,$alt_m"
}

receiver_origin_json() {
    printf "[%s, %s, %s]" "$RECEIVER_LAT" "$RECEIVER_LON" "$RECEIVER_ALT_M"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --pi-host) require_value "$1" "${2:-}"; PI_HOST="$2"; shift 2 ;;
            --pi-user) require_value "$1" "${2:-}"; PI_USER="$2"; shift 2 ;;
            --pi-workdir) require_value "$1" "${2:-}"; PI_WORKDIR="$2"; shift 2 ;;
            --pi-logger-script|--logger-script) require_value "$1" "${2:-}"; PI_LOGGER_SCRIPT="$2"; shift 2 ;;
            --ssh-bin) require_value "$1" "${2:-}"; SSH_BIN="$2"; shift 2 ;;
            --scp-bin) require_value "$1" "${2:-}"; SCP_BIN="$2"; shift 2 ;;
            --adsb-stage-dir) require_value "$1" "${2:-}"; ADSB_STAGE_DIR="$2"; shift 2 ;;
            --session-root) require_value "$1" "${2:-}"; SESSION_ROOT="$2"; shift 2 ;;
            --remote-wait-timeout) require_value "$1" "${2:-}"; REMOTE_WAIT_TIMEOUT="$2"; shift 2 ;;
            --fetch-poll) require_value "$1" "${2:-}"; FETCH_POLL="$2"; shift 2 ;;
            --receiver-origin-lla) require_value "$1" "${2:-}"; RECEIVER_ORIGIN_LLA="$2"; shift 2 ;;
            --capture-seconds) require_value "$1" "${2:-}"; CAPTURE_SECONDS="$2"; shift 2 ;;
            --interval-seconds) require_value "$1" "${2:-}"; INTERVAL_SECONDS="$2"; shift 2 ;;
            --campaign-seconds) require_value "$1" "${2:-}"; CAMPAIGN_SECONDS="$2"; shift 2 ;;
            --campaign-id) require_value "$1" "${2:-}"; CAMPAIGN_ID="$2"; shift 2 ;;
            --output-root) require_value "$1" "${2:-}"; OUTPUT_ROOT="$2"; shift 2 ;;
            --max-windows) require_value "$1" "${2:-}"; MAX_WINDOWS="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            --preflight-only) PREFLIGHT_ONLY=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
    done
}

validate_config() {
    is_positive_integer "$CAPTURE_SECONDS" || die "--capture-seconds must be a positive integer"
    is_positive_integer "$INTERVAL_SECONDS" || die "--interval-seconds must be a positive integer"
    is_positive_integer "$CAMPAIGN_SECONDS" || die "--campaign-seconds must be a positive integer"
    is_nonnegative_integer "$MAX_WINDOWS" || die "--max-windows must be a non-negative integer"
    is_positive_integer "$REMOTE_WAIT_TIMEOUT" || die "--remote-wait-timeout must be a positive integer"
    is_positive_integer "$FETCH_POLL" || die "--fetch-poll must be a positive integer"
    parse_receiver_origin_lla "$RECEIVER_ORIGIN_LLA"

    if [[ -z "$CAMPAIGN_ID" ]]; then
        CAMPAIGN_ID="stage4B_$(utc_token_now)"
    fi
    [[ "$CAMPAIGN_ID" =~ ^[A-Za-z0-9_.-]+$ ]] || \
        die "--campaign-id may contain only letters, numbers, underscore, dot, and hyphen"
}

run_ssh_body() {
    local body="$1"
    "$SSH_BIN" "${SSH_OPTIONS[@]}" "$PI_USER@$PI_HOST" "bash -lc $(quote_posix_arg "$body")"
}

remote_logger_ref() { printf "%s" "$PI_LOGGER_SCRIPT"; }

remote_logger_command() {
    local session_id="$1"
    printf "cd %s && sudo -n bash %s --adsb-only --adsb-session-id %s --adsb-run-seconds %s" \
        "$(quote_posix_arg "$PI_WORKDIR")" \
        "$(quote_posix_arg "$(remote_logger_ref)")" \
        "$(quote_posix_arg "$session_id")" \
        "$(quote_posix_arg "$CAPTURE_SECONDS")"
}

remote_log_file_for_session() {
    printf "%s/stage4B_adsb_capture_%s.log" "$PI_WORKDIR" "$1"
}

session_regex() {
    printf "%s" "$1" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g'
}

remote_logger_pattern() {
    printf "gatherTCPcompress.py.*%s" "$(session_regex "$1")"
}

remote_logger_running() {
    local body
    local output
    body="pgrep -f $(quote_posix_arg "$(remote_logger_pattern "$1")") >/dev/null && printf RUNNING || printf STOPPED"
    output="$(run_ssh_body "$body" 2>/dev/null)" || { printf UNKNOWN; return; }
    printf "%s" "$output"
}

signal_remote_logger() {
    local session_id="$1"
    local sig="${2:-TERM}"
    local body
    body="pids=\$(pgrep -f $(quote_posix_arg "$(remote_logger_pattern "$session_id")") || true); if [[ -z \"\$pids\" ]]; then printf STOPPED; else sudo -n kill -s $sig \$pids && printf SIGNALED; fi"
    run_ssh_body "$body"
}

wait_for_remote_logger_stop() {
    local session_id="$1"
    local deadline=$((SECONDS + CAPTURE_SECONDS + REMOTE_WAIT_TIMEOUT))
    local state

    while true; do
        [[ "$STOP_REQUESTED" -eq 0 ]] || return 130
        state="$(remote_logger_running "$session_id")"
        [[ "$state" == STOPPED ]] && return 0
        (( SECONDS < deadline )) || return 1
        sleep "$FETCH_POLL"
    done
}

local_can_write() {
    local root_path="$1"
    local label="$2"
    local probe_path

    mkdir -p "$root_path" 2>/dev/null || { echo "  FAIL cannot create $label: $root_path"; return 1; }
    probe_path="$root_path/.stage4B_write_probe_$$"
    : > "$probe_path" 2>/dev/null || { echo "  FAIL cannot write $label: $root_path"; return 1; }
    rm -f "$probe_path"
    echo "  OK writable $label: $root_path"
}

preflight_check() {
    local failures=0
    local output
    local body

    echo "Preflight checks:"
    if command -v "$SSH_BIN" >/dev/null 2>&1; then
        echo "  OK local ssh: $SSH_BIN"
    else
        echo "  FAIL local ssh not found: $SSH_BIN"
        failures=$((failures + 1))
    fi
    if command -v "$SCP_BIN" >/dev/null 2>&1; then
        echo "  OK local scp: $SCP_BIN"
    else
        echo "  FAIL local scp not found: $SCP_BIN"
        failures=$((failures + 1))
    fi

    local_can_write "$OUTPUT_ROOT" "campaign output root" || failures=$((failures + 1))
    local_can_write "$SESSION_ROOT" "session root" || failures=$((failures + 1))
    local_can_write "$ADSB_STAGE_DIR" "ADS-B staging root" || failures=$((failures + 1))

    if [[ "$failures" -eq 0 ]]; then
        body="cd $(quote_posix_arg "$PI_WORKDIR") && test -f $(quote_posix_arg "$(remote_logger_ref)") && command -v python3 >/dev/null 2>&1 && command -v dump1090 >/dev/null 2>&1 && printf PREFLIGHT_READY"
        output="$(run_ssh_body "$body" 2>&1)"
        if [[ $? -eq 0 && "$output" == *PREFLIGHT_READY* ]]; then
            echo "  OK remote logger wrapper, dump1090, and python3 on $PI_USER@$PI_HOST"
        else
            echo "  FAIL remote logger/python3/dump1090 check on $PI_USER@$PI_HOST"
            echo "       $output"
            failures=$((failures + 1))
        fi
    fi

    if [[ "$failures" -eq 0 ]]; then
        output="$(run_ssh_body "sudo -n true >/dev/null 2>&1 && printf SUDO_READY" 2>&1)"
        if [[ $? -eq 0 && "$output" == *SUDO_READY* ]]; then
            echo "  OK remote sudo -n access"
        else
            echo "  FAIL remote sudo -n access on $PI_USER@$PI_HOST"
            echo "       $output"
            failures=$((failures + 1))
        fi
    fi

    if [[ "$failures" -eq 0 ]]; then
        echo "Preflight result: PASS"
        return 0
    fi
    echo "Preflight result: FAIL ($failures issue(s))"
    return 1
}

planned_window_count() {
    local count=0
    local offset=0
    while [[ "$offset" -lt "$CAMPAIGN_SECONDS" ]]; do
        count=$((count + 1))
        [[ "$MAX_WINDOWS" -eq 0 || "$count" -lt "$MAX_WINDOWS" ]] || break
        offset=$((count * INTERVAL_SECONDS))
    done
    printf "%d" "$count"
}

print_plan() {
    local start_epoch="$1"
    local count
    local idx
    local window_id
    local planned_epoch
    local planned_iso
    local token
    local session_id

    count="$(planned_window_count)"
    echo "DRY_RUN	$DRY_RUN"
    echo "CAMPAIGN_ID	$CAMPAIGN_ID"
    echo "PI_TARGET	$PI_USER@$PI_HOST"
    echo "PI_WORKDIR	$PI_WORKDIR"
    echo "PI_LOGGER_SCRIPT	$PI_LOGGER_SCRIPT"
    echo "SESSION_ROOT	$SESSION_ROOT"
    echo "ADSB_STAGE_DIR	$ADSB_STAGE_DIR"
    echo "OUTPUT_ROOT	$OUTPUT_ROOT"
    echo "RECEIVER_ORIGIN_LLA	$RECEIVER_ORIGIN_LLA"
    echo "CAPTURE_SECONDS	$CAPTURE_SECONDS"
    echo "INTERVAL_SECONDS	$INTERVAL_SECONDS"
    echo "CAMPAIGN_SECONDS	$CAMPAIGN_SECONDS"
    echo "REMOTE_COMMAND_TEMPLATE	$(remote_logger_command '<session_id>')"
    echo "PLAN_HEADER	window_id	session_id	planned_start_utc"

    for ((idx = 1; idx <= count; idx++)); do
        window_id="$(window_id_for_index "$idx")"
        planned_epoch=$((start_epoch + (idx - 1) * INTERVAL_SECONDS))
        planned_iso="$(utc_iso_from_epoch "$planned_epoch")"
        token="$(utc_token_from_epoch "$planned_epoch")"
        session_id="${CAMPAIGN_ID}_${window_id}_${token}"
        echo "PLAN	$window_id	$session_id	$planned_iso"
    done
    echo "DRY_RUN_PLAN_WINDOWS	$count"
}

initialize_campaign_dir() {
    CAMPAIGN_DIR="$OUTPUT_ROOT/$CAMPAIGN_ID"
    [[ ! -e "$CAMPAIGN_DIR" ]] || die "Campaign directory already exists: $CAMPAIGN_DIR"
    mkdir -p "$CAMPAIGN_DIR" || die "Could not create campaign directory: $CAMPAIGN_DIR"
    STATUS_FILE="$CAMPAIGN_DIR/campaign_status.tsv"
    printf "window_id\tsession_id\tplanned_start_utc\tactual_start_utc\tactual_stop_utc\tstatus\tadsb_files_found\tbyte_count\tmessage\n" > "$STATUS_FILE"
}

write_campaign_metadata() {
    local start_epoch="$1"
    local path="$CAMPAIGN_DIR/campaign_metadata.txt"
    local plan_path="$CAMPAIGN_DIR/campaign_plan.tsv"
    local count
    local idx
    local window_id
    local planned_epoch
    local token

    count="$(planned_window_count)"
    {
        echo "campaign_id=$CAMPAIGN_ID"
        echo "generated_utc=$(utc_iso_now)"
        echo "campaign_start_utc=$(utc_iso_from_epoch "$start_epoch")"
        echo "capture_seconds=$CAPTURE_SECONDS"
        echo "interval_seconds=$INTERVAL_SECONDS"
        echo "campaign_seconds=$CAMPAIGN_SECONDS"
        echo "planned_windows=$count"
        echo "pi_target=$PI_USER@$PI_HOST"
        echo "pi_workdir=$PI_WORKDIR"
        echo "pi_logger_script=$PI_LOGGER_SCRIPT"
        echo "output_root=$OUTPUT_ROOT"
        echo "adsb_stage_dir=$ADSB_STAGE_DIR"
        echo "session_root=$SESSION_ROOT"
        echo "receiver_origin_lla=$RECEIVER_ORIGIN_LLA"
    } > "$path"

    printf "window_id\tsession_id\tplanned_start_utc\n" > "$plan_path"
    for ((idx = 1; idx <= count; idx++)); do
        window_id="$(window_id_for_index "$idx")"
        planned_epoch=$((start_epoch + (idx - 1) * INTERVAL_SECONDS))
        token="$(utc_token_from_epoch "$planned_epoch")"
        printf "%s\t%s_%s_%s\t%s\n" \
            "$window_id" "$CAMPAIGN_ID" "$window_id" "$token" "$(utc_iso_from_epoch "$planned_epoch")" >> "$plan_path"
    done
}

tsv_value() {
    local value="${1:-}"
    value="${value//$'\t'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    printf "%s" "$value"
}

append_status() {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$(tsv_value "$1")" "$(tsv_value "$2")" "$(tsv_value "$3")" \
        "$(tsv_value "$4")" "$(tsv_value "$5")" "$(tsv_value "$6")" \
        "$(tsv_value "$7")" "$(tsv_value "$8")" "$(tsv_value "$9")" >> "$STATUS_FILE"
}

sleep_interruptible() {
    local seconds="$1"
    local step
    while [[ "$seconds" -gt 0 ]]; do
        [[ "$STOP_REQUESTED" -eq 0 ]] || return 130
        step="$seconds"
        [[ "$step" -le 30 ]] || step=30
        sleep "$step" || true
        seconds=$((seconds - step))
    done
    [[ "$STOP_REQUESTED" -eq 0 ]] || return 130
}

wait_until_epoch() {
    local planned_epoch="$1"
    local now_epoch
    local wait_seconds
    while true; do
        now_epoch="$(date -u +%s)"
        [[ "$now_epoch" -lt "$planned_epoch" ]] || return 0
        wait_seconds=$((planned_epoch - now_epoch))
        sleep_interruptible "$wait_seconds" || return 130
    done
}

start_remote_logger() {
    local session_id="$1"
    local remote_log_file="$2"
    local cmd
    local body
    cmd="$(remote_logger_command "$session_id")"
    body="$cmd > $(quote_posix_arg "$remote_log_file") 2>&1; s=\$?; if [[ \$s -eq 0 ]]; then printf STARTED; else printf START_FAILED:\$s; exit \$s; fi"
    run_ssh_body "$body"
}

list_remote_adsb_files() {
    local session_id="$1"
    local remote_log_file="$2"
    local body
    body="
remote_log=$(quote_posix_arg "$remote_log_file")
pi_workdir=$(quote_posix_arg "$PI_WORKDIR")
session_glob=$(quote_posix_arg "*adsb_${session_id}*.txt.gz")
declare -a hits=()
if [[ -f \$remote_log ]]; then
    while IFS= read -r artifact; do
        [[ -n \$artifact && \$artifact != '(none)' ]] || continue
        [[ \$artifact == /* ]] || artifact=\"\$pi_workdir/\$artifact\"
        [[ -f \$artifact ]] && hits+=(\"\$artifact\")
    done < <(sed -n 's/^[[:space:]]*final artifact[[:space:]]*:[[:space:]]*//p' \"\$remote_log\")
fi
if [[ \${#hits[@]} -eq 0 ]]; then
    while IFS= read -r path; do
        [[ -n \$path ]] && hits+=(\"\$path\")
    done < <(find \"\$pi_workdir\" -maxdepth 1 -type f -name \"\$session_glob\" -print | sort)
fi
[[ \${#hits[@]} -eq 0 ]] || printf '%s\n' \"\${hits[@]}\" | awk '!seen[\$0]++'
"
    run_ssh_body "$body"
}

copy_remote_file_to_dir() {
    mkdir -p "$2"
    "$SCP_BIN" "${SCP_OPTIONS[@]}" "$PI_USER@$PI_HOST:$1" "$2/"
}

move_into_subdir() {
    local src="$1"
    local dest_dir="$2"
    local rel_prefix="$3"
    local dest="$dest_dir/$(basename "$src")"
    mkdir -p "$dest_dir"
    mv -f "$src" "$dest"
    printf "%s/%s" "$rel_prefix" "$(basename "$dest")"
}

sum_file_bytes() {
    local total=0
    local path
    local bytes
    for path in "$@"; do
        if [[ -f "$path" ]]; then
            bytes="$(wc -c < "$path")"
            bytes="${bytes//[[:space:]]/}"
            total=$((total + bytes))
        fi
    done
    printf "%s" "$total"
}

write_session_manifest() {
    local path="$1"
    local session_id="$2"
    local window_id="$3"
    local planned_start="$4"
    local actual_start="$5"
    local actual_stop="$6"
    local remote_log_file="$7"
    local status="$8"
    {
        printf "{\n"
        printf '  "manifest_version": 1,\n'
        printf '  "session_id": "%s",\n' "$(json_escape "$session_id")"
        printf '  "session_folder": "%s",\n' "$(json_escape "$session_id")"
        printf '  "session_created_utc": "%s",\n' "$(utc_iso_now)"
        printf '  "capture_type": "adsb_only_holdout",\n'
        printf '  "campaign_id": "%s",\n' "$(json_escape "$CAMPAIGN_ID")"
        printf '  "window_id": "%s",\n' "$(json_escape "$window_id")"
        printf '  "planned_start_utc": "%s",\n' "$(json_escape "$planned_start")"
        printf '  "actual_start_utc": "%s",\n' "$(json_escape "$actual_start")"
        printf '  "actual_stop_utc": "%s",\n' "$(json_escape "$actual_stop")"
        printf '  "capture_seconds": %s,\n' "$CAPTURE_SECONDS"
        printf '  "interval_seconds": %s,\n' "$INTERVAL_SECONDS"
        printf '  "campaign_seconds": %s,\n' "$CAMPAIGN_SECONDS"
        printf '  "status": "%s",\n' "$(json_escape "$status")"
        printf '  "receiver_origin_lla": %s,\n' "$(receiver_origin_json)"
        printf '  "pi_host": "%s",\n' "$(json_escape "$PI_HOST")"
        printf '  "pi_user": "%s",\n' "$(json_escape "$PI_USER")"
        printf '  "pi_workdir": "%s",\n' "$(json_escape "$PI_WORKDIR")"
        printf '  "pi_logger_script": "%s",\n' "$(json_escape "$PI_LOGGER_SCRIPT")"
        printf '  "remote_log_file": "%s",\n' "$(json_escape "$remote_log_file")"
        printf '  "radar_files": [],\n'
        printf '  "adsb_files": %s,\n' "$(write_json_array "${PACKAGED_ADSB_FILES[@]}")"
        printf '  "log_files": %s\n' "$(write_json_array "${PACKAGED_LOG_FILES[@]}")"
        printf "}\n"
    } > "$path"
}

handle_signal() {
    ACTIVE_SIGNAL="$1"
    STOP_REQUESTED=1
    echo "Received $ACTIVE_SIGNAL; interrupting campaign" >&2
    [[ -z "$ACTIVE_SESSION_ID" ]] || signal_remote_logger "$ACTIVE_SESSION_ID" TERM >/dev/null 2>&1 || true
}

run_capture_window() {
    local idx="$1"
    local planned_epoch="$2"
    local window_id
    local planned_iso
    local token
    local session_id
    local session_dir
    local truth_dir
    local log_dir
    local stage_dir
    local manifest_path
    local remote_log_file
    local coordinator_log
    local actual_start=""
    local actual_stop=""
    local start_output
    local start_status
    local wait_status
    local status
    local message
    local byte_count
    local fetch_status=0
    local remote_log_status=0
    local remote_file
    local staged_path
    local remote_files=()
    local staged_adsb_files=()

    PACKAGED_ADSB_FILES=()
    PACKAGED_LOG_FILES=()
    window_id="$(window_id_for_index "$idx")"
    planned_iso="$(utc_iso_from_epoch "$planned_epoch")"
    token="$(utc_token_from_epoch "$planned_epoch")"
    session_id="${CAMPAIGN_ID}_${window_id}_${token}"
    session_dir="$SESSION_ROOT/$session_id"
    truth_dir="$session_dir/truth"
    log_dir="$session_dir/logs"
    stage_dir="$ADSB_STAGE_DIR/$session_id"
    manifest_path="$session_dir/session_manifest.json"
    remote_log_file="$(remote_log_file_for_session "$session_id")"
    coordinator_log="$log_dir/stage4B_${session_id}_coordinator.log"

    if ! wait_until_epoch "$planned_epoch"; then
        actual_stop="$(utc_iso_now)"
        append_status "$window_id" "$session_id" "$planned_iso" "" "$actual_stop" interrupted 0 0 "interrupted before planned start by $ACTIVE_SIGNAL"
        return 130
    fi

    [[ "$STOP_REQUESTED" -eq 0 ]] || return 130
    mkdir -p "$truth_dir" "$log_dir" "$stage_dir" || die "Could not create package directories for $session_id"

    {
        echo "session_id=$session_id"
        echo "window_id=$window_id"
        echo "planned_start_utc=$planned_iso"
        echo "pi_target=$PI_USER@$PI_HOST"
        echo "remote_log_file=$remote_log_file"
        echo "remote_command=$(remote_logger_command "$session_id")"
    } > "$coordinator_log"
    PACKAGED_LOG_FILES+=("logs/$(basename "$coordinator_log")")

    echo "Starting $window_id session $session_id at $(utc_iso_now)"
    actual_start="$(utc_iso_now)"
    ACTIVE_SESSION_ID="$session_id"
    start_output="$(start_remote_logger "$session_id" "$remote_log_file" 2>&1)"
    start_status=$?
    {
        echo ""
        echo "remote_start_output:"
        printf "%s\n" "$start_output"
        echo "remote_start_status=$start_status"
    } >> "$coordinator_log"

    if [[ "$start_status" -ne 0 || "$start_output" != *STARTED* ]]; then
        actual_stop="$(utc_iso_now)"
        ACTIVE_SESSION_ID=""
        status="start_failed"
        message="remote logger wrapper failed to start"
        write_session_manifest "$manifest_path" "$session_id" "$window_id" "$planned_iso" "$actual_start" "$actual_stop" "$remote_log_file" "$status"
        append_status "$window_id" "$session_id" "$planned_iso" "$actual_start" "$actual_stop" "$status" 0 0 "$message"
        return 1
    fi

    wait_for_remote_logger_stop "$session_id"
    wait_status=$?
    if [[ "$wait_status" -eq 130 ]]; then
        actual_stop="$(utc_iso_now)"
        signal_remote_logger "$session_id" TERM >/dev/null 2>&1 || true
        ACTIVE_SESSION_ID=""
        status="interrupted"
        write_session_manifest "$manifest_path" "$session_id" "$window_id" "$planned_iso" "$actual_start" "$actual_stop" "$remote_log_file" "$status"
        append_status "$window_id" "$session_id" "$planned_iso" "$actual_start" "$actual_stop" "$status" 0 0 "interrupted during remote capture by $ACTIVE_SIGNAL"
        return 130
    fi
    if [[ "$wait_status" -ne 0 ]]; then
        echo "Warning: remote logger did not stop within configured timeout; sending TERM." | tee -a "$coordinator_log" >&2
        signal_remote_logger "$session_id" TERM >> "$coordinator_log" 2>&1 || true
    fi
    ACTIVE_SESSION_ID=""
    actual_stop="$(utc_iso_now)"

    mapfile -t remote_files < <(list_remote_adsb_files "$session_id" "$remote_log_file" 2>> "$coordinator_log" || true)
    if [[ "${#remote_files[@]}" -eq 0 ]]; then
        fetch_status=1
        echo "Warning: no remote ADS-B gzip files matched session $session_id." | tee -a "$coordinator_log" >&2
    else
        echo "Found ${#remote_files[@]} remote ADS-B artifact(s) for session $session_id." | tee -a "$coordinator_log"
        for remote_file in "${remote_files[@]}"; do
            [[ -n "$remote_file" ]] || continue
            if copy_remote_file_to_dir "$remote_file" "$stage_dir" >> "$coordinator_log" 2>&1; then
                staged_path="$stage_dir/$(basename "$remote_file")"
                [[ -f "$staged_path" ]] && staged_adsb_files+=("$staged_path")
            else
                fetch_status=1
                echo "Warning: failed to copy $remote_file from the Pi." | tee -a "$coordinator_log" >&2
            fi
        done
    fi

    if copy_remote_file_to_dir "$remote_log_file" "$log_dir" >> "$coordinator_log" 2>&1; then
        [[ -f "$log_dir/$(basename "$remote_log_file")" ]] && PACKAGED_LOG_FILES+=("logs/$(basename "$remote_log_file")")
    else
        remote_log_status=1
        echo "Warning: failed to copy remote Pi log $remote_log_file." | tee -a "$coordinator_log" >&2
    fi

    for staged_path in "${staged_adsb_files[@]}"; do
        [[ -f "$staged_path" ]] && PACKAGED_ADSB_FILES+=("$(move_into_subdir "$staged_path" "$truth_dir" truth)")
    done

    byte_count="$(sum_file_bytes "$truth_dir"/*)"
    if [[ "$wait_status" -ne 0 ]]; then
        status="remote_wait_timeout"
        message="remote ADS-B logger required timeout handling"
    elif [[ "${#PACKAGED_ADSB_FILES[@]}" -gt 0 && "$fetch_status" -eq 0 && "$remote_log_status" -eq 0 ]]; then
        status="completed"
        message="ADS-B gzip artifact(s) packaged"
    elif [[ "${#PACKAGED_ADSB_FILES[@]}" -gt 0 ]]; then
        status="completed_with_warnings"
        message="ADS-B gzip artifact(s) packaged with fetch/log warnings"
    else
        status="completed_no_gzip"
        message="No ADS-B gzip artifact found; continue campaign and review logs"
    fi

    write_session_manifest "$manifest_path" "$session_id" "$window_id" "$planned_iso" "$actual_start" "$actual_stop" "$remote_log_file" "$status"
    append_status "$window_id" "$session_id" "$planned_iso" "$actual_start" "$actual_stop" "$status" "${#PACKAGED_ADSB_FILES[@]}" "$byte_count" "$message"
    echo "Finished $window_id with status $status, ADS-B files: ${#PACKAGED_ADSB_FILES[@]}, bytes: $byte_count"
}

main() {
    local start_epoch
    local count
    local idx
    local planned_epoch
    local result
    local consecutive_failures=0

    parse_args "$@"
    validate_config
    start_epoch="$(date -u +%s)"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_plan "$start_epoch"
        return 0
    fi
    preflight_check || return 1
    [[ "$PREFLIGHT_ONLY" -eq 0 ]] || return 0

    trap 'handle_signal SIGINT' INT
    trap 'handle_signal SIGTERM' TERM
    initialize_campaign_dir
    write_campaign_metadata "$start_epoch"

    count="$(planned_window_count)"
    echo "Campaign $CAMPAIGN_ID initialized at $CAMPAIGN_DIR"
    echo "Packaged sessions root: $SESSION_ROOT"
    echo "Planned windows: $count"

    for ((idx = 1; idx <= count; idx++)); do
        planned_epoch=$((start_epoch + (idx - 1) * INTERVAL_SECONDS))
        run_capture_window "$idx" "$planned_epoch"
        result=$?
        if [[ "$result" -eq 130 ]]; then
            echo "Campaign interrupted. Status written to $STATUS_FILE" >&2
            return 130
        fi
        if [[ "$result" -eq 1 ]]; then
            consecutive_failures=$((consecutive_failures + 1))
            echo "Consecutive start failures: $consecutive_failures" >&2
            if [[ "$consecutive_failures" -ge "$MAX_CONSECUTIVE_START_FAILURES" ]]; then
                echo "Aborting after $MAX_CONSECUTIVE_START_FAILURES consecutive start failures." >&2
                return 1
            fi
        else
            consecutive_failures=0
        fi
    done

    echo "Campaign complete. Status: $STATUS_FILE"
}

main "$@"
