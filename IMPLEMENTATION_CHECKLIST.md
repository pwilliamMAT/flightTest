# Coordinated Capture Implementation Checklist

This checklist documents the capture-workflow separation work so another agent can audit or extend it without rediscovering the design.

## Inventory and archive planning

- [x] Create `fileList.md` before source changes.
- [x] Classify current `TestSetupTesting` files as active, candidate-archive, or unknown-review.
- [ ] Review archive candidates with a human before moving anything into `TestSetupTesting/archive/`.

## Capture workflow changes

- [x] Add a local-only MATLAB entrypoint for the standard HDTV SDR capture.
- [x] Hide stable SDR defaults behind that entrypoint:
  - `radio = 'My USRP N320'`
  - `cf = 540e6`
  - `sr = 6.144e6`
  - `lo = 200e3`
- [x] Keep user-tuned parameters exposed:
  - capture duration
  - capture file base name
  - gain
  - session ID
- [x] Add an external Ubuntu bash coordinator that starts ADS-B on the Pi over SSH.
- [x] Run the local SDR capture through `matlab -batch` from the bash coordinator.
- [x] Copy the matching ADS-B file back to the testing machine after the Pi logger exits.
- [x] Keep the old MATLAB-owned coordinator as a legacy compatibility path.

## Documentation

- [x] Document the new recommended coordinated-capture command in the top-level `README.md`.
- [x] Document the simplified command shape and the hidden local SDR defaults.
- [x] Document the SSH prerequisite and the Pi host `192.168.10.131`.
- [x] Document the legacy MATLAB-owned coordinator as a secondary path.

## Verification

- [x] Run a static inventory pass on the affected MATLAB capture files before editing.
- [x] Run MATLAB Code Analyzer on the new or modified MATLAB entrypoints after editing.
- [ ] Run the new shell coordinator on the Ubuntu testing machine against the Pi.
- [ ] Confirm that a single session ID appears in both the copied ADS-B file name and the local `.bb` file names.
- [ ] Decide whether `log_iq_n320.m`, `BenchmarkEngine.m`, and the visualization scripts remain active or move to archive.
