# Capabilities of lzrprf

This file lists what lzrprf can do on a Mac beyond fetching a page and showing it. For each power it
names the subs in `lzrprf` that hold it, its condition marks, why the browser needs it, the one act of
the person that sets it off, and the `selftest` runs that show it does not happen without that act.
`capabilities.json` holds the same facts for a program to read.

Subs are cited by name. To find their lines, run `perl tools/sub-map` (see AUDIT.md).

## How to read this file

- **Outside every container** means the program runs with the rights of the person's macOS account.
  lzrprf itself also runs there.
- **In a container** means a macOS sandbox profile written in `lzrprf` (`$CONTAINER`, `$FETCH`,
  `$WINDOW_CONTAINER`, `$DECODER`, `$CONVERTER`, `$SOUND_CONTAINER`, `$IMPORT_ALLOWED`, `$VERIFIER`, `$TOR_CONTAINER`, `$TRMNL_CONTAINER`),
  started through `/usr/bin/sandbox-exec` by `sub contain`.
- **The act** is a press, a choice or a typed address in lzrprf's own window. The window's process
  sends lzrprf one line for it, and lzrprf acts on that line alone.
- A run name is a key of `%about` in `selftest`. `perl selftest` runs all of them.

## Summary

| power | marks | where it runs | the act |
| --- | --- | --- | --- |
| The tool: processes and launchd jobs | `[C20]` | outside every container | open the tool; tick a row and confirm |
| The installer of a newer release | `[C4]` `[C5]` `[C25]` | outside every container | a yes to looking for releases; then Install it |
| The Tor client | `[C6]` `[C17]` | `$TOR_CONTAINER` | Tor on |
| The bookmark reader | `[C15]` | `$IMPORT_ALLOWED` | open the import wizard; choose a browser |
| The picture decoder (`sips`) | `[C3]` `[C21]` | `$DECODER` | visit a page with an AVIF, HEIC or HEIF picture |
| The stream converter (`avconvert`) | `[C22]` `[C24]` | `$CONVERTER` | click a video that is an MPEG-TS stream with sound |
| The sound process (`osascript`, core-lzrbrwsr-sound) | `[C3]` `[C12]` | `$SOUND_CONTAINER` | a click or a key in a page kept running, which then plays a sound |
| The terminal (LZRTRMNL): your login shell | `[C29]` | the shell outside every container, as you; its drawing in `$TRMNL_CONTAINER` | press the terminal icon of the local home |

## The tool: processes and launchd jobs `[C20]`

- **Subs:** `sub tool_shown`, `sub tool_look`, `sub tool_checked`, `sub tool_may`, `sub tool_done`,
  `sub tool_stop`, `sub tool_quiet`, `sub tool_off`, `sub tool_wake`, `sub tool_watch`, `sub tool_due`,
  `sub tool_kept`, `sub tool_keep`, `sub tool_signed`, `sub tool_file`, `sub tool_asked`, `sub tool_procs`,
  `sub tool_man`, `sub tool_notes`, `sub tool_note`.
- **Programs:** `/bin/ps`, `/bin/launchctl`, `/usr/bin/plutil`, `/usr/bin/codesign` (read only,
  `codesign -dv`), through `/bin/sh` for the loop over paths. All outside every container.
- **Why:** the tool shows what runs on this Mac and lets the person switch off a launchd job of their
  own account or ask a process of their own to end. What lzrprf saw is handed to the application in
  the page container, which has no network and no file.
- **The act:** a look starts when the person opens the tool from the window. A change starts only
  when the person ticks a row and then confirms. Each change is written in the log first.
- **Changes it can make:** `launchctl disable` then `launchctl bootout` (`sub tool_off`);
  `launchctl enable` then `launchctl bootstrap` (`sub tool_wake`); signal TERM to a process of the
  person's own (`sub tool_stop`).
- **Never:** in an incognito window; a job or process of the system or of Apple; lzrprf's own; with a
  password.
- **Repeat without a new act:** jobs the person switched off are kept in `~/.lzrprf/quieted`. At each
  start and every 300 seconds while a window is open (`$TOOL_WATCH`), `sub tool_watch` switches off
  again a job that something else switched on. This repeats the earlier tick and confirm. The person
  switches it on again in the tool.
- **Runs:** `tool`, `toolbad`, `toolwatch`. They use stand-ins for what the system's programs say, so
  no real job or process is touched. `tool` shows that only a ticked and confirmed row is changed.
  `toolbad` shows that an answer of the application with one line out of form changes nothing.
- **Show all processes:** a press at the bottom left of the list adds every process of the look with
  its share of a processor and its memory (`ps -axww -o pid=,%cpu=,rss=`), what it is (the
  application's word, else the manual page of its program read from `/usr/share/man` and the other
  man folders of this Mac, `sub tool_man`) and the note the person wrote to its program, kept in
  `~/.lzrprf/procnotes` after its log line (`sub tool_note`). Nothing of it is sent anywhere and
  nothing is changed; a process is changed only as a ticked row. Copy info copies what lzrprf
  gathered of one process to the clipboard on a press. Run `toolall` shows it.

## The installer of a newer release `[C4]` `[C5]` `[C25]`

- **Subs:** `sub newer`, `sub newer_looked`, `sub release_signed`, `sub manifest_read`,
  `sub signature_holds`, `sub signature_checked`, `sub release_key`, `sub approval_keys`, `sub installed`, `sub install_run`,
  `sub restarted`, `sub fixed`.
- **Programs:** `/usr/bin/curl` (contained, in `$FETCH`), `/usr/bin/ssh-keygen` (contained, in
  `$VERIFIER`), then `/usr/bin/env` and `/bin/sh` for the installer, outside every container, and
  `/usr/bin/open` for a restart.
- **Why:** an update replaces the application and lzrprf. The installer writes into Applications and
  `~/.lzrprf`, which no container allows.
- **The acts:** first, a yes to looking for newer releases, kept with its address in `~/.lzrprf/look`,
  or Check for updates in the cogwheel's menu for one look. Second, Install it, for the release the
  window offers. The installer runs only after Install it. After a finished install, a press on
  restart has `sub restarted` run `open -n` on the application.
- **What must hold before the installer runs** (`sub release_signed`, `sub installed`):
  1. The release file names the installer place, and the second place when there is one.
  2. `release.manifest`, `release.manifest.sig` and `release.manifest.approval` are fetched beside each
     place, and the two places hold the same bytes.
  3. The approval holds for an approval key lzrprf carries (`@APPROVAL_KEYS`, namespace
     `lzrbrwsr-approval`). This is checked first.
  4. The release signature holds for the release key lzrprf carries (`$RELEASE_KEY`, namespace
     `lzrbrwsr-release`).
  5. The manifest is in its one form (`sub manifest_read`), is of the published release number, is
     newer than the installed one, was signed no later than one day from now, has not expired, holds
     at most 400 days, and names `install.sh`.
  6. The installer is fetched from both places, up to 12 tries 30 seconds apart, and the copies are
     the same byte for byte.
  7. Its SHA-256 equals the manifest's `install.sh` line.
- **How it runs:** written to `~/.lzrprf/install.NUMBER/install.sh`, then run as
  `/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME=... TERM=dumb /bin/sh install.sh auto`
  in a session of its own, and ended after 1800 seconds (`sub install_run`). `lzrprf try` never runs it.
- **State today:** `@APPROVAL_KEYS` in `lzrprf` is empty. Until an approval key is written there,
  lzrprf refuses every release.
- **Runs:** without the act, `upno`, `uplater`, `upbad`, `upmoved`, `uplost` and `upunlogged` show that
  nothing is fetched or installed. `updiffer` and `upnosame` show that two differing places, or no
  place for the signed manifest, stop the update. With the act: `upyes`, `upcheck`, `uptwo`,
  `uptwobad`, `upquote`, `uplate`, `upsame`, `upown`, and the installer runs `installflush`,
  `installsignal`, `installgroup`, `installgone`, `installfetchtold`, `installendtold`, `installodd`,
  `installbanner`, `installbannerpipe`, `installbannerbare`, `installfault`.
- **Other tests:** the maker's own package test, not published here, checks that the installer refuses a release with a missing signature or approval, a stranger's approval key, an
  approval of other bytes, either signature in the other's place, no approval key, two places that
  differ, an expired manifest, or a changed manifest. VERIFY.md shows the same checks by hand.

## The Tor client `[C6]` `[C17]`

- **Subs:** `sub tor_on`, `sub tor_off`, `sub tor_failed`, `sub tor_reach`, `sub tor_where`, `sub tor_window_opened`, `sub tor_session_on`, `sub tor_sealed`, `sub tor_session_asked`, `sub tor_session_end`.
- **Program:** `arti`, beside the program, named by its SHA-256 in the release file (`file arti`).
  Started in `$TOR_CONTAINER` (its own folder and the network, nothing of the person's) through a
  `/bin/sh` guard.
- **Why:** to fetch through Tor. Each site's host is the SOCKS user, so each site gets its own circuit.
- **The act:** Tor on, from its icon in the window's bottom bar, opens a Tor window of its own: a
  fresh private session that browses only once Tor is connected and the window is shown sealed. While
  Tor is off no client runs. Tor off in a Tor window asks first, then closes the window whole and only
  then ends the client.
- **Runs:** `tor`, `torfail`, `torkeep`, `videotor`, `blockedtor`. A stand-in client relays SOCKS5. `torfail`
  shows that when Tor does not connect, nothing is fetched through Tor or directly.

## The bookmark reader `[C15]`

- **Subs:** `sub import_reader`, `sub import_profiles_of`, `sub import_kept`, `sub import_allowed`,
  `sub import_files`, `sub import_path`, `sub import_plan`, `sub import_go`.
- **Program:** `/usr/bin/perl` in `$IMPORT_ALLOWED`, with limits set by lzrprf (`sub limited`). No network, writes
  nothing, starts no program but itself.
- **Why:** to import bookmarks from Chrome, Edge, Brave, Vivaldi, Firefox and Safari without lzrprf or
  the closed application reading the home folder.
- **The acts:** opening the import wizard has the reader look whether each browser's folder is there.
  Choosing a browser has it read that browser's bookmark files. Allow on a folder in the Open panel
  has it try once more where macOS kept it out.
- **Runs:** `importreader`, `importwhy`, `importkept`, `importallow`, `allowpanel`, `importchrome`,
  `importfirefox`, `importsafari`, `importhtml`, `importhome`, `importwizard`. `importreader` shows the
  reader refused `History`, `Login Data`, `places.sqlite`, `History.db` and files outside the home
  folder.

## The picture decoder (`sips`) `[C3]` `[C21]`

- **Subs:** `sub system_decoded`, `sub decoding`, `sub decoder_named`, `sub pictured`, `sub holds`.
- **Program:** `/usr/bin/sips`, started by a waiting `/usr/bin/perl` (`$GATE`) that becomes `sips`
  only after the system said the process is contained. Container `$DECODER`.
- **Why:** the application cannot decode AVIF, HEIC or HEIF. `sips` writes a PNG of at most 1024
  pixels a side.
- **The act:** a visit to a page, by any road of `[C4]`, whose picture the application hands back whole
  as AVIF, HEIC or HEIF. At every start `sub holds` also runs `sips` once in that container as one of
  the `[C2]` tries.
- **Runs:** `picturesavif`, `pictureslarge`, `largeunstated`, `bigpng`, `decoderkilled`, `lostdecoder`.
  `pictureslarge` shows a file the application changed by one byte is not given to the system.

## The stream converter (`avconvert`) `[C22]` `[C24]`

- **Subs:** `sub system_converted`, `sub converting`, `sub ts_sounds`, `sub plain_read`,
  `sub videoed`, `sub hls_fetched`.
- **Program:** `/usr/bin/avconvert`, started by the same waiting perl. Container `$CONVERTER`.
- **Why:** the window's player cannot read the sound of an MPEG-TS stream in its container. avconvert
  copies pictures and sound into an MP4 without decoding them (`PresetPassthrough`).
- **The act:** a click on a video's place in the window, for an HLS stream lzrprf joined as MPEG-TS
  with sound.
- **Runs:** `hlsmore`, `hlsincog`, `hlssoundts`, `hlsplay`, `videoplay`. `videoplay` shows a video
  never clicked is never asked for.

## The sound process (`osascript`, core-lzrbrwsr-sound) `[C3]` `[C12]`

- **Subs:** `sub sounding`, `sub sound_told`, `sub sound_started`, `sub sound_flushed`, `sub sound_heard`,
  `sub sound_hushed`, `sub sound_ended`, `sub live_sound`, `sub live_sounded`.
- **Program:** `/usr/bin/osascript` running `$SOUND_TEXT`, through `/bin/sh` (`$SOUND_LIMITS`) and
  `sandbox-exec`. Container `$SOUND_CONTAINER`: three system services by name (the register of sound
  components, the sound server, the CoreServices daemon osascript needs), no network, no file written.
- **Why:** macOS plays no sound in a process that cannot reach its register of sound components, and
  the window's container keeps that name out (the owner's choice, 2026-11-21). The window keeps its 42
  names; the sound plays here instead, and each play is answered with what the system's player did.
- **The act:** a click or a key handed to a page kept running, within `$SOUND_PRESS_SECONDS` of which
  it plays a sound, or your click on a video's `Sound off` [C22] (its MP4 is handed over and its sound
  follows the window's clock of the picture, subs video_sound_kept and video_sound_at). Started for the
  first such sound of a window, after the system said it is contained; ended once nothing has played
  for `$SOUND_IDLE` seconds, or with the window. A video whose sound stays off starts none.
- **Runs:** `soundplays`, `soundwindow`, `soundvideo`, `soundvideowindow`, `livesound`, `livesoundbad`.
  `soundwindow` and `soundvideowindow` show the same text in the window's container plays nothing and
  says so.

## The terminal (LZRTRMNL) `[C29]`

- **Subs:** `sub trmnl_opened`, `sub trmnl_started`, `sub trmnl_shell`, `sub trmnl_input`,
  `sub trmnl_viewed`, `sub trmnl_pasted`, `sub trmnl_copied`, `sub trmnl_titled`, `sub trmnl_replied`, `sub trmnl_wrote`, `sub trmnl_read`, `sub trmnl_block`, `sub trmnl_end`.
- **Programs:** your login shell, the one the system names for your account when `/etc/shells` lists it,
  started by `sub trmnl_shell` as you, outside every container, on a pseudo-terminal of the system
  (`/dev/ptmx`), with `-l`, in your home folder, with nine variables and no descriptor of lzrprf's. Its
  screen is drawn by `core-lzrbrwsr-trmnl`, a program of the application, in `$TRMNL_CONTAINER` with
  `$TRMNL_LIMITS`, started by `sub trmnl_started`: no network, no file written, no program started, reads
  only its own program, the system's library cache and the root folder, and holds no descriptor of the
  terminal.
- **Why:** a terminal is a tab of the browser. A shell has your rights by what it is; what is kept in a
  container is everything that reads what the shell and its programs write.
- **The act:** a press of the terminal icon on the local home, taken only within a second of a press the
  window said, and only from the local home. Never in an incognito or Tor window. After that, only your
  keys and your paste reach the shell. The window reads the clipboard only on your paste (Cmd-V), and
  writes it only on your copy (Cmd-C), with the text you selected; a program's OSC 52 is passed over.
- **Runs:** none in `selftest` yet. Measured headless on macOS 27.2: see
  `managed-projects/lzrbrwsr/architecture/lzrtrmnl.md` in the repository the browser is built from.

## Every system program lzrprf names

| program | subs | when |
| --- | --- | --- |
| `/usr/bin/perl` | the start of the file, `find`, `proven`, `incognito_opened`, `pulled_command`, `profile_command`, `tor_window_opened`, `import_reader`, `decoder_named`, `system_decoded`, `system_converted`, `holds`, `run`, `tor_on`, `limited` | lzrprf re-runs itself by the system's perl. `find` looks up a host after its line is in the log `[C5]`, outside the containers. `proven` runs `selftest` after a yes to testing `[C11]`. The four `*_command`/`*_opened` subs start a new window after New Incognito Window, a tab pulled out, a profile opened, or Tor asked for in a window that is not a Tor window `[C17]`. The rest start a contained program, which `decoding` and `converting` are handed. `limited` starts one only when lzrprf holds more memory than a container may: a perl that sets that limit and becomes `sandbox-exec` (`$ROOM_SET`). |
| `/usr/bin/sandbox-exec` | `contain`, `run`, `tor_on`, `trmnl_started` | every contained start |
| `/usr/bin/osascript` | `run`, `witnessed`, `decoder_named`, `sounding` | the window, in `$WINDOW_CONTAINER` `[C10]`; the sound process, in `$SOUND_CONTAINER` `[C12]`; and the question whether a process is contained (`$WITNESS`, started by `witnessed` and asked by `inside`; `$NAMED` for the decoder) `[C3]` |
| `/usr/bin/curl` | `fetch` | each request, in `$FETCH` `[C3]` `[C6]` `[C7]` |
| `/usr/bin/sips` | `system_decoded`, `holds` | see the decoder |
| `/usr/bin/avconvert` | `system_converted` | see the converter |
| `/usr/bin/ssh-keygen` | `signature_checked` (asked by `signature_holds`) | a release's two signatures, in `$VERIFIER` `[C25]` |
| `/bin/ps` | `tool_look`, `tool_stop`, `shell_held`; the limits strings `$SOUND_LIMITS`, `$TRMNL_LIMITS` | the tool `[C20]`; one shell reads its own memory size once as a window begins, and every container is limited to it and 2 GiB more (`sub limited`); the sound and terminal shells read their own |
| `/bin/launchctl` | `tool_look`, `tool_off`, `tool_wake`, `tool_watch` | the tool `[C20]` |
| `/usr/bin/plutil` | `tool_file` | reads a launchd property list for the tool `[C20]` |
| `/usr/bin/codesign` | `tool_signed` | reads who signed a program, for the tool `[C20]` |
| `/sbin/route` | `route_asked` (run by `route` and `find`) | `route -n get`, read only: whether an address leads into the person's own network `[C8]` |
| `/usr/bin/env` | `install_run`; the limits strings `$SOUND_LIMITS`, `$TRMNL_LIMITS` | the installer, after Install it `[C25]`; the sound and terminal shells, their limits set, become `env -i` with lzrprf's own names alone, which starts `sandbox-exec` |
| `/bin/sh` | `install_run`, `shell_held`, `signature_checked`, `sounding`, `tool_signed`, `tor_on`, `trmnl_started` | sets the limits of the sound and terminal containers, and redirections, before a program starts; measures a shell once; runs the installer |
| `/usr/bin/open` | `restarted` | after a finished install and a press on restart |
| `/usr/bin/xattr` | `excluded` | marks a kept log to be left out of Time Machine; only when the person chose to keep a log |
| `/usr/sbin/sysctl` | `mark` | reads the build of macOS for the selftest mark `[C11]` |
| `/usr/bin/true` | `$TRIES` | never on purpose: the `[C2]` tries ask a container to start it, and it must refuse |

`selftest` checks this list against `lzrprf` itself, from the list `programs` of `capabilities.json`.
It finds every place `lzrprf` starts a system program: the program's path as a string of its own, at
the head of a command of a shell (`$(/bin/ps`, `exec /usr/bin/env`), or in a name that holds the path
(`$CURL`, `$SCRIPT`, `$SIPS`, `$AVCONVERT`) where the name is used. Each place is named by the sub it is
in, or by the variable whose text it is (the limits strings, `$TRIES`), or as the start of the file. A
program started where the list does not name it fails, and so does a line of the list that `lzrprf` no
longer starts. `selftest` also checks that `lzrprf` turns into another program only at the start of the
file and in `sub become`, so no start goes around that one sub (the programs whose path is not
written in `lzrprf`, the application and the Tor client, are the powers above); and it runs the check on two changed copies of `lzrprf`, one that starts `/usr/bin/whoami`
and one that no longer starts `/usr/bin/xattr`, to show that each is noticed.
