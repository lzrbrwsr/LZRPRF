# The style sheets a page names. Its first run may write a line
# "=sheets /path ..." of up to eight paths on its own host, and each is
# fetched the way a picture is: its line in the log first, then "fetch" to the
# same checked addresses the page came from. One clock of $SHEET_SECONDS is
# for starting them all. A sheet not begun by then, a fetch that failed and an
# answer larger than $SHEET_BYTES each go with length 0. Returns the frame for
# the second run, "=sheets", the length of each, a line end, then the answers
# as the site sent them, and how many had bytes; or nothing when a line of the
# log could not be written.                                              # [C14]
sub sheeted {
    my ($named, $host, $where, $kept) = @_;
    %BESIDE_LOGGED = (); if (my @had = beside_sheets($named)) { return @had }    # taken beside the first run, which named exactly these (07-visit-beside.pl)
    timed('sheets-begin ' . scalar @$named) if $TIMED;
    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;    # as in visit: no line of these requests falls into a clearing of the log
    my (@got, @jobs);
    for my $n (0 .. $#$named) {
        my $url = "https://$host$named->[$n]";
        if (listed($url)) { refused("a style sheet the page $host names", $kept) or return; push @got, ''; next }    # [C23] handed over with length 0
        if (my $filter = filter_said($url, 'stylesheet', $host)) { record("$url not fetched: $filter", $kept) or return; push @got, ''; next }    # [C27] after [C23]: handed over with length 0
        $BESIDE_LOGGED{$url} or $AHEAD{$url} && $AHEAD{$url}{logged} && $AHEAD{$url}{key} eq ahead_key([$url, $where, undef, ['style', $host]]) or record("$url -> lzrprf connects to the first that answers of: " . join(', ', map { $_->{text} } @$where), $kept) or return;    # [C5] written down first, connected second; a sheet taken beside a first run that then named other sheets has its two lines already, and its one fetch is not written down twice; one begun ahead for this very request (the key sub fetched_together takes it by) has this line already, any other is fetched afresh and written down here
        push @got, undef;
        push @jobs, [$n, $url];
    }
    busy('Fetching the ' . @jobs . (@jobs == 1 ? ' style sheet' : ' style sheets') . " of the page $host") if @jobs;
    my @answers = fetched_together(map { [$_->[1], $where, undef, ['style', $host]] } @jobs);    # [C6] [C7] side by side, each the request it always was
    for my $i (0 .. $#jobs) {
        my ($n, $url) = @{ $jobs[$i] };
        my ($got, $why, $from) = @{ $answers[$i] };
        delete $BESIDE_LOGGED{$url} or record("$url " . ($why ? "failed: $why" : 'answered: ' . length($got) . " bytes from $from"), $kept) or return;
        $got[$n] = !$why && length $got <= $SHEET_BYTES ? $got : '';
    }
    %BESIDE_LOGGED = ();
    close $request;
    ($BESIDE_FIRST ? sub { $BESIDE_FONTS = [@_] } : \&ahead_fonts)->($host, $where, $kept, map { ["https://$host$named->[$_]", $got[$_]] } grep { length $got[$_] } 0 .. $#got);    # [C30] the fonts these sheets name, begun now: here when the next run names them
    return (join(' ', '=sheets', map { length } @got) . "\n" . join('', @got), scalar grep { length } @got);
}

# The web fonts a page's sheets name. A run handed sheets may write a line
# "=webfonts /path|/path ..." of up to $FONTS fonts on the page's own host,
# which the application chose from the sheets' @font-face rules (https on
# the page's origin alone, of a format it draws), each up to $FONT_TRIES
# paths tried in order until one answers 200, as a src entry that fails
# falls through to the next. Each path is fetched as a sheet is:
# held to the illegal-content list, then the filter lists as a font, its line
# in the log first, then "fetch" to the same checked addresses the page came
# from, which holds it to LZRDFNDR's judgement and to Tor when Tor is on.
# One clock of $FONT_SECONDS is for starting them all, and each is cut at
# $FONT_BYTES; a font not begun in time, refused, failed, larger, or past
# $FONTS_TOTAL of all of them is not handed over; a font none of whose paths
# is goes with length 0, and the application draws
# that face's text in its own. Nothing of a font is written to the disk: the
# answers are held in memory for the page shown alone, in an incognito window
# as in any. Returns the frame for the next run, "=webfonts", the length of
# each, a line end, then the answers as the site sent them, and how many had
# bytes; or nothing when a line of the log could not be written.        # [C30]
sub fonted {
    my ($named, $host, $where, $kept) = @_;
    timed('fonts-begin ' . scalar @$named) if $TIMED;
    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;    # as in visit: no line of these requests falls into a clearing of the log
    my ($until, $total) = (now() + $FONT_SECONDS, 0);
    my @paths = map { [split /\|/, $_] } @$named;    # each font its paths in order, until one answers 200
    my @got = ('') x @$named;
    while (grep { scalar @$_ } @paths) {      # a round: the next path of every font that has none yet, side by side
        last if now() >= $until || !alive();  # not begun in time: nothing more is fetched
        my @jobs;
        for my $n (0 .. $#paths) {
            while (@{ $paths[$n] }) {
                my $url = "https://$host" . shift @{ $paths[$n] };
                if (listed($url)) { refused("a web font the page $host names", $kept) or return; next }    # [C23] not handed over
                if (my $filter = filter_said($url, 'font', $host)) { record("$url not fetched: $filter", $kept) or return; next }    # [C27] after [C23]: not handed over
                record("$url -> lzrprf connects to the first that answers of: " . join(', ', map { $_->{text} } @$where), $kept) or return;    # [C5] written down first, connected second
                push @jobs, [$n, $url];
                last;
            }
        }
        last unless @jobs;
        busy('Fetching the ' . @jobs . (@jobs == 1 ? ' web font' : ' web fonts') . " of the page $host");
        my @answers = fetched_together(map { [$_->[1], $where, [$FONT_BYTES, $FONT_SECONDS], ['font', $host]] } @jobs);    # [C6] [C7] side by side, each the request it always was
        for my $i (0 .. $#jobs) {
            my ($n, $url) = @{ $jobs[$i] };
            my ($got, $why, $from) = @{ $answers[$i] };
            $why ||= length($got) > $FONT_BYTES ? "it is larger than $FONT_BYTES bytes" : $total + length($got) > $FONTS_TOTAL ? "the page's fonts would be more than $FONTS_TOTAL bytes" : $got !~ m{\AHTTP/[0-9.]+ 200[ \r]} ? 'its answer is not 200' : undef;
            record("$url " . ($why ? "not handed over: $why" : 'answered: ' . length($got) . " bytes from $from, handed to $APP for a web font"), $kept) or return;
            next if $why;
            ($got[$n], $total) = ($got, $total + length $got);
            @{ $paths[$n] } = ();         # this font is here: its other paths are not tried
        }
    }
    close $request;
    return (join(' ', '=webfonts', map { length } @got) . "\n" . join('', @got), scalar grep { length } @got);
}

sub pixels {                            # what a picture run wrote: [wide, high, each row in base64], or nothing when it is not exactly a picture
    my ($wrote) = @_;
    return unless $wrote =~ s/\n\z//;
    my ($head, @rows) = split /\n/, $wrote, -1;
    my ($w, $h) = ($head // '') =~ /^P$N,$N$/ or return;
    return unless $w >= 1 && $h >= 1 && $w <= $DECODED_SIDE && $h <= $DECODED_SIDE && $w * $h <= $PICTURE_PIXELS && @rows == $h;
    return if grep { !/^p[0-9a-f]+$/ || length != 8 * $w + 1 } @rows;
    return [$w, $h, map { encode_base64(pack('H*', substr($_, 1)), '') } @rows];
}

# The application did not give a page. What is said is one of the fixed
# phrases below. And when the application's maker named an address for
# reports, you are asked whether to send one, shown the whole address first:
# one of two words, the release, the build of macOS. Not the address you
# typed, and nothing of the page. It is sent the way a typed address is, and
# written in the log the same way. The question also says what no request can
# hide: the server that receives it sees your internet address and the time.
# Two words and not the seven phrases, because five of the seven are the
# application's own doing: it could fail in one of five ways on purpose, and
# a report that named the way would carry what the application chose. So a
# report says "page" for all five, and "container" for the two that lzrprf
# and the system decide. Ending at once, before the system was asked about
# it, is one of the five: a process that is gone is "ended", never
# "uncontained", so the application cannot choose the word by how fast it
# ends. One thing stays the application's choice and cannot
# be taken from it: whether it fails on a page at all. A report you send
# therefore tells its maker that some page failed on your computer at that
# moment, and not which.
my %FAULT = (
    unstarted => 'its container could not be started',
    uncontained => 'the system did not say that it was in its container, so the answer was not handed to it',
    ended => 'it ended before it was given the page',
    late => 'it did not finish in time',
    large => 'it wrote more than lzrprf takes',
    unfit => 'what it wrote is not a page',
    flagged => 'LZRDFNDR blocked it as harmful or prohibited content',
    undrawn => 'the window could not draw what it wrote',
    changed => 'its program on the disk is another file than when this window opened, as after an update, so it was not started. Quit, and start it again',
);

sub fault {
    my ($which) = @_;
    my $says = "$APP did not show this page: $FAULT{$which}.";
    return idle($says) if $which eq 'changed';    # nothing of the application ran: there is nothing to report
    my ($release, undef, $to) = beside();
    my ($build) = mark() =~ /^macOS build (\w+)/;
    my $word = $which =~ /^un(?:started|contained)$/ ? 'container' : 'page';
    my ($url, $host) = $to && $build ? address("$to?fault=$word&release=$release&macos=$build") : ();
    return idle($says) unless $url;
    return idle($says) unless ask("$says Send a report to its developer? It holds one of two words, the number of the release and this Mac's build of macOS, and nothing else. The server that receives it sees your internet address and the time, as every site does. This is all of it, and it is written in the log: $url", "Don't send", 'Send') == 2;    # [C4]
    idle("$says " . (fixed("you sent a report: $url", $url, $host) ? 'The report was sent.' : $UNSAID ? 'lzrprf tried to send the report. Whether it arrived is not shown: the line that says how it ended could not be written to the log.' : 'The report could not be sent.'));
}

sub fault_said { return $FAULT{$_[0]} // "it failed ($_[0])" }    # the plain words for why a run of the application is not shown, as a log line says them
sub asked_words { my ($n) = @_; return $n ? "asked for $n " . ($n == 1 ? 'address' : 'addresses') . ', fetched or refused' : 'asked for no address' }    # [C19] what a run asked for while it was read, in words (sub contained)


# Where a host is. The name is looked up outside every container, after the
# address is in the log, by the system's perl running the few lines of
# $LOOKUP (the same as sub lookup, without the rest of this file to read
# first), given ten seconds. Not by a fork of this process: the system's
# libraries refuse a lookup in a copy that was not started afresh. The way to
# each address it gave is then asked of the system for all of them at once.
my $LOOKUP = 'use Socket qw(SOCK_STREAM NI_NUMERICHOST NI_NUMERICSERV getaddrinfo getnameinfo); my ($failed, @all) = getaddrinfo($ARGV[0], 443, { socktype => SOCK_STREAM }); print map { (getnameinfo($_->{addr}, NI_NUMERICHOST | NI_NUMERICSERV))[1] . "\n" } $failed ? () : @all;';
# An address written as a number, as the system's own: its family and the
# address to connect to, or nothing for text that is not a number. Never a
# lookup (AI_NUMERICHOST), so it is safe in a copy made by fork too. The same
# call find made before, given one place: this and sub lookup are the only
# places in this file that call getaddrinfo, and a name is looked up only by
# $LOOKUP in a fresh perl or by "lzrprf lookup", as before.
sub numbered {
    my ($failed, $one) = getaddrinfo($_[0], 443, { socktype => SOCK_STREAM, flags => AI_NUMERICHOST });
    return $failed || !$one ? undef : $one;
}

# The lookup of a name begun and not waited for: sub find reads what it says
# when the name is asked for. The same program, the same name and the same
# checks before it as sub find makes; a name that is never asked for after
# all was looked up and nothing more. At most $FINDING_MOST wait at a time.
sub find_ahead {
    my ($host) = @_;
    return if listed($host) || $TOR_SESSION || $TOR_WANTED || $PEER ne '-' || $FINDING{$host} || keys %FINDING >= $FINDING_MOST;    # [C23] [C17] as sub find: never a listed name, never past Tor
    my $cached = $FOUND{$host};
    return if $cached && now() - $cached->[0] < $FOUND_SECONDS;
    timed("find-ahead $$ $host") if $TIMED;
    pipe(my $from, my $to) or return;
    my $pid = fork // return;
    if (!$pid) {                          # a copy that waits for the lookup, in a fresh perl as ever, then asks the system the ways to what it gave, all at once, and writes both: asked by sub find itself after the lookup, the ways took 13 ms in which a page's waiting requests stood still (yle.fi, measured 2026-11-25)
        close $from;
        setpgrp(0, 0);                    # a group of its own, so the lookup it waits for ends with it (sub find_dropped)
        spare_dropped(); curl_ended($CURL_SPARE); undef $CURL_SPARE;
        $RUN = getppid();
        my ($found) = said($FIND_SECONDS, '/usr/bin/perl', '-e', $LOOKUP, $host);
        syswrite $to, $found // '';        # the lookup's answer at once: were the ways never told, sub find has it and asks them itself
        my ($numbers, $families, $told) = find_numbers($found // '');
        my @says = said_all(5, (map { route_asked($_->{family}, $_->{text}) } @$numbers), map { route_asked($_, 'default') } @$families);
        print $to "=ways\n", map { "=way $told->[$_]\n" . ($says[$_] // '') . "\n" } 0 .. $#$told;
        close $to;
        POSIX::_exit(0);
    }
    close $to;
    $FINDING{$host} = [$from, $pid];
    return;
}

sub find_numbers {                        # ($found): of what a lookup printed, the first $LOOKED addresses that are numbers, their families, and the name each way is told under (an address, default4, default6)
    my ($found) = @_;
    my (@numbers, %had, $looked);
    for my $text (grep { /^[0-9A-Fa-f:.]+(?:%[A-Za-z0-9]+)?$/ && !$had{$_}++ } split /\n/, $found) {
        last if ++$looked > $LOOKED;
        my $one = numbered($text) or next;
        push @numbers, { %$one, text => $text };
    }
    my @families = do { my %once; grep { !$once{$_}++ } map { $_->{family} } @numbers };
    return (\@numbers, \@families, [(map { $_->{text} } @numbers), map { $_ == AF_INET6 ? 'default6' : 'default4' } @families], scalar keys %had);
}

sub find_dropped {                        # the lookups begun and never asked for, ended
    for my $one (values %FINDING) { close $one->[0]; kill 'KILL', -$one->[1]; kill 'KILL', $one->[1]; waitpid $one->[1], 0 }    # the copy and, by its group, the lookup it waits for
    %FINDING = ();
    return;
}

# Returns the addresses the name leads to, each with whether it is "own":
# not on the public internet, or reached by a route of its own. At most eight
# are returned: the first eight this computer has a way to. An address it has
# no way to is passed over and is not one of the eight. The first sixteen the
# lookup gave are looked at, and no more.
sub find {
    my ($host) = @_;
    return (undef, $REFUSED_WHY) if listed($host);    # [C23] a listed name is never looked up, here or by a test's listener
    return (undef, 'this is a Tor window: no name is looked up on this Mac, and nothing goes out past Tor') if $TOR_SESSION;    # [C17]
    if ($PEER ne '-') {                   # "lzrprf try" only: every name leads to the test's listener
        timed('looked-up');               # the same diagnostic mark as a real lookup, so the selftest can prove one never began
        my ($to, $port) = split /:/, $PEER;
        my ($public, $names) = (0);
        $public = grep { chomp; $_ eq $host } <$names> if open $names, '<', "$ROOT/public";    # the names the test's file "public" lists are taken for hosts on the public internet, to try what is fetched there
        return [{ family => AF_INET, addr => pack_sockaddr_in($port, inet_aton($to)), text => $to, own => !$public && !public($to) }];
    }
    my $cached = $FOUND{$host};
    return [map { {%$_} } @{ $cached->[1] }] if $cached && now() - $cached->[0] < $FOUND_SECONDS;    # looked up a moment ago in this window: the same addresses, and the same ways to them, without the five processes a lookup starts
    timed("find-begin $$ $host") if $TIMED;    # "lzrprf try" with "times": each name looked up, and when its addresses and their ways were known (scripts/load-timeline.pl)
    my $begun = delete $FINDING{$host};    # the same lookup, begun while the page's answer was read (sub find_ahead): only what is left of it is waited for
    my ($found) = $begun ? @{ (said_read($FIND_SECONDS, $begun))[0] } : said($FIND_SECONDS, '/usr/bin/perl', '-e', $LOOKUP, $host);
    timed('looked-up');
    timed("find-looked $$ $host") if $TIMED;
    my %way;                              # what a lookup begun ahead was told of the ways (sub find_ahead)
    if ($begun && defined $found && $found =~ s/^=ways\n(.*)\z//ms) { my @told = split /^=way (\S{1,64})\n/m, $1; shift @told; %way = @told if @told % 2 == 0 }
    my @where;
    my ($numbers, $families, $told, $had) = find_numbers($found // '');
    my @numbers = @$numbers; my @families = @$families;
    my @says = %way && !(grep { !defined $way{$_} } @$told) ? @way{@$told} : said_all(5, (map { route_asked($_->{family}, $_->{text}) } @numbers), map { route_asked($_, 'default') } @families);    # the way to each address and the default way: told by the lookup begun ahead, or asked of the system all at once
    my %usual = map { $families[$_] => $says[@numbers + $_] } 0 .. $#families;
    for my $at (0 .. $#numbers) {
        last if @where >= $FOUND;
        my $one = $numbers[$at];
        my $route = route_of($one->{family}, $one->{text}, $says[$at], $usual{ $one->{family} }) or next;    # this computer has no way there at all
        push @where, { %$one, text => $one->{text}, own => $route eq 'own' || !public($one->{text}) };
    }
    timed("find-end $$ $host " . scalar @where) if $TIMED;
    return (undef, $had ? 'this computer has no way to that host' : 'no such host') unless @where;
    %FOUND = () if keys %FOUND >= 256;
    $FOUND{$host} = [now(), [map { {%$_} } @where]];    # only an answer with addresses is kept: a failure is looked up again
    return \@where;
}

# How this computer would send to an address: "internet" by the way it uses
# for the internet at large, "own" by a route of its own (a network this
# computer is in, another computer's network behind a VPN, this computer
# itself), nothing when there is no way. The address being in a public range
# does not make it public for you: a route can lead it into a network of
# your own, and then you are asked.
sub route_asked { my ($family, $text) = @_; return ['/sbin/route', '-n', 'get', ($family == AF_INET6 ? '-inet6' : ()), $text =~ s/%.*//r] }    # the question to the system about the way to one address
sub route {
    my ($family, $text) = @_;
    my ($says) = said(5, @{ route_asked($family, $text) });
    return route_of($family, $text, $says);
}
sub route_of {                            # the answer, from what the system said of the way to the address and, when it was asked already, of the default way
    my ($family, $text, $says, $usual) = @_;
    my ($to) = $says =~ /^\s*destination: (\S+)/m or return;
    return 'internet' if $to eq 'default' || $says =~ /^\s*mask: default\s*$/m;    # the default route: a mask of no bits at all. For IPv6 the system writes its destination as "::" and not as "default", and only the mask says so
    if ($says =~ /^\s*flags: <[^>]*\bWASCLONED\b/m && $text ne 'default') {
        # macOS keeps a route of its own for every address it spoke to a moment ago, a copy of the route
        # that led there. It is the internet's when it leaves by the same door as the default route.
        ($usual) = said(5, @{ route_asked($family, 'default') }) unless defined $usual;
        my @door = map { my $all = $_; join ' ', map { $all =~ /^\s*$_: (\S+)/m ? $1 : '?' } 'gateway', 'interface' } $says, $usual // '';
        return 'internet' if $door[0] eq $door[1] && $door[0] !~ /\?/ && ($usual // '') =~ /^\s*(?:destination|mask): default\s*$/m;    # the mask again: over IPv6 the default route's destination reads "::"
    }
    my ($mask) = $says =~ /^\s*mask: (\S+)/m or return 'own';
    my $bits = inet_pton($family, $mask) // return 'own';
    return unpack('%32b*', $bits) < 8 ? 'internet' : 'own';    # a route for half of all addresses is how some VPNs carry the whole internet
}

# The one connection to the site, made by lzrprf: to an address that was just
# checked and written down, never to the name again. This is the only place
# in this file that connects to anything outside this computer.          # [C6]
sub reach {
    my ($where, $until) = @_;
    return tor_reach($where->[0]{host}, $until) if $where->[0]{tor};    # [C17] through Tor, and never past it: a Tor that does not answer is a request that fails
    return if $TOR_SESSION;               # [C17] a Tor window connects to nothing but Tor
    for my $one (@$where) {
        my $left = $until - now();
        last if $left <= 0;
        socket(my $site, $one->{family}, SOCK_STREAM, 0) or next;
        unblocked($site);
        connect($site, $one->{addr});     # [C6]
        my $ready = '';
        vec($ready, fileno $site, 1) = 1;
        return ($site, $one->{text}) if select(undef, $ready, undef, $left < 10 ? $left : 10) > 0 && !unpack 'i', getsockopt($site, SOL_SOCKET, SO_ERROR);
    }
    return;
}

