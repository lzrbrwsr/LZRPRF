# The installer

This text was the README section "The installer" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- "Nothing here is signed with a key of the maker's" became: from release 76 on a release must carry
  the release key's and an approval key's signatures over its manifest ([C25]).
- The table row on a named maker: "nothing is signed with a key ... It is not built" became the same
  [C25] statement; up to release 75 nothing is signed with a key.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/installer.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| install.sh in this repository is the installer that ... | - | - | - |
| The first line saves the installer from the ... | - | - | - |
| The installer asks, at its start, for each ... | - | - | - |
| - sh install.sh parts=lzrbrwsr,lzrtnnl chooses without asking; parts=lzrbrwsr ... | - | - | - |
| - Started in auto (lzrprf's update) or with ... | - | - | - |
| - The program of a part left out ... | `paired`, `part_left_out` | - | - |
| - What you chose is written last, under ... | `parts_read`, `parts_set`, `parts_fetched`, `installed` | - | - |
| The package test pins each choice (scripts/test-package-parts.sh of ... | - | - | - |
| Everything that is installed stands in two places: ... | - | - | - |
| what is compared who compares the line ... | - | - | - |
| the installer, before it runs your own shell ... | - | - | - |
| the download the installer in install.sh: fetch "$SECOND/$FILE" ... | - | - | - |
| the installer of a newer release lzrprf sub ... | `installed`, `fixed` | - | - |
| What each is worth, and no more: ... | - | - | - |
| - The installer is the root. It carries ... | - | - | - |
| - The second comparison adds a record, not ... | - | - | - |
| - The third closes the road of a ... | - | - | - |
| So for anyone who pastes the three lines ... | - | - | - |
| What the two places do not cover: ... | - | - | - |
| - One maker holds both. Somebody with the ... | - | C25 | - |
| - What "on record" is worth. This repository's ... | - | - | - |
| - The three lines themselves. Most people copy ... | - | - | - |
| - https. Both fetches rest on TLS and ... | - | - | - |
| - Your shell. The three lines start curl ... | - | - | - |
| - main moves. The second line compares with ... | - | - | - |
| - The installer's word about itself. What the ... | - | - | - |
| - A hash and a branch. A commit ... | - | - | - |
| - A release in the making. For some ... | - | - | - |
| What the installer does, each step readable in ... | - | - | - |
| - Asks, on your terminal, whether to print ... | - | - | - |
| - Needs no password and no sudo. Before ... | - | - | - |
| - Has six settings for its own test, ... | - | - | - |
| - Refuses to put an older release over ... | - | - | - |
| - Fetches lzrprf and selftest from this repository ... | - | - | - |
| - Checks that the download holds exactly six ... | - | - | - |
| - When the release would replace the lzrprf ... | - | - | - |
| - Runs selftest and stops if one line ... | - | C11 | - |
| - Places files alone. Right after its questions, ... | - | - | - |
| - What an earlier install left behind is ... | - | - | - |
| - Only then are files put in place, ... | - | - | - |
| - Removes two files an earlier lzrprf kept ... | - | - | - |
| - Never runs the closed program. Installs no ... | - | - | - |
| It takes no attribute off any file. Up ... | - | - | - |
| From release 8 on the download is also ... | - | - | - |
| The two values are the same with the ... | - | - | - |
| Gatekeeper's question at a first start (is this ... | - | - | - |
| What stands where Apple's notarization would stand, and ... | - | - | - |
| notarization gives here ... | - | - | - |
| Apple's scan found no known malware in the ... | - | C2 | - |
| The bytes are the ones the maker handed ... | - | - | - |
| A named maker, and a ticket Apple can ... | - | C25 | - |
| A signature says who made a program, not ... | - | - | - |
<!-- index end -->

`install.sh` in this repository is the installer that https://lzrbrwsr.com/install.sh serves, and
`release.txt` holds the SHA-256 of it, of the download, and of each file in the download. The
installer runs from a file and never from a pipe, so that what runs is something you can read
and check first:

    curl -q -fsSO https://lzrbrwsr.com/install.sh &&
    curl -q -fsS https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/install.sh | cmp - install.sh &&
    sh install.sh

The first line saves the installer from the site as a file. The second compares that file, byte
for byte, with `install.sh` in this repository, where every change to it is on record. It
prints nothing when the two are the same, and it names the first difference when they are not.
The third line runs only when they are the same. Your own shell makes that comparison before a
byte of the installer has run. The installer cannot make it for you, because a changed
installer would simply say yes; so it only shows its SHA-256 and says where the published one
is. What the comparison shows: the site and this repository serve the same installer, so
somebody who changed one would have had to change the other too, in public. It does not show
that the installer is good. For that, read it: it is plain text.

## The parts you include

The installer asks, at its start, for each part of LZRBRWSR whether to include it (Henry, 2026-11-24,
HC-0858). LZRBRWSR itself, the browser with its profiles and settings, is always installed: the window,
and the settings where the others are switched later, are its own. Then, one by one: LZRDFNDR (the tool
that shows and stops what runs on this Mac), LZRTRMNL (the terminal tab), LZRTNNL (Tor, with an
optional VPN of your own) and LZRGM (the minigame). Enter takes the answer in capitals: on a first
install every part, over an earlier install what that one chose.

- `sh install.sh parts=lzrbrwsr,lzrtnnl` chooses without asking; `parts=lzrbrwsr` is the browser alone.
  A name that is no part stops the installer before anything changes.
- Started in auto (lzrprf's update) or with no terminal, the parts of the last install are kept.
- The program of a part left out (`arti` for LZRTNNL, `core-lzrbrwsr-trmnl` for LZRTRMNL) is taken out
  of the checked download before it is put in place. The download and its checksums are the same for
  everyone; lzrprf takes the absence of such a program for what was installed (`sub paired`,
  `sub part_left_out`). LZRDFNDR and LZRGM are inside the program and lzrprf: left out, they stay on
  the disk, switched off and shown nowhere.
- What you chose is written last, under the installer's lock, to `~/.lzrprf/parts`: the line
  `lzrbrwsr parts 1`, then one part a line (`sub parts_read`). "Add or remove LZR modules" in the
  window writes the same record (`sub parts_set`); a part added there whose program is not on the disk
  runs this installer of the published release through the signed road of an update, with the parts
  as its word (`sub parts_fetched`, `sub installed`).

With LZRTRMNL, `lzr`, its command, is put on the PATH of new terminals without sudo: a launcher in
`~/.lzrprf/path`, and one marked line in `~/.zprofile` and `~/.zshrc` (and `~/.bash_profile` when your
login shell is bash) that adds that folder, never twice. An install without LZRTRMNL takes the launcher
and the lines away; switching LZRTRMNL off in "Add or remove LZR modules" takes the launcher away, and
the next install the lines. Staging's launcher is `lzr-stg` in `~/.lzrprf-stg/path`, so the two never
shadow each other. When the installed lzrprf has no lzr yet, the launcher says so in one line.

The package test pins each choice (`scripts/test-package-parts.sh` of LZRBRWSR, step 25).

## Two places, and exactly what they are worth

Everything that is installed stands in two places: the maker's site, and this repository at
GitHub. They are two separate systems, and this one keeps every change with its date, as far
as ordinary git history does (see "What "on record" is worth" below). Three
comparisons use that. Each is a line you can read:

| what is compared | who compares | the line |
| --- | --- | --- |
| the installer, before it runs | your own shell | the second of the three lines above |
| the download | the installer | in `install.sh`: `fetch "$SECOND/$FILE" "$tmp/second"`, then `cmp -s "$tmp/$FILE" "$tmp/second"`; `SECOND` is this repository |
| the installer of a newer release | lzrprf | `sub installed`: two fetches through `sub fixed`, then `$copies[0] ne $copies[1]`, before anything is written or run |

What each is worth, and no more:

- **The installer is the root.** It carries the SHA-256 of the download, of `lzrprf` and of
  `selftest` (the lines `SHA256=`, `LZRPRF_SHA256=` and `SELFTEST_SHA256=`) and stops on a file
  that does not match (`get` in `install.sh`). So with the true installer, no changed file is
  installed, wherever it was fetched from. That leaves one question: is this the true installer?
  Before a first install, nothing on your Mac knows. The first comparison answers it as far as
  it can be answered without a key: two separate systems serve the same bytes. That shows
  that the two agree, not who wrote the bytes: both places are the maker's, so whoever holds
  both is not found by it, nor is one who stands between you and both with a certificate
  your Mac trusts.
- **The second comparison adds a record, not strength.** A changed installer would skip it, and
  against a changed download the checksum already stands. What it adds: the installer stops
  unless the file it is about to install is the file on record here. So every release anyone
  installed is in this repository's history, with its date, for anyone to fetch and take apart,
  as long as nobody rewrote that history (see "What "on record" is worth").
- **The third closes the road of a newer release**, which the first comparison does not cover,
  because nobody types the three lines then.

So for anyone who pastes the three lines printed here, and on the road of a newer release: to
put a changed program on a computer, the site and the `main` branch of this repository have to
be changed for the same moment, and the second is a public commit.

What the two places do not cover:

- **One maker holds both.** Somebody with the maker's computer or accounts can change both
  places. The change would be in this repository's history for everyone to see; an install in
  that moment would not notice it. From release 76 on a release must carry two signatures over its
  manifest: the release key's, held on the project's server, and an approval key's, held in the
  owner's phone, both public halves in `lzrprf` (`[C25]`, VERIFY.md). Up to release 75 nothing is
  signed with a key.
- **What "on record" is worth.** This repository's history is ordinary git at GitHub. Whoever
  holds the account can rewrite it with a forced push, the date of a commit is written by its
  author, and no rule of the repository forbids either today. What stands against a rewrite is
  every copy somebody else fetched before, and GitHub's own record of pushes, which the maker
  does not hold. The download is kept as a plain file in git, about 200 KB.
- **The three lines themselves.** Most people copy them from the site, and a changed site could
  show other lines. They are printed above, and in the first lines of `install.sh`. What you
  paste must be these.
- **https.** Both fetches rest on TLS and on macOS's list of certificate authorities: an
  authority that can speak for both hosts can change both copies on their way to you.
- **Your shell.** The three lines start `curl` from your shell, with your shell's variables (a
  proxy, a file of certificates): `-q` keeps curl from a settings file and no more. The same
  three lines with no variable of your shell:

      /usr/bin/env -i /usr/bin/curl -q -fsSO https://lzrbrwsr.com/install.sh &&
      /usr/bin/env -i /usr/bin/curl -q -fsS https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/install.sh | /usr/bin/cmp - install.sh &&
      /usr/bin/env -i /bin/sh install.sh

- **`main` moves.** The second line compares with `main` as it is in that moment, which shows
  that the two places agree now, not that this is the installer somebody read. Whoever read
  one release keeps two things from that reading: the full hash of the commit, and the
  SHA-256 of its `install.sh` (`release.txt` at that commit names it). Then
  `shasum -a 256 install.sh` on the file about to run must print that value.
- **The installer's word about itself.** What the installer promises to check proves nothing
  about the installer itself. Read it, or compare its SHA-256 with the one from somebody's
  reading, before you run it.
- **A hash and a branch.** A commit hash names content; a branch name such as `main` names
  whatever is newest there. Neither says who put it there.
- **A release in the making.** For some minutes the two places can differ, and GitHub serves a
  raw file from a cache for up to five minutes. A comparison then stops and nothing is
  installed. Try again later; if it still differs, one place was changed. `main` is what is
  released: lzrprf's own files and the release's files reach it in one push. A branch named
  `next` holds lzrprf's files of a release whose tests passed, from then until that push. In
  the minutes between the site serving a new installer and that push, the installer takes
  `lzrprf` and `selftest` from their commit on `next`, by its full hash and with their
  SHA-256 checked, as always.

What the installer does, each step readable in the file:

- Asks, on your terminal, whether to print the whole of itself, and then whether to run: two
  questions, the second whatever you answered to the first. Piped into a shell, or with no
  terminal to ask on, it runs nothing.
- Needs no password and no `sudo`. Before anything else it looks at what it would hand on to
  a program it starts, and goes on only when that is your home folder (as this Mac's list of
  accounts gives it), the system's own `PATH`, the kind of terminal as one plain word, names a
  shell sets for itself, each in its plain shape (`PWD`, `SHLVL`, `_`; zsh also `OLDPWD` and
  `LOGNAME`), and nothing else; with anything else there, or with a line break or another
  control character inside one of those values, it starts itself once more through
  `/usr/bin/env -i` with the first three (a test keeps its six settings too). So the curl, the
  perl and the `selftest` it starts get no variable of your shell (`PERL5OPT`, `PERL5LIB`,
  `SSL_CERT_FILE`, …). No mark says "already clean" that a starter could set (releases before
  15 used the number of the process as one): what is there is read by a perl that is itself
  started through `env -i`, and the lines before it name their tools by full path and use
  words of the shell that no function can give another meaning. What those first lines cannot
  see or undo is what `/bin/sh` took in for itself at its own start and does not hand on. On
  macOS `/bin/sh` is bash: it reads `SHELLOPTS` and `PS4`, and with those a command written
  into `PS4` runs before each of these lines, as the starter's own program. The second start
  has neither; started as `/usr/bin/env -i /bin/sh install.sh` (see "Your shell" under the
  three lines), the first has neither as well. Where an administrator made zsh the `/bin/sh`,
  it reads more for itself: the one found to act (`ARGV0`, the name it gives the programs it
  starts) is unset at the top, and `IFS` with it. What stays from the starter to the end and
  is no variable: the current folder, open files, limits, and signals set to be ignored. From
  a folder whose name holds a control character the installer does not start, and says so.
  It fetches over https
  only, with `/usr/bin/curl -q`, and follows no
  redirect: each file comes from the address written in the installer, or not at all (the
  function `fetch` in `install.sh`).
- Has six settings for its own test, read from variables of your shell whose names begin
  `LZRBRWSR_` or `LZRPRF_`. They are taken only when every file then comes from this computer
  (`file:///`), that is, opened through this computer's file names; a network volume mounted
  on this Mac has such names too, and every SHA-256 must still match. With one of them set and
  an https address in play, it stops and says so. So a
  variable somebody put into your shell cannot point a real install elsewhere or answer a
  question for you. With them in use, those six and the test's home folder are the only
  variables it keeps.
- Refuses to put an older release over a newer one: it looks in `/Applications` and in
  `~/Applications`, whichever of them it installs to.
- Fetches `lzrprf` and `selftest` from this repository at one fixed commit and checks their
  SHA-256. Fetches the download from the site and checks its SHA-256, fetches it again from
  this repository, and stops unless the two are the same file.
- Checks that the download holds exactly six files and no link, and that three of them are,
  byte for byte, texts written out in the installer: the launcher the icon runs (its one
  command starts perl through `env -i`; that perl finds your home folder in this Mac's list
  of accounts and starts `lzrprf run` with the `lzrbrwsr-bin` beside it, or shows an alert
  when lzrprf is missing), the property list that names the launcher to
  macOS and sets no variable for it, and the `release` file with its addresses (shown in "A
  newer release").
- When the release would replace the `lzrprf` that is installed with another one, shows both
  SHA-256 values and asks. The container is never changed silently.
- Runs `selftest` and stops if one line says `FAILED`. An `UNTESTED` line does not stop it:
  each one is printed again when the test ends, with its reason, the mark names it, and
  LZRBRWSR asks about it before it starts. A test that held writes the mark of `[C11]`, so the mark is on your Mac before
  any file is placed. An install that stops after the test, and before files are put in
  place, has added two things to the folder `~/.lzrprf`, and nothing else: that mark
  (`proven`) and the empty file `selftest.lock`. It has also set that folder's rights to
  yours alone (700).
- Places files alone. Right after its questions, before it compares releases or tests anything, the
  installer takes a lock: a link `~/.lzrprf/.installing` whose text is its process number and
  the moment that process started, read in one time zone whatever the Mac is set to. A second
  installer stops while the first one lives. The lock is in your home folder, so it holds for
  your account: an installer that another account of this Mac runs at the same moment is not
  seen by it, and both can write `/Applications`. A lock whose installer is gone (killed, or the
  power failed) is taken over, by one installer at a time. The lock is taken away as
  soon as the new parts stand at their names and the removal of the older ones was tried
  (whether or not it worked), before the installer removes `rules` and `refused`, prints its
  last lines and asks about the Dock; and at a failure, at Ctrl-C, Ctrl-\
  or a closed Terminal. A kill
  that no program can catch (`kill -9`) or a power failure leaves it, for the next installer
  to take over.
- What an earlier install left behind is looked at before files are put in place. In
  `~/.lzrprf`, staging folders (`.new.*`) that hold nothing of their own are removed; one that
  holds an older lzrprf which is not the installed one is the only copy of it, is kept, and is
  named each time until you remove it. In the app's folder a hidden folder `.LZRBRWSR.*` that
  holds anything is never removed, only named.
- Only then are files put in place, into `/Applications`, or into `~/Applications` when your
  account may not write there. Both new parts, the app and lzrprf, are first written whole
  beside the ones they replace, under names nobody can know beforehand, and checked there.
  Then they take their names by renames, back to back. If one fails, or Ctrl-C or Ctrl-\
  comes, it puts the older app and the older lzrprf back as a pair. What stands at lzrprf's
  two names must be a plain file or nothing: a folder or a link there stops the installer
  before it places anything. When a part cannot be put back, nothing
  older is removed: the installer says that not everything is back, and names each part that
  is not and where it is kept. That is true of the installer's own steps. It cannot undo a disk that fails
  in that moment, or another program that removes files then. An install that was killed outright, or lost power, between
  its renames can also leave a mixed pair. From release 12 on such a pair is noticed at the
  next start, when both parts know the line: lzrprf finds its own SHA-256 is not the one the
  app's `release` file names. The lzrprf of release 12 says so and asks, and can be told to
  start anyway; from release 13 on lzrprf says so and does not start, with one button, Quit.
  An app of release 11 or earlier names no lzrprf: from release 15 on lzrprf does not start
  such an app either. An lzrprf of release 11 or earlier does not look, so a mixed pair with
  that older lzrprf in it, as an update from release 11 that was cut off would leave, is not
  noticed. An lzrprf of release 16 or later also compares the launcher and the program, each
  with its line `file` in the app's `release` file, and from release 17 on stops at a file
  beside them that no line names. Installing again mends it in every case.
- Removes two files an earlier lzrprf kept and this one does not: `~/.lzrprf/rules` and
  `~/.lzrprf/refused`. A log an earlier release wrote is not removed: while nothing is
  kept, the installer says that it is there, and the Log button of the window offers to clear
  it.
- Never runs the closed program. Installs no other program, service, extension or updater,
  and leaves nothing running: no login item, no helper, nothing that runs by itself. What it
  does besides placing the app, `~/.lzrprf/lzrprf` and `~/.lzrprf/selftest`, each said above:
  it makes the folder `~/.lzrprf` and sets its rights to 700, makes the folder the app goes
  into when that is missing, and keeps there the mark
  `proven` and the empty file `selftest.lock` that `selftest` writes, and its own lock until
  the files are placed; it removes `~/.lzrprf/rules` and `~/.lzrprf/refused` of older releases; it leaves
  a log that is there alone; and it asks before it touches the Dock, and on a yes adds one
  entry and starts the Dock again so that it shows (`killall Dock`). Its temporary folder is taken away when it ends, its lock already when the files are
  placed (above); a kill no program can catch, or a power
  failure, leaves them, and with them the staging folders in which it readied the new parts,
  beside the installed ones: the next install removes those, or names them when they hold an
  older part. A folder that holds an older part it could not put back stays, and is named.

It takes no attribute off any file. Up to release 6 it ran `xattr -cr` on the unpacked files;
from release 7 on there is no such line. The line took away nothing that was there: a file
fetched with `curl` and unpacked with `tar` is not given the quarantine mark, which browsers
and mail programs set. But an installer has no business taking marks off, so a mark that macOS
put on a file stays where it is, and the download is packed without attributes of its own
(`tar --no-xattrs --no-mac-metadata`). To see that:
`gzip -dc lzrbrwsr-macos-arm64.tar.gz | LC_ALL=C grep -ac -e SCHILY.xattr -e LIBARCHIVE.xattr`
prints 0.

From release 8 on the download is also packed the same way every time: its entries in one
order, one fixed time and one set of rights on each, no owner, and no time in the gzip header.
The same six files give the same bytes. So you can see that the archive holds the files you
see in it and nothing beside them: unpack it, pack it again, and compare. From release 10 on
the program inside it holds no path of the computer it was built on (`strings` shows none
under `/Users`). That the same source gives the same program whichever folder it is built
from, and that a program with the same SHA-256 across releases was built the same way, cannot
be checked without the source: it is the maker's word. What you can check is the SHA-256 of
the packed file and of each file in it against `release.txt`.

    mkdir again && tar -xpzf lzrbrwsr-macos-arm64.tar.gz -C again
    (cd again && COPYFILE_DISABLE=1 TZ=UTC tar --no-xattrs --no-mac-metadata --format ustar --uid 0 --gid 0 --uname '' --gname '' --options 'gzip:!timestamp' -n -czf ../again.tar.gz $(tar -tzf ../lzrbrwsr-macos-arm64.tar.gz))
    shasum -a 256 lzrbrwsr-macos-arm64.tar.gz again.tar.gz

The two values are the same with the `tar` of the macOS it was packed on. A `tar` of another
version may compress otherwise; then compare what `gzip -dc` gives for each. This says nothing
about what the program does. It says that the download is those six files.

Gatekeeper's question at a first start (is this signed by a developer Apple knows, did Apple
notarize it) is asked about files that carry the quarantine mark. Fetched with `curl`, this
program carries none, so the question is not asked. Nothing here turns Gatekeeper off or
answers for it. The program carries an ad-hoc signature, made when it was built: a signature
with no identity in it, which Apple silicon requires before it runs native code such as this
program's. It is not signed
with an Apple developer identity and it is not notarized.

What stands where Apple's notarization would stand, and what does not:

| notarization gives | here |
| --- | --- |
| Apple's scan found no known malware in the program. | Nothing is assumed about the program. It runs with no network, no file of yours, nowhere to write and no other program, in a container whose every line is in this repository, and that container is probed on your Mac before a file is put in place (`selftest`) and proves itself again at every start `[C2]`. |
| The bytes are the ones the maker handed in. | The SHA-256 of the installer, of the download and of each file in it is on public record here (`release.txt`). The installer and the download stand in two places that must agree, and the installer stops on any other byte (`get` in `install.sh`). |
| A named maker, and a ticket Apple can take back. | Not here. No identity Apple knows stands behind a release, and a release cannot be taken back from a Mac it is on: a newer one can only be offered. From release 76 on the manifest is signed with the release key and approved with an approval key held in the owner's phone `[C25]`. Up to release 75 nothing is signed with a key. |

A signature says who made a program, not what it does, and whoever gives it can take it back.
