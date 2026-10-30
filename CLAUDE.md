# Tumbler - notes for Claude Code (and other coding agents)

A TOTP/HOTP authenticator. It is security-sensitive: read `SECURITY.md` and the "Security and privacy" section of `README.md` before changing storage, the PIN, URL handling or the clock check.
Secrets are stored in plain text (the README documents this and the other known weaknesses); do not weaken anything further and do not log secrets, codes or `otpauth://` URLs.
`third_party/quirc` is vendored (ISC licence) and decodes untrusted images; keep it in sync with `THIRD_PARTY_NOTICES.md` when updating it.

This is an iOS 6 app (armv7, deployment target 6.0, written for an iPhone 5 on iOS 6.1.3) built with a current Mac toolchain. Read `README.md` for what it does
and `CONTRIBUTING.md` for the ground rules; this file is the short version for working on it.

## Build

    tools/setup-sdk.sh                       # once; fetches and patches the iOS 9.3 SDK stubs into ./.sdk (git-ignored)
    export SDK93="$PWD/.sdk/iPhoneOS9.3.sdk"
    ./build.sh device                        # unsigned build/Tumbler.ipa, armv7
    ./build.sh sim                           # arm64 simulator app build/sim/Tumbler.app, compiled with -DTB_PREVIEW

Needs Xcode (or its command line tools) on macOS. There is no Xcode project; `build.sh` calls `clang` directly. Do not commit `build/` or `.sdk/`.
If the device link fails with `file not found: /usr/lib/system/liblaunch.dylib`, the SDK was not patched: run `tools/setup-sdk.sh` again.

## Test

Run `tests/run.sh`. It builds `tests/test_core.m` natively with the real `TBOTP` and `TBQR` sources and quirc, and checks RFC 4226/6238 vectors, the Google Authenticator migration payload and QR decoding. It exits non-zero on failure.

CI (`.github/workflows/ci.yml`) runs the simulator build and the tests on macOS, then the device build. Run the same before proposing a change.

## Rules that are easy to break

- **iOS 6 APIs only.** No `NSURLSession`, `UIAlertController`, `UIStackView`, Auto Layout-only code, `@available`, Swift or new frameworks. The simulator is much newer than the target,
  so code that runs in the simulator can still crash on iOS 6: check the API's availability, not just whether it compiles.
- **ARC is compiled in but not linked.** Files are built with `-fobjc-arc`; there is no `libarclite` for iOS 6, so avoid constructs that need it. `__weak` is fine.
- **The device build links against SDK stubs** with `-undefined dynamic_lookup`. A missing symbol shows up as a crash on the phone, not as a build error. Prefer `dlsym` for anything newer than iOS 6.
- **Preview hooks (`TB_PREVIEW`) exist only in the simulator build.** They read environment variables (listed in the README) so a screen can be reached without tapping. Keep new hooks inside `#ifdef TB_PREVIEW`, and never let them into the device build.
- **No fake data outside previews and tests, no credentials, no personal addresses, no analytics.** Test data must be made up.
- **Be careful with the network.** Only touch the services the README lists. Do not run discovery sweeps or tests against hosts you do not own.
- Match the surrounding style: short comments that say why, not what.

## Layout

See the project layout table in `README.md`. Sources are in `src/`, drawing is done in code (no image assets except the icon and launch images, which `make_assets.py` draws; it needs Pillow).

## Versioning and releases

Do not tag or publish by hand. A merge to `main` publishes the `nightly` build; raising `CFBundleShortVersionString` in `Info.plist` plus a `CHANGELOG.md` section publishes a versioned release (see `CONTRIBUTING.md`). Note user-visible changes in `CHANGELOG.md`.

## Before you finish

Say how you checked the change: which tests, simulator and/or a real device. Do not claim a fix works on a device you did not run it on.
