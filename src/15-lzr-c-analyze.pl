
# lzr processes analyze [C20]: one process watched until you close the view.
# Every --interval seconds (1 when left out) ps says how much processor time
# the process has had and its resident memory, and for a process of yours
# macOS says its footprint (sub lzr_footprint); its share of a processor is
# the processor time it had since the last sample over the time between the
# two. Two graphs show those against time, newest on the right, under a box
# of what it is: its program, where that lives, whose it is, what started it,
# when, who signed the program (codesign, as LZRDFNDR's tool asks it), and
# what LZRDFNDR does with it. Of another user's process the system shows
# anyone its processor time and resident memory; the rest is not shown, and
# the box says so. A process that ends stays in view, marked ended.
#
# On a terminal the view has the screen to itself (the alternate screen, the
# terminal's own scrollback untouched), and asks the terminal for presses: a
# press on [ Close ] at the top right closes it, as q, Esc and Ctrl-C do.
# Whatever way it ends, the terminal is given back as it was. --frames N
# draws N frames and stops, also outside a terminal, for scripts and tests.
my $LZR_SAMPLES = 2000;                   # DECLARED([C20] the most samples kept of one process: wider than any screen, so a graph is always full from the right)
my $LZR_CLOSE = '[ Close ]';
my @LZR_BLOCKS = (' ', "\x{2581}", "\x{2582}", "\x{2583}", "\x{2584}", "\x{2585}", "\x{2586}", "\x{2587}", "\x{2588}");    # an eighth of a row more each

sub lzr_size {                            # the terminal's columns and rows: as the terminal says, else COLUMNS and LINES, else 100 by 30
    my $size = "\0" x 8;
    my ($rows, $cols) = -t STDOUT && ioctl(STDOUT, 0x40087468, $size) ? unpack('S2', $size) : (0, 0);    # TIOCGWINSZ
    $cols ||= ($SHOWN{COLUMNS} // '') =~ /\A([1-9][0-9]{0,3})\z/ ? $1 : 100;
    $rows ||= ($SHOWN{LINES} // '') =~ /\A([1-9][0-9]{0,3})\z/ ? $1 : 30;
    return ($cols < 50 ? 50 : $cols, $rows < 20 ? 20 : $rows);
}

sub lzr_ceiling { my ($most) = @_; return 1 unless $most > 0; my $ten = 10**int(log($most) / log(10)); for my $step (1, 2, 5, 10) { return $step * $ten if $step * $ten >= $most } return 10 * $ten }    # a round top for a graph: 1, 2 or 5 times a power of ten, at least the most it shows

sub lzr_about {                           # [C20] the box: what the process is, as far as you may see it
    my ($pid) = @_;
    my $proc = $TOOL{procs}{$pid};
    my $path = $proc->{path};
    my $mine = $proc->{uid} == $<;
    my $parent = $TOOL{procs}{ $proc->{ppid} };
    my ($signed) = $path =~ m{^/} ? tool_signed($path) : ();
    my $who = !$signed ? 'not known (codesign was not asked, or did not say)' : $signed->[1] eq 'adhoc' ? 'ad hoc (by no one named)' : $signed->[1] eq 'none' ? 'not signed' : $signed->[1] eq '-' ? "signed, by no team ($signed->[2])" : "team $signed->[1] ($signed->[2])";
    my $state = lzr_state_of($pid);
    my $may = lzr_why_not($pid);
    return (
        ['Program', $path],
        ['Lives in', $path =~ m{\A(/.+?\.app)/} ? "$1 (an app)" : $path =~ m{\A(.*)/[^/]+\z} ? ($1 || '/') : 'not a path: the system gave its name only'],
        ['Owner', ((getpwuid $proc->{uid})[0] // 'unknown') . " (uid $proc->{uid})" . ($mine ? ', you' : '')],
        ['Parent', $parent ? "$proc->{ppid} " . ($parent->{path} =~ m{([^/]+)\z} ? $1 : $parent->{path}) : $proc->{ppid}],
        ['Started', $proc->{began}],
        ['Signed', $who],
        ['LZRDFNDR', ($state || 'neither deactivated nor contained') . (defined $may ? '; lzr does not change it: ' . ($may =~ s/^process \d+ is //r) : '')],
        ['Seen', $mine ? 'processor time and resident memory (ps), its footprint (macOS)' : "processor time and resident memory (ps) alone: its footprint, arguments and files are another user's, which macOS shows no one without privilege"],
    );
}

sub lzr_analyze {                         # [C20] lzr processes analyze: the live view, until it is closed
    my ($what, $flags) = @_;
    my ($pid, $why) = lzr_pid_of($what);
    return lzr_said("$why.") unless $pid;
    my $every = $flags->{interval} // 1;
    return lzr_wrong("--interval takes seconds from 0.2 to 60, not \"$every\"", 'processes analyze') unless $every =~ /\A[0-9]{1,2}(?:\.[0-9]{1,3})?\z/ && $every >= 0.2 && $every <= 60;
    my $frames = $flags->{frames};
    return lzr_wrong("--frames takes a number of frames from 1 to 100000, not \"$frames\"", 'processes analyze') if defined $frames && $frames !~ /\A[1-9][0-9]{0,4}\z/;
    return lzr_said('the live view needs a terminal; add --frames N to draw N frames anyway.') unless defined $frames || -t STDOUT;
    my $live = -t STDOUT;
    my @box = lzr_about($pid);
    my $mine = $TOOL{procs}{$pid}{uid} == $<;
    my $name = $TOOL{procs}{$pid}{path} =~ m{([^/]+)\z} ? $1 : $TOOL{procs}{$pid}{path};
    my (@cpu, @mem, $last, $ended, $close);
    my $since = strftime('%H:%M:%S', localtime);
    binmode STDOUT, ':encoding(UTF-8)';
    my $term = $live && -t STDIN ? POSIX::Termios->new : undef;
    my $was = $term && $term->getattr(0) ? [$term->getlflag, $term->getcc(POSIX::VMIN()), $term->getcc(POSIX::VTIME())] : undef;
    my $restore = sub {
        return unless $live;
        $live = 0;
        print "\e[?1006l\e[?1000l\e[?25h\e[?1049l";    # presses no longer asked for, the cursor back, the screen as it was
        STDOUT->flush;
        if ($was) { $term->setlflag($was->[0]); $term->setcc(POSIX::VMIN(), $was->[1]); $term->setcc(POSIX::VTIME(), $was->[2]); $term->setattr(0, POSIX::TCSANOW()) }
    };
    local $SIG{INT} = local $SIG{TERM} = local $SIG{HUP} = sub { $close = 'a signal' };
    local $SIG{WINCH} = sub { };          # a new size is read at the next frame
    if ($live) {
        print "\e[?1049h\e[?25l\e[?1000h\e[?1006h";    # the alternate screen, no cursor, presses asked for (sent back in the SGR form)
        if ($was) { $term->setlflag($was->[0] & ~(POSIX::ICANON() | POSIX::ECHO())); $term->setcc(POSIX::VMIN(), 1); $term->setcc(POSIX::VTIME(), 0); $term->setattr(0, POSIX::TCSANOW()) }    # each key as it comes, unseen; Ctrl-C is still a signal
    }
    my ($typed, $open) = ('', 1);
    my $ok = eval {
        while (!defined $close) {
            my $at = now();
            if (!$ended) {
                my ($said) = tool_asked("analyze.$pid", 5, '/bin/ps', '-o', 'time=,rss=,lstart=', '-p', $pid);
                my ($time, $rss, $began) = $said =~ /^\s*(\S+)\s+(\d+)\s+(.+?)\s*$/;
                if (!defined $time || ($began =~ s/\s+/ /gr) ne $TOOL{procs}{$pid}{began}) { $ended = strftime('%H:%M:%S', localtime) }
                else {
                    my $seconds = lzr_seconds($time);
                    push @cpu, $last ? ($seconds - $last->[1] < 0 ? 0 : 100 * ($seconds - $last->[1]) / (($at - $last->[0]) || 1)) : undef;
                    my $foot = $mine ? lzr_footprint($pid) : undef;
                    push @mem, $foot // $rss;
                    $last = [$at, $seconds];
                    splice @$_, 0, @$_ - $LZR_SAMPLES for grep { @$_ > $LZR_SAMPLES } \@cpu, \@mem;
                }
            }
            my ($cols, $rows) = lzr_size();
            print $live ? "\e[H\e[2J" : "\f\n", join("\n", lzr_frame($cols, $rows, $what->[0], $pid, $name, \@box, \@cpu, \@mem, $mine, $ended, $since, $every)), $live ? '' : "\n";
            STDOUT->flush;
            last if defined $frames && --$frames <= 0;
            my $until = $at + $every;
            while (!defined $close && (my $left = $until - now()) > 0) {
                my $ready = '';
                vec($ready, fileno STDIN, 1) = 1 if $open;
                my $seen = select($open ? $ready : undef, undef, undef, $left);
                next unless $seen > 0;
                my $got = sysread STDIN, my $bytes, 256;
                if (!$got) { $open = 0; next }    # nothing more will be typed (a pipe, or /dev/null): the view runs on until its frames or a signal
                $typed .= $bytes;
                $close = lzr_closing(\$typed, $cols);
            }
        }
        1;
    };
    my $error = $@;
    $restore->();
    die $error unless $ok;
    print 'Closed ' . ($close // "after its frames") . ". Process $pid " . ($ended ? "ended at $ended" : 'runs on') . ".\n" if defined $close || !defined $frames;
    return 0;
}

sub lzr_closing {                         # what the keys and presses typed so far say: the way the view was closed, or nothing yet
    my ($typed, $cols) = @_;
    while (length $$typed) {
        if ($$typed =~ s/\A\e\[<(\d+);(\d+);(\d+)([Mm])//) { return 'with its Close button' if $1 == 0 && $4 eq 'M' && $3 == 1 && $2 > $cols - length($LZR_CLOSE) && $2 <= $cols; next }    # a press, in the SGR form: the left button, on the button
        if ($$typed =~ s/\A\e\[M(.)(.)(.)//s) { return 'with its Close button' if (ord($1) & 3) == 0 && ord($3) - 32 == 1 && ord($2) - 32 > $cols - length($LZR_CLOSE); next }    # the older form, for a terminal that does not send the SGR one
        return if $$typed =~ /\A\e(?:\[[<0-9;]*)?\z/ && length $$typed < 32 && $$typed ne "\e";    # the start of a sequence: the rest comes
        return 'with Esc' if $$typed =~ s/\A\e(?!\[)//;
        $$typed =~ s/\A\e\[[0-9;<]*[A-Za-z~]// and next;    # another key's sequence (an arrow): nothing to do
        my $key = substr $$typed, 0, 1, '';
        return 'with q' if $key eq 'q' || $key eq 'Q';
        return 'with Ctrl-C' if $key eq "\x03";
    }
    return;
}

sub lzr_frame {                           # one frame of the view, as its lines
    my ($cols, $rows, $id, $pid, $name, $box, $cpu, $mem, $mine, $ended, $since, $every) = @_;
    my $title = "lzr processes analyze  $id  process $pid  $name";
    my $room = $cols - length $LZR_CLOSE;    # the button takes the last columns of the first row
    my @lines = (sprintf('%-*s', $room, substr($title, 0, $room - 1)) . lzr_paint('7', $LZR_CLOSE));
    my $inner = $cols - 4;
    push @lines, '+' . '-' x ($cols - 2) . '+';
    for my $row (@$box) {
        my $text = sprintf '%-9s %s', $row->[0], $row->[1];
        for (my $first = 1; $first || length $text; $first = 0) { push @lines, '| ' . sprintf('%-*s', $inner, substr($text, 0, $inner, '')) . ' |'; $text = ' ' x 10 . $text if length $text }
    }
    push @lines, '+' . '-' x ($cols - 2) . '+';
    my $left = $rows - @lines - 5;
    my $high = $left < 4 ? 2 : int($left / 2) - 1;
    my @shown_cpu = grep { defined } @$cpu;
    my $now_cpu = @shown_cpu ? $shown_cpu[-1] : undef;
    my $top_cpu = lzr_ceiling((sort { $b <=> $a } 100, @shown_cpu[($#shown_cpu > $inner ? -$inner : 0) .. $#shown_cpu])[0]);
    push @lines, lzr_paint(1, 'CPU') . sprintf(' %s of one processor now, top of graph %d%%', defined $now_cpu ? sprintf('%.1f%%', $now_cpu) : '-', $top_cpu), lzr_graph([map { $_ // 0 } @$cpu], $top_cpu, $inner, $high);
    my $top_mem = lzr_ceiling((sort { $b <=> $a } 1024, @$mem[($#$mem > $inner ? -$inner : 0) .. $#$mem])[0]);
    push @lines, lzr_paint(1, 'Memory') . sprintf(' %s %s now, top of graph %s', @$mem ? lzr_kib($mem->[-1]) : '-', $mine ? 'footprint' : 'resident', lzr_kib($top_mem)), lzr_graph($mem, $top_mem, $inner, $high);
    push @lines, lzr_paint(2, sprintf 'Since %s, a sample every %ss. q, Esc, Ctrl-C or %s closes.', $since, $every, $LZR_CLOSE) . ($ended ? ' ' . lzr_paint(33, "The process ended at $ended.") : '');
    splice @lines, $rows if @lines > $rows;
    return @lines;
}

sub lzr_graph {                           # the last $wide values as $high rows of blocks, each column one sample, the newest on the right (the scale is said above it)
    my ($values, $top, $wide, $high) = @_;
    my @last = @$values[($#$values >= $wide ? @$values - $wide : 0) .. $#$values];
    my @rows;
    for my $row (reverse 0 .. $high - 1) {
        my $line = join '', map { my $eighths = int($_ / $top * $high * 8 + 0.5) - $row * 8; $LZR_BLOCKS[$eighths < 0 ? 0 : $eighths > 8 ? 8 : $eighths] } @last;
        push @rows, '  ' . lzr_paint(96, ' ' x ($wide - @last) . $line);
    }
    push @rows, '  ' . "\x{2594}" x $wide;
    return @rows;
}
