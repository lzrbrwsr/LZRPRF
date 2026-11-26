# A newer release

This text was the README section "A newer release" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- The signed-manifest checks of [C25] were added.
- The installer must also match the manifest's SHA-256 ([C25]).
- The copy of the release file was replaced by a pointer to README.md, which release.sh checks.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/updates.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| lzrprf looks for a newer release only if ... | `newer` | - | - |
| - The look is one request for one ... | - | C7 C5 | - |
| - The address is on GitHub, not on ... | - | - | - |
| - The first start of a release shows ... | `welcome` | - | - |
| - When the number is larger than yours, ... | `installed` | - | - |
| - Before it offers the release, lzrprf fetches ... | `release_signed`, `signature_holds`, `manifest_read` | C25 | - |
| - lzrprf fetches the installer itself, like any ... | `fetch`, `installed` | C5 C6 C3 C7 | - |
| - It writes the installer into ~/.lzrprf/install.NUMBER/install.sh, a ... | - | - | - |
| - It runs it there, outside every container, ... | `install_line`, `installed`, `install_drained`, `restarted` | - | - |
| - The installer, in auto with no terminal ... | - | - | - |
| - The installer, in auto, shows no question ... | - | - | - |
| Where the addresses come from: a plain file, ... | `beside`, `paired`, `program_same`, `address` | - | `report`, `support` |
<!-- index end -->

lzrprf looks for a newer release only if you said yes, once, in the window (`sub newer`). The
yes is kept together with the address it was given for (`~/.lzrprf/look`), so a release that
names another address has no yes and asks again. A no is kept for every address. The answer is
a line of the log before it is kept, like a change of what is kept: `you allowed lzrprf to look
for a newer release at each start: ADDRESS`, or that none is looked for. When that line cannot
be written, or the answer cannot be kept, it counts for nothing: no look is made, and you are
asked again at the next start. To take a yes back, delete `~/.lzrprf/look`: you are asked again.

- The look is one request for one fixed address: the file `latest` in this repository, which
  holds one number. It is sent like any address you type, the same request from every computer
  `[C7]`, so the request does not say who you are or which release you run (your internet
  address, and how this Mac speaks TLS, are outside the request); GitHub still sees
  what any site sees (below). It is in the log like every
  other request `[C5]`.
- The address is on GitHub, not on a server of the application's maker. The maker's server
  sees no request at all. GitHub sees your internet address and the time, at each start.
- The first start of a release shows a welcome once (`sub welcome`): what is new in it, from
  the release file's lines `new`, and two short groups, what the application keeps you from
  and what it cannot keep you from, which stays yours to watch: what you type into a site, what
  a site does with it on its own servers, fake sites, what you take into another program, and
  your internet address. Got it writes the release number to `welcomed`; nothing is fetched.
- When a signed newer release is available, a centered modal shows both release numbers.
  Later or Escape dismisses it. Install it runs the installer in the window and shows its
  progress. No further confirmation is needed (`sub installed`).
- Before it offers the release, lzrprf fetches `release.manifest`, `release.manifest.sig` and
  `release.manifest.approval` beside each installer place and checks them `[C25]` (`sub release_signed`):
  the two places must hold the same bytes; the approval must hold for an approval key lzrprf carries
  and the signature for its release key, each checked by `/usr/bin/ssh-keygen` in the verifier container
  (`sub signature_holds`); the manifest must be in its one form (`sub manifest_read`), of the published
  number, newer than yours, signed no later than one day from now, not expired, valid at most 400 days,
  and must name `install.sh`. A refusal has no way around it: nothing is installed, and the window says
  why. VERIFY.md does the same checks by hand.
- lzrprf fetches the installer itself, like any request: its line in the log first `[C5]`,
  through `sub fetch` `[C6]`, by a contained `curl` that follows no redirect `[C3]` `[C7]`. When
  the release names a second place (the line `same`; the release on record here does), it
  fetches that copy too and goes on only when the two are the same byte for byte, and when its SHA-256
  is the one the signed manifest names for `install.sh` (`sub installed`). While a
  release is being published one place can keep its old copy for a few minutes, so when the two
  differ both are fetched again every 30 seconds, twelve times in all, each try a line in the
  window; a copy that differs is never run, and after the twelfth the install fails. A `same` line
  that is there and is no address counts as one that does not agree, and nothing is fetched.
  An address is handed to `curl` as one argument and to no shell, so a quote in it is a
  character like any other.
- It writes the installer into `~/.lzrprf/install.NUMBER/install.sh`, a file only you can read,
  shows that file and its SHA-256 in the window, and writes both in the log, before it runs it.
  The window and installer output give the signed manifest URL and the install.sh entry to compare.
- It runs it there, outside every container, as `/bin/sh install.sh auto`, through `env -i`
  with only the system's `PATH`, your home folder and `TERM=dumb`: no variable of your shell.
  Nothing is piped into a shell. Every line the installer prints is shown in a modal of
  lzrprf's own over the window, where no page draws, and appended to `~/.lzrprf/install.txt`.
  A colour it asks for becomes one letter the window draws in, and every escape and control
  character is taken out first (`sub install_line`), so nothing it prints acts on the window.
  A line that shows nothing, such as the empty line the installer begins with, is shown as
  what it is; releases 36 to 68 ended there without a word, so no install from the window
  reached its end. An error of lzrprf's own while it installs never ends it silently: it is
  said in the modal, in `install.txt` and in the log, as a stop signal is, and an installer
  that runs goes on, its lines read on into `install.txt` (`sub installed`), each line it had
  read and not yet shown as a line of its own (`sub install_drained`).
  After 30 minutes it is ended. At the end the modal says done or failed; after done, lzrprf
  takes nothing more in that window, which offers Close, and Close and restart. Restart starts
  the application again once this run has ended: a process of its own waits until lzrprf and
  the launcher are gone, then asks macOS to open the application at the place it ran from,
  which the installer has replaced (`sub restarted`). This is the one moment on this road when the maker's site is asked for anything:
  it sees your internet address then, as GitHub does.
- The installer, in auto with no terminal (as lzrprf runs it), prints every line that would show nothing
  as one space, and a line longer than 2000 bytes as lines of at most 2000, so that an lzrprf of
  releases 36 to 68 lives through its own update to a newer one. Where it can make no FIFO for that,
  it starts itself once more through the same reader and ends as that run ended.
- The installer, in auto, shows no question and leaves the Dock alone on an update, refuses to put an older
  release over a newer one, and says so when the release would replace `lzrprf` itself. Run by
  hand (`sh install.sh`), each question takes y (yes, and the next is asked), n (no), or a
  (auto: yes to it and to every one after it). It takes no test setting
  from a variable of your shell unless every file comes from this computer (see "The
  installer"), so a variable cannot point this road elsewhere.

Where the addresses come from: a plain file, `release`, beside the application
(`LZRBRWSR.app/Contents/Resources/release`), read by `sub beside` and `sub paired`. It may hold
nine kinds of line and nothing else counts: `release` (a number), `new` (what is new in the
release, shown in its welcome), `newest` (where the number is published), `installer` and
`same` (the two places of the installer), `report` (see the next section), `support` (the one
address of support requests, from release 61 on), `lzrprf` (the SHA-256 of the lzrprf the
release installs; an lzrprf of release 12 or later compares it with itself at every start, and
from release 15 an app whose `release` file has no such line does not start either) and `file`
(a name and the SHA-256 of a file in the folder of the program; the installer writes two, for
the launcher and for the program; an lzrprf of release 16 or later compares each with the file
that is there at every start, from release 17 on stops at a file beside the program that no
line names and checks before every page that the program is still the file it read at the start (its sum is
read whole again whenever the file was written, replaced or moved: `sub program_same`), and the installer compares each line
with what it unpacked before it puts anything in place).
Each address must pass `sub address`, the same check as an address you type. lzrprf hands each
installer address to `curl` as one argument and to no shell, so a character that would end a
quote is a character like any other; `selftest` tries exactly that. A `same` line that is there
but is no address does not turn the comparison off: nothing is fetched. The installer compares the `release` file byte for byte with the text written out in
the installer, and `release.txt` holds its SHA-256, so what your copy names is what is on record
here. The release file of the release on record is shown in README.md, "The release file".
