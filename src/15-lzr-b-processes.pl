
# lzr processes [C20]: LZRDFNDR from the terminal. The look is the tool's own
# (ps, as sub tool_look reads it, into %TOOL), and every change goes through
# the tool's rules: sub tool_may says which process may be ended, sub
# tool_stop ends it after asking ps again, sub tool_quiet switches a launchd
# job off and keeps it in ~/.lzrprf/quieted, sub tool_wake switches it on.
# Every change is written in the log first, and is made only on your word
# (a question on the terminal, or --yes). On top of those:
#
# - A program you deactivated is kept in ~/.lzrprf/deactivated (its path and
#   when). Each process of it is closed whenever LZRDFNDR sees it: at every
#   "lzr processes", and every $LZR_SEEN seconds while a window is open
#   (sub tool_watch). Its launchd jobs of your account are switched off.
# - A process you contained is ended and its program started again, with the
#   arguments it ran with, in the page container ($CONTAINER), as a child of
#   a keeper of its own ("core-lzrprf-contain ID", sub lzr_keeper). Each is a
#   file of ~/.lzrprf/contained, written whole: what was started, its
#   number, whether the system says it is contained, and how it ended.
#
# An ID is five of the letters and digits of $LZR_ALPHABET, at least one a
# digit, made from a SHA-256: of a process's number and start, of a program's
# path, of a launchd job's label, of a contained process's start. So it stays
# the same for as long as what it names does.
my $LZR_ALPHABET = '0123456789abcdefghjkmnpqrstvwxyz';    # no i, l, o or u: no two that look alike
my $LZR_SEEN = 10;                        # DECLARED([C20] seconds between two looks for deactivated programs while a window is open: a ps of every process, about 30 ms)
my $LZR_DEACTIVATED = 500;                # DECLARED([C20] the most programs kept deactivated: more than a person switches off)
my $LZR_CONTAINED = 64;                   # DECLARED([C20] the most contained processes kept: more than a person runs that way at once)
my $LZR_ARGS = 262_144;                   # DECLARED([C20] the most bytes of a process's arguments and environment read to start it again contained: the system's own limit, kern.argmax, is 1 MiB, and arguments longer than this are not contained)
my $LZR_SYSTEM = qr{^/(?:System|bin|sbin|usr(?!/local/)|Library/Apple)/};    # the system's own programs, as sub tool_may has them
my (%LZR_USE, $LZR_LOOKED, $LZR_WATCHED); # each process's share of a processor and memory (KiB) in the last look; when that look was; when a window last looked for deactivated programs

sub lzr_id {                              # the ID of what a key names (sub lzr_processes says which keys)
    my @bytes = unpack 'C*', Digest::SHA::sha256("lzr $_[0]");
    my $id = join '', map { substr $LZR_ALPHABET, $bytes[$_] % 32, 1 } 0 .. 4;
    substr($id, $bytes[5] % 5, 1) = $bytes[6] % 10 unless $id =~ /[0-9]/;    # one digit at least, so an ID is never a word
    return $id;
}

sub lzr_look {                            # every process the system lists, into %TOOL as the tool's look holds them, with what each uses; false when ps said nothing
    my ($list, $listed) = tool_asked('procs', 10, '/bin/ps', '-axww', '-o', 'pid=,ppid=,uid=,lstart=,comm=');
    return 0 unless $listed;
    my (%procs, %own);
    for (split /\n/, $list) {
        my ($pid, $ppid, $owner, $began, $path) = /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+\s+\S+\s+\d+\s+[\d:]+\s+\d+)\s+(.*?)\s*$/ or next;
        $procs{$pid} = { ppid => $ppid, uid => $owner, began => $began =~ s/\s+/ /gr, path => tool_plain($path, 1000), args => '' };
    }
    for (my $up = $$; $up > 1 && $procs{$up} && !$own{$up}; $up = $procs{$up}{ppid}) { $own{$up} = 1 }    # lzr and what started it: this terminal's shell, lzrprf, the window, up to launchd (what those started besides is LZRBRWSR's own program, or a system program, or yours to name)
    my ($use, $used) = tool_asked('usage', 10, '/bin/ps', '-axww', '-o', 'pid=,%cpu=,rss=');
    %LZR_USE = ();
    for (split /\n/, $used ? $use : '') { $LZR_USE{$1} = [$2, $3] if /^\s*(\d+)\s+([\d.]+)\s+(\d+)\s*$/ }
    @TOOL{qw(procs own)} = (\%procs, \%own);
    $LZR_LOOKED = now();
    return 1;
}

sub lzr_deactivated {                     # [C20] the programs you deactivated: [path, when]
    open my $in, '<', "${\ shared()}/deactivated" or return [];
    my @kept = map { chomp; my @one = split /\t/, $_, -1; @one == 2 && $one[0] =~ m{\A/[^\x00-\x1f\x7f]{1,1000}\z} && $one[1] =~ /\A[0-9TZ:-]{1,30}\z/ ? [@one] : () } <$in>;
    splice @kept, $LZR_DEACTIVATED if @kept > $LZR_DEACTIVATED;
    return \@kept;
}
sub lzr_keep_deactivated {                # [C20] that list, written beside the old one and through to the disk, then given its name in one step
    my ($kept) = @_;
    my $file = "${\ shared()}/deactivated";
    unlink "$file.new";
    return !-e $file || unlink $file unless @$kept;
    unless (put("$file.new", O_EXCL, map { join "\t", @$_ } @$kept) && rename "$file.new", $file) { unlink "$file.new"; return 0 }
    synced(shared());
    return 1;
}

sub lzr_contained {                       # [C20] the contained processes: one hash a file of ~/.lzrprf/contained, each by its ID
    my $dir = "${\ shared()}/contained";
    opendir my $folder, $dir or return {};
    my %all;
    for my $id (sort grep { /\A[0-9a-hjkmnp-tv-z]{5}\z/ } readdir $folder) {
        open my $in, '<', "$dir/$id" or next;
        my %one = (id => $id, args => []);
        while (my $line = <$in>) {
            chomp $line;
            my ($key, $value) = $line =~ /\A([a-z]+) (.*)\z/s or next;
            if ($key eq 'arg') { push @{ $one{args} }, $value =~ s/\\n/\n/gr =~ s/\\\\/\\/gr } else { $one{$key} = $value }
        }
        $all{$id} = \%one if ($one{program} // '') =~ m{\A/} && keys %all < $LZR_CONTAINED;
    }
    return \%all;
}
sub lzr_write_contained {                 # [C20] one contained process's file, written whole under a name of its own first
    my ($one) = @_;
    my $dir = "${\ shared()}/contained";
    mkdir $dir, 0700;
    my $file = "$dir/$one->{id}";
    unlink "$file.$$";
    my @lines = ((map { defined $one->{$_} ? "$_ $one->{$_}" : () } qw(id program own since keeper child began contained ended status by said)), map { 'arg ' . (s/\\/\\\\/gr =~ s/\n/\\n/gr) } @{ $one->{args} });
    unless (put("$file.$$", O_EXCL, @lines) && rename "$file.$$", $file) { unlink "$file.$$"; return 0 }
    return 1;
}

sub lzr_alive { my ($pid, $began) = @_; return 0 unless $pid && kill 0, $pid; my ($now) = tool_asked("proc.$pid", 5, '/bin/ps', '-o', 'lstart=', '-p', $pid); return ($now =~ s/^\s+|\s+$//gr =~ s/\s+/ /gr) eq ($began // '') }    # this process number is still the process that had it: the same start

# Everything an ID can name, now: [id, kind, what], kind "proc" (a process,
# what: its number), "program" (deactivated: its path), "job" (a launchd job
# switched off in LZRDFNDR: its label) or "box" (a contained process: its
# file's hash).
sub lzr_named_all {
    my @all = map { [lzr_id("proc $_ $TOOL{procs}{$_}{began}"), 'proc', $_] } sort { $a <=> $b } keys %{ $TOOL{procs} };
    push @all, map { [lzr_id("program $_->[0]"), 'program', $_->[0]] } @{ lzr_deactivated() };
    push @all, map { [lzr_id("job $_->[0]"), 'job', $_->[0]] } @{ tool_kept() };
    my $boxes = lzr_contained();
    push @all, map { [$_, 'box', $boxes->{$_}] } sort keys %$boxes;
    return @all;
}

sub lzr_which {                           # what an ID (or a process number) names: [id, kind, what], or nothing and why
    my ($typed) = @_;
    if ($typed =~ /\A[1-9][0-9]{0,6}\z/) {
        return (undef, "no process has the number $typed now") unless $TOOL{procs}{$typed};
        return ([lzr_id("proc $typed $TOOL{procs}{$typed}{began}"), 'proc', $typed]);
    }
    my @all = lzr_named_all();
    my @hit = grep { $_->[0] eq $typed } @all;
    @hit = grep { index($_->[0], $typed) == 0 } @all if !@hit && length $typed >= 3;
    return ($hit[0]) if @hit == 1;
    return (undef, "$typed is the start of " . @hit . ' IDs: ' . join(', ', map { $_->[0] } @hit[0 .. ($#hit > 7 ? 7 : $#hit)]) . '. Type more of it') if @hit;
    return (undef, "nothing has the ID $typed now. \"lzr processes all\" shows every ID; the ID of a process that ended is gone with it");
}

sub lzr_running {                         # the processes of a program now, by number
    my ($path) = @_;
    return sort { $a <=> $b } grep { $TOOL{procs}{$_}{path} eq $path } keys %{ $TOOL{procs} };
}

sub lzr_why_not {                         # [C20] why lzr does not end this process, in words; nothing when sub tool_may lets it
    my ($pid) = @_;
    my $proc = $TOOL{procs}{$pid} or return "process $pid is not running";
    return if defined tool_may('stop', $pid);
    my $user = (getpwuid $proc->{uid})[0] // $proc->{uid};
    return "process $pid is ${user}'s, and lzr changes your own processes only" if $proc->{uid} != $<;
    return "process $pid is this terminal, LZRBRWSR or lzr itself, or what started them" if $TOOL{own}{$pid};
    return "process $pid is a program of the system ($proc->{path}), which lzr never changes" if $proc->{path} =~ $LZR_SYSTEM || $proc->{path} !~ m{^/};
    return "process $pid is not one lzr ends";
}

sub lzr_program_why_not {                 # [C20] why a program cannot be deactivated or contained, in words; nothing when it can
    my ($path) = @_;
    return "$path is no program's full path" unless $path =~ m{\A/[^\x00-\x1f\x7f]{1,1000}\z};
    return "$path holds a character lzrprf does not pass to a container" if $path =~ /["\\]/;
    return "$path is a program of the system, which lzr never changes" if $path =~ $LZR_SYSTEM;
    return "$path is LZRBRWSR's own" if $path =~ m{/LZRBRWSR[^/]*\.app/} || grep { $TOOL{procs}{$_} && $TOOL{procs}{$_}{path} eq $path } keys %{ $TOOL{own} };
    return;
}

sub lzr_jobs_of {                         # [C20] the launchd jobs of your account that run this program, read as the tool reads them into %TOOL: their labels
    my ($path, @pids) = @_;
    my ($gui, $said) = tool_asked('jobs', 10, '/bin/launchctl', 'print', "gui/$<");
    return () unless $said;
    my ($loaded, $off) = tool_services($gui);
    my %jobs;
    for my $place (grep { $_->[0] eq 'gui' } tool_places()) {
        opendir(my $dir, $place->[1]) or next;
        for my $name (sort grep { /\.plist\z/ && !/[\x00-\x1f\x7f]/ } readdir $dir) {
            my ($label, $program, $with, $flags) = tool_file("$place->[1]/$name") or next;
            $jobs{$label} //= { pid => $loaded->{$label} // 0, state => exists $loaded->{$label} ? ($loaded->{$label} ? 'run' : 'load') : $off->{$label} ? 'off' : 'file', program => $program, file => tool_plain("$place->[1]/$name", 1000), flags => $flags, args => $with };
        }
        closedir $dir;
    }
    my %of = map { $_ => 1 } @pids;
    for my $label (grep { !$jobs{$_} && $of{ $loaded->{$_} } && /^$TOOL_LABEL\z/ } keys %$loaded) {    # a job written down in no folder: asked about only when one of the program's processes is its
        my ($one) = tool_asked("job.$label", 5, '/bin/launchctl', 'print', "gui/$</$label");
        my ($program) = $one =~ /^\tprogram = (.+)$/m;
        $jobs{$label} = { pid => $loaded->{$label}, state => 'run', program => tool_plain($program // '', 1000), file => '', flags => '', args => '' };
    }
    $TOOL{jobs}{gui} = \%jobs;
    return sort grep { $jobs{$_}{program} eq $path || $jobs{$_}{pid} && $of{ $jobs{$_}{pid} } } keys %jobs;
}

sub lzr_asked {                           # your word before a change: --yes, or y typed on the terminal; nothing is asked where lzr cannot ask
    my ($question, $flags) = @_;
    return 1 if $flags->{yes};
    unless (-t STDIN) { print STDERR "lzr: nothing was done: lzr is not in a terminal, so it cannot ask first. Add --yes to do it anyway.\n"; return 0 }
    print "$question [y/N] ";
    my $answer = <STDIN>;
    return 1 if defined $answer && $answer =~ /\A\s*y(?:es)?\s*\z/i;
    print "Nothing was done.\n";
    return 0;
}

sub lzr_seen {                            # [C20] the deactivated programs seen running: each of their processes closed, after its log line; what was closed, in words
    my $kept = lzr_deactivated();
    return () unless @$kept;
    my @closed;
    for my $one (@$kept) {
        for my $pid (lzr_running($one->[0])) {
            next if defined lzr_why_not($pid);
            my ($ok, $says) = tool_stop($pid, "LZRDFNDR closed a program you deactivated, seen running again");
            push @closed, "$says ($one->[0], deactivated)" if $ok;
        }
    }
    return @closed;
}

sub lzr_processes {                       # lzr processes COMMAND [ID]: the look, what it found closed, then the command
    my ($command, $typed, $flags) = @_;
    return lzr_said('an incognito window has no LZRDFNDR.') if $INCOGNITO;
    mkdir $DIR, 0700;
    lzr_look() or return lzr_said('the system did not list its processes (ps), so nothing was looked at or done.');
    my @closed = lzr_seen();
    if (@closed) { lzr_look(); print STDERR map { "lzr: $_\n" } @closed }
    return lzr_list($flags) if $command eq 'list';
    return lzr_all($flags) if $command eq 'all';
    my ($what, $why) = lzr_which($typed);
    return lzr_said("$why.") unless $what;
    return lzr_analyze($what, $flags) if $command eq 'analyze';
    return lzr_kill($what, $flags) if $command eq 'kill';
    return lzr_deactivate($what, $flags) if $command eq 'deactivate';
    return lzr_reactivate($what, $flags) if $command eq 'reactivate';
    return lzr_contain($what, $flags) if $command eq 'contain';
    return lzr_release($what, $flags);
}

sub lzr_kib { my ($kib) = @_; return '-' unless defined $kib && length $kib; return $kib >= 1048576 ? sprintf('%.1f GiB', $kib / 1048576) : $kib >= 1024 ? sprintf('%.1f MiB', $kib / 1024) : "$kib KiB" }
sub lzr_json { my ($v) = @_; return 'null' unless defined $v; return $v if !ref $v && $v =~ /\A-?(?:0|[1-9][0-9]{0,15})(?:\.[0-9]{1,6})?\z/; return '[' . join(',', map { lzr_json($_) } @$v) . ']' if ref $v eq 'ARRAY'; return '{' . join(',', map { lzr_json("$_") . ':' . lzr_json($v->{$_}) } sort keys %$v) . '}' if ref $v eq 'HASH'; return '"' . ("$v" =~ s/(["\\])/\\$1/gr =~ s/([\x00-\x1f])/sprintf '\\u%04x', ord $1/ger) . '"' }    # numbers bare, the rest as strings
sub lzr_when { my ($iso) = @_; return $iso =~ /\A(\d{4}-\d\d-\d\d)T(\d\d:\d\d)/ ? "$1 $2 UTC" : $iso }
sub lzr_state_of { my ($pid) = @_; my $box = (grep { ($_->{child} // 0) == $pid && !defined $_->{ended} } values %{ lzr_contained() })[0]; return $box ? "contained ($box->{id})" : (grep { $_->[0] eq $TOOL{procs}{$pid}{path} } @{ lzr_deactivated() }) ? 'deactivated' : '' }

sub lzr_list {                            # lzr processes: what LZRDFNDR deactivated, and what it contains
    my ($flags) = @_;
    my (@off, @in);
    for my $one (@{ lzr_deactivated() }) { push @off, { id => lzr_id("program $one->[0]"), kind => 'program', what => $one->[0], since => $one->[1], running => [lzr_running($one->[0])] } }
    for my $one (@{ tool_kept() }) { push @off, { id => lzr_id("job $one->[0]"), kind => 'launchd job', what => $one->[0], since => $one->[2], running => [] } }
    my $boxes = lzr_contained();
    for my $box (map { $boxes->{$_} } sort keys %$boxes) {
        my $alive = !defined $box->{ended} && lzr_alive($box->{child}, $box->{began});
        push @in, { id => $box->{id}, pid => $alive ? 0 + $box->{child} : undef, program => $box->{program}, args => $box->{args}, since => $box->{since}, contained => ($box->{contained} // '') eq 'yes' ? 1 : 0,
            state => $alive ? 'running' : defined $box->{ended} ? "ended ($box->{status}, $box->{by})" : !defined $box->{child} ? 'starting' : 'gone', cpu => $alive ? $LZR_USE{ $box->{child} }[0] : undef, rss => $alive ? $LZR_USE{ $box->{child} }[1] : undef };
    }
    if ($flags->{json}) { print lzr_json({ deactivated => \@off, contained => \@in }), "\n"; return 0 }
    print lzr_paint(1, 'Deactivated by LZRDFNDR') . ' (' . @off . ")\n";
    print @off ? (sprintf("  %-6s %-12s %-18s %s\n", 'ID', 'KIND', 'SINCE', 'WHAT'), map { sprintf "  %s %-12s %-18s %s%s\n", lzr_paint(96, sprintf '%-6s', $_->{id}), $_->{kind}, lzr_when($_->{since}), $_->{what}, @{ $_->{running} } ? lzr_paint(33, '  running now: ' . join(' ', @{ $_->{running} })) : '' } @off) : "  none\n";
    print "\n", lzr_paint(1, 'Contained by LZRDFNDR') . ' (' . @in . ")\n";
    print @in ? (sprintf("  %-6s %-7s %-18s %-26s %s\n", 'ID', 'PID', 'SINCE', 'STATE', 'PROGRAM'), map { sprintf "  %s %-7s %-18s %-26s %s\n", lzr_paint(96, sprintf '%-6s', $_->{id}), $_->{pid} // '-', lzr_when($_->{since}), $_->{state} . ($_->{pid} ? ', ' . ($_->{contained} ? 'contained' : 'NOT SAID CONTAINED') : ''), $_->{program} } @in) : "  none\n";
    print "\n", lzr_paint(2, '"lzr processes all" lists every process with its ID; "lzr processes ID analyze|kill|deactivate|contain" acts on one; "lzr help processes" says more.'), "\n";
    return 0;
}

sub lzr_all {                             # lzr processes all: every process, each with its ID
    my ($flags) = @_;
    my $sort = $flags->{sort} // 'cpu';
    return lzr_wrong("--sort takes cpu, memory, pid or name, not \"$sort\"", 'processes all') unless $sort =~ /\A(?:cpu|memory|pid|name)\z/;
    my (%user, @rows);
    for my $pid (keys %{ $TOOL{procs} }) {
        my $proc = $TOOL{procs}{$pid};
        next if $flags->{mine} && $proc->{uid} != $<;
        $user{ $proc->{uid} } //= tool_plain((getpwuid $proc->{uid})[0] // $proc->{uid}, 32);
        push @rows, { id => lzr_id("proc $pid $proc->{began}"), pid => 0 + $pid, ppid => 0 + $proc->{ppid}, user => $user{ $proc->{uid} }, uid => 0 + $proc->{uid}, cpu => $LZR_USE{$pid} ? 0 + $LZR_USE{$pid}[0] : undef, rss_kib => $LZR_USE{$pid} ? 0 + $LZR_USE{$pid}[1] : undef,
            name => $proc->{path} =~ m{([^/]+)\z} ? $1 : $proc->{path}, program => $proc->{path}, started => $proc->{began}, lzrdfndr => lzr_state_of($pid) };
    }
    my %by = (cpu => sub { ($_[1]{cpu} // -1) <=> ($_[0]{cpu} // -1) || ($_[1]{rss_kib} // -1) <=> ($_[0]{rss_kib} // -1) }, memory => sub { ($_[1]{rss_kib} // -1) <=> ($_[0]{rss_kib} // -1) }, name => sub { lc $_[0]{name} cmp lc $_[1]{name} });
    @rows = sort { ($by{$sort} ? $by{$sort}->($a, $b) : 0) || $a->{pid} <=> $b->{pid} } @rows;
    if ($flags->{json}) { print lzr_json(\@rows), "\n"; return 0 }
    my $wide = lzr_columns() // 1000;
    printf "%-6s %7s %-10s %6s %10s %-22s %-16s %s\n", qw(ID PID USER CPU% MEMORY NAME LZRDFNDR PROGRAM);
    for my $row (@rows) {
        my $line = sprintf "%7s %-10s %6s %10s %-22s %-16s %s", $row->{pid}, substr($row->{user}, 0, 10), defined $row->{cpu} ? sprintf('%.1f', $row->{cpu}) : '-', lzr_kib($row->{rss_kib}), substr($row->{name}, 0, 22), $row->{lzrdfndr}, $row->{program};
        print lzr_paint(96, $row->{id}), ' ', substr($line, 0, $wide - 7), "\n";
    }
    print lzr_paint(2, scalar(@rows) . ' processes. "lzr processes ID analyze" watches one; "lzr help processes" says more.'), "\n";
    return 0;
}

sub lzr_columns { return unless -t STDOUT; my $size = "\0" x 8; return ioctl(STDOUT, 0x40087468, $size) && (unpack 'S2', $size)[1] ? (unpack 'S2', $size)[1] : undef }    # TIOCGWINSZ: the terminal's width

sub lzr_pid_of {                          # the process an ID stands for now: a process, a deactivated program's one process, a contained process; or nothing and why
    my ($what) = @_;
    my ($id, $kind, $it) = @$what;
    return $it if $kind eq 'proc';
    if ($kind eq 'box') { return (undef, "the contained process $id has ended") unless !defined $it->{ended} && lzr_alive($it->{child}, $it->{began}); return $it->{child} }
    my @pids = $kind eq 'program' ? lzr_running($it) : ();    # a job switched off runs nothing that launchd holds
    return (undef, "$id is " . ($kind eq 'job' ? "the launchd job $it" : $it) . ', and nothing of it runs now') unless @pids;
    return (undef, "$id is $it, which runs as " . @pids . ' processes now: name one by its own ID (lzr processes all)') if @pids > 1;
    return $pids[0];
}

sub lzr_sample {                          # [C20] what a process uses now: its share of a processor over half a second (from the time ps says it ran), its resident memory and, for your own process, its footprint, both in KiB
    my ($pid) = @_;
    my @at;
    for my $n (0, 1) {
        Time::HiRes::sleep(0.5) if $n;
        my ($said) = tool_asked("sample.$pid", 5, '/bin/ps', '-o', 'time=,rss=', '-p', $pid);
        my ($time, $rss) = $said =~ /^\s*(\S+)\s+(\d+)\s*$/ or return;
        push @at, [now(), lzr_seconds($time), $rss];
    }
    my $share = $at[1][0] > $at[0][0] ? 100 * ($at[1][1] - $at[0][1]) / ($at[1][0] - $at[0][0]) : 0;
    my $foot = lzr_footprint($pid);
    return (($share < 0 ? 0 : $share), $at[1][2], $foot);
}
sub lzr_seconds { my ($t) = @_; my ($d, $h, $m, $s) = $t =~ /\A(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+(?:\.\d+)?)\z/ or return 0; return ((($d // 0) * 24 + ($h // 0)) * 60 + $m) * 60 + $s }    # ps's [[DD-]HH:]MM:SS.cc as seconds
sub lzr_footprint {                       # [C20] macOS's answer about a process of yours (proc_pid_rusage, the call libproc makes): its footprint in KiB, as Activity Monitor's Memory; nothing for another user's
    my ($pid) = @_;
    return unless $^O eq 'darwin' && $TOOL{procs}{$pid} && $TOOL{procs}{$pid}{uid} == $<;
    my $usage = "\0" x 296;
    return unless syscall(336, 9, $pid + 0, 4, 0, $usage, 296) == 0;    # proc_info: PROC_INFO_CALL_PIDRUSAGE, RUSAGE_INFO_V4
    return int((unpack 'Q<*', substr($usage, 16))[7] / 1024);     # ri_phys_footprint
}

sub lzr_kill {                            # [C20] lzr processes kill: what the process uses now, your word, then TERM, and KILL three seconds on
    my ($what, $flags) = @_;
    my ($pid, $why) = lzr_pid_of($what);
    return lzr_said("$why.") unless $pid;
    $why = lzr_why_not($pid);
    return lzr_said("$why. Nothing was done.") if defined $why;
    my $proc = $TOOL{procs}{$pid};
    my ($share, $rss, $foot) = lzr_sample($pid) or return lzr_said("process $pid ended before it was measured.");
    print "Process $pid ($what->[0]), started $proc->{began}: $proc->{path}\n", sprintf("  now: %.1f%% of a processor, memory %s%s\n", $share, lzr_kib($rss), defined $foot ? ' resident, ' . lzr_kib($foot) . ' footprint' : '');
    if ($flags->{'dry-run'}) { print "Would ask it to end (TERM), and end it (KILL) if it has not after three seconds. It may start again later. Nothing was done.\n"; return 0 }
    return 1 unless lzr_asked('Kill it? It ends now, and may start again when something starts it.', $flags);
    my ($ok, $says) = tool_stop($pid, 'You ended a process with lzr processes kill');
    return lzr_said("$says.") unless $ok;
    for (my $until = now() + 1; now() < $until && kill(0, $pid);) { Time::HiRes::sleep(0.05) }
    if (kill 0, $pid) {
        return lzr_said("process $pid is no longer the one that was listed; it was left as it is.") unless lzr_alive($pid, $proc->{began});
        record("You ended a process with lzr processes kill, which did not end when asked: the process $pid, started $proc->{began}, $proc->{path}") or return lzr_said("process $pid: the log could not be written, so it was left running.");
        kill 'KILL', $pid;
        for (my $until = now() + 2; now() < $until && kill(0, $pid);) { Time::HiRes::sleep(0.05) }
        $says = kill(0, $pid) ? "process $pid was ended (KILL) and is still going" : "process $pid did not end when asked, and was ended (KILL)";
    }
    print ucfirst($says), ". It may start again when something starts it; \"lzr processes $what->[0] deactivate\" keeps it off.\n";
    return 0;
}

sub lzr_deactivate {                      # [C20] lzr processes deactivate: the program kept in the list, its jobs switched off, its processes closed
    my ($what, $flags) = @_;
    my ($id, $kind, $it) = @$what;
    return lzr_said("$id is deactivated already.") if $kind eq 'program' || $kind eq 'job';
    my $path = $kind eq 'proc' ? $TOOL{procs}{$it}{path} : $it->{program};
    my $why = lzr_program_why_not($path);
    return lzr_said("$why. Nothing was done.") if defined $why;
    if ($kind eq 'proc') { $why = lzr_why_not($it); return lzr_said("$why. Nothing was done.") if defined $why }
    my @pids = lzr_running($path);
    my @jobs = grep { defined tool_may('quiet', $_) } lzr_jobs_of($path, @pids);
    print "Deactivate $path?\n", "  closes now: " . (@pids ? join(' ', map { "process $_" } @pids) : 'nothing (it does not run)') . "\n", '  switches off: ' . (@jobs ? join(', ', map { "the launchd job $_" } @jobs) : 'no launchd job of your account runs it') . "\n", "  and LZRDFNDR closes it whenever it sees it run again, until \"lzr processes reactivate " . lzr_id("program $path") . "\".\n";
    if ($flags->{'dry-run'}) { print "Nothing was done.\n"; return 0 }
    return 1 unless lzr_asked('Deactivate it?', $flags);
    record("You deactivated a program with lzr processes deactivate: $path") or return lzr_said('the log could not be written, so nothing was done.');
    my $kept = lzr_deactivated();
    lzr_keep_deactivated([(grep { $_->[0] ne $path } @$kept), [$path, strftime('%Y-%m-%dT%H:%M:%SZ', gmtime)]]) or return lzr_said('the list of deactivated programs could not be written, so nothing was done.');
    my @said = map { (tool_quiet($_))[1] } @jobs;
    push @said, map { (tool_stop($_, 'You deactivated its program with lzr processes deactivate'))[1] } grep { !defined lzr_why_not($_) } @pids;
    print map({ ucfirst("$_.\n") } @said), "Deactivated: $path (ID " . lzr_id("program $path") . ").\n";
    return 0;
}

sub lzr_reactivate {                      # [C20] lzr processes reactivate: off the list; a job switched on again
    my ($what, $flags) = @_;
    my ($id, $kind, $it) = @$what;
    return lzr_said("$id is not deactivated: \"lzr processes\" lists what is.") unless $kind eq 'program' || $kind eq 'job';
    print 'Reactivate ' . ($kind eq 'job' ? "the launchd job $it (switched on again)" : $it) . "? Nothing is started.\n";
    if ($flags->{'dry-run'}) { print "Nothing was done.\n"; return 0 }
    return 1 unless lzr_asked('Reactivate it?', $flags);
    if ($kind eq 'job') {
        $TOOL{kept} = { map { $_->[0] => $_ } @{ tool_kept() } };
        my ($ok, $says) = tool_wake($it);
        print ucfirst("$says.\n");
        return $ok ? 0 : 1;
    }
    record("You reactivated a program with lzr processes reactivate: $it") or return lzr_said('the log could not be written, so nothing was done.');
    lzr_keep_deactivated([grep { $_->[0] ne $it } @{ lzr_deactivated() }]) or return lzr_said('the list of deactivated programs could not be written, so it stays deactivated.');
    print "Reactivated: $it. It may run again; LZRDFNDR no longer closes it.\n";
    return 0;
}

# A window looks for the programs you deactivated every $LZR_SEEN seconds,
# from sub tool_watch, and closes each one it sees. With none deactivated
# nothing is read at all.                                             # [C20]
sub lzr_due { return unless -s "${\ shared()}/deactivated"; return ($LZR_WATCHED // 0) + $LZR_SEEN - now() }    # the seconds until that look; nothing when none is deactivated
sub lzr_watch {
    return if $INCOGNITO || !-s "${\ shared()}/deactivated" || defined $LZR_WATCHED && now() < $LZR_WATCHED + $LZR_SEEN;
    $LZR_WATCHED = now();
    local @TOOL{qw(procs own)};           # the window's own look at the tool stays as it was
    lzr_look() or return;
    lzr_seen();
    return;
}

sub lzr_argv {                            # [C20] the arguments a process of yours was started with, exactly, as macOS keeps them (sysctl KERN_PROCARGS2): the first is how it was named; nothing when they cannot be read
    my ($pid) = @_;
    return unless $^O eq 'darwin';
    my ($buffer, $size) = ("\0" x $LZR_ARGS, pack('Q', $LZR_ARGS));
    return unless syscall(202, pack('i3', 1, 49, $pid + 0), 3, $buffer, $size, 0, 0) == 0;    # __sysctl: CTL_KERN, KERN_PROCARGS2, the process
    $buffer = substr $buffer, 0, unpack('Q', $size);
    my ($count, $rest) = unpack 'i a*', $buffer;
    $rest =~ s/\A[^\0]+\0+// or return;     # its program, and the padding after it
    my @strings = split /\0/, $rest, -1;     # the arguments, each as it was (an empty one too), then the environment
    return unless $count >= 1 && $count <= @strings;
    return @strings[0 .. $count - 1];
}

sub lzr_contain {                         # [C20] lzr processes contain: the process ended and its program started again, with the same arguments, in the container, by a keeper of its own
    my ($what, $flags) = @_;
    my ($id, $kind, $pid) = @$what;
    return lzr_said("$id is contained already.") if $kind eq 'box';
    return lzr_said("$id is deactivated: reactivate it first (lzr processes reactivate $id), then contain one of its processes.") unless $kind eq 'proc';
    my $proc = $TOOL{procs}{$pid};
    my $why = lzr_why_not($pid) // lzr_program_why_not($proc->{path});
    return lzr_said("$why. Nothing was done.") if defined $why;
    my @argv = lzr_argv($pid);
    return lzr_said("the arguments process $pid runs with could not be read (or are longer than $LZR_ARGS bytes), so it could not be started again the same way. Nothing was done.") unless @argv;
    my $own = $proc->{path} =~ m{^(.*\.app)/Contents/MacOS/[^/]+$} ? $1 : $proc->{path};    # what the container lets it read of its own, as sub contain says
    my @jobs = grep { defined tool_may('quiet', $_) } lzr_jobs_of($proc->{path}, $pid);
    print "Contain process $pid ($id): $proc->{path}\n", "  ends it now, and starts it again with the same arguments in LZRDFNDR's container: no network, no file written, no other program started,\n  no system service, no variable of yours, and nothing to read but the system and $own.\n",
        '  switches off: ' . (@jobs ? join(', ', map { "the launchd job $_" } @jobs) : 'no launchd job of your account runs it') . "\n", "  A program that needs what the container refuses stops at once; \"lzr processes\" says how it ended.\n";
    if ($flags->{'dry-run'}) { print "Nothing was done.\n"; return 0 }
    return 1 unless lzr_asked('Contain it?', $flags);
    record("You contained a process with lzr processes contain: " . tool_may('stop', $pid)) or return lzr_said('the log could not be written, so nothing was done.');
    my @said = map { (tool_quiet($_))[1] } @jobs;
    my ($ok, $says) = tool_stop($pid, 'You contained a process with lzr processes contain, which ended it to start it again contained');
    return lzr_said("$says, so nothing was started.") unless $ok;
    for (my $until = now() + 3; now() < $until && kill(0, $pid);) { Time::HiRes::sleep(0.05) }
    return lzr_said("process $pid did not end, so no contained copy of it was started. \"lzr processes $id kill\" ends it.") if lzr_alive($pid, $proc->{began});
    my $box = { id => lzr_id("box $proc->{path} $pid $proc->{began} " . now()), program => $proc->{path}, own => $own, args => [@argv[1 .. $#argv]], since => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime) };
    lzr_write_contained($box) && lzr_keeper($box) or return lzr_said("process $pid was ended, and its contained copy could not be started.");
    my $now = {};
    for (my $until = now() + 15; now() < $until && !defined $now->{contained}; Time::HiRes::sleep(0.1)) { $now = lzr_contained()->{ $box->{id} } // {} }
    print map({ ucfirst("$_.\n") } @said, $says);
    return lzr_said("the keeper of $box->{id} did not say within 15 seconds whether it started; \"lzr processes\" shows it when it does.") unless defined $now->{contained};
    return lzr_said("$proc->{path} started, and the system did not say it was in the container, so it was ended at once. Nothing of it runs.") if $now->{contained} eq 'no';
    return lzr_said("$proc->{path} ended at once in the container ($now->{status}" . (defined $now->{said} ? ", saying: $now->{said}" : '') . "): it needs what the container refuses. \"lzr processes release $box->{id}\" forgets it.") if defined $now->{ended};
    print "Contained: $proc->{path} runs as process $now->{child}, and the system says it is in the container (ID $box->{id}; \"lzr processes release $box->{id}\" ends it).\n";
    return 0;
}

sub lzr_keeper {                          # [C20] the keeper of a contained process, apart from this terminal: it starts the program in the container, asks the system whether it is there, holds it, and writes how it ended
    my ($box) = @_;
    my $first = fork // return 0;
    if ($first) { waitpid $first, 0; return $? == 0 }
    POSIX::setsid();
    my $keeper = fork // POSIX::_exit(1);
    POSIX::_exit(0) if $keeper;
    open STDIN, '<', '/dev/null'; open STDOUT, '>', '/dev/null'; open STDERR, '>', '/dev/null';
    $0 = "core-lzrprf-contain $box->{id}";
    @$box{qw(keeper by)} = ($$, 'its keeper');
    my ($released, $child) = (0);
    local $SIG{ALRM} = sub { kill 'KILL', $child if $child };    # a program that does not end when asked is ended three seconds on
    local $SIG{TERM} = sub { $released = 1; if ($child) { kill 'TERM', $child; alarm 3 } };    # a release: sub lzr_release
    pipe(my $heard, my $says) or do { @$box{qw(ended status)} = (strftime('%Y-%m-%dT%H:%M:%SZ', gmtime), 'not started'); lzr_write_contained($box); POSIX::_exit(1) };
    $child = fork // do { @$box{qw(ended status)} = (strftime('%Y-%m-%dT%H:%M:%SZ', gmtime), 'not started'); lzr_write_contained($box); POSIX::_exit(1) };
    unless ($child) {                     # the program: no byte written into a file, no memory dump, no variable, no descriptor but nowhere; sandbox-exec puts it in the container, then becomes it
        my $none = pack 'QQ', 0, 0;       # a variable: perl hands syscall a constant's bytes as read-only, and dies
        syscall(195, 1, $none) == 0 && syscall(195, 4, $none) == 0 or POSIX::_exit(127);    # setrlimit: RLIMIT_FSIZE and RLIMIT_CORE, now and for good
        %ENV = ();
        become(undef, undef, $says, contain('', $box->{program}), @{ $box->{args} });    # the page container, as sub contain writes it for the program
    }
    $SIG{TERM}->() if $released;          # a release that came before fork gave the number
    close $says;
    my ($began) = tool_asked("proc.$child", 5, '/bin/ps', '-o', 'lstart=', '-p', $child);
    @$box{qw(child began)} = ($child, $began =~ s/^\s+|\s+$//gr =~ s/\s+/ /gr);
    my $in = inside($child);
    my $held = waitpid($child, POSIX::WNOHANG()) == 0;    # still running after the answer, so the answer was about it running
    my $status = $held ? undef : $?;
    if ($witness) { close $to_witness; waitpid $witness, 0; undef $witness }
    $box->{contained} = $in && $held ? 'yes' : $held ? 'no' : 'unknown';
    if ($box->{contained} eq 'no') { kill 'KILL', $child; $box->{by} = 'lzrprf, as the system did not say it was contained' }
    lzr_write_contained($box);
    my ($last, $got) = ('');
    while (($got = sysread $heard, my $more, 4096) || !defined $got && $!{EINTR}) { $last = substr($last . ($more // ''), -400) }    # what it wrote on its errors, to its end: the last words kept
    $box->{said} = tool_plain($last =~ s/\s+/ /gr =~ s/^ | $//gr, 400) if length $last;
    unless (defined $status) { 1 while waitpid($child, 0) == -1 && $!{EINTR}; $status = $?; alarm 0 }
    $box->{by} = 'lzr processes release' if $released;
    @$box{qw(ended status)} = (strftime('%Y-%m-%dT%H:%M:%SZ', gmtime), $status & 127 ? 'ended by signal ' . ($status & 127) : 'exit ' . ($status >> 8));
    record("A process LZRDFNDR contained ended ($box->{status}, by $box->{by}): the process $child, $box->{program}");
    lzr_write_contained($box) unless $released;    # a release forgets it: lzr removes its file
    POSIX::_exit(0);
}

sub lzr_keeper_is { my ($box) = @_; return 0 unless ($box->{keeper} // '') =~ /\A[1-9][0-9]{0,6}\z/; my ($said) = tool_asked("keeper.$box->{keeper}", 5, '/bin/ps', '-ww', '-o', 'uid=,args=', '-p', $box->{keeper}); return $said =~ /\A\s*(\d+)\s+core-lzrprf-contain ([0-9a-z]{5})(?:\s|\z)/ && $1 == $< && $2 eq $box->{id} }    # the keeper is still running as that keeper: yours, by its name (macOS shows what was in the place its name was written over after it)

sub lzr_release {                         # [C20] lzr processes release: the contained process ended by its keeper, and forgotten; nothing is started outside
    my ($what, $flags) = @_;
    my ($id, $kind, $box) = @$what;
    return lzr_said("$id is not contained: \"lzr processes\" lists what is.") unless $kind eq 'box';
    my $keeper = !defined $box->{ended} && lzr_keeper_is($box);
    my $orphan = !$keeper && !defined $box->{ended} && ($box->{child} // '') =~ /\A[1-9][0-9]{0,6}\z/ && lzr_alive($box->{child}, $box->{began}) && ($TOOL{procs}{ $box->{child} }{uid} // -1) == $<;
    print $keeper || $orphan ? "Release $id? Its contained process $box->{child} ($box->{program}) is ended, and not started again outside: start it as you usually do.\n" : "Forget $id? $box->{program} runs no more" . (defined $box->{status} ? " ($box->{status})" : '') . ".\n";
    if ($flags->{'dry-run'}) { print "Nothing was done.\n"; return 0 }
    return 1 unless lzr_asked('Release it?', $flags);
    record("You released a contained process with lzr processes release: $id, $box->{program}" . ($keeper || $orphan ? ", the process $box->{child}" : ', which had ended')) or return lzr_said('the log could not be written, so nothing was done.');
    if ($keeper || $orphan) {
        my $whom = $keeper ? $box->{keeper} : $box->{child};
        kill 'TERM', $whom;
        for (my $until = now() + 6; now() < $until && kill(0, $whom);) { Time::HiRes::sleep(0.05) }
        return lzr_said("the keeper of $id did not end; it is still listed.") if kill 0, $whom;
    }
    unlink "${\ shared()}/contained/$id";
    print "Released: $id ($box->{program}).\n";
    return 0;
}
