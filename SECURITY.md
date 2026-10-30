# Security policy

Tumbler stores two-factor secrets, so security reports are welcome. Please read the "Security and privacy" section of the
[README](README.md) first: several weaknesses (plain-text storage, a four-digit passcode that is only a UI lock) are known and documented limitations of
the current design rather than vulnerabilities.

## Reporting a vulnerability

Please do **not** open a public issue for a vulnerability. Use GitHub's private vulnerability reporting instead:
on the repository page open **Security > Report a vulnerability** (or **Security > Advisories > New draft security advisory**).
Include the device model and iOS version, what you did, and what you observed.

This is a hobby project maintained on a best-effort basis, so there is no guaranteed response time, but reports will be read and acknowledged.
There is no bug bounty.

## Scope

In scope: ways to obtain secrets or codes without the passcode that go beyond the known limits above, memory-safety problems in the parsers
(`otpauth://`, `otpauth-migration://`, base32, QR decoding), and the handling of the clipboard and URL scheme.

Out of scope: attacks that need root or file-system access on the device, and vulnerabilities in the iOS 6 operating system itself.
For the bundled quirc library, please report upstream at https://github.com/dlbeer/quirc as well.
