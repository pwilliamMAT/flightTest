#!/usr/bin/env bash
# RUN_PLUTO_AZIMUTH_ENVIRONMENT_SCAN Launch the operator-guided azimuth scan.
#
# Usage:
#   ./run_pluto_azimuth_environment_scan.sh [steps] [capture_seconds] [scan_id]
#
# Examples:
#   ./run_pluto_azimuth_environment_scan.sh
#   ./run_pluto_azimuth_environment_scan.sh 8 10
#   ./run_pluto_azimuth_environment_scan.sh 16 20 roof_scan_20260806
#
# The script intentionally uses MATLAB -nodisplay/-r instead of -batch so
# command-line input() prompts remain available while the operator rotates
# the directional antenna.

set -euo pipefail

STEPS="${1:-8}"
CAPTURE_SECONDS="${2:-10}"
SCAN_ID="${3:-}"

case "${STEPS}" in
    4|8|16)
        ;;
    *)
        echo "ERROR: steps must be 4, 8, or 16." >&2
        exit 2
        ;;
esac

if ! [[ "${CAPTURE_SECONDS}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "ERROR: capture_seconds must be numeric." >&2
    exit 2
fi

if [[ -n "${SCAN_ID}" ]] && ! [[ "${SCAN_ID}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "ERROR: scan_id may only contain letters, numbers, underscore, dash, and dot." >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ -n "${SCAN_ID}" ]]; then
    SESSION_ARG=", 'SessionID', '${SCAN_ID}'"
else
    SESSION_ARG=""
fi

MATLAB_COMMAND="try, scan = runPlutoAzimuthEnvironmentalScan('NumAzimuthSteps', ${STEPS}, 'CaptureDuration_s', ${CAPTURE_SECONDS}, 'PulseDuration_s', 0.2, 'PulseStartDelay_s', 0.5${SESSION_ARG}, 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); disp(scan.artifact_paths.html); catch me, disp(getReport(me, 'extended', 'hyperlinks', 'off')); exit(1); end; exit(0);"

echo "Launching Pluto azimuth environmental scan..."
echo "  steps:           ${STEPS}"
echo "  capture seconds: ${CAPTURE_SECONDS}"
if [[ -n "${SCAN_ID}" ]]; then
    echo "  scan id:         ${SCAN_ID}"
fi
echo

matlab -nodisplay -nosplash -r "${MATLAB_COMMAND}"
