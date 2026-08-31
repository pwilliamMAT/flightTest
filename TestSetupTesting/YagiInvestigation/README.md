# Troubleshooting Summary: Underperforming Amplified UHF Yagi TV Antenna

## Executive Summary

A commercial amplified UHF Yagi TV antenna is exhibiting significantly poorer performance than expected when compared against a separate amplified monopole reference antenna located approximately 100 feet away.

The antenna was evaluated using a HackRF and GQRX while receiving Boston-area ATSC television broadcasts near 596-602 MHz. Although the Yagi demonstrates directional behavior consistent with a functioning antenna array, there is evidence suggesting that the integrated low-noise amplifier (LNA) may not be operating correctly.
![Yagi Anten GQRX Scan](02_Yagi_Scans/yagi_bearing_100.png)

The strongest indicator of a fault is that disabling power to the antenna does **not produce an observable change in received signal level**, whereas a separate amplified monopole antenna exhibits a substantial signal reduction when power is removed.

Current suspicion is focused on the active RF amplifier chain rather than the antenna structure itself.

---

# System Description

## Antenna Under Test

Commercial amplified UHF TV Yagi antenna with:

- Integrated rotator
- Integrated amplifier PCB
- Controller providing:
  - Antenna rotation
  - Power to electronics
  - Front-panel LED indicator

### Observed PCB Architecture

Based on visual inspection of the PCB:

1. Antenna feed enters near lower-right corner.
2. Through-hole magnetic component likely serves as:
   - Balun
   - Impedance transformer
   - Common-mode choke
3. RF filtering network follows.
4. Two apparent active RF stages are present.
5. Bias chokes and matching components are visible.

Likely signal chain:

```text
Driven Element
       |
     Balun
       |
 Input Filter
       |
 Amplifier #1
       |
 Interstage Filter
       |
 Amplifier #2
       |
 Output Match
       |
    Coax
```


***

# Test Environment

## RF Source

Boston-area UHF television transmissions.

Primary observation:

* CBS transmitter located approximately 6 miles east of test location.

## Receiver

* HackRF
* GQRX

## Frequency Range

Approximately:

```text
596 MHz - 602 MHz
```

Multiple ATSC channels present.

***

# Key Observations

## Observation 1: Antenna Is Directional

When aimed directly at the TV tower:

* Signal levels increase.

When rotated away:

* Signal levels decrease.
* Sidelobe/null behavior becomes visible.

This confirms:

✅ The Yagi structure is functioning as a directional antenna.

✅ The driven element is likely connected.

✅ The feed system is not completely open.

✅ Energy is entering through the antenna aperture rather than predominantly through cable pickup.

***

## Observation 2: Amplifier Does Not Appear To Affect Received Signal

Power was removed from the antenna electronics.

Expected result:

* Noticeable drop in signal level.
* Change in noise floor.
* Loss of gain.

Actual result:

* No obvious change observed on the spectrum display.

This is the most significant symptom observed to date.

***

## Observation 3: Reference Antenna Behaves Normally

A separate amplified monopole antenna was tested. The two images show the signal from the reference antenna with the Bias Tee on and off - see the two images below.

![ref antenna scan](01_Ref_Antenna_Scans/Test_Signal_Bias_Tee_On.png)
![ref antenna scan](01_Ref_Antenna_Scans/Ref_Signal_Bias_Tee_Off.png)

Observed behavior:

* Larger signal-to-noise ratio.
* Better channel contrast.
* Deep spectral valleys between channels.
* Significant reduction in signal when amplifier power was removed.

This indicates:

✅ Measurement setup is functioning.

✅ Receiver chain is functioning.

✅ Loss of signal when amplifier power is removed is detectable in this test setup.

***

## Observation 4: Yagi Spectrum Appears Compressed

Yagi spectrum characteristics:

* Broad plateau from roughly 596-602 MHz.
* Limited dynamic range.
* Approximate visible contrast:
  * Peaks ≈ -25 dB
  * Floor ≈ -38 dB
  * Dynamic range ≈ 13 dB

Reference monopole characteristics:

* Deep nulls between channels.
* Much larger peak-to-floor separation.
* Strong channel definition.

The Yagi spectrum does not resemble what would normally be expected from a directional UHF antenna aimed at a strong local transmitter.

***

# Working Hypotheses

## Hypothesis A: Amplifier Not Receiving Power

Possible causes:

* Open bias path
* Failed feed choke
* Failed bias resistor
* Broken power routing on PCB

Evidence:

* Controller power and LED operation do not prove amplifier rail is energized.
* Rotator may operate from a separate supply rail.

Likelihood: High

***

## Hypothesis B: Amplifier Device Failure

Possible causes:

* Failed MMIC
* Failed transistor
* ESD damage
* Lightning damage

Evidence:

* RF path still appears functional.
* Antenna still exhibits directivity.
* Signal propagates even when amplifier power removed.

Likelihood: High

***

## Hypothesis C: Amplifier Operating in Compression or Oscillation

Possible causes:

* Incorrect bias voltage
* Marginal component failure
* Self-oscillation
* Overload from strong local transmitters

Evidence:

* Elevated broadband spectral plateau.
* Poor channel contrast.
* Reduced apparent dynamic range.

Likelihood: Moderate

***

## Hypothesis D: Amplifier Includes Passive Bypass Path

Some TV masthead amplifiers allow RF to pass when unpowered.

Evidence:

* No large change when power removed.

Likelihood: Moderate

However, even with a passive bypass present, some measurable difference would generally be expected if the LNA were healthy.

***

# Recommended Troubleshooting Plan

## Step 1: Verify DC Supply Voltages

Using DMM:

### Measure Controller Output

Measure:

```text
Center conductor to shield
```

at controller output.

Record:

* Voltage
* Polarity

***

### Measure Voltage At PCB Input

Verify:

* Supply voltage arrives at PCB.
* Same voltage present as seen at controller.

***

### Measure Bias Voltage At Each RF Stage

For each amplifier stage:

Measure:

```text
Amplifier Vcc
Amplifier bias node
Ground reference
```

Look for:

* Missing voltage
* Partially collapsed rails
* Different voltages between stages

Expected result:

Both amplifier stages should have valid bias.

***

## Step 2: Measure Current Consumption

Insert ammeter in series with supply.

Record total current draw.

Compare:

### Powered

Current > 0

Expected:

```text
~10 mA to 100 mA
```

depending on design.

### Suspicious Results

```text
0 mA
Very low current
Intermittent current
```

would strongly suggest amplifier failure.

***

## Step 3: Quantify Gain Difference

Rather than visual inspection.

Measure exact channel level.

Example:

```text
596 MHz
599 MHz
602 MHz
```

Record:

### Powered

Peak power

### Unpowered

Peak power

Compute:

```text
Delta = Powered - Unpowered
```

Interpretation:

| Delta     | Interpretation                 |
| --------- | ------------------------------ |
| 0-1 dB    | Amplifier likely nonfunctional |
| 2-5 dB    | Marginal or small gain         |
| 10-20+ dB | Amplifier likely healthy       |

***

## Step 4: Inspect RF Path Continuity

Check:

* Driven element continuity
* Balun continuity
* Coax connector continuity
* Ground bond continuity

Verify no corrosion or cracked solder joints.

***

## Step 5: Identify Active Devices

Read markings on:

* Amplifier ICs
* MMICs
* Transistors

Determine:

* Intended gain
* Bias requirements
* Expected current draw

***

# NanoVNA Investigation

If you're intentionally coupling into the **folded dipole only** and not trying to illuminate the entire Yagi aperture, then you're not doing a classical antenna-pattern measurement. Instead, you're effectively doing a **contactless injection test of the feed network and amplifier chain**.

Conceptually:

```text
NanoVNA Port 0
      |
  Rubber Ducky

      ~~~ near field coupling ~~~

  Folded Dipole
      |
    Balun
      |
   Filter
      |
    LNA(s)
      |
NanoVNA Port 1
```

For troubleshooting, that's actually attractive because it largely removes uncertainties associated with:

* tower signal fading
* multipath
* beam pointing
* atmospheric changes
* SDR gain settings

and instead asks:

> "Can RF energy injected into the driven element make it through the internal RF chain?"

## What I would look for

### Test 1: Powered vs Unpowered S21

This is the money test.

Measure:

```text
S21(f)
```

from perhaps:

```text
500 MHz - 700 MHz
```

and compare:

1. Amplifier powered
2. Amplifier unpowered

If the LNA is healthy, I'd expect a very obvious change.

For example:

```text
Powered     : -20 dB coupled path
Unpowered   : -40 dB coupled path
```

or something similarly dramatic.

If the two traces sit nearly on top of one another:

```text
Powered     : -35 dB
Unpowered   : -36 dB
```

then the amplifier likely isn't contributing meaningful gain.

***

### Test 2: Look for the TV passband

Your first GQRX screenshot suggested some sort of response that rolls off around 602 MHz.

The VNA may reveal whether the board intentionally contains a UHF bandpass filter.

You might see something like:

```text
550 MHz - 620 MHz : relatively flat

Below 500 MHz : attenuated

Above 700 MHz : attenuated
```

which would tell us the filter network is still functioning.

***

### Test 3: Check for oscillation

If the amplifier is unstable, sometimes you'll see weird behavior such as:

* response changing when your hand moves nearby
* extremely jagged S21
* narrow spikes
* large peak structures

A healthy TV amplifier tends to produce a fairly smooth response.

***

## One caveat

Because you're coupling into the dipole in the near field, don't worry about the absolute magnitude of S21.

For example:

```text
S21 = -25 dB
```

or

```text
S21 = -55 dB
```

doesn't matter very much.

Moving the ducky 1 inch can change that substantially.

The thing that matters is:

### Repeatability

and

### Powered vs unpowered difference

You're looking for changes, not calibration-grade gain measurements.

***

## What would convince me the amplifier is dead?

If you observe all of the following:

* Directional Yagi behavior when pointed at TV towers.
* Nearly identical GQRX signal levels with power on/off.
* Nearly identical NanoVNA S21 with power on/off.
* Proper DC voltage present on the board.

Then I'd be highly suspicious of a failed MMIC or transistor stage.

At that point I'd start tracing the RF path component-by-component and identify the amplifier devices.

***

## One additional measurement I'd make

Since you're already opening the enclosure, measure:

```text
S11
```

looking into the amplifier output port.

Powered and unpowered.

A dead amplifier sometimes leaves the output looking essentially like a passive network. A healthy broadband MMIC stage often changes the apparent impedance environment somewhat when biased. The information is secondary to S21, but it's another clue essentially for free.

Overall, I think your near-field NanoVNA test is a clever way to isolate the balun/filter/amplifier chain from the propagation environment. For troubleshooting whether the active RF path is alive, I'd actually trust the powered-vs-unpowered S21 comparison more than another round of OTA TV measurements.

# Conclusions

The antenna array itself appears functional because:

* Directionality is present.
* Beam pointing affects received level.
* Sidelobes/nulls are observable.

The primary concern is the active RF chain.

Most likely causes, in descending order:

1. Amplifier bias rail failure.
2. Failed amplifier device.
3. Amplifier operating incorrectly due to improper bias.
4. Passive bypass path masking an amplifier failure.

Highest priority next actions are:

1. Measure all DC voltages on the RF PCB.
2. Measure total current consumption.
3. Quantify powered vs unpowered gain with exact dB measurements.
4. Identify the RF amplifier devices and verify their operating conditions.

At present, the evidence points much more strongly toward an amplifier problem than an antenna or feedline problem.

---

# Current Investigation Notes

Additional observations from the July 17, 2026 teardown:

* The RF board ground appears weakly bonded and may be effectively floating relative to the rest of the assembly.
* The RF output path runs through coax into the rotator/motor box before reaching the receiver connection.
* A direct connection to the RF board output is now part of the planned comparison testing because the rotator-box path may be adding loss or noise.
* The original power component/controller path needed to energize the amplifier is not currently available, so active bias and powered-vs-unpowered tests are blocked for now.

These observations change the immediate troubleshooting order:

1. Verify passive grounding and continuity first.
2. Compare RF board output against the normal downstream output path.
3. Use unpowered NanoVNA measurements to isolate passive-path problems before concluding the amplifier is dead.
4. Defer bias and current-draw conclusions until a safe power source is available.

---

# Practical Investigation Procedure

This section is intended to be used as the working checklist during bench measurements with a digital multimeter (DMM), HackRF, and NanoVNA.

## Stage 1: Visual And Mechanical Inspection

Record the following before touching probes or moving cables:

* Date and time - July 17, 2026
* Antenna orientation or bench configuration - Disassembled on lab bench (Pat's basement workshop)
* Which output point is connected:
  * Normal external output (through rotator box)
  * Direct connection at RF board output
* Photos of:
  * RF board top and bottom - Captured
  * Coax routing - Captured
  * Ground attachment points - Captured
  * Any active-device markings - Captured in other images

Goal:

* Create a stable reference so later measurements can be compared to the exact same hardware state.

## Stage 2: DMM Checks

These tests are available now even without board power.

Measure continuity or resistance between:

* RF board ground and coax shield at the board output
* RF board ground and coax shield after the rotator-box path
* RF board ground and any metal mounting hardware or housing contact points
* Board output center conductor and downstream center conductor

Look for:

* Open ground paths
* Intermittent continuity when cables are flexed
* A large difference between board-output ground continuity and final-output ground continuity

Interpretation:

* If the ground path is poor or unstable, fix that problem before trusting RF measurements.
* If center-conductor continuity is good but shield continuity is poor, the coax or connector path becomes a primary suspect.

# Pat Notes:
DMM Setup:
1. Basline Lead Resistance 0.2 Ohm
2. DMM at 200 Ohm setting

Tests:
A. 2 "ground" leads that attach to housing = 0.3 Ohm (very close to baseline)
B. 1 ground lead and outside of Coax = 0.3 Ohm

# Shared "YagiBoard.jpg" image and get specific suggestions for measurements:

## Test 1: RF board ground to coax shield at the board output - Completed, this is "B" above, 0.3 Ohm, so close to baseline

  On this board, that is basically the same RF node family, so use it to establish your reference.

  - Black lead: outer threaded shell of the F connector
  - Red lead: a second likely-ground point on the board

  Best second points to try:

  - the wire terminal at the top right marked -
  - the metal shell or mounting metal of the F connector where it meets the board, if accessible
  - later, any known downstream connector shell

  Expected:

  - beep or very low ohms from F shell to the - terminal if DC return and RF ground are bonded
  - if no beep, that is important and worth logging

  ## Test 2: RF board ground to coax shield after the rotator-box path - Completed 0.6 Ohm, so close to baseline, but slightly elevated from Test 1

  This is the cleanest one from your photo.

  - Black lead: outer threaded shell of the F connector on this board
  - Red lead: outer shell / threaded body of the connector at the far end of the downstream path - NOTE: meaning I connected the motor box's Coax (black wire) to the RF boards coax and tested the output of the motor box (Coax sticking out of motor box)

  If the downstream path is another coax cable, use:

  - F connector outer threads
  - SMA outer shell
  - BNC outer shell

  Expected:

  - solid beep
  - very low ohms
  - stable while gently moving the cable

  If this is intermittent, the shield path is suspect.

  ## Test 3: RF board ground to metal mounting hardware or housing contact points

  Use the F shell as the board-ground reference.

  - Black lead: outer threaded shell of the F connector
  - Red lead: one metal part at a time
      - screw heads
      - brackets
      - any metal insert in the housing
      - any metal part touching the assembly
      - the loose ring terminals only if they are actually part of the installed assembly

  Expected:

  - some parts may beep, some may not
  - the goal is to map what is actually bonded

  If a part is supposed to provide grounding but does not beep to the F shell, that supports your floating-ground concern.

  ## Test 4: Board output center conductor to downstream center conductor - Not possible given connections

  Use the F connector center as the board-output center node.

  - Black lead: center contact inside the F connector
  - Red lead: center conductor at the far end of the downstream path

  Expected:

  - solid beep
  - low ohms
  - stable while flexing the cable gently

  Important:

  - do not let the probe touch both the center and the outer shell at once
  - if the F connector center is hard to probe, use a short male F adapter or cable and probe its center pin instead

   # Revised Test 4 - Completed, have not been able to get a solid reading, unclear if this is difficulty reaching center pins or if the reading is actually unreliable

  - Disconnect the downstream coax from the board’s F connector.
  - Put the DMM in continuity or low ohms.
  - Put one probe on the center pin / center wire of the male F plug that normally screws onto the board.
  - Put the other probe on the center conductor at the far end of that same downstream path.
  - This checks the center conductor continuity through the cable/rotator path.

  So the path under test is:

  male F plug that normally attaches to board -> downstream coax / rotator path -> final output center conductor

  The same simplification applies to Test 2:

  - one probe on the outer threaded shell of the male F plug
  - the other probe on the outer shell of the final downstream connector

  That checks the shield path through the downstream assembly.

  Two important notes:

  - In continuity mode, red vs black does not matter. One probe is just the fixed reference and the other is the moving probe.
  - Testing the downstream path disconnected is actually better, because it isolates the cable/rotator assembly from whatever is on the board.

  If you specifically want to test the mated connection while assembled, then you need one of these:

  - an F-type T-adapter
  - a short male-female breakout / extension
  - a sacrificial adapter that gives you access to the center conductor

  Without a breakout, you generally cannot probe the board-side center conductor once the connector is mated.

  So the short answer is:

  - No, don’t try to do Test 4 exactly as originally phrased with the cable attached
  - Yes, revise it to test the downstream coax path disconnected from the board

  ## Practical recommendation

  For this specific board, start with these three checks in this exact order:

  1. F shell -> top-right - terminal
  2. F shell -> far-end connector shell
  3. F center -> far-end connector center

  That will tell you very quickly:

  - whether the board return is tied to RF ground
  - whether the shield path survives through the downstream wiring
  - whether the signal conductor survives through the downstream wiring

  ## What I would not use as a first probe point

  I would not start with:

  - the loose ring terminals
  - bare mounting holes
  - random capacitor leads

  Those may be useful later, but from this photo the F connector is the only unambiguous RF reference.


## Stage 3: HackRF Comparisons

Use the same SDR settings for every capture:

* Same gain settings
* Same sample rate
* Same center frequency span
* Same antenna orientation

Run at least these two configurations:

1. Normal output path through the rotator-box coax
2. Direct connection to the RF board output, if safe

For each capture, record:

* Peak level near 596 MHz
* Peak level near 599 MHz
* Peak level near 602 MHz
* Approximate floor between channels
* Whether the spectrum shows a broad plateau or well-defined channels

Interpretation:

* If the direct board output produces deeper valleys and higher channel contrast than the normal output, the rotator/coax path is likely degrading SNR.
* If both paths look equally compressed, the issue is likely upstream of that downstream coax path.

## Stage 4: NanoVNA Measurements

Because the board is unpowered, use the NanoVNA to answer passive-path questions only.

Recommended sweeps:

* `S21` from near-field coupling into the driven element or folded dipole to the RF board output
* `S21` from near-field coupling into the driven element or folded dipole to the normal final output
* `S11` looking into the RF board output
* `S11` looking into the normal final output, if accessible

Suggested sweep range:

```text
500 MHz - 700 MHz
```

Look for:

* A smooth UHF passband
* Extra loss added by the rotator-box path
* Jagged or hand-sensitive behavior suggesting a grounding or shielding problem

Interpretation:

* If the board-output `S21` is reasonable but the final-output `S21` is much worse, the downstream coax or rotator path is a likely source of error.
* If both board-output and final-output paths already look poor, the fault is likely on the RF board or at the antenna feed structure.

## Stage 5: Powered Tests Later

Do not conclude that the amplifier is dead until a safe power source is available and the DC path is verified.

When power becomes available, add:

* Controller or injected supply voltage
* Polarity
* Voltage at board power entry
* Bias at each amplifier stage
* Total current draw
* Powered vs unpowered HackRF comparison
* Powered vs unpowered NanoVNA `S21`

---

# Measurement Log Template

Use one session entry per bench session.

## Session Header

| Field | Value |
| :--- | :--- |
| Session ID | |
| Date | |
| Start time | |
| Operator | |
| Hardware configuration | |
| Output connection point | |
| Notes | |

## DMM Log

| Test ID | Node A | Node B | Meter mode | Reading | Stable or intermittent | Expected result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| DMM-01 | | | Continuity / Ohms | | | | |

## HackRF Log

| Capture ID | Connection point | Center frequency / span | Sample rate | Gain settings | Peak 596 MHz [dB] | Peak 599 MHz [dB] | Peak 602 MHz [dB] | Floor between channels [dB] | Visual notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| SDR-01 | | | | | | | | | |

## NanoVNA Log

| Sweep ID | Measurement | Connection point | Freq range | Marker summary | Passband summary | Jagged or unstable | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| VNA-01 | S21 / S11 | | 500-700 MHz | | | | |

## Findings Summary

| Finding ID | Evidence | Suspected subsystem | Confidence | Next action |
| :--- | :--- | :--- | :--- | :--- |
| F-01 | | | Low / Medium / High | |

---

# Decision Rules During The Investigation

Use these rules to avoid drawing conclusions too early:

* If the ground bond is poor, fix grounding first and repeat the passive measurements before escalating to amplifier-failure hypotheses.
* If the direct RF board output is better than the normal downstream output, prioritize the coax and rotator-box path.
* If unpowered `S21` is already poor at the RF board output, prioritize the feed, balun, passive filter network, and solder joints.
* If powered tests later show valid voltage and current but almost no RF improvement, the active devices become the leading suspect.
