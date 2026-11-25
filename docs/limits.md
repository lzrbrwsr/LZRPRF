# What it does not prove

This text was the README section "What it does not prove" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- Releases are signed from release 76 on ([C25]).

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/limits.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| - The program started by another hand. lzrprf ... | - | C1 | - |
| - What you are told to type. A ... | - | - | - |
| - What you are shown. The application decides ... | `address` | - | - |
| - The window's process. It draws text the ... | - | C10 | - |
| - say to lzrprf what the window says ... | `hear`, `choose_keeping`, `changed` | - | - |
| - say that a page it was handed ... | `behind` | - | - |
| - look up by name 42 of the ... | - | C22 C3 | `shaders`, `videoplays`, `novideodecoder`, `openservices`, `lostservices`, `widerservices`, `soundplays`, `soundwindow` |
| - make shared memory, open devices and reach ... | - | - | - |
| - read the four folders it is allowed ... | - | - | - |
| - read your temporary folder (getconf DARWIN_USER_TEMP_DIR, under ... | - | - | - |
| lzrprf's own lines for the window read no ... | `checked` | - | - |
| - What the site learns. Your internet address, ... | - | - | - |
| - The parts lzrprf stands on. The macOS ... | `fetch` | C7 | - |
| - sandbox-exec is marked deprecated. The command and ... | `proven` | C11 C2 C3 | - |
| - Your account. Any other program you run ... | - | - | - |
| - The first download. The installer and the ... | - | C25 | - |
| - A tunnel that carries everything. A network ... | - | - | - |
| - Load. Within about 2 GiB of address ... | - | - | - |
| - What is kept, and where else it ... | - | - | - |
| - Time. How long a page container runs ... | - | - | - |
| - A question left open. A question in ... | - | - | - |
| - Lines the test could not try. An ... | `proven` | - | - |
| - The mark. The mark of [C11] is ... | `mark` | C11 | - |
| - Counting lines. Where the table says "reads ... | - | - | - |
| - Who takes the connection. lzrprf hands the ... | `fetch` | - | - |
| - A page process left behind. From release ... | `keeper` | - | - |
| - An authority added to this Mac. curl ... | - | - | - |
| - Older installers. The refusal to put an ... | - | - | - |
| - latest held back. Whoever holds this repository ... | - | - | - |
| - Where it was run. By the maker ... | - | C11 | - |
| - Other ways in. It holds for a ... | - | - | - |
<!-- index end -->

- **The program started by another hand.** lzrprf holds the closed program when lzrprf
  starts it `[C1]`. Nothing that is installed starts it another way: the launcher is one
  command that you can print ("Check it yourself"), and it starts `lzrprf run`. But
  `lzrbrwsr-bin` is a file like any other: you, or another program of your account, can start
  it straight, and then it runs with no container. See "Your account".
- **What you are told to type.** A hostile application cannot send anything by the ways its
  container gives it (the exception is "The window's process" below), but it can show a
  text that asks you to type an address that carries a secret. See "It can read a few facts
  about your computer".
- **What you are shown.** The application decides what the page says. It can show a page
  falsely. It cannot change the bar, the buttons, the log or the title. Of the words under
  the bar and of the questions it can choose only up to four host names and their count (see
  "No request you did not ask for"), and which of five fixed phrases says why a page was not
  shown, which the question about a report repeats: the rest are lzrprf's,
  and the bar shows the address lzrprf made of what you typed and asked for (`sub address`),
  whether or not an answer came.
- **The window's process.** It draws text the application chose, with macOS's own text drawing.
  This is the weakest point, so it is said in full. If such text could take over that process,
  the process has no network of its own, writes no file, starts no other program, opens nothing through
  the system, commands no other program, sends no signal to another process, and reads nothing under `/Users` or on another disk
  but settings, fonts, keyboard layouts and input methods `[C10]`, by the data volume's name of those
  folders too (`/System/Volumes/Data/Users/...`); `selftest` also tries the file by its number
  on the disk (`/.vol/...`). What it could still do:
  - say to lzrprf what the window says (`sub hear`): "go ADDRESS" as if you had typed it, a
    press of either button of the question that is open ("Send", "Yes, look", "Install it",
    "Clear the log" and the buttons that keep less among them), a request for the
    log, a support request of its own words to the one support address of the release file
    (with your licence code when one is kept), a tab pulled out, which starts a second
    lzrprf for the address that tab shows, or a window of a profile, by its id, or a
    profile made, renamed or removed. Removing one asks lzrprf's own question, which such a
    window could answer as it can any question; it never removes the first profile or one with a
    window open. Each of these that fetches is in the log before
    it has an effect outside your Mac,
    and "Install it" runs the installer of the published release, the same from both places,
    in lzrprf's own modal. A
    press cannot make lzrprf keep more: the buttons that change what is kept only keep less
    (`sub choose_keeping`), and the change is a line of the log (`sub changed`). Two presses
    clear the log on this computer: a kept log then says so in its first line, and with
    nothing kept no log is left and only that window's lines say so. lzrprf has no way of its
    own to tell such a line from your Return or your click: the log shows it as typed or
    pressed;
  - say that a page it was handed could not be drawn. That opens the question about a report,
    once for each page (`sub behind`), and "Send" is one of the presses above;
  - look up by name 42 of the system's services (Mach services) and one local name, the
    clipboard's. It could read what you copied, and put text on the clipboard, which other
    programs read and which macOS may carry to your other devices (Universal Clipboard). The
    one way out that lzrprf itself gives it is an address it asks lzrprf to fetch, which is
    logged first. From release 19 on its container refuses the lookup by name of every
    other service (`(deny mach-lookup)` and the list after it in `$WINDOW_CONTAINER`).
    The 41 are services a window's process was seen to ask for on macOS build 26B123;
    that each is needed was not tested, except the graphics shader compiler, added in
    release 34: the system draws a window's pictures on the graphics card and has the
    compiler teach it each new way of drawing one, and without it the system ended the
    window the moment a tile, a scaled picture or a full-screen window needed one.
    `selftest` compiles a shader from inside the container (`shaders`). The 42nd is the
    system's video decoder, added when the window began to play a video you click `[C22]`:
    without it the system's player in the window says "Cannot Decode", and `selftest` plays
    a clip from inside the container (`videoplays`) and not without the name
    (`novideodecoder`). It decodes a site's bytes, chosen by the site, in a process of macOS
    outside every container of lzrprf. One more that a window asks for, the helper of the
    Services menu, is left off the list and so refused, because it lets another
    application act on what the window hands it. macOS is asked at every start whether the
    container refuses a system service by default; that question names no service, so it
    says nothing about the list. From the real window `selftest` asks for six by name: the
    clipboard is answered, and the system's downloader, the keeper of certificates, the
    network's settings, the resolver of names and the watcher of files are refused. A copy
    without the refusal and without that question is answered as a program outside every
    container is (`openservices`), a copy with the refusal alone taken out shows no page
    (`lostservices`), and a copy whose list names the downloader too is caught by the same
    try (`widerservices`). Before release 19 the container refused one service, the
    system's downloader, and allowed every other.
    What this does not cover: a connection that a listed service hands back, a port the
    process was started with, and the drivers of devices (IOKit) are not lookups by name.
    And each of the 42 is a program of macOS that the window's process may talk to. Four
    kinds of them, named because nothing here tests what they would do for a window that
    was taken over: launch services (three names) keep the list of which application opens
    which kind of address; the keepers of input methods (four names) hand out connections
    to other processes; the system's log and its notifications (six names) take what the
    process writes, the log keeps it on disk, and a notification reaches any program of
    yours that listens; sound, the window server and the keeper of privacy permissions
    answer by macOS's own permissions, which this container neither adds to nor takes
    away. The registrar of audio components (`com.apple.audio.AudioComponentRegistrar`) is
    not among the 42, and stays off the list: without it the system's player in the window
    neither prepares nor plays, so the window plays no sound, a video's included. A page's
    sound, and a video's once you turn it on (its MP4 handed over, the sound kept within
    40 ms of the window's picture, `soundvideo`; nothing started for a page with no video),
    is played by the sound process in its own container (`$SOUND_CONTAINER`), which
    starts from "deny everything" and may look up three names: that registrar, the system's
    sound server and the core services. Those three were measured, each needed and enough:
    with the registrar or the sound server taken away the player there did not play, and
    without the core services `osascript` ran no JavaScript. `selftest` plays a sound in that
    container and hears the player say it started (`soundplays`), plays the same in the
    window's container and hears it fail (`soundwindow`), and checks that the window's list
    holds 42 names without the registrar and the sound container exactly its three. The sound
    process is handed only samples the page made, the MP4 of a video whose sound you turned on, and play, stop and the picture's clock, after macOS says it is
    contained `[C3]`; what it can reach is the sound server, which plays to your speakers,
    and the two services above. Nothing here proves that none of the 42 is another way out. In the one run of a
    window on screen that was made with this list (with the Services helper still on it),
    the window asked for more, the graphics shader compiler among it, and was refused: it
    still drew and took typing then, but from release 31 on its pictures needed a shader
    that was not ready, and the system ended the window; the compiler is listed since
    release 34. Where a window asks
    for a service that is not on the list, that service is refused, the window may then
    not work, and the container holds as before;
  - make shared memory, open devices and reach their drivers (IOKit): the window's container (`allow default`) does not
    deny these. A signal to another process it does deny (`(deny signal)`, with a signal to
    itself allowed): macOS is asked about that at every start, and from the real window
    `selftest` asks to send one to its own process (signal 0, which delivers nothing) and
    sees it refused;
  - read the four folders it is allowed (your settings, fonts, keyboard layouts and input
    methods), and what any program of yours can read outside `/Users` and other disks. From
    release 18 on `selftest` puts a file of its own among your settings
    (`~/Library/Preferences`) and shows the difference: read outside every container, refused
    in the page and fetch containers, and what the real window's process got is printed in
    its line (`settings=read`, while macOS allows it what the container allows). The run that
    made that file removes it; a run killed outright leaves it there, one line long, as
    `lzrprf-selftest.NUMBER`;
  - read your temporary folder (`getconf DARWIN_USER_TEMP_DIR`, under `/var/folders`, outside
    the home folder). It is not denied, because `osascript` keeps its own caches there;
    `selftest` reads a file of its own there from the real window, and that line says it was
    read.

  lzrprf's own lines for the window read no file of the closed download: the icon of the
  running window in the Dock is drawn by the lines of `icon` in `window_text`, and no picture
  is taken from the app. What lzrprf hands the window from the application is the list of
  lines that `sub checked` let through, and nothing else. Two things stay as they are for
  every app: a window that was taken over could read the app's files as it can read anything
  outside `/Users`; and the Finder, and the Dock while the app is not running, show the app's
  own icon file (`Contents/Resources/lzrbrwsr.icns`), read by macOS as soon as the app is on
  the disk, with no container of lzrprf's around the Finder.
- **What the site learns.** Your internet address, the time, the address you typed with its
  path and query, and how this macOS and the system's `curl` speak TLS and TCP. lzrprf keeps
  the closed program from sending what it reads; it does not make your Mac look like any other
  Mac. The name lookup is seen by your resolver.
- **The parts lzrprf stands on.** The macOS kernel and its sandbox, and the system's `perl`,
  `sh`, `env`, `ps`, `curl` with its TLS library and list of authorities, `route`, `sysctl`,
  `open`, `xattr` and `osascript`. A flaw in one of these is a flaw here. A flaw in `curl` can reach one place
  only: the connection lzrprf made for the address you typed (`selftest` puts the hostile
  application in curl's place). A `curl` taken over by a site's answer could send that one host
  other bytes than the fixed request, through that one connection, within the 64 KB and the 30
  seconds a fetch carries (`sub fetch`): lzrprf does not read inside the encryption `[C7]`.
- **`sandbox-exec` is marked deprecated.** The command and the profile language are; the
  mechanism in the kernel is the one macOS confines its own processes with. So lzrprf does not
  trust it to keep working: `[C11]`, `[C2]` and `[C3]` make it prove itself on every build of
  macOS, at every start and for every process, and nothing is shown when it does not hold.
  The day a build of macOS comes without the command, or reads a profile another way: the
  mark of `[C11]` is for one build of macOS, one `lzrprf` and one `selftest` (`sub proven`), so after a system
  update no page is shown until `selftest` held again on the new build. Where a profile no
  longer holds, the window says so, names `selftest` to see what was not refused, and the
  program is not started. Where the command itself is gone, no window opens: lzrprf stops with
  one sentence, which you read when you start it from a terminal; started from Applications,
  nothing appears. There is no second road that runs it without the container in lzrprf itself; a start by another hand is under "What it does not prove". LZRBRWSR then does not work on that build until a
  release whose container holds there. What that container would be is not built.
- **Your account.** Any other program you run can change `~/.lzrprf/lzrprf` or the launcher.
  Compare them with this repository.
- **The first download.** The installer and the download stand in two places that would both
  have to be changed: the site and this repository. Both places are in the hands of one maker.
  From release 76 on a release is installed only when its manifest is signed with the release key and
  approved with an approval key (`[C25]`, VERIFY.md). "The installer" says exactly what the two places
  are worth and what they are not.
- **A tunnel that carries everything.** A network reached by the default route itself, such as
  a VPN all traffic goes through, looks like the internet to lzrprf: a host in there with a
  public address is fetched without the question about your own network.
- **Load.** Within about 2 GiB of address space and 30 seconds of processor time, each page
  can still load this computer, with as many threads as it starts. The window's process and
  lzrprf itself have no limit on memory or processor time. A flaw in macOS
  itself is outside what lzrprf can refuse. See "It cannot reach other applications".
- **What is kept, and where else it can go.** The lines of a window that keeps nothing are in
  memory, which the system can write to its swap or into a crash report. A log of hosts still
  shows habits. Time Machine's honouring of the mark is Apple's. See "What is kept".
- **Time.** How long a page container runs is the application's choice, up to 30 seconds after
  it is handed the answer, and about a second more. The
  request is over before the application sees the answer, so it cannot shape a request by it.
- **A question left open.** A question in the window that is still open after 10 minutes counts
  as answered with its first button. A window closed while it asks ends lzrprf: nothing is
  fetched or sent. The first button never fetches or sends anything, never
  replaces the application or the log, and never keeps more. Two such answers are written
  down: a "No" to looking for newer releases, like a no you pressed (delete `~/.lzrprf/look` to
  be asked again), and, after you pressed "Keep less", "Keep nothing", or after "Keep a log"
  from full addresses, "Hosts only".
- **Lines the test could not try.** An `UNTESTED` line does not stop an install. There are four
  such lines in `selftest`. Two depend on the network of the moment: whether `curl` opens
  its encryption with the same bytes each time, and how this Mac would send to an address on
  the internet. Neither is about what holds the program, and a Mac that is offline would
  otherwise never be allowed to show a page. The third, from release 17 on, is about the
  container: when the test was itself started with a limit below 300 open files that no
  process may raise, a try at 300 is refused with or without a container, so the limit of
  256 cannot be shown there. A Terminal as macOS sets it up has no such limit. The fourth,
  also from release 17 on, comes when this macOS holds no file of code for its perl that
  the test could copy into the hostile application's folder: then the refusal to load one
  cannot be shown. So a run whose other lines held still writes the
  mark, and the mark then names each check that could not be tried, with the reason. The
  installer prints those lines again when the test ends. LZRBRWSR does not start on such a
  mark before its window has named the checks and you pressed "Start" (`sub proven`): what
  could not be tried is not shown to hold on your Mac, and that is yours to accept or not.
  Your yes is kept in `~/.lzrprf/untested` as that whole line of the mark. When the build of
  macOS, `lzrprf`, `selftest`, the checks untried or their reasons change, the line is
  another one, and you are asked again. The window shows all of the line's text: lzrprf
  counts 600 characters of it at most, and a `selftest` with more to name cuts its list and
  says so in it. That file is a plain file of your account, like the mark: see the next point.
- **The mark.** The mark of `[C11]` is a record in a plain file of your account
  (`~/.lzrprf/proven`), which any program running as you could write, as it could change
  `lzrprf` itself. It protects against forgetting to test after an update, not against a
  program already running as you. The mark always names the build of macOS, and `lzrprf` and
  the `selftest` that ran each by its SHA-256, and lzrprf compares it with the `selftest`
  beside it (`sub mark`). A mark without the `selftest`'s sum counts as no mark. The yes in
  `~/.lzrprf/untested` is the same kind of record, with the same limit.
- **Counting lines.** Where the table says "reads the text", `selftest` counts lines of
  `lzrprf`. That catches a careless change. It is no defence against a deliberate one, which
  would change the test too. What ties the file you run to the file you read is its SHA-256.
- **Who takes the connection.** lzrprf hands the one connection to the first process that
  opens its socket file, after macOS said that `curl` is contained (`sub fetch`). It does not
  ask which process opened it. The file is in `~/.lzrprf`, which only your account can enter,
  and the fetch container is given that one name. Another program of your account could take
  a connection in that moment; see "Your account".
- **A page process left behind.** From release 17 on, when lzrprf is ended by force while a
  page is laid out, the page's keeper ends the application at once (`sub keeper`). If another
  program of your account killed the keeper first, nothing ends the application when lzrprf
  is killed later, and the same holds when both are killed at once: it stays in its container,
  with no network and no file of yours, until it ends, uses up its processor time, or you log
  out. Processor time is counted only while a program computes, so one that sleeps is not
  ended by that limit. Two smaller moments are named under
  "The end of lzrprf". `curl` has no keeper: it ends by its own
  limit of 30 seconds, or when lzrprf's socket closes.
- **An authority added to this Mac.** `curl` trusts the certificate authorities of macOS. One
  that you, an administrator or another program added is trusted like the rest, and whoever
  holds its key and stands in your network reads and changes what is fetched.
- **Older installers.** The refusal to put an older release over a newer one is in the
  installer since release 5. An older installer, or a download unpacked by hand, does not
  refuse.
- **`latest` held back.** Whoever holds this repository can leave `latest` at an old number.
  Then nobody is offered a newer release. Nothing is installed by that, and the file's history
  is public.
- **Where it was run.** By the maker on one Mac: macOS 27.2, build 26B123, Apple silicon.
  That is why `[C11]` makes your Mac run the test itself before a page is shown.
- **Other ways in.** It holds for a program started through `lzrprf run`. `lzrprf try`,
  `lzrprf behind` and `lzrprf lookup` are entries of the same code: `try` is `run` with its
  state in a test folder and a test site in place of the name lookup, for `selftest`, which
  the installer runs; `behind` and `lookup` are what `run` starts for itself. The launcher
  uses none of them.
