# The proof for this computer. "selftest" probes this file on this Mac and,
# when every probe was held, writes down the mark of what it tested: the
# build of macOS, the SHA-256 of this file and the SHA-256 of the selftest
# beside it, the file that made the probes. Nothing is shown unless that
# mark is the mark of now. So after macOS was updated, or this file or the
# selftest beside it changed, no page is shown before the probes were made
# again. Where no selftest can be read beside this file, there is no mark,
# and nothing counts as proven.
# When the test held but could not try every check on this Mac, it writes
# the mark followed by ", untested: " and the checks it could not try. Such
# a line counts only after you said yes to starting without exactly those
# checks, for exactly this mark: the window names them and asks, Quit first,
# and your yes is kept as that whole line in the file "untested". A yes to
# another line (other checks, another build, another lzrprf) is not a yes to
# this one, and the question comes again.                                # [C11]
# The file of marks holds up to eight lines, one for each copy of lzrprf that
# was tested on this build of macOS: testing another copy, such as one from
# the public repository, does not take the proof from the one that is
# installed. A line counts only when it is the mark of this file, of now.
sub mark {
    my ($build) = said(5, '/usr/sbin/sysctl', '-n', 'kern.osversion');
    my $self = sum_of($SELF) // return '';
    my $test = sum_of(dirname($SELF) . '/selftest') // return '';    # no selftest to read beside this file: no mark, so nothing counts as proven
    return $build =~ /^(\w+)$/ ? "macOS build $1, lzrprf $self, selftest $test" : '';
}

sub sum_of { sysopen my $in, $_[0], O_RDONLY | O_NOFOLLOW | O_NONBLOCK or return; -f $in or return; binmode $in; return eval { Digest::SHA->new(256)->addfile($in)->hexdigest } }    # what cannot be read to its end has no sum; a plain file and no link, and a pipe put in its place is not waited for

# The program is the file this window began with. Its SHA-256 is read whole when the window begins
# ($BEGAN, sub behind), and with it the file it was read from, as the system names a file: its
# device, its number on that device, its mode, its size, and the times it was last written and last
# changed, to the nanosecond. Before every run (sub contained) and before a site is asked for a page
# (sub visit) the file is named again; while it is still that file, nothing was written to it, put
# in its place or moved over it since its bytes were read: every write sets the time of change,
# which no program can set back, and a file put in its place is another number. Then the sum stands
# without reading 10 MB again, which took 30 to 36 ms before every run, four times for a visit with
# the two runs before its page (measured 2026-11-24, scripts/snappy.pl). Any other file, or one that
# was touched, is read whole again, and the window goes on only with the same sum. A sum read again
# would come from what the system holds in memory, not from the disk, so reading it again found no
# more than this does. The file is named once it is open (fstat), never by its path alone.
sub sum_seen {                            # (the SHA-256 of a file, the file it was) from one opening; the file only when it did not change while it was read
    sysopen my $in, $_[0], O_RDONLY | O_NOFOLLOW | O_NONBLOCK or return;
    -f $in or return;
    binmode $in;
    my $before = file_named($in);
    my $sum = eval { Digest::SHA->new(256)->addfile($in)->hexdigest } // return;
    my $after = file_named($in);
    return ($sum, defined $before && defined $after && $before eq $after ? $after : undef);
}
sub file_named { my @is = Time::HiRes::stat($_[0]); return @is ? join(' ', @is[0, 1, 2, 7, 9, 10]) : undef }    # device, number, mode, size, written, changed
sub program_same {                        # true when the program on the disk is the file this window began with
    return 0 unless defined $BEGAN;
    if (defined $PROGRAM_SEEN && sysopen my $in, $PROGRAM, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) { return 1 if -f $in && (file_named($in) // '') eq $PROGRAM_SEEN }
    my ($sum, $seen) = sum_seen($PROGRAM);
    my $same = defined $sum && $sum eq $BEGAN;
    $PROGRAM_SEEN = $same ? $seen : undef;
    return $same ? 1 : 0;
}

sub proven {
    my $mark = mark();
    my $is = sub {                        # 'plain' for the mark of now; the line, for the mark of now with the checks that could not be tried; '' for neither
        sysopen my $in, "$ROOT/proven", O_RDONLY | O_NONBLOCK or return '';    # a pipe put in its place is not waited for
        return '' unless length $mark && -f $in;
        my @lines = map { scalar(<$in>) // () } 1 .. 8;
        return 'plain' if grep { $_ eq "$mark\n" } @lines;
        my ($line) = grep { /^\Q$mark\E, untested: [\x20-\x7e]{1,600}\n\z/ } @lines;    # as selftest writes it: the question shows all of it, so the yes is to nothing unseen
        return defined $line ? $line =~ s/\n\z//r : '';
    };
    my $without = sub {                   # a line that names checks the test could not try counts only after a yes to exactly that line
        my ($line) = @_;
        return 1 if $line eq 'plain';
        my $yes = '';
        if (sysopen my $in, "$ROOT/untested", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) { $yes = (-f $in ? scalar(<$in>) : undef) // '' }    # a plain file and no link; a pipe put in its place is not waited for
        return 1 if $yes eq "$line\n";
        my $text = substr($line, length "$mark, untested: ");
        if (ask("The self-test held on this Mac, but it could not try every check here: $text. What it could not try is not shown to hold on this Mac as it is now. Start $APP without it?", 'Quit', 'Start') != 2) {
            window('quit');
            leave();
        }
        unlink "${\ shared()}/untested";
        if (sysopen my $out, "${\ shared()}/untested", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) { print $out "$line\n"; close $out }    # when it cannot be kept, the question comes again at the next start
        return 1;
    };
    my $found = $is->();
    return $without->($found) if length $found;
    if (testing()) {                      # a self-test is running on this Mac (an installer's in Terminal, or one by hand): it took this copy's mark out when it began and writes it again when it holds, so its result is waited for, not asked for twice
        busy("lzrprf's self-test is running on this Mac, an installer's or one by hand. $APP waits for its result instead of asking to test again.");
        my $until = now() + 900;
        select undef, undef, undef, 0.5 while testing() && now() < $until;
        $found = $is->();
        return $without->($found) if length $found;
    }
    return 0 if $INCOGNITO;               # [C16] the self-test writes its result: an incognito window does not run it
    my $test = dirname($SELF) . '/selftest';
    if (ask("lzrprf has not been tested on this Mac as it is now: macOS was updated, or lzrprf or its selftest is new. The test runs hostile tries we made ourselves, just to be sure, and lzrprf must deflect every one; it takes about half a minute. $APP shows a page only when all were deflected. Test now?", 'Not now', 'Test now') != 2) {
        window('quit');
        leave();
    }
    busy('lzrprf is deflecting hostile tries we made ourselves, just to be sure. This takes about half a minute.');
    my ($report) = -f $test ? said(900, '/usr/bin/perl', $test) : ("there is no selftest beside $SELF\n");
    unlink "${\ shared()}/selftest.txt";
    if (sysopen my $out, "${\ shared()}/selftest.txt", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) { print $out $report }
    $found = $is->();
    return $without->($found) if length $found;    # the test held: when it could not try every check, the same question is asked before an address is taken
    my @failed = grep { /^(?:FAILED|UNTESTED|selftest:)/ } split /\n/, $report;
    @failed = (split /\n/, $report)[-20 .. -1] unless @failed;
    window('page', 'Pc0', (map { ('T@' . substr(s/\t/   /gr =~ s/[^\x20-\x7e]/?/gr, 0, 300), 'B') } grep { length } @failed[0 .. (@failed > 200 ? 199 : $#failed)]), '.');
    return 0;
}

# True while another process holds the lock selftest keeps for the whole of its run
# (~/.lzrprf/selftest.lock): a shared lock is not given beside it. A link, a pipe
# or no file at all is no test running.
sub testing {
    sysopen my $lock, "$ROOT/selftest.lock", O_RDONLY | O_NOFOLLOW | O_NONBLOCK or return 0;
    return 0 unless -f $lock;
    return !flock $lock, LOCK_SH | LOCK_NB;
}

sub lookup {                              # every address a name leads to, as numbers, one on a line
    return unless $$ == $FRESH;           # only in a process started afresh ("lzrprf lookup NAME"): a copy made by fork looks up nothing here, and is given no address
    return if listed($_[0]);              # [C23] a listed name is never handed to the resolver, from here either: nothing is printed, as for a name that leads nowhere
    my ($failed, @all) = getaddrinfo($_[0], 443, { socktype => SOCK_STREAM });
    print map { (getnameinfo($_->{addr}, NI_NUMERICHOST | NI_NUMERICSERV))[1] . "\n" } $failed ? () : @all;
}

