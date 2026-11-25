# Reporting a security finding

## What to report

- A way for the closed application, a site or a page to do something a condition `[C1]` to `[C26]` of
  `lzrprf` says it cannot do.
- A statement in this repository that the code does not hold.
- A `selftest` run that passes while the condition it checks does not hold.
- A way to install a release that does not carry both valid signatures (VERIFY.md).
- A way to run a system program from `lzrprf` outside the subs and acts in CAPABILITIES.md.

## Where to report

- **Findings that are safe to show in public:** open an issue at
  https://github.com/lzrbrwsr/lzrprf/issues. Name the commit, the condition mark, the sub, and the
  smallest steps that show it.
- **Findings that should stay private until fixed:** this repository does not yet name a private
  channel.

  > PRIVATE CHANNEL: to be named by the owner before this line is removed.

  Until it is named, open an issue that says only that you have a private finding and how to reach
  you. Do not put the details in the issue.

## What to include

1. The commit of this repository (`git rev-parse HEAD`).
2. The build of macOS (`sw_vers -buildVersion`) and the Mac's chip.
3. The condition mark, and the name of the sub, as `tools/sub-map` prints it.
4. What you did, what you expected, what happened.
5. The `selftest` output when it is relevant (`perl selftest`).

Do not send key material, passwords or personal data of anyone.

## Scope

Out of scope: what THREAT_MODEL.md lists under "Out of scope".
