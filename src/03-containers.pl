# What the operating system allows inside the page container and the fetch
# container. Every line is an allowance; what is not listed is refused: every
# network use, writing any file, reading any file outside the system's own
# folders and the application's own folder, starting any other program, starting a second process, signalling
# another process, asking another program to open something, every system
# service (so: no window, no key, no clipboard, no other application), and
# every fact about the computer that is not under the three prefixes or among
# the single names below (so: not its name, not its other processes, not its
# network). As code it may load itself and the system's own libraries; from
# release 17 on no other file, also not one in its own folder. That takes a
# refusal of its own: macOS lets a contained program load as code whatever
# file it may read, unless a line says no, so before release 17 the line that
# allows was all there was and it refused nothing.
# One thing macOS does not refuse by itself inside a container: making (not
# using) memory, flags and queues of the old "System V" kind, of which the
# whole computer has only a few. The three calls that make them are refused
# by name, so a contained program cannot use them up for other programs.
my $CONTAINER = <<'END';
(version 1)
(deny default)
(deny syscall-unix (syscall-number SYS_shmget SYS_semget SYS_msgget))
(allow process-exec (literal (param "APP")))
(deny file-map-executable)
(allow file-map-executable (subpath "/System") (subpath "/usr/lib") (literal (param "APP")))
(allow sysctl-read
  (sysctl-name-prefix "hw.") (sysctl-name-prefix "machdep.cpu.") (sysctl-name-prefix "kern.osvariant")
  (sysctl-name "kern.ostype") (sysctl-name "kern.osrelease") (sysctl-name "kern.osversion")
  (sysctl-name "kern.osproductversion") (sysctl-name "kern.osproductversioncompat") (sysctl-name "kern.version")
  (sysctl-name "kern.maxfilesperproc") (sysctl-name "kern.argmax") (sysctl-name "kern.ngroups")
  (sysctl-name "kern.usrstack64") (sysctl-name "kern.secure_kernel") (sysctl-name "kern.willshutdown")
  (sysctl-name "kern.hv_vmm_present") (sysctl-name "vm.footprint_suspend")
  (sysctl-name "sysctl.proc_native") (sysctl-name "sysctl.proc_cputype") (sysctl-name "sysctl.proc_translated"))
(allow file-read*
  (subpath "/System") (subpath "/usr/lib") (subpath "/usr/share") (subpath "/private/etc/ssl")
  (literal "/") (literal "/dev/null") (literal "/dev/random") (literal "/dev/urandom")
  (subpath (param "OWN")))
(deny file-read* (subpath "/System/Volumes"))
(allow file-read* (subpath "/System/Volumes/Preboot/Cryptexes"))
(allow file-read-metadata
  (literal "/") (literal "/usr") (literal "/Library") (literal "/dev") (literal "/private")
  (literal "/private/etc") (literal "/private/var") (literal "/private/var/db") (literal "/etc") (literal "/var")
  (literal "/System/Volumes") (literal "/System/Volumes/Preboot")
END

# The page container is allowed nothing on top of that. It also gets at most
# 30 seconds of processor time, may write no byte into a file and no memory dump, may
# hold no more than 256 open files (where lzrprf itself was started with a
# lower limit that no process may raise, that lower limit stands), may
# take no more memory than a shell holds plus 2 GiB
# ($PAGE_ROOM), and is told two things: the address it lays out and the seal
# of its run [C1] (and, beside them, that the run is for a picture, for the
# application's tool or for LZRDFNDR's verdicts before a fetch [C28]). It sees no other variable. Each limit is set before the next step, and a limit the
# system will not set starts nothing. Each is set as the limit that counts
# now and as the limit that may not be raised again, both in one call (sub
# limited). Before release 17 a bare "ulimit" set one of the two, which one
# differing between the shells macOS can use as /bin/sh, and with one of them
# the program could have raised its limits again. Until release 83 a
# shell set them and became "env -i", which became sandbox-exec: two
# programs started for every container, three containers a page. Since then
# lzrprf sets them itself (sub limited, which says why that is as strong).
my $PAGE_LIMITS = { bytes => 0, told => [qw(LZRPRF_CONTAINED LZRPRF_SEAL)], set => [qw(LZRPRF_PICTURE LZRPRF_TOOL LZRPRF_JUDGE LZRPRF_TOR LZRPRF_HOME)] };    # the bytes one file may hold; the variables told always, and those told only when they hold something

# What curl's container is allowed on top of it: one socket file, behind which
# lzrprf holds the connection to the site, and the list of certificate
# authorities. It has no network of its own. So whatever a site sends it, curl
# can reach no other place, read no file of yours, write nothing and start
# nothing.
my $FETCH = <<'END';
(allow network-outbound (literal (param "WAY")))
(allow file-read* (literal (param "ROOTS")))
END
# curl too gets at most 30 seconds of processor time, may write no byte into a
# file and no memory dump, may hold no more than 256 open files, and may take no
# more memory than a shell holds plus 2 GiB. When the system will not set one of these limits, curl
# is not started. It is told no variable at all.
my $FETCH_LIMITS = { bytes => 0 };

# The decoder container, on top of the page container's text: the one file
# it reads (IN), the one file it writes (OUT, which it may also look at), a
# folder of its own for the temporary file sips writes first (TMP, its
# TMPDIR), and two things of the system, which is all the system's decoder of
# AVIF and HEIC needs and was measured to need on macOS build 26B123: sips
# may ask for one system service by name, the video decoder service, which
# does the decoding in a process of the system's own, and sips's own process
# may open one kind of connection to the graphics driver, IOSurfaceRoot's,
# to read the picture the service hands back in graphics memory. Without
# either, sips writes nothing (tried 2026-11-21: without the second, sips
# itself fails to write, so it is sips's and not only the service's). The
# bytes both of them read are the site's answer exactly: the site chooses
# every one, the application only says that the file is for the system, and
# lzrprf hands sips the body curl fetched (sub pictured). The folders above
# the picture's folder may be known to exist, and no more (sub decoding).
# The program started in it is the system's perl, which waits for one byte
# from lzrprf and then turns into sips, the one other program the container
# lets start (sub system_decoded): so sips starts only after the system said
# the process is contained, and is never already gone when it is asked.
# At every start the system is asked whether this container lets another
# service be named (sub decoder_named), and the tries show it writes no
# second name for a file of yours (sub holds).                        # [C21]
my $DECODER = <<'END';
(allow file-read* (literal (param "IN")))
(allow file-write* (literal (param "OUT")))
(allow file-read-metadata (literal (param "OUT")))
(allow file-read* file-write* (subpath (param "TMP")))
(allow mach-lookup (global-name "com.apple.coremedia.videodecoder"))
(allow iokit-open-user-client (iokit-user-client-class "IOSurfaceRootUserClient"))
(allow process-exec (literal "/usr/bin/sips"))
END
# Its limits are the page container's, but for the PNG it writes: 16 MiB.
# It sees one variable, its TMPDIR.
my $GATE = 'sysread(STDIN, my $go, 1) == 1 or exit 1; exec { $ARGV[0] } @ARGV; exit 1';    # [C3] [C21] the decoder's program waits until the system said it is contained, then becomes sips
# The converter container [C24], on top of the page container's text: the
# one file it reads (IN, the MPEG-TS stream lzrprf joined), the one file it
# writes (OUT, the MP4), a folder of its own for the copy avconvert writes
# first (TMP, its TMPDIR), and two services of the system by name, which is
# all /usr/bin/avconvert needs to rewrap a stream with sound without decoding
# it, measured on macOS build 26B123 (2026-11-21): the register of sound
# decoders (com.apple.audio.AudioComponentRegistrar), without which it
# cannot read the stream's sound ("unable to read"), and the read-only map of
# the system's file types (com.apple.lsd.mapdb), without which it knows no
# kind of file to write ("file extension mp4 not valid"). Without TMP it
# fails too. No network, no other file of yours, no other program but
# avconvert, started by the same waiting perl as sips ($GATE), so it starts
# only after the system said the process is contained. These two names are
# reachable from this process alone, never from the window's: the window
# then plays an MP4, as it plays any MP4, with the 42 names it had. It is
# the site's bytes avconvert reads, chosen by the site: a flaw in avconvert
# or in the system's code it loads that a stream reaches is held by this
# container and its limits, and gives the site nothing lzrprf trusts.
my $CONVERTER = <<'END';
(allow file-read* (literal (param "IN")))
(allow file-write* (literal (param "OUT")))
(allow file-read-metadata (literal (param "OUT")))
(allow file-read* file-write* (subpath (param "TMP")))
(allow mach-lookup (global-name "com.apple.audio.AudioComponentRegistrar") (global-name "com.apple.lsd.mapdb"))
(allow process-exec (literal "/usr/bin/avconvert"))
END
# Its limits are the decoder's, but for the files it writes: 96 MiB each
# (the MP4 and avconvert's own copy of it, both smaller than the stream of at
# most $VIDEO_BYTES). Until release 83 the shell's "ulimit -f"
# counted these two in blocks of 1024 bytes, not 512 as was written here, so
# they were twice what this said (32 and 192 MiB, measured 2026-11-24); from
# then on they are the bytes said here.
my $CONVERT_LIMITS = { bytes => 96 * 1024 * 1024, as => { TMPDIR => 'LZRPRF_TMPDIR' } };
# The sound container [C12], on top of the page container's text, holds the
# sound process ($SOUND_NAME): the system's own osascript running the text of
# $SOUND_TEXT, which plays the sound of a page kept running, and nothing else.
# The window's container lets the window reach no register of sound
# components (com.apple.audio.AudioComponentRegistrar), the owner's choice of
# 2026-11-21, and without that name macOS plays no sound in a process at all:
# a player in the window said prepared=false play=false, and outside it true
# and true. So the sound plays here, in a process of its own that may look up
# three services of the system by name and no other, measured on macOS build
# 26B123 (2026-11-24) by playing a second of silence at no volume in this
# container and taking away one name at a time from the fourteen the process
# asked for: the register of sound components and the sound server
# (com.apple.audio.audiohald), without either of which its player is not
# ready and does not play, and the CoreServices daemon
# (com.apple.CoreServices.coreservicesd), without which osascript finds no
# JavaScript to run ("no such component"). It reads no file but the system's
# own, writes none, has no network, starts no program but the one it is and
# no second process, and sees no variable. It is handed the samples lzrprf
# checked (sub live_sound) as text, and the words play, stop and clear; it
# says back, for each play, whether the system's player played it.
my $SOUND_CONTAINER = <<'END';
(allow mach-lookup (global-name "com.apple.audio.AudioComponentRegistrar") (global-name "com.apple.audio.audiohald") (global-name "com.apple.CoreServices.coreservicesd"))
END
# Its limits are the page container's, but for processor time: ten minutes of
# it, where a sound looping took a third of a second of it a minute (measured
# 2026-11-24: 0.33 s, 22 MiB), so a day of music; lzrprf ends the process
# once nothing played for $SOUND_IDLE seconds, and the next sound starts a
# new one, ready in a tenth of a second. A shell still sets them (selftest
# runs sub sounding with this text by itself), and asks /bin/ps for its size.
my $SOUND_LIMITS = 'limit() { ulimit -S "$@" && ulimit -H "$@"; } && v=$(/bin/ps -o vsz= -p $$) && limit -t 600 && limit -f 0 && limit -c 0 && { limit -n 256 2>/dev/null || [ "$(ulimit -H -n)" -le 256 ] 2>/dev/null; } && limit -v $((v + ' . $PAGE_ROOM . ')) && exec /usr/bin/env -i "$@"';
my $DECODER_LIMITS = { bytes => 16 * 1024 * 1024, as => { TMPDIR => 'LZRPRF_TMPDIR' } };

# What a shell holds is the same each time, within a few hundred KiB of its
# 2 GiB room (measured 2026-11-24: 488781664 to 488782384 KiB over eight
# shells, with and without variables). So one shell is measured once, as a
# window begins, and every container is given that number and 2 GiB more; the
# tries that follow (sub holds) start their containers with it, so they prove
# the limit it sets. Before that number is had, the first container to start
# measures it.
my $SHELL_HELD;                           # KiB, as /bin/ps says a shell holds
sub shell_held {
    my ($said) = said(5, '/bin/sh', '-c', 'v=$(/bin/ps -o vsz= -p $$) && echo "$v"');
    my ($v) = ($said // '') =~ /^\s*([0-9]{1,15})\s*\z/ or return;
    return $v;
}
sub shell_measured { $SHELL_HELD = shell_held(); return defined $SHELL_HELD }

# A container's limits are set by lzrprf itself, in the process it made for
# the container (sub become), after it closed every descriptor but three
# (sub seal) and just before that process becomes sandbox-exec, which puts
# itself into the container and becomes the program. Why that is as strong as
# the shell it replaced: a limit is the kernel's, kept by a process through
# every program it becomes; the shell set it with setrlimit, and lzrprf calls
# the same setrlimit (by its number in the system's table of calls, 195, as
# the tries call mmap by 197), with the same numbers, as the limit that
# counts now and the limit that may not be raised again together, so the
# program can raise neither. The variables are replaced whole by the ones
# named, so sandbox-exec and the program see those alone, as "env -i" did.
# Nothing else is started in between, and no step of the program lzrprf is
# left to run after a limit could not be set: the process ends, and the
# container never starts. The memory limit is set last, and the system will
# not set it below what the process holds already (EINVAL; measured
# 2026-11-24 with 3 GiB taken first). A copy of an lzrprf that grew past a
# shell and 2 GiB therefore becomes a small perl first, which sets it and
# then becomes sandbox-exec ($ROOM_SET): one program more, only then.
# selftest takes each limit out of a copy of lzrprf in turn, and the tries
# show it is missed (lostmemory, lostfiles, lostsoft); the tries of every
# start prove each one holds in the page and decoder containers.
my $ROOM_SET = 'syscall(195, 5, pack("QQ", $ARGV[0], $ARGV[0])) == 0 or exit 127; shift; exec { $ARGV[0] } @ARGV; exit 127';
sub limited {                             # the process about to become @$command given a container's limits and variables; false when one could not be set, and then it starts nothing
    my ($limits, $command) = @_;
    my $held = $SHELL_HELD // ($SHELL_HELD = shell_held()) // return 0;
    my $room = ($held + $PAGE_ROOM) * 1024;    # in bytes
    my %told = (map({ ($_ => $ENV{$_} // '') } @{ $limits->{told} || [] }), map({ length($ENV{$_} // '') ? ($_ => $ENV{$_}) : () } @{ $limits->{set} || [] }), map({ ($_ => $ENV{ $limits->{as}{$_} } // '') } keys %{ $limits->{as} || {} }));
    my $hard = sub { my $was = pack('QQ', 0, 0); syscall(194, $_[0], $was) == 0 ? (unpack 'QQ', $was)[1] : ~0 };    # getrlimit: the limit that may not be raised
    my $set = sub { syscall(195, $_[0], pack('QQ', $_[1], $_[1])) == 0 };    # setrlimit: the limit that counts now and the one that may not be raised again, both
    $set->(0, 30) or return 0;            # seconds of processor time (RLIMIT_CPU)
    $set->(1, $limits->{bytes}) or return 0;    # the bytes of any file it writes (RLIMIT_FSIZE)
    $set->(4, 0) or return 0;             # no memory dump (RLIMIT_CORE)
    $set->(8, 256) || $hard->(8) <= 256 or return 0;    # open files (RLIMIT_NOFILE): 256, or a lower limit already set that no process may raise
    $set->(5, $room) or $!{EINVAL} && unshift(@$command, '/usr/bin/perl', '-e', $ROOM_SET, $room) or return 0;    # memory (RLIMIT_AS), last
    %ENV = %told;
    return 1;
}

# The window's container. A window needs the system's services, so this one
# is written the other way round: what a program of yours may do, without
# the things below. No network of any kind. No writing of any file. No
# starting of any program but the one it is, in this same container. No asking the system to open an address, a file
# or another program for it. No command to another program. No writing of
# your settings. No system service but the ones named below, so no asking the system's downloader to fetch for it. No
# signal to any other process. No reading under /Users or on another disk, apart from your settings, your
# fonts, keyboard layouts and input methods. No file of the application is
# read: the icon in the Dock is drawn by the lines of "icon" in window_text.
# What it reads on descriptor 0 and writes on descriptor 1 is its talk with
# lzrprf.
# Of each browser's own folder that [C15] names, and the folders above it, it may know that it is
# there and no more, so that the import's Open panel can open at it [C15].
# The system services it may look up by name are listed one by one: 41 that
# a window's process was seen to ask for on macOS build 26B123 (drawing,
# fonts, typing, the clipboard, the Dock and the menu bar, settings, the
# log, sound, privacy prompts, launch services, Apple events, notifications),
# the system's video decoder service, which decodes a video you clicked
# (sub videoed; the window has no decoder of its own, and this one name is
# what lets the system's player in it show a picture) [C22], and one local
# name, the clipboard's. That each is needed was not tested,
# except for two: the video decoder (without it the system's player gives
# "Cannot Decode"; selftest plays a clip from inside this container, and
# not without the name), and the graphics card's shader compiler. The system draws a
# window's pictures on the graphics card and has it taught a new step for
# each new way of drawing one (another form of pixel, a scale while the
# window is resized or full screen); without the compiler the system ends
# the window's process at that moment (release 34; selftest compiles one
# from inside this container).
# Every other lookup by name is refused: the helper of the Services menu
# among them, which a window asks for too, because it lets another program
# act on what the window hands it. The clipboard is listed because you
# paste into the bar, and because a press on the copy button of the
# application's tool writes the rows you ticked there [C20].
# What this container does NOT refuse, said plainly: what a program of
# yours may do besides the things above, shared memory, devices and their
# drivers among it; and what a listed service hands back is not a lookup.
# So this container is weaker than the page container, and the README
# says what follows from that.                                         # [C10]
my $WINDOW_CONTAINER = <<'END';
(version 1)
(allow default)
(deny network*)
(deny file-write*)
(allow file-write* (literal "/dev/null"))
(deny process-fork)
(deny process-exec)
(allow process-exec (literal "/usr/bin/osascript"))
(deny lsopen)
(deny appleevent-send)
(deny user-preference-write)
(deny signal)
(allow signal (target self))
(deny mach-lookup)
(allow mach-lookup
  (global-name "com.apple.windowserver.active")
  (global-name "com.apple.CARenderServer")
  (global-name "com.apple.CoreDisplay.master")
  (global-name "com.apple.CoreDisplay.Notification")
  (global-name "com.apple.cvmsServ")
  (global-name "com.apple.MTLCompilerService")
  (global-name "com.apple.window_proxies")
  (global-name "com.apple.dock.server")
  (global-name "com.apple.dock.fullscreen")
  (global-name "com.apple.windowmanager.server")
  (global-name "com.apple.iohideventsystem")
  (global-name "com.apple.coreservices.launchservicesd")
  (global-name "com.apple.lsd.mapdb")
  (global-name "com.apple.CoreServices.coreservicesd")
  (global-name "com.apple.coreservices.appleevents")
  (global-name "com.apple.runningboard")
  (global-name "com.apple.distributed_notifications@Uv3")
  (global-name "com.apple.distributed_notifications@1v3")
  (global-name "com.apple.system.notification_center")
  (global-name "com.apple.cfprefsd.daemon")
  (global-name "com.apple.cfprefsd.agent")
  (global-name "com.apple.logd")
  (global-name "com.apple.diagnosticd")
  (global-name "com.apple.system.logger")
  (global-name "com.apple.fonts")
  (global-name "com.apple.FontObjectsServer")
  (global-name "com.apple.FontRegistry.FontRegistryUIAgent")
  (global-name "com.apple.colorsyncd")
  (global-name "com.apple.colorsync.useragent")
  (global-name "com.apple.tsm.uiserver")
  (global-name "com.apple.inputmethodkit.getxpcendpoint")
  (global-name "com.apple.inputmethodkit.launchagent")
  (global-name "com.apple.inputmethodkit.launcher")
  (global-name "com.apple.inputmethodkit.setxpcendpoint")
  (global-name "com.apple.pasteboard.1")
  (global-name "com.apple.iconservices")
  (global-name "com.apple.iconservices.store")
  (global-name "com.apple.audio.audiohald")
  (global-name "com.apple.audio.SystemSoundServer-OSX")
  (global-name "com.apple.coremedia.videodecoder")
  (global-name "com.apple.tccd")
  (global-name "com.apple.VoiceOver.running") (local-name "com.apple.CFPasteboardClient"))
(deny file-read* (subpath "/Users") (subpath "/Volumes") (subpath (param "HOME")) (subpath "/System/Volumes/Data/Users") (subpath "/System/Volumes/Data/Volumes") (subpath (string-append "/System/Volumes/Data" (param "HOME"))))
(allow file-read*
  (subpath (string-append (param "HOME") "/Library/Preferences")) (subpath (string-append (param "HOME") "/Library/Fonts"))
  (subpath (string-append (param "HOME") "/Library/Keyboard Layouts")) (subpath (string-append (param "HOME") "/Library/Input Methods"))
  (subpath (string-append "/System/Volumes/Data" (param "HOME") "/Library/Preferences")) (subpath (string-append "/System/Volumes/Data" (param "HOME") "/Library/Fonts"))
  (subpath (string-append "/System/Volumes/Data" (param "HOME") "/Library/Keyboard Layouts")) (subpath (string-append "/System/Volumes/Data" (param "HOME") "/Library/Input Methods")))
(allow file-read-metadata (literal "/Users") (literal "/Volumes") (literal (param "HOME")) (literal (string-append (param "HOME") "/Library")))
(allow file-read-metadata (literal (string-append (param "HOME") "/Library/Safari"))
  (literal (string-append (param "HOME") "/Library/Application Support")) (literal (string-append (param "HOME") "/Library/Application Support/Google")) (literal (string-append (param "HOME") "/Library/Application Support/Google/Chrome")) (literal (string-append (param "HOME") "/Library/Application Support/Microsoft Edge"))
  (literal (string-append (param "HOME") "/Library/Application Support/BraveSoftware")) (literal (string-append (param "HOME") "/Library/Application Support/BraveSoftware/Brave-Browser")) (literal (string-append (param "HOME") "/Library/Application Support/Vivaldi")) (literal (string-append (param "HOME") "/Library/Application Support/Firefox")))
END

sub contain {
    my ($more, $program, @rest) = @_;
    my $own = $program =~ m{^(.*\.app)/Contents/MacOS/[^/]+$} ? $1 : $program;
    my @above;                            # the folders above the program: it may know they exist, and no more
    for (my $up = $own; $up =~ s{/[^/]+$}{} && length $up;) { push @above, qq{(literal "$up")} }
    die "lzrprf: the program's path holds a character lzrprf does not pass on\n" if $own =~ /["\\\n]/;
    return ('/usr/bin/sandbox-exec', '-D', "APP=$program", '-D', "OWN=$own", @rest, '-p', "$CONTAINER  @above)\n$more", $program);
}

# A program started in the decoder container for the picture in $folder: it
# reads $folder/in, writes $folder/out.png, and keeps its temporary file in
# $folder/t, under the decoder's limits, told its TMPDIR alone. Nothing, for
# a folder whose name holds a character the container's text cannot hold:
# it runs in a picture's process, which ends by itself and says why. # [C21]
sub decoding {
    my ($folder, $program, @arguments) = @_;
    return if $folder =~ /["\\\n]/;
    my @above = (qq{(literal "$folder")});    # the picture's folder and those above it: it may know they exist, and no more
    for (my $up = $folder; $up =~ s{/[^/]+$}{} && length $up;) { push @above, qq{(literal "$up")} }
    return ($DECODER_LIMITS, contain("$DECODER(allow file-read-metadata @above)\n", $program, '-D', "IN=$folder/in", '-D', "OUT=$folder/out.png", '-D', "TMP=$folder/t"), @arguments);
}

# A program started in the converter container for the stream in $folder:
# it reads $folder/in.ts, writes $folder/out.mp4, and keeps its copy in
# $folder/t, under the converter's limits, told its TMPDIR alone. Nothing for
# a folder whose name the container's text cannot hold.                # [C24]
sub converting {
    my ($folder, $program, @arguments) = @_;
    return if $folder =~ /["\\\n]/;
    my @above = (qq{(literal "$folder")});    # the stream's folder and those above it: it may know they exist, and no more
    for (my $up = $folder; $up =~ s{/[^/]+$}{} && length $up;) { push @above, qq{(literal "$up")} }
    return ($CONVERT_LIMITS, contain("$CONVERTER(allow file-read-metadata @above)\n", $program, '-D', "IN=$folder/in.ts", '-D', "OUT=$folder/out.mp4", '-D', "TMP=$folder/t"), @arguments);
}

# Starting a program. Whatever lzrprf starts is handed three descriptors that
# lzrprf chose, and no other: not a file, a socket or a terminal that was open
# in lzrprf or in whoever started lzrprf.
sub seal {
    opendir(my $open, '/dev/fd') or POSIX::_exit(127);
    my @numbers = grep { /^\d+$/ && $_ > 2 } readdir $open;
    closedir $open;
    POSIX::close($_) for @numbers;
}

sub become {                              # this process turns into @command; a descriptor that is not given leads nowhere
    my ($in, $out, $err, @command) = @_;
    my $limits = ref $command[0] ? shift @command : undef;    # a container's limits, first, when @command starts one (sub limited)
    my $nowhere = POSIX::open('/dev/null', O_RDWR) // POSIX::_exit(127);
    my @given = map { POSIX::dup(defined $_ ? fileno $_ : $nowhere) // POSIX::_exit(127) } $in, $out, $err;
    POSIX::dup2($given[$_], $_) // POSIX::_exit(127) for 0 .. 2;
    seal();
    limited($limits, \@command) or POSIX::_exit(127) if $limits;
    { no warnings; exec { $command[0] } @command; }
    POSIX::_exit(127);
}

# What a program printed within some seconds; and whether it ended by itself,
# without an error, in that time. When the time is over it is ended. With
# $SAID_INSIDE set, the system is asked first whether the program is in its
# container (sub inside), by the number fork gave, while the program waits
# on its input for lzrprf's one byte and so is surely there to be asked
# about; when the system does not say so, or the byte cannot be written, the
# program is ended, and whether it ended well is undef.
our $SAID_INSIDE = 0;
sub said {
    my ($seconds, @command) = @_;
    pipe(my $from, my $to) or return ('', 0);
    my ($gate, $open) = (undef, undef);   # with $SAID_INSIDE, the program waits on its input for one byte, sent once the system said it is contained (the decoder's gate, sub system_decoded)
    pipe($gate, $open) or return ('', 0) if $SAID_INSIDE;
    my $child = fork // return ('', 0);
    if (!$child) {
        close $from;
        close $open if $open;
        become($gate, $to, undef, @command);
    }
    close $to;
    close $gate if $gate;
    if ($SAID_INSIDE) {
        my $went = inside($child) && do { local $SIG{PIPE} = 'IGNORE'; syswrite($open, 'g') };    # a write to a process that is gone fails at once: it was not there to be asked about
        close $open;
        if (!$went) { ended($child, 0); return ('', undef) }
    }
    my ($text, $until, $whole) = ('', now() + $seconds, 0);
    while ((my $left = $until - now()) > 0 && length $text < 4 * 1024 * 1024) {
        my $ready = '';
        vec($ready, fileno $from, 1) = 1;
        select($ready, undef, undef, $left > 1 ? 1 : $left) > 0 or next;
        my $got = sysread($from, $text, 65536, length $text);
        next if !defined $got && $!{EINTR};
        $whole = 1 if defined $got && !$got;
        last unless $got;
    }
    return ($text, ended($child, $whole ? 2 : 0) == 0 && $whole);
}

# What several programs printed, each within the same seconds, all of them
# started at once and read side by side: one answer each, in the order asked.
sub said_all {
    my ($seconds, @commands) = @_;
    my (@from, @child);
    for my $at (0 .. $#commands) {
        pipe(my $from, my $to) or next;
        my $child = fork // next;
        if (!$child) {
            close $_ for $from, grep { defined } @from;
            become(undef, $to, undef, @{ $commands[$at] });
        }
        close $to;
        ($from[$at], $child[$at]) = ($from, $child);
    }
    my @text = map { '' } @commands;
    my $until = now() + $seconds;
    while ((my $left = $until - now()) > 0 && grep { defined } @from) {
        my $ready = '';
        vec($ready, fileno $_, 1) = 1 for grep { defined } @from;
        select($ready, undef, undef, $left > 1 ? 1 : $left) > 0 or next;
        for my $at (grep { defined $from[$_] && vec($ready, fileno $from[$_], 1) } 0 .. $#from) {
            my $got = sysread($from[$at], $text[$at], 65536, length $text[$at]);
            next if !defined $got && $!{EINTR};
            undef $from[$at] if !$got || length $text[$at] > 1024 * 1024;
        }
    }
    ended($_, 0) for grep { defined } @child;
    return @text;
}

sub ended {                               # waits this long for a process to end, then ends it; returns how it ended
    my ($pid, $patience) = @_;
    my $until = now() + $patience;
    while (1) {
        my $gone = waitpid $pid, POSIX::WNOHANG();
        return $? if $gone == $pid;
        return -1 if $gone < 0;
        last if now() >= $until;
        select undef, undef, undef, 0.02;
    }
    kill 'KILL', $pid;
    waitpid $pid, 0;
    return $? || -1;
}

# The proof that the containers hold, in two parts. Neither rests on what the
# application says about itself.
#
# The first part is made at every start. A small program, the text below, is
# run inside the page container: the same container text, the same way of
# starting, with the same limits. It tries eight things the container must
# refuse, each against something that is really there (a listener lzrprf
# opened a moment ago, a file lzrprf wrote a moment ago, lzrprf's own
# process, 3 GiB of memory). Then the same program is run outside every
# container and without the limits, where each of the eight must work:
# so a refusal inside is the container's, not a try that could never have
# worked. In the decoder's container, sips says its version, and behind
# the gate that waits for lzrprf's byte ($GATE), sent none, it says nothing:
# it never started. Unless all of that holds, nothing is started.        # [C2]
my $TRIES = <<'END';
use Socket;
my ($port, $folder, $pid) = @ARGV;
$| = 1;
socket(my $s, AF_INET, SOCK_STREAM, 0);
print 'network ', (connect($s, pack_sockaddr_in($port, inet_aton('127.0.0.1'))) ? 'done' : 'refused'), "\n";
print 'read ', (open(my $in, '<', "$folder/here") ? 'done' : 'refused'), "\n";
print 'write ', (open(my $out, '>', "$folder/made") ? 'done' : 'refused'), "\n";
print 'hard link ', (link("$folder/here", "$folder/out.png") ? 'done' : 'refused'), "\n";    # a second name for a file of yours, in the one place the decoder may write
print 'signal ', (kill(0, $pid) ? 'done' : 'refused'), "\n";
print 'memory ', (syscall(197, 0, 3 * 1024**3, 3, 0x1002, -1, 0) != -1 ? 'done' : 'refused'), "\n";    # asks for 3 GiB of addresses (mmap) and touches none of it
my $child = fork;
exit 0 if defined $child && !$child;
print 'second process ', (defined $child ? 'done' : 'refused'), "\n";
{ no warnings; exec '/usr/bin/true'; }
print "other program refused\n";
END

sub holds {
    my $listen = IO::Socket::INET->new(Listen => 4, LocalAddr => '127.0.0.1', LocalPort => 0) or return 0;
    my $folder = (abs_path($DIR) // return 0) . "/tries.$$";    # the folder's real path, as the decoder container names it (sub decoding)
    mkdir $folder or return 0;
    put("$folder/here", O_EXCL, 'a file of yours') or return 0;
    my @tries = ('-e', $TRIES, $listen->sockport, $folder, $$);
    shell_measured();                     # before the tries, so they hold with the number every later container is given
    my ($inside) = said(10, $PAGE_LIMITS, contain('', '/usr/bin/perl'), @tries);    # started as a page is started, limits and all
    my ($decoder) = do { local $ENV{LZRPRF_TMPDIR} = "$folder/t/"; said(10, decoding($folder, '/usr/bin/perl', @tries)) };    # [C21] and as the system's decoder is, for a picture beside the file it tries: in, out.png and t are its, "here" and "made" are not
    my ($sips, undef, $gated, $gate_well) = do { local $ENV{LZRPRF_TMPDIR} = "$folder/t/"; (said(10, decoding($folder, $SIPS, '--version')), said(10, decoding($folder, '/usr/bin/perl', '-e', $GATE, $SIPS, '--version'))) };    # [C3] [C21] sips says its version in the decoder container, and behind the gate, sent no byte (its input leads nowhere), it never starts
    my ($outside) = said(10, '/usr/bin/perl', @tries);
    unlink "$folder/here", "$folder/made", "$folder/out.png";
    my $named = decoder_named($folder);    # [C21] the one system service the decoder may ask for, and no other
    rmdir $folder;
    my @what = ('network', 'read', 'write', 'hard link', 'signal', 'memory', 'second process');
    my $refused = join('', map { "$_ refused\n" } @what, 'other program');
    my $gate_held = $sips =~ /^sips-\d+\n\z/ && $gated eq '' && !$gate_well;    # [C3] [C21] the gate ended as it does with no byte, not well, and sips said nothing
    return $named && $gate_held && $inside eq $refused && $decoder eq $refused && $outside eq join('', map { "$_ done\n" } @what);    # outside, the last try turns the program into another one, which says nothing
}

# The decoder container lets sips ask for one system service by its name,
# the video decoder service, and no other. While a process waits in that
# container, the system is asked by the process's number, as for every
# process (sub inside), whether it may ask for that service, and whether it
# may ask for the clipboard's (com.apple.pasteboard.1), which it must not:
# so the one rule lets one name through, and not every name. The system's
# function takes the name after a list of arguments of any length, which on
# Apple silicon stands in memory after eight in registers: the five zeros
# put it there. That is the arm64 calling convention, and only that: lzrprf
# runs on Apple silicon alone, and on an Intel Mac the name would be read
# from a register and the question would name nothing.                   # [C21]
my $NAMED = <<'END';
ObjC.import('Foundation');
ObjC.bindFunction('sandbox_check', ['int', ['int', 'char *', 'int', 'int', 'int', 'int', 'int', 'int', 'char *']]);
function run(argv) {
    var pid = +argv[0];
    return ['com.apple.coremedia.videodecoder', 'com.apple.pasteboard.1'].map(function (name) { return $.sandbox_check(pid, 'mach-lookup', 2, 0, 0, 0, 0, 0, name); }).join(' ');
}
END
sub decoder_named {
    my ($folder) = @_;
    my @command = decoding($folder, '/usr/bin/perl', '-e', 'sysread STDIN, my $x, 1') or return 0;
    pipe(my $wait, my $go) or return 0;
    my $child = fork // return 0;
    if (!$child) { $ENV{LZRPRF_TMPDIR} = "$folder/t/"; close $go; become($wait, undef, undef, @command) }
    close $wait;
    my ($said) = inside($child) ? said(10, $SCRIPT, '-l', 'JavaScript', '-e', $NAMED, $child) : ('');
    close $go;
    ended($child, 2);
    return $said eq "0 1\n";
}

# The second part is made for every process. The system keeps, for each
# process, the container it was put in, and answers questions about it. One
# small process, the text below, asks the system: may this process use the
# network, create a file, start a second process, reach a system service?
# Only when the system says no to all four is the process handed anything:
# a page container the site's answer, curl the connection to the site. The
# question is put to the system, by number of the process. Nothing is asked
# of the process itself. The window's process is asked about in the same
# way before it takes an address: no to the same four, and no to opening
# something through the system, to commanding another program, to writing
# your settings and to a signal. For the window the fourth question names
# no service: the no says that its container refuses a system service by
# default, and nothing of which names its list lets through. selftest
# asks for six by name from the real window.                              # [C3]
my $WITNESS = <<'END';
ObjC.import('Foundation');
ObjC.bindFunction('sandbox_check', ['int', ['int', 'char *', 'int']]);
function run() {
    var from = $.NSFileHandle.fileHandleWithStandardInput, to = $.NSFileHandle.fileHandleWithStandardOutput, held = '';
    while (true) {
        var data = from.availableData;
        if (data.length == 0) return;
        held += $.NSString.alloc.initWithDataEncoding(data, 4).js;
        for (var at; (at = held.indexOf('\n')) >= 0; held = held.slice(at + 1)) {
            var pid = parseInt(held.slice(0, at), 10);
            var refused = ['network-outbound', 'file-write-create', 'process-fork', 'mach-lookup', 'lsopen', 'appleevent-send', 'user-preference-write', 'signal'].map(function (what) { return $.sandbox_check(pid, what, 0); });
            to.writeData($(pid + ' ' + refused.join(' ') + '\n').dataUsingEncoding(4));
        }
    }
}
END
my ($witness, $to_witness, $from_witness, $witness_of) = (undef, undef, undef, 0);

sub witnessed {                           # the one that answers is running, started now when it was not: true when it is
    return 1 if $witness;
    pipe(my $asked, $to_witness) && pipe($from_witness, my $told) or return 0;
    $witness = fork // return 0;
    become($asked, $told, undef, $SCRIPT, '-l', 'JavaScript', '-e', $WITNESS) unless $witness;
    $witness_of = $$;
    close $_ for $asked, $told;
    $to_witness->autoflush(1);
    return 1;
}

# A process that ended and was not yet waited for (a zombie) is still there
# by its number, and the system answers 1 for it to every question, as for
# a process that is gone: so inside() calls such a process contained. That
# says nothing of a process that ran, so every caller must hold the process
# it asks about before it does anything of its own, until the answer came:
# curl, the application and the sips gate ($GATE) each wait for lzrprf's
# word, so one that ended while it was asked about ended having done nothing.
sub inside {                              # true when the system says that this process is contained; it is asked for ten seconds from its first question, and then the answer is no
    my ($pid, $window) = @_;
    my $contained = $window ? qr/^\Q$pid\E 1 1 1 1 1 1 1 1\n\z/ : qr/^\Q$pid\E 1 1 1 1 [01] [01] [01] [01]\n\z/;    # the page and fetch containers refuse everything; what the last four say of them is not what holds them
    my $lost = sub {                      # the one that answers did not answer: it is ended, so that no late answer of its is ever read as the answer to a later question
        return 0 if $witness_of != $$;    # by the process that started it alone: a picture's run beside others asks lzrprf's and ends nothing of lzrprf's
        kill 'KILL', $witness;
        waitpid $witness, 0;
        close $_ for $to_witness, $from_witness;
        undef $witness;
        return 0;
    };
    witnessed() or return 0;
    return 0 if !kill(0, $pid) && $!{ESRCH};    # a process that is gone is said to refuse everything (measured 2026-11-21, an ended one too): nothing of it can be asked, and no is the answer, at once
    my $until;                            # ten seconds from the first question, never counting the wait for the turn: on a busy computer, pages asked about side by side spent two seconds in that wait alone and a contained page was refused (seen 2026-11-21 in two installs)
    open my $turn, '<', $SELF or return 0;    # one question at a time: the runs that fetch a page's pictures side by side ask the same one, and each must read the answer to its own question, not another's
    while (!defined $until || now() < $until) {
        flock $turn, LOCK_EX or return 0; $until //= now() + 10;
        print $to_witness "$pid\n" or return $lost->();
        my $ready = '';
        vec($ready, fileno $from_witness, 1) = 1;
        select($ready, undef, undef, ($until - now() > 2 ? $until - now() : 2) + 0.5) > 0 or return $lost->();    # an answer always has two seconds, also when a later turn came after the ten
        my $says = readline($from_witness) // return $lost->();
        flock $turn, LOCK_UN;
        return 1 if $says =~ $contained;
        select undef, undef, undef, 0.002;    # not yet: the process is still being put into its container, which takes about 25 ms; asked again 2 ms on, so the answer comes no more than 2 ms after it is true (10 ms cost a page 5 ms a container, measured 2026-11-24)
    }
    return 0;
}

