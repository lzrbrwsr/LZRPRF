# Auditing lzrprf

This file is for a reader who wants to check lzrprf against what this repository says about it. It
gives a reading order, the trust boundary on one page, the map of every sub, and how to reproduce the
test and the build.

## Reading order

1. **THREAT_MODEL.md**: what is protected, from whom, and what is trusted.
2. **The first lines of `lzrprf`**, up to the line `use strict;` (the part `src/01-header.pl`): the
   commands it takes and the conditions `[C1]` to `[C27]`, each one sentence.
3. **The containers**: the sandbox profiles `$CONTAINER` (the page), `$FETCH`, `$WINDOW_CONTAINER`,
   `$DECODER`, `$CONVERTER`, `$SOUND_CONTAINER` (the sound process), `$IMPORT_ALLOWED` (the bookmark reader), `$VERIFIER`, `$TOR_CONTAINER` and `$TRMNL_CONTAINER`;
   then `sub contain`, which builds every contained start, `sub holds`, which tries each container at
   every start `[C2]`, and `sub inside`, which asks macOS whether a process is contained `[C3]`.
4. **One visit**, in order: `sub visit`, `sub address`, `sub record`, `sub find`, `sub fetch`,
   `sub reach`, `sub laid_out`, `sub keeper`, `sub contained`, `sub checked`.
5. **CAPABILITIES.md**, then each of the subs it names. It lists every system program `lzrprf` starts and the
   act that starts it.
6. **Updates**: `sub newer`, `sub release_signed`, `sub manifest_read`, `sub signature_holds`,
   `sub installed`, `sub install_run`; then VERIFY.md, which does the same checks by hand.
7. **`selftest`**: `%about` (one line for each run), `$hostile` (the program put in the closed
   application's place), `%lost` (the weakened copies of `lzrprf` it must catch).
8. **README.md**, "The conditions": each condition with the subs that hold it and how `selftest`
   probes it. Then docs/, where each file starts with a statement index.

## The trust boundary

```
 The person's macOS account: trusted. Everything here runs with its rights.
 |
 +-- lzrprf (outside every container)
 |     looks up names, makes the one connection to a site, writes the log, checks every line
 |     that crosses, runs the tool [C20] and the installer [C25] after the person's act
 |
 |     starts, each through /usr/bin/sandbox-exec (sub contain):
 |     +-- page       $CONTAINER          the closed application   deny by default, no network
 |     +-- fetch      $FETCH              /usr/bin/curl            one socket file to lzrprf's connection
 |     +-- window     $WINDOW_CONTAINER   /usr/bin/osascript       allow by default, no network of its own
 |     +-- decoder    $DECODER            /usr/bin/sips            one file in, one PNG out
 |     +-- converter  $CONVERTER          /usr/bin/avconvert       one stream in, one MP4 out
 |     +-- sound      $SOUND_CONTAINER    /usr/bin/osascript       the system's sound and nothing else
 |     +-- reader     $IMPORT_ALLOWED     /usr/bin/perl            reads named bookmark files only
 |     +-- verifier   $VERIFIER           /usr/bin/ssh-keygen      reads its work folder only
 |     +-- tor        $TOR_CONTAINER      arti                     its own folder and the network
 |     +-- terminal   $TRMNL_CONTAINER    core-lzrbrwsr-trmnl      its two pipes; no file, no network
 |   and the person's login shell on a pseudo-terminal, as the person, after a press of the terminal icon [C29]
 |
 +-- outside lzrprf's control: the macOS kernel and sandbox; the system's video decoder service
       (used by sips [C21] and by the window's player [C22]); the swap, caches and backups
```

What crosses, and who checks it:

| from | to | what | checked by |
| --- | --- | --- | --- |
| window | lzrprf | one line per act of the person (an address, a press, a choice) | lzrprf reads only lines of known forms |
| lzrprf | page | the fetched answer, fonts, style sheets, script permissions, after macOS says the process is contained | `[C3]` `[C13]` `[C14]` `[C26]` |
| page | lzrprf | a list of lines to draw; a page kept running asks for addresses | every line `[C9]`; every request `[C19]` |
| lzrprf | window | lines lzrprf checked, and its own words | `[C9]` |
| lzrprf | site | the fixed request bytes of `sub request` | `[C7]` |
| lzrprf | decoder, converter | a site's bytes the application handed back whole | `[C21]` `[C24]` |
| lzrprf | sound | the samples a page kept running made, and play and stop, after macOS says the process is contained | `[C3]` `[C12]`; the process answers each play `played ID yes` or `no` |
| reader, verifier | lzrprf | bookmark bytes; whether a signature holds | `[C15]` `[C25]` |

**The default home is the closed application's, not lzrprf's.** Its drawing (the words, shapes,
buttons and the minigame) is a scene compiled into the closed program, so lzrprf holds none of it,
and it runs only by the program's SHA-256 in the release file. The door lzrprf keeps, and all of it:

1. the release file says `home local` (`sub behind`), or no home is started;
2. the program is the file the release file names on its line `file`, by SHA-256: checked at the
   start (`sub paired`) and read again before the home's run as before every run (`sub contained`);
3. the home runs in the page container as a page kept running, at `https://lzrbrwsr.invalid/_home`,
   which is never fetched (`sub home_shown`); its first list must name no picture, style sheet or
   video (`sub home_arrived`), and every request it makes is refused (`sub live_fetched`);
4. its lines and layers are checked as every page's `[C9]` `[C18]`, and of the addresses it asks to
   follow only four fixed local words and LZRDFNDR's panel reach the window, within a second of a
   press handed to it; nothing is followed (`sub live_answered`).

The window keeps a picture of the first scene in its memory for a new tab, and draws the beam from a
pressed button to the bar or the new tab itself, as nothing of a page may draw over the bar.

## Limits set by lzrprf itself

Until release 82 every page, fetch, decoder, converter and reader container was started as
`/bin/sh -c '<ulimit lines> && exec /usr/bin/env -i <names> "$@"' sandbox-exec ...`: two programs
before `sandbox-exec`, about 15 ms of the start of a container, three containers a page. From release
83 `sub become` hands the limits to `sub limited`, which runs in the process forked for the container,
after `sub seal` closed every descriptor but three, and then that process becomes `sandbox-exec`
itself. What to check, and why it is as strong:

- The same kernel call with the same numbers. `ulimit` is the shell calling `setrlimit(2)`. `sub
  limited` calls it by its number (195, as the tries in `sub holds` call `mmap` by 197) for
  `RLIMIT_CPU` 30 s, `RLIMIT_FSIZE` (0 for the page and fetch containers), `RLIMIT_CORE` 0,
  `RLIMIT_NOFILE` 256 (or a lower hard limit already set, as before) and `RLIMIT_AS` a shell's size
  plus `$PAGE_ROOM`, last. Each call sets the soft and the hard limit together, so neither can be
  raised by the program. A process keeps its limits through `exec`, so `sandbox-exec` and the
  program it becomes start under them, as they did under the shell's.
- Fail closed. Any call that fails ends the forked process (`POSIX::_exit(127)`) before
  `sandbox-exec` starts; nothing of the program runs.
- The variables. `%ENV` is replaced whole by the names the container's limits list (the seal, the
  address, the run's kind; `TMPDIR` for the decoder and converter; none for `curl`), as `env -i` did.
  No shell runs, so no `PWD`, `SHLVL` or `_` was ever made.
- Memory. macOS refuses (`EINVAL`) an `RLIMIT_AS` below what the process holds already (measured
  2026-11-24 with 3 GiB reserved first). A fork of an lzrprf grown past a shell and 2 GiB therefore
  becomes `/usr/bin/perl -e $ROOM_SET` first, with the cleaned variables, which sets that one limit
  and becomes `sandbox-exec`; any other error starts nothing.
- One correction found on the way: the shell's `ulimit -f` counts 1024-byte blocks on this macOS,
  not 512, so the decoder and converter could write files of 32 and 192 MiB, not the 16 and 96 the
  text said. From release 83 they are 16 and 96 MiB, in bytes.
- The proof is unchanged in kind. The tries of every start (`sub holds`) start the page and decoder
  containers through `sub limited` and must see 3 GiB, a second process and the rest refused; the
  runs `lostmemory`, `lostmemoryprobe`, `lostfiles` and `lostsoft` take the memory limit, the
  open-file limit and the hard half of every limit out of `sub limited` in a copy, and must be
  noticed.
- Two containers keep a shell. The sound process (`sub sounding`, `$SOUND_LIMITS`: ten minutes of
  processor time) and the terminal's drawing (`sub trmnl_started`, `$TRMNL_LIMITS`: 16 open files,
  a shell and 64 MiB) have limits of their own, so a shell still sets them with `ulimit` and becomes
  `env -i`, as every container did before release 83.

## How lzrprf is built from its parts

The shipped file is one file, `lzrprf`, and its SHA-256 is pinned: the installer fetches it by commit and
sum, and `selftest` probes it. In git its source is the folder `src/`, one file a part, named
`NN-name.pl`. Each part is an exact slice of `lzrprf`, cut between two subs, and nothing is added
between two parts: joining them in the order of their names gives `lzrprf` byte for byte. `lzrprf`
itself stays in git beside them, as the file that ships.

To change lzrprf:

1. edit the part that holds what you change;
2. run `perl tools/join`, which writes `lzrprf` from `src/*.pl`;
3. run `perl selftest`. Among its checks, `perl tools/join --check` must say that `src/` joins to
   `lzrprf`, and the map of subs below must be what `perl tools/sub-map` prints (when a line moved,
   `perl tools/sub-map --write AUDIT.md` writes it again).

```
perl tools/join            # writes lzrprf from src/*.pl
perl tools/join --check    # exits 0 when src/*.pl join to lzrprf; otherwise names the first part and line that differ
```

The parts, in order:

| part | what it holds |
| --- | --- |
| `01-header.pl` | the commands lzrprf takes and the conditions `[C1]` to `[C27]`, up to the line before `use strict;` |
| `02-limits-and-state.pl` | the modules it uses, the start of the file, every limit and the state of one run |
| `03-containers.pl` | the sandbox profiles, `sub contain` and the subs that start a program, and the proof that the containers hold |
| `04-start.pl` | the start (`sub run`), an incognito window, a tab pulled out into a window of its own |
| `05-profiles.pl` | profiles |
| `06-behind.pl` | the process behind the window, and the pair of the application and lzrprf |
| `07-visit.pl` | one visit, the run of the application in the page container, the keeper, and what the application may write |
| `08-pictures.pl` | the pictures of a page, and the system's decoder and converter |
| `09-videos.pl` | videos and HLS streams, and which host is another site |
| `10-tabs.pl` | the size of the page, tabs, the cogwheel's menu, back and forward, search, the lock, redirects |
| `11-bookmarks.pl` | bookmarks, the window's kept frame, the game's best score, the order of a folder |
| `12-import.pl` | importing bookmarks: the reader's container and the reader |
| `13-sheets-and-reach.pl` | style sheets, what is said when no page came, the lookup of a name, and the one connection to a site |
| `14-tool.pl` | the application's tool |
| `15-tor.pl` | Tor |
| `16-blocklist.pl` | the list of addresses lzrprf never opens |
| `17-fetch.pl` | the request bytes, the fetch, the public internet, the fixed addresses |
| `18-licence-and-support.pl` | the support member licence, Ed25519, a support request |
| `19-updates.pl` | the release file, the look for a newer release, the welcome, the installer |
| `20-window-side.pl` | what lzrprf says to the window and hears from it |
| `21-live.pl` | pages kept running with their tabs, and their requests |
| `22-permits.pl` | script permissions |
| `23-filters.pl` | the filter lists |
| `24-live-input.pl` | what a page kept running is handed, and its answers |
| `24-sound.pl` | the sound process: its container, its text, what it is told and what it answers, a video's sound included |
| `24-trmnl-window.pl` | the terminal tab's part of the window's text (`sub window_trmnl_text`): the wheel, a drag, your copy and your paste `[C29]` |
| `24-trmnl.pl` | the terminal tab (LZRTRMNL): the shell on a pseudo-terminal, its drawing container, keys in and laid rows out, scrollback, selection, copy, paste and titles `[C29]` |
| `25-ask-and-address.pl` | a question in the strip, and what is fetched for a text that was typed |
| `25-cht.pl` | LZRCHT `[C32]`: its three roles started in their containers, the drawing role's pages and copy checked, the keeper's word passed on, and a connector's one connection opened and held by lzrprf to an address its platform publishes |
| `26-log.pl` | the log, and what is kept |
| `27-proof.pl` | the proof for this computer (`sub mark`, `sub proven`) and the lookup of a name |
| `28-window-sound.pl` | the window's part of a video's sound: `sub window_sound_text`, joined after the window's text when it starts |
| `28-window.pl` | the window: `sub window_text`, the text the system's osascript runs |
| `29-commands.pl` | the commands read from the command line, each sent to its sub |

`28-window.pl` is one part of about 5,000 lines because it is one sub: the window's text is one block
of text inside `sub window_text`, and no part is cut through a sub. The terminal's part of that text is
`sub window_trmnl_text` in `24-trmnl-window.pl`, which `sub run` joins after `sub window_text`.

## The map of subs

The docs cite subs by name only, so a line that moves does not make them wrong. The map with line
numbers is generated:

```
perl tools/sub-map                    # PART <tab> LINE <tab> NAME <tab> MARKS, for every part and every top-level subroutine in it
perl tools/sub-map --joined           # the same with a fifth column: the line in lzrprf itself
perl tools/sub-map --count            # how many subs and parts, and how many of the subs carry a mark
perl tools/sub-map --write AUDIT.md   # writes the map below again
```

LINE is the line in the part. Each part has a row of its own at its line 1, named `-`, with the marks
written in it before its first sub. MARKS lists the condition marks written from one top-level
subroutine to the next, or to the end of its part. Text between two subs that is not part of the first
(a constant, a sandbox profile) is counted with the one above it. So every mark in `lzrprf` stands on
one row: the row of the part and the sub it is written in.

The map below is every part of `lzrprf` and every sub in it, in the order of the file. Line numbers
are counted inside each part, so a change to one part moves no line of the map in any other part.
`selftest` compares this map with what `perl tools/sub-map` prints for the parts in `src/`, and fails
naming the first part or sub that is missing, is not in `lzrprf`, or stands at another line. A change
that moves lines of a part is followed by `perl tools/sub-map --write AUDIT.md`.

<!-- sub-map begin -->
```
01-header.pl	1	-	C16 C17 C27 C20 C1 C2 C3 C21 C4 C22 C19 C5 C6 C7 C8 C9 C10 C11 C12 C26 C13 C14 C30 C15 C18 C24 C23 C25 C28 C29 C31 C32
02-limits-and-state.pl	1	-	-
02-limits-and-state.pl	18	remove_tree	-
02-limits-and-state.pl	19	unblocked	C20 C16 C17
02-limits-and-state.pl	32	kept_in	-
02-limits-and-state.pl	36	shared	C16 C19 C18 C12 C22 C21 C24 C30 C23 C11 C29 C32 C26
02-limits-and-state.pl	212	sandbox_says	C26 C27 C4
02-limits-and-state.pl	263	permit_class	C26
02-limits-and-state.pl	264	permit_kinds	C26
02-limits-and-state.pl	294	fresh_tab	C19
02-limits-and-state.pl	310	now	C19 C6 C8 C14 C30
02-limits-and-state.pl	329	timed	C28
03-containers.pl	1	-	C1 C28 C21 C3 C24 C12
03-containers.pl	185	shell_held	-
03-containers.pl	190	shell_measured	-
03-containers.pl	214	limited	C15 C22 C20 C10
03-containers.pl	339	contain	C21
03-containers.pl	353	decoding	C24
03-containers.pl	365	converting	-
03-containers.pl	376	seal	-
03-containers.pl	383	the_program	C1
03-containers.pl	384	become	-
03-containers.pl	404	said	-
03-containers.pl	437	said_all	-
03-containers.pl	468	said_started	-
03-containers.pl	477	said_read	-
03-containers.pl	497	ended	C2
03-containers.pl	545	holds	C21 C3
03-containers.pl	588	decoder_named	C3
03-containers.pl	635	witnessed	-
03-containers.pl	653	inside	-
03-containers.pl	675	witness_lost	-
03-containers.pl	684	named_asked	C21
04-start.pl	1	-	-
04-start.pl	4	run	C16 C17 C29
04-start.pl	43	runs_swept	C16
04-start.pl	61	temp_folder	-
04-start.pl	70	swept	C16
04-start.pl	81	removed	-
04-start.pl	87	incognito_begun	-
04-start.pl	113	incognito_opened	-
04-start.pl	120	window_opened	-
04-start.pl	128	help_opened	-
04-start.pl	137	apart	-
04-start.pl	168	tab_out	C29 C32
04-start.pl	187	pulled_command	-
04-start.pl	193	opened_with	-
05-profiles.pl	1	-	-
05-profiles.pl	35	profiles_root	-
05-profiles.pl	36	profiles_folder	-
05-profiles.pl	41	profile_folder	-
05-profiles.pl	51	profile_ids	-
05-profiles.pl	58	profile_fit	-
05-profiles.pl	71	profile_name	-
05-profiles.pl	79	profile_open	-
05-profiles.pl	85	profiles_told	-
05-profiles.pl	94	profiles_refused	-
05-profiles.pl	96	profiles_locked	-
05-profiles.pl	103	profiles_swept	-
05-profiles.pl	113	profile_taken	-
05-profiles.pl	118	profile_entered	C16
05-profiles.pl	127	profile_held	-
05-profiles.pl	135	first_held	-
05-profiles.pl	137	profile_command	-
05-profiles.pl	139	profile_window	-
05-profiles.pl	150	profile_new	-
05-profiles.pl	183	profile_renamed	-
05-profiles.pl	208	profile_removed	-
05-profiles.pl	266	sso_providers	-
05-profiles.pl	272	sso_on	C16 C17
05-profiles.pl	273	sso_of	-
05-profiles.pl	280	sso_file	-
05-profiles.pl	281	sso_kept	-
05-profiles.pl	295	sso_state	-
05-profiles.pl	296	sso_cookies	-
05-profiles.pl	300	sso_cookie	-
05-profiles.pl	312	sso_heard	-
05-profiles.pl	359	sso_date	-
05-profiles.pl	367	sso_written	-
05-profiles.pl	378	sso_told	-
05-profiles.pl	383	sso_connect	C4
05-profiles.pl	400	sso_remove	-
06-behind.pl	1	-	-
06-behind.pl	4	started	-
06-behind.pl	9	named	-
06-behind.pl	17	behind	C16 C17 C10 C2 C23 C11 C12 C21 C4 C5 C31 C20 C7 C26 C27 C22 C29 C18 C15
06-behind.pl	173	unheard	-
06-behind.pl	217	paired	-
06-behind.pl	232	unnamed	-
06-behind.pl	239	leave	C17 C7 C29 C32 C12 C16
06-behind.pl	257	closed	-
07-visit-beside.pl	1	-	C14 C17
07-visit-beside.pl	23	beside_wanted	-
07-visit-beside.pl	25	beside_fds	-
07-visit-beside.pl	29	beside_dropped	-
07-visit-beside.pl	38	beside_sheets	-
07-visit-beside.pl	50	beside_taken	-
07-visit-beside.pl	60	beside_begun	-
07-visit-beside.pl	75	beside_second	C14 C23 C27 C5 C30 C19
07-visit-beside.pl	98	run_read	C19 C26 C28
07-visit.pl	1	-	-
07-visit.pl	4	visit	C19 C29 C32 C17 C23 C26 C5 C28 C8 C7 C4 C14 C30
07-visit.pl	245	laid_out	C28 C9
07-visit.pl	261	outrun	-
07-visit.pl	276	faces	C13
07-visit.pl	312	contained	C28 C20 C13 C14 C26 C7 C3
07-visit.pl	368	page_started	C1 C3
07-visit.pl	391	spare_for	-
07-visit.pl	399	spare_taken	-
07-visit.pl	410	spare_dropped	-
07-visit.pl	418	spare_work	-
07-visit.pl	425	idle_taken	C1
07-visit.pl	437	run_seal	-
07-visit.pl	463	keeper	C9
07-visit.pl	551	unhung	-
07-visit.pl	559	parted	-
07-visit.pl	568	checked	C30 C9 C22 C14
07-visit.pl	671	laid	-
07-visit.pl	684	laid_run	C4
07-visit.pl	734	redirect_noted	C4
07-visit.pl	746	redirect_answered	-
07-visit.pl	753	redirects_listed	C4
07-visit.pl	766	redirects_told	C4 C23
07-visit.pl	768	redirects_decide	C4
08-pictures.pl	1	-	C7 C5 C17 C8 C22
08-pictures.pl	46	pictures_state	C28
08-pictures.pl	57	pictures_begun	C23 C28 C27 C4 C5 C8 C6 C7 C1 C3 C21
08-pictures.pl	114	pictures_heard	C9
08-pictures.pl	137	pictures_ended	C21 C17
08-pictures.pl	152	pictures_judged	-
08-pictures.pl	160	pictures_ahead	-
08-pictures.pl	174	pictures_pumped	-
08-pictures.pl	188	pictures_waited	-
08-pictures.pl	201	pictures_so_far	-
08-pictures.pl	208	pictures_before	-
08-pictures.pl	224	pictures_dropped	-
08-pictures.pl	231	pictured	C28
08-pictures.pl	288	picture_named	-
08-pictures.pl	312	picture_one	-
08-pictures.pl	319	picture_like	-
08-pictures.pl	324	picture_same	-
08-pictures.pl	331	named_owed	-
08-pictures.pl	344	named_again	-
08-pictures.pl	358	fit_crop	C21
08-pictures.pl	395	system_decoded	C21 C24
08-pictures.pl	434	plain_read	C24
08-pictures.pl	454	ts_sounds	C24 C21
08-pictures.pl	506	system_converted	C21
08-pictures.pl	532	stated_size	C21
08-pictures.pl	563	decoders_removed	C24
09-videos.pl	1	-	C22
09-videos.pl	28	videoed	C23 C27 C5 C4 C28 C8 C6 C7 C22 C24
09-videos.pl	162	hls_fetched	C5 C6 C7 C22 C23 C28
09-videos.pl	266	hls_lines	-
09-videos.pl	284	hls_attributes	C22
09-videos.pl	299	hls_locked	C22
09-videos.pl	316	hls_address	-
09-videos.pl	335	hls_whole	C23
09-videos.pl	348	hls_listed	C12 C22
09-videos.pl	361	hls_away	C23
09-videos.pl	378	video_stop	C4
09-videos.pl	407	named_in	C4
09-videos.pl	417	elsewhere	C4
09-videos.pl	427	under	-
10-tabs.pl	1	-	-
10-tabs.pl	11	viewing	C32 C29 C18 C19
10-tabs.pl	40	relaid	C22
10-tabs.pl	79	tabbed	C32 C29 C4
10-tabs.pl	107	closed_kept	-
10-tabs.pl	118	tab_reopened	C4
10-tabs.pl	135	lists_bounded	-
10-tabs.pl	144	tab_moved	-
10-tabs.pl	160	tab_shown	C29 C32 C18 C12 C7
10-tabs.pl	195	menu	C7 C16 C4
10-tabs.pl	254	nav_told	-
10-tabs.pl	259	navigated	C4
10-tabs.pl	277	engine_fit	-
10-tabs.pl	283	engine	-
10-tabs.pl	293	search_set	C16
10-tabs.pl	304	typed	C23
10-tabs.pl	319	secured	-
10-tabs.pl	341	home	-
10-tabs.pl	353	go	C7
10-tabs.pl	378	redirected	-
10-tabs.pl	386	unfit	-
10-tabs.pl	397	resolved	-
10-tabs.pl	422	home_shown	C29 C32
10-tabs.pl	453	home_arrived	C19
11-bookmarks.pl	1	-	C4
11-bookmarks.pl	19	marks_root	C16
11-bookmarks.pl	28	marks_into_bar	C16
11-bookmarks.pl	43	owned_folder	-
11-bookmarks.pl	45	marks_read	-
11-bookmarks.pl	51	marks_walk	-
11-bookmarks.pl	72	plain_name	-
11-bookmarks.pl	85	marks_told	-
11-bookmarks.pl	92	mark_written	-
11-bookmarks.pl	101	mark_saved	C16 C23
11-bookmarks.pl	129	mark_removed	C16
11-bookmarks.pl	141	mark_moved	C16
11-bookmarks.pl	155	frame_kept	-
11-bookmarks.pl	163	frame_said	-
11-bookmarks.pl	171	checked_kept	-
11-bookmarks.pl	179	checked_said	-
11-bookmarks.pl	189	marks_bar	-
11-bookmarks.pl	198	pictures_elsewhere	C16
11-bookmarks.pl	213	game_helper	-
11-bookmarks.pl	223	game_helper_set	-
11-bookmarks.pl	252	order_of	-
11-bookmarks.pl	262	order_shown	-
11-bookmarks.pl	269	order_set	-
11-bookmarks.pl	283	mark_file	-
12-import.pl	1	-	C15 C4
12-import.pl	127	import_home	-
12-import.pl	129	import_base	-
12-import.pl	131	import_reader	-
12-import.pl	168	import_read	-
12-import.pl	181	import_node	-
12-import.pl	189	import_json	-
12-import.pl	204	import_json_member	-
12-import.pl	224	lz4_block	-
12-import.pl	250	plist_binary	-
12-import.pl	306	html_text	-
12-import.pl	313	import_html	-
12-import.pl	350	import_chromium	-
12-import.pl	364	import_tops	-
12-import.pl	367	import_firefox	-
12-import.pl	385	import_safari	-
12-import.pl	404	import_profiles_of	-
12-import.pl	462	import_profile_name	-
12-import.pl	474	import_why	-
12-import.pl	476	import_files	-
12-import.pl	493	import_sources	C16
12-import.pl	508	import_profiles	C16
12-import.pl	522	import_refused	-
12-import.pl	524	import_kept_out	-
12-import.pl	529	import_kept	-
12-import.pl	538	import_cancelled	-
12-import.pl	540	import_unshown	-
12-import.pl	545	import_allowed	-
12-import.pl	559	import_path	C16
12-import.pl	569	import_plan	-
12-import.pl	616	import_go	C16
13-sheets-and-reach.pl	1	-	C14
13-sheets-and-reach.pl	10	sheeted	C23 C27 C5 C6 C7 C30
13-sheets-and-reach.pl	57	fonted	C23 C27 C5 C6 C7
13-sheets-and-reach.pl	95	pixels	-
13-sheets-and-reach.pl	135	fault	C4
13-sheets-and-reach.pl	148	fault_said	-
13-sheets-and-reach.pl	149	asked_words	C19
13-sheets-and-reach.pl	165	numbered	-
13-sheets-and-reach.pl	174	find_ahead	C23 C17
13-sheets-and-reach.pl	200	find_numbers	-
13-sheets-and-reach.pl	212	find_dropped	-
13-sheets-and-reach.pl	223	find	C23 C17
13-sheets-and-reach.pl	267	route_asked	-
13-sheets-and-reach.pl	268	route	-
13-sheets-and-reach.pl	273	route_of	C6
13-sheets-and-reach.pl	292	reach	C17 C6
14-tool.pl	1	-	C20
14-tool.pl	35	tool_stand	-
14-tool.pl	36	tool_asked	-
14-tool.pl	43	tool_ran	C20
14-tool.pl	48	tool_plain	-
14-tool.pl	57	tool_text	C20
14-tool.pl	64	tool_places	-
14-tool.pl	68	tool_services	-
14-tool.pl	77	tool_file	-
14-tool.pl	100	tool_signed	-
14-tool.pl	123	tool_kept	C20
14-tool.pl	127	tool_keep	C20
14-tool.pl	141	tool_look	C20
14-tool.pl	210	tool_may	C20
14-tool.pl	236	tool_checked	-
14-tool.pl	277	tool_none	-
14-tool.pl	283	tool_shown	C1 C3 C20
14-tool.pl	304	tool_done	C20
14-tool.pl	336	tool_procs	-
14-tool.pl	357	tool_man	C20
14-tool.pl	381	tool_notes	C20
14-tool.pl	398	tool_note	-
14-tool.pl	413	tool_stop	C20
14-tool.pl	426	tool_off	C20
14-tool.pl	436	tool_quiet	C20
14-tool.pl	446	tool_wake	C20
14-tool.pl	465	tool_due	-
14-tool.pl	471	tool_watch	-
15-lzr-a-commands.pl	1	-	C20
15-lzr-a-commands.pl	126	lzr_main	-
15-lzr-a-commands.pl	148	lzr_parsed	-
15-lzr-a-commands.pl	178	lzr_named	-
15-lzr-a-commands.pl	187	lzr_id_like	-
15-lzr-a-commands.pl	189	lzr_found	-
15-lzr-a-commands.pl	207	lzr_hint	-
15-lzr-a-commands.pl	214	lzr_near	-
15-lzr-a-commands.pl	226	lzr_distance	-
15-lzr-a-commands.pl	241	lzr_wrong	-
15-lzr-a-commands.pl	247	lzr_said	-
15-lzr-a-commands.pl	253	lzr_paint	-
15-lzr-a-commands.pl	255	lzr_wrapped	-
15-lzr-a-commands.pl	266	lzr_help	-
15-lzr-a-commands.pl	286	lzr_version	C20
15-lzr-a-commands.pl	292	lzr_bin	-
15-lzr-b-processes.pl	1	-	C20
15-lzr-b-processes.pl	32	lzr_id	-
15-lzr-b-processes.pl	39	lzr_look	-
15-lzr-b-processes.pl	56	lzr_deactivated	C20
15-lzr-b-processes.pl	62	lzr_keep_deactivated	C20
15-lzr-b-processes.pl	72	lzr_contained	C20
15-lzr-b-processes.pl	88	lzr_write_contained	C20
15-lzr-b-processes.pl	99	lzr_alive	-
15-lzr-b-processes.pl	105	lzr_named_all	-
15-lzr-b-processes.pl	114	lzr_which	-
15-lzr-b-processes.pl	128	lzr_running	-
15-lzr-b-processes.pl	133	lzr_why_not	C20
15-lzr-b-processes.pl	144	lzr_program_why_not	C20
15-lzr-b-processes.pl	153	lzr_jobs_of	C20
15-lzr-b-processes.pl	177	lzr_asked	-
15-lzr-b-processes.pl	188	lzr_seen	C20
15-lzr-b-processes.pl	202	lzr_processes	-
15-lzr-b-processes.pl	221	lzr_kib	-
15-lzr-b-processes.pl	222	lzr_json	-
15-lzr-b-processes.pl	223	lzr_when	-
15-lzr-b-processes.pl	224	lzr_state_of	-
15-lzr-b-processes.pl	226	lzr_list	-
15-lzr-b-processes.pl	246	lzr_all	-
15-lzr-b-processes.pl	271	lzr_columns	-
15-lzr-b-processes.pl	273	lzr_pid_of	-
15-lzr-b-processes.pl	284	lzr_sample	C20
15-lzr-b-processes.pl	297	lzr_seconds	-
15-lzr-b-processes.pl	298	lzr_footprint	C20
15-lzr-b-processes.pl	306	lzr_kill	C20
15-lzr-b-processes.pl	331	lzr_deactivate	C20
15-lzr-b-processes.pl	353	lzr_reactivate	C20
15-lzr-b-processes.pl	375	lzr_due	-
15-lzr-b-processes.pl	376	lzr_watch	-
15-lzr-b-processes.pl	385	lzr_argv	C20
15-lzr-b-processes.pl	398	lzr_contain	C20
15-lzr-b-processes.pl	432	lzr_keeper	C20
15-lzr-b-processes.pl	475	lzr_keeper_is	-
15-lzr-b-processes.pl	477	lzr_release	C20
15-lzr-c-analyze.pl	1	-	C20
15-lzr-c-analyze.pl	23	lzr_size	-
15-lzr-c-analyze.pl	31	lzr_ceiling	-
15-lzr-c-analyze.pl	33	lzr_about	C20
15-lzr-c-analyze.pl	55	lzr_analyze	C20
15-lzr-c-analyze.pl	128	lzr_closing	-
15-lzr-c-analyze.pl	143	lzr_frame	-
15-lzr-c-analyze.pl	168	lzr_graph	-
15-tor.pl	1	-	-
15-tor.pl	41	tor_client	-
15-tor.pl	45	tor_where	C23
15-tor.pl	46	tor_on	C17
15-tor.pl	112	tor_failed	-
15-tor.pl	120	tor_off	C17
15-tor.pl	138	tor_reach	C23 C17
15-tor.pl	181	tor_phase	C17
15-tor.pl	189	tor_window_opened	C17
15-tor.pl	197	tor_session_on	C17
15-tor.pl	211	tor_sealed	C17
15-tor.pl	219	tor_session_asked	C17
15-tor.pl	225	tor_session_tables	C17
15-tor.pl	230	tor_session_files	C17
15-tor.pl	235	tor_told	C17
15-tor.pl	237	tor_session_end	C17
16-blocklist.pl	1	-	C23
16-blocklist.pl	25	list_read	C23
16-blocklist.pl	70	list_has	C23
16-blocklist.pl	101	url_form	C23
16-blocklist.pl	145	listed_said	C17
16-blocklist.pl	146	listed	-
16-blocklist.pl	157	listed_now	C23
16-blocklist.pl	185	unlisted	-
16-blocklist.pl	194	refused	C23
16-blocklist.pl	204	barred	C23 C28
16-blocklist.pl	225	flag_of	C28
16-blocklist.pl	231	flagged_by	C28
16-blocklist.pl	244	shield_ahead	C28
16-blocklist.pl	266	shield_heard	C28
16-blocklist.pl	287	shield_asked	C28
16-blocklist.pl	308	shield_said	C28
16-blocklist.pl	318	shield_why	C28
16-blocklist.pl	323	flag_shown	C28
16-blocklist.pl	338	flag_door	C28
16-blocklist.pl	345	flag_report	C28
16-tnnl.pl	1	-	-
16-tnnl.pl	28	tnnl_on	-
16-tnnl.pl	31	tnnl_read	-
16-tnnl.pl	53	tnnl_asked	-
16-tnnl.pl	56	tnnl_file	C5
16-tnnl.pl	74	tnnl_interface	-
16-tnnl.pl	91	tnnl_look	C5
16-tnnl.pl	102	tnnl_forget	-
16-tnnl.pl	105	tnnl_relay	-
16-tnnl.pl	126	tnnl_relay_end	-
16-tnnl.pl	134	tnnl_serve	-
16-tnnl.pl	158	tnnl_bound	-
16-tnnl.pl	169	tnnl_carried	-
16-tnnl.pl	229	tnnl_due	-
16-tnnl.pl	230	tnnl_watch	-
16-tnnl.pl	242	tnnl_ready	-
16-tnnl.pl	252	tnnl_lines	-
16-tnnl.pl	253	tnnl_container	-
16-tnnl.pl	259	tnnl_said	-
16-tnnl.pl	270	tnnl_tried	-
16-tnnl.pl	313	tnnl_dialed	-
17-fetch.pl	1	-	C7
17-fetch.pl	16	request	C7
17-fetch.pl	46	identity_on	C17
17-fetch.pl	47	identity_word	-
17-fetch.pl	48	identity_asked	C1 C3
17-fetch.pl	59	identity_of_host	-
17-fetch.pl	65	identity_site	-
17-fetch.pl	75	identity_headers	C7 C19
17-fetch.pl	102	fetch	C7 C23 C28 C19 C3
17-fetch.pl	227	curl_started	C3
17-fetch.pl	253	curl_for	-
17-fetch.pl	266	curl_taken	-
17-fetch.pl	275	curl_ended	-
17-fetch.pl	283	alive	-
17-fetch.pl	285	public	-
17-fetch.pl	298	public4	C4
17-fetch.pl	316	fixed	C23 C5
17-jar.pl	1	-	C7 C12 C16 C17 C26
17-jar.pl	40	jar_kept	C16 C17
17-jar.pl	41	jar_directory	-
17-jar.pl	42	jar_file	-
17-jar.pl	43	jar_skips	-
17-jar.pl	51	jar_encoded	-
17-jar.pl	53	jar_started	C1 C3
17-jar.pl	85	jar_locked	-
17-jar.pl	92	jar_key	-
17-jar.pl	107	jar_stamp	-
17-jar.pl	109	jar_merged	-
17-jar.pl	125	jar_save	-
17-jar.pl	148	jar_wrote	-
17-jar.pl	163	jar_line	-
17-jar.pl	180	jar_said	-
17-jar.pl	187	jar_lost	-
17-jar.pl	198	jar_end	-
17-jar.pl	204	jar_context	-
17-jar.pl	210	jar_cookie	-
17-jar.pl	219	jar_heard	-
17-jar.pl	232	jar_kept_write	C26
17-jar.pl	247	jar_frame	-
17-jar.pl	265	jar_clear	-
17-jar.pl	274	jar_forget	-
17-prefetch.pl	1	-	C19
17-prefetch.pl	26	prefetch_end	-
17-prefetch.pl	41	prefetch_begin	C17 C26 C14 C23
17-prefetch.pl	86	prefetch_later	C27 C28
17-prefetch.pl	98	prefetch_go	C26 C7 C28 C27 C8
17-prefetch.pl	126	prefetch_soon	C19 C26 C27 C28 C7 C8
17-prefetch.pl	153	prefetch_pump	C5 C7
17-prefetch.pl	173	prefetch_select	-
17-prefetch.pl	182	prefetch_heard	-
17-prefetch.pl	202	prefetch_made	C28 C6 C7
17-prefetch.pl	246	prefetch_numbers	-
17-prefetch.pl	262	prefetch_ended	-
17-prefetch.pl	269	prefetch_asked	C19
17-prefetch.pl	271	prefetch_keep	C17 C7
17-prefetch.pl	281	prefetch_take	C7
17-prefetch.pl	322	together_said	C6 C7
17-prefetch.pl	330	together_started	-
17-prefetch.pl	348	together_read	-
17-prefetch.pl	357	fetched_together	-
17-prefetch.pl	393	fetchers_for	-
17-prefetch.pl	425	fetcher_taken	-
17-prefetch.pl	439	fetchers_dropped	C14 C30 C5
17-prefetch.pl	454	ahead_key	-
17-prefetch.pl	456	ahead_begin	C5
17-prefetch.pl	473	ahead_sheets	C14 C23 C27
17-prefetch.pl	496	ahead_fonts	C30 C23 C27
18-licence-and-support.pl	1	-	C16
18-licence-and-support.pl	19	licence_key	-
18-licence-and-support.pl	27	licence_read	-
18-licence-and-support.pl	38	licence_written	-
18-licence-and-support.pl	39	licence_month	-
18-licence-and-support.pl	41	licence_checked	-
18-licence-and-support.pl	55	signed	-
18-licence-and-support.pl	104	licence_kept	-
18-licence-and-support.pl	114	licence_told	-
18-licence-and-support.pl	115	licence_refused	-
18-licence-and-support.pl	117	licence_set	C16
18-licence-and-support.pl	132	licence_removed	C16 C7 C4
18-licence-and-support.pl	167	support_address	C16
18-licence-and-support.pl	175	support_kept	-
18-licence-and-support.pl	176	support_told	-
18-licence-and-support.pl	177	support_failed	-
18-licence-and-support.pl	179	support_words	-
18-licence-and-support.pl	190	support_picture	-
18-licence-and-support.pl	198	support_answer	-
18-licence-and-support.pl	206	support_problem	-
18-licence-and-support.pl	215	support_sent	C16
18-licence-and-support.pl	245	support_read	C16
18-licence-and-support.pl	270	support_forgot	C16
19-updates.pl	1	-	-
19-updates.pl	9	release_file	-
19-updates.pl	10	release_lines	-
19-updates.pl	12	beside	C25
19-updates.pl	77	release_key	-
19-updates.pl	85	approval_keys	-
19-updates.pl	94	approval_key_current	C25
19-updates.pl	102	manifest_read	C25
19-updates.pl	126	signature_holds	C25
19-updates.pl	133	signature_checked	C25
19-updates.pl	155	release_signed	C25
19-updates.pl	185	newer	C16
19-updates.pl	214	newer_looked	C25
19-updates.pl	267	welcome	-
19-updates.pl	284	welcomed	C5 C6 C3
19-updates.pl	331	installed	C25
19-updates.pl	358	install_run	C25 C5
19-updates.pl	462	install_drained	-
19-updates.pl	495	install_guarded	-
19-updates.pl	510	restarted	C5
19-updates.pl	542	install_line	-
19-updates.pl	560	install_end	-
19-updates.pl	573	body_of	-
20-window-side.pl	1	-	C29
20-window-side.pl	14	window	C12
20-window-side.pl	24	strip_back	-
20-window-side.pl	28	busy	-
20-window-side.pl	29	idle	-
20-window-side.pl	36	aside	-
20-window-side.pl	44	noted	C23
20-window-side.pl	45	said_noted	-
20-window-side.pl	57	stated	-
20-window-side.pl	65	hear	C12 C29 C32 C19
20-window-side.pl	120	window_changed	-
21-kept-app.pl	1	-	C32
21-kept-app.pl	11	kept_app_discord	-
21-kept-app.pl	19	kept_app_valid	-
21-kept-app.pl	27	kept_app_budget	-
21-kept-app.pl	40	kept_app_folder	-
21-kept-app.pl	55	kept_app_jar	-
21-kept-app.pl	66	kept_app_fetched	-
21-kept-app.pl	77	kept_app_response	-
21-kept-app.pl	100	kept_app_open_tab	-
21-kept-app.pl	120	kept_app_visit	-
21-link.pl	1	-	C31
21-link.pl	49	link_folder	-
21-link.pl	50	link_state	C31
21-link.pl	68	link_on	-
21-link.pl	69	link_random	-
21-link.pl	71	link_menu	C31
21-link.pl	90	link_off	C31
21-link.pl	102	link_told	C31
21-link.pl	105	link_url	C31
21-link.pl	114	link_tokenish	-
21-link.pl	115	link_words	C31
21-link.pl	127	link_value	-
21-link.pl	128	link_stamp	-
21-link.pl	129	link_line	C31
21-link.pl	149	link_wrap	-
21-link.pl	177	link_around	C31
21-link.pl	197	link_due	-
21-link.pl	198	link_watch	C31
21-link.pl	234	link_plain	C31
21-link.pl	235	link_local	C31
21-link.pl	248	link_reaped	C31
21-link.pl	261	link_checked	C31
21-link.pl	280	link_command	C31
21-link.pl	363	link_drew	C31
21-link.pl	369	link_shot	C31
21-live.pl	1	-	-
21-live.pl	8	live_of	-
21-live.pl	10	live_kept	C18
21-live.pl	22	live_dropped	-
21-live.pl	28	live_told	C29
21-live.pl	36	live_end	-
21-live.pl	67	live_read	-
21-live.pl	80	live_due	C19
21-live.pl	92	live_turn	C18 C19 C26 C5 C17 C6 C7
21-live.pl	150	live_asked	C19 C26
21-live.pl	184	live_early	C19
21-live.pl	204	live_fetched	C19 C26 C7 C27 C23 C5 C28 C17 C8 C6
21-live.pl	309	live_parts	C19
21-live.pl	328	unchunked	-
21-live.pl	343	live_replied	C19
21-live.pl	348	live_sent	C19
21-websocket.pl	1	-	-
21-websocket.pl	4	ws_asked	-
21-websocket.pl	26	ws_request	-
21-websocket.pl	40	ws_frame	-
21-websocket.pl	51	ws_read_frame	-
21-websocket.pl	75	ws_valid_text	-
21-websocket.pl	81	ws_endpoint	-
21-websocket.pl	94	ws_open	-
21-websocket.pl	129	ws_upgrade	-
21-websocket.pl	152	ws_reply	-
21-websocket.pl	162	ws_close_socket	-
21-websocket.pl	174	ws_queue_frame	-
21-websocket.pl	183	ws_page_frame	-
21-websocket.pl	199	ws_frames_heard	-
21-websocket.pl	235	ws_pump	-
21-websocket.pl	245	ws_step	-
21-websocket.pl	281	ws_end	-
22-essential-web.pl	1	-	-
22-essential-web.pl	17	essential_web_count	-
22-essential-web.pl	18	essential_web_clear	-
22-essential-web.pl	20	website_path	-
22-essential-web.pl	27	essential_web_redirect	-
22-essential-web.pl	39	essential_web_script	-
22-essential-web.pl	53	essential_web_settings	-
22-essential-web.pl	71	essential_web_choice	-
22-essential-web.pl	77	essential_web_told	-
22-essential-web.pl	88	essential_web_save	-
22-essential-web.pl	123	essential_web_site	-
22-essential-web.pl	129	essential_web_answer	-
22-essential-web.pl	140	web_question	-
22-essential-web.pl	153	essential_test_text	-
22-permits.pl	1	-	C26
22-permits.pl	43	permit_rules	C26
22-permits.pl	65	permit_written	C26
22-permits.pl	76	permit_stored	C26
22-permits.pl	91	permit_covers	C26
22-permits.pl	97	permit_site	C26
22-permits.pl	106	permit_signin	C26
22-permits.pl	115	permit_password	C26
22-permits.pl	122	permit_seen	C26
22-permits.pl	130	permit_info	C26
22-permits.pl	139	permit_tracker	C26
22-permits.pl	147	permit_named	C26
22-permits.pl	156	permit_part	C26
22-permits.pl	172	permit_decision	C26
22-permits.pl	186	sites_told	C26
22-permits.pl	192	sites_listed	C26
22-permits.pl	217	permit_layers	C26
22-permits.pl	235	permit_layers_kept	C26
22-permits.pl	264	curated	C26
22-permits.pl	295	curated_read	C26
22-permits.pl	332	curated_rule	C26
22-permits.pl	369	curated_on	C26
22-permits.pl	376	permit_curated	C26
22-permits.pl	387	permit_refused	C26
22-permits.pl	394	permit_essential_id	-
22-permits.pl	403	permit_decided	C26
22-permits.pl	423	permit_queued	C26
22-permits.pl	440	permit_page	C26
22-permits.pl	478	permit_parts	C26
22-permits.pl	494	permit_unread	-
22-permits.pl	502	permit_read	-
22-permits.pl	511	permit_stripped	C26
22-permits.pl	526	permit_body	C26
22-permits.pl	565	permit_tag	C26
22-permits.pl	579	permit_scripted	C26
22-permits.pl	589	live_permitted	C26
22-permits.pl	605	permit_visited	C26
22-permits.pl	616	permits_asked	C26
22-permits.pl	651	permit_button	C26
22-permits.pl	659	permit_answered	C26
22-permits.pl	716	permits_later	C26
22-permits.pl	721	scripts_set	C26 C4
22-permits.pl	745	scripts_layer	C26 C4
22-permits.pl	763	scripts_told	C26
22-sends.pl	1	-	-
22-sends.pl	7	send_keys	-
22-sends.pl	11	sends_told	-
22-sends.pl	20	sends_decide	-
22-sends.pl	34	send_question	-
22-sends.pl	52	sends_count	-
22-sends.pl	53	sends_clear	-
22-website-scripts.pl	1	-	-
22-website-scripts.pl	3	sites_decide	C26 C4
22-website-scripts.pl	37	permit_essentials_saved	-
23-filters.pl	1	-	C27 C23 C26
23-filters.pl	34	filters	C27
23-filters.pl	67	filter_empty	C27
23-filters.pl	69	beside_read	C25
23-filters.pl	81	filter_list_read	C27
23-filters.pl	112	filter_line	C27
23-filters.pl	145	filter_split	C27
23-filters.pl	147	filter_token	C27
23-filters.pl	163	filter_rule	C27
23-filters.pl	193	filter_party	C27
23-filters.pl	195	filter_up	C27
23-filters.pl	197	filtered	C27
23-filters.pl	225	filter_named	C27
23-filters.pl	227	filter_said	C27
23-filters.pl	244	filter_layers	C27
23-filters.pl	262	filter_layers_kept	C27
23-filters.pl	274	filters_set	C27 C4
23-filters.pl	286	filter_changed	C27
23-filters.pl	313	filters_told	C27
23-filters.pl	326	filter_skipped	C27
23-filters.pl	328	filters_dir	C27
24-inspect.pl	1	-	C18
24-inspect.pl	5	inspect_input	-
24-inspect.pl	19	inspect_answer	-
24-live-input.pl	1	-	C12
24-live-input.pl	39	live_input	C18 C32 C29 C12
24-live-input.pl	76	live_wrote	C18
24-live-input.pl	88	live_flushed	C18
24-live-input.pl	96	live_stopped	C18
24-live-input.pl	108	live_scroll_told	C18
24-live-input.pl	117	live_scroll_back	C18
24-live-input.pl	122	live_home_settling	-
24-live-input.pl	129	live_home_left	-
24-live-input.pl	135	live_home_told	-
24-live-input.pl	142	live_scroll_left	C18
24-live-input.pl	197	live_unknown	-
24-live-input.pl	209	live_answered	C18 C19 C12 C7 C9 C26 C29 C4
24-live-input.pl	337	live_layer	C18
24-live-input.pl	374	live_layer_gone	C18
24-live-input.pl	386	live_layers_paid	C18
24-live-input.pl	411	live_sound	C12
24-live-input.pl	459	live_sounded	C12
24-live-input.pl	474	live_layers_again	C18 C9
24-live-input.pl	490	live_patched	-
24-live-input.pl	538	live_window_patch	-
24-parts.pl	1	-	-
24-parts.pl	24	parts_read	-
24-parts.pl	35	part_on	-
24-parts.pl	36	part_left_out	-
24-parts.pl	41	parts_told	-
24-parts.pl	42	parts_record	-
24-parts.pl	47	parts_set	C5
24-parts.pl	79	parts_fetched	C25
24-sound.pl	1	-	C12 C3 C22
24-sound.pl	168	sounding	-
24-sound.pl	173	sound_told	C12
24-sound.pl	182	sound_started	C12 C3
24-sound.pl	195	sound_flushed	C12
24-sound.pl	202	sound_heard	C12 C22
24-sound.pl	225	video_sound_kept	C22
24-sound.pl	234	video_sound_at	C22
24-sound.pl	253	sound_hushed	C12
24-sound.pl	261	sound_ended	C12
24-trmnl-panes.pl	1	-	C29
24-trmnl-panes.pl	69	trmnl_leaves	-
24-trmnl-panes.pl	70	trmnl_panes	-
24-trmnl-panes.pl	71	trmnl_shown_tab	-
24-trmnl-panes.pl	73	trmnl_path	-
24-trmnl-panes.pl	81	trmnl_replaced	-
24-trmnl-panes.pl	95	trmnl_page	-
24-trmnl-panes.pl	102	trmnl_least	-
24-trmnl-panes.pl	110	trmnl_held	-
24-trmnl-panes.pl	119	trmnl_place	-
24-trmnl-panes.pl	135	trmnl_layout	-
24-trmnl-panes.pl	142	trmnl_relaid	-
24-trmnl-panes.pl	150	trmnl_span	-
24-trmnl-panes.pl	156	trmnl_label	-
24-trmnl-panes.pl	161	trmnl_fitted	-
24-trmnl-panes.pl	171	trmnl_chrome	-
24-trmnl-panes.pl	190	trmnl_moved	-
24-trmnl-panes.pl	211	trmnl_composed	-
24-trmnl-panes.pl	237	trmnl_retitled	-
24-trmnl-panes.pl	250	trmnl_workspace	-
24-trmnl-panes.pl	272	trmnl_grown	-
24-trmnl-panes.pl	284	trmnl_pane_new	C29
24-trmnl-panes.pl	298	trmnl_pressed	-
24-trmnl-panes.pl	313	trmnl_pane_at	-
24-trmnl-panes.pl	315	trmnl_divider_at	-
24-trmnl-panes.pl	324	trmnl_clicked	-
24-trmnl-panes.pl	350	trmnl_inside	-
24-trmnl-panes.pl	352	trmnl_dragged	-
24-trmnl-panes.pl	363	trmnl_shared	-
24-trmnl-panes.pl	371	trmnl_focused	-
24-trmnl-panes.pl	379	trmnl_neighbour	-
24-trmnl-panes.pl	395	trmnl_divider_for	-
24-trmnl-panes.pl	403	trmnl_across	-
24-trmnl-panes.pl	405	trmnl_even	-
24-trmnl-panes.pl	413	trmnl_splits	-
24-trmnl-panes.pl	425	trmnl_items	-
24-trmnl-panes.pl	440	trmnl_menu_offered	-
24-trmnl-panes.pl	447	trmnl_act	C29
24-trmnl-panes.pl	477	trmnl_split	C29
24-trmnl-panes.pl	490	trmnl_pane_closed	C29
24-trmnl-panes.pl	507	trmnl_tab_added	C29
24-trmnl-panes.pl	521	trmnl_tab_closed	C29
24-trmnl-panes.pl	531	trmnl_tab_chosen	-
24-trmnl-panes.pl	540	trmnl_file	-
24-trmnl-panes.pl	542	trmnl_cwd	-
24-trmnl-panes.pl	551	trmnl_tree_lines	-
24-trmnl-panes.pl	558	trmnl_written	-
24-trmnl-panes.pl	569	trmnl_saved	C29
24-trmnl-panes.pl	582	trmnl_kept	-
24-trmnl-panes.pl	593	trmnl_read_saved	-
24-trmnl-panes.pl	610	trmnl_tree_read	-
24-trmnl-window.pl	1	-	C29 C32
24-trmnl-window.pl	30	window_trmnl_text	C32 C29
24-trmnl.pl	1	-	C29
24-trmnl.pl	85	trmnl_opened	-
24-trmnl.pl	102	trmnl_program	-
24-trmnl.pl	110	trmnl_started	C29 C3
24-trmnl.pl	132	trmnl_sized	-
24-trmnl.pl	144	trmnl_shell	C20 C29
24-trmnl.pl	175	trmnl_send	-
24-trmnl.pl	181	trmnl_fed	-
24-trmnl.pl	189	trmnl_keys	-
24-trmnl.pl	202	trmnl_input	C32
24-trmnl.pl	225	trmnl_viewed	C29
24-trmnl.pl	236	trmnl_pasted	C29
24-trmnl.pl	253	trmnl_copied	C29
24-trmnl.pl	269	trmnl_titled	C29
24-trmnl.pl	284	trmnl_replied	C29
24-trmnl.pl	294	trmnl_reported	C29
24-trmnl.pl	304	trmnl_moded	-
24-trmnl.pl	316	trmnl_wrote	-
24-trmnl.pl	330	trmnl_gone	-
24-trmnl.pl	344	trmnl_read	-
24-trmnl.pl	382	trmnl_block	C29 C9
24-trmnl.pl	405	trmnl_drawn	-
24-trmnl.pl	418	trmnl_shown	-
24-trmnl.pl	433	trmnl_pane_end	-
24-trmnl.pl	443	trmnl_lost	-
24-trmnl.pl	452	trmnl_end	-
24-trmnl.pl	464	trmnl_all	-
24-trmnl.pl	466	trmnl_select	-
24-trmnl.pl	476	trmnl_heard	-
24-trmnl.pl	491	trmnl_fds	-
25-ask-and-address.pl	1	-	-
25-ask-and-address.pl	10	ask	-
25-ask-and-address.pl	12	asked_later	-
25-ask-and-address.pl	14	asked	-
25-ask-and-address.pl	48	address	C23 C8
25-ask-and-address.pl	65	own_network	-
25-cht.pl	1	-	C32
25-cht.pl	50	cht_opened	-
25-cht.pl	69	cht_program	-
25-cht.pl	77	cht_box	C32 C3
25-cht.pl	98	cht_keeper	C32
25-cht.pl	122	cht_send	-
25-cht.pl	129	cht_fed	-
25-cht.pl	137	cht_tell	-
25-cht.pl	143	cht_sized	-
25-cht.pl	152	cht_input	C32
25-cht.pl	159	cht_shown	-
25-cht.pl	174	cht_units	-
25-cht.pl	202	cht_drew	C32
25-cht.pl	227	cht_paged	C32 C9
25-cht.pl	245	cht_copied	C32
25-cht.pl	256	cht_kept	C32
25-cht.pl	268	cht_linked	C32
25-cht.pl	278	cht_reachable	C32
25-cht.pl	291	cht_heard_link	C32
25-cht.pl	311	cht_dialed	C32
25-cht.pl	321	cht_hung	-
25-cht.pl	330	cht_net	-
25-cht.pl	354	cht_box_end	-
25-cht.pl	364	cht_unlinked	-
25-cht.pl	373	cht_end	-
25-cht.pl	385	cht_boxes	-
25-cht.pl	387	cht_select	-
25-cht.pl	401	cht_heard	-
25-cht.pl	419	cht_fds	-
26-log.pl	1	-	C12
26-log.pl	13	log_shown	C16
26-log.pl	50	choose_keeping	-
26-log.pl	73	changed	-
26-log.pl	88	log_lock	-
26-log.pl	94	keep_lock	-
26-log.pl	100	holds_log	C12
26-log.pl	126	keeping	C16
26-log.pl	139	kept_words	-
26-log.pl	145	keep_as	-
26-log.pl	156	keep_command	C5 C12
26-log.pl	206	record	C23
26-log.pl	225	line	-
26-log.pl	230	shortened	-
26-log.pl	235	excluded	-
26-log.pl	242	put	-
26-log.pl	252	synced	C12
26-log.pl	258	replace_log	-
26-log.pl	271	clear_log	C12
26-log.pl	292	expire_log	-
26-log.pl	311	show	-
27-proof.pl	1	-	C11
27-proof.pl	20	mark	-
27-proof.pl	27	sum_of	-
27-proof.pl	41	sum_seen	-
27-proof.pl	55	copied	-
27-proof.pl	68	copy_said	-
27-proof.pl	76	sum_started	-
27-proof.pl	77	sum_read	-
27-proof.pl	85	file_named	-
27-proof.pl	86	program_same	-
27-proof.pl	99	mark_started	-
27-proof.pl	100	mark_read	-
27-proof.pl	101	proven	C16
27-proof.pl	156	testing	-
27-proof.pl	162	lookup	C23
28-window-inspect.pl	1	-	-
28-window-inspect.pl	4	window_inspect_text	-
28-window-inspect.pl	206	inspect_window_test_text	-
28-window-link.pl	1	-	C31
28-window-link.pl	14	window_link_text	-
28-window-menu.pl	1	-	-
28-window-menu.pl	21	window_menu_text	-
28-window-pointer.pl	1	-	-
28-window-pointer.pl	23	window_pointer_text	C22
28-window-sound.pl	1	-	C22
28-window-sound.pl	10	window_sound_text	-
28-window-website.pl	1	-	-
28-window-website.pl	3	window_website_text	-
28-window.pl	1	-	C22
28-window.pl	18	window_text	C17 C16 C29 C18 C22 C12 C28 C26 C4 C27 C15
28-window1-tabs.pl	1	-	C26
28-window2.pl	1	-	-
29-commands.pl	1	-	C17 C16 C18 C23 C27 C20
```
<!-- sub-map end -->

To check that the docs name only subs and runs that exist, and that each statement index is current:

```
perl tools/doc-index --check docs/*.md
```

## Reproduce the test

On a Mac on Apple silicon, in a clone of this repository at the commit to check:

```
git rev-parse HEAD
perl selftest
```

`selftest` reads `lzrprf` beside it, puts its own hostile program in the closed application's place,
and prints every check as `works`, `held`, `FAILED` or `UNTESTED`. When nothing failed it writes a mark for this
build of macOS, this `lzrprf` and this `selftest` (`sub mark`), and prints a line that begins
`Nothing failed.` with their SHA-256. Compare that line with `selftest-output.txt`, the run made when
the release was made, and with `release.txt`.

To try a probe of your own, add it to `$hostile` in `selftest` and run it again.

## Reproduce the build

The source of the closed application is not in this repository, so its build can be reproduced only
where the source is. The maker's repository holds
`managed-projects/lzrbrwsr/audit/reproducible-build.sh`, which builds one commit twice in two clean
folders and compares the download, the installer and every file in the download byte for byte. A
reviewer with access to that source runs it as `sh audit/reproducible-build.sh COMMIT`.

What anyone can check without the source:

- the download is packed the same way every time (docs/installer.md shows how to repack it and compare);
- every file in the download has the SHA-256 that `release.txt` names (VERIFY.md, step 7);
- the program holds no path of the computer it was built on (`strings` shows none under `/Users`).

## Web fonts

Henry's decision of 2026-11-24 (ledger HC-0848) is that a page's `@font-face` fonts may be fetched
safely. It is built end to end: the application names the fonts, lzrprf fetches them (`fonted`,
`[C30]`), and the application decodes, checks and draws them. Here is the reasoning a reviewer needs.

- **Which fonts may be fetched.** This is decided in `managed-projects/lzrbrwsr/src/page/pictures.rs`
  (`wanted_fonts`, `font_entry`), under CSS Fonts 4 §4.3.1. A browser fetches a font file in CORS
  mode, so a font from another origin can only be used if its server allows it. The application
  makes no CORS request. It names a font only when the font's `url()`, resolved against the sheet
  that names it (the page's address for a `<style>` block), is a path on the page's own host by the
  same rules as a picture's, allowed by the page's font-src, and is not a `.otf` (CFF outlines, which
  Type does not draw). A font host on a name under the page's host or on another site is not
  fetched, and the face draws in the application's own local font. A page may fetch at most 8 font
  files and 8 MB in all, and each file at most 2 MB.
- **Which run names them.** A run reads the `@font-face` rules of the sheets it was handed and of
  the `<style>` blocks its policy allows (`src/page/webfonts.rs`, `wanted`, `with_inline`). Of each
  rule it names the first `src` entry it can use, no path twice and at most 8, with the rule's
  later paths after it joined by `|`, at most 4 (`Pictures::wanted_font_groups`), on one line
  `=webfonts /path|/path ...` after the `=sheets` line, and only when it has every sheet it will
  have and was handed no fonts (`run`). lzrprf checks that line to the same path form as
  `=sheets`, `{1,8}` fonts of 1 to `$FONT_TRIES` paths (sub `checked`), and tries a font's paths in
  order until one answers 200, as CSS Fonts 4 §4.3.1 falls through a src entry that fails. Such a run is read as a first run is: with no network and no tiles, as the page
  is laid out again. A `data:` font carries its file in the sheet: the application decodes it itself
  (`engine/typeface/data_font.rs`, at most 2 MB once decoded) and nothing is fetched for it.
- **The fetch.** It is lzrprf's own, `fonted` beside `sheeted`, with no network code in the
  application:
  - the page's own host, https only;
  - `listed()` before a request ([C23]), then `filter_said()` with the type `font` ([C27]);
  - `record()` before `fetch()` ([C5]), and a second line after it saying whether the font was
    handed over and why not;
  - `fetch()` itself holds it to LZRDFNDR's judgement ([C28]) and to the page's own checked
    addresses, through Tor when Tor is on ([C6] [C7]); the identity headers ask as Safari does,
    `Sec-Fetch-Dest: font`, `Sec-Fetch-Mode: cors`;
  - one clock of 10 seconds for starting all of them, each request cut at 2 MiB and 64 KiB
    (`$FONT_BYTES`), all of them together at most 8 MiB (`$FONTS_TOTAL`).

  A refused, failed, larger, late or not-200 path is not handed over and the font's next path is
  tried; a font none of whose paths is handed over goes with length 0, as a refused sheet does.
  Nothing of a font is written to the disk: the answers are held in memory for the page shown
  (`$SHOWN->{frame}`, so a new width lays it out with them again) in an incognito window as in any.
- **A page that names no style sheet.** Its own `<style>` blocks, those its policy allows, are
  read for `@font-face` too. When a first run that names no sheet names fonts from them, lzrprf
  fetches them with `fonted` exactly as above and hands a second run `=sheets` with no sheet and the
  `=webfonts` frame (the `elsif` after the sheets branch of `visit`). That first run is read without
  the network, as one that names sheets is; the second is shown when it is a page that names
  neither sheets nor fonts again. When it is no page and asked for no address, a third run is handed
  each font with length 0 and is read with the network, as `[C14]`'s unsheeted run is; it is shown
  when it is such a page, else the first run is. Still never a fourth run (selftest runs
  `inlinefonts`, `inlinefontsagain`, `inlinefontsrescue` in `webfonts`).
- **The third run.** The fonts are handed to a third run in a frame `=webfonts n1 ... nk` after the
  `=sheets` frame, the answers back to back. It is shown when it is a page that names neither sheets
  nor fonts again; otherwise the second run is (the first time a page is laid out three times in
  this way, `[C14]` still holds: never a fourth run). The application reads each answer only as a
  whole HTTP 200 with no encoding, decodes it (below), and keeps the files that pass for that page
  alone (`webfonts::files`, then `Pictures::plain_fonts`); a face that does not pass draws in the
  local font, and the page's statement line says which and why.
- **The proof.** The studio page `r-webfonts` serves the pinned Liberation Mono 2.1.5 (OFL; the file
  of `scripts/fetch-test-data.sh`, nothing downloaded) from the page's own host as TrueType, WOFF 1.0
  and WOFF 2.0, each a family on Arial-fallback text. Our engines and Chrome draw all three in
  Liberation Mono: every span 259.25 px wide in Chrome and 259.28 to 259.30 px in ours, the font on
  another host and plain Arial at their Arial widths, 99.84% of pixels the same (`tstr` compare,
  2026-11-24). The selftest run `webfonts` proves lzrprf's side; `src/page/webfonts_tests.rs` the
  three runs and every refusal.
- **Telling the format.** A file's format is read from its first four bytes alone: `wOF2`, `wOFF`,
  `0x00010000` or `true`. The name and the Content-Type are never used. `OTTO` (CFF outlines) and
  `ttcf` (collections) are refused, because the application draws neither.
- **The decoder.** It is in `engine/typeface/woff.rs`, `woff2.rs`, `woff2_glyf.rs` and `brotli.rs`,
  written for this purpose with no dependency (`woff::to_sfnt`).
  - Every read is checked against the end of its buffer.
  - Every loop pays from a fuel counter.
  - The input is capped at 2 MB (`MOST_FILE`), the unpacked font at 8 MB (`MOST_SFNT`), its tables
    at 64 and its glyphs at 16384 (`MOST_GLYPHS`, which bounds the glyf rebuild).
  - A WOFF 1.0 table inflates into a buffer of exactly its declared size. A Brotli meta-block that
    would pass the cap is refused at its header, before a byte of it is written. WOFF2's Brotli
    stream is decoded by our own RFC 7932 decoder, and every distance and copy is bounds-checked.
  - The unpacked font must then read through Type's own readers (`read::read`,
    `glyf::Glyphs::read`), or the whole file is refused.
  - Tests cover every cut, every flipped byte and random bytes, headers and directories that claim
    too much, a zlib bomb, broken glyf and hmtx transforms, and byte-for-byte rebuilds of Source Code
    Pro from real encoders; none of them panics. They are `engine/typeface/woff_tests.rs`,
    `woff_hostile_tests.rs`, `woff_real_tests.rs`, `brotli_tests.rs`, `web_tests.rs` and
    `data_font.rs`.
- **No font code runs.** A font's `fpgm`, `prep` and glyph bytecode are kept, as WOFF2's rebuild
  keeps them byte for byte, but no reader in Type has an interpreter, so none of it ever runs.
- **The one file taken from elsewhere.** Brotli's static dictionary (RFC 7932 Appendix A) is
  `engine/typeface/brotli_dictionary.bin`.
  - It was downloaded with Henry's approval from
    `https://raw.githubusercontent.com/google/brotli/ed738e842d2fbdf2d6459e39267a633c4a9b2f5d/c/common/dictionary.bin`
    (tag v1.1.0).
  - It is 122,784 bytes, with SHA-256
    `20e42eb1b511c21806d4d227d07e5dd06877d8ce7b3a817f378f313653f35c70`.
  - It is data. It is included with `include_bytes!` and is only ever indexed.
  - Brotli's MIT notice sits beside it as `BROTLI-LICENSE`, taken from the same commit, with SHA-256
    `3d180008e36922a4e8daec11c34c7af264fed5962d07924aea928c38e8663c94`.
  - The 121 word transforms and the context tables in `brotli_tables.rs` were read once, by a script,
    from the libbrotlicommon 1.2.0 already on the build Mac; nothing was downloaded for them. Some
    entries were checked by hand against the RFC's text, as listed in that file's header.

## Not built yet

These parts of the audit plan are not built in this release. Each is named so a reader does not assume
it.

- **Web fonts, what is left.** Fonts are fetched and drawn (see "Web fonts"), but:
  - only fonts named in fetched sheets are; an `@font-face` in an inline `<style>` alone is not yet;
  - `data:` font addresses are not decoded yet;
  - no bold or italic is synthesised for a family that lacks the face;
  - the `ch` unit is measured in the local font.

- **A `selftest` run of `tools/doc-index --check`.** `selftest` checks the map of subs above and that
  every system program `lzrprf` starts is listed in `capabilities.json` with the sub that starts it,
  but the statement indexes of docs/ are checked only by running `tools/doc-index --check` by hand.
- **A reproduced build by someone other than the maker.** `reproducible-build.sh` has not been run by
  an independent reviewer. `managed-projects/lzrbrwsr/audit/independent-review.md` in the maker's
  repository is the template for that review.
- **The header of `lzrprf` says "Four kinds of process are started here".** The converter, the bookmark
  reader, the verifier and the Tor client are started too, each in a container of its own. The
  sentence is out of date; the code and CAPABILITIES.md are not.
