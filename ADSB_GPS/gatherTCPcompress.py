#!/usr/bin/env python3

import sys
import socket
import time
import gzip
import threading
import os
from datetime import datetime


def gzip_file(filename):
    """Compress a file with gzip and remove original."""
    gz_name = filename + ".gz"
    with open(filename, "rb") as f_in, gzip.open(
        gz_name, "wb", compresslevel=9
    ) as f_out:
        f_out.writelines(f_in)
    os.remove(filename)


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


def main():

    formatted = datetime.now().strftime("%Y%m%d_%H%M%S")

    argy = {
        "-s": ["127.0.0.1", "Host IP running Server"],
        "-p": [30003, "TCP Port of service on server"],
        "-L": ["localhost", "local IP"],
        "-h": ["", "this help"],
        "-f": [f"adsb_{formatted}.txt", "filename of output"],
        "-t": [2000000, "duration per file(seconds)"],
        "-l": [200000, "Lines per file"],
        "-n": [50, "number of files to allow"],
    }

    args = sys.argv[1:]
    if len(args) % 2 != 0 or "-h" in args:
        usage(argy)

    # Build arglist dictionary from args (flag,value) pairs
    arglist = dict(zip(args[0::2], args[1::2]))

    server = arglist.get("-s", argy["-s"][0])
    port = int(arglist.get("-p", argy["-p"][0]))
    host = arglist.get("-L", argy["-L"][0])
    filename = arglist.get("-f", argy["-f"][0])
    spf = int(arglist.get("-t", argy["-t"][0]))  # seconds per file
    lpf = int(arglist.get("-l", argy["-l"][0]))  # lines per file
    numFile = int(arglist.get("-n", argy["-n"][0]))  # number of files to allow

    print(f"server:{server}  port:{port}  host:{host}")
    print(f" filename:{filename} lpf:{lpf}   Number of Files:{numFile}")

    # Create socket and connect
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.connect((server, port))
    except Exception as e:
        print(f"Can't connect to port {port} on {server}! {e}")
        sys.exit(1)

    startTime = time.time()
    cnt = 0
    filecounter = 0
    fn = filename
    fh = open(fn, "w")

    # Track files for deletion
    gz_files = []

    try:
        while True:
            data = s.recv(4096)
            if not data:
                break

            lines = data.decode(errors="ignore").split("\n")
            for line in lines:
                line = line.rstrip("\r\n")
                if (cnt % lpf == 0) or (
                    int((time.time() - startTime) / spf) > filecounter
                ):
                    if cnt > 0:
                        fh.close()

                        # Start gzip compression in a thread so it won't block
                        threading.Thread(
                            target=gzip_file, args=(fn,), daemon=True
                        ).start()

                        filecounter += 1

                        # Remove old gzipped files if too many
                        if filecounter > numFile:
                            old_file_index = filecounter - 1 - numFile
                            old_fn = f"{old_file_index}_{filename}.gz"
                            if os.path.exists(old_fn):
                                print(f"deleting: {old_fn}")
                                try:
                                    os.remove(old_fn)
                                except Exception as e:
                                    print(f"Failed to delete {old_fn}: {e}")

                    fn = f"{filecounter}_{filename}"
                    print(f"starting: {fn}")
                    fh = open(fn, "w")

                else:
                    print_progress(cnt)

                fh.write(line + "\n")
                cnt += 1

    finally:
        if not fh.closed:
            fh.close()
        s.close()

        # Final gzip for last file
        threading.Thread(target=gzip_file, args=(fn,), daemon=True).start()


if __name__ == "__main__":
    main()
