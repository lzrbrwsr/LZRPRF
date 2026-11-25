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
    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;    # as in visit: no line of these requests falls into a clearing of the log
    my ($until, @got) = (now() + $SHEET_SECONDS);
    for my $n (0 .. $#$named) {
        if (now() >= $until || !alive()) { push @got, ''; next }    # not begun in time: nothing is fetched for it
        my $url = "https://$host$named->[$n]";
        if (listed($url)) { refused("a style sheet the page $host names", $kept) or return; push @got, ''; next }    # [C23] handed over with length 0
        if (my $filter = filter_said($url, 'stylesheet', $host)) { record("$url not fetched: $filter", $kept) or return; push @got, ''; next }    # [C27] after [C23]: handed over with length 0
        record("$url -> lzrprf connects to the first that answers of: " . join(', ', map { $_->{text} } @$where), $kept) or return;    # [C5] written down first, connected second
        busy('Fetching style sheet ' . ($n + 1) . " of the page: $url");
        my ($got, $why, $from) = fetch($url, $where, undef, undef, undef, undef, ['style', $host]);    # [C6] [C7]
        record("$url " . ($why ? "failed: $why" : 'answered: ' . length($got) . " bytes from $from"), $kept) or return;
        push @got, !$why && length $got <= $SHEET_BYTES ? $got : '';
    }
    close $request;
    return (join(' ', '=sheets', map { length } @got) . "\n" . join('', @got), scalar grep { length } @got);
}

sub pixels {                              # what a picture run wrote: [wide, high, each row in base64], or nothing when it is not exactly a picture
    my ($wrote) = @_;
    return unless $wrote =~ s/\n\z//;
    my ($head, @rows) = split /\n/, $wrote, -1;
    my ($w, $h) = ($head // '') =~ /^P$N,$N$/ or return;
    return unless $w >= 1 && $h >= 1 && $w <= 1024 && $h <= 1024 && $w * $h <= $PICTURE_PIXELS && @rows == $h;
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
    my ($found) = said($FIND_SECONDS, '/usr/bin/perl', '-e', $LOOKUP, $host);
    timed('looked-up');
    my (@where, %had, @numbers, $looked);
    for my $text (grep { /^[0-9A-Fa-f:.]+(?:%[A-Za-z0-9]+)?$/ && !$had{$_}++ } split /\n/, $found) {
        last if ++$looked > $LOOKED;
        my $one = numbered($text) or next;
        push @numbers, { %$one, text => $text };
    }
    my @families = do { my %once; grep { !$once{$_}++ } map { $_->{family} } @numbers };
    my @says = said_all(5, (map { route_asked($_->{family}, $_->{text}) } @numbers), map { route_asked($_, 'default') } @families);    # the way to each address and the default way, asked of the system all at once
    my %usual = map { $families[$_] => $says[@numbers + $_] } 0 .. $#families;
    for my $at (0 .. $#numbers) {
        last if @where >= $FOUND;
        my $one = $numbers[$at];
        my $route = route_of($one->{family}, $one->{text}, $says[$at], $usual{ $one->{family} }) or next;    # this computer has no way there at all
        push @where, { %$one, text => $one->{text}, own => $route eq 'own' || !public($one->{text}) };
    }
    return (undef, %had ? 'this computer has no way to that host' : 'no such host') unless @where;
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
        $site->blocking(0);
        connect($site, $one->{addr});     # [C6]
        my $ready = '';
        vec($ready, fileno $site, 1) = 1;
        return ($site, $one->{text}) if select(undef, $ready, undef, $left < 10 ? $left : 10) > 0 && !unpack 'i', getsockopt($site, SOL_SOCKET, SO_ERROR);
    }
    return;
}

