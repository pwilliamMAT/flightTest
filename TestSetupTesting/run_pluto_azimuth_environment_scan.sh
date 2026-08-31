#!/usr/bin/env bash
# RUN_PLUTO_AZIMUTH_ENVIRONMENT_SCAN Launch the operator-guided azimuth scan.
#
# Usage:
#   ./run_pluto_azimuth_environment_scan.sh [options]
#
# Options:
#   -n, --num-steps VALUE          Number of clockwise azimuth steps. Default: 8.
#   -c, --capture-seconds VALUE    Capture duration per bearing in seconds. Default: 4.
#   -p, --pulse-seconds VALUE      Pluto calibration pulse duration in seconds. Default: 1.0.
#       --pulse-start-seconds VALUE
#                                  Delay from capture start to Pluto pulse in seconds. Default: 0.5.
#   -i, --scan-id VALUE            Output folder/session name. Default: az_scan_XXsteps_YYsecs_JJJJHHMM.
#   -a, --auto-confirm VALUE       true/false/auto. Use true/auto for remote debug without prompts. Default: false.
#   -h, --help                     Show this help text.
#
# Examples:
#   ./run_pluto_azimuth_environment_scan.sh
#   ./run_pluto_azimuth_environment_scan.sh -n 12 -c 4 -p 1.0
#   ./run_pluto_azimuth_environment_scan.sh --num-steps 24 --capture-seconds 6 --scan-id roof_scan_24pt
#   ./run_pluto_azimuth_environment_scan.sh -n 4 -c 5 -i az_remote_debug -a auto
#
# The default scan id uses JJJJHHMM, where JJJJ is YDDD: the last digit of the
# local year plus the 3-digit Julian day of year, followed by local HHMM.
#
# The script intentionally uses MATLAB -nodisplay/-r instead of -batch so
# command-line input() prompts remain available while the operator rotates
# the directional antenna.

set -euo pipefail

DEFAULT_STEPS=8
DEFAULT_CAPTURE_SECONDS=4
DEFAULT_PULSE_SECONDS=1.0
DEFAULT_PULSE_START_SECONDS=0.5

STEPS="${DEFAULT_STEPS}"
CAPTURE_SECONDS="${DEFAULT_CAPTURE_SECONDS}"
PULSE_SECONDS="${DEFAULT_PULSE_SECONDS}"
PULSE_START_SECONDS="${DEFAULT_PULSE_START_SECONDS}"
SCAN_ID=""
AUTO_CONFIRM="${AZIMUTH_AUTO_CONFIRM:-false}"

usage() {
    sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
}

fail_usage() {
    echo "ERROR: $1" >&2
    echo >&2
    usage >&2
    exit 2
}

require_value() {
    local option_name="$1"
    local option_value="${2:-}"
    if [[ -z "${option_value}" || "${option_value}" == -* ]]; then
        fail_usage "${option_name} requires a value."
    fi
}

format_count_label() {
    printf "%02d" "$((10#$1))"
}

format_duration_label() {
    local value="$1"
    if [[ "${value}" =~ ^[0-9]+$ ]]; then
        printf "%02d" "$((10#${value}))"
    else
        local label="${value//./p}"
        label="${label//[^A-Za-z0-9_-]/_}"
        printf "%s" "${label}"
    fi
}

default_scan_id() {
    local year_digit
    local julian_day
    local hhmm
    year_digit="$(date +%Y)"
    year_digit="${year_digit: -1}"
    julian_day="$(date +%j)"
    hhmm="$(date +%H%M)"
    printf "az_scan_%ssteps_%ssecs_%s%s%s" \
        "$(format_count_label "${STEPS}")" \
        "$(format_duration_label "${CAPTURE_SECONDS}")" \
        "${year_digit}" "${julian_day}" "${hhmm}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--num-steps)
            require_value "$1" "${2:-}"
            STEPS="$2"
            shift 2
            ;;
        -c|--capture-seconds)
            require_value "$1" "${2:-}"
            CAPTURE_SECONDS="$2"
            shift 2
            ;;
        -p|--pulse-seconds)
            require_value "$1" "${2:-}"
            PULSE_SECONDS="$2"
            shift 2
            ;;
        --pulse-start-seconds)
            require_value "$1" "${2:-}"
            PULSE_START_SECONDS="$2"
            shift 2
            ;;
        -i|--scan-id)
            require_value "$1" "${2:-}"
            SCAN_ID="$2"
            shift 2
            ;;
        -a|--auto-confirm)
            require_value "$1" "${2:-}"
            AUTO_CONFIRM="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail_usage "Unknown option: $1"
            ;;
    esac
done

if ! [[ "${STEPS}" =~ ^[0-9]+$ ]] || [[ "$((10#${STEPS}))" -lt 1 ]]; then
    fail_usage "--num-steps must be a positive integer."
fi

if ! [[ "${CAPTURE_SECONDS}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    fail_usage "--capture-seconds must be numeric."
fi

if [[ "${CAPTURE_SECONDS}" =~ ^0+([.]0+)?$ ]]; then
    fail_usage "--capture-seconds must be greater than zero."
fi

if ! [[ "${PULSE_SECONDS}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    fail_usage "--pulse-seconds must be numeric."
fi

if [[ "${PULSE_SECONDS}" =~ ^0+([.]0+)?$ ]]; then
    fail_usage "--pulse-seconds must be greater than zero."
fi

if ! [[ "${PULSE_START_SECONDS}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    fail_usage "--pulse-start-seconds must be numeric."
fi

if ! awk -v capture="${CAPTURE_SECONDS}" -v pulse="${PULSE_SECONDS}" -v start="${PULSE_START_SECONDS}" \
    'BEGIN { exit !((start + pulse) <= capture) }'; then
    fail_usage "pulse start plus pulse duration must fit inside capture duration."
fi

if [[ -z "${SCAN_ID}" ]]; then
    SCAN_ID="$(default_scan_id)"
fi

if ! [[ "${SCAN_ID}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    fail_usage "--scan-id may only contain letters, numbers, underscore, dash, and dot."
fi

case "${AUTO_CONFIRM,,}" in
    true|1|yes|y|auto|no-prompt|noprompt)
        AUTO_CONFIRM_ARG=", 'AutoConfirm', true"
        ;;
    false|0|no|n|"")
        AUTO_CONFIRM_ARG=""
        ;;
    *)
        fail_usage "--auto-confirm must be true/false or auto."
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

SESSION_ARG=", 'SessionID', '${SCAN_ID}'"

MATLAB_COMMAND="try, scan = runPlutoAzimuthEnvironmentalScan('NumAzimuthSteps', ${STEPS}, 'CaptureDuration_s', ${CAPTURE_SECONDS}, 'PulseDuration_s', ${PULSE_SECONDS}, 'PulseStartDelay_s', ${PULSE_START_SECONDS}${SESSION_ARG}${AUTO_CONFIRM_ARG}, 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); disp(scan.artifact_paths.html); catch me, disp(getReport(me, 'extended', 'hyperlinks', 'off')); exit(1); end; exit(0);"

echo "Launching Pluto azimuth environmental scan..."
echo "  steps:           ${STEPS}"
echo "  capture seconds: ${CAPTURE_SECONDS}"
echo "  pulse seconds:   ${PULSE_SECONDS}"
echo "  pulse start:     ${PULSE_START_SECONDS}"
echo "  scan id:         ${SCAN_ID}"
if [[ -n "${AUTO_CONFIRM_ARG}" ]]; then
    echo "  operator prompt: auto-confirmed"
else
    echo "  operator prompt: wait for Enter at each bearing"
fi
echo

matlab -nodisplay -nosplash -r "${MATLAB_COMMAND}"
