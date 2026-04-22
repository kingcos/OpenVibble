# Security Policy

## Reporting a vulnerability

If you find a security issue in OpenVibble, please **do not** file a public GitHub issue. Instead, report it privately via one of:

- GitHub's [private vulnerability reporting](https://github.com/kingcos/OpenVibble/security/advisories/new) (preferred)
- Email the maintainer at the address listed on the [@kingcos GitHub profile](https://github.com/kingcos)

Please include:

- A description of the vulnerability and its impact
- Reproduction steps or a proof-of-concept
- The version / commit you tested against (run `git rev-parse HEAD` if working from source)
- Any suggested mitigation

You should receive an acknowledgement within 5 business days. We'll work with you on a fix and a coordinated disclosure timeline.

## Supported versions

OpenVibble is pre-1.0; only the `main` branch is supported. Security fixes are not backported to older tags.

## Out of scope

- Issues that require physical access to an unlocked, paired device
- Vulnerabilities in upstream dependencies (please report those to the respective project)
- Behavior caused by jailbroken iOS devices or modified Claude Desktop / Claude Code installations
