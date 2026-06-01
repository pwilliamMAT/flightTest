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

import sys
import socket
import subprocess
import time
import gzip
import threading
import os
import glob
from collections import deque, OrderedDict
from datetime import datetime


def gzip_file(filename):
    """Compress a file with gzip and remove the original."""
    gz_name = filename + ".gz"
    try:
        with open(filename, "rb") as f_in, gzip.open(
            gz_name, "wb", compresslevel=9
        ) as f_out:
            f_out.writelines(f_in)
        os.remove(filename)
    except Exception as e:
        print(f"\ngzip error on {filename}: {e}")


def rsync_file(gz_path, dest):
    """rsync a single file to dest. Returns True on success."""
    try:
        result = subprocess.run(
            ["rsync", "-az", "--remove-source-files", gz_path, dest],
            capture_output=True, timeout=120
        )
        if result.returncode == 0:
            print(f"\nrsync OK: {os.path.basename(gz_path)} → {dest}")
            return True
        else:
            print(f"\nrsync FAIL ({result.returncode}): {result.stderr.decode().strip()}")
            return False
    except Exception as e:
        print(f"\nrsync error: {e}")
        return False


def rclone_file(gz_path, remote):
    """rclone copy a single file to remote. Returns True on success."""
    try:
        result = subprocess.run(
            ["rclone", "copy", gz_path, remote, "--no-traverse"],
            capture_output=True, timeout=300
        )
        if result.returncode == 0:
            print(f"\nrclone OK: {os.path.basename(gz_path)} → {remote}")
            return True
        else:
            print(f"\nrclone FAIL ({result.returncode}): {result.stderr.decode().strip()}")
            return False
    except FileNotFoundError:
        print("\nrclone not found — skipping cloud sync")
        return False
    except Exception as e:
        print(f"\nrclone error: {e}")
        return False


def print_progress(cnt):
    """Print progress similar to Perl script."""
    if cnt % 100 == 0:
        if cnt % 1000 == 0:
            if cnt % 3000 == 0:
                print(int((cnt % 10000) / 1000))
            else:
                print(int((cnt % 10000) / 1000), end="")
        else:
            print(".", end="")
        sys.stdout.flush()


def usage(argy):
    print("\nUsage: name.py [option: -flag value]\n")
    for k, v in argy.items():
        print(f"   {k} : {v[1]}  [{v[0]}]")
    sys.exit(1)


def scan_start_counter(filename):
    """Return the next available file counter by scanning existing gz files.

    Prevents overwriting data if the logger is restarted with the same
    base filename.
    """
    max_idx = -1
    for path in glob.glob(f"*_{filename}.gz"):
        try:
            idx = int(os.path.basename(path).split("_")[0])
            max_idx = max(max_idx, idx)
        except (ValueError, IndexError):
            pass
    return max_idx + 1  # 0 if no existing files found


def main():

    startup_ts = datetime.now().strftime("%Y%m%d_%H%M%S")

    argy = {
        "-s": ["127.0.0.1",  "Host IP running Server"],
        "-p": [30003,         "TCP Port of service on server"],
        "-L": ["localhost",   "local IP"],
        "-h": ["",            "this help"],
        "-f": [f"adsb_{startup_ts}.txt", "Base filename (session identifier)"],
        "-t": [2000000,       "Duration per file (seconds)"],
        "-l": [200000,        "Lines per file"],
        "-n": [500,           "Minimum free disk space (MB) before oldest file is deleted"],
        "-R": ["",            "rsync destination  e.g. user@host:/path/  (empty = disabled)"],
        "-C": ["",            "rclone remote path e.g. gdrive:bucket/dir (empty = disabled)"],
    }

    args = sys.argv[1:]
    if len(args) % 2 != 0 or "-h" in args:
        usage(argy)

    arglist = dict(zip(args[0::2], args[1::2]))

    server       = arglist.get("-s", argy["-s"][0])
    port         = int(arglist.get("-p", argy["-p"][0]))
    host         = arglist.get("-L", argy["-L"][0])
    filename     = arglist.get("-f", argy["-f"][0])
    spf          = int(arglist.get("-t", argy["-t"][0]))
    lpf          = int(arglist.get("-l", argy["-l"][0]))
    min_free_mb  = int(arglist.get("-n", argy["-n"][0]))
    rsync_dest   = arglist.get("-R", argy["-R"][0])
    rclone_dest  = arglist.get("-C", argy["-C"][0])

    # Advance counter past any pre-existing files to prevent overwriting
    filecounter = scan_start_counter(filename)
    if filecounter > 0:
        print(f"Existing files found; resuming from index {filecounter}")

    print(f"server:{server}  port:{port}  host:{host}")
    print(f" base filename:{filename}  lpf:{lpf}  min_free_disk:{min_free_mb} MB")
    print(f" rsync dest : {rsync_dest  or '(disabled)'}")
    print(f" rclone dest: {rclone_dest or '(disabled)'}")

    # Create socket and connect
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.connect((server, port))
    except Exception as e:
        print(f"Can't connect to port {port} on {server}! {e}")
        sys.exit(1)

    startTime = time.time()
    cnt = 0
    files_this_session = 0
    fh = None
    fn = None

    # sync_status: OrderedDict  gz_path -> {'rsync': bool, 'rclone': bool}
    # Ordered so popleft() gives the oldest file.
    sync_status = OrderedDict()
    status_lock = threading.Lock()

    def free_mb(path="."):
        st = os.statvfs(path)
        return (st.f_bavail * st.f_frsize) / (1024 * 1024)

    def purge_if_needed():
        """Delete oldest synced files first when disk is low."""
        if free_mb() >= min_free_mb:
            return
        with status_lock:
            candidates = list(sync_status.items())

        def sync_score(item):
            st = item[1]
            # Higher score = safer to delete (more copies exist)
            return (1 if (not rsync_dest  or st["rsync"])  else 0) + \
                   (1 if (not rclone_dest or st["rclone"]) else 0)

        # Sort by ascending score (unsafest last), then delete from safest
        candidates.sort(key=lambda x: -sync_score(x))
        for gz_path, st in candidates:
            if free_mb() >= min_free_mb:
                break
            if not os.path.exists(gz_path):
                with status_lock:
                    sync_status.pop(gz_path, None)
                continue
            score = sync_score((gz_path, st))
            label = "fully synced" if score == 2 else \
                    "partially synced" if score == 1 else "NOT YET SYNCED"
            print(f"\nDisk low ({free_mb():.0f} MB free) [{label}] — deleting: {gz_path}")
            try:
                os.remove(gz_path)
                with status_lock:
                    sync_status.pop(gz_path, None)
            except Exception as e:
                print(f"Failed to delete {gz_path}: {e}")

    def compress_and_sync(src):
        """Background thread: gzip, then rsync+rclone, then purge if needed."""
        gzip_file(src)
        gz_path = src + ".gz"

        with status_lock:
            sync_status[gz_path] = {"rsync": False, "rclone": False}

        # rsync: transfers AND removes the local file on success
        rsync_ok = False
        if rsync_dest:
            rsync_ok = rsync_file(gz_path, rsync_dest)
            if rsync_ok:
                # rsync --remove-source-files already deleted the local copy
                with status_lock:
                    sync_status[gz_path]["rsync"] = True
                    sync_status[gz_path]["rclone"] = True  # local gone; treat as safe
                purge_if_needed()
                return  # nothing left to do locally

        # rclone: copies to cloud, local file kept
        if rclone_dest:
            rclone_ok = rclone_file(gz_path, rclone_dest)
            with status_lock:
                if gz_path in sync_status:
                    sync_status[gz_path]["rclone"] = rclone_ok

        purge_if_needed()

    def open_next_file():
        nonlocal fn, fh, filecounter, files_this_session
        file_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        fn = f"{filecounter}_{file_ts}_{filename}"
        print(f"\nstarting: {fn}")
        fh = open(fn, "w")
        files_this_session += 1

    def rotate():
        nonlocal fh, filecounter
        fh.close()
        threading.Thread(
            target=compress_and_sync, args=(fn,), daemon=True
        ).start()
        filecounter += 1

    try:
        while True:
            data = s.recv(4096)
            if not data:
                break

            lines = data.decode(errors="ignore").split("\n")
            for line in lines:
                line = line.rstrip("\r\n")

                should_rotate = (
                    fh is None
                    or (cnt > 0 and cnt % lpf == 0)
                    or int((time.time() - startTime) / spf) >= files_this_session
                )

                if should_rotate:
                    if fh is not None:
                        rotate()
                    open_next_file()
                else:
                    print_progress(cnt)

                fh.write(line + "\n")
                cnt += 1

    finally:
        if fh is not None and not fh.closed:
            fh.close()
        s.close()
        if fn and os.path.exists(fn) and os.path.getsize(fn) > 0:
            threading.Thread(
                target=compress_and_sync, args=(fn,), daemon=True
            ).start()


if __name__ == "__main__":
    main()
