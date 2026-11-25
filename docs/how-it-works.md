# How it works

This text was the README section "How it works" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- lzrprf starts more than four kinds of contained process: the converter, the reader, the verifier and Tor were added.
- Pictures are fetched and shown; "every picture is a grey box" was dropped.
- "How lzrprf is built from its parts" was added at the end, with the split of lzrprf into the parts in src/.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/how-it-works.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| Your Mac shows one window, named after the ... | - | - | - |
| container what runs in it network what it ... | - | - | - |
| page the closed application, once for each answer ... | - | - | - |
| fetch the system's curl, once for each request ... | - | - | - |
| window lzrprf's own window text, run by the ... | - | C22 | - |
| decoder the system's sips, for an AVIF, HEIC ... | - | C21 | - |
| The page, fetch and decoder containers start from ... | - | - | - |
| Before the first page, at every start (sub ... | `behind`, `paired`, `visit`, `laid_out`, `proven` | C10 C11 | `pairother`, `pairnone`, `fileother`, `filebeside`, `filegone`, `filenone`, `fileunnamed`, `filefolder`, `filedamaged`, `filelone`, `fileextra`, `filedot`, `lostbeside`, `swapped`, `lostswap`, `lostlook` |
| One visit, in order (sub visit): ... | `visit` | - | - |
| 1. You type an address into the bar ... | - | - | - |
| 2. lzrprf checks that it is an https ... | `address`, `record` | C5 | - |
| 3. It looks the host up, in a ... | `find` | - | - |
| 4. If the host leads into your own ... | - | C8 | - |
| 5. It writes down the numeric addresses, connects ... | `fetch`, `route` | C6 | - |
| 6. It writes down how it ended and ... | - | - | `logend` |
| 7. Only now, with the connection closed, and ... | `laid_out`, `keeper` | C1 C3 | - |
| 8. The application writes a list of what ... | `checked`, `pictured`, `laid` | C9 C21 | - |
| A page kept running [C18] may have parts ... | - | C18 | - |
| - n ID P g a group, n ... | - | - | - |
| - m ID A B C D E ... | - | - | - |
| The checks (sub live_layer) are strict. An id ... | `live_layer`, `live_layers_paid` | - | - |
| The window of the tab shown is told ... | `live_layers_again` | - | - |
| What the application sends as layers, and what ... | - | - | - |
| A page kept running [C18] may play sound ... | - | C18 | - |
| - =sound ID RATE FRAMES FROM TO makes ... | - | - | - |
| - =samples ID BASE64 adds to its samples, ... | - | - | - |
| - =play ID AT sounds it from frame ... | - | - | - |
| The checks (sub live_sound) are strict. An id ... | `live_sound` | C12 | - |
| The window does not play it. Its container ... | `sounding`, `sound_started`, `sound_heard` | C3 | `soundplays` |
| The sound process is told a sound's samples ... | `sound_told`, `sound_heard`, `tab_shown`, `sound_hushed` | C12 | `soundwindow` |
| A video's sound is played there too [C22], ... | `video_sound_kept`, `sound_heard` | C22 | - |
| lzrprf ships as one file, and its SHA-256 ... | - | - | - |
<!-- index end -->

Your Mac shows one window, named after the application. That window is lzrprf's. Behind it,
lzrprf starts its processes in containers: macOS sandbox profiles. The table lists the four that run
for a page; the converter, the sound process, the bookmark reader, the verifier and the Tor client
have containers of their own too (CAPABILITIES.md, and "Sound of a page kept running" below). The
keeper of a page, the name lookup and the system's tools that lzrprf calls run outside the
containers, as lzrprf itself does; the closed program is never one of them.

| container | what runs in it | network | what it is given |
| --- | --- | --- | --- |
| page | the closed application, once for each answer | none | the finished answer on one pipe; a pipe to lzrprf for a list of lines |
| fetch | the system's `curl`, once for each request | none | one socket file, behind which lzrprf holds the one connection |
| window | lzrprf's own window text, run by the system's `osascript` | none of its own | two pipes to lzrprf, and the 42 system services and one local name its container lists; a video you clicked, held in its memory, its container read by the system's player in this process, its pictures decoded by the system's video decoder `[C22]`; the registrar of audio components is not on its list, so it plays no sound |
| decoder | the system's `sips`, for an AVIF, HEIC or HEIF picture the application hands back whole `[C21]` | none | one file to read and one PNG to write, in a folder lzrprf made for that picture, a folder within for its temporary file, and two things of the system: a lookup of its video decoder service by name, and connections of one class to a driver, the graphics surfaces (`IOSurfaceRootUserClient`), which `sips` opens itself; every byte it reads was chosen by the site |

The page, fetch and decoder containers start from "deny everything" and allow a short list
(`$CONTAINER` in `lzrprf`, and `$DECODER` for what the decoder adds). The window container is written the other way round
(`$WINDOW_CONTAINER`): what a program of yours may do, without a list of things, except the
system services it may look up by name, which from release 19 on are listed one by one. It is the
weaker of the two kinds, and "What it does not prove" says what follows from that. What is
outside every container is `lzrprf` itself: it looks up the name, makes the one connection,
writes the log and checks what crosses.

Before the first page, at every start (`sub behind`): macOS is asked whether the window's own
process is in its container `[C10]`, and lzrprf looks whether `selftest` held on this Mac as it
is now `[C11]`. Without both, no page is shown. lzrprf also compares its own SHA-256 with the
line `lzrprf` of the installed app's `release` file; when they differ, or when the app names
no lzrprf at all (apps before release 12 named none), it says so and does not start: that
window has one button, Quit (`sub paired`, the runs `pairother` and `pairnone` in `selftest`).
From release 16 on the same `release` file names the launcher and the program with their
SHA-256 (two lines `file`), and lzrprf compares each file those lines name with the file
that is there, at the same moment: when one is another file, or the program is not named,
the app does not start either (the runs `fileother`, `filebeside`, `filegone`, `filenone` and
`fileunnamed`). Only a plain file is read, so a folder, a pipe or a device of that name
counts as another file (`filefolder`), and a line that begins with `file` and is not in its
shape counts as a file that differs (`filedamaged`). From release 17 on, in an application
folder, every entry in the program's folder (`Contents/MacOS`) whose name does not begin with
a dot must be named by a line `file NAME SHA-256`: so the launcher must be named, and a file
put beside the program that the `release` file does not name stops the start (`filelone`,
`fileextra`). A name that begins with a dot is passed over, because the Finder writes
`.DS_Store` there, and nothing starts such a file (`filedot`). Release 16 required only that
the program be named (a copy that does not look beside it: `lostbeside`). The installer stops
unless both lines are there. The named files are looked at once, at the start, measured by a
file of the app's own: it finds a program or a launcher that was changed while that file was
not, as a damaged disk or a copy that did not finish leaves them. From release 17 on the
program is also read again for every page, twice: lzrprf takes its SHA-256 at the start,
takes it again when you press Return, before a site is asked (`sub visit`), and once more
just before the program is started (`sub laid_out`). When it differs at the first, nothing
is fetched. When it changed while the site answered, that request was made and is in the
log, and the program is not started. The
window then says that the program on the disk is another file than when the window opened, as
after an update, and to quit and start again; no report is offered for this (`swapped`,
`lostswap`, `lostlook`). Release 16 looked once, at the start. Between reading the file and starting it
there is a moment. Whoever can replace the program can replace that file, and lzrprf, too:
this finds an update or a damaged file under an open window, not an intruder in your
account. It does not have to find one: the program is the part that is assumed hostile, and
it is kept in the container whichever file it is.
A program that stands in no application and has no `release` file beside it is not asked: the
installer places no such program, and the launcher starts none. And when the mark names checks the test could not try on this Mac,
the window names them and asks, and no page is fetched or shown before your yes to exactly those
(`sub proven`).

One visit, in order (`sub visit`):

1. You type an address into the bar and press Return. The window tells lzrprf.
2. lzrprf checks that it is an https address of a host by its name (`sub address`). From
   release 17 on it then reads the application's program again: when that is no longer the
   file the window began with, the visit ends here, with nothing written and no site asked.
   Then it writes
   "you typed ADDRESS" into the log `[C5]` (`sub record`). When you chose to keep a log (see
   "What is kept") the line is written to the disk first, and added to the memory of the
   process behind the window only after that write succeeded; otherwise it goes into that
   memory alone. Both come before the request.
3. It looks the host up, in a process of its own that is given 10 seconds, and takes the first
   8 addresses this computer has a way to (`sub find`): one it has no route to is passed over,
   and what the lookup gave beyond its first 16 is not looked at.
4. If the host leads into your own network, it asks you, for this one request `[C8]`.
5. It writes down the numeric addresses, connects to one of them itself `[C6]`, and lets `curl`
   do the https over that one connection, in the fetch container (`sub fetch`). A fetch is
   given 30 seconds, looked at once a second, so a request that runs over ends at most about a
   second later. Those 30 seconds start in `sub fetch`: the lookup before it, the question to
   the system about the way to each address (`sub route`, 5 seconds each, and a second one for
   some), and your answer about your own network have their own time and are not inside them.
   From release 19 on the way the internet at large is sent is recognized over IPv6 too:
   macOS writes that route with the destination `::`, and until release 18 lzrprf took it
   for a route of your own, so on a network with IPv6 it asked about your own network before
   a site that has an IPv6 address. It asked too often, never too seldom.
   An answer may be 6 MB, and 64 KB at most are carried to the site. Neither
   bound is passed: what comes beyond it is not passed on, and the request fails.
6. It writes down how it ended and which address answered. When that line cannot be written,
   the answer is not shown, and the window says that the fetch was tried, not that nothing was
   fetched (the run `logend` of `selftest`).
7. Only now, with the connection closed, and from release 17 on only when its program is
   still that same file, the closed application is started in a page container
   `[C1]` with the address in one variable and nothing else, and handed the answer once macOS
   itself says the process is contained `[C3]` (`sub laid_out`). From release 17 on the
   answer is handed over by the page's keeper, a second process of lzrprf's own (`sub keeper`),
   which ends the application when lzrprf ends (see "It cannot reach other applications").
8. The application writes a list of what to draw. lzrprf checks every line `[C9]`
   (`sub checked`) and gives the window only lines of five kinds: a paragraph begins, text, a
   line ends, a grey box where a picture would stand, and before all of these, from release 20
   on, a thing the application says the page is made of; or a laid page. The window draws them.
   Pictures are fetched and decoded (`sub pictured`, `[C21]`), and a laid page carries their pixels.
   Those first lines are what the application says the page is made of: a kind (one of eight
   letters: document, CSS, JavaScript, libraries, media and formats, web APIs, security and
   transport, metadata), a `+` or a `-` for whether the application says its own code
   supports the thing, a name of at most 60 plain characters, and after a tab a version of at
   most 30. There are at most 120, in the order of the kinds and by name within a kind, no
   name twice in a kind, so one list has one form. The window lists them in a pane under the
   page, a row for each: its name, its version, and "supported by" the application's name
   with true or false. Above the rows a sentence says that lzrprf checked the form of the
   list and not whether it is true. Apart from refusing a whole list in which such a line has
   a wrong form or place, lzrprf does nothing with them: nothing is fetched or allowed
   because of what they say.
   From release 21 on the list is also held to what the window can set without standing
   still. The window sets text with the system's own code, and that code slows down far
   more than the text grows: measured in the real window, unseen, one block of 100,000
   characters outside the first font kept it busy for more than a minute, and so did one
   letter under 20,000 marks. So a list may hold 12 MB and 50000 lines, and one block (from
   one line that begins a paragraph to the next) 20000 characters as the application wrote
   them, where a line break counts 1 and a grey box 400. A list over any of these is not
   drawn at all. And lzrprf changes two things in a text, as it changes a control
   character in it to U+FFFD. After 30 characters in a row that hang on the one before them
   the next becomes U+FFFD. What hangs is what Unicode joins to the character before it (a
   mark, a character that extends a cluster or is spaced like a mark, a Hangul vowel or
   final, a Hangul initial after another), what follows a character that comes before its
   letter, and what follows a sign that joins two letters into one (`$HANGS`). And after
   1000 characters with no white space, that is with no space where a line may end (a
   no-break space is none), it puts in a space of no width (U+200B), which shows nothing
   and lets a line end there. It is put after the characters that hang on the last one; a
   word that ends in them keeps them whole. A text you copy out of the window holds those
   spaces. `selftest` draws the heaviest pages these limits allow, of each kind that was
   measured slow, in the real window, and fails when one takes 30 seconds; on the Mac this
   was written on the slowest took about 7. That is a measurement on one Mac and one build
   of macOS, not a bound on the system's code: a text of a kind nobody tried may still be
   slow.
   From release 22 on a page may instead be laid: the application has laid it out itself and
   says where everything stands (`sub laid`). After the lines of what the page is made of
   comes one line with the page's width, 320 to 2400, and height, 1 to 200000, in CSS pixels.
   Then, in the order they are painted: filled rectangles in a colour, runs of text whose
   baseline begins at a point, in a size of 6 to 96 and with the same letter of looks as a
   text, grey boxes where a picture would stand, and pictures. A picture is given as its
   pixels, at most 1024 by 1024, one line of base64 for each row: red, green, blue and how
   opaque, a byte each. All the pictures of a page hold 262144 pixels at most. Every number
   is written in one way only, everything stands inside the page, and a page is laid or
   flowing, never both. A laid page holds at most 20000 rectangles, 30000 runs of text, 1000
   grey boxes and 64 pictures, a run 2000 characters and all its runs 1000000, within the
   12 MB and 50000 lines of every list. A page over any of these, a picture whose rows are
   not as many as it says, a row that is not exactly as long as the picture is wide, or
   base64 in any other form than the one it is written in, is not drawn at all. A run of
   text gets the changes a text gets: a control or format character becomes U+FFFD, and so
   does the 31st character in a row that hangs, counted in each run by itself. No space of
   no width is put in, since a run is drawn on one line. The window draws a laid page in a
   view of its own in the place of the text: white, scaled to the window's width and never
   larger until the window is half as wide again as the page, the rectangles over what is
   under them, the text in Arial and Menlo, and each picture from its bytes as they are,
   handed to the system as pixels, with no image decoder. A laid page has no menu, and its
   text cannot be selected or copied.

## Layers of a page kept running

A page kept running `[C18]` may have parts that move every frame: an svg its script changes, a
box turning or fading for ever by itself. Drawing the whole page again for each frame would
send a laid page sixty times a second, so the application sends those parts once as layers, and
then only what changed of them, in lines `=layers ITEMS` between `=scroll` and `=again` of an
answer (src/page/layers.rs in the application). Each item, split by `;`, is one of:

- `n ID P g` a group, `n ID P k X Y W H` a group that cuts what it holds to a rectangle,
  `n ID P s FILL STROKE WIDTH CAP RULE GLOWC GLOWR PATH` a shape,
  `n ID P t SIZE WEIGHT STRETCH ANCHOR COLOR SPACING GLOWC GLOWR TEXT` a line of text, and
  `n ID P e COLOR RATE LIFE SPEED SPREAD ANGLE AX AY SIZE` a source of particles, each made
  under its parent P, a group or the page (0);
- `m ID A B C D E F` its transform, `o ID ALPHA` its opacity, `d ID PATH` a shape's outline,
  `f ID FILL STROKE WIDTH GLOWC GLOWR` its colours, `c ID TEXT` a text's words, `r ID RATE` a
  source's rate, and `x ID` the layer taken away with all it holds.

The checks (sub live_layer) are strict. An id is 1 to 9999; a layer is made once, under a group
that is there, and changed only in the ways of its kind. A number is written one way only: no
0 in front, at most four decimals and none of them a trailing 0, no `-0`. A colour is
`rrggbbaa` or `-`, an outline is M, L, Q, C and Z steps of at most 16 KiB, a text printable
characters without `;`, at most 200. At most 4096 layers and 64 particle sources at once; a
source's rate is 0 to 1000 a second, its life 0 to 10 seconds, its speed 0 to 2000, its spread
0 to 6.2832 and its particles at most 64 points across. A line is at most 65536 bytes, and the
lines of one page are paid from a budget of their own (sub live_layers_paid) that fills at
512 KiB a second up to 2 MiB: a scene of the most layers sent whole fits it, and so does a scene
of about 80 layers moving at 60 frames a second. Their bytes are not counted in the four laid
pages a page may write. Anything else ends the page, as any line out of its form does, and its
last drawing stays.

The window of the tab shown is told `layers T ITEMS` before the drawing of the same answer.
It keeps the layers in one view of its own inside the laid page's view, the page's size in its
own pixels, so they scroll and zoom with the page, and the scroll view cuts them to the page's
place: the bar, the strip, the tabs and every modal stand over them as over the page, and they
take no press, which goes on to the page under them. Each line is applied at once in one
transaction with Core Animation's own animations off, so a layer is where the page put it in
that frame and never slides toward it. A shape's glow is drawn once and kept; a particle source
is an emitter of the system's, which moves its particles by itself, so a page sends nothing for
them frame by frame. The window lets every layer go with another tab, a new page, and when no
page is kept running. A tab not shown is told nothing; when it is shown again lzrprf writes its
page `=layers` (sub live_layers_again), and the page takes every layer away and makes it again.

What the application sends as layers, and what it leaves to the drawing: an inline svg becomes
layers the first time its script changes it after the first list (that once it is drawn again
too), and from then on a change inside it is sent as layers with no drawing at all; a change
elsewhere is drawn as before. Of an svg it sends groups, paths, rectangles, circles, ellipses,
lines, polylines, polygons and text with their fill, stroke, opacity and transform, and a glow
written as `filter: drop-shadow(0 0 R C)`, read from their attributes and style attributes and
not from style sheets; an element with `data-particles` becomes a source.
A box of a page that keeps running, whose animations are only of transform and opacity and run
for ever, with a background or border and nothing painted inside it but its words, becomes a
group moved by the application at each frame. Gradients, clip paths, masks, use and images inside an svg,
letter spacing of a text layer and the turn of a particle source are not drawn as layers.

## Sound of a page kept running

A page kept running `[C18]` may play sound through its Web Audio: a buffer of samples its script
filled, played by a source that may loop. The application sends it in lines after `=layers` and
before `=again` of an answer (src/page/sound.rs in the application), and only once the page's
script started a source in a context the page may run, which the application allows only within
five seconds of a click or key it was handed:

- `=sound ID RATE FRAMES FROM TO` makes sound ID, FRAMES samples of 16 bits, one channel, at
  RATE frames a second, that loops from frame FROM to frame TO, or plays once when both are 0;
- `=samples ID BASE64` adds to its samples, in base64 lines of at most 65536 characters;
- `=play ID AT` sounds it from frame AT, and `=hush ID` silences it.

The checks (sub live_sound) are strict. An id is 1 to 4294967295 and made once; a rate is 8000 to
96000; a sound is 1 to 2880000 frames, a minute at 48000 a second; a loop lies inside it; its
samples are base64 in groups of four, padded only on the line that ends them, never more than it
holds, and a play needs all of them and a frame before its end. A page may make 1024 sounds and
16 MiB of samples in its life, counted apart from its four laid pages. Anything else ends the
page, as any line out of its form does, and its last drawing stays. A page never starts sound by
itself `[C12]`: lzrprf passes a play on only within five seconds of the last click or key it
handed the page, and only for the tab shown; a play later than that sounds nothing, and the log
says so once for the page.

The window does not play it. Its container does not let it look up the system's registrar of
audio components (`com.apple.audio.AudioComponentRegistrar`), without which the system's player
neither prepares nor plays, and that name stays off the window's list (Henry, 2026-11-21). The
sound is played by the sound process, core-lzrbrwsr-sound: the system's `osascript` in a container
of its own, `$SOUND_CONTAINER`, which starts from "deny everything" as the page's does and may look
up three services by name and nothing else: the registrar, the system's sound server
(`com.apple.audio.audiohald`) and the core services (`com.apple.CoreServices.coreservicesd`). That
list was measured on macOS build 26B123 by taking away, one at a time, the fourteen names the
process asked for: without the registrar or the sound server its player is not ready and does not
play, and without the core services `osascript` finds no JavaScript to run (sub sounding,
`soundplays`). lzrprf starts it on
the first sound, asks macOS whether it is contained before it hands it anything `[C3]`, and ends it
when it says it has had nothing to play for 30 seconds (`$SOUND_IDLE`); the next sound starts it
again, ready in about a tenth of a second (sub sound_started, sub sound_heard).

The sound process is told a sound's samples once, `sound begin T ID RATE FRAMES FROM TO` and then
`sound part T ID BASE64` lines, before its first `sound play T ID AT`; `sound stop T ID` silences
it, and `sound clear` stops and lets go of every sound (sub sound_told). It checks each line again
and holds every sound in its memory alone, at most 32 MiB, as a WAV of its samples handed to the
system's AVAudioPlayer as data, so nothing is written `[C12]`. A sound that loops is played once
from AT up to its loop and then the loop over and over. Every play is answered: `played ID yes`
when the system's player was ready and started, else `played ID no` with what failed, and lzrprf
logs a play that was not heard once for the page (sub sound_heard). The same process text in the
window's container answers `no` to every play (`soundwindow`). Every sound stops and is let go with
another tab, a new page, and when no page is kept running, and lzrprf then forgets what it sent
(sub tab_shown, sub sound_hushed): a sound played again after that is sent whole again. A tab not
shown sounds nothing.

A video's sound is played there too `[C22]`, while its picture stays in the window, whose player is
muted and whose container plays nothing. When an MP4 handed to the window has a sound track (the
handler `soun` in its description of tracks), lzrprf keeps a reference to the same bytes, two
videos at most (sub video_sound_kept); a video with none says `No sound` on its words and is turned
on by nothing. Nothing more happens until you click `Sound off`: a page with videos whose sound
stays off, and a page with no video, start no sound process. From that click the window says where
the picture is, `video at K STATE MEDIA RATE WALL`, at each play, pause, seek, end and change of
rate and each second while it plays (window_sound_text). lzrprf hands the MP4 over once, in
`video begin`, `video part` and `video end` lines of 48 KiB, and passes each clock on (sub
video_sound_at). The sound process makes the system's AVAudioPlayer of those bytes, which decodes
them itself, and follows the clock: it starts the sound 50 ms ahead on the device's own clock at
where the picture will be then, and sets it right again once it is 20 ms off (it answers `video T K
drift MS` for each clock while it plays). Measured on a 60-second clip with play, pause, a seek to
the start, rate 1.5 and back, 244 clocks: mean 8.6 ms, at most 10 ms apart, the same at both rates
(`soundvideo`). The bytes were chosen over decoded samples: lzrprf already holds them, so nothing
is fetched again and nothing more is decoded in lzrprf; AAC is about a tenth of the size of the
samples it makes, and 16 MiB was handed over in 0.29 s. An MP4 with no sound track, or one the
system cannot read, is answered `no` and logged once (sub sound_heard); the same text in the
window's container plays no video's sound (`soundvideowindow`). Turning the sound off pauses it;
the end of the video, another tab or a new page lets it go.

## How lzrprf is built from its parts

lzrprf ships as one file, and its SHA-256 is pinned. In git its source is the folder `src/`: one file
a part, named `NN-name.pl`, each an exact slice of lzrprf cut between two subs, so joining the parts in
the order of their names gives lzrprf byte for byte. To change lzrprf, edit the part that holds what
you change, run `perl tools/join` to write lzrprf from the parts, then run `perl selftest`, which
fails when `perl tools/join --check` says the parts do not join to lzrprf, or when the map of subs in
AUDIT.md is not what `perl tools/sub-map` prints for the parts. AUDIT.md, "How lzrprf is built from
its parts", lists the parts.
