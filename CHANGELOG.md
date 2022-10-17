# Changelog

## 1.1.3 (17/10/2022)

- Refactored wrapper code. Main script is physioWrapper.m and helper scripts are under code/cbrain.
- Variance reduced image is gzipped after creation.
- Updated PhysIO version to latest TAPAS release (6.0.0).
- Updated MATLAB runtime to R2021b.
- Changed Docker image name from tapasphysio to physio_cbrain.

Known bugs:
- BR and HR estimation may return all zeros on some datasets.

