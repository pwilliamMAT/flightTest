#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REMOTE_USER="${USER:-}"
REMOTE_HOST=""
SESSION_ID=""
REMOTE_ROOT="~/agenticProjects/flightTest/captures"
LOCAL_ROOT="$REPO_ROOT/captures"
RSYNC_BIN="rsync"
SSH_BIN="ssh"
MATLAB_BIN="matlab"
MATLAB_LAUNCH_BIN=""
ASK_ANALYSIS=1

SSH_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

usage() {
    cat <<EOF
Usage: bash TestSetupTesting/sync_capture_session.sh --host <testing-machine> --session-id <id> [options]

Options:
  --host <host>               Testing machine hostname or IP (required)
  --session-id <id>           Session ID to pull (required)
  --user <user>               SSH username on the testing machine (default: current user)
  --remote-root <path>        Remote capture root (default: ~/agenticProjects/flightTest/captures)
  --dest <path>               Local dataset root (default: <repo>/captures)
  --rsync-bin <path>          rsync executable (default: rsync)
  --ssh-bin <path>            SSH executable (default: ssh)
  --matlab-bin <path>         MATLAB executable for optional analysis launch (default: matlab)
  --ask-analysis              Prompt to launch analysis after sync (default in interactive shells)
  --no-ask-analysis           Do not prompt; print the analysis command instead
  -h, --help                  Show this help text
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

resolve_matlab_launch_bin() {
    local candidate=""

    if [[ -n "$MATLAB_LAUNCH_BIN" ]]; then
        return 0
    fi

    if [[ -x "$MATLAB_BIN" ]]; then
        MATLAB_LAUNCH_BIN="$MATLAB_BIN"
        return 0
    fi

    set +e
    candidate="$(command -v "$MATLAB_BIN" 2>/dev/null)"
    local status=$?
    set -e
    if [[ $status -eq 0 && -n "$candidate" ]]; then
        MATLAB_LAUNCH_BIN="$candidate"
        return 0
    fi

    if [[ "$OSTYPE" == darwin* ]]; then
        for candidate in /Applications/MATLAB*.app/bin/matlab; do
            if [[ "$candidate" == "/Applications/MATLAB*.app/bin/matlab" ]]; then
                continue
            fi
            if [[ -x "$candidate" ]]; then
                MATLAB_LAUNCH_BIN="$candidate"
            fi
        done
        if [[ -n "$MATLAB_LAUNCH_BIN" ]]; then
            return 0
        fi
    fi

    return 1
}

build_analysis_matlab_command() {
    printf "cd(%s); out = runBistaticAnalysisSession(%s);" \
        "$(quote_matlab_string "$REPO_ROOT/BistaticDataAnalysis")" \
        "$(quote_matlab_string "$SESSION_ID")"
}

print_analysis_commands() {
    local matlab_cmd=""

    matlab_cmd="$(build_analysis_matlab_command)"

    if resolve_matlab_launch_bin; then
        echo "Analysis command from a terminal on this machine:"
        printf "  %s -batch %s\n" "$(printf '%q' "$MATLAB_LAUNCH_BIN")" "$(printf '%q' "$matlab_cmd")"
    else
        echo "Terminal MATLAB launch is not configured on this shell."
        if [[ "$OSTYPE" == darwin* ]]; then
            echo "If MATLAB is installed on macOS, rerun with --matlab-bin /Applications/MATLAB_R20xx?.app/bin/matlab or add matlab to PATH."
        else
            echo "Rerun with --matlab-bin <path-to-matlab> or add matlab to PATH."
        fi
    fi
    echo "From inside MATLAB:"
    printf "  cd(%s)\n" "$(quote_matlab_string "$REPO_ROOT/BistaticDataAnalysis")"
    printf "  out = runBistaticAnalysisSession(%s)\n" "$(quote_matlab_string "$SESSION_ID")"
}

launch_analysis() {
    local matlab_cmd=""

    matlab_cmd="$(build_analysis_matlab_command)"
    if ! resolve_matlab_launch_bin; then
        echo "MATLAB auto-launch skipped: '$MATLAB_BIN' was not found."
        if [[ "$OSTYPE" == darwin* ]]; then
            echo "On macOS, pass --matlab-bin /Applications/MATLAB_R20xx?.app/bin/matlab if MATLAB is installed outside PATH."
        else
            echo "Pass --matlab-bin <path-to-matlab> if MATLAB is installed outside PATH."
        fi
        print_analysis_commands
        return 0
    fi

    if [[ "$MATLAB_LAUNCH_BIN" != "$MATLAB_BIN" ]]; then
        echo "Using MATLAB executable: $MATLAB_LAUNCH_BIN"
    fi
    echo "Launching MATLAB analysis for session $SESSION_ID ..."
    "$MATLAB_LAUNCH_BIN" -batch "$matlab_cmd"
}

prompt_for_analysis() {
    local reply=""

    printf "Run analysis for %s now? [y/N] " "$SESSION_ID"
    if ! IFS= read -r reply; then
        reply=""
    fi
    case "$reply" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REMOTE_HOST="$2"
            shift 2
            ;;
        --session-id)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SESSION_ID="$2"
            shift 2
            ;;
        --user)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REMOTE_USER="$2"
            shift 2
            ;;
        --remote-root)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            REMOTE_ROOT="$2"
            shift 2
            ;;
        --dest)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            LOCAL_ROOT="$2"
            shift 2
            ;;
        --rsync-bin)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            RSYNC_BIN="$2"
            shift 2
            ;;
        --ssh-bin)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            SSH_BIN="$2"
            shift 2
            ;;
        --matlab-bin)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            MATLAB_BIN="$2"
            shift 2
            ;;
        --ask-analysis)
            ASK_ANALYSIS=1
            shift
            ;;
        --no-ask-analysis)
            ASK_ANALYSIS=0
            shift
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

[[ -n "$REMOTE_HOST" ]] || die "--host is required."
[[ -n "$SESSION_ID" ]] || die "--session-id is required."
[[ -n "$REMOTE_USER" ]] || die "--user is empty; pass --user explicitly if your shell USER variable is unavailable."

REMOTE_TARGET="$REMOTE_USER@$REMOTE_HOST"
REMOTE_SESSION_DIR="$REMOTE_ROOT/$SESSION_ID"
LOCAL_SESSION_DIR="$LOCAL_ROOT/$SESSION_ID"
REMOTE_MANIFEST="$REMOTE_SESSION_DIR/session_manifest.json"

echo "Preflight: verifying remote session $SESSION_ID on $REMOTE_TARGET ..."
set +e
probe_output="$("$SSH_BIN" "${SSH_OPTIONS[@]}" "$REMOTE_TARGET" "bash -lc $(quote_posix_arg "test -d $REMOTE_SESSION_DIR && test -f $REMOTE_MANIFEST && printf READY")" 2>&1)"
probe_status=$?
set -e
if [[ $probe_status -ne 0 ]]; then
    die "SSH preflight failed for $REMOTE_TARGET. If the testing-machine username differs from your local username, pass --user <testing-user>. SSH output: $probe_output"
fi
if [[ "$probe_output" != *"READY"* ]]; then
    die "Remote session folder or manifest not found at $REMOTE_SESSION_DIR."
fi

mkdir -p "$LOCAL_ROOT"
echo "Syncing $REMOTE_TARGET:$REMOTE_SESSION_DIR/ -> $LOCAL_SESSION_DIR/"
echo "Note: large radar captures can take several minutes to transfer, and rsync may appear quiet while it copies radar files."
"$RSYNC_BIN" -av -C -e "$SSH_BIN ${SSH_OPTIONS[*]}" "$REMOTE_TARGET:$REMOTE_SESSION_DIR/" "$LOCAL_SESSION_DIR/"

[[ -d "$LOCAL_SESSION_DIR" ]] || die "Local sync completed but the session folder is missing: $LOCAL_SESSION_DIR"
[[ -f "$LOCAL_SESSION_DIR/session_manifest.json" ]] || die "Local sync completed but session_manifest.json is missing in $LOCAL_SESSION_DIR"

echo "SESSION_ID=$SESSION_ID"
echo "LOCAL_SESSION_DIR=$LOCAL_SESSION_DIR"
echo "LOCAL_MANIFEST=$LOCAL_SESSION_DIR/session_manifest.json"

if [[ $ASK_ANALYSIS -eq 1 && -t 0 && -t 1 ]]; then
    if prompt_for_analysis; then
        launch_analysis
    else
        print_analysis_commands
    fi
else
    print_analysis_commands
fi
