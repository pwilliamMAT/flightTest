# Synthetic HDTV Simulation Concepts

This local index tracks Synthetic HDTV simulation concepts and points to the MATLAB files where they are implemented. The repo-root `concepts.md` remains the cross-module index.

| Concept | Description | Implemented In |
| :--- | :--- | :--- |
| **Synthetic Session Archive Companion** | Each generated synthetic session now saves an additive full-session MAT companion that preserves the exact interleaved two-channel samples written to every packaged radar part, records the operational channel contract (`CH1 = surveillance`, `CH2 = reference`), and points back to the final manifest and truth artifacts. This archive is explicitly offline-only and does not replace the `.bb` plus `session_manifest.json` ingest path. | `generateSyntheticHDTVSession.m`, `helperSyntheticWriteBasebandParts.m`, `helperSyntheticBuildManifest.m`, `seedBackedSyntheticHDTVSessionWalkthrough.m`, `tests/SyntheticHDTVSessionGeneratorTest.m` |
