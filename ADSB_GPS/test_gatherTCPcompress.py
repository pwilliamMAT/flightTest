import gzip
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "gatherTCPcompress.py"


class TCPFeeder(threading.Thread):
    def __init__(self, host, port, chunks, delay_s=0.05):
        super().__init__(daemon=True)
        self.host = host
        self.port = port
        self.chunks = chunks
        self.delay_s = delay_s
        self.ready = threading.Event()
        self.errors = []

    def run(self):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
                server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                server.bind((self.host, self.port))
                server.listen(1)
                self.ready.set()
                conn, _ = server.accept()
                with conn:
                    for chunk in self.chunks:
                        conn.sendall(chunk)
                        time.sleep(self.delay_s)
        except Exception as exc:
            self.errors.append(exc)
            self.ready.set()


def get_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class GatherTCPCompressTests(unittest.TestCase):
    def test_run_seconds_preserves_complete_sbs1_lines(self):
        session_id = "TESTSESSION"
        port = get_free_port()
        expected_lines = [
            "MSG,1,1,1,ABC123,1,2026/06/10,09:40:00.000,2026/06/10,09:40:00.000,CALL123,,,,,,,,,,",
            "MSG,3,1,1,ABC123,1,2026/06/10,09:40:01.000,2026/06/10,09:40:01.000,,12000,,,42.300000,-71.300000,,,,0",
            "MSG,4,1,1,ABC123,1,2026/06/10,09:40:01.500,2026/06/10,09:40:01.500,,,250,180,,0,,0",
        ]
        chunks = [
            (expected_lines[0] + "\n" + expected_lines[1][:64]).encode("utf-8"),
            (expected_lines[1][64:] + "\n").encode("utf-8"),
            (expected_lines[2] + "\n").encode("utf-8"),
        ]

        feeder = TCPFeeder("127.0.0.1", port, chunks)
        feeder.start()
        self.assertTrue(feeder.ready.wait(timeout=2), "TCP feeder did not start")

        with tempfile.TemporaryDirectory() as tmpdir:
            cmd = [
                sys.executable,
                str(SCRIPT_PATH),
                "--server",
                "127.0.0.1",
                "--port",
                str(port),
                "--session-id",
                session_id,
                "--run-seconds",
                "5",
                "--time-per-file",
                "60",
                "--lines-per-file",
                "1000",
            ]
            result = subprocess.run(
                cmd,
                cwd=tmpdir,
                capture_output=True,
                text=True,
                timeout=15,
                check=False,
            )

            self.assertEqual(
                result.returncode,
                0,
                msg=f"stdout:\n{result.stdout}\n\nstderr:\n{result.stderr}",
            )
            self.assertFalse(feeder.errors, msg=str(feeder.errors))

            gz_files = sorted(Path(tmpdir).glob(f"*adsb_{session_id}.txt.gz"))
            self.assertEqual(len(gz_files), 1, msg=f"Files: {list(Path(tmpdir).iterdir())}")

            with gzip.open(gz_files[0], "rt", encoding="utf-8") as handle:
                logged_lines = [line.rstrip("\n") for line in handle]

            self.assertEqual(logged_lines, expected_lines)
            self.assertIn("Capture summary:", result.stdout)


if __name__ == "__main__":
    unittest.main()
