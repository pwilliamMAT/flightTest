#!/bin/bash

# --- Configuration ---
# Absolute path to your Python and Perl scripts
GPS_LOGGER_SCRIPT="/home/pi2/flightTest/ADSB_GPS/gatherNMEAcompress.py"
ADSB_LOGGER_SCRIPT="/home/pi2/flightTest/ADSB_GPS/1928d043d6e4b19e0aef498c6055b74f/gatherTCPcompress.pl"

# Log files for the nohup processes
GPSD_LOG="/var/log/gpsd_startup.log"
DUMP1090_LOG="/var/log/dump1090_startup.log"
GPS_LOGGER_LOG="/var/log/adsb_logger.log" # Your NMEA logger from before
ADSB_LOGGER_LOG="/var/log/nmea_logger.log" # Your TCP logger from before (note: you called this nmea_logger.log earlier)

# --- Functions ---

# Function to check if a process is running
is_running() {
    pgrep -x "$1" > /dev/null
}

# Function to check if a systemd service is active
is_service_active() {
    systemctl is-active --quiet "$1"
}

# Function to kill processes by name
kill_process_by_name() {
    PROCESS_NAME="$1"
    echo "Checking for existing '$PROCESS_NAME' processes..."
    PIDS=$(pgrep -x "$PROCESS_NAME")
    if [ -n "$PIDS" ]; then
        echo "  Found PIDs: $PIDS. Attempting graceful kill..."
        kill $PIDS
        sleep 3 # Give it a moment to shut down
        PIDS_AFTER_KILL=$(pgrep -x "$PROCESS_NAME")
        if [ -n "$PIDS_AFTER_KILL" ]; then
            echo "  '$PROCESS_NAME' did not terminate gracefully. Force killing (kill -9) PIDs: $PIDS_AFTER_KILL"
            kill -9 $PIDS_AFTER_KILL
            sleep 1
        else
            echo "  '$PROCESS_NAME' terminated gracefully."
        fi
    else
        echo "  No '$PROCESS_NAME' processes found."
    fi
}

# Function to stop and disable a systemd service
stop_and_disable_service() {
    SERVICE_NAME="$1"
    echo "Checking status of service: $SERVICE_NAME"
    if is_service_active "$SERVICE_NAME"; then
        echo "  Service '$SERVICE_NAME' is active. Stopping..."
        systemctl stop "$SERVICE_NAME"
        sleep 2
        if ! is_service_active "$SERVICE_NAME"; then
            echo "  Service '$SERVICE_NAME' stopped."
        else
            echo "  Warning: Service '$SERVICE_NAME' still active after stop attempt."
        fi
    else
        echo "  Service '$SERVICE_NAME' is not active."
    fi
    echo "  Disabling service '$SERVICE_NAME' to prevent automatic restart (if manually starting)."
    systemctl disable "$SERVICE_NAME" > /dev/null 2>&1 # Disable quietly
}

# Function to ensure log directories exist
ensure_log_directories() {
    echo "Ensuring log directory /var/log exists..."
    if [ ! -d "/var/log" ]; then
        mkdir -p "/var/log"
        if [ $? -ne 0 ]; then
            echo "Error: Could not create /var/log. Check permissions or disk space."
            exit 1
        fi
    fi
}


# --- Main Script Logic ---
echo "--- Starting ADSB and GPS Logger Management Script ---"
ensure_log_directories

# 1. Kill existing processes and stop services
echo ""
echo "--- Step 1: Stopping existing processes and services ---"

# Kill custom gpsd instance if running (from your manual start 'gpsd -n -F /tmp/gpsd.sock /dev/serial0 &')
kill_process_by_name "gpsd"

# Stop systemd gpsd services (if any are active)
stop_and_disable_service "gpsd.socket"
stop_and_disable_service "gpsd"

# Kill custom dump1090-mutability instance if running (from your manual nohup start)
kill_process_by_name "dump1090"

# Kill your logger scripts if they are still running from a previous invocation
kill_process_by_name "python3" # Will catch gatherNMEAcompress.py
kill_process_by_name "perl"    # Will catch gatherTCPcompress.pl

echo "--- Finished stopping processes ---"

echo ""
echo "--- Step 2: Starting Services and Loggers ---"

# 3. Start gpsd in the background
echo "Starting gpsd manually..."
# Your manual start: gpsd -n -F /tmp/gpsd.sock /dev/serial0 &
# Use nohup for persistence and redirect its stdout/stderr to a log file
nohup gpsd -n -F /tmp/gpsd.sock /dev/serial0 > "$GPSD_LOG" 2>&1 &
echo "  gpsd started. Log: $GPSD_LOG"
sleep 2 # Give gpsd a moment to start up

# 4. Start dump1090-mutability in the background
echo "Starting dump1090-mutability manually..."
# Your manual start: sudo sh -c 'nohup dump1090 --net --gain -1 --mlat --sbs-port 30003 > /var/log/dump1090.log 2>&1 &'
nohup dump1090 --net --gain -1 --mlat --sbs-port 30003 > "$DUMP1090_LOG" 2>&1 &
echo "  dump1090-mutability started. Log: $DUMP1090_LOG"
sleep 5 # Give dump1090 a bit more time to get going

# 5. Start gatherTCPcompress.pl (ADSB logger) in the background
echo "Starting ADSB logger (gatherTCPcompress.pl)..."
nohup "$ADSB_LOGGER_SCRIPT" > "$ADSB_LOGGER_LOG" 2>&1 &
echo "  ADSB logger started. Log: $ADSB_LOGGER_LOG"

# 6. Start gatherNMEAcompress.py (GPS logger) in the background
echo "Starting GPS logger (gatherNMEAcompress.py)..."
nohup "$GPS_LOGGER_SCRIPT" > "$GPS_LOGGER_LOG" 2>&1 &
echo "  GPS logger started. Log: $GPS_LOGGER_LOG"

echo ""
echo "--- All services and loggers have been initiated. ---"
echo "You can check their status with 'ps aux | grep <process_name>' or 'tail -f /var/log/your_log_file.log'"
echo "Script finished."
