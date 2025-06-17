#!/usr/bin/env python3
import socket
import argparse
import datetime
import time
import os
import gzip
import sys
import signal
import subprocess # New: Import subprocess to run chronyc command

# Global flag to indicate if a shutdown signal has been received
SHUTDOWN_REQUESTED = False

def signal_handler(signum, frame):
    """
    Handler for graceful shutdown signals (e.g., Ctrl+C, kill).
    Sets a global flag to indicate that shutdown is requested.
    """
    global SHUTDOWN_REQUESTED
    print(f"\nShutdown signal ({signum}) received. Preparing for graceful exit...")
    SHUTDOWN_REQUESTED = True

def main():
    """
    Main function to parse arguments, connect to gpsd, and log NMEA data.
    Includes high-precision system time and chrony stats logging.
    """
    # Register the signal handler for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)  # Handle Ctrl+C (SIGINT)
    signal.signal(signal.SIGTERM, signal_handler) # Handle 'kill' command (SIGTERM)

    # Default arguments (can be overridden by command-line flags)
    default_server = '127.0.0.1'
    default_port = 2947  # Default gpsd port
    default_filename_prefix = f"nmea_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    default_seconds_per_file = 3600  # Rotate every 1 hour by default
    default_lines_per_file = 200000    # Rotate every 2000 lines by default
    default_num_files = 50           # Keep last 10 compressed files by default

    # --- Timing and Chrony Stats Configuration ---
    # Interval for logging high-precision system time (e.g., every 5 seconds)
    NTP_TIME_RECORD_INTERVAL_SECONDS = 5
    # Interval for logging chronyc sourcestats (e.g., every 60 seconds)
    CHRONY_STATS_RECORD_INTERVAL_SECONDS = 60
    # --- End Timing Configuration ---

    parser = argparse.ArgumentParser(
        description="Connects to gpsd and logs NMEA sentences to rotating files, "
                    "including high-precision NTP time and chrony stats."
    )
    parser.add_argument(
        '-s', '--server', type=str, default=default_server,
        help=f"Host IP running gpsd server (default: {default_server})"
    )
    parser.add_argument(
        '-p', '--port', type=int, default=default_port,
        help=f"TCP Port of gpsd service on server (default: {default_port})"
    )
    parser.add_argument(
        '-f', '--filename_prefix', type=str, default=default_filename_prefix,
        help=f"Prefix for the output filename (default: {default_filename_prefix}_[counter]_.txt)"
    )
    parser.add_argument(
        '-t', '--time_per_file', type=int, default=default_seconds_per_file,
        help=f"Duration per file in seconds (default: {default_seconds_per_file})"
    )
    parser.add_argument(
        '-l', '--lines_per_file', type=int, default=default_lines_per_file,
        help=f"Number of lines per file (default: {default_lines_per_file})"
    )
    parser.add_argument(
        '-n', '--num_files', type=int, default=default_num_files,
        help=f"Maximum number of files to retain (oldest will be deleted) (default: {default_num_files})"
    )

    args = parser.parse_args()

    server = args.server
    port = args.port
    filename_prefix = args.filename_prefix
    time_per_file = args.time_per_file
    lines_per_file = args.lines_per_file
    num_files_to_keep = args.num_files

    print(f"Connecting to gpsd at {server}:{port}")
    print(f"Output files will be prefixed with: {filename_prefix}")
    print(f"Rotate every {time_per_file} seconds or {lines_per_file} lines. Keep {num_files_to_keep} files.")

    sock = None
    current_file_handle = None # Initialize outside try-finally for scope

    # Variables to track when to log NTP time and chrony stats
    last_ntp_time_record_time = time.time()
    last_chrony_stats_record_time = time.time()

    try:
        # Create a TCP socket to connect to gpsd
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5) # Set a timeout for connection
        sock.connect((server, port))
        sock.settimeout(None) # Remove timeout for continuous reading

        # Send the WATCH command to gpsd to get raw NMEA data
        # 'raw': 2 is for raw NMEA sentences.
        watch_command = '?WATCH={"enable":true,"raw":2,"json":false}\n'
        sock.sendall(watch_command.encode('utf-8'))
        print("Sent WATCH command to gpsd. Waiting for data...")

        line_count = 0
        file_counter = 0
        start_time_current_file = time.time()
        current_filename = ""
        

        while not SHUTDOWN_REQUESTED: # Main loop now checks the graceful shutdown flag
            try:
                # --- Timing and Chrony Stats Logging ---
                current_loop_time = time.time()

                # Log high-precision system time every N seconds
                if current_file_handle and (current_loop_time - last_ntp_time_record_time >= NTP_TIME_RECORD_INTERVAL_SECONDS):
                    # Format: #NTP_TIME YYYY-MM-DD HH:MM:SS.microseconds
                    system_ntp_time = datetime.datetime.now()
                    current_file_handle.write(f"#NTP_TIME {system_ntp_time.isoformat(sep=' ')}\n")
                    current_file_handle.flush() # Ensure it's written immediately
                    last_ntp_time_record_time = current_loop_time

                # Log chrony sourcestats every N seconds
                if current_file_handle and (current_loop_time - last_chrony_stats_record_time >= CHRONY_STATS_RECORD_INTERVAL_SECONDS):
                    try:
                        # Execute 'chronyc -m sourcestats sources' and capture its output
                        # check=True will raise CalledProcessError if chronyc returns a non-zero exit code
                        chrony_process = subprocess.run(
                            ['chronyc', '-m', 'sourcestats', 'sources'],
                            capture_output=True, # Capture stdout and stderr
                            text=True,           # Decode output as text (UTF-8 by default)
                            check=True           # Raise an exception for non-zero exit codes
                        )
                        # Write chrony stats to the log file, wrapped with markers
                        current_file_handle.write(f"#CHRONY_STATS_START {datetime.datetime.now().isoformat(sep=' ')}\n")
                        current_file_handle.write(chrony_process.stdout)
                        current_file_handle.write(f"#CHRONY_STATS_END\n")
                        current_file_handle.flush()
                        
                    except subprocess.CalledProcessError as e:
                        print(f"\nError running chronyc: {e}")
                        print(f"Stderr from chronyc: {e.stderr}")
                    except FileNotFoundError:
                        print("\nWarning: 'chronyc' command not found. Is chrony installed and in your system's PATH?")
                    
                    last_chrony_stats_record_time = current_loop_time
                # --- End Timing and Chrony Stats Logging ---


                # Read data from the socket, assuming lines are terminated by '\n'
                data = sock.recv(4096).decode('utf-8')
                if not data:
                    print("\nConnection closed by gpsd. Exiting.")
                    break # Exit loop if connection is closed

                lines = data.splitlines()
                for line in lines:
                    if SHUTDOWN_REQUESTED: # Check flag again after processing a block of data
                        break # Exit inner loop quickly if shutdown requested

                    # Skip empty lines or lines that aren't NMEA (NMEA starts with '$')
                    if not line.strip() or not line.strip().startswith('$'):
                        continue

                    # File rotation logic (based on time or line count)
                    time_elapsed = time.time() - start_time_current_file
                    
                    if current_file_handle is None or \
                       line_count >= lines_per_file or \
                       time_elapsed >= time_per_file:
                        
                        # If shutdown requested, and we're about to rotate,
                        # this is the graceful exit point.
                        if SHUTDOWN_REQUESTED and current_file_handle is not None:
                            print("\nFinishing current file before exiting gracefully...")
                            # Don't open a new file, just process remaining data and break from main loop.
                            break

                        if current_file_handle: # Close previous file if it was open
                            current_file_handle.close()
                            print(f"\nCompressing {current_filename}...")
                            # Use 'gzip -9 -f' for maximum compression and force overwrite
                            # The '&' runs it in the background so the script doesn't wait
                            os.system(f"gzip -9 -f '{current_filename}' &")

                            # Delete oldest compressed files to manage disk space
                            oldest_file_index_to_delete = file_counter - num_files_to_keep
                            if oldest_file_index_to_delete >= 0:
                                old_gz_filename = f"{filename_prefix}_{oldest_file_index_to_delete}.txt.gz"
                                if os.path.exists(old_gz_filename):
                                    print(f"Deleting old file: {old_gz_filename}")
                                    os.unlink(old_gz_filename) # Use os.unlink to delete a file
                                else:
                                    print(f"Warning: Old file not found for deletion: {old_gz_filename}")

                        # Prepare for a new log file
                        current_filename = f"{filename_prefix}_{file_counter}.txt"
                        print(f"\nStarting new file: {current_filename}")
                        current_file_handle = open(current_filename, 'a') # Open in append mode
                        line_count = 0
                        file_counter += 1
                        start_time_current_file = time.time()

                    # Write the NMEA line to the current file
                    current_file_handle.write(line.strip() + '\n')
                    line_count += 1

                    # Progress indicator (visual feedback in the console/log)
                    if line_count % 100 == 0:
                        if line_count % 3000 == 0:
                            print(f"{int(line_count / 1000)}", end='\n')
                        elif line_count % 1000 == 0:
                            print(f"{int(line_count / 1000)}", end='')
                        else:
                            print(".", end='')
                        sys.stdout.flush() # Ensure output appears immediately

            except socket.timeout:
                # If a shutdown is requested, the outer loop will handle the exit
                if not SHUTDOWN_REQUESTED:
                    print("\nSocket read timeout. Retrying...")
            except Exception as e:
                print(f"\nError reading from socket: {e}")
                break # Exit loop on unhandled error

    except socket.error as e:
        print(f"Socket error: Could not connect to gpsd at {server}:{port}. Is gpsd running? Error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    finally:
        # Final cleanup: Close and compress the last opened file upon script termination
        if current_file_handle and not current_file_handle.closed:
            current_file_handle.close()
            print(f"\nCompressing final file {current_filename}...")
            os.system(f"gzip -9 -f '{current_filename}' &")

        if sock:
            sock.close()
            print("Socket closed.")
        print("Script terminated.")

if __name__ == "__main__":
    main()
