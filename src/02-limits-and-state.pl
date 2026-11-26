use strict;
use warnings;
use Cwd 'abs_path';
use Digest::SHA;
use Fcntl qw(:flock O_RDONLY O_RDWR O_WRONLY O_APPEND O_CREAT O_EXCL O_NOFOLLOW O_NONBLOCK);
use File::Basename qw(basename dirname);
use File::Glob 'bsd_glob';
use MIME::Base64 qw(decode_base64 encode_base64);
use POSIX 'strftime';
use Socket qw(AF_INET AF_INET6 AF_UNIX SOCK_STREAM SOL_SOCKET SO_ERROR NI_NUMERICHOST NI_NUMERICSERV AI_NUMERICHOST inet_aton inet_pton pack_sockaddr_in unpack_sockaddr_in pack_sockaddr_un getaddrinfo getnameinfo);
use Time::HiRes;
use Scalar::Util 'weaken';

$^X eq '/usr/bin/perl' or exec '/usr/bin/perl', $0, @ARGV or die "lzrprf: the system's own perl is missing\n";
umask 0077;                               # what lzrprf writes is readable by you alone
{ my $number; do { $number = POSIX::open('/dev/null', O_RDWR) } while defined $number && $number < 3; POSIX::close($number) if defined $number }    # descriptors 0, 1 and 2 exist from here on
# Loaded where first needed, not at every start: File::Path (sub remove_tree), Time::Local, Digest::MD5 and IO::Handle (required where called); the two listening sockets are made by socket, bind and listen, the calls IO::Socket made, and a handle is made not to block by fcntl (sub unblocked) and to write at once by $| (11 to 20 ms of the 22 ms of modules, measured 2026-11-24).
sub remove_tree { require File::Path; return File::Path::remove_tree(@_) }    # File::Path's own, unchanged
sub unblocked { my $flags = fcntl($_[0], POSIX::F_GETFL(), 0) // return; return fcntl($_[0], POSIX::F_SETFL(), $flags | O_NONBLOCK) }    # what IO::Handle's blocking(0) does: the flags the handle has, and O_NONBLOCK
my %SHOWN = map { ($ENV{$_} // '') =~ /\A[0-9A-Za-z]{1,8}\z/ ? ($_ => $ENV{$_}) : () } qw(NO_COLOR COLUMNS LINES);    # [C20] how lzr is asked to draw, read before the variables are dropped and told to no program
%ENV = (PATH => '/usr/bin:/bin:/usr/sbin:/sbin', map { defined $ENV{$_} ? ($_ => $ENV{$_}) : () } qw(LANG TMPDIR __CF_USER_TEXT_ENCODING LZRPRF_SELFTEST_HOME));    # nothing lzrprf starts is found through, or told, a variable of whoever started lzrprf (LZRPRF_SELFTEST_HOME: only a runner slot's home counts, below)

my $SELF = abs_path($0);
my $HOME = abs_path((($ENV{LZRPRF_SELFTEST_HOME} // q{}) =~ m{^/private/tmp/lzr-run/slot-[0-9]+/home\z} && -d $ENV{LZRPRF_SELFTEST_HOME} && -o _ ? $ENV{LZRPRF_SELFTEST_HOME} : (getpwuid $<)[7]));    # from the account, not from the environment; only the home of a runner slot of scripts/test-run.sh, a folder of yours, stands in for it in a test
my $DIR = "$HOME/.lzrprf";                # no container can read or write this folder
my ($INCOGNITO, $BASE) = (0, undef);     # an incognito window [C16]: $DIR is then its own folder in your temporary folder, and $BASE the folder its few settings are read from, never written
my $UNKEPT = 'An incognito window writes nothing';    # the start of every refusal to keep something in one
my ($HELD_ENGINE, $HELD_BAR, $HELD_PICTURES, $HELD_HELPER);    # in an incognito window, a search address, a bookmarks bar, pictures from other sites or LZRDFNDR's satellite chosen in it: in its memory only
my $PICTURES_SHOWN = 1;                   # whether the window is told of pictures from other sites, which shows their row in the cogwheel's menu: on, since lzrprf fetches by sub pictures_elsewhere; 0 hides the row again
my ($TOR_WANTED, $TOR) = (0, undef);      # $TOR: {pid, guard (lzrprf's end of the pipe), port} while the client runs
my ($TOR_WINDOW, $TOR_SESSION) = (0, undef);    # [C17] a Tor window, and its phase while it runs ({phase}: sub tor_phase); a window that is not one never has Tor
sub kept_in { $INCOGNITO ? $BASE : $DIR }    # where settings are read from: ~/.lzrprf (or a test's folder), or a profile's own folder in a profile's window, and the same in an incognito window opened from it
my $ROOT = $DIR;                         # the state folder itself, ~/.lzrprf (or a test's folder): the folder of the first profile, and of what belongs to the installation and to no profile (sub profile_entered)
my $PROFILE;                              # the profile of this window, by its id (12 hex digits lzrprf made); undef for the first profile, whose folder is the state folder as it always was
my $GONE = 'No new window was started: the profile this window was opened from has been removed since. Open one from a window of another profile.';    # said instead of starting a window that would end at its first check, in an incognito window whose profile was removed while it was open
sub shared { $INCOGNITO ? $DIR : $ROOT }  # where what belongs to the installation is written: the state folder, or in an incognito window its own folder, removed when it ends [C16], as before there were profiles
my $CURL = '/usr/bin/curl';               # the system's own; it does the https, lzrprf holds no code for it
# What curl offers a site to encrypt with, fixed here rather than left to the system's library: left to it,
# curl offers 49 ciphers, among them old ones each release of the library changes, so the first message of
# every connection would name the macOS release. Pinned, every computer offers the same six ciphers (and
# the library's three of TLS 1.3, which it does not let anyone change) and the same two curves
# (so neither names the macOS release). Measured with curl 8.7.1 and LibreSSL 3.3.6, 2026-11-20.
my $TLS_CIPHERS = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';    # DECLARED(the modern ciphers every current site accepts, and no others)
my $TLS_CURVES = 'X25519:P-256';          # DECLARED(the two curves every current site accepts)
my $SCRIPT = '/usr/bin/osascript';        # the system's own; it runs the window's text and the question to the system
my $ROOTS = '/private/etc/ssl/cert.pem';  # the system's list of certificate authorities
my $FETCH_BYTES = 6 * 1024 * 1024;        # the most that is taken from a site for one address
my $FETCH_SECONDS = 30;                   # the most one request may take, from the first connection to the last byte
my $WIRE_BYTES = $FETCH_BYTES + 1024 * 1024;    # the most that is carried from the site to curl: the answer, and what encryption adds
my $SENT_BYTES = 64 * 1024;               # the most that is carried from curl to the site: one request is far smaller
my $FIND_SECONDS = 10;                    # the most a name lookup may take
my $FOUND = 8;                            # the most addresses of one name that are taken: the first eight this computer has a way to
my $LOOKED = 16;                          # the most addresses of one name that are looked at for that: what the lookup gave beyond them is left out
my $PAGE_BYTES = 48 * 1024 * 1024;        # the most one page container may write (four times 12 MiB since retina tiles: each has four times the pixels at scale 2): room for the 32 tiles of a laid page, 32 x 262,656 bytes of base64, about 8.4 MB, and the rest of the page
my $PAGE_SECONDS = 30;                    # a page container is ended after this, whatever it is doing
my $PAGE_ROOM = 2097152;                 # the address space, in KiB, a page container may take on top of what the shell that starts it holds: 2 GiB. What the application itself holds at its start is not measured
my $LIVE_SECONDS = 1800;                  # DECLARED(half an hour: a page kept running with its tab, sub live_kept, is ended after this whatever it does, and its last drawing stays; reading a long form takes minutes, not hours)
my $LIVE_BYTES = 4 * $PAGE_BYTES;         # DECLARED(burst budget for live drawing, refilled by one PAGE_BYTES per second; repeated edits do not exhaust a lifetime byte allowance)
my $LIVE_MOST = 3;                        # DECLARED(the most pages kept running at once, each in a container of up to $PAGE_ROOM: three stay under 8 GiB of a 16 GB Mac; the oldest is ended first, its drawing kept)
my $LIVE_INPUT = 1040;                      # DECLARED(LONGEST_INPUT of the application's scripted module, src/page/scripted.rs: the longest input line it reads, its line end not counted)
my $LIVE_TEXT = 1024;                       # DECLARED(LONGEST_TEXT of the same module: the most bytes of the text of one "=text" line)
my $LIVE_HELD = 65536;                     # DECLARED(the most input the keeper holds for a page that does not read it: bounded in the keeper; the parent retains at most 1 MiB more and resumes partial writes when the relay is writable)
my $LIVE_FETCH_MOST = 600;               # DECLARED([C19] the most addresses one page kept running may ask for in its life: one every three seconds for its half hour; a page that asks for more is answered "=fetched 0 0 0")
my $LIVE_FETCH_UP = 65536;                # DECLARED([C19] LONGEST_BODY_UP of the application's scripted module, src/page/scripted.rs: the most bytes of a body a page's request carries up)
my $LIVE_FETCH_LINE = 8300;               # DECLARED([C19] the longest "=fetch" line: its words, 65536, the longest type and an address of LONGEST_GO, 8192, as the application writes it)
my $LAYERS_RATE = 524288;                 # DECLARED([C18] the bytes of "=layers" lines a page kept running may write a second, steadily: a scene of about 79 layers moving at 60 frames a second wrote 19 to 70 kB a second, MEASURED in the layer bench; seven times its most)
my $LAYERS_BURST = 2097152;               # DECLARED([C18] the bytes of "=layers" lines it may write at once above that rate: a scene of the most layers sent whole, $LAYERS_MOST of about 500 bytes each, after a tab was shown again)
my $LAYERS_LINE = 65536;                  # DECLARED(LINE_BYTES of the application's layers module, src/page/layers.rs: the longest "=layers" line, its line end not counted)
my $LAYERS_PATH = 16384;                  # DECLARED(PATH_BYTES of the same module: the longest outline of one shape)
my $LAYERS_MOST = 4096;                   # DECLARED(MOST_LAYERS of the same module: the most layers of one page at once)
my $LAYERS_EMITTERS = 128;                 # DECLARED(MOST_EMITTERS of the same module: the most particle sources of one page at once)
my $SOUND_LINE = 65536;                   # DECLARED([C12] LINE_BYTES of the application's sound module, src/page/sound.rs: the most base64 characters of one "=samples" line, its line end not counted)
my $SOUND_FRAMES = 2880000;               # DECLARED([C12] MOST_FRAMES of the engine's sound, engine/bindings/audio.rs: the most frames of one sound, a minute at 48000 a second)
my $SOUND_BYTES = 16777216;               # DECLARED([C12] the most bytes of samples, two to a frame, a page kept running may hand lzrprf in its life: over six minutes at 22050 frames a second, and all the window holds for it; they are not counted in $LIVE_BYTES)
my $SOUNDS_MOST = 1024;                   # DECLARED([C12] the most sounds a page kept running may make in its life: a sound of a few frames each time a page plays a short one, many times a minute)
my $SOUND_PRESS_SECONDS = 5;              # DECLARED([C12] ACTIVATION_MS of the engine's sound: a page sounds only this soon after a click or a key lzrprf handed it; a sound it starts later is not passed to the sound process)
my $SOUND_IDLE = 30;                      # DECLARED([C12] the seconds with nothing playing after which the sound process says it is idle and lzrprf ends it; the next sound starts it again, ready in a tenth of a second)
my $SOUND_NAME = 'core-lzrbrwsr-sound';   # [C12] the name the sound process gives itself (the owner's form core-<project>-<purpose>, HC-0844)
my $SOUND;                                # [C12] the sound process while it runs: {pid, to, from, out (what waits to be written to it), in (what it said that is not a whole line), asked (the page of each play not answered yet), of (the process that started it)}
my $SOUND_FAULTED = 0;                    # [C12] the sound process could not be started once in this window: said in the log that once
my %VIDEO_SOUND;                          # [C22] the MP4 of each video of the tab shown that has a sound track, by "TAB K": {body (a reference to the bytes handed to the window), url, at}, two at most, in memory only
my %VIDEO_SOUND_SAID;                     # [C22] the videos whose lack of a sound lzrprf can hand over was said in the log, once each
my $LAYER_NUM = qr/(?!-0(?![.0-9]))-?(?:0|[1-9][0-9]{0,6})(?:\.[0-9]{0,3}[1-9])?/;    # [C18] a number of a "=layers" item, written one way only: no 0 in front, at most four decimals and none ending in 0, no sign on 0
my $LAYER_PATH = qr/M$LAYER_NUM,$LAYER_NUM(?:[ML]$LAYER_NUM,$LAYER_NUM|Q(?:$LAYER_NUM,){3}$LAYER_NUM|C(?:$LAYER_NUM,){5}$LAYER_NUM|Z)*/;    # [C18] an outline: M, L, Q, C and Z steps, their numbers joined by commas
my $LAYER_COLOUR = qr/(?:[0-9a-f]{8}|-)/;    # [C18] rrggbbaa, or - for none
my $LAYER_TEXT = qr/[\x20-\x3a\x3c-\x7e]{1,200}/;    # [C18] the words of a text layer: printable, no ";", at most 200
my $LIVE_HEAD_BYTES = 8192;               # DECLARED([C19] REPLY_HEAD_BYTES of the same module: the most bytes of the header lines of one reply; lines past it are left out)
my $TRY_QUIET = 2;                        # DECLARED("lzrprf try" only: once the test's lines are all given, it ends after every page kept running has written nothing for this long; a page's timers and its requests run in milliseconds)
my ($LISTS_KEPT, $LIST_USED) = (8, 0);    # DECLARED(the tabs whose page lists lzrprf keeps, the ones shown last (sub lists_bounded): 8, the tabs a person moves among; the window keeps as many drawings)
my $LIVE_END_SECONDS = 1;                 # DECLARED(what a page is given to end by itself after "=end" before it is ended: the application reads the line and returns at once)
my $PIECES = 50_000;                      # the most lines one page may have
my $BOXES = 2000;                         # the most grey boxes among them
my $BLOCK = 20_000;                       # the most one block of a page may hold, from one line that begins a block to the next: a line of text counts its characters, a line break one, a grey box $BOX
my $BOX = 400;                            # what a grey box counts in a block: more than the widest and flattest one becomes in the window
my $HUNG = 30;                            # the most characters in a row that hang on the one before them
my $WORD = 1000;                          # the most characters in a row with no place among them where a line may end
my $JOINER = qr/(?!\x{103a})\p{Ccc=9}/;    # a sign that joins the letter after it to the one before (Myanmar's asat ends a syllable and joins nothing)
my $HANGS = qr/[\p{M}\p{GCB=Extend}\p{GCB=SpacingMark}\p{GCB=Prepend}\p{GCB=V}\p{GCB=T}]|(?<=\p{GCB=L})\p{GCB=L}|(?<=\p{GCB=Prepend})[^\x{fffd}]|(?<=$JOINER)[^\x{fffd}]|(?<=$JOINER\p{M})[^\x{fffd}]/;    # a character that hangs on the one before it: see "What the window is spared"
my $SOLID = qr/[^\x{20}\x{1680}\x{2000}-\x{2006}\x{2008}-\x{200a}\x{205f}\x{3000}\x{200b}]/;    # a character where no line may end: all but the spaces that let one end (a no-break space does not)
my $MADE = 120;                           # the most lines that say what the page is made of
my %LAID = (R => 20_000, X => 30_000, G => 1000, M => 64, I => 1000, K => 32, J => 1024, Q => 1000, V => 8);    # a laid page: the most rectangles, runs of text, grey boxes, pictures, places for a fetched picture, tiles (numbered under K), places of a tile, places of a video and rounded edges a fetched picture is cut to
my $RUN_TEXT = 2000;                      # the most characters in one run of text of a laid page
my $ALL_TEXT = 1_000_000;                 # the most characters in all its runs together
my $PIXELS = 262_144;                     # the most pixels in all its pictures together: one picture of 512 by 512
my $PICTURES = 24;                        # DECLARED(lzrbrwsr src/page/pictures.rs MOST_PICTURES, the same number): the most pictures one page may name, each fetched by a run of its own
my $PICTURE_SITES = 8;                    # DECLARED(lzrbrwsr src/page/pictures.rs MOST_PICTURE_SITES, the same number): the most other sites, neither the page's host nor a name under it (sub under), that are asked for one page's pictures; a picture on one more is not fetched, and the log says why
my $PICTURES_AT_ONCE = 8;                 # DECLARED: the most pictures of one page fetched and decoded side by side, the owner's order of 2026-11-21: 24 one after the other took over 4 seconds; 8 since 2026-11-24, when hs.fi's 24 AVIF pictures took 2.4 s at 4 (scripts/load-timeline.pl)
my $PICTURE_SECONDS = 20;                 # one clock for all of a page's pictures: a picture not begun by then stays a grey box
my $PICTURE_PIXELS = 800_000;             # the most pixels in one fetched picture: four times 200,000 since retina pictures, sharp at two device pixels a point
my $SIPS = '/usr/bin/sips';               # [C21] the system's own; it decodes for lzrprf what the application cannot (AVIF, HEIC, HEIF), lzrprf holds no code for it
my $DECODE_SECONDS = 10;                  # DECLARED([C21] the most one run of the system's decoder may take in all: a picture of 1024 pixels a side takes it under one second)
my $DECODED_SIDE = 2048;                  # DECLARED([C21] the longest side of the PNG the system's decoder writes: lzrbrwsr src/page/picture_container.rs PICTURE_SIDE, the most the application draws)
my $VIDEOS = 8;                           # DECLARED(lzrbrwsr src/page/pictures.rs MOST_VIDEOS, the same number): the most MP4 files one page may name on its =videos line, and the most places of a video (V) of a laid page
my $VIDEO_BYTES = 64 * 1024 * 1024;       # DECLARED([C22] the most of one video that is fetched and handed to the window: a minute of 1080p H.264 at 8 Mbit/s, or two of 720p at 4, is 60 MB, the length of a news site's clip; the window holds a whole file in its memory while it plays, and at most two (VIDEO_HELD), so videos take at most twice this of your memory, and it hands the system's player at most 4 MiB of one at a time)
my $VIDEO_SECONDS = 120;                  # DECLARED([C22] the most one video's request may take: 64 MiB in 120 seconds asks for 4.5 Mbit/s, which a home connection gives)
my $VIDEO_FRAME = 49152;                  # DECLARED([C22] bytes of a video in one line to the window, 65536 characters of base64: lines the window reads a piece at a time, never the whole file at once)
my $HLS_PLAYLIST = 256 * 1024;            # DECLARED([C22] the most bytes of one HLS playlist lzrprf reads: a master playlist is a few KB, and a media playlist of $HLS_SEGMENTS segments about 100 KB)
my $HLS_VARIANTS = 32;                    # DECLARED([C22] the most qualities (EXT-X-STREAM-INF) one master playlist may offer: news sites offer 4 to 12)
my $HLS_SEGMENTS = 1024;                  # DECLARED([C22] the most segments one media playlist may list: at 6 seconds each, an hour and 42 minutes; what is fetched of them stops at $VIDEO_BYTES and $VIDEO_SECONDS)
my $HLS_BITRATE = 2_500_000;              # DECLARED([C22] the cap of the quality lzrprf chooses of a stream: the middle of those offered at or under 2.5 Mbit/s (720p H.264), so 64 MiB holds three minutes or more; the lowest offered when none is under it)
my $HLS_LINE = 4096;                      # DECLARED([C22] the most bytes of one line of a playlist: an address is at most 2000, a tag with its attributes a few hundred)
my $AVCONVERT = '/usr/bin/avconvert';     # [C24] the system's own; it turns an MPEG-TS stream with sound into an MP4 file without decoding it (PresetPassthrough), lzrprf holds no code for it
my $CONVERT_SECONDS = 30;                 # DECLARED([C24] the most one run of the system's converter may take in all: 10.9 MB took 2 seconds on 2026-11-21)
my $VIDEO_CLICKED;                       # the video you clicked last, the one a Stop that comes after its fetch ended is answered for (the window takes "stopped" only for a video that loads)
my $DECODED_BYTES = 16 * 1024 * 1024;     # DECLARED([C21] the most of a PNG the system's decoder writes that is read: 1024 by 1024 pixels of four bytes is 4 MiB before it is packed)
my $SHEETS = 8;                           # the most style sheets one page may name on its own host, fetched before it is laid out a second time
my $SHEET_BYTES = 1024 * 1024;            # the most of one style sheet's answer that is handed over: a larger one goes with length 0
my $SHEET_SECONDS = 10;                   # one clock for starting all of a page's style sheets: a sheet not begun by then goes with length 0
my $FONTS = 8;                            # DECLARED([C30] the most web font files one page may name on its own origin: the application names no more, page::MOST_WEB_FONTS)
my $FONT_TRIES = 4;                       # DECLARED([C30] the most paths of one web font, tried in order until one answers 200, as a src entry that fails falls through to the next: the application names no more, page::MOST_ALTERNATES)
my $FONT_BYTES = 2 * 1024 * 1024 + 64 * 1024;    # DECLARED([C30] the most of one font's answer: the application's cap of a font file, woff::MOST_FILE, and room for its headers; a larger one goes with length 0)
my $FONTS_TOTAL = 8 * 1024 * 1024;        # DECLARED([C30] the most of all of a page's font answers together: a font that would pass it goes with length 0; Liberation's four faces are 1.6 MB as TrueType)
my $FONT_SECONDS = 10;                    # DECLARED([C30] one clock for starting all of a page's fonts, and the most one font's request may take)
my @FONTS_NAMED;                          # [C30] the web font files the run read last named on its =webfonts line, by path on the page's own host: sub checked sets it for every run
my @PICTURED;                             # the other hosts the pictures of the page last laid out were asked of, in its order: what the bar says
my $PICTURES_AHEAD;                       # the pictures of the page being read begun ahead of its own list (sub pictures_ahead), until sub pictured takes them over
my $PICTURES_BEFORE;                      # the pictures decoded for the page this tab showed, kept while the same site is asked again in it and placed in the first list where grey boxes stood (sub pictures_before, sub pictures_so_far); dropped once the visit's own pictures are here, when the tab goes to another host and when it is closed
my $PICTURES_BEFORE_BYTES = 64 * 1024 * 1024;    # the most bytes of decoded rows kept so: a picture beyond them is a grey box until it is fetched again
my %NAMED;                                # the decoded pictures this lzrprf named in a list, by name: [name, the picture (held weakly: a picture no page keeps is gone here too), whether its rows were sent to the window]. A list places a picture by its name (a line N), and its rows go to the window once (sub picture_named, sub named_owed)
my %NAMED_AT;                             # the same, by where the picture stands in memory
my ($NAMED_RUN, $NAMED_OWNER, $NAMED_COUNT) = ('', 0, 0);    # the eight random characters every name of this process begins with, the process they were made in, and how many it named: a copy made by fork, or lzrprf started again behind a window that lives on, never names a bitmap another one sent
my $AHEAD_PAGE;                           # the answer being read now, with its host, its addresses and how its lines are kept: what a picture begun ahead is checked against (sub prefetch_begin)
my $DRAWN_PIXELS = 8 * $PICTURE_PIXELS;   # the most pixels the window is given for fetched pictures on one page, however often one is placed: a place beyond that stays a grey box
my @FACES = map { "/System/Library/Fonts/Supplemental/$_.ttf" } 'Arial', 'Arial Bold', 'Arial Italic', 'Arial Bold Italic', 'Courier New', 'Courier New Bold', 'Courier New Italic', 'Courier New Bold Italic';    # the fonts a page is drawn with, in the application's order: plain, bold, italic, both, then the same in fixed width
my $FACE_BYTES = 2 * 1024 * 1024;         # the most of one font that is handed over: the largest of the eight is 773,236 bytes on this macOS
my $ANSWER_SECONDS = 600;                 # a question that is still open then counts as answered with its first button
my $NAME = qr/(?:[A-Za-z0-9-]{1,63}\.)+[A-Za-z][A-Za-z0-9-]{0,62}/;    # a host name: never a bare number, never one word
my $UNWRITTEN = 'Nothing was fetched: the log could not be written.';
my $UNENDED = 'lzrprf tried the fetch. Nothing of its answer is shown: the line that says how it ended could not be written to the log.';    # not the words above: by then the site was connected to, or was tried
my $UNSAID = 0;                           # set while a fixed request (sub fixed) was tried and the line of how it ended is not in the log yet
my $LIST_BYTES = 64 * 1024 * 1024;        # DECLARED([C23] the largest list file lzrprf reads: room for a million digests of the address lists, many times the lists of today)
my $LIST_FORM = 2;                        # [C23] the form of the addresses the list's digests are made of (README, "The digests"), named in its first line: a list made for another form matches nothing here, so it is no list
my $QUERY_SUBSETS = 8;                    # DECLARED([C23] the most query parts whose every choice is looked up, 255 searches by halves; with more, a path that has any listed query is refused whole)
my %LISTED;                               # [C23] the list as lzrprf holds it, once it was read: for onion, host and url, the digests of that part side by side, sorted, 16 or 32 bytes each
my ($LIST_HELD, $LIST_WHY, $LIST_COUNT) = (0, undef, 0);    # [C23] whether the list is held; why it is not, once reading it failed; how many digests it holds
my $REFUSED = 'This address is on a list of child sexual abuse material or other illegal content, so LZRBRWSR does not open it.';    # [C23] the one sentence of a refusal, the same in the window and in the log
my $REFUSED_HELP = 'If you are worried about your own thoughts or someone else\'s, Stop It Now helps in confidence: https://www.stopitnow.org.uk. To report child sexual abuse material you came across: https://report.iwf.org.uk';    # [C23] said in the window after it, never written in the log
my $REFUSED_AHMIA = 'This onion address is on Ahmia\'s list of child sexual abuse material sites (https://ahmia.fi/blacklist/). That list can contain mistakes: a site that only names such terms without sharing the material, such as some Tor hidden wikis, can be on it. If you believe this address is listed by mistake, report it to Ahmia (https://ahmia.fi/about/)';    # [C23] said in the window after $REFUSED when the onion part refused it (Ahmia's list), never written in the log; sub refused adds the release file's report address
my $LIST_HIT;                            # [C23] the part of the list (onion, host, url, query, or whole for an address too long to be read) that refused the address sub listed matched last, for the words of sub refused; emptied there
my $REFUSED_WHY = 'that address is on a list of child sexual abuse material or other illegal content';    # [C23] why, where a lower check refuses: it names no address
my $KEPT_DAYS = 30;                       # how long a kept log keeps a line, when you chose a kept log and no number of days
my $KEPT_MOST = 3650;                     # a setting of more days than this is no setting: nothing is kept

# "lzrprf try" is the same program for tests (selftest, and nothing else):
# its state is in a folder of its own, every name leads to one listener on
# this computer, whose certificate must be signed by the test's own
# authority, and with "allow" or "deny" there is no window: what the window
# would be told is printed, what would be typed is the test's text, and every
# question gets that one answer; with a row of the digits 1 and 2 instead,
# each question in turn gets the next one, and once the row is used up every
# question is answered as nobody answering would. With "ask" the real window runs, and the
# test may add text of its own to the window's. A test that puts a file
# "prove" into its folder gets the question of [C11] as well, against a mark
# in that folder. "lzrprf run" has none of this.
my ($TRY, $PEER, $TYPED, $ANSWER, $RUN, $APP, $PROGRAM, @ARGUMENTS) = (0, '-', '-', 'ask', 0, 'the application', '');
my $BEGAN;                                # the SHA-256 of the program when this window began: see "sub laid_out"
my $PROGRAM_SEEN;                         # the file the program was when its SHA-256 was last found to be $BEGAN: see "sub program_same"
my ($FROM, @EVENTS);                      # what the window says; or, without a window, what a test has typed
my $FROM_HELD = '';                       # what the window said that is not a whole line yet (sub hear)
my $IDLE_WORK;                            # a sub run once, the first moment the window and every page are quiet (sub hear), set by sub behind: the identity question, asked before the first address is typed
my ($SPARE, $SPARE_WANTED);               # the process of the next page run, started before that run (sub spare_for); the address one is wanted for at the next quiet moment (sub spare_work)
my ($CURL_SPARE, $CURL_WANTED) = (undef, 1);    # curl started before its request (sub curl_for); whether the next quiet moment starts one
my @LIVE;                                 # the pages kept running with their tabs, the oldest first (sub live_kept)
my $LAID_TALLY;                           # what the last laid list checked holds: its counts, text, pixels and tiles (sub laid), kept by a page kept running for a splice of it (sub live_patched)
my $TRMNL_OPEN = 0;                       # [C29] the local home's terminal icon was pressed: a terminal is opened once the answer that said so is taken (sub trmnl_opened)
my @TRMNL_VIEW;                           # the size of the window's page as it said it, before it is held to a page's steps: a terminal's screen fills it (sub trmnl_sized)
my @LIVE_TOLD = ('off', 0);               # what the window was last told of the selected tab's page kept running (sub live_told)
my $LIVE_STOP_SECONDS = 0.25;             # DECLARED(a quarter of a second, many frames of the screen: the window says where it stopped on the frame after it read lzrprf's scroll): how long after the window said a page's own scroll back its next place may say where its view stopped short of it (sub live_input)
my $LIVE_FRAME_SECONDS = 1 / 60;          # DECLARED(one frame of a screen that draws 60 times a second; the window shows no more places than that): the least time between two places of a page's own scroll that lzrprf tells the window; one sooner waits, and only the newest (sub live_scroll_told)
my $LIVE_UNKNOWN_NAMES = 16;              # DECLARED(far more than one later application adds at once): the most names of answer lines it does not know that lzrprf writes in the log for one page kept running (sub live_unknown)
my %LIVE_KNOWN = map { $_ => 1 } qw(focus go statement scroll layers sound samples play hush again patch ready fetch fetched end page live permit permitted permits keep jar inspect);    # the names of the lines of an answer and of the frame around it: one of these out of its form or its place ends the page
my %CURSORS = map { $_ => 1 } qw(default pointer text vertical-text crosshair move grab grabbing not-allowed no-drop copy alias context-menu col-resize row-resize ew-resize ns-resize e-resize w-resize n-resize s-resize);    # the pointer's shapes a page kept running may ask for ("=cursor"), those the window has a cursor for: the application's own list of them
my %PERMIT_CAPS = (                       # [C26] the capabilities a script may ask, by name, and who may grant each: "low", the sandbox (E1), a curated rule (E2) or you (E3); "person", only you, by your own rule; "c5", nobody by any script permission: it has its own question each time (C5). A name not here is granted by your rule alone
    dom => 'low', layout => 'low', timers => 'low', 'storage-own' => 'low', 'fetch-same' => 'low',
    clipboard => 'person', camera => 'person', microphone => 'person', location => 'person', files => 'person',
    'post-other' => 'c5', payment => 'c5', credentials => 'c5');
my %PERMIT_E1 = map { $_ => 1 } grep { $PERMIT_CAPS{$_} eq 'low' } keys %PERMIT_CAPS;    # [C26] E1, the capabilities of low risk: an inline or same-origin script asking only these runs with no question
my @PERMIT_SANDBOX = (                    # [C26] E1, the sandbox: what a page whose site has no rule of yours runs, is asked for and is refused, by name. sub sandbox_says reads it, and lzrprf enforces each line where its name is read; Script permissions shows it
    ['own-scripts', 'runs', "the page's own scripts, inline and external from its own origin, asking only capabilities of low risk"],
    ['other-scripts', 'asks', 'a script or module from another origin: fetched, hashed and asked about, unless a curated rule (E2) names it'],
    ['strings', 'asks', 'text turned into code: eval, Function, a timer given a string'],
    ['fetch-own', 'runs', 'a GET or HEAD of the page to its own origin'],
    ['fetch-other', 'refused', 'any other request of the page to another origin, frames and workers included: answered 403 and never fetched'],
    ['post', 'refused', 'a POST of the page to any origin, its own included: answered 403 and never sent'],
    ['credentials', 'refused', 'cookies and credentials: lzrprf sends none, and a request of a page carries no header of its own'],
    ['keep', 'refused', "nothing is written for the site: its storage lives in the page alone, and what the sandbox decided is held in this window's memory"],
    ['sign-in', 'off', 'a page with a password field, or at an address of signing in, has no sandbox and no curated rule: its scripts are asked about'],
);
sub sandbox_says { my ($name) = @_; my ($line) = grep { $_->[0] eq $name } @PERMIT_SANDBOX; return $line ? $line->[1] : 'refused' }    # [C26] what the sandbox does with one thing, by its name in @PERMIT_SANDBOX; a name not there is refused
my $PERMIT_SEEN_MOST = 48;                # DECLARED(script-permissions contract E1 2026-11-22: what Script permissions shows of the sandbox's and the curated rules' decisions, the newest first)
my @PERMIT_SEEN;                          # [C26] the decisions of E1 and E2 in this window, newest first: [layer, site, what, said, count], in memory only and never written
my $CURATED;                              # [C26] E2, the curated rules, read once a window: {rules => [...], parts => [[site, used or ignored, why]], why => why none is used}
my $CURATED_BYTES = 512 * 1024;           # DECLARED(script-permissions contract E2 2026-11-22: the largest file of curated rules read)
my $CURATED_MOST = 4000;                  # DECLARED(script-permissions contract E2 2026-11-22: the most curated rules read; a file of more is not used)
my %SIGNIN_HOSTS = map { $_ => 1 } qw(login signin sso auth oauth idp accounts account id identity tunnistus tunnistautuminen kirjaudu);    # [C26] the first labels of a host that say it is for signing in: no sandbox and no curated rule there, and a curated rule for such a site is not used
my %SIGNIN_PATHS = map { $_ => 1 } qw(login signin sign-in log-in sso oauth auth kirjaudu kirjautuminen tunnistaudu tunnistautuminen);    # [C26] the path segments that say a page is for signing in, in small letters, before any "." of the segment
my %PERMIT_PASSWORD;                      # [C26] the addresses whose page held a password field, at most $PERMIT_SEEN_MOST: no sandbox and no curated rule for them
my $FILTERS;                              # [C27] the filter lists, read and checked once a window, when a request is first held to them (sub filters)
my $FILTER_BYTES = 4 * 1024 * 1024;       # DECLARED(the filter design of 2026-11-22: the largest list file read; EasyList, the largest, is 2.0 MB)
my $FILTER_LISTS = 24;                    # DECLARED(the filter design of 2026-11-22: the most lists one manifest may name; it names 15 when the uAssets lists ship, and holds at most 32 files)
my $FILTER_SEEN_MOST = 48;                # DECLARED(the filter design of 2026-11-22: the blocked requests Filters shows, the newest first)
my @FILTER_SEEN;                          # [C27] the requests the filter lists blocked in this window, newest first: [page host, address, type, rule, list], in memory only and never written
my $FILTER_ALLOWS = 400;                  # DECLARED(the filter design of 2026-11-22: the most hosts you may let through on sites; a file of more is not read)
my $HELD_FILTER_LAYERS;                   # [C27] in an incognito window, and for "lzrprf filters": the filter switches, in memory only
my %FILTER_DEST = (data => 'xmlhttprequest', script => 'script', module => 'script', worker => 'script', frame => 'subdocument', image => 'image');    # [C27] the type a filter rule names for each destination of a page's request (sub live_fetched)
my %PERMIT_PATHS;                         # [C26] the path each script came from, by "SITE ORIGIN SHA256", as lzrprf fetched it for the page: what a curated rule by path pattern is matched against
my ($HELD_LAYERS);                        # [C26] in an incognito window, the sandbox switch and the curated rules switched off, as chosen in it: in its memory only
my $PERMIT_KIND = qr/inline|external|module|handler|eval|function|timer|worker|import|frame/;    # [C26] what a page's engine asks to run
my $PERMIT_ORIGIN = qr/inline|data:|blob:|https:\/\/$NAME(?::[0-9]{1,5})?/;    # [C26] where its bytes came from: the page itself, a data: or blob: address, or an https origin
my $PERMIT_CAPS = qr/-|[a-z][a-z0-9-]{0,31}(?:,[a-z][a-z0-9-]{0,31}){0,31}/;    # [C26] the capabilities it asks, by name, or none
my $PERMIT_FILE_BYTES = 256 * 1024;       # DECLARED(script-permissions contract 2026-11-22: the largest scripts file read, room for well over a thousand rules)
my $PERMIT_RULES = 1000;                  # DECLARED(script-permissions contract 2026-11-22: a file of more rules is not read, and none is written)
my $PERMIT_QUEUE = 32;                    # DECLARED(script-permissions contract 2026-11-22: the most scripts of one visit put to you in one question)
my $PERMIT_ROUNDS = 1;                    # DECLARED(Henry 2026-11-24, yle.fi: one reload after your answers, never one per question; a later Allow holds for the page as it runs): the most reloads in a row that your Allow starts for one address
my $LIVE_PERMIT_MOST = 2000;              # DECLARED(script-permissions contract 2026-11-22: the most =permit questions one page asks in its life; a page that asks more is ended)
my $BEHIND_FAULTS = 100;                 # DECLARED(Henry 2026-11-24: a page must never take the browser down; past this many errors of its own in one window, lzrprf behind it ends after all, as one that comes back at every line would never let the window go on)
my @PERMIT_HELD;                          # [C26] rules in this window's memory only: every rule of an incognito window, and a rule lzrprf could not write because the file is not read
my %PERMIT_DENIED;                        # [C26] what you denied with Deny Once, by site: "CLASS ORIGIN SHA256" of a script, and '' for the site's scripts as a whole; for the visit shown only (sub permit_visited lets it go) and never written
my $PERMIT_STRIPPED;                     # [C26] the last answer whose scripts were taken out, and what that gave: [answer, without them, how many parts, the parts] (sub permit_page)
my $PERMIT_UNREAD;                       # [C26] the allowed page whose parts are not read for their names yet: [address, site, answer, read] (sub permit_unread)
my %PERMIT_INFO;                          # [C26] what lzrprf saw of each script it fetched or found in a page, by "SITE ORIGIN SHA256": {name => host and path (or "inline script ... in" the page), where => inline or external, bytes, source => its first $PERMIT_SOURCE_MOST bytes}; in memory only, at most $PERMIT_RULES
my $PERMIT_SOURCE_MOST = 8192;            # DECLARED(enough to read what a script does at its start; a large bundle is cut and said so): the most bytes of one script's source shown when you are asked about it
my %PERMIT_WEB;                           # [C26] the scripts put to you, by "SITE<tab>CLASS<tab>ORIGIN<tab>SHA256": [site, kind, origin, sha256, caps], for LZRDFNDR's On Websites; in memory only, at most $PERMIT_RULES
my %REDIRECTS;                            # [C4] every redirect lzrprf put to you in this window, by "FROM<tab>TO": {site, status, from, to, fit, decision, n}; the decision is "pending" while you are asked, "cancelled" or "proceeded" once answered, and "cancel always" or "proceed always" once LZRDFNDR's Redirects changed it, which then answers that redirect for you; in memory only, never written, at most $REDIRECTS_MOST
my $REDIRECTS_MOST = 256;                # DECLARED(a long session of redirects, each a few hundred bytes): the most redirects LZRDFNDR's Redirects keeps; the oldest goes first
my $REDIRECTS_SEEN = 0;                  # [C4] how many redirects were noted, the order of their keeping
my $LZRDFNDR_OPEN = 'https://lzrbrwsr.com/play/lzrdfndr';    # [C26] the address the program's own game page (https://lzrbrwsr.com/play) goes to for its Activate or Setup LZRDFNDR button: never fetched; it opens LZRDFNDR's panel on On Your Computer
my $LZRDFNDR_PAGE = qr{\Ahttps://(?:www\.)?lzrbrwsr\.com/play(?:\.html)?(?:[?#][\x21-\x7e]*)?\z}i;    # [C26] the game page's own addresses, as the page engine takes them (is_play): only a page at one of them opens the panel that way
my @PERMIT_TRACKERS = (                   # [C26] hosts whose scripts are named by who runs them when you are asked, the end of the host matched: [end of host, name]
    ['googletagmanager.com', 'Google Tag Manager'], ['google-analytics.com', 'Google Analytics'], ['analytics.google.com', 'Google Analytics'], ['doubleclick.net', 'Google DoubleClick ads'],
    ['googlesyndication.com', 'Google AdSense'], ['googleadservices.com', 'Google Ads'], ['gstatic.com', 'Google gstatic'], ['connect.facebook.net', 'Meta Pixel'], ['hotjar.com', 'Hotjar'],
    ['clarity.ms', 'Microsoft Clarity'], ['scorecardresearch.com', 'comScore'], ['chartbeat.com', 'Chartbeat'], ['chartbeat.net', 'Chartbeat'], ['nr-data.net', 'New Relic'],
    ['newrelic.com', 'New Relic'], ['segment.com', 'Segment'], ['tiktok.com', 'TikTok Pixel'], ['ads-twitter.com', 'X (Twitter) ads'], ['snap.licdn.com', 'LinkedIn Insight'],
    ['cookiebot.com', 'Cookiebot consent'], ['onetrust.com', 'OneTrust consent'], ['cookielaw.org', 'OneTrust consent'], ['quantserve.com', 'Quantcast'], ['criteo.com', 'Criteo ads'],
    ['taboola.com', 'Taboola'], ['outbrain.com', 'Outbrain'], ['amazon-adsystem.com', 'Amazon ads'], ['adnxs.com', 'Xandr ads'], ['gemius.pl', 'Gemius'], ['sentry-cdn.com', 'Sentry'],
);
my %PERMIT_NEXT;                          # [C26] Allow Once, by site, for the next visit to it: {keys => {"KIND ORIGIN SHA256 CAPS" => 1}}, the kind asked when you answered
my %PERMIT_ONCE;                          # [C26] Allow Once of the visit shown of each site: taken from %PERMIT_NEXT as the visit begins, and gone with the next visit
my ($PERMIT_RELOAD, $PERMIT_ROUND) = (undef, 0);    # [C26] the address your Allow is loading again, and how many reloads in a row your Allow started for the visit shown
sub permit_class { return $_[0] =~ /\A(?:eval|function|timer)\z/ ? 'strings' : 'code' }    # [C26] the class of a kind: "strings", text a script turns into code (eval, Function, a timer given a string), asked on its own on purpose; "code", the script's own bytes run
sub permit_kinds { my ($class, $origin) = @_; return $class eq 'strings' ? qw(eval function timer) : $origin eq 'inline' ? qw(inline module handler) : qw(external module worker import) }    # [C26] the kinds a rule of this class and origin holds for, as =permits tells them
my $PERMITS_MOST = 512;                   # DECLARED(the application's wire, src/page/permit.rs, 2026-11-22: a =permits frame of more lines is refused whole): the most lines of one =permits frame, its "page" line among them
my $PERMIT_ASK;                           # [C26] the visit being shown: {site, url, items => {"KIND ORIGIN SHA256 CAPS" => [kind, origin, sha256, caps]}, stripped, refused}, what is put to you once it is drawn
my $WENT = 0;                             # when the visit shown began, on the clock nobody can set (sub go)
my $DRAWN = 0;                            # a page was handed to the window, and the window has not said yet that it could not draw it
my @VIEW_WIDE = (320, 1600);              # the narrowest and the widest a page is laid out: a window's width outside them is taken as the nearer one, and the application refuses a =view frame outside them
my @VIEW_HIGH = (240, 2160);              # the same for the height of its first screen, which a page's vh is taken from
my $VIEW_SCALE = 1;                       # device pixels a point of the window's screen, 1 or 2 (a retina screen), as the window last said it: a page's tiles are drawn at it
my @VIEW = (960, 768);                    # the size of the window's page, in points, as the window last said it and held to those bounds; until it says one, the size every page was laid at before
my $LAID_WIDE;                            # the width the run being checked was asked to lay its page at: a laid page of any other width is unfit
my $OUTRUN = 0;                           # a relayout runs (sub relaid): the window is heard while it runs, and a newer width ends it (sub outrun)
my $SHOWN;                                # the page shown, kept to lay it out again when the window's page changes width: its address, its answer, the frame of style sheets it was laid with, whether that was a second run, its host, its decoded pictures, the width it was laid at
my $WINDOW_LISTS = 0;                     # how many times the window was handed lines of a page (page, relaid, patch, runs) or its tabs: a list sent earlier is still the one it holds while this stands (sub pictures_pumped)
my @HELD;                                 # what the window said while lzrprf looked for its latest size, in order: heard before anything new
my @LATER;                                # Tor turned on or off in the window while a question was open, and the newest place the window showed the page from: heard by the loop of sub behind once the question is answered, so the window's onion never waits for an answer that was dropped
my $TABS_MOST = 32;                       # the most tabs one window holds: the owner's order of 2026-11-20
my ($PULLED, $PULLED_MOST) = (0, 32);     # DECLARED(the most windows one window opens from its tabs and its profiles together in its life, as many as it holds tabs: a window process taken over cannot have lzrprf start processes without end)
my $PROFILES_MOST = 16;                   # DECLARED(the most profiles, the first among them: one for each person or each part of a life who shares this Mac, with room; each is a folder and each window of one a process, so a window taken over cannot fill the disk with them)
my $PROFILE_NAME = 32;                    # DECLARED(the most characters of a profile's name: it is shown in one row of the Profiles list, beside the icon; a longer one is refused, never cut)
my @CLOSED;                               # the tabs closed in this window, the newest first, for "Reopen Closed Tab": [its place, the tab] (sub closed_kept)
my $CLOSED_MOST = 10;                     # DECLARED(the owner's order of 2026-11-21: the last ten closed tabs)
my $CLOSED_DRAWN = 2;                     # DECLARED(the newest two closed tabs keep their page, so the reopen pressed at once shows it without a fetch; an older one is visited again, so ten closed tabs do not hold ten pages)
my ($OPEN, $OPEN_FRAME);                  # a window of a tab pulled out of another (sub opened_with): the address it opens first, and the frame it opens at
my $TITLE = 200;                          # the most characters of a page's title, the =title line, shown in its tab
my $VISITED = 100;                        # the most addresses a tab's history holds, the oldest dropped first: a list nothing is fetched from, emptied by "Clear history"
my $INSTALL_SECONDS = 1800;               # the installer of a newer release is ended after this long: the slowest install measured by hand took under two minutes
my $INSTALL_TRIES = 12;                 # how often the installer is fetched from both places while the two differ: a release being published reaches one place minutes before the other
my $INSTALL_WAIT = 30;                   # the seconds between those tries: twelve cover the five minutes one place may keep its old copy
my $INSTALL_LINE = 2000;                  # the most characters of one line the installer printed that the window is given; a longer one is given in parts
my @INSTALL_STOPS = qw(TERM HUP INT QUIT USR1 USR2 XCPU);    # the signals that would end lzrprf behind the window without a word: from "install begin" to the end of an install, each is said in install.txt, the window and the log, and lzrprf stops; an installer that runs goes on, its lines read on into install.txt (sub installed, sub install_drained)
sub fresh_tab { return { url => '', title => '', visited => [], at => -1, shown => undef, says => undef, secure => undef } }    # a tab: the address in its bar, its page's title, the addresses it went to and where in them it stands (back and forward), its page shown as $SHOWN keeps it, lzrprf's last words in it, what lzrprf saw of the connection its page came over
my @TABS = (fresh_tab());                 # the window's tabs, in the order the window shows them; the page of the selected one is the only one shown, and it is $SHOWN while it is selected
my $TAB = 0;                              # which tab is selected
my $NEXT;                                 # set by sub visit when you chose to follow a redirect: [its address, how its log line begins, undef] (sub go)
my @WAY;                                  # the redirects of one go, each "FROM answered STATUS, to TO (how)": what the lock tells of how the page shown was reached (sub go, sub secured)
my %ENGINES = (brave => 'https://search.brave.com/search?q=%s', duckduckgo => 'https://html.duckduckgo.com/html/?q=%s', google => 'https://www.google.com/search?q=%s');    # the search addresses offered by name (sub typed)
my $WROTE = "\nlzrprf-certificates\n";    # the line curl writes after the whole answer, before the certificates it checked (sub fetch)
my $WROTE_ROOM = 256 * 1024;              # what curl may write after an answer, that line and the certificates in text, read on top of the answer's own limit and cut off before it is judged: without it an answer just under its limit ended the reading before curl did (sub fetch)
my @MARKS;                                # the bookmarks as last told to the window, by number: [its file, its name, its address, its folder] (sub marks_told)
my $TITLED = '';                          # the title of the page the last checked run wrote, '' for none (sub checked)
my $READ_ASKED = 0;                       # [C19] how many requests the last page run made while it was read, before its first list, each fetched or refused: its external and module scripts among them (sub contained)
my %MORE = (nothing => 0, hosts => 1, all => 2);    # what is kept, from less to more
my $HALF;                                 # the line of a change reached the log, and the system did not say that it is on the disk
my $FRESH = $$;                           # the number of the process the system started afresh for this file; a copy made by fork has another one. A guard, which changed nothing that ran when it came: sub lookup is only reached by "lzrprf lookup", a fresh process, and sub numbered does what find did before. It keeps a later change from looking a name up in a copy, where the system's libraries end a copy of a process with more than one thread the moment a lookup loads them (+[NSString initialize] ... when fork() was called: an uncommitted change crashed so on 2026-11-21 05:01 to 05:04); and the stop signals of an install end a copy at once (sub installed)
my (@SESSION, $UNMARKED, $MARKED, $UNEXPIRED);    # this window's lines, in the memory of the process behind it and nowhere else; whether a log could not be marked for Time Machine; whether this process marked it; whether the days you chose still wait for another window's request to end

sub now { Time::HiRes::clock_gettime(Time::HiRes::CLOCK_MONOTONIC()) }    # a clock nobody can set: seconds since the computer started
my $TIMED = 0;                            # "lzrprf try" only, with a file "times" in the test's folder: each step of a start and a visit is said with the time it was reached, for the audit (scripts/audit.mjs) to show where the time goes
my $PREFETCH_AT_ONCE = 24;                # DECLARED([C19] the most requests of one page fetched ahead side by side: yle.fi names 13 scripts and a sheet on its own host, and with twelve the last waited until the page asked (2026-11-25); each curl waits on its site, not on a processor)
my $PREFETCH_HELD_BYTES = 32 * 1024 * 1024;    # DECLARED([C19] the most bytes of answers fetched ahead that lzrprf reads before the page asks for them (sub prefetch_select): hs.fi's 45 scripts are 9 MiB; past it an answer waits in its pipe as every one did before, so at most this and one read more of each running request, 24 x 256 KiB, is held)
my $PREFETCH_MOST = 64;                   # DECLARED([C19] the most scripts of one page fetched ahead; the rest are fetched when the page asks, as before)
my %FOUND;                                # [C6] each name looked up in this window: when, and the addresses with their ways (sub find), in memory only
my $FOUND_SECONDS = 30;                   # DECLARED([C6] [C8] how long a lookup stands: a page asks a host for dozens of requests in its first seconds, and a network changed under it is looked at again within half a minute)
my %FINDING;                             # [C6] the lookups begun ahead of their request and not read yet, by name (sub find_ahead)
my $FINDING_MOST = 4;                     # DECLARED([C6] the most names looked up ahead at a time: a page names a font host and a picture host, seldom more that it asks at once)
my $VISIT_KEPT_BYTES = 48 * 1024 * 1024;  # DECLARED([C19] the most bytes of answers one visit keeps for its page's later reads of the same request: yle.fi's scripts are 3 MB)
my %PREFETCH;                             # [C19] the scripts of the page being read fetched ahead, by address (sub prefetch_begin), and the answers this visit already handed its page (sub prefetch_keep)
my $PREFETCH_LATER;                      # [C19] the page whose named scripts are judged and begun once its first run is started: its address, where it came from, its host (sub prefetch_later)
my %AHEAD;                                # [C14] [C30] the style sheets and web fonts begun ahead of the run that names them, by address (sub ahead_begin)
my @FETCHERS;                             # copies of lzrprf that wait with their curl for a style sheet's address (sub fetchers_for)
my @PREFETCH_MADE;                        # [C19] the makers of those begun (sub prefetch_made), until each is reaped
my @PREFETCH_WAITING;                     # [C19] those not begun yet, in the page's order
my $PREFETCH_NAMED;                       # [C19] the scripts the page being read names, fetched once it asks for its first (sub prefetch_go)
my $TIMING_MARK = 'lzrprf-clocks';        # with $TIMED alone: the line curl writes after an answer with its own clocks of it (sub fetch), read by scripts/load-timeline.pl
my $TIMING_OUT = "\n$TIMING_MARK %{time_appconnect} %{time_starttransfer} %{time_total} %{http_code} %{num_connects}";
sub timed { printf STDERR "test time %s %.1f\n", $_[0], Time::HiRes::time() * 1000 if $TIMED; return }    # the step and the time of day in milliseconds, on the clock the audit reads too
my $SHIELD_CACHE = 2048;                   # DECLARED([C28] at most this many address verdicts are cached; at the bound the next batch is judged afresh)
my $SHIELD_DAY = int(time / 86400);        # the UTC day of cached verdicts; list expiry is checked again when it changes
my %SHIELD_SAID;                          # [C28] LZRDFNDR's verdict on each address this window asked about before fetching it, in memory only: its line, "=allow" or a checked "=flagged" (sub shield_asked)
my $BESIDE_SECONDS = 0.25;                # DECLARED(the style sheets begun ahead are waited for this long before a page's first run is read; yle.fi's is here within 0.06 s, and a first run that names other sheets, or none, is read this much later at most)
my %BESIDE_LOGGED;                        # the sheets whose two lines of the log were written when they were taken beside a first run (sub beside_sheets)
my ($BESIDE, $BESIDE_WANTED, $BESIDE_FIRST, $BESIDE_FONTS, @AHEAD_SHEETS);    # a page's second run started beside its first (07-visit-beside.pl): the run with what it was handed; what its first run begins when it is started; the first run's pipes meanwhile; the addresses of the style sheets the answer names, in its order (sub ahead_sheets)
my $SHIELD_AHEAD;                         # a judging run begun beside the page's second run (sub shield_ahead), until its verdicts are taken (sub shield_heard)
my $SHIELD_CHILD = 0;                     # a copy of lzrprf made to fetch one picture: it asks the application nothing, and what the window did not judge before it is not fetched
my $FLAGGED;                              # [C28] what LZRDFNDR said of the page it blocked last, checked (sub flagged_by): {category, list, confidence, context}, in memory only
