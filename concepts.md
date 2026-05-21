# Key Radar Signal Processing Concepts

This document tracks the key concepts introduced during this project and points to the relevant MATLAB files where they are implemented.

| Concept | Description | Implemented In |
| :--- | :--- | :--- |
| **Data Cube** | A 2D matrix structuring raw 1D signal data into `fast-time` (range) and `slow-time` (Doppler) dimensions for radar processing. | `loadIQData.m` |
| **Coherent Processing Interval (CPI) in Passive Radar** | In passive radar, there are no transmitted pulses. The CPI is an **artificial construct** created by segmenting the continuous incoming data stream into fixed-length chunks. Each chunk is treated as a "virtual pulse," allowing for Doppler processing. The length of this artificial CPI is a critical tuning parameter: a longer CPI improves Doppler resolution but can cause smearing for fast targets, while a shorter CPI has worse Doppler resolution but provides a clearer snapshot. | `analyzeBistaticData.m` (see `config.cpi_duration_s`) |
