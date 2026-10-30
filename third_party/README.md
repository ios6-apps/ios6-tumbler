# Vendored libraries

## quirc

QR-code recognition library by Daniel Beer, used by `src/TBQR.m` because iOS 6 has no built-in QR detection.

- Upstream: https://github.com/dlbeer/quirc
- Version: 1.2 (release tag `v1.2`, commit `542848d`, March 2023). The files in `quirc/` (`decode.c`, `identify.c`, `quirc.c`, `quirc.h`,
  `quirc_internal.h`, `version_db.c`, `LICENSE`) are byte-for-byte identical to that tag; there are no local modifications.
- Licence: ISC (see `quirc/LICENSE`).
- Build: compiled as plain C with `-DQUIRC_MAX_REGIONS=65534` (see `build.sh` and `tests/run.sh`). Upstream's default is 254 regions; the larger
  value makes quirc use 16-bit region labels and allows many more connected regions in a cluttered image (a photographed screen), at the cost of a
  larger decoder object (the region table grows to 65534 entries). `QUIRC_MAX_REGIONS` above 65534 is rejected by upstream. The upstream demo and test programs are not included.

Updating: upstream `master` has received hardening fixes since v1.2 (bounded alignment-pattern search, integer-overflow fixes in image resizing).
The app decodes untrusted images, so it is worth syncing the six library files with a newer upstream revision, running `tests/run.sh`, and checking a real scan on a device.
