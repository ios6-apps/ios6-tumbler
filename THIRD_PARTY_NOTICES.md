# Third-party notices

Tumbler itself is MIT licensed (see [LICENSE](LICENSE)). It includes the following third-party code.

## quirc

- Location: `third_party/quirc/`
- Upstream: https://github.com/dlbeer/quirc, version 1.2 (unmodified)
- Licence: ISC, copyright (C) 2010-2012 Daniel Beer. The full text is in `third_party/quirc/LICENSE` and in the header of each source file.

## Apple SDK

The iOS 9.3 SDK stubs used to link the armv7 build are **not** part of this repository. `tools/setup-sdk.sh` downloads them from
https://github.com/theos/sdks at build time; they remain subject to the Xcode and Apple SDKs Agreement. The built app links only against the system frameworks
that exist on the device.
