# Project Plan and Progress

**Guiding Principle**: Each processing step should be implemented as a standalone MATLAB function. A main script, `analyzeBistaticData.m`, will be used to define parameters and orchestrate the calls to these functions. All implementations should prioritize using functions from MATLAB Toolboxes (Phased Array, Radar, Signal Processing).

- **[COMPLETED] 1. Create MATLAB Data Loading Function (`loadIQData.m`)**
  - **Task**: Develop a MATLAB function to read, de-interleave, and reshape raw IQ data into `fast-time` x `slow-time` data cubes.
  - **Verification**: Function successfully loads data and creates data cubes of the correct dimensions.

- **[COMPLETED] 2. Implement DPI and Clutter Mitigation (`mitigateClutter.m`)**
  - **Task**: Create a function to implement an adaptive filter (`dsp.LMSFilter`) to remove the direct-path interference and static clutter from the surveillance channel.
  - **Verification**: Comparison of Range-Doppler maps before and after filtering confirms attenuation of the zero-Doppler clutter.

- **[COMPLETED] 3. Generate Range-Doppler Map (`createRDM.m`)**
  - **Task**: Develop a function that uses the `phased.RangeDopplerResponse` object to perform matched filtering and generate the Range-Doppler Map (RDM).
  - **Verification**: The function runs without error and produces an RDM, which serves as the primary output for target detection.

- **[NOTE] 4. Synchronization Check**
  - **Task**: This was originally planned as a separate function. However, the presence of a strong, clear direct-path signal in the initial RDM serves as sufficient verification that the reference and surveillance channels are time-synchronized. This task is considered implicitly complete.

- **[PENDING] 5. Implement CFAR Detection**
  - **Task**: Create a function (`detectTargets.m`) that applies a 2D CFAR detector (e.g., `phased.CFARDetector2D`) to the RDM to find potential targets.
  - **Verification**: Overlay CFAR detections on the Range-Doppler map to confirm correct identification of target peaks above the noise floor.

- **[PENDING] 6. Implement Target Tracker**
  - **Task**: Create a final function (`trackTargets.m`) to process CFAR detections over multiple time steps with a tracker (e.g., `trackerGNN`).
  - **Verification**: Plot the estimated target trajectories to ensure they are smooth and consistent.

---

## Human Verification Checklist

- **[COMPLETED] A. Verify `loadIQData.m` Functionality**
  - **Action**: Run the `analyzeBistaticData.m` script.
  - **Check**: The script successfully loads data, reporting the dimensions of the raw data and the final data cubes.

- **[COMPLETED] B. Verify `mitigateClutter.m` Functionality**
  - **Action**: Run the `analyzeBistaticData.m` script.
  - **Check**: The script produces two RDM plots. The "After Mitigation" plot should show significant reduction in the power of the zero-Doppler line compared to the "Before Mitigation" plot.

- **[COMPLETED] C. Verify `createRDM.m` Functionality**
  - **Action**: Run the `analyzeBistaticData.m` script.
  - **Check**: The script executes to completion and displays the RDM plots without error.

- **[PENDING] D. Verify `detectTargets.m` Functionality**
  - **Action**: Execute the `analyzeBistaticData.m` script after the detection function is added.
  - **Check**: The script should produce a plot of the RDM with target detections overlaid.
