# Security Policy

## Scope

Ubunli is an **installer** that discovers and installs third-party security
tools from Kali's official repository. This policy covers vulnerabilities in
**Ubunli itself** — for example, its handling of the Kali repository, the GPG
signing key, APT pinning, package discovery, or privilege escalation via `sudo`.

Vulnerabilities in the tools Ubunli installs (nmap, Metasploit, sqlmap, etc.)
are **out of scope** here — please report those to the respective upstream
projects. Issues in Kali's packaging or metapackages should go to the
[Kali bug tracker](https://bugs.kali.org/).

## Supported Versions

Only the latest release on the `main` branch receives security fixes.

## Reporting a Vulnerability

**Please do not open a public issue for security problems.**

Instead, report privately using GitHub's built-in advisory flow:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability** (GitHub Private Vulnerability Reporting).

If that is unavailable, open a minimal issue titled `security contact request`
(with **no** technical details) asking the maintainer to open a private channel.

When reporting, please include where practical:

- A clear description of the issue and its impact.
- The affected part of the script (function name or line range).
- Steps to reproduce, and your OS / release / architecture.
- Any suggested fix.

## What to Expect

- **Acknowledgement:** within 7 days.
- **Assessment & fix timeline:** communicated after triage.
- **Disclosure:** coordinated. We ask that you give a reasonable window for a
  fix to ship before any public disclosure. Credit will be given to reporters
  who wish to be named.

## Good-Faith Research

We support responsible security research conducted in good faith. Testing must
be performed **only against systems you own or are explicitly authorized to
test**, and must not violate any law. See the warning in the
[README](README.md).

Thank you for helping keep Ubunli and its users safe.
