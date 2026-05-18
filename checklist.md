# Project Plan and Progress

- **[COMPLETED] 1. Create MATLAB Data Loading Script**
  - **Task**: Develop a MATLAB script (`loadIQData.m`) to read and de-interleave raw IQ data.
  - **Verification**: Script successfully loads and de-interleaves data, confirmed by checking the dimensions of the output channel vectors.

- **[COMPLETED] 2. Reshape Data into a Data Cube**
  - **Task**: Add functionality to `loadIQData.m` to reshape the 1D channel data into a 2D `fast-time` x `slow-time` matrix.
  - **Verification**: Script successfully creates data cubes of the correct dimensions. A waterfall plot was generated for visual inspection.

- **[PENDING] 3. Perform Synchronization Check**
  - **Task**: Create a new script (`verifySync.m`) that takes the two channel data arrays, performs a cross-correlation, and plots the result.
  - **Verification**: Analyze the plot to find a strong peak corresponding to the direct-path signal, confirming time synchronization.

- **[PENDING] 4. Implement DPI and Clutter Mitigation**
  - **Task**: Create a script (`mitigateClutter.m`) to implement a Doppler-based filter on the surveillance channel's data cube.
  - **Verification**: Compare Range-Doppler maps before and after filtering to confirm attenuation of the zero-Doppler clutter.

- **[PENDING] 5. Implement Bistatic Range Estimation**
  - **Task**: Develop a script (`estimateRange.m`) that performs cross-correlation to generate a Range-Doppler map.
  - **Verification**: Inspect the Range-Doppler map for distinct target peaks.

- **[PENDING] 6. Implement CFAR Detection**
  - **Task**: Add a 2D CFAR detector to `estimateRange.m`.
  - **Verification**: Overlay CFAR detections on the Range-Doppler map to confirm correct identification of target peaks.

- **[PENDING] 7. Implement Target Tracker**
  - **Task**: Create a final script (`trackTargets.m`) to process detections with a Kalman filter.
  - **Verification**: Plot the estimated trajectory to ensure it is smooth and consistent.
