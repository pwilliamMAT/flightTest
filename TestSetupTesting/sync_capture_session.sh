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
"$SSH_BIN" "${SSH_OPTIONS[@]}" "$REMOTE_TARGET" "bash -lc $(quote_posix_arg "test -d $REMOTE_SESSION_DIR && test -f $REMOTE_MANIFEST && printf READY")"
probe_status=$?
set -e
if [[ $probe_status -ne 0 ]]; then
    die "Remote session folder or manifest not found at $REMOTE_SESSION_DIR."
fi

mkdir -p "$LOCAL_ROOT"
echo "Syncing $REMOTE_TARGET:$REMOTE_SESSION_DIR/ -> $LOCAL_SESSION_DIR/"
"$RSYNC_BIN" -av -C -e "$SSH_BIN ${SSH_OPTIONS[*]}" "$REMOTE_TARGET:$REMOTE_SESSION_DIR/" "$LOCAL_SESSION_DIR/"

[[ -d "$LOCAL_SESSION_DIR" ]] || die "Local sync completed but the session folder is missing: $LOCAL_SESSION_DIR"
[[ -f "$LOCAL_SESSION_DIR/session_manifest.json" ]] || die "Local sync completed but session_manifest.json is missing in $LOCAL_SESSION_DIR"

echo "SESSION_ID=$SESSION_ID"
echo "LOCAL_SESSION_DIR=$LOCAL_SESSION_DIR"
echo "LOCAL_MANIFEST=$LOCAL_SESSION_DIR/session_manifest.json"
