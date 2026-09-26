"""Write the cueProbe test payload: a real track_cue, a preset dictionary built from a
different capture, and the cue compressed with Python's zlib (raw deflate + dictionary),
which is what the ADSB cue tasker would send. Output goes next to cueProbe.m.
"""

import json
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVIDENCE = HERE.parent.parent / "evidence"

lines = (EVIDENCE / "cue_traffic_20260926T1234Z.jsonl").read_text(encoding="utf-8").splitlines()
cue = next(line for line in lines if '"message_type":"track_cue"' in line).encode()
training = (EVIDENCE / "cue_traffic_20260926T0050Z.jsonl").read_text(encoding="utf-8")
dictionary = "".join(training.splitlines()).encode()[-32768:]
compressor = zlib.compressobj(9, zlib.DEFLATED, -15, 9, zlib.Z_DEFAULT_STRATEGY, dictionary)
compressed = compressor.compress(cue) + compressor.flush()

(HERE / "cue.json").write_bytes(cue)
(HERE / "cue.dict").write_bytes(dictionary)
(HERE / "cue.deflate").write_bytes(compressed)
print(f"cue.json {len(cue)} B, cue.dict {len(dictionary)} B, cue.deflate {len(compressed)} B")
