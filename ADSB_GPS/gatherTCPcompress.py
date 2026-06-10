#!/usr/bin/env python3
#
# Sync destinations (configure before use):
#
#   rsync:  set -R to  user@host:/path/to/dest/
#           e.g.  -R pi@192.168.10.1:~/adsb_archive/
#           SSH key auth required (no password prompt).
#
#   rclone: set -C to  remote:bucket/path/
#           e.g.  -C gdrive:FlightTest/adsb/
#           Run `rclone config` on the Pi first to set up the remote.
#           rclone must be installed: sudo apt install rclone
#
# Deletion priority when disk is low:
#   1. Delete oldest file that has been successfully synced to BOTH destinations
#   2. Delete oldest file synced to at least one destination
#   3. Delete oldest file regardless (last resort)

import argparse
import glob
import gzip
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
from collections import OrderedDict
from datetime import datetime


SHUTDOWN_REQUESTED = False
SHUTDOWN_REASON = ""


def request_shutdown(reason):
    """Record the first shutdown request and let the main loop exit cleanly."""
    global SHUTDOWN_REQUESTED, SHUTDOWN_REASON
    if not SHUTDOWN_REQUESTED:
        print(f"\nShutdown requested: {reason}")
    SHUTDOWN_REQUESTED = True
    if not SHUTDOWN_REASON:
        SHUTDOWN_REASON = reason


def signal_handler(signum, _frame):
    """Translate POSIX signals into a cooperative shutdown request."""
    request_shutdown(f"signal {signum}")


def register_signal_handlers():
    """Register the signals that should stop capture gracefully."""
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    if hasattr(signal, "SIGBREAK"):
        signal.signal(signal.SIGBREAK, signal_handler)


def gzip_file(filename):
    """Compress a file with gzip and remove the original on success."""
    gz_name = filename + ".gz"
    try:
        with open(filename, "rb") as f_in, gzip.open(
            gz_name, "wb", compresslevel=9
        ) as f_out:
            shutil.copyfileobj(f_in, f_out)
        os.remove(filename)
        return gz_name
    except Exception as exc:
        print(f"\ngzip error on {filename}: {exc}")
        return None


def rsync_file(gz_path, dest):
    """rsync a single file to dest. Returns True on success."""
    try:
        result = subprocess.run(
            ["rsync", "-az", "--remove-source-files", gz_path, dest],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode == 0:
            print(f"\nrsync OK: {os.path.basename(gz_path)} -> {dest}")
            return True
        print(f"\nrsync FAIL ({result.returncode}): {result.stderr.strip()}")
        return False
    except Exception as exc:
        print(f"\nrsync error: {exc}")
        return False


def rclone_file(gz_path, remote):
    """rclone copy a single file to remote. Returns True on success."""
    try:
        result = subprocess.run(
            ["rclone", "copy", gz_path, remote, "--no-traverse"],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode == 0:
            print(f"\nrclone OK: {os.path.basename(gz_path)} -> {remote}")
            return True
        print(f"\nrclone FAIL ({result.returncode}): {result.stderr.strip()}")
        return False
    except FileNotFoundError:
        print("\nrclone not found - skipping cloud sync")
        return False
    except Exception as exc:
        print(f"\nrclone error: {exc}")
        return False


def print_progress(cnt):
    """Print progress similar to the legacy Perl logger."""
    if cnt % 100 == 0:
        if cnt % 1000 == 0:
            if cnt % 3000 == 0:
                print(int((cnt % 10000) / 1000))
            else:
                print(int((cnt % 10000) / 1000), end="")
        else:
            print(".", end="")
        sys.stdout.flush()


def scan_start_counter(filename):
    """Return the next file counter by scanning existing matching files."""
    max_idx = -1
    patterns = [f"*_{filename}", f"*_{filename}.gz"]
    for pattern in patterns:
        for path in glob.glob(pattern):
            try:
                idx = int(os.path.basename(path).split("_", 1)[0])
                max_idx = max(max_idx, idx)
            except (ValueError, IndexError):
                pass
    return max_idx + 1


def parse_args():
    """Parse CLI options while preserving the original short flags."""
    startup_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    parser = argparse.ArgumentParser(
        description=(
            "Capture SBS-1/BaseStation ADS-B messages from a TCP stream into "
            "rotating text files, then gzip and optionally sync them."
        )
    )
    parser.add_argument(
        "-s",
        "--server",
        default="127.0.0.1",
        help="Host IP running the SBS-1 TCP service (default: 127.0.0.1)",
    )
    parser.add_argument(
        "-p",
        "--port",
        type=int,
        default=30003,
        help="TCP port of the SBS-1 service (default: 30003)",
    )
    parser.add_argument(
        "-L",
        "--local-host",
        default="localhost",
        help="Local host label for logs (default: localhost)",
    )
    parser.add_argument(
        "-f",
        "--filename",
        default="",
        help="Base filename, e.g. adsb_capture.txt (default: auto-generated)",
    )
    parser.add_argument(
        "--session-id",
        default="",
        help="Session token used to build the default filename when -f is omitted",
    )
    parser.add_argument(
        "-t",
        "--time-per-file",
        type=float,
        default=2000000,
        help="Rotate to a new file after this many seconds (default: 2000000)",
    )
    parser.add_argument(
        "-l",
        "--lines-per-file",
        type=int,
        default=200000,
        help="Rotate to a new file after this many lines (default: 200000)",
    )
    parser.add_argument(
        "-n",
        "--min-free-mb",
        type=int,
        default=500,
        help="Minimum free disk space before old files are purged (default: 500)",
    )
    parser.add_argument(
        "-R",
        "--rsync-dest",
        default="",
        help="rsync destination, e.g. user@host:/path/ (default: disabled)",
    )
    parser.add_argument(
        "-C",
        "--rclone-dest",
        default="",
        help="rclone destination, e.g. remote:bucket/path (default: disabled)",
    )
    parser.add_argument(
        "--run-seconds",
        type=float,
        default=0.0,
        help="Stop capture after this many seconds; 0 means run until interrupted",
    )
    parser.add_argument(
        "--connect-timeout",
        type=float,
        default=5.0,
        help="Socket connect timeout in seconds (default: 5.0)",
    )
    parser.add_argument(
        "--recv-timeout",
        type=float,
        default=1.0,
        help="Socket receive timeout in seconds (default: 1.0)",
    )

    args = parser.parse_args()

    if not args.filename:
        if args.session_id:
            args.filename = f"adsb_{args.session_id}.txt"
        else:
            args.filename = f"adsb_{startup_ts}.txt"

    if args.time_per_file <= 0:
        parser.error("--time-per-file must be positive")
    if args.lines_per_file <= 0:
        parser.error("--lines-per-file must be positive")
    if args.min_free_mb < 0:
        parser.error("--min-free-mb must be non-negative")
    if args.connect_timeout <= 0 or args.recv_timeout <= 0:
        parser.error("socket timeouts must be positive")
    if args.run_seconds < 0:
        parser.error("--run-seconds must be non-negative")

    return args


def main():
    """Capture ADS-B text, rotate files, and exit cleanly on timeout or signal."""
    register_signal_handlers()
    args = parse_args()

    filecounter = scan_start_counter(args.filename)
    if filecounter > 0:
        print(f"Existing files found; resuming from index {filecounter}")

    print(f"server:{args.server}  port:{args.port}  host:{args.local_host}")
    print(
        f" base filename:{args.filename}  lpf:{args.lines_per_file}  "
        f"min_free_disk:{args.min_free_mb} MB"
    )
    if args.run_seconds > 0:
        print(f" run duration:{args.run_seconds:.1f} s")
    print(f" rsync dest : {args.rsync_dest or '(disabled)'}")
    print(f" rclone dest: {args.rclone_dest or '(disabled)'}")

    sync_status = OrderedDict()
    status_lock = threading.Lock()
    worker_threads = []

    def free_mb(path="."):
        usage = shutil.disk_usage(path)
        return usage.free / (1024 * 1024)

    def purge_if_needed():
        """Delete oldest synced files first when disk is low."""
        if free_mb() >= args.min_free_mb:
            return
        with status_lock:
            candidates = list(sync_status.items())

        def sync_score(item):
            st = item[1]
            return (1 if (not args.rsync_dest or st["rsync"]) else 0) + (
                1 if (not args.rclone_dest or st["rclone"]) else 0
            )

        candidates.sort(key=lambda item: -sync_score(item))
        for gz_path, st in candidates:
            if free_mb() >= args.min_free_mb:
                break
            if not os.path.exists(gz_path):
                with status_lock:
                    sync_status.pop(gz_path, None)
                continue
            score = sync_score((gz_path, st))
            if score == 2:
                label = "fully synced"
            elif score == 1:
                label = "partially synced"
            else:
                label = "NOT YET SYNCED"
            print(f"\nDisk low ({free_mb():.0f} MB free) [{label}] - deleting: {gz_path}")
            try:
                os.remove(gz_path)
                with status_lock:
                    sync_status.pop(gz_path, None)
            except Exception as exc:
                print(f"Failed to delete {gz_path}: {exc}")

    def compress_and_sync(src):
        """Gzip one file, then optionally rsync/rclone it."""
        gz_path = gzip_file(src)
        if gz_path is None:
            return src if os.path.exists(src) else None

        with status_lock:
            sync_status[gz_path] = {"rsync": False, "rclone": False}

        if args.rsync_dest:
            rsync_ok = rsync_file(gz_path, args.rsync_dest)
            if rsync_ok:
                with status_lock:
                    if gz_path in sync_status:
                        sync_status[gz_path]["rsync"] = True
                        sync_status[gz_path]["rclone"] = True
                purge_if_needed()
                return gz_path

        if args.rclone_dest:
            rclone_ok = rclone_file(gz_path, args.rclone_dest)
            with status_lock:
                if gz_path in sync_status:
                    sync_status[gz_path]["rclone"] = rclone_ok

        purge_if_needed()
        return gz_path

    def start_sync_thread(src):
        """Launch background gzip/sync work and keep the handle for join()."""
        thread = threading.Thread(target=compress_and_sync, args=(src,), daemon=False)
        worker_threads.append(thread)
        thread.start()

    current_handle = None
    current_filename = ""
    current_file_start = None
    current_file_lines = 0
    total_lines = 0
    saved_files = 0
    last_artifact_path = ""
    partial_tail_dropped = False

    def open_next_file():
        """Open the next capture file only when there is a complete line to write."""
        nonlocal current_handle, current_filename, current_file_start
        nonlocal current_file_lines
        file_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        current_filename = f"{filecounter}_{file_ts}_{args.filename}"
        print(f"\nstarting: {current_filename}")
        current_handle = open(current_filename, "w", encoding="utf-8", newline="\n")
        current_file_start = time.monotonic()
        current_file_lines = 0

    def close_current_file(sync_now):
        """Flush and preserve the current file, or delete it if it stayed empty."""
        nonlocal current_handle, current_filename, current_file_start
        nonlocal current_file_lines, saved_files, last_artifact_path

        if current_handle is None:
            return None

        current_handle.flush()
        os.fsync(current_handle.fileno())
        current_handle.close()

        size_bytes = os.path.getsize(current_filename) if os.path.exists(current_filename) else 0
        if size_bytes == 0:
            if os.path.exists(current_filename):
                os.remove(current_filename)
                print(f"\nRemoved empty file: {current_filename}")
            current_handle = None
            current_filename = ""
            current_file_start = None
            current_file_lines = 0
            return None

        saved_files += 1
        artifact_path = current_filename + ".gz"
        if sync_now:
            artifact_path = compress_and_sync(current_filename) or current_filename
        else:
            start_sync_thread(current_filename)
        last_artifact_path = artifact_path

        current_handle = None
        current_filename = ""
        current_file_start = None
        current_file_lines = 0
        return artifact_path

    sock = None
    recv_buffer = ""
    session_start = time.monotonic()

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(args.connect_timeout)
        sock.connect((args.server, args.port))
        sock.settimeout(args.recv_timeout)
    except Exception as exc:
        print(f"Can't connect to port {args.port} on {args.server}! {exc}")
        return 1

    try:
        while not SHUTDOWN_REQUESTED:
            if args.run_seconds > 0 and (time.monotonic() - session_start) >= args.run_seconds:
                request_shutdown("run-seconds expired")
                break

            try:
                chunk = sock.recv(4096)
            except socket.timeout:
                continue
            except OSError as exc:
                if not SHUTDOWN_REQUESTED:
                    request_shutdown(f"socket error: {exc}")
                break

            if not chunk:
                request_shutdown("remote socket closed")
                break

            recv_buffer += chunk.decode("utf-8", errors="ignore")
            lines = recv_buffer.split("\n")
            recv_buffer = lines.pop()

            for line in lines:
                if SHUTDOWN_REQUESTED:
                    break
                line = line.rstrip("\r")
                if not line:
                    continue

                should_rotate = (
                    current_handle is None
                    or current_file_lines >= args.lines_per_file
                    or (
                        current_file_start is not None
                        and (time.monotonic() - current_file_start) >= args.time_per_file
                    )
                )

                if should_rotate:
                    if current_handle is not None:
                        close_current_file(sync_now=False)
                        filecounter += 1
                    open_next_file()

                current_handle.write(line + "\n")
                current_file_lines += 1
                total_lines += 1
                print_progress(total_lines)
    finally:
        if recv_buffer:
            partial_tail_dropped = True

        if sock is not None:
            try:
                sock.close()
            except OSError:
                pass

        close_current_file(sync_now=True)

        for thread in worker_threads:
            thread.join()

    if partial_tail_dropped:
        print("\nDropped one trailing partial TCP record to avoid a truncated SBS-1 line.")

    print("\nCapture summary:")
    print(f"  shutdown reason : {SHUTDOWN_REASON or 'normal exit'}")
    print(f"  lines captured  : {total_lines}")
    print(f"  files preserved : {saved_files}")
    print(f"  final artifact  : {last_artifact_path or '(none)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
