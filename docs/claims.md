# The claims, one by one

This text was the README section "The claims, one by one" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- `sub fixed` also fetches the signed manifest of a newer release ([C25]).
- Pictures are fetched and shown; "every picture is a grey box" was dropped.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/claims.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| Each claim below is stated as a chain: ... | - | - | - |
| For the application to run outside, lzrprf would ... | - | - | - |
| - There is one line that starts it, ... | `laid_out`, `contain` | C1 | - |
| - The container text is tried at every ... | - | C2 | - |
| - For each process, macOS is asked by ... | `inside` | C3 C2 | - |
| - What the icon runs is a short ... | - | - | - |
| - Which process sees which variables. lzrprf's own ... | - | - | - |
| Condition: this holds for a program started through ... | - | - | - |
| A request of lzrprf's to a site goes ... | `fetch`, `holds`, `lookup`, `route`, `proven` | - | - |
| - sub visit, called from sub go alone, ... | `visit`, `go` | C4 | - |
| - sub pictured, called from sub visit after ... | `pictured`, `visit`, `relaid`, `under`, `address` | C8 C17 C7 | - |
| After the lines =pictures and =sheets, or where ... | `stated` | - | - |
| - sub sheeted, called from sub visit alone, ... | `sheeted`, `visit` | C13 C14 C19 | - |
| - sub fonted, called from sub visit alone, ... | `fonted`, `visit`, `sheeted`, `checked`, `listed` | C30 | - |
| - sub fixed, which runs for three fixed ... | `fixed`, `newer`, `fault`, `installed`, `release_signed`, `support_sent`, `support_read` | C25 | - |
| - sub live_fetched, from release 54 on, for ... | `live_fetched` | C19 | - |
| Before any of them, the line is in ... | `redirected`, `pictured`, `checked` | C5 C6 C19 | - |
| The name lookup is a request too, to ... | - | - | - |
| The installer of a newer release is fetched ... | `fixed`, `fetch`, `installed` | - | - |
| Conditions: macOS enforces the containers (tested on your ... | - | C2 C3 C11 | - |
| A fingerprint needs two things: reading what tells ... | - | - | - |
| - Code. From release 17 on the page ... | - | - | `lostcode` |
| - Reading. The page container lets it read ... | - | - | - |
| - Delivering. It has no way out by ... | `checked`, `pictured` | C9 C10 | - |
| - What it read it can still use ... | - | - | - |
| - lzrprf does not make one either. What ... | `request` | C7 | - |
| - One thing is the application's choice and ... | `fault` | - | `page` |
| The page container keeps the closed program from ... | `fetch` | - | - |
| Condition, and the one way around it: you. ... | - | - | - |
| What it is given no way to do ... | - | - | - |
| Who could keep a record of where you ... | - | - | - |
| - The application: it is started fresh for ... | - | - | - |
| - lzrprf: unless you chose otherwise, it keeps ... | `reach` | C12 C6 | - |
| - The maker of the application: receives nothing ... | - | C4 C7 | - |
| - GitHub: once you said yes to looking ... | - | - | - |
| - Other sites, by two ways. First, pictures: ... | - | C19 | - |
| What remains: each site sees your internet address ... | - | - | - |
| Interfering needs a way to reach them, or ... | - | - | - |
| - Reach. The page and fetch containers refuse: ... | `seal` | - | `alias` |
| - Shared objects. macOS does not refuse the ... | - | - | - |
| - Starving. A page container gets at most ... | `limited`, `laid_out`, `holds` | - | `lostsoft`, `lostfiles` |
| - The end of lzrprf. From release 17 ... | `keeper`, `laid_out` | - | `killed`, `leftkilled` |
| - Memory. The same sub limited sets, before ... | `limited`, `shell_measured` | - | - |
| Limit, said plainly: within those limits a hostile ... | - | - | - |
| The page and fetch containers may read the ... | - | - | - |
| No. See "What "proof" means here". It rests ... | - | - | - |
<!-- index end -->

Each claim below is stated as a chain: what would have to happen for it to be false, and the
condition that stops each step. Where a claim holds only under a condition, the condition is named.

## The closed application runs inside the container, or not at all

For the application to run outside, lzrprf would have to start it another way, or the container
would have to be weaker than it reads.

- There is one line that starts it, in `sub laid_out`, and it goes through `sub contain` `[C1]`.
  `selftest` reads `lzrprf` and counts.
- The container text is tried at every start, with real targets: a listener lzrprf opened, a
  file it wrote, its own process `[C2]`. So a macOS that stopped enforcing it is noticed before
  anything runs.
- For each process, macOS is asked by the number of the process about eight things
  (`$WITNESS`, `sub inside`). For a page or a fetch process four of them must be refused: using
  the network, creating a file, starting a second process, reaching a system service. The answer
  or the connection is handed over only after those four refusals `[C3]`. These are questions
  about a fixed list of operations, not about the whole container text: the rest of the text is
  what `[C2]` tries. And the process is already running when it is asked, with the address it
  was given; what waits for the answer is the site's answer, or for `curl` the connection.
  From release 19 on an application the system does not call contained is held still
  (`SIGSTOP`) before its keeper is ended, and then killed: the keeper's end closes the
  application's input, and until release 18 it could go on at that for an instant, outside
  the container it was never in, with the address and without the answer. `selftest` saw
  that once in its own run of a copy that starts the application uncontained.
  For the window's process eight must be refused: those four, and opening something
  through the system, commanding another program, writing your settings, sending a signal. For
  the window the fourth question names no service (from release 19 on): the no says that its
  container refuses a system service by default, and nothing about which names its list lets
  through. What the window may
  read is not among the questions: `selftest` tries that from the real window. Nothing is
  asked of the process itself.
- What the icon runs is a short plain-text launcher. It starts `lzrprf run` through
  `/usr/bin/env -i`, or without lzrprf only an alert, so no variable of whoever started it
  reaches lzrprf. From release 14 the launcher reads no variable itself either: its one
  command starts perl through `env -i`, and that perl finds your home folder in this Mac's
  list of accounts, as lzrprf does. What is left of the starter's is how `/bin/sh` itself
  starts, before that one command. The installer compares the launcher byte for byte before
  it installs anything.
- Which process sees which variables. lzrprf's own process, outside every container, sets its
  own at its start: `PATH` to the system's folders, and `LANG`, `TMPDIR` and
  `__CF_USER_TEXT_ENCODING` kept only when they were set; every process it starts outside the
  page and fetch containers starts with those: the window's (in its own container), the
  keeper, the name lookup, `route`, `xattr`, `sysctl`, the `osascript` that asks macOS
  whether a process is contained, `open`, and `selftest` when you say yes to a run. The page program sees
  one variable, `LZRPRF_CONTAINED`, which holds the address. `curl` and the bookmark reader see none.

Condition: this holds for a program started through `lzrprf run`. The program file itself is an
ordinary file; started by hand, from a terminal, it runs like any program you start by hand.
Nothing that is installed starts it that way.

## No request you did not ask for

A request of lzrprf's to a site goes only through `sub fetch`: it is the one way for an address
you typed, a bookmark or the home page you opened, a redirect you said yes to, the look for a
newer release, a report and the installer after "Install it", a support request you sent and
the reading of its answer, and what a page kept running asks for. Other things touch a socket,
and none of them connects to a site: the try at each start against a listener lzrprf opened
on this computer (`sub holds`), the system's name lookup (`sub lookup`, below), `curl`'s
connection to lzrprf's own socket file, the question to the system's routing table
(`/sbin/route` in `sub route`), and `selftest`, which `sub proven` starts after your yes:
it opens listeners on this computer and tries 192.0.2.1, an address no host answers. Outside
lzrprf, the `curl` of the installer you start by hand fetches too ("The installer"). `fetch` is
called from five places, and `selftest` reads `lzrprf` and counts them:

- `sub visit`, called from `sub go` alone, for an address that came from the window `[C4]`: a
  line `go TEXT`, which the window writes when Return is pressed in the bar and at no other
  time; a line `mark open N`, a bookmark you made; the home page you set, at the window's start
  and in a new tab; a closed tab you reopened, at the address it went to before; the address
  of a tab you pulled out of another window, which lzrprf itself hands the new window's lzrprf
  on its standard input; or the address a redirect named, after your yes in lzrprf's own modal
  (see "Tabs, the home page, bookmarks, redirects"). The application cannot write any of these: it
  has no pipe to that side, and nothing it writes is passed on as words to lzrprf.
- `sub pictured`, called from `sub visit` after the page was laid out, and from `sub relaid`
  (the page laid out again at a new width, also in a tab chosen again) with the pictures it
  decoded then, which fetches nothing. A laid
  page may name up to twenty-four pictures, in its order, in a second line
  `=pictures ENTRY ENTRY ...`, and place them with `I` lines. Each entry is a path beginning
  with `/` on the page's own host, or a full address `https://HOST/PATH` on a name under that
  host (`sub under`: the page's host with `www.` taken off, and one name or more in front of it),
  or on any other host by its name, another site, as a news site's image server is (hs.fi keeps
  its pictures on `images.sanoma-sndp.fi`). At most eight other sites are asked for one page's
  pictures, the first the page names (`$PICTURE_SITES`, the same number as the application's
  `MOST_PICTURE_SITES`); a name under the page's host is not counted among them. A picture on
  one more other site is not fetched: the log says `<address> not fetched: ...`, and nothing
  is looked up. What another site learns from a picture is your internet address and the
  picture's address, which names the page's picture and so tells it which page you read, and
  when; it is sent no cookie (lzrprf keeps none), no `Referer`, no `Origin`, nothing but the
  fixed request of that address. Each
  picture placed is fetched once, in the page's order, at most eight side by side
  (`$PICTURES_AT_ONCE`: twenty-four one after the other took over four seconds). A path goes the way the page went: its
  line `<address> -> lzrprf connects to ...` is in the log first, then `fetch` connects to the
  same addresses the page came from. An address on any other host is checked exactly as a typed
  address is (`sub address`: https, a host by name, port 443, plain characters); its line
  `the page HOST names a picture on OTHER: <address>` is in the log before the name is looked
  up, and a host that leads inside your own network is not fetched and nothing is asked: the
  log says `<address> not fetched: ...` `[C8]`. Otherwise its `connects to` line is written and
  it is fetched the same way; with Tor on, through Tor, one circuit for that host `[C17]`. The site is sent `request` of the picture's address, the same
  five lines as for any address, without the line `Accept` a page you visit carries `[C7]`,
  and its result is written as a second line. The application then decodes the picture
  in a page container of its own, started exactly as a page's is, with one variable more
  (`LZRPRF_PICTURE=1`), and writes only pixels: `P<w>,<h>` and one line of hex per row.
  lzrprf checks every byte of that; anything else is no picture. The window is never given a
  byte the site sent: lzrprf writes the pixels into the form of picture a laid page already
  has, rows of red, green, blue and how opaque, and a picture that is missing, late (all of
  them share one clock of 20 seconds) or wrong is the grey box it was before. The line under
  the bar says how many of the pictures were fetched and shown, and which other hosts were
  asked for them; of the other hosts the page names, it says that none was asked for anything
  but a picture.

  After the lines `=pictures` and `=sheets`, or where they would stand, the application may write one line
  `=statement TEXT`: in its own words, why it shows the page in compatibility-statement mode,
  1 to 200 plain printable characters (bytes 0x20 to 0x7e). lzrprf shows those words as plain
  text at the end of the line under the bar, and reads them for nothing else; they name no
  address and cause no fetch. A second such line, or one too long or with any other byte,
  makes the page no page (`sub stated`).
- `sub sheeted`, called from `sub visit` alone, from release 32 on, before the pictures. A page
  may name up to eight style sheets on its own host, by path, in a line `=sheets /path /path ...`
  right after the line `=pictures` (or where it would stand), in the same grammar and with the
  same checks as the paths of pictures; a second such line, or one in another place, makes the
  page no page and nothing is fetched. Every page run is given, after the fonts `[C13]`, a frame
  of style sheets: on the first run the empty line `=sheets`. When the first run names sheets,
  each is fetched the way a picture is, its line in the log first, from `https://` the page's own
  host and that path, never another host; one clock of 10 seconds for starting them, and a sheet
  not begun by then, a fetch that failed and an answer over 1 MiB each go with length 0. The page
  is then run a second time with `=sheets` and the length of each on one line, and the answers
  as the site sent them, in front of the page's `[C14]`. The second run's page is shown when it
  is a page and names no style sheet. When it names style sheets again the first run's is, and
  the line under the bar says that the style sheets were not used. When its program or its
  container failed, that fault is said, as for a first run, and no page is shown. When it is no
  page (unfit, ended or late) and asked for no address while it was read, the page is run a
  third time, given `=sheets` with each named sheet at length 0: the application reads a first
  run that names sheets without the network, so that run fetched and ran no external or module
  script, and the third run, which is not a first run, has the network and fetches them. Its
  page is shown when it is a page and names no style sheet; otherwise the first run's is, and the
  line under the bar says that neither the run with the sheets nor a run without them is a page.
  A second run that asked for an address, fetched or refused, has no third, since a third would
  ask the site again: the first run's page is shown, and the line under the bar and the log say
  how many addresses it asked for. A second run that wrote too much has no third either: the
  first run's page is shown, the line under the bar gives that fault, and the log adds that it
  asked for no address. Whenever the first run's page is shown after a second run that is no
  page, the line under the bar says that none of the page's external or module scripts ran in
  the page shown. No run of a visit asks again for what an earlier run of it asked. A run laid
  again, for a new width or a tab chosen again, asks again. A page kept running asks as `[C19]`
  allows. A visit can take three runs of up to 30 seconds each, 90 seconds besides its fetches,
  when a late second run that asked for nothing gets a third. There is never a
  fourth run, and a picture run is given neither frame. The pictures are fetched after the page
  that is shown was chosen.
- `sub fonted`, called from `sub visit` alone, from release 84 on, after `sub sheeted`. A run
  handed style sheets may name up to 8 web fonts the sheets' `@font-face` rules name on the
  page's own host, each by up to 4 paths joined by `|`, in a line `=webfonts /path|/path /path ...`
  right after the line `=sheets` (or where it would stand), each path in the same grammar and with
  the same checks as the paths of sheets; `sub checked` reads it. When the second run is shown and
  names fonts, each font's paths are tried in order until one answers 200, as a src entry that
  fails to load falls through to the next, and each path is fetched the way a
  sheet is, after `sub listed` and the filter lists as a font, its line in the log first, from
  `https://` the page's own host and that path; one clock of 10 seconds for starting them, each
  cut at 2 MiB and 64 KiB, all at most 8 MiB, and a font not begun in time, refused, failed or
  over either cap, or not answered 200, is not handed over, its second line in the log saying why,
  and a font none of whose paths is goes with length 0 `[C30]`. The page is
  then run a third time with the same `=sheets` frame and, after it, `=webfonts` and the length of
  each on one line, and the answers as the site sent them. The third run's page is shown when it
  is a page and names neither sheets nor fonts; otherwise the second run's is, and the line under
  the bar says that the run with the web fonts is not shown. Nothing of a font is written to the
  disk: the frame is kept in memory with the page shown, and a new width lays the page out with
  it again. This third run and the third run of `sub sheeted` never both happen, as one follows a
  second run that is shown and the other one that is not: there is never a fourth run. A first run
  of a page that names no sheet may name fonts its own `<style>` names: that
  run is read without the network, as one that names sheets is, the fonts are fetched the same
  way, and a second run is handed `=sheets` with no sheet and the fonts; it is shown when it is a
  page that names neither again. When it is no page and asked for no address, a third run is
  handed each font with length 0 and read with the network, shown when it is such a page; else the
  first run's page is shown, and the bar says none of its external or module scripts ran.
- `sub fixed`, which runs for three fixed addresses of the release file, each only after your
  yes in the window: the newest release number (`sub newer`), a report you chose to send
  (`sub fault`), and the installer after "Install it" (`sub installed`); and, from release 76 on,
  for the signed manifest, its signature and its approval beside each installer place of a newer
  release that look found (`sub release_signed`, `[C25]`), from both places when
  the release names two. For the
  newest release number the yes is given once and kept with its address in `~/.lzrprf/look`:
  the look is then made at each start, without a new yes, until you delete that file. From
  release 61 on it runs twice more, for the one support address the release file names, each
  only after a press in the cogwheel's menu: a support request you sent (`sub support_sent`)
  and the reading of its answer after "Read the answer" (`sub support_read`). See "Tabs, the
  home page, bookmarks, search, the lock, redirects".
- `sub live_fetched`, from release 54 on, for an address a page kept running with its tab
  asked for, within `[C19]`.

Before any of them, the line is in the log `[C5]`. The connection is made by lzrprf, to a numeric
address it wrote down `[C6]`. `curl` has no network of its own: it gets one socket file, so it
can reach that one connection and nothing else. `curl` follows no redirect: an answer that
sends on is never laid out, and lzrprf asks you in its own modal (`sub redirected`). Of the other
hosts a page names, two kinds are asked, and no others. A picture's host, one of at most eight
other sites a page (`sub pictured`), is sent the picture's fixed request with no `Origin`; lzrprf
fetches it only when its address stands in the page's own text. And a page kept running asks any
public host its scripts ask for `[C19]`, up to 600 requests in its life, POST among them, with
the page's own `Origin`; the setting that blocks pictures from other sites does not stop those.
The list of other hosts under the bar is the application's reading of the page: lzrprf takes at
most 200 names from it and shows you how many and the first four. A hostile application can name
fewer or other hosts than the page does. That changes a sentence in the window and no request. Those up to four
names, and how many it named, are the only text the application chooses that is shown outside
the page: in lzrprf's words under the bar, each name in the shape of a host name (letters,
digits, hyphens, at least one dot, each part at most 63 characters, the last part beginning
with a letter; `$NAME`, used in `sub checked`). They are not written in the log.
Which of five of the eight fixed phrases says why a page was not shown is its choice too; the
other three are lzrprf's and the system's (see "When a page cannot be shown").
The page cannot make a request by being clicked either: a link is drawn as a colour and does
nothing.

The name lookup is a request too, to your resolver, for the host you typed, after the log line.

The installer of a newer release is fetched by lzrprf itself, after you pressed "Install it",
through `sub fixed` and `sub fetch` like every request, from the places the release names, and
it runs in lzrprf's own window (`sub installed`). Nothing on that road is fetched outside lzrprf.
See "A newer release".

Conditions: macOS enforces the containers (tested on your Mac, `[C2]`, `[C3]`, `[C11]`); the
`lzrprf` you run is the one in this repository (compare its SHA-256); and the keys pressed in the
bar are yours. A program on your Mac that you allowed to control your computer can type there
like you can.

## It can read a few facts about your computer, and has no way to deliver them

A fingerprint needs two things: reading what tells your computer apart, and delivering it. The
application can do the first in part. The second is what the container refuses.

- Code. From release 17 on the page program may load as code only itself and the system's
  own libraries (`/System`, `/usr/lib`): no other file, also not one in its own folder
  (`(deny file-map-executable)` and the line after it in `$CONTAINER`). `curl` in the fetch
  container is held to the same. `selftest` puts a file of code into the hostile
  application's own folder: outside every container it loads, in the page container it is
  refused, and with the refusal taken out it loads again (`lostcode`). Before release 17
  the profile held only the line that allows, and macOS refuses nothing there without a
  line that says no: the program could load as code any file it could read, which was the
  system's folders and its own app folder. It could write to none of them then, and cannot
  now. So the files of an app folder that no line `file` names (the icon, `Info.plist`, the
  `release` file itself, anything put into another folder of the app) are not compared with
  anything, and from release 17 on none of them can be run or loaded by the program.
- Reading. The page container lets it read every system value (`sysctl`) this macOS has under
  three prefixes, `hw.`, `machdep.cpu.` and `kern.osvariant` (prefixes, not a fixed list: the
  model of the computer, its processor, its memory, which variant of macOS this is and
  whatever else this macOS puts there),
  and single names under `kern.` (the version of macOS and of its kernel, a few fixed limits,
  where its own stack begins, whether the kernel is the secured one,
  whether it runs in a virtual machine, whether the system is shutting down), three about its
  own process (`sysctl.proc_`) and one under `vm.`, exactly as `$CONTAINER` names them; and the
  time, and the folder it is installed in. So it can tell the processor, the size of the
  memory, the version of macOS and whether it runs in a virtual machine. Not the computer's
  name, your account's variables, your files, the fonts you installed, your time zone, your
  screen, or other processes.
- Delivering. It has no way out by the ways its page container gives it. No network, no file
  to write, no shared memory by the ways the test tries, no second process, no window. The one thing that leaves it is the list of lines, and `sub checked` lets through
  only lines that cannot carry an address or a command `[C9]`. Until release 22 they could
  carry no picture either; from then on a laid page may hold pictures, as pixels that the
  window draws as they are, never as a file that is decoded. Pictures are fetched for the page
  (`sub pictured`) and handed back as pixels. From release 20 on
  the list may begin with up to 120 lines that say what the page is made of. They are plain
  characters, shown as text in the pane under the page, and they are the application's own
  words as much as the text of the page is: what stands there is whatever it wrote. The true
  or false beside each of them is the application's word about itself, which lzrprf cannot
  check either. The window that draws
  them has no network `[C10]`. One exception: the window's process. An application
  whose text took that process over, by a flaw in how macOS draws text, would have the ways
  that process has, a fetch through lzrprf among them, logged first (see "The window's process"
  under "What it does not prove").
- What it read it can still use inside its own page: lay the page out differently, take
  longer, fail on purpose, or put the facts into the text it shows, which you could copy.
- lzrprf does not make one either. What a site is sent is `sub request`: the address, its host,
  one fixed browser name, `User-Agent: LZRBRWSR`, and two fixed lines `[C7]`; the request of a
  page you visit carries one more fixed line, `Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`, the same
  on every computer (some sites refuse a request that does not say it takes a page). The name is that
  one word, with no version: the same from every computer and in every release (some sites
  answer a request that names no browser with nothing but a redirect, which is why it names
  one). No cookie, no language, no page you came from, no number of this computer or of this
  copy. Each request is a new `curl` that can write
  nothing, so nothing is kept for the next one.

- One thing is the application's choice and reaches its maker, and only after your click:
  whether it fails on a page at all. When it does, you are asked whether to send a report. A
  report says `page` for every failure of the application's own doing, and an application that
  ended by itself before macOS was asked about it counts as `page` too, so the application
  cannot choose among words (`sub fault`). It chooses no field of a report; by failing it
  chooses whether you are asked, and the word it brings about is `page`. Sending still needs
  your "Send" in the window. A report you send tells the maker that some page
  failed, on a Mac with your build of macOS, at that moment. So, though a report holds no
  address, the question and a report you then send carry a little from the program: that a
  page failed, at a moment it chose. It cannot choose the word. Never pressing "Send" closes
  this way. See "When a page
  cannot be shown".

The page container keeps the closed program from sending what it can read about this
computer. It does not make your Mac look like any other Mac. What a site does see: your
internet address, the time, the address you typed with its path and query, and how this
macOS and the system's `curl` open TLS and TCP. `selftest` compares the TLS opening bytes
between the requests of one run on your Mac. When they are the same the line says `held`; when they differ,
or the test site could not read them, it says `UNTESTED`, not `FAILED`, the mark of that run
names the check, and LZRBRWSR asks before it starts without it. Nothing here shows that
two Macs, or two builds of the system's `curl`, send the same opening bytes. What the code says
of them is only that the system's own `curl` makes them, with fixed switches (`sub fetch`).

Condition, and the one way around it: **you**. A page can show a text that asks you to type or
paste an address, and that address can carry whatever the application knows. lzrprf sends what
you type and writes it in the log first. It cannot judge an address for you.

## The application is given no way to keep anything between pages or to send anything

What it is given no way to do is keep a record of where you go, or send one; the bullets
below say how far that goes. What any request shows is
still seen: each site, your resolver and your network see your internet address and the time,
and a site can tie your requests together by that address, or by links it made unique to you.

Who could keep a record of where you go?

- The application: it is started fresh for each answer and sees that one page and its address.
  It is given no way to keep anything between pages (no file to write, no shared memory by the ways the test tries) and
  no way to send anything (the exception: "The window's process" under
  "What it does not prove"). That is said of the ways its container gives it and the test
  tries, not of every way a program could find: what it draws, how long it takes and whether
  it fails are its own to choose, and an application left behind after lzrprf and its keeper
  were both killed ("A page process left behind", below) lives on past its page.
- lzrprf: unless you chose otherwise, it keeps nothing of its own after the window closes:
  the lines are in the memory of the process behind the window, and gone with it; a log kept
  earlier stays until you clear it, and what macOS keeps is its own (see "What is kept"). A
  log you chose to keep is on your disk, readable by your account alone, hosts only unless you
  chose full addresses. Nothing in `lzrprf` sends the log or any part of it `[C12]`: the only
  place that connects to a site is `sub reach` `[C6]`.
- The maker of the application: receives nothing about where you go. The two fixed addresses
  are fetched only after your yes `[C4]`. The release check goes to a file in this public
  repository on GitHub, not to a server of the maker, with the same request from everyone `[C7]`. The
  maker's server is asked for something by an installed copy in two cases only, both after
  your own click: a report you chose to send (three values, none of them an address you
  visited), and the installer of a newer release you chose to install. Installing asks it too:
  the three lines under "The installer" fetch the installer from it, and the installer fetches
  the download. The site is the maker's own server. While that server is down the maker can
  point the name at a copy held by a hosting company (Vercel), which then sees those requests
  in its place; the header `X-Served-By` of every answer says which one answered, `box` or
  `copy`. A report goes to `origin.lzrbrwsr.com`, which names the maker's own server only.
- GitHub: once you said yes to looking for newer releases, it is asked for the file `latest`
  at each start. It sees your internet address and the time you started the application, and
  nothing else from lzrprf.
- Other sites, by two ways. First, pictures: a page's pictures may come from up to eight other
  sites, as a news site's image server, and so may a tracking pixel larger than two dots (that
  a picture of two dots or less is never fetched, and that the page's img-src policy is kept,
  are the application's checks, and a hostile application could skip them; lzrprf itself keeps
  the eight sites and fetches only an address that stands in the page's own text). Such a site
  sees your internet address, the time and the picture's address, which tells it which page you
  read; it gets no cookie, no `Referer`, no `Origin` and nothing else. "Block pictures from other
  sites" in the cogwheel's menu stops these. Second, a page kept running `[C19]`: its scripts may
  ask any public host, up to 600 requests in its life, POST among them, each carrying the page's
  own `Origin`, so such a host learns which site you are on; the pictures setting does not stop
  these. A page's style sheets and frames on other hosts are never fetched. The sites you do type
  get no cookie back and no page you came from, so they cannot link one visit to the next by
  anything lzrprf adds.

What remains: each site sees your internet address and the time, and can link your visits by
that address or by an address unique to you that you type in; your resolver sees the names you look
up. Hiding those is the job of a network you choose, not of a container.

## It cannot reach other applications, and can load the computer only within its limits

Interfering needs a way to reach them, or a way to starve them.

- Reach. The page and fetch containers refuse: signalling another process, every system service
  (so no window of another program, no key, no clipboard, no event to another program),
  starting a program or a second process, and writing any file. `selftest` tries each.
  Whatever lzrprf starts is handed three open files it chose and no other (`sub seal`):
  `selftest` keeps a file open under the number 19 and, from release 17 on, also under 700
  when the system lets it, and the hostile application looks at every number from 3 to 1023
  (before release 17, 3 to 255).
  They open no device but `/dev/null` and the two that give random numbers: the test opens
  a device of the terminals (`/dev/ptmx`), outside every container and inside. A file in your
  home folder is tried by three names: its path, its path through the data volume, and its
  number on the disk (`/.vol/…`), a name that holds no folder. They read no
  file in your temporary folder, which is outside the home folder: the test puts one there
  and reads it outside every container and inside. And a name in
  the program's own folder that points at a file in your home folder opens nothing in the
  page container: the rule goes by where the file is, not by the name it is opened by (the
  run `alias` of `selftest`, with the same link opened outside every container first).
- Shared objects. macOS does not refuse the creation of old "System V" memory, flags and queues
  inside a container, and the computer has only a few of them. `selftest` found that on
  2026-11-18; `$CONTAINER` now refuses the three calls `shmget`, `semget` and `msgget` by name,
  and the test makes each. Memory and flags with a name (`shm_open`, `sem_open`) are refused by
  the container's `deny default`, which no rule opens for them, and the test makes those too.
  From release 19 on the test also makes memory with a name itself, outside every container,
  and the hostile application asks to open it: opened outside, refused in the page and fetch
  containers, as the making is. The window container refuses neither.
  That is a test of these six ways, not a proof that no other way to share exists.
- Starving. A page container gets at most 30 seconds of processor time, counted over all
  processor cores together (`sub limited`, for `$PAGE_LIMITS`); nothing limits how many threads
  it starts, and they share the 30 seconds. It is ended after 30 seconds of the clock
  whatever it does (`$PAGE_SECONDS`, looked at once a second, so up to about a second later),
  counted from when it is handed the answer, after macOS was asked about it for about two
  seconds at most. Before release 16, when the process that hands the answer over could not be
  started, the page process was left to end by itself; from release 16 on it is ended there
  (`sub laid_out`). It may write no byte into a file (`$PAGE_LIMITS`; making a file is refused
  by the container) and leave no memory dump. It may write at most 12 MB,
  50000 lines and 2000 boxes, and no block of more than 20000 characters; more is not drawn
  (until release 20: 6 MB and 200000 lines, and a block of any length). From release 17 on the page program and
  `curl` may hold at most 256 open files (`$PAGE_LIMITS` and
  `$FETCH_LIMITS`), set like the other limits. From release 17 on each limit is set twice,
  as the limit that counts now and as the limit that may not be raised again; from release 83
  on both in one call of `setrlimit` that lzrprf makes itself (`sub limited`). Before that a bare `ulimit` set them: the shell macOS uses as
  `/bin/sh` unless an administrator chose another sets both kinds that way, but one of the
  shells that can be chosen sets only the first, and there the program could have raised
  its limits again. The hostile application asks for more processor time and more memory
  too, in both containers, and a copy that sets only the first kind is noticed (`lostsoft`). The hostile application asks the system for a
  limit of 300, in both containers, where it must be refused, and outside, where it must be
  given; the run `lostfiles` takes the limit out of the page container, and the limit on
  `curl` has no such copy. Where lzrprf was itself started with a limit below 256 that no
  process may raise, that lower limit stands (before this was written so, such a start
  failed). `sub holds` does not try it at each start:
  it still tries seven things.
- The end of lzrprf. From release 17 on each page has a second process of lzrprf's own, its
  keeper (`sub keeper`), started in `sub laid_out` right after the application and before
  macOS is asked about it. It waits for lzrprf's word that macOS called the application
  contained, hands the site's answer over, and all the while waits for one thing: the end of lzrprf.
  It reads a pipe whose other end only lzrprf holds, so when lzrprf ends in any way, also when
  it is killed, the keeper ends the application at once, and then itself. `selftest` kills
  lzrprf while the application sleeps, and the application is ended (`killed`); with the
  keeper's line taken out the application goes on, so the test would notice (`leftkilled`).
  Release 16 and earlier left a page process running when lzrprf was killed. What remains:
  if the keeper itself is killed by another program of your account, nothing ends the
  application when lzrprf is killed later. The keeper is started right after the
  application, so an lzrprf killed in the instant between the two leaves that one
  application without a keeper. And after lzrprf's end the keeper acts on the application's
  process number: if the application ended in that same instant and the system gave its
  number to a new process of your account, that process is the one ended. And `curl` in the
  fetch container has no keeper:
  it ends by its own limit of 30 seconds, or when lzrprf's socket closes.
- Memory. The same `sub limited` sets, before the container starts, the system's
  own limit on address space (`RLIMIT_AS`) to what a shell holds plus 2 GiB. One shell is
  measured once with `ps -o vsz=` as a window begins (`sub shell_measured`), and every container
  is given that number: shells vary by under 1 MiB. Until release 83 a shell (`/bin/sh` with
  `ulimit`) set these limits and became `env -i`, which became `sandbox-exec`; from release 83
  lzrprf sets them with the same `setrlimit` in the process that becomes `sandbox-exec`, and
  replaces its variables whole (AUDIT.md "Limits set by lzrprf itself"). macOS will not set the
  memory limit below what a process holds already: an lzrprf grown past that becomes a small
  perl first, which sets it (`$ROOM_SET`). What the application holds at its own start is not measured, so its real room is
  about 2 GiB, a little more or less. macOS enforces the limit: a request beyond it is refused
  by the system. If a limit cannot be set, nothing is started. `selftest` asks for 3 GiB in
  the page container, where it must be refused, and outside every container, where it must be
  given. The limit counts address space, not memory in use: an application that reserves much
  more than it uses (a large engine does) would need a larger `$PAGE_ROOM`, and with too small
  a one it shows no page.
  The system's `curl` in the fetch container is started under the same limit on memory, and
  from release 15 also with at most 30 seconds of processor time, no byte written into a file
  and no memory dump (`$FETCH_LIMITS`); the test asks for the 3 GiB there too. From release
  16 on `curl` sees no variable at all, not one a shell that sets its limits made for itself
  (`PWD`, `SHLVL`, `_`; from release 83 no shell sets them); in
  `curl`'s place the test's program lists what it is given, and the list must be empty.
  The window's process (the system's `osascript`) has no limit on memory or processor time,
  and neither has lzrprf's own process or any process it starts outside the page and fetch
  containers (the keeper, the name lookup, `route`, `xattr`, `sysctl`, the `osascript` that
  asks macOS, `open`, `selftest`): only `$PAGE_LIMITS` and `$FETCH_LIMITS` set limits.
  From release 21 on what the window's process is given to set is bounded (point 8 of "How
  it works": the size of a list and of a block, and the two changes in a text). That bounds
  the work one page was measured to make it do; it is no limit on the process itself.

Limit, said plainly: within those limits a hostile application can still load this computer,
each time you ask for a page: about 2 GiB of address space, as the system counts it, and every
processor core until its 30 seconds of processor time are used. Then it is ended. Memory the
kernel holds for a process (what is in its pipes, and in messages it sends to itself) is not
counted in that limit; it is bounded only by the 30 seconds, after which the process and what
was held for it are gone. No probe of the test tries that. And a flaw in macOS itself, in its
kernel or its sandbox, is outside what lzrprf can refuse.

## It cannot read or change your files

The page and fetch containers may read the system's own folders and the application's own
folder, and write nothing. `selftest` puts a secret in your home folder and tries to read it,
to learn that it exists, to list the folder, and to reach it by its other path through the data
volume and by its number on the disk (`/.vol/…`). It tries to read and change the log, the setting of what is kept (`~/.lzrprf/keep`)
and `lzrprf` itself, and to put a setting of its own in its place. Each is refused.

## Is its safety mathematically proven?

No. See "What "proof" means here". It rests on parts nobody has proven: the macOS kernel and
its sandbox, the system's `perl`, `curl` and `osascript`. What this repository gives instead is
short enough to read, probed on your own Mac, and probed again whenever macOS changes.
