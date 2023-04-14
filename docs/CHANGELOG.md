# Changelog

## 1.1.4 (14/04/2023)

- Fixed memory issues with large NifTI files
- Added error messages when data cannot be found in BIDS folder
- Changed Docker image versioning scheme to simply match version of PhysIO in use (8.1.0)
- Updated descriptor with output typesetting and help URL
- Removed 'derivatives' and 'PhysIO' output directory layers
- Set Docker container to run as nonroot user

## 1.1.3 (17/10/2022)

- Refactored wrapper code. Main script is physioWrapper.m and helper scripts are under code/cbrain.
- Variance reduced image is gzipped after creation.
- Updated PhysIO version to latest TAPAS release (6.0.0).
- Updated MATLAB runtime to R2021b.
- Changed Docker image name from tapasphysio to physio_cbrain.

Known bugs:
- BR and HR estimation may return all zeros on some datasets.

