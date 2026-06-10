#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# --- Configuration ---
GPS_LOGGER_SCRIPT="$SCRIPT_DIR/gatherNMEAcompress.py"
ADSB_LOGGER_SCRIPT="$SCRIPT_DIR/gatherTCPcompress.py"
LEGACY_ADSB_PATTERN="gatherTCPcompress\\.pl"

GPSD_LOG="/var/log/gpsd_startup.log"
DUMP1090_LOG="/var/log/dump1090_startup.log"
GPS_LOGGER_LOG="/var/log/gps_logger.log"
ADSB_LOGGER_LOG="/var/log/adsb_logger.log"

ADSB_RUN_SECONDS=""
ADSB_SESSION_ID=""
START_ADSB=1
START_GPS=1

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --adsb-run-seconds <seconds>   Stop the ADS-B logger after this duration.
  --adsb-session-id <token>      Pass a shared session ID to the ADS-B logger.
  --adsb-only                    Start only dump1090 + ADS-B logging.
  --gps-only                     Start only gpsd + GPS logging.
  -h, --help                     Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --adsb-run-seconds)
            [[ $# -ge 2 ]] || { echo "Missing value for $1"; exit 1; }
            ADSB_RUN_SECONDS="$2"
            shift 2
            ;;
        --adsb-session-id)
            [[ $# -ge 2 ]] || { echo "Missing value for $1"; exit 1; }
            ADSB_SESSION_ID="$2"
            shift 2
            ;;
        --adsb-only)
            START_GPS=0
            shift
            ;;
        --gps-only)
            START_ADSB=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ $START_ADSB -eq 0 && $START_GPS -eq 0 ]]; then
    echo "Nothing to start. Remove --adsb-only or --gps-only."
    exit 1
fi

# --- Functions ---

is_service_active() {
    systemctl is-active --quiet "$1"
}

kill_process_by_name() {
    local process_name="$1"
    local pids

    echo "Checking for existing '$process_name' processes..."
    pids=$(pgrep -x "$process_name")
    if [[ -z "$pids" ]]; then
        echo "  No '$process_name' processes found."
        return
    fi

    echo "  Found PIDs: $pids. Attempting graceful kill..."
    kill $pids
    sleep 3

    pids=$(pgrep -x "$process_name")
    if [[ -n "$pids" ]]; then
        echo "  '$process_name' did not terminate gracefully. Force killing: $pids"
        kill -9 $pids
        sleep 1
    else
        echo "  '$process_name' terminated gracefully."
    fi
}

kill_process_by_pattern() {
    local label="$1"
    local pattern="$2"
    local pids

    echo "Checking for existing '$label' processes..."
    pids=$(pgrep -f "$pattern")
    if [[ -z "$pids" ]]; then
        echo "  No '$label' processes found."
        return
    fi

    echo "  Found PIDs: $pids. Attempting graceful kill..."
    kill $pids
    sleep 3

    pids=$(pgrep -f "$pattern")
    if [[ -n "$pids" ]]; then
        echo "  '$label' did not terminate gracefully. Force killing: $pids"
        kill -9 $pids
        sleep 1
    else
        echo "  '$label' terminated gracefully."
    fi
}

stop_and_disable_service() {
    local service_name="$1"

    echo "Checking status of service: $service_name"
    if is_service_active "$service_name"; then
        echo "  Service '$service_name' is active. Stopping..."
        systemctl stop "$service_name"
        sleep 2
        if ! is_service_active "$service_name"; then
            echo "  Service '$service_name' stopped."
        else
            echo "  Warning: Service '$service_name' still active after stop attempt."
        fi
    else
        echo "  Service '$service_name' is not active."
    fi
    echo "  Disabling service '$service_name' to prevent automatic restart."
    systemctl disable "$service_name" > /dev/null 2>&1
}

ensure_log_directories() {
    echo "Ensuring log directory /var/log exists..."
    if [[ ! -d "/var/log" ]]; then
        mkdir -p "/var/log"
        if [[ $? -ne 0 ]]; then
            echo "Error: Could not create /var/log. Check permissions or disk space."
            exit 1
        fi
    fi
}

# --- Main Script Logic ---
echo "--- Starting ADSB and GPS Logger Management Script ---"
ensure_log_directories

echo ""
echo "--- Step 1: Stopping existing processes and services ---"

if [[ $START_GPS -eq 1 ]]; then
    kill_process_by_name "gpsd"
    stop_and_disable_service "gpsd.socket"
    stop_and_disable_service "gpsd"
    kill_process_by_pattern "GPS logger" "$GPS_LOGGER_SCRIPT"
fi

if [[ $START_ADSB -eq 1 ]]; then
    kill_process_by_name "dump1090"
    kill_process_by_pattern "ADSB logger (Python)" "$ADSB_LOGGER_SCRIPT"
    kill_process_by_pattern "ADSB logger (legacy Perl)" "$LEGACY_ADSB_PATTERN"
fi

echo "--- Finished stopping processes ---"

echo ""
echo "--- Step 2: Starting Services and Loggers ---"

if [[ $START_GPS -eq 1 ]]; then
    echo "Starting gpsd manually..."
    nohup gpsd -n -F /tmp/gpsd.sock /dev/serial0 > "$GPSD_LOG" 2>&1 &
    echo "  gpsd started. Log: $GPSD_LOG"
    sleep 2
fi

if [[ $START_ADSB -eq 1 ]]; then
    echo "Starting dump1090-mutability manually..."
    nohup dump1090 --net --gain -1 --mlat --sbs-port 30003 > "$DUMP1090_LOG" 2>&1 &
    echo "  dump1090-mutability started. Log: $DUMP1090_LOG"
    sleep 5
fi

if [[ $START_ADSB -eq 1 ]]; then
    adsb_cmd=(python3 "$ADSB_LOGGER_SCRIPT")
    if [[ -n "$ADSB_SESSION_ID" ]]; then
        adsb_cmd+=(--session-id "$ADSB_SESSION_ID")
    fi
    if [[ -n "$ADSB_RUN_SECONDS" ]]; then
        adsb_cmd+=(--run-seconds "$ADSB_RUN_SECONDS")
    fi

    echo "Starting ADSB logger (gatherTCPcompress.py)..."
    nohup "${adsb_cmd[@]}" > "$ADSB_LOGGER_LOG" 2>&1 &
    echo "  ADSB logger started. Log: $ADSB_LOGGER_LOG"
fi

if [[ $START_GPS -eq 1 ]]; then
    echo "Starting GPS logger (gatherNMEAcompress.py)..."
    nohup python3 "$GPS_LOGGER_SCRIPT" > "$GPS_LOGGER_LOG" 2>&1 &
    echo "  GPS logger started. Log: $GPS_LOGGER_LOG"
fi

echo ""
echo "--- All requested services and loggers have been initiated. ---"
echo "Working directory: $SCRIPT_DIR"
if [[ -n "$ADSB_SESSION_ID" ]]; then
    echo "ADS-B session ID: $ADSB_SESSION_ID"
fi
if [[ -n "$ADSB_RUN_SECONDS" ]]; then
    echo "ADS-B run duration: $ADSB_RUN_SECONDS s"
fi
echo "You can check status with 'ps aux | grep <process_name>' or 'tail -f /var/log/<logfile>'."
echo "Script finished."
