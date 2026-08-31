# Stage 4B ADS-B Interval Capture Campaign

This folder contains the Stage 4B ADS-B-only capture coordinator. Run it from the Ubuntu testing machine at the repository root; the script SSHes to the Pi, starts bounded ADS-B-only windows with the same `ADSB_GPS/gatherTCPcompress.py` SSH pattern used by the full capture pipeline, fetches the gzip truth files with `scp`, and packages each window as a local session.

It intentionally does not start SDR/radar capture and does not modify the Pi logger framework.

## Run From The Testing Machine

From the repository root on the testing machine:

```bash
cd /path/to/flightTest
bash adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh
```

The default Pi target mirrors the coordinated HDTV capture pipeline:

```text
pi2@192.168.10.131
/home/pi2/flightTest/ADSB_GPS
```

The default remote command template per window mirrors `TestSetupTesting/run_coordinated_hdtv_capture.sh`:

```bash
cd /home/pi2/flightTest/ADSB_GPS && exec python3 /home/pi2/flightTest/ADSB_GPS/gatherTCPcompress.py --session-id <session_id> --run-seconds 300
```

For a short smoke test:

```bash
bash adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh --campaign-seconds 700 --capture-seconds 30 --interval-seconds 300 --max-windows 2
```

Use `--dry-run` before a field run to confirm the planned windows, Pi target, local session root, receiver LLA, and remote command template without SSH or package writes.

Use `--preflight-only` to check non-interactive SSH, the remote Python ADS-B logger, `python3`, local `scp`, and local write access. This intentionally matches the full capture coordinator preflight and does not add a separate `dump1090` check.

## Key Options

```text
--pi-host <host>
--pi-user <user>
--pi-workdir <path>
--pi-logger-script <path>
--ssh-bin <path>
--scp-bin <path>
--adsb-stage-dir <path>
--session-root <path>
--remote-wait-timeout <seconds>
--fetch-poll <seconds>
--receiver-origin-lla <lat,lon,alt_m>
```

The default `receiver_origin_lla` written to each manifest is:

```text
[42.2999333, -71.349333, 15.0]
```

Override it with `--receiver-origin-lla <lat,lon,alt_m>` if the field receiver origin changes.

## Expected Outputs

Campaign metadata is written under:

```text
adsbForTracking/piCaptureCampaign/campaigns/<campaign_id>/campaign_metadata.txt
adsbForTracking/piCaptureCampaign/campaigns/<campaign_id>/campaign_plan.tsv
adsbForTracking/piCaptureCampaign/campaigns/<campaign_id>/campaign_status.tsv
```

Each capture window is packaged under the local session root, which defaults to `captures/` at the repository root:

```text
captures/<session_id>/truth/*adsb_<session_id>*.txt.gz
captures/<session_id>/logs/stage4B_<session_id>_coordinator.log
captures/<session_id>/logs/stage4B_adsb_capture_<session_id>.log
captures/<session_id>/session_manifest.json
```

Each manifest includes `receiver_origin_lla`, `campaign_id`, `window_id`, `capture_type: "adsb_only_holdout"`, `pi_host`, `pi_user`, `remote_log_file`, `adsb_files`, `log_files`, and `radar_files: []`.

No-aircraft windows may legitimately produce no gzip file. Those windows are recorded as `completed_no_gzip` and do not stop the campaign. The coordinator aborts after three consecutive remote logger start failures.

## After The Campaign

Sync the packaged `captures/<session_id>/` folders back to the development machine or archive location as needed, preserving `session_manifest.json` alongside `truth/`. Then rerun the Stage 3C archive evaluation and Stage 4A capture-planning Live Script. The current priorities are independent Pi-only holdout data, receiver-origin metadata completeness, source diversity, targeted turn/sparse-update and climb/descent coverage, and passive-radar-relevant geometry.
