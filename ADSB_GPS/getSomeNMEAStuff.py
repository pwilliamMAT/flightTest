#!/usr/bin/env python3
"""
gpsd_nmea_logger.py
Log every NMEA sentence seen by gpsd into
~/gpslogs/YYYY-MM-DD_nmea.log (rotated daily).

Requires:
    pip install gpsd-py3
"""

import os
import sys
import datetime as dt
from pathlib import Path
from gpsd import connect, get_current, WATCH_RAW

# ----------------------------------------------------------------------
# 1.  Configuration  ---------------------------------------------------
LOG_DIR = Path.home() / "gpslogs"          # ~/gpslogs (create if needed)
LOG_DIR.mkdir(exist_ok=True)

GPSD_HOST = "127.0.0.1"
GPSD_PORT = 2947                           # match the -F path, if custom
# ----------------------------------------------------------------------

def open_logfile():
    """Open (or reopen) today's logfile: gpslogs/2025-06-13_nmea.log"""
    fname = LOG_DIR / f"{dt.date.today():%Y-%m-%d}_nmea.log"
    return open(fname, "a", buffering=1)   # line-buffered

def main():
    log = open_logfile()
    connect(host=GPSD_HOST, port=GPSD_PORT)
    gpsd = get_current()                  # forces initial poll
    
    # Put gpsd into "raw" mode: sends every talker sentence verbatim
    gpsd.socket.send(b"?WATCH={\"raw\":2,\"enable\":true}\n")
    
    print("Logging NMEA…  Ctrl-C to stop.", file=sys.stderr)
    while True:
        # gpsd.poll() blocks until next message
        msg = gpsd.socket.readline()
        if not msg:
            continue
        
        # Daily rotation: reopen at midnight
        if dt.datetime.now().hour == 0 and log.closed is False:
            log.close()
            log = open_logfile()
        
        line = msg.decode(errors="replace").rstrip("\r\n")
        if line.startswith(("$", "!")):   # NMEA / AIS
            timestamp = dt.datetime.utcnow().isoformat(timespec="milliseconds")
            print(f"{timestamp}  {line}", file=log)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
