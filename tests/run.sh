#!/bin/bash
# Builds tests/test_core.m natively (macOS) together with the OTP core and the QR decoder, then runs it from the repo root.
# Covers RFC 4226 / RFC 6238 known-answer vectors, base32, otpauth:// and otpauth-migration:// parsing, and QR decoding of a generated code (CoreImage).
# Extra arguments are image files that must each contain exactly one QR code with a valid 2FA payload.
set -e
cd "$(dirname "$0")/.."
OUT=build/tests
mkdir -p "$OUT"
for f in third_party/quirc/*.c; do
    clang -O2 -w -DQUIRC_MAX_REGIONS=65534 -Ithird_party/quirc -c "$f" -o "$OUT/c_$(basename "$f" .c).o"
done
clang -fobjc-arc -Wno-deprecated-declarations -DQUIRC_MAX_REGIONS=65534 -Isrc -Ithird_party/quirc \
    -framework Foundation -framework CoreGraphics -framework ImageIO -framework CoreImage \
    tests/test_core.m src/TBOTP.m src/TBQR.m "$OUT"/c_*.o -o "$OUT/test_core"
"$OUT/test_core" "$@"
