
# LZRTRMNL, a terminal in a tab [C29]. It starts on a press of the terminal
# icon of the local home and on nothing else, and never in an incognito or a
# Tor window. Three processes make it, each with as little as it needs:
#
# - lzrprf, outside every container and as you, opens a pseudo-terminal of
#   the system (/dev/ptmx) and starts your login shell on its other end: the
#   shell the system names for your account and lists in /etc/shells, in your
#   home folder, with a short list of variables and no descriptor of lzrprf's.
#   That shell runs with your rights, as one in Terminal does: that is what a
#   terminal is for.
# - core-lzrbrwsr-trmnl, a program of the application, in a container of its
#   own, $TRMNL_CONTAINER, narrower than the page's: it keeps the screen and
#   draws it as the lines of a laid page. It holds no descriptor of the
#   terminal; lzrprf hands it what the shell wrote, "o LEN" and the bytes, and
#   the size of the tab, "s WIDE HIGH". It has no network, reads no file but
#   its own program and the system's shared libraries, writes none, starts
#   nothing, and gets no variable but its seal.
# - the window, which draws those lines as it draws a page and says the keys.
#
# What scrolled off is kept by the container, in a ring of at most 5,000 rows
# and 256 KiB; the wheel and Shift-Page Up and Down look back in it, and what
# the shell writes brings the tab back to its screen. A press and a drag
# select; your copy (Cmd-C) has the container hand lzrprf the selected text,
# each row checked as text, which lzrprf hands the window to write to the
# clipboard (sub trmnl_copied). Your paste (Cmd-V) is the one moment the
# window reads the clipboard: it hands lzrprf the text, and lzrprf writes it to
# the shell with no control character but tabs and line ends, between ESC
# [200~ and ESC [201~ when the shell asked for that (sub trmnl_pasted). A
# title a program sets (OSC 0 or 2) is the tab's title, as plain text of at
# most $TRMNL_TITLE characters (sub trmnl_titled). Nothing a program writes
# ever reaches the clipboard: OSC 52 is passed over.
#
# A key goes from the window to lzrprf, which writes it into the terminal in
# the one fixed form each named key has (sub trmnl_input). Nothing the
# container says is ever written to the shell, but for the answers a terminal
# gives when a program asks it (its status, where its cursor is, what kind of
# terminal it is), each only after the shell wrote that question, once for
# each question, in its one form, with numbers inside the screen
# (sub trmnl_replied). Each line the container draws is checked as a line of
# a laid page is (sub laid_run), so it can draw nothing a page could not.
#
# The container's allow list, and why each entry is in it. Everything else is
# refused (deny default), and so is mapping any file as code. Measured on
# macOS 27.2 by taking each entry out in turn: the program does not start
# without any one of them, and starts with these alone.
#   process-exec of the program itself: sandbox-exec turns into it.
#   file-read* of the program: the system reads it to run it.
#   file-read* of the system's cryptex: the shared cache of the system
#     libraries the program links (libSystem), where macOS keeps it.
#   file-read* of "/" itself (not what is under it): the loader reads the
#     root folder once as it starts.
#   sysctl-read of hw.pagesize_compat alone: the size of a memory page, which
#     the program's runtime reads to place its stack's guard page.
# Its limits ($TRMNL_LIMITS): no byte written to a file, no memory dump, at
# most 16 open files, no more memory than its shell holds plus 64 MiB. No
# limit of processor time: a terminal stays open as long as you keep it.
my $TRMNL_CONTAINER = <<'END';
(version 1)
(deny default)
(deny syscall-unix (syscall-number SYS_shmget SYS_semget SYS_msgget))
(allow process-exec (literal (param "APP")))
(deny file-map-executable)
(allow file-read* (subpath "/System/Volumes/Preboot/Cryptexes") (literal "/") (literal (param "APP")))
(allow sysctl-read (sysctl-name "hw.pagesize_compat"))
END
my $TRMNL_LIMITS = 'limit() { ulimit -S "$@" && ulimit -H "$@"; } && v=$(/bin/ps -o vsz= -p $$) && limit -f 0 && limit -c 0 && { limit -n 16 2>/dev/null || [ "$(ulimit -H -n)" -le 16 ] 2>/dev/null; } && limit -v $((v + 65536)) && exec /usr/bin/env -i "LZRPRF_SEAL=$LZRPRF_SEAL" "$@"';
my $TRMNL_PROGRAM = 'core-lzrbrwsr-trmnl';    # its file name is the name Activity Monitor shows (docs/process-names.md)
my $TRMNL_FEED = 262_144;                 # the most of what the shell wrote held for the container: past it lzrprf reads no more of the terminal, and the shell waits in its write
my $TRMNL_LINE = 9000;                    # the longest line the container may write: a run of 2000 characters of up to four bytes each, and its head
my $TRMNL_ROW = 420;                      # the most lines one row of the screen may be drawn with (DECLARED: src/trmnl/draw.rs ROW_R + ROW_X + the cursor)
my $TRMNL_KEYS = 131_072;                 # the most of your keys held while the shell does not read them: a whole paste and the keys around it
my $TRMNL_PASTE = 65_536;                 # the most bytes one paste writes (DECLARED: the window's trmnlPaste)
my $TRMNL_COPY = 262_144;                 # the most bytes one copy hands the clipboard (DECLARED: src/trmnl/scroll.rs COPY_MOST)
my $TRMNL_COPY_ROWS = 5120;               # the most rows of one copy: the scrollback's 5,000 and a screen's 120 (DECLARED: src/trmnl/scroll.rs ROWS_MOST, src/trmnl/grid.rs MOST_ROWS)
my $TRMNL_TITLE = 80;                     # the most characters of a title a program sets (DECLARED: src/trmnl/scroll.rs TITLE_CHARS)
my %TRMNL_NAMED = (Space => ' ', Enter => "\r", Tab => "\t", Backspace => "\x7f", Escape => "\e", Delete => "\e[3~", PageUp => "\e[5~", PageDown => "\e[6~");
my %TRMNL_CURSOR = (ArrowUp => 'A', ArrowDown => 'B', ArrowRight => 'C', ArrowLeft => 'D', Home => 'H', End => 'F');    # after ESC [, or ESC O while the shell asked for the cursor keys' other form
my %TRMNL_ASKS = (status => qr/\e\[5n/, cursor => qr/\e\[6n/, primary => qr/\e\[0?c/, secondary => qr/\e\[>0?c/);    # the questions a program writes to its terminal, by the answer each wants

# The press: a new tab, with the terminal's containers started in it, one a
# pane: the tabs and views saved for this profile, or one pane
# (24-trmnl-panes.pl). Each pane's shell is started once its container said
# the size of its screen.
sub trmnl_opened {
    $TRMNL_OPEN = 0;
    return idle('An incognito or Tor window opens no terminal: a shell writes its history to your disk, which such a window promises not to do.') if $INCOGNITO || $TOR_WINDOW;
    return idle('LZRTRMNL is not installed. Add it in Add or remove LZR modules, in the cogwheel menu.') unless part_on('lzrtrmnl');
    return idle("A window holds $TABS_MOST tabs at most: close one to open LZRTRMNL.") if @TABS >= $TABS_MOST;
    my ($w, $why) = trmnl_workspace();
    return idle($why) unless $w;
    $TABS[$TAB]{shown} = $SHOWN;
    push @TABS, fresh_tab();
    $TAB = $#TABS;
    undef $SHOWN;
    @{ $TABS[$TAB] }{qw(title trmnl says)} = ('LZRTRMNL', $w, 'LZRTRMNL: your login shell, as you, drawn by a container of its own that has no network and writes no file.');
    noted('you opened LZRTRMNL: your login shell, drawn in a container of its own');
    tab_shown();
    live_told();
}

sub trmnl_program {                       # the drawing program beside this application, as it was installed: its path, or nothing and why in full
    my $program = dirname($PROGRAM) . "/$TRMNL_PROGRAM";
    my ($named) = map { /^file \Q$TRMNL_PROGRAM\E ([0-9a-f]{64})$/ ? $1 : () } release_lines();
    return (undef, 'LZRTRMNL is not installed beside this application, so no terminal was opened') unless -f $program && -x _;
    return (undef, 'LZRTRMNL is not the program this application was installed with, so no terminal was opened. Installing again mends it') if $PROGRAM =~ m{\.app/Contents/MacOS/} && (!defined $named || $named ne (sum_of($program) // ''));    # read again for each pane, as the page's program is read again before each run (sub contained)
    return $program;
}

sub trmnl_started {                       # a pane's container, started and said to be contained by the system, handed its seal: the pane's record, its shell to start in $cwd, or nothing and why
    my ($program, $cwd) = @_;
    return (undef, 'its path holds a character lzrprf does not pass on') if $program =~ /["\\\n]/;
    pipe(my $in, my $to) && pipe(my $from, my $out) or return (undef, 'no pipe was to be had');
    my $seal = run_seal() // return (undef, 'no seal was to be had');
    my $box = fork // return (undef, 'no process was to be had');
    if (!$box) {
        %ENV = (LZRPRF_SEAL => $seal);
        chdir '/';
        become($in, $out, $TRY ? \*STDERR : undef, '/bin/sh', '-c', $TRMNL_LIMITS, 'lzrprf', '/usr/bin/sandbox-exec', '-D', "APP=$program", '-p', $TRMNL_CONTAINER, $program);    # [C29]
    }
    close $_ for $in, $out;
    if (!inside($box)) {                  # [C3] it waits for its seal on its input, so it is there to be asked about
        kill 'KILL', $box;
        waitpid $box, 0;
        return (undef, 'the system did not say that its container holds');
    }
    fcntl($_, POSIX::F_SETFL(), O_NONBLOCK) for $to, $from;
    my $t = { box => $box, to => $to, from => $from, feed => "=seal $seal\n", heard => '', keys => '', size => [0, 0], laid => undef, head => [], rows => [], tally => [], asked => {}, tail => "", ckm => 0, cwd => $cwd, mtail => '', mouse => 0, sgr => 0, pressed => 0 };    # its size is told once it is laid out (sub trmnl_layout)
    return $t;
}

sub trmnl_sized {                         # the size of a pane, in points, to its container, when it is not the size it was told last
    my ($t) = @_;
    return unless $t->{rect} && $t->{to};
    my ($wide, $high) = @{ $t->{rect} }[2, 3];
    return if "$wide $high" eq ($t->{told} // '');
    $t->{told} = "$wide $high";
    trmnl_send($t, "s $wide $high\n");
}

# Your shell, on the other end of a terminal of the system, the size of the
# screen the container said. Nothing when the system gives no terminal or the
# shell is not one it lists.
sub trmnl_shell {
    my ($t, $cols, $rows) = @_;
    my ($user, $home, $shell) = (getpwuid $<)[0, 7, 8];
    open my $listed, '<', '/etc/shells' or return 'the system lists no shell';
    my %shells = map { chomp; m{^/} ? ($_ => 1) : () } <$listed>;
    return 'your login shell is not one the system lists in /etc/shells' unless defined $shell && $shells{$shell} && -x $shell;
    sysopen(my $master, '/dev/ptmx', O_RDWR | POSIX::O_NOCTTY()) or return 'the system gave no terminal';
    my $name = "\0" x 128;
    ioctl($master, 0x20007454, 0) && ioctl($master, 0x20007452, 0) && ioctl($master, 0x40807453, $name) or return 'the system gave no terminal';    # TIOCPTYGRANT, TIOCPTYUNLK, TIOCPTYGNAME
    ($name) = $name =~ m{\A(/dev/ttys[0-9]{3,5})\0} or return 'the system gave a terminal of no name lzrprf knows';
    my $size = pack 'S4', $rows, $cols, 0, 0;
    my $lzr = lzr_bin();                  # [C20] the folder of lzr, the terminal's own command, first on the shell's PATH (sub lzr_bin)
    my %own = (HOME => $home, USER => $user, LOGNAME => $user, SHELL => $shell, PATH => (defined $lzr ? "$lzr:" : '') . '/usr/bin:/bin:/usr/sbin:/sbin', TERM => 'xterm-256color', COLORTERM => 'truecolor', TERM_PROGRAM => 'LZRTRMNL',
        LANG => ($ENV{LANG} // '') =~ /\A([A-Za-z0-9_.@-]{1,40})\z/ ? $1 : 'en_US.UTF-8', ($ENV{TMPDIR} // '') =~ m{\A(/[A-Za-z0-9_./-]{1,200})\z} ? (TMPDIR => $1) : ());
    my $pid = fork // return 'no process was to be had';
    if (!$pid) {
        POSIX::setsid() // POSIX::_exit(127);    # a session of its own, whose terminal this is
        sysopen(my $terminal, $name, O_RDWR) or POSIX::_exit(127);
        ioctl($terminal, 0x20007461, 0) // POSIX::_exit(127);    # TIOCSCTTY
        ioctl($terminal, 0x80087467, $size) // POSIX::_exit(127);    # TIOCSWINSZ
        $SIG{$_} = 'DEFAULT' for grep { !/^__/ } keys %SIG;    # lzrprf ignores SIGPIPE; your shell gets every signal back as it would in Terminal
        POSIX::sigprocmask(POSIX::SIG_SETMASK(), POSIX::SigSet->new);
        %ENV = %own;
        (defined $t->{cwd} && chdir $t->{cwd}) or chdir $home or chdir '/';    # the folder a saved or split pane's shell was in, else your home folder
        become($terminal, $terminal, $terminal, $shell, '-l');    # [C29] as you, a login shell; every other descriptor of lzrprf is closed (sub seal)
    }
    fcntl($master, POSIX::F_SETFL(), O_NONBLOCK);
    @$t{qw(master shell)} = ($master, $pid);
    return;
}

sub trmnl_send {                          # bytes for the container, written as it takes them
    my ($t, $bytes) = @_;
    $t->{feed} .= $bytes;
    trmnl_fed($t);
}

sub trmnl_fed {
    my ($t) = @_;
    return unless $t->{to} && length $t->{feed};
    my $n = syswrite($t->{to}, $t->{feed});
    if (defined $n) { substr($t->{feed}, 0, $n, '') }
    elsif (!$!{EAGAIN} && !$!{EINTR}) { $t->{lost} = 'its container stopped reading' }
}

sub trmnl_keys {                          # your keys, written into the terminal as the shell takes them
    my ($t) = @_;
    return unless $t->{master} && length $t->{keys};
    my $n = syswrite($t->{master}, $t->{keys});
    substr($t->{keys}, 0, $n, '') if defined $n;
}

# What the window says while a terminal's tab is shown: a key in its one
# form; text typed with a key that makes a character beyond ASCII, as UTF-8;
# a key held with Control, as the control character it makes; each to the
# focused pane's shell. A press, a drag, a right press, an item of a menu and
# a key of the terminal's own are sub trmnl_pressed's; what is no key (the
# wheel, a copy, a paste) is sub trmnl_viewed's, for the focused pane.
sub trmnl_input {
    my ($what) = @_;
    return cht_input($what) if $TABS[$TAB]{cht};    # [C32] the wheel in LZRCHT's tab, which takes the terminal's part of the window
    my $w = $TABS[$TAB]{trmnl} or return;
    return trmnl_pressed($TABS[$TAB], $what) if $what =~ /^(?:click|drag|context|menu|tkey) /;
    my $t = trmnl_shown_tab($w)->{focus};
    return trmnl_viewed($t, $what) if $what =~ /^(?:wheel|copy|paste|pastelong)(?: |\z)/ || $what =~ /^key Page(?:Up|Down) shift$/;
    return unless $t->{master};
    my $bytes;
    if ($what =~ /^key ([\x21-\x7e])(?: shift)?$/) { $bytes = $1 }    # the character the key makes, Shift already in it
    elsif ($what eq 'key Tab shift') { $bytes = "\e[Z" }
    elsif ($what =~ /^key ([A-Za-z]+)(?: shift)?$/ && defined $TRMNL_NAMED{$1}) { $bytes = $TRMNL_NAMED{$1} }
    elsif ($what =~ /^key ([A-Za-z]+)(?: shift)?$/ && defined $TRMNL_CURSOR{$1}) { $bytes = ($t->{ckm} ? "\eO" : "\e[") . $TRMNL_CURSOR{$1} }
    elsif ($what =~ /^ctrl ([a-z@\[\]\\^_])$/) { $bytes = chr(ord(uc $1) & 0x1f) }
    elsif ($what =~ /^text (.+)\z/s) {
        my $chars = $bytes = $1;
        return unless utf8::decode($chars) && $chars !~ /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]/;
    }
    return unless defined $bytes && length($t->{keys}) + length($bytes) <= $TRMNL_KEYS;
    $t->{keys} .= $bytes;
    trmnl_keys($t);
}

sub trmnl_viewed {                        # [C29] looking back, copying, pasting: the container is told, and only a paste reaches the shell (a press and a drag that select: sub trmnl_clicked)
    my ($t, $what) = @_;
    return if $t->{ended};
    my $page = ($t->{size}[1] || 2) - 1;
    if ($what =~ /^key Page(Up|Down) shift$/) { trmnl_send($t, ($1 eq 'Up' ? 'u' : 'd') . " $page\n") }
    elsif ($what =~ /^wheel (-?)([1-9][0-9]{0,2})$/) { trmnl_send($t, ($1 ? 'd' : 'u') . " $2\n") }
    elsif ($what eq 'copy') { $t->{copying} = 1; trmnl_send($t, "c\n") }
    elsif ($what eq 'pastelong') { aside("LZRTRMNL takes a paste of at most $TRMNL_PASTE bytes, so nothing was pasted.") }
    elsif ($what =~ /^paste (.+)\z/s) { trmnl_pasted($t, $1) }
}

sub trmnl_pasted {                        # [C29] what you pasted, which the window read from the clipboard on your paste alone: text for the shell, with no control character but tabs and line ends, so nothing pasted can move the cursor, end a bracketed paste or act as a key of its own
    my ($t, $said) = @_;
    return unless $t->{master} && length $said <= 3 * $TRMNL_PASTE && $said =~ /\A(?:[A-Za-z0-9_.!~*'()-]|%[0-9A-F]{2})+\z/;    # as the window's encodeURIComponent writes it
    (my $text = $said) =~ s/%([0-9A-F]{2})/chr hex $1/ge;
    return unless length $text <= $TRMNL_PASTE && utf8::decode($text);
    $text =~ s/\r\n?/\n/g;
    $text =~ s/[^\P{Cc}\t\n]//g;          # ESC and every other control character go
    $text =~ tr/\n/\r/;                     # a line end is Return, as a terminal sends it
    utf8::encode($text);
    return unless length $text;
    $text = "\e[200~$text\e[201~" if $t->{paste};    # the shell asked for it (mode 2004): it reads the paste as text, not as keys
    return aside('The shell has not read what was typed before, so nothing was pasted. Paste again in a moment.') if length($t->{keys}) + length($text) > $TRMNL_KEYS;
    $t->{keys} .= $text;
    trmnl_keys($t);
    trmnl_send($t, "d 100000\n");    # back to the screen, where the paste is
}

sub trmnl_copied {                        # [C29] the text you selected, from the container on your copy: each row text with no control character, handed to the window, which writes it to the clipboard
    my ($tab, $rows) = @_;
    my @rows = @$rows;
    for (@rows) { my $chars = $_; return unless utf8::decode($chars) && $chars !~ /\p{Cc}/ }
    my $text = join "\n", @rows;
    return if length $text > $TRMNL_COPY;
    if (!length $text) { aside('Nothing is selected: drag across the text, then copy.'); return 1 }
    (my $said = $text) =~ s/([%\x00-\x1f\x7f])/sprintf '%%%02X', ord $1/ge;
    return 1 unless $tab == $TABS[$TAB];
    window("trmnlcopy $said");
    my $chars = $text;
    utf8::decode($chars);
    aside('Copied ' . length($chars) . (length($chars) == 1 ? ' character' : ' characters') . ' to the clipboard.');
    return 1;
}

sub trmnl_titled {                        # [C29] a title a program set: its pane's title, as plain text of at most $TRMNL_TITLE characters, which names its terminal tab in the strip and, while it has the focus, the browser tab; none when it is empty
    my ($tab, $t, $title) = @_;
    return unless utf8::decode($title);
    $title =~ s/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]//g;
    $title =~ s/\s+/ /g;
    $title =~ s/\A | \z//g;
    $title = substr $title, 0, $TRMNL_TITLE;
    utf8::encode($title);
    return 1 if $title eq ($t->{title} // '');
    $t->{title} = length $title ? $title : undef;
    $t->{fresh} = 1;                      # the strip drawn again with it
    trmnl_retitled($tab);
    return 1;
}

sub trmnl_replied {                       # [C29] an answer the container gives, written to the shell only when it asked for one of that kind and not yet answered
    my ($t, $kind, $row, $col) = @_;
    $kind =~ s/ .*//;
    return unless $t->{master} && ($t->{asked}{$kind} // 0) > 0;
    $t->{asked}{$kind}--;
    return if $kind eq 'cursor' && ($row > $t->{size}[1] || $col > $t->{size}[0]);
    $t->{keys} .= { status => "\e[0n", cursor => "\e[$row;${col}R", primary => "\e[?1;2c", secondary => "\e[>0;0;0c" }->{$kind};
    trmnl_keys($t);
}

sub trmnl_reported {                      # [C29] a press you made, told to the shell as a program asked: only while lzrprf saw the shell ask for presses (DEC 1000, 1002 or 1003), once for each press of yours, at a cell inside the screen, as a left press and its release
    my ($t, $col, $row) = @_;
    return unless $t->{master} && $t->{mouse} && $t->{pressed} > 0 && $col <= $t->{size}[0] && $row <= $t->{size}[1];
    $t->{pressed}--;
    my $report = $t->{sgr} ? "\e[<0;$col;${row}M\e[<0;$col;${row}m" : $col <= 223 && $row <= 223 ? "\e[M" . chr(32) . chr(32 + $col) . chr(32 + $row) . "\e[M" . chr(35) . chr(32 + $col) . chr(32 + $row) : return;
    return if length($t->{keys}) + length($report) > $TRMNL_KEYS;
    $t->{keys} .= $report;
    trmnl_keys($t);
}

sub trmnl_moded {                         # the modes of presses the shell asked for, read by lzrprf itself in what it wrote: whether a press is told (1000, 1002, 1003) and in which form (1006)
    my ($t, $bytes) = @_;
    my $scan = $t->{mtail} . $bytes;
    while ($scan =~ /\e\[\?([0-9;]{1,40})([hl])/g) {
        my ($modes, $on) = ($1, $2 eq 'h');
        for (split /;/, $modes) { $t->{mouse} = $on if /^100[023]\z/; $t->{sgr} = $on if $_ eq '1006' }
    }
    $t->{pressed} = 0 unless $t->{mouse};    # a press made while no press was asked for is never told later
    $t->{mtail} = substr($scan, -44);
    $t->{mtail} =~ s/\A.*\e\[\?[0-9;]*[hl]//s;    # a request read whole is not read again
}

sub trmnl_wrote {                         # what a pane's shell wrote, to its container; the questions in it counted
    my ($tab, $t) = @_;
    my $got = sysread($t->{master}, my $bytes, 65536);
    return if !defined $got && ($!{EAGAIN} || $!{EINTR});
    return trmnl_gone($tab, $t) unless $got;    # the shell and all it started let go of the terminal (EIO), or it closed
    my $scan = $t->{tail} . $bytes;
    for my $kind (keys %TRMNL_ASKS) {
        while ($scan =~ /$TRMNL_ASKS{$kind}/g) { $t->{asked}{$kind}++ if pos($scan) > length $t->{tail} && ($t->{asked}{$kind} // 0) < 8 }    # a question that ended in the bytes before was counted then
    }
    $t->{tail} = substr($scan, -4);
    trmnl_moded($t, $bytes);
    trmnl_send($t, 'o ' . length($bytes) . "\n" . $bytes);
}

sub trmnl_gone {                          # a pane's shell ended: the pane closes, as in the common terminals; the last pane stays as it was, with a line that says so, and takes no more keys
    my ($tab, $t) = @_;
    close $t->{master};
    ended($t->{shell}, 1);
    delete @$t{qw(master shell)};
    @$t{qw(keys gone)} = ('', 1);
    my @panes = trmnl_panes($tab->{trmnl});
    return trmnl_pane_closed($tab, $t) if @panes > 1;
    my $note = "\r\n\e[2m[the shell ended]\e[m";
    trmnl_send($t, 'o ' . length($note) . "\n$note");
    $tab->{says} = 'The shell ended. Close this tab, or open LZRTRMNL again from the home page.';
    idle($tab->{says}) if $tab == $TABS[$TAB];
}

sub trmnl_read {                          # what a pane's container drew, line by line, each checked
    my ($tab, $t) = @_;
    my $got = sysread($t->{from}, $t->{heard}, 262_144, length $t->{heard});
    return if !defined $got && ($!{EAGAIN} || $!{EINTR});
    return trmnl_lost($tab, $t, 'its container ended') unless $got;
    while ((my $end = index($t->{heard}, "\n")) >= 0) {
        my $line = substr($t->{heard}, 0, $end + 1, '');
        chop $line;
        return trmnl_lost($tab, $t, 'its container wrote a line too long') if length $line > $TRMNL_LINE;
        if (my $block = $t->{block}) {
            push @{ $block->[3] }, $line;
            next if --$block->[2];
            delete $t->{block};
            next if $block->[0] eq 'copy' && trmnl_copied($tab, $block->[3]);
            return trmnl_lost($tab, $t, 'its container handed a copy that is not text') if $block->[0] eq 'copy';
            trmnl_block($t, @$block) or return trmnl_lost($tab, $t, 'its container drew a row that is not fit');
        }
        elsif ($line =~ /^=row (0|[1-9][0-9]{0,2}) (0|[1-9][0-9]{0,3})$/ && $1 < $t->{size}[1] && $2 <= $TRMNL_ROW) { $2 ? ($t->{block} = ['row', 0 + $1, 0 + $2, []]) : trmnl_block($t, 'row', 0 + $1, 0, []) }
        elsif ($line eq '=head 2') { $t->{block} = ['head', 0, 2, []] }
        elsif ($line eq '=drawn') { $t->{fresh} = 1 }
        elsif ($line =~ /^=size ([1-9][0-9]{0,2}) ([1-9][0-9]{0,2})$/ && $1 <= 300 && $2 <= 120) {
            my ($cols, $rows) = (0 + $1, 0 + $2);
            $t->{size} = [$cols, $rows];
            splice @{ $t->{$_} }, $rows for grep { @{ $t->{$_} } > $rows } 'rows', 'tally', 'moved';
            if ($t->{master}) { my $size = pack 'S4', $rows, $cols, 0, 0; ioctl($t->{master}, 0x80087467, $size) }    # TIOCSWINSZ: the shell's programs are told the new size
            elsif (!$t->{gone}) { my $w = $tab->{trmnl}; trmnl_send($t, "b\n") if $w && !$w->{opened}++; my $why = trmnl_shell($t, $cols, $rows); return trmnl_lost($tab, $t, $why) if $why }    # the first size: the opening screen (the container's src/trmnl/banner.rs) in the first pane of a window alone, then the shell starts, once
        }
        elsif ($line =~ /^=reply (status|cursor ([1-9][0-9]{0,2}) ([1-9][0-9]{0,2})|primary|secondary)$/) { trmnl_replied($t, $1, $2, $3) }
        elsif ($line =~ /^=mode ckm ([01])$/) { $t->{ckm} = $1 }
        elsif ($line =~ /^=mode paste ([01])$/) { $t->{paste} = $1 }
        elsif ($line =~ /^=mouse ([1-9][0-9]{0,2}) ([1-9][0-9]{0,2})$/) { trmnl_reported($t, $1, $2) }
        elsif ($line =~ /^=title(?: (.{1,400}))?$/s) { trmnl_titled($tab, $t, $1 // '') or return trmnl_lost($tab, $t, 'its container wrote a title that is not text') }
        elsif ($line =~ /^=copy (0|[1-9][0-9]{0,3})$/ && $1 <= $TRMNL_COPY_ROWS && delete $t->{copying}) { $1 ? ($t->{block} = ['copy', 0, 0 + $1, []]) : trmnl_copied($tab, []) }    # only after your copy asked for it
        else { return trmnl_lost($tab, $t, 'its container wrote a line of no form') }
    }
    return trmnl_lost($tab, $t, 'its container wrote a line too long') if length $t->{heard} > $TRMNL_LINE;
}

sub trmnl_block {                         # [C29] [C9] the head of a pane's screen, or one row: lines of a laid page, checked as every laid line is
    my ($t, $kind, $n, undef, $lines) = @_;
    no warnings 'utf8';
    if ($kind eq 'head') {
        my ($wide, $high) = $lines->[0] =~ /^L${N}x$N$/ or return;
        return unless $wide >= 1 && $high >= 1 && $wide <= 20_000 && $high <= 20_000 && $lines->[1] =~ /^R/;
        my $state = { wide => $wide, high => $high, text => 0, pixels => 0, rows => 0, row_bytes => 0, row_chars => 0, count => {}, tile => {} };
        laid_run($lines, 1, 1, $state, [], []) or return;
        @$t{qw(laid head rows tally moved)} = ([$wide, $high], $lines, [], [], []);    # a new head: every row is drawn again after it
        return 1;
    }
    my ($wide, $high) = @{ $t->{laid} // return };
    utf8::decode($_) or return for @$lines;
    return if grep { !/^[RX]/ } @$lines;
    my $state = { wide => $wide, high => $high, text => 0, pixels => 0, rows => 0, row_bytes => 0, row_chars => 0, count => {}, tile => {} };
    laid_run($lines, 0, $#$lines, $state, [], []) or return;
    utf8::encode($_) for @$lines;
    $t->{rows}[$n] = $lines;
    $t->{tally}[$n] = [$state->{count}{R} // 0, $state->{count}{X} // 0, $state->{text}];
    $t->{moved}[$n] = undef;              # moved to where the pane stands again when it is drawn (sub trmnl_composed)
    return 1;
}

sub trmnl_drawn {                         # the workspace as one laid list, the bar, the strip and the panes of the terminal tab shown, sent to the window when its tab is shown: only the lines that changed
    my ($tab) = @_;
    my $w = $tab->{trmnl} or return;
    delete $_->{fresh} for trmnl_panes($w);
    my ($list, $cut) = trmnl_composed($w);
    aside('LZRTRMNL left out rows its panes drew: together they held more than a page may.') if $cut && !$w->{cut}++;    # said once
    $w->{list} = $list;
    return unless $tab == $TABS[$TAB];
    live_window_patch($w->{sent}, $w->{list});
    $w->{sent} = $w->{list};
    $DRAWN = 1;
}

sub trmnl_shown {                         # a terminal's tab chosen: laid out at the window's size, each pane told its own, and drawn
    my ($tab) = @_;
    my $w = $tab->{trmnl};
    window('address LZRTRMNL');
    trmnl_layout($w);
    trmnl_retitled($tab);
    ($w->{list}) = trmnl_composed($w);
    window("page $TAB", @{ $w->{list} }, '.');
    $w->{sent} = $w->{list};
    $DRAWN = 1;
    window('secure none');
    nav_told();
    idle($tab->{says});
}

sub trmnl_pane_end {                      # one pane ended: its shell's group hung up (as a closed terminal does), the terminal closed, its container ended, and both waited for
    my ($t) = @_;
    return if $t->{ended}++;
    if ($t->{shell}) { kill 'HUP', -$t->{shell}; close $t->{master}; ended($t->{shell}, 1) }    # the shell's group, then the terminal closed: what runs in front is hung up too
    kill 'KILL', $t->{box};
    waitpid $t->{box}, 0;
    close $_ for grep { defined } @$t{qw(to from)};
    delete @$t{qw(to from master shell)};
}

sub trmnl_lost {                          # a pane's container ended or went wrong: that pane closes, and the terminal with it when it was the last pane
    my ($tab, $t, $why) = @_;
    my @panes = trmnl_panes($tab->{trmnl});
    return trmnl_end($tab, $why) if @panes <= 1;
    noted("a pane of LZRTRMNL ended: $why");
    aside("A pane of LZRTRMNL ended: $why.") if $tab == $TABS[$TAB];
    trmnl_pane_closed($tab, $t);
}

sub trmnl_end {                           # a terminal ended: every pane's shell hung up and its container ended
    my ($tab, $why) = @_;
    my $w = delete $tab->{trmnl} or return;
    trmnl_pane_end($_) for trmnl_panes($w);
    noted("LZRTRMNL ended: $why");
    $tab->{says} = "LZRTRMNL ended: $why.";
    return unless $tab == $TABS[$TAB];
    window("page $TAB", @{ $w->{list} // [] }, '.');
    live_told();
    idle($tab->{says});
}

sub trmnl_all { return map { $_->{trmnl} ? trmnl_panes($_->{trmnl}) : () } @TABS }    # every pane of every terminal of the window

sub trmnl_select {                        # the panes' descriptors, for the wait of sub hear
    my ($ready, $writable) = @_;
    for my $t (grep { !$_->{ended} } trmnl_all()) {
        vec($$ready, fileno $t->{from}, 1) = 1;
        vec($$ready, fileno $t->{master}, 1) = 1 if $t->{master} && length $t->{feed} < $TRMNL_FEED;
        vec($$writable, fileno $t->{to}, 1) = 1 if length $t->{feed};
        vec($$writable, fileno $t->{master}, 1) = 1 if $t->{master} && length $t->{keys};
    }
}

sub trmnl_heard {                         # what the wait of sub hear found ready, for each pane; each terminal drawn once for all it read
    my ($ready, $writable) = @_;
    for my $tab (grep { $_->{trmnl} } @TABS) {
        for my $t (trmnl_panes($tab->{trmnl})) {
            next if $t->{ended} || !$tab->{trmnl};
            trmnl_fed($t) if vec($writable, fileno $t->{to}, 1);
            trmnl_keys($t) if $t->{master} && vec($writable, fileno $t->{master}, 1);
            trmnl_wrote($tab, $t) if $t->{master} && vec($ready, fileno $t->{master}, 1);
            trmnl_read($tab, $t) if !$t->{ended} && $tab->{trmnl} && vec($ready, fileno $t->{from}, 1);
            trmnl_lost($tab, $t, $t->{lost}) if !$t->{ended} && $tab->{trmnl} && $t->{lost};
        }
        trmnl_drawn($tab) if $tab->{trmnl} && grep { $_->{fresh} } trmnl_panes($tab->{trmnl});
    }
}

sub trmnl_fds { return map { grep { defined } @$_{qw(to from master)} } trmnl_all() }    # for a copy of lzrprf that goes on as perl: it lets go of every terminal, so their ends are lzrprf's alone
