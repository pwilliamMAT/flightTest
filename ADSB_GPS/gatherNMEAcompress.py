#!/usr/bin/env python3
import socket
import argparse
import datetime
import time
import os
import gzip
import sys # For sys.stdout.flush()

def main():
    """
    Main function to parse arguments, connect to gpsd, and log NMEA data.
    """

    # Default arguments, similar to the Perl script
    default_server = '127.0.0.1'
    default_port = 2947  # Default gpsd port, not 30003 as in the Perl script
    default_filename_prefix = f"nmea_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    default_seconds_per_file = 3600  # 1 hour per file by default
    default_lines_per_file = 2000    # Lines per file by default
    default_num_files = 10           # Number of files to allow before deleting oldest

    parser = argparse.ArgumentParser(
        description="Connects to gpsd and logs NMEA sentences to rotating files."
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
    try:
        # Create a TCP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5) # Set a timeout for connection
        sock.connect((server, port))
        sock.settimeout(None) # Remove timeout for continuous reading

        # Send the WATCH command to gpsd to get raw NMEA data
        # 'raw': 2 is often used for raw NMEA. 'raw': true sometimes sends more.
        # Check gpsd documentation if you need specific raw output.
        watch_command = '?WATCH={"enable":true,"raw":2,"json":false}\n'
        sock.sendall(watch_command.encode('utf-8'))
        print("Sent WATCH command to gpsd. Waiting for data...")

        line_count = 0
        file_counter = 0
        start_time_current_file = time.time()
        current_filename = ""
        current_file_handle = None

        while True:
            try:
                # Read data from the socket, assuming lines are terminated by '\n'
                # Increased buffer size for potentially longer lines
                data = sock.recv(4096).decode('utf-8')
                if not data:
                    print("\nConnection closed by gpsd. Exiting.")
                    break

                lines = data.splitlines()
                for line in lines:
                    # Skip empty lines or lines that aren't NMEA (NMEA starts with $)
                    if not line.strip() or not line.strip().startswith('$'):
                        continue

                    # File rotation logic
                    time_elapsed = time.time() - start_time_current_file
                    
                    # Check if it's time to rotate the file
                    if current_file_handle is None or \
                       line_count >= lines_per_file or \
                       time_elapsed >= time_per_file:

                        if current_file_handle:
                            current_file_handle.close()
                            # Compress the previous file in the background
                            print(f"\nCompressing {current_filename}...")
                            os.system(f"gzip -9 -f '{current_filename}' &")

                            # Delete oldest files if limit is exceeded
                            oldest_file_index_to_delete = file_counter - num_files_to_keep
                            if oldest_file_index_to_delete >= 0:
                                old_gz_filename = f"{filename_prefix}_{oldest_file_index_to_delete}.txt.gz"
                                if os.path.exists(old_gz_filename):
                                    print(f"Deleting old file: {old_gz_filename}")
                                    os.unlink(old_gz_filename)
                                else:
                                    print(f"Warning: Old file not found for deletion: {old_gz_filename}")

                        current_filename = f"{filename_prefix}_{file_counter}.txt"
                        print(f"\nStarting new file: {current_filename}")
                        current_file_handle = open(current_filename, 'a')
                        line_count = 0
                        file_counter += 1
                        start_time_current_file = time.time()

                    # Write NMEA line to the current file
                    current_file_handle.write(line.strip() + '\n')
                    line_count += 1

                    # Progress indicator (similar to Perl script's dots/numbers)
                    if line_count % 100 == 0:
                        if line_count % 3000 == 0:
                            print(f"{int(line_count / 1000)}", end='\n')
                        elif line_count % 1000 == 0:
                            print(f"{int(line_count / 1000)}", end='')
                        else:
                            print(".", end='')
                        sys.stdout.flush() # Ensure output is visible immediately

            except socket.timeout:
                print("\nSocket read timeout. Retrying...")
            except Exception as e:
                print(f"\nError reading from socket: {e}")
                break

    except socket.error as e:
        print(f"Socket error: Could not connect to gpsd at {server}:{port}. Is gpsd running? Error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    finally:
        if current_file_handle and not current_file_handle.closed:
            current_file_handle.close()
            # Compress the very last file
            print(f"\nCompressing final file {current_filename}...")
            os.system(f"gzip -9 -f '{current_filename}' &")

        if sock:
            sock.close()
            print("Socket closed.")

if __name__ == "__main__":
    main()
