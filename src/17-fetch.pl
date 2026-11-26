# What a site is sent, inside the encryption, for an address: these bytes,
# made from the address and from nothing else but one fixed browser name,
# LZRBRWSR: no version, no other word, the same from every computer and every
# release (some sites answer a request with no browser name only with a
# redirect, so it names one). The request of a page you visit says too which
# answers it takes, in one fixed line (some sites refuse a request that does
# not); a picture, a style sheet, the release file and what a page kept
# running asks for do not carry it. No cookie, no language, no page you came from,
# no number of this computer or of this copy. Every computer that runs lzrprf
# sends the same bytes for the same address, so they tell a site nothing
# about which one you are. curl is
# told to send exactly this (the switches in "fetch"), and selftest compares
# these bytes with the bytes its test site really received.              # [C7]
my $BROWSER = 'LZRBRWSR';                # DECLARED: the one browser name every request carries, the owner's order of 2026-11-20; a fixed word, never a version or anything of this computer
my $PAGE_ACCEPT = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';    # DECLARED: the kinds of answer the request of a page you visit takes, the owner's order of 2026-11-21; one fixed line, the same on every computer
sub request {
    my ($url, $page) = @_;                # $page: the request of a page you visit (sub visit), the one that says which answers it takes
    my ($host, $rest) = $url =~ m{^https://([^/]+)(/.*)$} or return '';
    return "GET $rest HTTP/1.1\r\nHost: $host\r\nUser-Agent: $BROWSER\r\n" . ($page ? "Accept: $PAGE_ACCEPT\r\n" : '') . "Accept-Encoding: identity\r\nConnection: close\r\n\r\n";
}

# The one exception to those bytes: a compatibility identity (managed-projects/lzrbrwsr/SYSTEM.md
# D19). Where a site refuses the honest name and that blocks what you asked for, the application,
# the closed part, may tell lzrprf to send a request as a mainstream browser sends it. Which
# sites, and why, is the application's table, never lzrprf's: lzrprf holds only the fixed header
# sets below, one per word, so what the application can choose is one of these byte sets and
# nothing else, and it is told the word for each request. A page asks with "as WORD" on its
# =fetch line; for the requests lzrprf makes itself (the page you visit, its redirects, style
# sheets and pictures) the application names its families once a window, before the first visit,
# as "identity WORD HOST" lines to the question "=identity" (sub identity_asked), held in this
# process's memory only; asked the first moment the window is quiet, before you type (release 83),
# and at the first visit when no such moment came: a tool run with no network and no address, so its
# answer is the same whenever it is asked. Through Tor no identity is ever applied: Tor keeps one uniform identity.
# What curl lets lzrprf choose: User-Agent, Accept, Accept-Language and Sec-Fetch-* in Safari's
# order, after Host, and no Sec-CH-UA client hints, which Safari does not send. What it does not:
# Accept-Encoding stays identity (lzrprf decodes no gzip or br), the connection HTTP/1.1 and
# closed, and the TLS hello curl's own (SecureTransport), not Safari's.                    # [C7]
my %IDENTITIES = (                        # DECLARED: the owner's order of 2026-11-22; Safari 27.2 on macOS, the platform lzrprf runs on
    safari => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2 Safari/605.1.15',
);
my $IDENTITY_LANGUAGE = 'en-US,en;q=0.9';    # DECLARED: the language line Safari sends for en-US, the application's one locale
my %IDENTITY_ACCEPT = (document => $PAGE_ACCEPT, iframe => $PAGE_ACCEPT, style => 'text/css,*/*;q=0.1', image => 'image/webp,image/avif,image/jxl,image/heic,image/heic-sequence,video/*;q=0.8,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5');    # DECLARED: Safari's Accept by what is asked for; anything else */*
my %IDENTITY_OF;                          # host => word, as the application named them for this window (sub identity_asked)
my $IDENTITY_ASKED = 0;
my $IDENTITY_HOSTS = 64;                  # DECLARED: the most hosts the application may name for this window
sub identity_on { !$TOR_WANTED && !$TOR }    # [C17] never through Tor
sub identity_word { exists $IDENTITIES{$_[0]} }    # a word lzrprf holds a header set for
sub identity_asked {                      # once a window, while it is idle or else before its first visit, and never through Tor: a tool run of the application, in the page container, is asked "=identity"; lines of no form are passed over
    undef $IDLE_WORK if defined $IDLE_WORK && $IDLE_WORK == \&identity_asked;    # asked now, before a first visit: a quiet moment later has the next work to do (sub idle_taken)
    return if !identity_on() || $IDENTITY_ASKED++;
    my ($wrote) = contained('identity', "=identity\n", undef, 0, 1);    # [C1] [C3] as a tool run: no network, no file
    for my $line (split /\n/, $wrote // '') {
        last if keys %IDENTITY_OF >= $IDENTITY_HOSTS;
        $IDENTITY_OF{$2} = $1 if $line =~ /\Aidentity ([a-z]{1,16}) ([a-z0-9](?:[a-z0-9-]{0,62})(?:\.[a-z0-9](?:[a-z0-9-]{0,62})){1,8})\z/ && exists $IDENTITIES{$1};
    }
    noted('The application named ' . keys(%IDENTITY_OF) . ' hosts shown another browser identity in this window') if %IDENTITY_OF;
    return;
}
sub identity_of_host {                    # the word for a request lzrprf makes for a page on this host, or nothing
    my ($host) = @_;
    return unless defined $host && identity_on();
    for my $family (sort keys %IDENTITY_OF) { return $IDENTITY_OF{$family} if $host eq $family || substr($host, -length(".$family")) eq ".$family" }
    return;
}
sub identity_site {                       # Sec-Fetch-Site of a request to $to from a page on $from
    my ($from, $to) = @_;
    return 'none' unless defined $from;
    return 'same-origin' if $from eq $to;
    for my $family (keys %IDENTITY_OF) {
        return 'same-site' if ($from eq $family || substr($from, -length(".$family")) eq ".$family") && ($to eq $family || substr($to, -length(".$family")) eq ".$family");
    }
    return 'cross-site';    # no last-two-label guess: unrelated co.uk sites are not the same site
}
my %IDENTITY_FOR = (document => ['document', 'navigate'], frame => ['iframe', 'navigate'], data => ['empty', 'cors'], script => ['script', 'no-cors'], module => ['script', 'cors'], worker => ['worker', 'same-origin'], style => ['style', 'no-cors'], font => ['font', 'cors'], image => ['image', 'no-cors']);    # what is asked for => Sec-Fetch-Dest and Sec-Fetch-Mode, as Safari sends them
sub identity_headers {                    # curl's -H switches for a request sent as identity $word: Safari's headers in Safari's order
    my ($word, $url, $for, $from) = @_;   # $for: a key of %IDENTITY_FOR; $from: the host of the page asking, or nothing for a page you visit
    my ($to) = $url =~ m{^https?://([^/:]+)};
    my ($dest, $mode) = @{ $IDENTITY_FOR{$for} // $IDENTITY_FOR{data} };
    return ('-H', "Sec-Fetch-Dest: $dest", '-H', "User-Agent: $IDENTITIES{$word}", '-H', 'Accept: ' . ($IDENTITY_ACCEPT{$dest} // '*/*'), '-H', 'Sec-Fetch-Site: ' . identity_site($from, $to // ''), '-H', "Sec-Fetch-Mode: $mode",
        '-H', "Accept-Language: $IDENTITY_LANGUAGE", '-H', 'Accept-Encoding: identity', '-H', 'Connection: close');
}

# The request. curl does the https, and it is told the address and nothing
# else: the bytes above. It has no network. It gets one socket file; when it
# comes there, and the system says that it is contained, lzrprf connects to
# the site and carries the bytes both ways, which are encrypted between curl
# and the site. curl is held to https, follows no redirect, tries once, takes
# no setting from a file or a variable, and the certificate must prove the
# host to the system's list of authorities. It keeps nothing for a later
# request, because it can write nothing: each request is a new curl with an
# empty memory, so no cookie, no stored answer and no earlier connection
# comes back to a site.                                                  # [C7]
# One clock runs for the whole request, looked at once a round, and a round
# waits at most a second. No more is carried either way than one request and
# one answer need: a side that sent more than its allowance has nothing more
# passed on, and the request fails. Returns the answer, or why there is
# none, and the address that answered.
# A request of a page kept running ($ask, [C19]) is the same request with at
# most three things more, each made by lzrprf from what it checked: HEAD in
# place of GET, or POST with the page's body (handed to curl on its input) and
# its type of three; and for another host than the page's, the page's Origin.
sub fetch {
    my ($url, $where, $ask, $page, $most, $stop, $for, $fixed) = @_;    # $page: the request of a page you visit, which carries the line Accept (sub request); $most: [bytes, seconds] in place of $FETCH_BYTES and $FETCH_SECONDS, and $stop: true when you stopped it, for a video (sub videoed); $for: [style, font or image, the page's host] for what lzrprf fetches for a page
    my $as = $ask ? (defined $ask->{as} && identity_on() ? $ask->{as} : undef) : identity_of_host($for || $page ? (address($url))[1] : undef);    # [C7] the one exception, D19: a page's request as its =fetch line said; lzrprf's own for a page as the application named the page's host (sub identity_asked); never through Tor
    my @sent = defined $as && exists $IDENTITIES{$as} ? identity_headers($as, $url, $ask ? $ask->{dest} || 'data' : $for ? $for->[0] : 'document', $ask ? $ask->{from} : $for ? $for->[1] : undef)
        : ('-H', "User-Agent: $BROWSER", '-H', $page ? "Accept: $PAGE_ACCEPT" : 'Accept:', '-H', 'Accept-Encoding: identity', '-H', 'Connection: close');
    return (undef, $REFUSED_WHY) if listed($url);    # [C23] no curl is started for a listed address, whatever asked for it
    if (!$fixed) { my $shield = shield_said($url); return (undef, shield_why($shield)) if $shield ne 'allow' }    # [C28] nor for one LZRDFNDR blocks or did not judge, whatever asked for it; $fixed: one of the release file's own addresses (sub fixed)
    my ($bytes, $seconds) = $most ? @$most : ($FETCH_BYTES, $FETCH_SECONDS);
    my $wire = $bytes + $WIRE_BYTES - $FETCH_BYTES;    # what encryption adds, on top of the answer
    my ($way, $roots) = ("$DIR/way.$$", $PEER ne '-' ? "$ROOT/authority.pem" : $ROOTS);
    my $none = 'the request could not be made';
    my $sends = $ask && ($ask->{method} eq 'POST' || $ask->{kept_app} && $ask->{method} =~ /\A(?:PATCH|PUT|DELETE)\z/);
    my $up = $sends ? $ask->{body} : $ask && defined $ask->{key} ? "Authorization: Bearer $ask->{key}\n" : undef;    # [C19] the body a page's POST carries, all that is carried besides the request; or the key that reads the answer to a support request, as a line curl adds to its request, so that no list of processes shows it (sub support_read)
    my @asked = !$ask ? () : ($ask->{method} eq 'HEAD' ? ('--head') : (), defined $ask->{key} ? ('-H', '@-') : (), $sends ? ('--data-binary', '@-', '-H', 'Content-Type:' . ($ask->{type} eq '-' ? '' : " $ask->{type}"), '-H', 'Expect:') : (), defined $ask->{origin} ? ('-H', "Origin: $ask->{origin}") : ());    # [C19]
    push @asked, '--request', $ask->{method} if $sends && $ask->{method} ne 'POST';
    my $cookie = $page && !($ask && $ask->{kept_app}) ? sso_cookie($url) : $ask ? $ask->{cookie} : undef;    # [C7] the cookies of a provider you connected in this profile, to that provider's own hosts only (sub sso_cookie), carried on curl's input and never on its command line
    my $jarred = ($page || $ask && defined $ask->{top}) && !defined $cookie && !jar_skips($url);    # [C7] or else the jar's, for a page you visit or a page kept running outside the sandbox (sub jar_cookie)
    my $ahead = $ask && exists $ask->{jar};    # a request made ahead: the window asked the jar before this run began, and tells it of the answer when the page takes it (sub prefetch_pump)
    $cookie = $ahead ? (length $ask->{jar} ? $ask->{jar} : undef) : jar_cookie($url, $page, $ask) if $jarred;
    if (defined $cookie && !defined $up) { $up = "$cookie\n"; push @asked, '-H', '@-' }
    elsif (defined $cookie && $sends && $up !~ /\x00/) {    # a POST's body and its cookies, both on curl's input as its settings: a quoted text, with \\ \" \t \n \r \v written as curl reads them
        my $quoted = sub { my ($text) = @_; $text =~ s/([\\"])/\\$1/g; $text =~ s/\t/\\t/g; $text =~ s/\n/\\n/g; $text =~ s/\r/\\r/g; $text =~ s/\x0b/\\v/g; return qq("$text") };
        $up = 'header = ' . $quoted->($cookie) . "\ndata-raw = " . $quoted->($up) . "\n";
        my ($at) = grep { $asked[$_] eq '--data-binary' } 0 .. $#asked;
        @asked[$at, $at + 1] = ('-K', '-');    # in place of --data-binary @-: -K - reads both
    }
    my $set = !defined $up && !@asked && !grep({ /[\x00-\x1f\x7f]/ } $url, @sent) && !grep({ $sent[$_] ne '-H' } grep { !($_ % 2) } 0 .. $#sent) ? curl_taken() : undef;    # curl started before this request, for one that is the address and its headers alone (sub curl_for)
    $way = $set->{way} if $set;
    unlink $way;
    my $listen; socket($listen, AF_UNIX, SOCK_STREAM, 0) && bind($listen, pack_sockaddr_un($way)) && listen($listen, 1) or do { curl_ended($set); return (undef, $none) };
    my ($curl, $from_curl, $body_in, $to_curl);
    timed("fetch-begin $$ $url") if $TIMED;    # "lzrprf try" with "times": each request by the process that makes it, so requests side by side are told apart (scripts/load-timeline.pl)
    if ($set) {                           # what it would be told on its command line, written as its settings on its input and closed: only then does it go to the socket
        my $quoted = sub { my ($text) = @_; $text =~ s/([\\"])/\\$1/g; return qq("$text") };    # no character below a space is in either, so these two are all a quoted text holds
        my $told = "max-time = $seconds\nmax-filesize = $bytes\n" . join('', map { 'header = ' . $quoted->($sent[$_]) . "\n" } grep { $_ % 2 } 0 .. $#sent) . 'url = ' . $quoted->($url) . "\n";
        ($curl, $from_curl) = @$set{qw(curl from)};
        my $put = 0;
        while ($put < length $told) { my $n = syswrite($set->{to}, $told, length($told) - $put, $put) or last; $put += $n }
        close $set->{to};
        if ($put < length $told) { curl_ended({ %$set, to => undef }); return (undef, $none) }
    }
    else {
        if (defined $up) { pipe($body_in, $to_curl) or return (undef, $none) }
        ($curl, $from_curl) = curl_started($body_in, $way, '--max-time', $seconds, '--max-filesize', $bytes, '--write-out', ($TIMED ? $TIMING_OUT : '') . "$WROTE%{certs}", @sent, @asked, '--unix-socket', $way, '--', $url) or return (undef, $none);
    }
    if (defined $up) {                    # [C19] the body goes to curl as it reads it, never waited for in a write
        close $body_in;
        fcntl($to_curl, POSIX::F_SETFL(), O_NONBLOCK);
        if (!length $up) { close $to_curl; undef $to_curl }
    }
    my ($got, $until, $unreached, $loose, $done, $peer, @links) = ('', now() + $seconds, 0, 0, 0);    # a link: from, to, bytes held, 1 while "from" is open, bytes carried
    my $stopped = 0;
    while (now() < $until && length $got <= $bytes + $WROTE_ROOM && alive() && !grep { $_->[4] > $_->[5] } @links) {    # what curl writes after the answer is read too, and cut off below before the answer's length is judged
        if ($stop && $stop->(\$got)) { $stopped = 1; last }    # it is shown what came so far (sub videoed: a playlist by its type is read no further than a playlist)
        my ($read, $write) = ('', '');
        vec($read, fileno $from_curl, 1) = 1;
        vec($read, fileno $listen, 1) = 1 unless @links;
        vec($write, fileno $to_curl, 1) = 1 if $to_curl;
        for (@links) {
            vec($read, fileno $_->[0], 1) = 1 if $_->[3] == 1 && length $_->[2] < 262144;
            vec($write, fileno $_->[1], 1) = 1 if length $_->[2];
        }
        select($read, $write, undef, 1) > 0 or next;
        if (!@links && vec($read, fileno $listen, 1)) {
            accept(my $in, $listen) or last;
            timed('curl-came');
            if (!inside($curl)) { $loose = 1; last }    # [C3] the system did not say that curl is contained: no connection is made for it
            timed('curl-inside');
            (my $site, $peer) = reach($where, $until);
            if (!$site) { $unreached = 1; last }
            timed('connected');
            timed("fetch-connected $$ $peer") if $TIMED;
            unblocked($in);
            @links = ([$in, $site, '', 1, 0, $SENT_BYTES + length($up // '')], [$site, $in, '', 1, 0, $wire]);    # [C19] a page's POST may carry its body more
            next;
        }
        for my $link (@links) {
            my ($from, $to) = @$link;
            if ($link->[3] == 1 && vec($read, fileno $from, 1)) {
                my $n = sysread($from, $link->[2], 65536, length $link->[2]);
                $link->[3] = 0 if defined $n ? !$n : !$!{EAGAIN};
                $link->[4] += $n // 0;
            }
            if (length $link->[2] && $link->[4] <= $link->[5] && vec($write, fileno $to, 1)) {    # nothing more is passed on once more came than the allowance: so no more than the allowance ever is
                my $sent = syswrite($to, $link->[2]);
                substr($link->[2], 0, $sent, '') if $sent;
                @$link[2, 3] = ('', 0) unless defined $sent || $!{EAGAIN};
            }
            if (!$link->[3] && !length $link->[2]) {    # one side has ended and all it sent is passed on
                shutdown($to, 1);
                $link->[3] = 2;
            }
        }
        if ($to_curl && vec($write, fileno $to_curl, 1)) {
            my $sent = syswrite($to_curl, $up);
            substr($up, 0, $sent, '') if $sent;
            if (!length $up || !defined $sent && !$!{EAGAIN}) { close $to_curl; undef $to_curl }
        }
        if (vec($read, fileno $from_curl, 1)) { timed("fetch-first-byte $$") if $TIMED && !length $got; sysread($from_curl, $got, 65536, length $got) or ($done = 1, last) }    # "lzrprf try" with "times": curl hands on the answer's head the moment it came
    }
    close $to_curl if $to_curl;
    my $late = now() >= $until;
    my $capped = !$done && length $got > $bytes + $WROTE_ROOM;    # the reading stopped on the length, not at curl's end: whatever the answer holds, a line like curl's among it too, it is not taken
    my $at = rindex $got, $WROTE;            # curl writes the certificates after the whole answer, so the last such line is curl's own, whatever the answer holds
    my $certs = $at >= 0 ? substr($got, $at + length $WROTE) : '';
    substr($got, $at) = '' if $at >= 0;
    if ($TIMED) { my $clocks = $got =~ s/\n\Q$TIMING_MARK\E ([0-9.]+ [0-9.]+ [0-9.]+ [0-9]+ [0-9]+)\z// ? $1 : '-'; timed("fetch-end $$ " . length($got) . " $clocks") }    # "lzrprf try" with "times": the answer's length, and curl's own clocks (TLS done, first byte, all, status, how many connections it opened), taken off the answer again
    unlink $way;
    my $how = ended($curl, $done ? 2 : 0);    # curl is gone, whatever it was doing, before anything is said about the answer
    my $exit = $how >> 8;
    return (undef, 'the system did not say that curl was in its container') if $loose;
    return (undef, 'you stopped it') if $stopped;
    return (undef, 'the answer is larger than lzrprf takes') if $capped || length $got > $bytes || $exit == 63 || @links && $links[1][4] > $wire;
    return (undef, $none) if @links && $links[0][4] > $links[0][5];
    return (undef, 'could not connect') if $unreached;
    return (undef, 'the site did not answer in time') if $late || $exit == 28;
    jar_heard($url, $page, $ask, $got) if $jarred && !$ahead && $done && $how == 0 && length $got && defined $peer;    # [C7] the Set-Cookie lines of an answer that will be taken, to the jar (sub jar_heard)
    return ($got, undef, $peer, $certs) if $done && $how == 0 && length $got && defined $peer;    # an answer is taken only when curl's output was read to its end
    return (undef, 'the certificate does not prove the host') if grep { $exit == $_ } 51, 53, 54, 58, 59, 60, 66, 77, 80, 82, 83, 90, 91;
    return (undef, 'no secure connection could be made') if $exit == 35;
    return (undef, $none);
}

# curl's process for one request: the fixed switches, then what this request adds. It is started
# in its container with its limits and no variable, as sub fetch has always started it.
sub curl_started {
    my ($in, $way, @told) = @_;
    my $roots = $PEER ne '-' ? "$ROOT/authority.pem" : $ROOTS;
    pipe(my $from_curl, my $out) or return;
    my $curl = fork // return;
    if (!$curl) {
        %ENV = ();                        # curl takes no setting from the environment
        my @curl = ($CURL, '-q', '-g', '-s', '-i', '--raw', '--path-as-is', '--proto', '=https', '--tlsv1.2', '--http1.1', '--noproxy', '*', '--no-sessionid', '--ciphers', $TLS_CIPHERS, '--curves', $TLS_CURVES,
            '--cacert', $roots, @told);
        if ($PEER ne '-' && open my $instead, '<', "$ROOT/fetcher") { chomp(@curl = <$instead>) }    # "lzrprf try" only: the test's own program in curl's place, to probe this container too
        become($in, $out, undef, $FETCH_LIMITS, contain($FETCH, shift @curl, '-D', "WAY=$way", '-D', "ROOTS=$roots"), @curl);    # the memory limit first, then the container
    }
    close $out;
    return ($curl, $from_curl);
}

# curl started before its request: the 10 to 15 ms it takes to start in its container are spent
# while the address is judged and looked up, or while the window is quiet, and not on the way to
# the page (measured 2026-11-24). It is the same curl with the same fixed switches and container,
# and the address, its headers and the two limits of the request are written as its settings on
# its input ("-K -") and not on its command line; it reads nothing else, knows no address until
# then, and goes to its socket file only after its input is closed. Of the requests it takes only
# one that is the address and its headers alone: one with a body, a key or cookies on curl's
# input starts its own. At most one waits, made by this process and taken by it alone (a picture's
# copy of lzrprf closes its ends); its socket file is its own and is removed with it. Whether the
# system says it is contained is asked when it comes to its socket, as for every curl [C3].
sub curl_for {                            # one curl started to wait for the next request, unless one waits; ($own): in a copy of lzrprf made to fetch one address (sub fetchers_for)
    return if $CURL_SPARE && $CURL_SPARE->{of} == $$;
    curl_ended($CURL_SPARE);
    undef $CURL_SPARE;
    return unless ($_[0] || $$ == $FRESH) && !($PEER ne '-' && -e "$ROOT/fetcher");    # the test's own program in curl's place is started as it always was
    my $way = "$DIR/way.$$";             # the same name as every other request's: a socket name must stay under 104 bytes, and one profile's folder in a deep temporary folder already comes close
    pipe(my $in, my $to) or return;
    my ($curl, $from) = curl_started($in, $way, '--write-out', "$WROTE%{certs}", '--unix-socket', $way, '-K', '-') or return;
    close $in;
    $CURL_SPARE = { curl => $curl, to => $to, from => $from, way => $way, of => $$ };
    return;
}

sub curl_taken {                          # the curl that waits, still waiting; else nothing
    my $one = $CURL_SPARE // return;
    undef $CURL_SPARE;
    return curl_ended($one) if $one->{of} != $$ || -e "$ROOT/fetcher" && $PEER ne '-';
    return $one if waitpid($one->{curl}, POSIX::WNOHANG()) == 0;
    close $_ for @$one{qw(to from)};      # it ended while it waited, told nothing: a curl is started for the request as before
    return;
}

sub curl_ended {                          # a curl started before its request, ended and its ends closed; a copy of lzrprf only closes its own copies of them
    my ($one) = @_;
    $one or return;
    if ($one->{of} == $$) { kill 'KILL', $one->{curl}; waitpid $one->{curl}, 0; unlink $one->{way} }
    close $_ for grep { defined } @$one{qw(to from)};
    return;
}

sub alive { !$RUN || getppid() == $RUN }  # the window is still there; without it nothing is carried on

sub public {
    my ($address) = @_;
    if (my $four = inet_pton(AF_INET, $address)) { return public4(unpack 'N', $four) }
    my $six = inet_pton(AF_INET6, $address) or return 0;
    my @part = unpack 'n8', $six;
    my $inside = ($part[6] << 16) | $part[7];                                    # where an address of the older kind is carried
    return public4($inside) if !grep({ $_ } @part[0 .. 4]) && $part[5] == 0xffff;
    return public4($inside) if $part[0] == 0x64 && $part[1] == 0xff9b && !grep { $_ } @part[2 .. 5];
    return 0 unless ($part[0] & 0xe000) == 0x2000;                               # only the block the public internet uses
    return 0 if $part[0] == 0x2002 || $part[0] == 0x2001 && ($part[1] < 0x200 || $part[1] == 0xdb8) || ($part[0] & 0xfff0) == 0x3ff0;    # tunnels, special uses, examples
    return 1;
}

sub public4 {
    my ($number) = @_;
    for (qw(0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24
            192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/3)) {
        my ($net, $bits) = split m{/};
        return 0 if ($number & (0xffffffff << (32 - $bits) & 0xffffffff)) == unpack 'N', inet_aton($net);
    }
    return 1;
}

# The fixed addresses. Besides what you type, lzrprf fetches five things,
# each only after you asked for it in the window, each written in the log
# first, each sent the way a typed address is: the newest release number
# (below), a report you chose to send (above), after "Install it" the
# installer, from the one or two places the release file names (sub
# installed), a support request you send, and the answer to it when you ask
# to read it (sub support_sent, sub support_read). An address that is not on
# the public internet is not fetched for any.                            # [C4]
sub fixed {
    my ($line, $url, $host, $ask) = @_;   # $ask: a support request sent, or the answer to it read (sub support_sent, sub support_read), the two that are more than a GET of the address alone
    $UNSAID = 0;
    if (listed($url)) { refused('one of the fixed addresses of the release file'); return }    # [C23] never the case for a release made by its maker; held all the same

    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;
    my ($kept) = keeping();
    record($line, $kept) or return;       # [C5]
    my ($where, $why) = $TOR_WANTED ? tor_where($host) : find($host);
    $why = 'that host is not on the public internet' if $where && $PEER eq '-' && grep { $_->{own} } @$where;
    my ($got, $from);
    if (!$why) {
        record("$url -> lzrprf connects " . ($TOR_WANTED ? "through Tor, one circuit for $host" : 'to the first that answers of: ' . join(', ', map { $_->{text} } @$where)), $kept) or return;    # [C5]
        $UNSAID = 1;
        ($got, $why, $from) = fetch($url, $where, $ask, undef, undef, undef, undef, 1);
    }
    record("$url " . ($why ? "failed: $why" : 'answered: ' . length($got) . " bytes from $from"), $kept) or return;    # nothing of the answer is written, and "sub fault" says the report was tried
    $UNSAID = 0;
    return $why ? undef : $got;
}

