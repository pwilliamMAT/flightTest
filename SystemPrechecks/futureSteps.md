# Future Steps

The items below are intentionally deferred.
They are not required to complete this session's cleanup, restructuring, write-up, or deck.

- Rerun the Newton-specific bistatic link budget so `TargetPathPower_dBm` no longer inherits the Hudson placeholder.
- Freeze the retained live scripts to the assumptions table so Newton/Hudson station identity, ERP, and RF channel data are no longer embedded ad hoc inside the `.mlx` workflows.
- Replace interactive ROI and polyline selection in the supporting link-budget live scripts with checked-in deterministic geometry inputs.
- Run a field spectrum survey at the receiver location to bound adjacent-channel loading and real direct-path levels before capture.
- Bench-check the assembled reference and surveillance chains for actual headroom, required attenuation, and TwinRX gain settings.
- Measure the assembled chain noise figure and compare it with the current modeled 3.4-3.6 dB system NF baseline.
- Verify the bandpass filter response in the assembled hardware chain, especially if any additional adapters, tees, or attenuators are inserted.
- Add the next-stage passive-radar items that are explicitly out of scope for this pass: synchronization, calibration, DSI cancellation, clutter rejection, and measured detection performance.
