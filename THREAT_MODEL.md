# Threat model

This file says what lzrprf and the LZRBRWSR release process protect, from whom, what they trust, and
what they leave out. It states the design. Whether the code meets it is for a reader to check, with
the conditions `[C1]` to `[C26]` in `lzrprf` and the runs of `selftest`.

## What is protected

1. **The person's files and accounts.** The closed application reads no file under `/Users`, writes
   no file, and has no network of its own `[C1]` `[C2]` `[C10]`.
2. **Other applications and the system.** The application starts no other program, sends no signal
   to another process, and reaches no system service `[C2]` `[C10]`.
3. **What the person did not ask for.** No request is made that did not come from the bar, a
   bookmark, the home page, a redirect said yes to, a page's pictures, style sheets and videos within
   limits, a page kept running within `[C19]`, or a fixed address of the release file after a yes
   `[C4]`. Each is in the log first `[C5]`.
4. **The person's own network.** A host inside it is fetched only after a yes to exactly that `[C8]`.
5. **What is kept.** Nothing of what was fetched stays on the disk unless the person chose a kept log
   `[C12]`. An incognito window leaves nothing behind `[C16]`.
6. **What is installed.** An update installs only a release whose manifest both keys signed `[C25]`.
7. **Scripts.** No script runs that the person did not allow `[C26]`.

## From whom

| who | what they might try | what stands in the way |
| --- | --- | --- |
| The closed application | read files, reach the network, keep data between pages, start programs, read facts of the Mac and send them | the page container (`$CONTAINER`), probed at every start `[C2]`; every line it writes checked `[C9]`; it is started only inside the container `[C1]` `[C3]` |
| A site | send bytes that exploit a parser | the application parses inside the page container; pictures it cannot decode go to `sips` in `$DECODER` `[C21]`; MPEG-TS streams to `avconvert` in `$CONVERTER` `[C24]`; video goes to the system's player in the window's process `[C22]` (see "Out of scope") |
| A site or a page kept running | make requests the person did not ask for | `[C4]` `[C19]` `[C26]`; a POST to another host is asked for on its own |
| Someone on the network | read or change traffic | TLS by the system's `curl` `[C6]` `[C7]`; Tor when turned on `[C17]` |
| Someone who changes one download place | publish a changed installer or download | the two places must agree; the manifest names each file's SHA-256; both signatures must hold `[C25]` |
| Someone who controls the project's server | sign a release without the owner | an approval by a key of `approval-keys.pub` is required, and the signing service checks it before signing. Without the agent approval key, that is the owner's phone. While `approval-keys.pub` lists the agent approval key, its private half is on the server too, so control of the server signs a release until its `valid-until` day or until a release drops its line |
| Someone who controls the owner's phone | approve a release without the server | the approval key alone cannot make the release signature |
| Automation or an agent of the maker | publish a release with no person involved | the owner's key opens only to his Face ID at each use. By the owner's decision (2026-11-22) the maker's tooling releases as work lands with the agent approval key while it is listed: not stopped, but limited to its `valid-until` day, and revoked by a release that drops its line |

## What is trusted

| trusted part | why it must be trusted | where that trust is limited |
| --- | --- | --- |
| macOS, its kernel and its sandbox | every container is a macOS sandbox profile | each container is probed from inside at every start `[C2]`, and the system is asked whether a process is contained `[C3]` `[C10]` |
| The system's programs (`perl`, `curl`, `osascript`, `sips`, `avconvert`, `ssh-keygen`, `ps`, `launchctl`, `plutil`, `codesign`, `route`) | lzrprf uses them instead of code of its own | each runs by a fixed path; those that read a site's bytes run in a container (CAPABILITIES.md) |
| lzrprf itself | it runs outside every container and decides | it is one readable file; its SHA-256 is in `release.txt` and in the app's release file `[C11]` |
| The release key, on the project's server | it makes the release signature | it signs only after a valid approval; it is readable only by the signing service; it signs each release number once |
| The approval key, in the Secure Enclave of the owner's phone | it makes the approval signature | it is made there, never leaves the phone, is in no backup, and opens only to Face ID at each use |
| The agent approval key, on the project's server | while listed, it makes the approval signature | made on the server, readable only by the signing service; refused after its `valid-until` day by lzrprf and the installer |
| The person's macOS account | lzrprf, the launcher and `~/.lzrprf` live there | see "Out of scope" |
| Arti, the Tor client | it carries traffic while Tor is on | named by its SHA-256 in the release file; runs in `$TOR_CONTAINER` `[C17]` |
| The two download places | availability | they must agree, and the signatures make a change in one of them fail |

## Out of scope

These are not protected. Each is stated so a reader does not assume otherwise.

- **A taken-over Mac account.** Any program running as the person can change `~/.lzrprf/lzrprf`, the
  launcher, the application or the state folder. lzrprf finds a changed program between reads, as
  after an update, but not someone with the account's rights.
- **A flaw in macOS.** A way out of a sandbox, or a flaw in the kernel, is outside what lzrprf can
  hold.
- **Decoding done by the system.** `sips` hands decoding to the system's video decoder service, which
  runs outside every container of lzrprf, in Apple's own sandbox for that service `[C21]`. A flaw there
  is not contained by lzrprf.
- **Video in the window's process.** The system's player reads a clicked video's MP4 container and
  decodes its sound in the window's own process `[C22]`. A flaw there that a site's file reaches hands
  that site the window's process, and with it what lzrprf trusts the window to say.
- **The window container is the weaker kind.** `$WINDOW_CONTAINER` allows by default and lists what it
  refuses. The other containers refuse by default.
- **What a site does with what the person sends it**, on its own servers. Fake sites. What the person
  copies into another program.
- **The person's internet address**, and how this Mac speaks TLS, TCP and IP. Sites, the maker's server
  and GitHub see the address of a request.
- **What a server keeps.** What the maker's server keeps of a report or a request cannot be checked
  from the person's Mac.
- **Both keys at once.** Someone who controls both the project's server and the owner's phone with
  Face ID can sign a release. While the agent approval key is listed, the server alone can.
- **The swap, crash reports, the resolver's cache, disk snapshots and backups.** macOS keeps these on
  its own. lzrprf marks a kept log to be left out of Time Machine and cannot prevent the rest.
- **Physical access** to the Mac or the phone.

## Where each part is checked

- Conditions and their probes: README.md, "The conditions".
- Powers and the acts that start them: CAPABILITIES.md.
- The release signatures, by hand: VERIFY.md.
- How to audit: AUDIT.md. How to report: SECURITY.md.
