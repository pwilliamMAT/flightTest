# Antenna Pointing Controller (ESP32 / ESP-NOW) — Design Note

Status: proposed design, not built. Recorded 2026-09-25.

## Purpose

Measure and control the azimuth of each rotator-mounted Yagi (REF and SURV). The existing rotators turn only while the controller's button is held, alternate direction on each press, have no position feedback, and bounce at the end of travel.

## Existing equipment

- Each rotator controller sits in a weather enclosure about 6–8 ft from its antenna and runs from a 15 VAC wall supply.
- The rotator and the antenna's built-in LNA are powered up the coax from that controller.
- See [SiteGeometry.md](SiteGeometry.md) for the antenna layout and pointing.

## Hardware

### Antenna node (one per antenna, in its weather enclosure)

- **ESP32**, powered from a 5 V USB adapter in the enclosure. It is mains-powered, so it can listen for commands continuously and needs no battery. Don't tap the rotator controller's supply or the coax.
- **Adafruit STEMMA mini relay (4409)**, wired across the controller's button contacts. It "presses" the button for the node, whatever the button's voltage or polarity, and keeps the ESP32 isolated from the controller.
- **Adafruit LSM303AGR accelerometer and magnetometer (4413)**, mounted on the rotating mast on a non-ferrous standoff at least 30 cm above the rotator:
  - The accelerometer provides tilt compensation. Earth's field dips about 66° here, so every 1° of mount tilt can cause up to about 2.3° of heading error, and that error varies with heading.
  - It connects by an 8 ft cable with a service loop for the rotation, using I2C slowed to 10–50 kHz. If that is unreliable, use a PCA9615 differential I2C extender over Cat5.
- **Optional:** an Adafruit MMC5603 (5579) as a second magnetometer for cross-checking. Its SET/RESET cancels offset drift with temperature.

Not recommended from the parts considered:

- **HMC5883L:** end-of-life, and many boards sold under that name carry the QMC5883L instead.
- **MAX4544 analog switch:** it needs the button circuit to be under 12 V and share a ground with the ESP32, which is unknown.
- **ICM-20948:** its magnetometer is the weakest of the group. Its gyro is a later upgrade if the rotator motor disturbs heading readings while turning.

### Gateway (at the collection PC)

- An **ESP32 on USB** that relays ESP-NOW packets to and from a USB serial port. MATLAB talks to it with `serialport`, so the PC needs no special drivers or network setup.
- Place it near the stairwell glass. If coated glass limits the range, use a board with an external-antenna connector.

## Radio link

- ESP-NOW (2.4 GHz, acknowledged), with all nodes on one fixed Wi-Fi channel at reduced transmit power.
- 2.4 GHz is well away from the UHF TV band, but REF's broadband LNA (20 MHz–4 GHz) covers it. Keep transmissions sparse (see Behaviour) and record heartbeat times in the capture metadata.

## Behaviour

**Idle**

- Read the heading about once per second.
- Transmit only when the heading changes by more than about 0.5°, or as a 10 s heartbeat. Antennas don't move during captures, so the link is quiet then.

**`goTo(deg)`**

1. Close the relay and watch the heading at about 10 Hz.
2. If the antenna turns the wrong way, release, pause, and press again; the next press turns it the other way. The node learns the toggle state from the sign of the heading change, so it corrects itself if it loses track.
3. Release a few degrees early to allow for coast.
4. Failsafes: release if the heading stops changing (end of travel, before the bounce), if the link drops, or after a maximum hold time.

**Packet contents**

- Node ID and sequence number.
- True heading.
- Raw magnetometer and accelerometer vectors.
- Total field strength, which flags local disturbances such as a car parking near an antenna.
- A moving flag.

## Calibration

1. Sweep each antenna through its full travel while logging raw magnetometer data, and fit the hard- and soft-iron offsets (ellipse or ellipsoid fit).
2. Convert magnetic to true bearing with the local declination (about 14° W at Natick; check the current value with the NOAA calculator).
3. Anchor to RF truth by rotating each Yagi while logging channel levels. The main DTV towers are at about 83° true for both antennas. The Pluto injector's bearing gives a second reference once it is placed on the REF–SURV leg. Note that from SURV the stairwell shadows the Hudson transmitter (309°), so don't use channel 22 as a SURV reference.

Take heading readings only while the rotator is stopped, since the motor's field can disturb the magnetometer while it runs.

## MATLAB integration

- A `rotatorLink` class wrapping `serialport`, with `heading(node)`, `goTo(node, deg)` and a logger.
- `runPlutoAzimuthEnvironmentalScan` calls it instead of prompting the operator for bearings, which turns the azimuth scan into an unattended sweep.
- Every capture manifest records both antenna headings, with their field-strength and tilt quality flags.

## Open items before firmware

- Which ESP32 boards are on hand (model or Adafruit product number), so the STEMMA QT port and pins can be set.
- Mounting details for the sensor standoff and the cable service loop on each mast.
