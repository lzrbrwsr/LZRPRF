# The pictures of a laid page. A page may name up to $PICTURES of them, each
# a path on its own host or a full address https://HOST/PATH on another host
# by its name. A name under the page's host (sub under) is the site you visit;
# any other host is another site, as a news site's image server is (sub
# elsewhere), and at most $PICTURE_SITES other sites are asked for one page's
# pictures, the first the page names: a picture on one more is not fetched,
# and the log says so. An address on another site is fetched only when it
# stands, as //HOST/PATH, in the text of the page as it was fetched (&amp; read
# as &, the host in any case): the application, which may be hostile, cannot
# make lzrprf ask another site for an address the page never named. That a
# picture of two dots or less is not named, and that the page's img-src policy
# is kept, are the application's checks: lzrprf keeps the eight sites, the
# address in the page, and everything below, and "Block pictures from other
# sites" in the cogwheel's menu (sub pictures_elsewhere) stops every one.
# What another site learns from a picture is your address and the picture's
# address, which names the page's picture and so tells it which page you read,
# at the moment you read it. It is sent nothing else: no cookie (lzrprf keeps
# none), no Referer, no Origin, only the fixed request of its address [C7].
# Each one a place I of the page draws is fetched once, the way the page was: its
# line in the log first, then "fetch", so a site is sent "request" of the
# picture's address and nothing else. At most $PICTURES_AT_ONCE are fetched
# and decoded side by side, each in a process of its own that writes nothing
# to the log: lzrprf writes every line itself. A path goes to the same checked
# addresses the page came from. Any other host is checked as a typed address is
# (sub address), its line is written before it is looked up [C5], with Tor on
# it is fetched through Tor as everything is [C17], and a host that
# leads inside your own network is not fetched at all, with no question: a
# page cannot make lzrprf ask you about your router [C8]. The application decodes it, in a
# page container of its own started as a page's is, and writes pixels:
#
#   P<w>,<h>      then exactly h lines p<hex>, 8 times w lowercase hex characters each:
#                 red, green, blue and how opaque, a byte each, not multiplied by it;
#                 1 to 1024 wide and high, 200,000 pixels at most; or P0,0 for none
#
# Anything else is no picture, and so is a picture not begun within one clock
# of $PICTURE_SECONDS for them all. Each place I becomes, for the window, an M
# with its rows in base64, the form of a picture a laid page already has, or
# the G it would be without one. This does not widen what the window reads:
# the window decodes no picture of a site (a video it hands to the system is
# the one file of a site it holds [C22]), and every byte of an M and
# its rows was written by lzrprf from numbers and hex it checked here, so the
# window is given nothing it was not given before. Returns the lines for the
# window, how many pictures were fetched and how many were asked for, and the
# pictures decoded, by number, which a new width places again; or nothing
# when a line of the log could not be written.
sub pictures_state {                      # what one page's pictures are fetched with: sub pictured's own, or begun ahead of it for an early list (sub pictures_ahead)
    my ($paths, $wanted, $host, $where, $kept, $page) = @_;
    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;    # as in visit: no line of these requests falls into a clearing of the log
    my %once;
    my @waiting = grep { $wanted->{$_} && !$once{$_}++ } @$paths;    # in the page's order
    shield_asked(map { m{^/} ? "https://$host$_" : (address($_))[0] } @waiting);    # [C28] all judged in one run, before any is looked up or fetched
    return { owner => $$, request => $request, host => $host, where => $where, kept => $kept, answer => $page // '', until => now() + $PICTURE_SECONDS, n => 0, lost => 0, running => {}, sites => {}, found => {}, hosts => [], picture => {}, begun => {%once}, waiting => \@waiting,
        named => (body_of($page // '') // '') =~ s/&amp;/&/gr };    # running: each picture fetched now, by the number fork gave for it: its entry, its address, what it said so far, its pipe; sites: the other sites asked for this page's pictures so far; found: what each other host was found at, looked up once; named: the page's own text, its body alone and not the site's headers, where an address on another site must stand (sub named_in)
}

sub pictures_begun {                      # the pictures waiting begun, up to $PICTURES_AT_ONCE side by side: every check and every line of the log of each, then its run
    my ($P, $few) = @_;                   # $few: at most that many begun in this call (sub pictures_ahead, sub pictures_pumped): beginning eight at once held the page's waiting script requests 31 ms on yle.fi (measured 2026-11-25)
    my ($host, $where, $kept) = @$P{qw(host where kept)};
    while (!$P->{lost} && @{ $P->{waiting} } && keys(%{ $P->{running} }) < $PICTURES_AT_ONCE && now() < $P->{until} && (!defined $few || $few-- > 0)) {    # a picture not begun within the clock is not begun
        my $entry = shift @{ $P->{waiting} };
        my $n = ++$P->{n};
        if (listed($entry =~ m{^/} ? "https://$host$entry" : $entry)) { refused("a picture the page $host names", $kept) or $P->{lost} = 1; next }    # [C23] its place stays a grey box, and nothing is looked up or asked
        my ($url, $there) = $entry =~ m{^/} ? ("https://$host$entry") : address($entry);    # another host: checked as a typed address is
        next unless defined $url;
        if (my $filter = filter_said($url, 'image', $host)) { record("$url not fetched: $filter", $kept) or $P->{lost} = 1; next }
        if ((my $shield = shield_said($url)) ne 'allow') { record("$url not fetched: " . shield_why($shield), $kept) or $P->{lost} = 1; next }    # [C28] its place stays a grey box, and its host is not even looked up    # [C27] after [C23]: its place stays a grey box, and nothing is looked up or asked
        my $other = defined $there && elsewhere($there, $host);
        if ($other && !pictures_elsewhere()) { record("$url not fetched: pictures from other sites are blocked (Block pictures from other sites, in the cogwheel's menu)", $kept) or $P->{lost} = 1; next }    # [C4] the setting of the cogwheel's menu (sub pictures_elsewhere): nothing is looked up, nothing is asked
        if ($other && !named_in($P->{named}, $there, $url)) { record("$url not fetched: the page $host does not name that address in its text", $kept) or $P->{lost} = 1; next }    # [C4] the application named it, and may be hostile: nothing is looked up, nothing is asked
        if ($other && !$P->{sites}{$there}) {    # another site, not asked yet for this page
            if (keys(%{ $P->{sites} }) >= $PICTURE_SITES) { record("$url not fetched: the page $host names pictures on more than $PICTURE_SITES other sites, and lzrprf asks at most $PICTURE_SITES of them for one page's pictures", $kept) or $P->{lost} = 1; next }    # [C4] nothing is looked up, nothing is asked
            $P->{sites}{$there} = 1;
        }
        my $to = $where;
        if (defined $there && $there ne $host) {
            record("the page $host names a picture on $there: $url", $kept) or ($P->{lost} = 1, last);    # [C5] before the name is even looked up
            my $why;
            ($to, $why) = @{ $P->{found}{$there} //= [$TOR_WANTED ? tor_where($there) : find($there)] };    # one lookup for each host of the page's pictures, however many it names there
            if ($to && grep { $_->{own} } @$to) { ($to, $why) = (undef, "$there leads inside your own network (" . join(', ', map { $_->{text} } @$to) . '), where no picture is fetched') }    # [C8] never for a picture, and nothing is asked
            if (!$to) { record("$url not fetched: $why", $kept) or $P->{lost} = 1; next }
            push @{ $P->{hosts} }, $there unless grep { $_ eq $there } @{ $P->{hosts} };
        }
        record("$url -> lzrprf connects " . ($TOR_WANTED ? 'through Tor, one circuit for ' . ($there // $host) : 'to the first that answers of: ' . join(', ', map { $_->{text} } @$to)), $kept) or ($P->{lost} = 1, last);    # [C5] written down first, connected second
        busy("Fetching picture $n of the page: $url");
        pipe(my $from_run, my $to_lzrprf) or next;
        my $run = fork // next;
        if (!$run) {                    # fetched and decoded beside up to seven others; what it says goes to lzrprf alone, which writes the log
            setpgrp(0, 0);              # a group of its own, named by its number, so what it started (curl, the application, sips) ends with it
            spare_dropped(); curl_ended($CURL_SPARE); undef $CURL_SPARE;    # its copies of the ends of what lzrprf started before a run: closed here, so they hold nothing open
            close $from_run;
            $RUN = getppid();           # it goes on while lzrprf does, and lzrprf ends it when the window is gone
            $SHIELD_CHILD = 1;          # [C28] it asks the application nothing: what was judged before it, and only that, may be fetched
            my ($got, $why, $from) = fetch($url, $to, undef, undef, undef, undef, ['image', $host]);    # [C6] [C7]
            my ($wrote) = $why ? () : contained($url, $got);    # [C1] [C3] no frame of style sheets: a picture run
            my $system = '';            # what the system's decoder made of it, for the log
            if (defined $wrote && $wrote =~ /\AS([1-9][0-9]{0,8})\n/ && length($wrote) == length($&) + $1) {    # [C21] a file the application does not decode, handed back whole
                my $body = body_of($got);    # what sips is given is the site's answer itself, which lzrprf takes from what curl fetched: the application only says that it is for the system, and chooses no byte of it
                my ($png, $fault) = defined $body && $body eq substr($wrote, length $&) ? system_decoded($body) : (undef, 'the application handed back another file than the site answered');
                ($wrote) = defined $png ? contained($url, "HTTP/1.1 200 OK\r\nContent-Length: " . length($png) . "\r\n\r\n$png") : ();    # the PNG is decoded by the application as any picture is
                $system = defined $png ? 'decoded by the operating system (sips) and then by the application' : "the operating system's decoder gave no picture: $fault";
            }
            print $to_lzrprf join("\t", defined $wrote ? 1 : 0, length($got // ''), $from // '', $why // '', $system), "\n", $wrote // '';
            close $to_lzrprf;
            POSIX::_exit(0);
        }
        close $to_lzrprf;
        setpgrp($run, $run);            # the same from this side, so the group is there whichever of the two runs first
        $P->{running}{$run} = [$entry, $url, '', $from_run];
    }
    return;
}

sub pictures_heard {                      # ($P, $wait): what the runs wrote within $wait seconds read, and each that ended written to the log and kept
    my ($P, $wait) = @_;
    my $kept = $P->{kept};
    return unless %{ $P->{running} };
    my $read = '';
    vec($read, fileno $_->[3], 1) = 1 for values %{ $P->{running} };
    select($read, undef, undef, $wait) > 0 or return;
    for my $run (grep { vec($read, fileno $P->{running}{$_}[3], 1) } keys %{ $P->{running} }) {
        my $one = $P->{running}{$run};
        my $came = sysread($one->[3], $one->[2], 262144, length $one->[2]);
        next if defined $came ? $came && length $one->[2] <= $PAGE_BYTES + 1000 : $!{EINTR} || $!{EAGAIN};    # a read a signal broke off is tried again
        delete $P->{running}{$run};    # it has said all it says
        close $one->[3];
        waitpid $run, 0;
        my ($head, $wrote) = split /\n/, $one->[2], 2;
        my ($decoded, $length, $from, $why, $system) = split /\t/, $head // '', 5;
        $why = 'the request could not be made' unless defined $from && ($length // '') =~ /^\d+$/;
        record("$one->[1] " . (length $why ? "failed: $why" : "answered: $length bytes from $from" . (length($system // '') ? "; $system" : '')), $kept) or ($P->{lost} = 1, last);
        $P->{picture}{ $one->[0] } = pixels($wrote) if !length $why && $decoded && defined $wrote;    # [C9]
    }
    return;
}

sub pictures_ended {                      # what still runs of a page's pictures ended, each run and every process of its group, sips among them, by the number fork gave
    my ($P) = @_;
    kill 'KILL', map { (-$_, $_) } keys %{ $P->{running} };
    waitpid $_, 0 for keys %{ $P->{running} };
    decoders_removed(keys %{ $P->{running} });    # [C21] the folder a run ended this way had for the system's decoder, which it could not remove itself
    close $P->{request};
    return;
}

# The pictures an early list places (sub live_early), begun while the page's
# scripts still run: the same checks, the same lines of the log before each
# request and the same runs as sub pictured makes, which takes them over when
# the page's own list is here and begins only what that list places besides.
# What the page's own list does not place after all was fetched as the early
# one placed it. Never through Tor, where a request waits for the page [C17].
sub pictures_judged {                     # ($lines, $paths, $host): the pictures of the page's first list judged beside its second run (sub shield_ahead), so its early list finds their verdicts
    my ($lines, $paths, $host) = @_;
    return if $TOR_WANTED;
    my %wanted = map { /^I\d+,\d+,\d+,\d+,(\d+)$/ ? ($paths->[$1] => 1) : () } @$lines;
    shield_ahead(map { m{^/} ? "https://$host$_" : (address($_))[0] } grep { $wanted{$_} } @$paths);
    return;
}

sub pictures_ahead {
    my ($lines, $paths, $host, $sent) = @_;
    my $page = $AHEAD_PAGE or return;
    return if $PICTURES_AHEAD || $TOR_WANTED || $page->{host} ne $host;
    my %wanted = map { /^I\d+,\d+,\d+,\d+,(\d+)$/ ? ($paths->[$1] => 1) : () } @$lines;
    return unless %wanted;
    $PICTURES_AHEAD = pictures_state($paths, \%wanted, $host, @$page{qw(where kept answer)}) or return;
    $PICTURES_AHEAD->{early} = [$lines, $paths, $host];    # the list they are drawn into when they are here (sub pictures_pumped)
    $PICTURES_AHEAD->{sent} = [$sent, $TAB, $WINDOW_LISTS] if $sent;    # the list the window was just handed, and how to tell that it still holds it
    timed('pictures-ahead ' . scalar @{ $PICTURES_AHEAD->{waiting} }) if $TIMED;
    pictures_begun($PICTURES_AHEAD, 2);
    return;
}

sub pictures_pumped {                     # the pictures begun ahead: what they wrote so far read without waiting, and the next of them begun
    my $P = $PICTURES_AHEAD or return;
    return if $P->{owner} != $$;        # a run started since holds a copy of them (a picture's own run reads its decoder as a page is read): only the process that began them hears them or begins more
    pictures_heard($P, 0);
    pictures_begun($P, 2);
    if ($P->{early} && !%{ $P->{running} } && !@{ $P->{waiting} } && !$P->{lost} && !$P->{shown}++ && %{ $P->{picture} }) {    # all of them here before the page's own list: the early list drawn once more, with them in their places
        my ($shown) = pictured(@{ $P->{early} }, undef, undef, pictures_so_far($P->{host}));
        my $held = $P->{sent} && $P->{sent}[1] == $TAB && $P->{sent}[2] == $WINDOW_LISTS ? $P->{sent}[0] : undef;    # the window still holds the early list: only the pictures' lines are sent
        window_changed($held, $shown);
        timed('pictures-early') if $TIMED;
    }
    return;
}

sub pictures_waited {                     # ($ready, $seconds): select on $ready for reading, changed in place as select changes it; the runs of the pictures begun ahead wake it too and are heard then. Returns how many of the caller's own are ready
    my $P = $PICTURES_AHEAD;
    undef $P if $P && $P->{owner} != $$;
    my @own = grep { vec($_[0], $_, 1) } 0 .. 8 * length($_[0]) - 1;
    if ($P) { vec($_[0], fileno $_->[3], 1) = 1 for values %{ $P->{running} } }
    prefetch_select(\$_[0]);              # and the scripts begun ahead (17-prefetch.pl)
    my $any = select($_[0], undef, undef, $_[1]) > 0;
    $_[0] = q{} unless $any;
    pictures_pumped() if $P && $any;
    prefetch_heard($_[0]) if $any;
    return scalar grep { vec($_[0], $_, 1) } @own;
}

sub pictures_so_far {                     # ($host): the pictures a first list may place with nothing fetched: those kept of the page this tab showed before on this host, and over them those begun ahead for this page that are decoded by now
    my ($host) = @_;
    my ($P, $B) = ($PICTURES_AHEAD, $PICTURES_BEFORE);
    if ($B && ($B->{host} ne $host || $B->{tab} != $TABS[$TAB])) { undef $PICTURES_BEFORE; undef $B }    # the tab went to another host, or another tab is read: dropped
    return { ($B ? %{ $B->{picture} } : ()), ($P && $P->{owner} == $$ && $P->{host} eq $host ? %{ $P->{picture} } : ()) };
}

sub pictures_before {                     # ($shown, $tab): the decoded pictures of the page shown in this tab kept for the visit that begins, by their entry, up to $PICTURES_BEFORE_BYTES; what was kept before is dropped first
    my ($shown, $tab) = @_;
    undef $PICTURES_BEFORE;
    my $all = $shown && $shown->{pictures} or return;
    my ($bytes, %kept) = (0);
    for my $entry (sort keys %$all) {
        my $size = 0;
        $size += length for @{ $all->{$entry} }[2 .. $#{ $all->{$entry} }];
        next if $bytes + $size > $PICTURES_BEFORE_BYTES;
        $bytes += $size;
        $kept{$entry} = $all->{$entry};
    }
    $PICTURES_BEFORE = { tab => $tab, host => $shown->{host}, picture => \%kept } if %kept;
    return;
}

sub pictures_dropped {                    # the pictures begun ahead and never taken over, ended
    pictures_ended($PICTURES_AHEAD) if $PICTURES_AHEAD && $PICTURES_AHEAD->{owner} == $$;
    undef $PICTURES_AHEAD;
    undef $AHEAD_PAGE;
    return;
}

sub pictured {
    my ($lines, $paths, $host, $where, $kept, $decoded, $page) = @_;    # $decoded: the pictures of this page decoded before, by their entry in =pictures; given when it is laid out again, and then nothing is fetched (sub relaid); $page: the page's answer as it was fetched, which an address on another site must stand in
    my %wanted = map { /^I\d+,\d+,\d+,\d+,(\d+)$/ ? ($paths->[$1] => 1) : () } @$lines;    # by entry: at another width the page may choose other sources, and an entry decoded then is placed again
    @PICTURED = ();
    if (!%wanted) { pictures_dropped() unless $decoded; return ($lines, 0, 0, {}) }
    my %picture = $decoded ? %$decoded : ();
    if (!$decoded) {
        my $P = $PICTURES_AHEAD;
        undef $PICTURES_AHEAD;
        undef $P if $P && $P->{owner} != $$;
        if ($P && ($P->{host} ne $host || $P->{answer} ne ($page // ''))) { pictures_ended($P); undef $P }    # begun for another page than this one
        if ($P) {                           # begun ahead for this very page: what this list places besides waits behind them, in the page's order
            my @more = grep { $wanted{$_} && !$P->{begun}{$_}++ } @$paths;
            shield_asked(map { m{^/} ? "https://$host$_" : (address($_))[0] } @more);    # [C28]
            push @{ $P->{waiting} }, @more;
            @$P{qw(where kept)} = ($where, $kept);
        }
        $P //= pictures_state($paths, \%wanted, $host, $where, $kept, $page) or return;
        while (!$P->{lost} && alive() && (%{ $P->{running} } || @{ $P->{waiting} } && now() < $P->{until})) {
            pictures_begun($P);
            last if $P->{lost} || !%{ $P->{running} };
            pictures_heard($P, 1);
        }
        pictures_ended($P);                 # the window is gone or a line could not be written: what still runs is ended
        return if $P->{lost};
        %picture = %{ $P->{picture} };
        @PICTURED = @{ $P->{hosts} };
    }
    my ($drawn, @shown) = (0);
    for (@$lines) {
        my ($x, $y, $w, $h, $n, @fit) = /^I(\d+),(\d+),(\d+),(\d+),(\d+)(?:,([1-4]),(\d+),(\d+),(\d+),(\d+))?$/ or (push(@shown, $_), next);
        my $one = $picture{ $paths->[$n] };
        if ($one && ($drawn += $one->[0] * $one->[1]) <= $DRAWN_PIXELS) {
            $one = $picture{ $paths->[$n] } = picture_one($one);
            my @crop = defined $fit[0] ? fit_crop($x, $y, $w, $h, $one->[0], $one->[1], @fit) : ($x, $y, $w, $h);
            next unless @crop;    # the fit leaves nothing of the picture in its box
            push @shown, 'N' . join(',', picture_named($one), @crop[0 .. 3], $one->[0], $one->[1], @crop[4 .. $#crop]);    # by its name: its rows go to the window once (sub named_owed), however many lists place it
        }
        else { push @shown, "G$x,$y,$w,$h" }
    }
    return (\@shown, scalar(grep { $picture{$_} } keys %wanted), scalar(keys %wanted), \%picture);
}

# A decoded picture goes to the window once. A list places it by a name, a line
# "N<name>,x,y,w,h,<wide>,<high>" with the fit's four numbers after it when it
# has a fit, and holds none of its rows; before a list is written, the rows of
# every picture it names that this process has not sent yet are written as
# "picture <name> <wide> <high>", a line "m<row>" for each row and a line "."
# (sub named_owed, called by sub window alone). A page's three lists and a
# page loaded again so carry each picture's rows once: on a front page 22 MB
# went with every list (measured in the real browser, 2026-11-25). Only sub
# pictured writes a line N: a list the application makes may not hold one (sub
# laid_run), so a page cannot place a bitmap of another page. The window keeps
# a bounded number of bitmaps; one it no longer has is asked for with "page
# refresh", and then every picture of the list is owed again (sub named_again).
my %NAMED_LIKE;                           # the names of this process by what a picture looks like at a glance (sub picture_like), so a picture decoded again finds the name of the same pixels

sub picture_named {                       # ($one): the name of a decoded picture, made the first time it is placed
    my ($one) = @_;
    if ($NAMED_OWNER != $$) {             # the first name of this process: a start of its own
        my $bytes = '';
        if (open my $random, '<:raw', '/dev/urandom') { read($random, $bytes, 4); close $random }
        $bytes = pack('N', (time() ^ ($$ << 15)) & 0xffffffff) unless length($bytes) == 4;
        ($NAMED_RUN, $NAMED_OWNER, $NAMED_COUNT) = (unpack('H*', $bytes), $$, 0);
        %NAMED = %NAMED_AT = %NAMED_LIKE = ();
    }
    my $known = $NAMED_AT{ 0 + $one };
    return $known->[0] if $known && defined $known->[1] && $known->[1] == $one;
    if (!(++$NAMED_COUNT % 64)) {         # the names of pictures no page keeps any more are let go
        for my $name (grep { !defined $NAMED{$_}[1] } keys %NAMED) { delete $NAMED{$name} }
        for my $at (grep { !defined $NAMED_AT{$_}[1] } keys %NAMED_AT) { delete $NAMED_AT{$at} }
        for my $like (grep { !$NAMED{ $NAMED_LIKE{$_} } } keys %NAMED_LIKE) { delete $NAMED_LIKE{$like} }
    }
    my $like = picture_like($one);
    my $entry = [$NAMED_RUN . sprintf('%x', $NAMED_COUNT), $one, 0];
    weaken($entry->[1]);
    $NAMED{ $entry->[0] } = $NAMED_AT{ 0 + $one } = $entry;
    $NAMED_LIKE{$like} = $entry->[0];
    return $entry->[0];
}

sub picture_one {                         # ($one): the picture already named that holds the same pixels, when one is still kept; else $one. A page asked again, or the next page of a site, decodes its pictures again: placed as the one the window holds, no row is sent and the second copy is let go
    my ($one) = @_;
    return $one if $NAMED_OWNER != $$ || $NAMED_AT{ 0 + $one };
    my $same = $NAMED{ $NAMED_LIKE{ picture_like($one) } // '' };
    return $same && defined $same->[1] && picture_same($same->[1], $one) ? $same->[1] : $one;
}

sub picture_like {                        # ($one): what a decoded picture looks like at a glance: its size, its rows' number and its middle row
    my ($one) = @_;
    return join ',', @$one[0, 1], $#$one, $one->[ 2 + int(($#$one - 2) / 2) ] // '';
}

sub picture_same {                        # ($one, $other): both hold the same size and the same rows, each compared whole
    my ($one, $other) = @_;
    return 0 if @$one != @$other;
    $one->[$_] eq $other->[$_] or return 0 for 0 .. $#$one;
    return 1;
}

sub named_owed {                          # (@lines of one list): the rows of each picture it names that the window was not sent yet, as lines to write before it
    my @owed;
    for (@_) {
        next unless /^N([0-9a-f]{9,24}),/;
        my $entry = $NAMED{$1} or next;
        next if $entry->[2] || !defined $entry->[1];
        $entry->[2] = 1;
        my $one = $entry->[1];
        push @owed, "picture $entry->[0] $one->[0] $one->[1]", (map { "m$_" } @$one[2 .. $#$one]), '.';
    }
    return @owed;
}

sub named_again { $_->[2] = 0 for values %NAMED; return }    # the window said it lacks a bitmap a list names: every picture is owed again with the list that names it next

# object-fit and object-position (CSS Images 3, sections 5.5 and 5.6): the
# engine lays the page out before any picture is decoded, so an I line whose
# img is not fill carries five more numbers: the fit (1 contain, 2 cover, 3
# none, 4 scale-down), then across and down each a permyriad of the room the
# box leaves and px, each plus 100000 so no number has a sign. Given the box
# x, y, w, h and the decoded picture pw by ph, gives the part of the box the
# picture shows in (rounded to whole px) and the part of the picture drawn
# there, in hundredths of a picture pixel: left, top, width and height of each.
# Nothing when none of it shows. The same arithmetic, in the same order, as the
# engine's layout/object_fit.rs crop, whose tests hold the numbers of this one's
# selftest. A picture the decoder made smaller has lost its own size: none and
# scale-down use the smaller one.
sub fit_crop {
    my ($x, $y, $bw, $bh, $nw, $nh, $fit, $xp, $xl, $yp, $yl) = @_;
    return if $nw < 1 || $nh < 1 || $bw <= 0 || $bh <= 0;
    my $round = sub { $_[0] < 0 ? -int(0.5 - $_[0]) : int($_[0] + 0.5) };
    my ($across, $down) = ($bw / $nw, $bh / $nh);
    my $contain = $across < $down ? $across : $down;
    my $scale = $fit == 1 ? $contain : $fit == 2 ? ($across > $down ? $across : $down) : $fit == 3 || $contain > 1 ? 1 : $contain;
    my ($w, $h) = ($nw * $scale, $nh * $scale);
    my $ox = $x + ($xp - 100000) / 10000 * ($bw - $w) + ($xl - 100000);
    my $oy = $y + ($yp - 100000) / 10000 * ($bh - $h) + ($yl - 100000);
    my ($l, $t) = ($round->($ox > $x ? $ox : $x), $round->($oy > $y ? $oy : $y));
    my ($r, $b) = ($round->($ox + $w < $x + $bw ? $ox + $w : $x + $bw), $round->($oy + $h < $y + $bh ? $oy + $h : $y + $bh));
    return if $r <= $l || $b <= $t || $w <= 0 || $h <= 0;
    my $along = sub {
        my ($from, $o, $size, $n) = @_;
        my ($v, $most) = ($round->(($from - $o) * $n / $size * 100), $round->($n * 100));
        $v < 0 ? 0 : $v > $most ? $most : $v;
    };
    my ($sx, $sy, $sr, $sb) = ($along->($l, $ox, $w, $nw), $along->($t, $oy, $h, $nh), $along->($r, $ox, $w, $nw), $along->($b, $oy, $h, $nh));
    return if $sr <= $sx || $sb <= $sy;
    return ($l, $t, $r - $l, $b - $t, $sx, $sy, $sr - $sx, $sb - $sy);
}

# A picture for the system to decode [C21]: the site's answer itself, which
# the application said is for the system and handed back whole, so lzrprf
# knows it is the same file; an ISO base media file whose first box names
# AVIF or HEIF, as the application judged it, judged again here. In a folder
# of its own, readable by you alone and removed after, the file is written,
# and the system's own sips runs in the decoder container to write it as a
# PNG: told to make it at most 1024 pixels a side when the file says it is
# larger (sub stated_size; sips -Z makes a small picture larger too, so it is
# told only then), and once more on the PNG when a side of it is still over
# 1024 (a file that said too little). In its container sips ends at once when
# asked the size of an AVIF, so the size is read here. A PNG is taken only
# when the system said, before sips started ($GATE), that it ran contained,
# and only when out.png is a plain file with no other name. Returns the PNG,
# or nothing and why.
sub system_decoded {
    my ($file) = @_;
    my $size = length $file >= 16 ? unpack('N', $file) : 0;
    my @brands = $size >= 16 && $size <= 256 && $size % 4 == 0 && length $file >= $size && substr($file, 4, 4) eq 'ftyp' ? (substr($file, 8, 4), unpack('(a4)*', substr($file, 16, $size - 16))) : ();
    return (undef, 'it is not an AVIF, HEIC or HEIF file') unless grep { /^(?:avif|avis|heic|heix|heim|heis|hevc|hevx|mif1|msf1)$/ } @brands;
    my $folder = abs_path($DIR) // return (undef, 'no folder could be made for it');
    $folder .= '/decode.' . $$ . '.' . join('', map { sprintf '%02x', int rand 256 } 1 .. 6);
    (() = decoding($folder, $SIPS)) or return (undef, "the folder for it has a name lzrprf does not pass on");
    mkdir($folder, 0700) or return (undef, 'no folder could be made for it');
    if (!mkdir("$folder/t", 0700)) { remove_tree($folder); return (undef, 'no folder could be made for it') }    # no empty folder is left
    my ($in, @result) = (undef, undef, 'the file could not be written');
    if (sysopen($in, "$folder/in", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) && (syswrite($in, $file) // -1) == length $file && close $in) {
        local $ENV{LZRPRF_TMPDIR} = "$folder/t/";
        local $SAID_INSIDE = 1;           # each run is asked about while it runs, before it is waited for (sub said)
        my ($png, $why) = ('', 'it wrote no PNG');
        my ($wide, $high) = stated_size($file);
        for my $run (1, 2) {
            my ($w, $h) = $run == 1 ? ($wide, $high) : substr($png, 0, 16) eq "\x89PNG\r\n\x1a\n\0\0\0\rIHDR" ? unpack('NN', substr($png, 16, 8)) : ();
            my $smaller = $w && $h && ($w > $DECODED_SIDE || $h > $DECODED_SIDE);
            last if $run == 2 && !($smaller && rename("$folder/out.png", "$folder/in"));
            (undef, my $ended) = said($DECODE_SECONDS, decoding($folder, '/usr/bin/perl', '-e', $GATE, $SIPS, '-s', 'format', 'png', $smaller ? ('-Z', $DECODED_SIDE) : (), "$folder/in", '--out', "$folder/out.png"));
            ($png, $why) = ('', defined $ended ? 'it wrote no PNG' : 'the system did not say that sips was in its container');
            last unless $ended;
            my ($read, $large) = plain_read("$folder/out.png", $DECODED_BYTES);
            if (defined $read) { $png = $read } elsif ($large) { $why = 'it wrote a PNG larger than lzrprf takes' }
        }
        @result = substr($png, 0, 8) eq "\x89PNG\r\n\x1a\n" ? ($png) : (undef, $why);
    }
    remove_tree($folder);
    return @result;
}

# What a program in a container of lzrprf's wrote, read only when its name is
# a plain file with one name, at most $most bytes, looked at before it is
# opened (lstat) and again once it is open, the same file: a link, a pipe or
# a device put in its place by a program that misbehaved is never opened or
# never waited on (O_NONBLOCK), and lzrprf goes on to remove the folder.
# Returns the bytes, or nothing and whether a plain file was too large.
# [C21] [C24]
sub plain_read {
    my ($path, $most) = @_;
    my @named = lstat $path or return;
    return (undef, 1) if -f _ && $named[7] > $most;
    return unless -f _ && $named[3] == 1;
    sysopen(my $in, $path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return;
    my @opened = stat $in;
    my $same = -f _ && $opened[0] == $named[0] && $opened[1] == $named[1] && $opened[3] == 1 && $opened[7] <= $most;
    my $bytes = '';
    if ($same) { local $/; $bytes = <$in> // '' }
    close $in;
    return $same && length $bytes <= $most ? ($bytes) : ();
}

# Whether an MPEG-TS stream may carry sound: true unless its program map
# (ISO/IEC 13818-1 2.4.4: the PAT on PID 0 names the PMT's PID, the PMT
# names each stream's type) is found in its first packets and names only
# pictures (MPEG-1 and -2 video, H.264, HEVC). A map not found, or a type
# lzrprf does not know, counts as sound: so a stream goes to the converter
# whenever it is not plainly pictures alone. [C24]
sub ts_sounds {
    my ($ts) = @_;
    my $section = sub {                   # the first section of a table on this PID, in one packet: its bytes after the pointer field, or nothing
        my ($pid) = @_;
        for (my $at = 0; $at + 188 <= length $ts && $at < 188 * 2000; $at += 188) {
            my ($sync, $head, $flags) = unpack('CnC', substr($ts, $at, 4));
            return if $sync != 0x47;
            next unless ($head & 0x1fff) == $pid && $head & 0x4000;    # the start of a table
            my $from = 4;
            $from += 1 + unpack('C', substr($ts, $at + 4, 1)) if $flags & 0x20;    # an adaptation field first
            next if ($flags & 0x10) == 0 || $from >= 188;
            my $pointer = unpack('C', substr($ts, $at + $from, 1));
            return substr($ts, $at + $from + 1 + $pointer, 188 - $from - 1 - $pointer) if $from + 1 + $pointer < 188;
        }
        return;
    };
    my $pat = $section->(0) // return 1;
    return 1 unless length $pat >= 12 && unpack('C', $pat) == 0x00;
    my $length = unpack('n', substr($pat, 1, 2)) & 0x0fff;
    my ($pmt);
    for (my $at = 8; $at + 4 <= 3 + $length - 4 && $at + 4 <= length $pat; $at += 4) {
        my ($number, $pid) = unpack('nn', substr($pat, $at, 4));
        ($pmt = $pid & 0x1fff), last if $number != 0;
    }
    defined $pmt or return 1;
    my $map = $section->($pmt) // return 1;
    return 1 unless length $map >= 12 && unpack('C', $map) == 0x02;
    my $end = 3 + (unpack('n', substr($map, 1, 2)) & 0x0fff) - 4;    # before its CRC
    return 1 if $end > length $map;
    my $at = 12 + (unpack('n', substr($map, 10, 2)) & 0x0fff);
    my $streams = 0;
    while ($at + 5 <= $end) {
        my ($type, undef, $info) = unpack('Cnn', substr($map, $at, 5));
        return 1 unless $type == 0x01 || $type == 0x02 || $type == 0x1b || $type == 0x24;
        $streams++;
        $at += 5 + ($info & 0x0fff);
    }
    return $streams ? 0 : 1;
}

# An MPEG-TS stream with sound made into an MP4 file by the system's own
# avconvert [C24], which the window's player reads without the system's
# register of sound decoders, a name the window's container does not list.
# The preset is PresetPassthrough: the pictures and the sound are copied as
# they came, not decoded and not made again, into an MP4 with its index at
# its start. In a folder of its own, readable by you alone and removed
# after, in incognito too (as for sips [C21]), the stream is written as
# in.ts and avconvert writes out.mp4 in the converter container. An MP4 is
# taken only when the system said, before avconvert started ($GATE), that it
# ran contained, and only when out.mp4 is a plain file with no other name,
# at most $VIDEO_BYTES, whose first box is ftyp. Returns the MP4, or nothing
# and why.
sub system_converted {
    my ($ts) = @_;
    my $folder = abs_path($DIR) // return (undef, 'no folder could be made for it');
    $folder .= '/convert.' . $$ . '.' . join('', map { sprintf '%02x', int rand 256 } 1 .. 6);
    (() = converting($folder, $AVCONVERT)) or return (undef, 'the folder for it has a name lzrprf does not pass on');
    mkdir($folder, 0700) or return (undef, 'no folder could be made for it');
    if (!mkdir("$folder/t", 0700)) { remove_tree($folder); return (undef, 'no folder could be made for it') }    # no empty folder is left
    my ($in, @result) = (undef, undef, 'the stream could not be written for the system\'s converter');
    if (sysopen($in, "$folder/in.ts", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) && (syswrite($in, $ts) // -1) == length $ts && close $in) {
        local $ENV{LZRPRF_TMPDIR} = "$folder/t/";
        local $SAID_INSIDE = 1;           # asked about while it runs, before it is waited for (sub said)
        (undef, my $ended) = said($CONVERT_SECONDS, converting($folder, '/usr/bin/perl', '-e', $GATE, $AVCONVERT, '--preset', 'PresetPassthrough', '--source', "$folder/in.ts", '--output', "$folder/out.mp4"));
        my ($mp4, $why) = ('', defined $ended ? 'the system\'s converter made no MP4 of it' : 'the system did not say that its converter was in its container');
        my ($read, $large) = $ended ? plain_read("$folder/out.mp4", $VIDEO_BYTES) : ();
        if (defined $read) { $mp4 = $read } elsif ($large) { $why = "the system's converter made an MP4 larger than lzrprf takes" }
        @result = substr($mp4, 4, 4) eq 'ftyp' ? ($mp4) : (undef, $why);
    }
    remove_tree($folder);
    return @result;
}

# The size an AVIF or HEIF file says its pictures have: the largest of the
# "ispe" boxes in meta, iprp, ipco (ISO/IEC 23008-12 6.5.3), read as boxes
# are, from the top, and nothing when they are not there. It decides only
# whether sips is told -Z on its first run: a size that is wrong costs a
# second run, or a picture smaller than it could be, and nothing more. [C21]
sub stated_size {
    my ($file) = @_;
    my @boxes = ([0, length $file]);      # where to look next: a range of the file that holds boxes
    my ($wide, $high) = (0, 0);
    for my $want ('meta', 'iprp', 'ipco', 'ispe') {
        my @found;
        for my $range (@boxes) {
            my ($at, $end) = @$range;
            while ($at + 8 <= $end) {
                my ($size, $type) = unpack('Na4', substr($file, $at, 8));
                $size = $end - $at if $size == 0;
                last if $size < 8 || $at + $size > $end;    # a box that says it is larger than what holds it ends the reading of that range
                push @found, [$at + 8 + ($type eq 'meta' ? 4 : 0), $at + $size] if $type eq $want;    # meta is a full box: a version and flags come first
                $at += $size;
            }
            last if @found > 64;
        }
        @boxes = @found or return;
    }
    for (@boxes) {
        my ($at, $end) = @$_;
        next unless $end - $at >= 12;
        my ($w, $h) = unpack('NN', substr($file, $at + 4, 8));    # after its version and flags
        ($wide, $high) = ($w, $h) if $w * $h > $wide * $high;
    }
    return $wide && $high ? ($wide, $high) : ();
}

# The folders of the system's decoder left by picture runs that were ended
# by number (sub pictured): each run names its folder decode.<its number>.
# And, at the start, those of runs whose process is no longer there.  [C21]
sub decoders_removed {
    my (@runs) = @_;
    my $at = abs_path($DIR) // return;
    opendir(my $list, $at) or return;
    my %ended = map { $_ => 1 } @runs;
    for (readdir $list) {
        my ($run) = /^(?:decode|convert)\.([1-9][0-9]{0,9})\.[0-9a-f]{12}\z/ or next;    # [C24] a converter's folder too, named by lzrprf's own number: at the start, one of an lzrprf that is gone
        remove_tree("$at/$_") if @runs ? $ended{$run} : !kill(0, $run) && $!{ESRCH};
    }
    closedir $list;
}

