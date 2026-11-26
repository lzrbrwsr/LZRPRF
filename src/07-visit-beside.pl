# A page run read, and a page's second run started beside its first.
#
# A page that names style sheets on its own host is laid out twice [C14]: a
# first run, told that none came with the answer, names them; lzrprf fetches
# them and a second run lays the page with them. The sheets the answer names
# are begun ahead of the first run (sub ahead_sheets), and on yle.fi they
# were here from 17 ms before the first run ended to 5 ms after it, while the
# second run began 22 to 40 ms after they were (measured 2026-11-25). So the moment the first run is started
# and computes, what the page names is begun (sub prefetch_begin, which
# waited before that run until now), and when every sheet begun ahead is
# here within $BESIDE_SECONDS, they are taken as sub sheeted takes
# them, with every check and every line of the log it writes, and the second
# run is started with them at once: handed the same frame and the same
# answer a second run is handed, by the same keeper, under the same seal and
# container. Nothing of it is read yet. It is the run shown only when the
# first run then names exactly those sheets in that order (sub
# beside_sheets), and when the frame and the answer sub contained makes for
# the second run are, byte for byte, what this run was handed (sub
# beside_taken): the size, the fonts, the sheets, the permissions and the
# cookies. In every other case it is ended and reaped unread, and the page
# goes on as it always did. A copy of lzrprf only forgets it. Never through
# Tor [C17], where nothing is begun ahead.
sub beside_wanted { $BESIDE_WANTED = [@_]; prefetch_begin(@_); return }    # ($url, $host, $got, $kept, $where): what sub beside_begun begins when the page's first run is started

sub beside_fds {                          # lzrprf's ends of the run started beside and of the first run it is started beside: no keeper holds them
    return grep { defined } ($BESIDE && $BESIDE->{run} ? @{ $BESIDE->{run} }{qw(relay from hold)} : ()), @{ $BESIDE_FIRST // [] };
}

sub beside_dropped {                      # the run started beside ended and reaped, unread; a copy of lzrprf only forgets it
    my $one = $BESIDE or return;
    undef $BESIDE;
    my $run = $one->{run} or return;
    if ($one->{owner} == $$) { kill 'KILL', @$run{qw(keeper page)}; waitpid $_, 0 for @$run{qw(keeper page)} }    # the keeper first, as sub contained ends a run
    close $_ for grep { defined } @$run{qw(relay from hold)};
    return;
}

sub beside_sheets {                       # ($named): the frame of the sheets taken beside the first run, when that run names exactly them; else the run beside is ended, and the sheets go back to be taken by sub sheeted
    my ($named) = @_;
    my $one = $BESIDE or return;
    if ($one->{owner} != $$ || join("\n", @$named) ne join("\n", @{ $one->{named} })) {
        if ($one->{owner} == $$) { $AHEAD{$_} //= $one->{ahead}{$_} for keys %{ $one->{ahead} }; %BESIDE_LOGGED = map { $_ => 1 } keys %{ $one->{ahead} } }    # each as it was when it was all here: sub fetched_together takes it, and nothing is asked twice
        return beside_dropped();
    }
    undef $BESIDE unless $one->{run};
    timed('sheets-beside ' . scalar @$named) if $TIMED;
    return @{ $one->{sheeted} };
}

sub beside_taken {                        # ($fed, $page, $url, $plain): the run started beside, for the page run that is handed exactly what it was handed; any other page run ends it
    my ($fed, $page, $url, $plain) = @_;  # $plain: no run of the local home and none handed back unread ($soon)
    my $one = $BESIDE or return;
    return unless $page;                  # a picture's run or a judging run is no run of the page
    return beside_dropped() unless $plain && $one->{run} && $one->{owner} == $$ && $one->{run}{url} eq $url && $one->{run}{fed} eq $fed;
    undef $BESIDE;
    delete $one->{run}{fed};
    return $one->{run};
}

sub beside_begun {                        # ($first, $sheets, $keep, $tool): called by sub contained when a run is started, before it is read
    my ($first, $sheets, $keep, $tool) = @_;
    my $wanted = $BESIDE_WANTED or return;
    undef $BESIDE_WANTED;
    my ($url, $host, $got, $kept, $where) = @$wanted;
    return unless $keep && !$tool && ($sheets // '') eq "=sheets\n" && $first->{url} eq $url && $where && !$TOR_WANTED && $$ == $FRESH;
    my @urls = @AHEAD_SHEETS or return;
    return if grep { !$AHEAD{$_} || substr($_, 0, length("https://$host/")) ne "https://$host/" } @urls;    # every sheet the answer names was begun, on the page's own host
    my @named = map { substr($_, length "https://$host") } @urls;
    $BESIDE_FIRST = [grep { defined } @$first{qw(relay from hold)}];    # the second run's keeper is not to hold the first run's pipes
    beside_second($first, $url, $host, $got, $kept, $where, \@urls, \@named);
    undef $BESIDE_FIRST;
    return;
}

sub beside_second {                       # the wait for the sheets begun ahead, beside the first run, and the second run started with them
    my ($first, $url, $host, $got, $kept, $where, $urls, $named) = @_;
    my @urls = @$urls;
    spare_for($url);                      # the second run's process
    my $until = now() + $BESIDE_SECONDS;
    while (my @open = grep { !$_->{done} } @AHEAD{@urls}) {
        return if now() >= $until || !alive();
        my $ready = '';
        vec($ready, fileno $_->{from}, 1) = 1 for @open;
        select($ready, undef, undef, $BESIDE_SECONDS) > 0 or next;
        together_read($_) for grep { vec($ready, fileno $_->{from}, 1) } @open;
    }
    my %ahead = map { $_ => { %{ $AHEAD{$_} } } } @urls;
    undef $BESIDE_FONTS;
    my @sheeted = sheeted($named, $host, $where, $kept) or return;    # [C14] [C23] [C27] [C5] every check and every line of the log, as for a first run that named them
    my (undef, undef, $run) = contained($url, $got, $sheeted[0], 1, undef, undef, 'beside');
    $BESIDE = { owner => $$, run => $run, named => $named, sheeted => \@sheeted, ahead => \%ahead };
    ahead_fonts(@{ $BESIDE_FONTS // return });    # [C30] the fonts these sheets name, and
    undef $BESIDE_FONTS;
    prefetch_later() if $run;             # [C19] what the page names, judged and begun while the run started lays the page: after its start, where both stood before it
    return;
}

sub run_read {                            # ($run, $keep, $sheets, $tool): the second half of sub contained: a run that is started and contained, read to its first list or to its end
    my ($run, $keep, $sheets, $tool) = @_;
    my ($page, $feeder, $relay, $from_page, $hold, $local_home, $url) = @$run{qw(page keeper relay from hold home url)};
    my $app = $run->{kept_app};
    my ($wrote, $until, $open, $looked, $ready_at, $early, $outrun) = ('', now() + $PAGE_SECONDS, 1, 0, -1); prefetch_later() if !$app && ($sheets // q{}) ne "=sheets\n";    # [C19] the run with its sheets is started: what the page names is judged and begun while it lays the page (17-prefetch.pl)
    while ($open && now() < $until && length $wrote <= $PAGE_BYTES && alive()) {
        my $ready = '';
        vec($ready, fileno $from_page, 1) = 1;
        vec($ready, fileno $FROM, 1) = 1 if $OUTRUN && $FROM;    # a relayout hears the window while it runs (sub outrun)
        pictures_waited($ready, 1) or next;    # as select, and the pictures begun ahead are heard meanwhile (08-pictures.pl)
        if ($OUTRUN && $FROM && vec($ready, fileno $FROM, 1)) { last if $outrun = outrun(); next unless vec($ready, fileno $from_page, 1) }
        $open = sysread($from_page, $wrote, 65536, length $wrote) // $!{EINTR};
        next unless $keep;
        while ($wrote =~ /\A=(?:fetch|permit|early|soon|wsopen|wssend|wsclose|store) /) {    # [C19] a request of the page while it is read (an external script), before its first list: answered as one after it, within the same $PAGE_SECONDS, and counted in the same $LIVE_FETCH_MOST of its life; [C26] or a question whether a script may run, answered at once
            $early //= { page => $page, keeper => $feeder, relay => $relay, from => $from_page, hold => $hold, looked => 0, home => $local_home, url => $url, host => (address($url))[1] // '', fetches => 0 };
            @$early{qw(kept_app storage_epoch)} = ($app, $run->{storage_epoch}) if $app;
            $early->{held} = $wrote;
            my $asked = live_asked($early) or last;    # not all there yet
            $READ_ASKED++ unless substr($asked->[0], 0, 8) eq '=permit ' || $asked->[0] eq '=early' || substr($asked->[0], 0, 6) eq '=soon ' || substr($asked->[0], 0, 3) eq '=ws' || substr($asked->[0], 0, 7) eq '=store ';    # counted whatever comes of it: fetched, or refused by lzrprf; a question to run a script asks for no address
            live_fetched($early, $asked);
            return (undef, 'ended') if $early->{ended};    # a request of no form, or a reply the page did not take: it is ended as a page kept running is (sub live_end)
            ($wrote, $looked) = ($early->{held}, 0);
        }
        $ready_at = index($wrote, "\n=ready\n", $looked > 7 ? $looked - 7 : 0);    # a line no list holds: every line of a list begins with a letter, or is "=page" and the lines of its head
        $looked = length $wrote;
        last if $ready_at >= 0;
    }
    timed("run-read $$ " . length $wrote) if $TIMED;
    if ($outrun) { kill 'KILL', $feeder, $page; waitpid $_, 0 for $feeder, $page; return (undef, 'outrun') }    # a newer width was said: this run is of no use, and the next is not kept waiting behind it
    if ($ready_at >= 0 && length $wrote <= $PAGE_BYTES) {    # the page is kept running: its first list, and what it wrote after "=ready" is the beginning of its next answer
        return (substr($wrote, 0, $ready_at + 1), undef, { page => $page, keeper => $feeder, relay => $relay, from => $from_page, hold => $hold, held => substr($wrote, $ready_at + 8), looked => 0, wide => $VIEW[0], scale => $VIEW_SCALE, until => $app ? $app->{until} : now() + $LIVE_SECONDS, kept_app => $app, storage_epoch => $run->{storage_epoch}, bytes => length($wrote) - $ready_at - 8, waiting => 0, focus => 0, home => $local_home, url => $url, fetches => $early ? $early->{fetches} : 0, heard => now() });
    }
    if ($tool && $tool eq 'judge' && !$open && length $wrote <= $PAGE_BYTES) {    # [C28] complete output is not enough: the judge must exit successfully within the same clock
        my $exit;
        while (now() < $until && alive()) {
            my $done = waitpid $page, POSIX::WNOHANG();
            if ($done == $page) { $exit = $?; last }
            last if $done == -1;
            Time::HiRes::sleep(0.001);
        }
        kill 'KILL', $feeder; waitpid $feeder, 0;
        if (!defined $exit) { kill 'KILL', $page; waitpid $page, 0; return (undef, 'late') }
        return $exit == 0 ? ($wrote) : (undef, 'ended');
    }
    kill 'KILL', $feeder, $page;
    waitpid $_, 0 for $feeder, $page;
    return (undef, 'late') if $open && length $wrote <= $PAGE_BYTES;
    return (undef, 'large') if length $wrote > $PAGE_BYTES;
    return ($wrote);
}
