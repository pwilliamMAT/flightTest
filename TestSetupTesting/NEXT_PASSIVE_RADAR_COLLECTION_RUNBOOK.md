# Next Passive-Radar Collection Runbook

This procedure is for the testing machine. Preparation and August replay are
offline only; they make no claim that the N320, antennas, or live ADS-B feed
have been validated.

This session is commissioning-only. It creates hardware and provenance
evidence; it does not create a formal aircraft opportunity, tune a detector,
or claim an aircraft detection.

## 0. Pass the ADS-B-Only Acceptance Test

Do this before connecting to or running the N320. The purpose is to prove that
the Pi feed supplies timely position and velocity data and that at least one
aircraft has a defensible 599 MHz manual-selection opportunity.

First verify the live feed and watch the ADSB-remoter console:

```bash
nc -vz 192.168.10.131 30003
cd external/ADSB-remoter
uv run --no-dev adsb-console \
  --source 192.168.10.131:30003 \
  --carrier-frequency-mhz 599 \
  --observerfile ../../BistaticDataAnalysis/adsb_remoter_599mhz_observer.ini \
  --dtv-file ../../BistaticDataAnalysis/adsb_remoter_599mhz_emitter.csv \
  --dtv-bands uhf \
  --bistatic-display-tracks 10
```

The console's BiSNR and bistatic range/Doppler describe the latest reported
position. Its CPA columns are constant-velocity predictions to the receiver,
not BiSNR predictions at CPA. Use the display as an indicator and keep
selection manual.

Record at least 90 seconds of ADS-B without starting the N320. On the Pi:

```bash
cd /home/pi2/flightTest/ADSB_GPS
ADSB_TEST_ID="adsb-readiness-$(date +%Y%m%dT%H%M%S)"
python3 gatherTCPcompress.py \
  --session-id "$ADSB_TEST_ID" \
  --run-seconds 90
gzip -t *"adsb_${ADSB_TEST_ID}.txt.gz"
```

Copy the resulting gzip to the testing machine, then run from the repository
root in MATLAB:

```matlab
addpath("BistaticDataAnalysis")
adsb = runADSBReadinessTest( ...
    "<path-to-adsb-readiness.txt.gz>", ...
    "WindowDurationS", 60, ...
    "CreatePlot", true);
adsb.Summary
adsb.Gates
adsb.Candidates
```

`adsb.TruthReady` reports whether the ADS-B trajectory data itself is usable.
`adsb.ReadyForManualSelection` additionally requires a defensible candidate.
Proceed to hardware setup only when:

```matlab
adsb.Status == "pass" && adsb.ReadyForManualSelection
```

PASS means that the archive is readable, position fixes cover both ends of the
60-second window, update density and velocity availability meet the defaults,
and at least one candidate has a non-endpoint observed receiver CPA. If only
`defensible_manual_candidate` is HOLD, keep watching or record a longer
ADS-B-only interval; do not choose an endpoint-censored candidate solely
because its displayed BiSNR is high. A corrupt or truncated gzip must be
reacquired or restored from an intact source, not partially recovered as truth.

## 1. Fix and Record the Physical Configuration

Install and aim both directional antennas before changing receiver gain.
Use this channel order unless the physical verification proves otherwise:

| Stored channel | N320 port | Role | Initial gain |
| --- | --- | --- | ---: |
| 1 | `RF0:RX2` | surveillance | 16 dB |
| 2 | `RF1:RX2` | reference | 16 dB |

Record antenna model, amplifier/LNA state, polarization, azimuth, elevation,
height, cable, connector path, and receiver coordinates. Verify the mapping
with a deliberate one-channel stimulus or disconnect test; do not infer it
from which channel is louder.

Prepare one required setup-note record for each physical configuration:

```bash
SETUP_NOTES='CH1 RF0:RX2 surveillance <antenna and inline chain>; CH2 RF1:RX2 reference <antenna and inline chain>; polarization <...>; az/el/height <...>; mapping proof <method and result>; anomalies/weather/deviations <...>'
```

The capture scripts save this text verbatim as `operator_setup_notes` in the
manifest. In interactive MATLAB an omitted note opens this one prompt; a
headless command with no note fails before it starts ADS-B or RF capture.

## 2. Run Three Short Precheck Captures

From the repository root in MATLAB:

```matlab
addpath(pwd, "AcquisitionPrecheck", "BistaticDataAnalysis", ...
    "TestSetupTesting")

config = struct;
config.Mode = "live";
config.CenterFrequencyHz = 599e6;
config.SampleRateHz = 6.144e6;
config.LOOffsetHz = 0;
config.IlluminatorCenterFrequencyHz = 599e6;
config.AntennaPorts = ["RF0:RX2", "RF1:RX2"];
config.ChannelRoles = ["surveillance", "reference"];
config.GainDB = [16, 16];                 % [SURV REF]
config.AnalysisDurationS = 1;
config.CPIDurationS = 0.5e-3;
config.MinimumStableCaptures = 3;
config.CreatePlots = true;

config.Live.EnableHardwareAccess = true;  % Required live-only opt-in
config.Live.RadioName = "My USRP N320";
config.Live.CaptureDurationS = 1;
config.Live.CaptureFile = "passive_radar_precheck";
config.Live.Repetitions = 3;
config.Live.RepetitionSpacingS = 1;

result = runPassiveRadarHardwarePrecheck(config);
result.Summary
result.ControlStability
```

Omitting `Mode` is an error. `"offline"` never calls the hardware capture
path, and `"live"` is refused unless `EnableHardwareAccess` is exactly true.

To replay a packaged session without hardware:

```matlab
config = rmfield(config, "Live");
config.Mode = "offline";
config.Source = fullfile("captures", "<session-id>");
config.PartIndices = 1:15;
config.CreatePlots = false;

result = runPassiveRadarHardwarePrecheck(config);
```

## 3. PASS, HOLD, and Gain Adjustment

Proceed only when:

```matlab
result.Status == "pass" && result.SafeForProduction
```

HOLD the collection for missing or inconsistent metadata, a channel-integrity
failure, exact rail contact, inadequate headroom, a weak ATSC pilot, an
ambiguous correlation peak, failed ECA suppression, or unstable repeated
levels. Treat a channel-role review advisory as a reason to verify the
physical mapping. Treat `REF-SURV` power difference as advisory only.

Change exactly one channel by 6 dB only after the named headroom or pilot
check fails, then rerun all three precheck captures:

- SURV clipping or low headroom: reduce SURV by 6 dB.
- REF clipping or low headroom: reduce REF by 6 dB.
- Weak reference pilot with adequate REF headroom: increase REF by 6 dB.
- Weak surveillance/direct-path coupling with adequate SURV headroom:
  increase SURV by 6 dB only after the reference and mapping pass.

Never change both gains in one iteration. Record every attempted gain pair and
its named failed check and precheck verdict.

## 4. Reference-Chain A1–B–A2

Keep RF0, both gains, cable path, pointing, and every processing setting fixed.
Collect three one-second repetitions for each phase: A1 with the reference
dipole, B with the directional reference antenna, and A2 after restoring the
dipole. Create a fresh `SETUP_NOTES` record after every physical change.

Accept the comparison only when the RF0 control and the A1/A2 reference
measurements remain within the existing 2 dB rule. Otherwise label it
`configuration not controlled`, retain the evidence, and do not claim that
either reference antenna improves aircraft detection.

## 5. Final 30-Second Diagnostic Package

After the selected configuration passes a fresh three-capture precheck, record
one continuous diagnostic stream. Replace the gain pair and note text only
with the values actually verified in the field:

```bash
bash TestSetupTesting/run_coordinated_hdtv_capture.sh \
  --radio-name "My USRP N320" \
  --center-frequency 599000000 \
  --sample-rate 6144000 \
  --lo-offset 0 \
  --antenna-ports RF0:RX2,RF1:RX2 \
  --channel-roles surveillance,reference \
  --gain 16,16 \
  --capture-duration 30 \
  --repetitions 1 \
  --operator-setup-notes "$SETUP_NOTES" \
  --capture-file n320_hdtv_commissioning
```

Before accepting this as commissioning evidence, verify the manifest and
baseband metadata contain the supplied note and two ordered mapping records;
the radar, ADS-B, and log paths resolve; hashes match; the stream has no
dropped/overflow evidence, clipping, or rail contact; and ADS-B truth overlaps
the radar interval. Do not interpret this package as a detector result.
