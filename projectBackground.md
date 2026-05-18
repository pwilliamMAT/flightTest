# Project Background: Passive Bistatic Target Localization and Tracking

## 1. Project Overview

This document outlines the plan and key considerations for a project focused on processing In-phase and Quadrature (IQ) data for passive bistatic target localization. The system uses High-Definition Television (HDTV) signals as the signal of opportunity and a USRP N320 for data collection.

The primary technical goal is to estimate a target's 2D trajectory. This will be achieved by first calculating the target's bistatic range using Time Difference of Arrival (TDOA) and then processing a sequence of these range measurements over time with a tracking filter. All processing and analysis will be conducted using MATLAB.

## 2. High-Level Plan

The project will be executed in the following phases:

1.  **Data Loading and Preparation:**
    *   Develop a MATLAB script to read the raw IQ data files (`.bin`), separating the surveillance and reference channels.
    *   Reshape the data into a `fast-time` (samples) by `slow-time` (pulses) matrix to form the data cube for processing.

2.  **Synchronization Check:**
    *   Perform a cross-correlation between the reference and surveillance channels to verify system time synchronization. A strong peak at the expected direct path delay will validate the timing.

3.  **Direct-Path Interference (DPI) and Clutter Mitigation:**
    *   Implement a Doppler-based filtering technique, such as the Enhanced Cancellation Algorithm by Carrier (ECA-C), to remove the strong, stationary direct signal and static clutter from the surveillance channel data.

4.  **Bistatic Range Estimation via TDOA:**
    *   Perform a cross-correlation between the cleaned surveillance signal and the reference signal to find the TDOA of any target echoes.
    *   Convert the TDOA measurement to bistatic range (`range = tdoa * c`).

5.  **Target Detection:**
    *   Apply a Constant False Alarm Rate (CFAR) detector to the range profile (the cross-correlation output) to automatically detect target peaks above the noise floor.

6.  **Trajectory Estimation with a Tracker:**
    *   Initialize and configure a Kalman filter (likely an Extended or Unscented Kalman Filter) to handle the non-linear measurement model.
    *   The filter's state will represent the target's 2D position and velocity.
    *   The bistatic range detections will be used as measurements to update the tracker over time, producing an estimated target trajectory.

## 3. Critical Consideration: ITAR Compliance

**This project must not implement capabilities that are restricted by the International Traffic in Arms Regulations (ITAR).** All development and analysis must be conducted with the explicit goal of remaining within the scope of fundamental research and avoiding the creation of a "defense article."

### ITAR Analysis Summary

Our review of the United States Munitions List (USML) indicates that passive radar systems can fall under ITAR control. The most relevant section is **USML Category XI(a)(3)(xxvii)**, which controls:

> "Bi-static/multi-static radar that exploits greater than 125 kHz bandwidth and is lower than 2 GHz center frequency to passively detect or track using radio frequency (RF) transmissions (e.g., commercial radio, television stations);"

### Guiding Principles for Compliance:

To ensure this project remains outside the scope of ITAR:

1.  **Fundamental Research:** The work should be treated as fundamental research, intended for public dissemination.
2.  **No Military Design:** The software and system must not be "specially designed" for a military end-user or for a military application.
3.  **Public Domain Methods:** The processing techniques used (e.g., cross-correlation, FFT, CFAR, Kalman filtering) are standard, publicly documented algorithms and do not in themselves constitute "technical data" in this context.
4.  **Focus on "How," not "What":** The project's focus is on the scientific process of signal processing, not on creating a deployable, operational system for surveillance.
5.  **Performance Limitations:** While we aim for the best possible results, we will not artificially limit the accuracy of the processing. The key is that the system as a whole is not designed or intended for a controlled military purpose.

All personnel and automated agents working on this project must adhere to these principles to ensure that the resulting software and data are not subject to ITAR export controls.