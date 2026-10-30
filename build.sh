#!/bin/bash
# build.sh device  -> build/Tumbler.ipa (armv7, iOS 6, unsigned; install with ideviceinstaller on an AppSync device)
# build.sh sim     -> build/sim/Tumbler.app (arm64 simulator, for previewing the layout with demo data)
# SDK93 must point at an iOS 9.3 SDK (stub frameworks are enough, we link with -undefined dynamic_lookup).
set -e
cd "$(dirname "$0")"
SRC=(src/*.m)
CSRC=(third_party/quirc/*.c)
CFLAGS=(-DQUIRC_MAX_REGIONS=65534 -Ithird_party/quirc -Isrc)
FW=(-framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework AudioToolbox)
if [ "$1" = device ]; then
    : "${SDK93:?set SDK93 to the iOS 9.3 SDK path}"
    rm -rf build/device; mkdir -p build/device/Payload/Tumbler.app
    OBJS=()
    # ObjC is compiled with ARC but linked without it: the Xcode toolchain has no libarclite, and iOS 6's libobjc already has the ARC entry points we use
    for f in "${SRC[@]}"; do
        o=build/device/$(basename "$f" .m).o
        xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" -fobjc-arc -Os -Wno-deprecated-declarations -Isrc -Ithird_party/quirc -c "$f" -o "$o"
        OBJS+=("$o")
    done
    for f in "${CSRC[@]}"; do
        o=build/device/c_$(basename "$f" .c).o
        xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" -O2 -w "${CFLAGS[@]}" -c "$f" -o "$o"
        OBJS+=("$o")
    done
    xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" "${FW[@]}" -undefined dynamic_lookup \
        "${OBJS[@]}" -o build/device/Payload/Tumbler.app/Tumbler
    cp Info.plist res/*.png build/device/Payload/Tumbler.app/
    cp LICENSE THIRD_PARTY_NOTICES.md build/device/Payload/Tumbler.app/
    (cd build/device && zip -q -r ../Tumbler.ipa Payload)
    echo "built build/Tumbler.ipa"
else
    SIM=$(xcrun --sdk iphonesimulator --show-sdk-path)
    rm -rf build/sim; mkdir -p build/sim/Tumbler.app
    xcrun clang -arch arm64 -mios-simulator-version-min=15.0 -isysroot "$SIM" -fobjc-arc -O0 -DTB_PREVIEW -Wno-deprecated-declarations "${CFLAGS[@]}" \
        "${FW[@]}" "${SRC[@]}" "${CSRC[@]}" -w -o build/sim/Tumbler.app/Tumbler
    cp Info.plist res/*.png build/sim/Tumbler.app/ 2>/dev/null || cp Info.plist build/sim/Tumbler.app/
    echo "built build/sim/Tumbler.app"
fi
