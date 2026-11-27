
# The scripts a page names, fetched ahead and side by side [C19]. While the
# application reads a page it asks for each external script it meets with a
# "=fetch" line and waits for the answer before it reads on, so a page of
# sixty scripts was sixty requests one after another, each its own curl,
# container and handshake: 7.5 seconds of hs.fi before its first drawing,
# measured 2026-11-24 (scripts/load-timeline.pl). So once the page's answer
# is here, lzrprf reads the addresses of its script elements from the
# answer's text (a pattern match on the bytes, nothing parsed and nothing
# run). It fetches none of them until the page asks for its first external
# script, which shows that this page runs them: a page whose scripts are not
# run makes the site no request of them. Then the others are fetched side by
# side, at most $PREFETCH_AT_ONCE at a time, each judged, filtered, looked up
# and written in the log before it is fetched, exactly as when the page asks
# for it. Nothing fetched ahead is handed to anything: when the page then
# asks for that address, with the very request that was made ahead (the same
# method, kind, origin and identity), its answer is the one lzrprf fetched,
# and every check of the page's request runs on it as before. A page
# lzrprf's sandbox runs carries no cookie and no Referer, so the request made
# ahead is the request the page makes, byte for byte. A page of a site you
# allowed is fetched ahead too (2026-11-25: yle.fi with a rule of yours read
# its twenty scripts one after another, a second of every visit). Its
# request carries the cookies the jar gives it, asked by the window before
# the run starts, and what the answer sets reaches the jar only when the
# page takes that answer: one never taken changes nothing you keep. An answer not asked for is dropped, unread, with the visit.
sub prefetch_end {                        # every request fetched ahead ended, and what it said dropped
    for my $one (values %PREFETCH) { next unless $one->{pid} && !$one->{done}; prefetch_ended($one); close $one->{from} if $one->{from} }
    for my $made (splice @PREFETCH_MADE) { prefetch_numbers($made); kill 'KILL', $made->{maker}; waitpid $made->{maker}, 0 }    # every maker ended and reaped: its copies are ended above or done
    %PREFETCH = ();
    @PREFETCH_WAITING = ();
    undef $PREFETCH_NAMED; undef $PREFETCH_LATER; shield_heard();    # and a judging run begun beside a visit that asked for none of its verdicts is taken and reaped here
    beside_dropped(); @AHEAD_SHEETS = (); %BESIDE_LOGGED = ();    # the run started beside a first run that never named its sheets
    for my $one (grep { !$_->{done} } values %AHEAD) { kill 'KILL', -$one->{pid}; kill 'KILL', $one->{pid}; waitpid $one->{pid}, 0; close $one->{from} }    # what was fetched ahead of a run and never asked for
    %AHEAD = ();
    fetchers_dropped() unless $_[0];
    find_dropped();
    pictures_dropped();
    return;
}

sub prefetch_begin {                      # ($url, $host, $got, $kept): the scripts the page's answer names, kept for when it asks for its first (sub prefetch_go)
    my ($url, $host, $got, $kept, $where) = @_;
    prefetch_end(1);                      # the copies that wait for this answer's style sheets stay (sub fetchers_for)
    return if $TOR_WANTED;                # [C17] through Tor every request is its own circuit, asked when the page asks
    $AHEAD_PAGE = { host => $host, where => $where, kept => $kept, answer => $got } if $where;
    permit_password($url, $got);       # [C26] a page for signing in runs no script in the sandbox: known before any of its scripts is begun
    ahead_sheets($url, $host, $got, $kept, $where) if $where;    # [C14] the style sheets the answer names, begun now: here when the first run names them
    my ($rules) = permit_rules();
    my $allowed = permit_site("https://$host", $rules, $url) // '';
    timed("prefetch-allowed $$ " . ($allowed || 'none')) if $TIMED;
    return unless $allowed;                 # [C26] a site whose scripts do not run asks for none
    my $body = body_of($got) // return;
    $body =~ s{<(noscript|template)\b.*?</\1\s*>}{}gis;    # what a page that runs scripts never loads
    my (@asked, %once);
    while ($body =~ /<script\b([^>]{0,2000})>/gi) {
        my $attributes = $1;
        my ($src) = $attributes =~ /(?:^|\s)src\s*=\s*(?:"([^"]{1,2000})"|'([^']{1,2000})'|([^\s"'>]{1,2000}))/i or next;
        $src = (grep { defined } $src, $2, $3)[0] // next;
        $src =~ s/&amp;/&/g;
        next if $attributes =~ /(?:^|\s)nomodule(?:[\s=]|\z)/i;    # the script for a browser without modules, which the application never asks for
        next if $attributes =~ /(?:^|\s)type\s*=\s*["']?(?!text\/javascript|application\/javascript|module)[a-z]/i;    # a data block or a template is not a script the page asks for
        my ($to, $there) = address(resolved($url, $src)) or next;
        next if $once{$to}++ || listed($to);    # [C23]
        push @asked, [$to, $there, 'script'];    # the application asks for a module as for any script (measured on yle.fi, 2026-11-24)
        last if @asked >= $PREFETCH_MOST;
    }
    while (@asked < $PREFETCH_MOST && $body =~ /<link\b([^>]{0,2000})>/gi) {    # what the answer tells a browser to load early (rel=preload, rel=modulepreload): a page whose scripts run asks for each, the fonts and sheets among them as data (measured on yle.fi, 2026-11-25)
        my $attributes = $1;
        my ($rel) = $attributes =~ /(?:^|\s)rel\s*=\s*["']?\s*(preload|modulepreload)\s*["']?(?:\s|\/|\z)/i or next;
        my ($as) = $attributes =~ /(?:^|\s)as\s*=\s*["']?\s*([a-z]{1,16})/i;
        my $dest = lc $rel eq 'modulepreload' || lc($as // q{}) eq 'script' ? 'script' : lc($as // q{}) =~ /^(?:font|style)\z/ ? 'data' : next;
        my ($href) = $attributes =~ /(?:^|\s)href\s*=\s*(?:"([^"]{1,2000})"|'([^']{1,2000})'|([^\s"'>]{1,2000}))/i or next;
        $href = (grep { defined } $href, $2, $3)[0] // next;
        $href =~ s/&amp;/&/g;
        my ($to, $there) = address(resolved($url, $href)) or next;
        next if $once{$to}++ || listed($to);    # [C23]
        push @asked, [$to, $there, $dest];
    }
    timed("prefetch-named $$ " . scalar @asked) if $TIMED;
    $PREFETCH_NAMED = { asked => \@asked, host => $host, kept => $kept, page => $url, allowed => $allowed } if @asked;
    $PREFETCH_LATER = [$url, $where, $host] if @asked && $where;
    prefetch_later() unless %AHEAD;        # a page with no style sheet begun ahead has one run: judged and begun now, as before    # with style sheets begun ahead its second run is the one shown: judged and begun once that run is started (sub prefetch_later), since the judging is a run of its own, 100 ms that neither the first run nor the early list waits for (measured on yle.fi, 2026-11-25)
    return;
}

sub prefetch_later {                      # what sub prefetch_begin left for the moment the page's first run is started: the scripts on the page's own host begin, at the addresses the page came from (a site whose scripts run asks for them; the first was asked 340 ms after the answer on yle.fi, 2026-11-25), and the other hosts it names are looked up meanwhile, not waited for: their requests begin when its sheets are here (sub ahead_fonts), or at its first script
    my $later = $PREFETCH_LATER or return;
    undef $PREFETCH_LATER;                # before anything is run: the run that judges them comes by here too
    my ($url, $where, $host) = @$later;
    my $named = $PREFETCH_NAMED or return;
    return if $named->{page} ne $url;
    my @other = grep { $_->[1] ne $host } @{ $named->{asked} };
    prefetch_go('', $url, $where);         # judges them all (sub shield_asked), and begins those on the page's own host
    find_ahead($_->[1]) for grep { !filter_said($_->[0], $FILTER_DEST{ $_->[2] }, $host) && shield_said($_->[0]) eq 'allow' } @other;    # [C27] [C28] a host whose every named address a list or the shield blocks is not even looked up
    return;
}

sub prefetch_go {                         # ($first, $page): the page $page asked for its first external script, $first: the others it names judged, looked up and fetched ahead
    my ($first, $page, $own) = @_;         # $own: only the scripts on the page's own host, at these addresses (sub prefetch_begin)
    my $named = $PREFETCH_NAMED or return;
    return if $named->{page} ne ($page // q{});    # only the page being read, never another tab's
    my $early = $own && !ref $own;       # 'found': only what is on a host whose lookup was begun ahead (sub find_ahead)
    undef $PREFETCH_NAMED unless $own;
    my ($host, $kept, $url, $allowed) = @$named{qw(host kept page allowed)};
    my $top = $allowed eq 'sandbox' ? undef : $url;    # [C26] [C7] a page outside the sandbox: the request made ahead is the one it makes, its site's cookies with it (sub prefetch_pump)
    my @asked = grep { $_->[0] ne $first } @{ $named->{asked} };
    return unless @asked;
    shield_asked(map { $_->[0] } @asked);  # [C28] all judged in one run, before any is looked up or fetched
    my %found;
    for my $one (@asked) {
        my ($to, $there, $dest) = @$one;
        next if $PREFETCH{$to} || ref $own && $there ne $host || $early && !$FINDING{$there} && !$found{$there};    # begun already; or not now
        next if filter_said($to, $FILTER_DEST{$dest}, $host);    # [C27] what a list blocks is never fetched; the page's own request says why
        next unless shield_said($to) eq 'allow';    # [C28]
        next if defined sso_cookie($to, $host);    # [C7] a request that carries a provider's cookies is made when the page asks
        next if defined $top && defined identity_of_host($there);    # [C7] D19: a request the page makes under another identity is made when it asks
        my ($where) = ref $own ? ($own) : @{ $found{$there} //= [find($there)] };
        next unless $where && !grep { $_->{own} } @$where;    # [C8] never into your own network
        push @PREFETCH_WAITING, { url => $to, where => $where, ask => { method => 'GET', type => '-', body => '', origin => $there eq $host ? undef : "https://$host", cookie => undef, top => $top, as => undef, dest => $dest, from => $host }, kept => $kept, page => $url };
        $PREFETCH{$to} = $PREFETCH_WAITING[-1];
    }
    prefetch_pump();
    return;
}

sub prefetch_soon {                       # [C19] ($live, $dest, $to): "=soon DEST URL", a GET the page's own script set going and makes in a later task (a script it made: yle.fi waited 205, 88 and 280 ms on three, one after another, 2026-11-25). Judged here as sub live_fetched will judge the request, begun with the two lines sub prefetch_pump writes first, and handed over only by sub prefetch_take when the page asks for exactly it. Whatever this refuses is simply not begun: the request says why when it comes
    my ($live, $dest, $to) = @_;
    return if $live->{home} || $TOR_WANTED || listed($to) || ++$live->{soon} > ($live->{kept_app} ? $LIVE_FETCH_KEPT_MOST : $LIVE_FETCH_MOST);
    my ($url, $host) = address($to);
    return if !$url || $PREFETCH{$url};
    my ($rules) = permit_rules();
    my $allowed = permit_site("https://$live->{host}", $rules, $live->{url}) or return;    # [C26] never for a site whose scripts do not run
    return if defined filter_said($url, $FILTER_DEST{$dest}, $live->{host});    # [C27]
    shield_asked($url);
    return unless shield_said($url) eq 'allow';    # [C28] before any lookup
    return if defined sso_cookie($url, $live->{host});    # [C7] as in sub prefetch_go
    my $top = $allowed eq 'sandbox' ? undef : $live->{url};
    return if defined $top && defined identity_of_host($host);    # [C7] D19
    return if $allowed eq 'sandbox' && $host ne $live->{host} && $dest ne 'script' && sandbox_says('fetch-other') eq 'refused';    # [C26] E1: what the sandbox's table refuses the request is not begun
    my ($where) = find($host);
    return unless $where && !grep { $_->{own} } @$where;    # [C8]
    my ($kept) = keeping();
    push @PREFETCH_WAITING, { url => $url, where => $where, ask => { method => 'GET', type => '-', body => '', origin => $host eq $live->{host} ? undef : "https://$live->{host}", cookie => undef, top => $top, as => undef, dest => $dest, from => $live->{host} }, kept => $kept, page => $live->{url} };
    if ($dest eq 'data' && defined $top && !jar_skips($url)) {    # [C7] a data request is begun ahead only where no cookie goes with it: the jar is asked now, once, and a request it has a cookie for is made by the page's own ask
        my $ask = $PREFETCH_WAITING[-1]{ask};
        if (length($ask->{jar} = jar_cookie($url, undef, $ask) // q{})) { pop @PREFETCH_WAITING; return }
    }
    $PREFETCH{$url} = $PREFETCH_WAITING[-1];
    prefetch_pump();
    return;
}

sub prefetch_pump {                       # the requests waiting started, up to $PREFETCH_AT_ONCE at a time, and what the running ones wrote read
    my $running = grep { $_->{pid} && !$_->{done} } values %PREFETCH;
    return unless @PREFETCH_WAITING && $running < $PREFETCH_AT_ONCE;
    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;    # as in visit: no line of these requests falls into a clearing of the log
    my @batch;
    while (@PREFETCH_WAITING && $running < $PREFETCH_AT_ONCE) {
        my $one = shift @PREFETCH_WAITING;
        record("the page $one->{page} names " . ($one->{ask}{dest} eq 'script' ? 'the script' : 'for an early load') . " $one->{url}; lzrprf fetches it ahead, for when the page asks for it", $one->{kept}) or last;    # [C5] written down first, connected second
        record("$one->{url} -> lzrprf connects to the first that answers of: " . join(', ', map { $_->{text} } @{ $one->{where} }), $one->{kept}) or last;
        $one->{ask}{jar} = jar_cookie($one->{url}, undef, $one->{ask}) // q{} if defined $one->{ask}{top} && !exists $one->{ask}{jar} && !jar_skips($one->{url});    # [C7] the jar asked here, by the window, never by the run below: the line Cookie it gives this request now, and what the answer sets is told to the jar only when the page takes it (sub prefetch_take)
        pipe(my $from, my $to) or last;
        @$one{qw(from to said)} = ($from, $to, '');
        push @batch, $one;
        $running++;
    }
    prefetch_made(@batch) if @batch;
    return;
}

sub prefetch_select {                     # (\$ready): the requests begun ahead and not yet read to their end, added to what a select waits for
    my ($ready) = @_;
    my $held = 0;
    $held += length($_->{said} // '') for values %PREFETCH;
    return if $held > $PREFETCH_HELD_BYTES;    # enough is held unread: the rest stay in their pipes, their places taken, until the page takes some (sub prefetch_take)
    vec($$ready, fileno $_->{from}, 1) = 1 for grep { $_->{pid} && !$_->{done} } values %PREFETCH;
    return;
}

sub prefetch_heard {                      # ($ready): what the requests begun ahead wrote, read while lzrprf waits for something else; one read to its end leaves its place to one that waits. Before, an answer was read only when the page asked for it, so the first $PREFETCH_AT_ONCE held every place until then: hs.fi names 45, and its other 21 were each made when the page asked, 60 to 130 ms its reader stood at each (measured 2026-11-25)
    my ($ready) = @_;
    my $ended = 0;
    for my $read (grep { $_->{pid} && !$_->{done} && vec($ready, fileno $_->{from}, 1) } values %PREFETCH) {
        my $n = sysread($read->{from}, $read->{said}, 262144, length $read->{said});
        next if !defined $n && ($!{EINTR} || $!{EAGAIN});
        next if $n && length $read->{said} <= $FETCH_BYTES + $WROTE_ROOM;
        $read->{done} = 1; close $read->{from}; $ended++;
    }
    prefetch_pump() if $ended;
    return;
}

# The requests of one turn of the pump begun by one copy of lzrprf, which makes
# the copy of each and waits for them: lzrprf itself made each before, 2.4 ms a copy,
# 46 ms in one stretch for the 19 scripts of yle.fi in which it read nothing
# of the page's run (measured 2026-11-25). Each request's copy is as before,
# in a group of its own; its number is told on a pipe and read only when the
# request has to be ended (sub prefetch_ended). None of them is a child of
# lzrprf: each ends by itself when its answer is written or its clock runs out.
sub prefetch_made {
    my (@batch) = @_;
    my $made = { numbers => undef };
    my ($told, $tell, $maker);
    if (!pipe($told, $tell) || !defined($maker = fork)) {    # none begun: the page makes each request itself when it asks
        for my $one (@batch) { close $_ for @$one{qw(from to)}; delete $PREFETCH{ $one->{url} } }
        return;
    }
    if (!$maker) {
        close $told;
        spare_dropped(); curl_ended($CURL_SPARE); undef $CURL_SPARE;    # its copies of the ends of what lzrprf started before a run, closed as a picture's run closes them (08-pictures.pl), so a fetch on the spare never waits for this one to end
        my $window = getppid();
        $RUN = $$;                        # each of its copies goes on while it does (sub alive), and it stays while lzrprf does and one of them runs
        $SHIELD_CHILD = 1;                # [C28] judged before it, and only that is fetched
        for my $at (0 .. $#batch) {
            my $one = $batch[$at];
            my $pid = fork // next;
            if (!$pid) {
                setpgrp(0, 0);            # a group of its own, so the curl it starts ends with it
                close $tell;
                close $_ for map({ $_->{from} } @batch), map { $_->{to} } grep { $_ != $one } @batch;    # the others' pipes: an answer ends when its own request does
                my ($got, $why, $peer) = fetch($one->{url}, $one->{where}, $one->{ask});    # [C6] [C7] the request the page makes
                print { $one->{to} } join("\t", length($got // ''), $peer // '', $why // ''), "\n", $got // '';
                close $one->{to};
                POSIX::_exit(0);
            }
            syswrite $tell, "$at $pid\n";
        }
        close $tell;
        close $_ for map { @$_{qw(from to)} } @batch;
        while (getppid() == $window) {    # lzrprf gone: it ends, and each copy sees that at its next look
            my $ended = waitpid(-1, POSIX::WNOHANG());
            last if $ended < 0;           # none left
            select(undef, undef, undef, 0.05) unless $ended;
        }
        POSIX::_exit(0);
    }
    close $tell;
    @$made{qw(from maker)} = ($told, $maker);
    for my $at (0 .. $#batch) { my $one = $batch[$at]; close delete $one->{to}; @$one{qw(pid made at)} = (1, $made, $at) }    # pid: begun, as before; its number is read when it is needed
    push @PREFETCH_MADE, $made;
    return;
}

sub prefetch_numbers {                    # ($made): the numbers its copies were given, read once its maker made them all
    my ($made) = @_;
    return $made->{numbers} if $made->{numbers};
    my ($said, $until) = ('', now() + 5);
    while (now() < $until) {
        my $ready = '';
        vec($ready, fileno $made->{from}, 1) = 1;
        next unless select($ready, undef, undef, 1) > 0;
        my $n = sysread($made->{from}, $said, 65536, length $said);
        next if !defined $n && ($!{EINTR} || $!{EAGAIN});
        last unless $n;
    }
    close $made->{from};
    return $made->{numbers} = { map { /^(\d{1,4}) ([1-9]\d{1,9})$/ ? ($1 => $2) : () } split /\n/, $said };
}

sub prefetch_ended {                      # ($one): a request begun and not done, ended with the curl it started
    my ($one) = @_;
    my $pid = $one->{made} ? prefetch_numbers($one->{made})->{ $one->{at} } : undef;
    if ($pid) { kill 'KILL', -$pid; kill 'KILL', $pid }
    return;
}

sub prefetch_asked { my ($ask) = @_; join "\t", map { $ask->{$_} // '-' } qw(method type origin top as dest from) }    # [C19] what makes two requests the same request

sub prefetch_keep {                       # ($url, $ask, $got, $peer): an answer the page was just handed, kept for the rest of the visit for its later reads of the very same request
    my ($url, $ask, $got, $peer) = @_;
    return if $TOR_WANTED || $PREFETCH{$url} || ($ask->{method} // '') ne 'GET' || defined $ask->{cookie} || defined $ask->{top} || length($ask->{body} // '');    # [C17] [C7] only what a sandboxed page asks with no cookie
    my $kept = 0;
    $kept += length $_->{answer}[0] for grep { $_->{answer} } values %PREFETCH;
    return if $kept + length $got > $VISIT_KEPT_BYTES;
    $PREFETCH{$url} = { ask => {%$ask}, done => 1, answer => [$got, undef, $peer] };
    return;
}

sub prefetch_take {                       # ($url, $ask): the answer fetched ahead for exactly this request, as fetch returns it; nothing when there is none
    my ($url, $ask, $shown) = @_;
    my $one = $PREFETCH{$url} or return;
    return if prefetch_asked($one->{ask}) ne prefetch_asked($ask) || defined $ask->{cookie} || length($ask->{body} // '');    # another request than the one made ahead: made now, as asked
    if ($one->{ask}{dest} eq 'data' && defined $ask->{top} && !exists $one->{answer} && !jar_skips($url) && length(jar_cookie($url, undef, $ask) // q{})) {    # [C7] the jar has a cookie for it now that it had not when it was told ahead (a sign-in step between): what was begun without it is dropped, and the request is made now, with it
        if ($one->{pid} && !$one->{done}) { prefetch_ended($one); close $one->{from} }
        delete $PREFETCH{$url}; @PREFETCH_WAITING = grep { $_ != $one } @PREFETCH_WAITING;
        return;
    }
    if ($one->{answer}) { return @{ $one->{answer} } unless $shown; delete $PREFETCH{$url}; return }    # the page laid out again in this visit asks the same again: the same answer, every check of its request run again; once it is shown and runs, what it asks is fetched anew
    if (!$one->{pid}) { delete $PREFETCH{$url}; @PREFETCH_WAITING = grep { $_ != $one } @PREFETCH_WAITING; return }    # not begun yet: made now, as asked
    my $until = now() + $FETCH_SECONDS + 5;
    while (!$one->{done} && now() < $until && alive()) {
        my $ready = '';
        vec($ready, fileno $_->{from}, 1) = 1 for grep { $_->{pid} && !$_->{done} } values(%PREFETCH), $one;
        select($ready, undef, undef, 1) > 0 or next;
        for my $read (grep { $_->{pid} && !$_->{done} && vec($ready, fileno $_->{from}, 1) } values(%PREFETCH), $one) {
            my $n = sysread($read->{from}, $read->{said}, 262144, length $read->{said});
            next if !defined $n && ($!{EINTR} || $!{EAGAIN});
            if (!$n || length $read->{said} > $FETCH_BYTES + $WROTE_ROOM) { $read->{done} = 1; close $read->{from}; prefetch_pump() }
        }
    }
    delete $PREFETCH{$url};               # kept again below only when it answered
    if (!$one->{done}) { prefetch_ended($one); close $one->{from}; return (undef, 'the site did not answer in time') }
    my ($head, $got) = split /\n/, delete($one->{said}), 2;
    my ($length, $peer, $why) = split /\t/, $head // '', 3;
    return (undef, 'the request could not be made') unless defined $length && $length =~ /^\d+$/ && defined $got && length $got == $length;
    return (undef, $why) if length($why // '');
    jar_heard($url, undef, $ask, $got) if exists $one->{ask}{jar};    # [C7] taken by the page: now its Set-Cookie lines reach the jar, as when fetch makes the request itself
    prefetch_keep($url, $one->{ask}, $got, $peer);
    return ($got, undef, $peer);
}

# What lzrprf fetches for a page by itself, its style sheets and its web
# fonts, side by side: each was one request after another, a container, a
# connection and a handshake each, 370 ms of yle.fi before its second run
# began (measured 2026-11-25). Every check and every line of the log of each
# is made by the caller before this is called, in the page's order; here
# the requests only run at once, at most $PREFETCH_AT_ONCE at a time, each
# in a run of its own as a script fetched ahead is, and their answers come
# back in the order asked.
sub together_said {                       # ($to, $url, $where, $most, $for): the one request of such a copy made, and its answer written to the process that began it
    my ($to, $url, $where, $most, $for) = @_;
    my ($got, $why, $peer) = fetch($url, $where, undef, undef, $most, undef, $for);    # [C6] [C7] the very request sheeted and fonted made one by one
    print $to join("\t", length($got // ''), $peer // '', $why // ''), "\n", $got // '';
    close $to;
    return;
}

sub together_started {                    # one request of sub fetched_together begun in a run of its own: its pid and the pipe its answer comes on, or why not
    my ($one) = @_;
    return if fetcher_taken($one);
    my ($from, $to, $pid);
    if (!pipe($from, $to) || !defined($pid = fork)) { @$one{qw(done why)} = (1, 'the request could not be made'); return }
    if (!$pid) {
        setpgrp(0, 0);            # a group of its own, so the curl it starts ends with it
        spare_dropped(); curl_ended($CURL_SPARE); undef $CURL_SPARE;    # as a script fetched ahead closes them (sub prefetch_pump)
        close $from;
        $RUN = getppid();
        together_said($to, @{ $one->{job} });
        POSIX::_exit(0);
    }
    close $to;
    @$one{qw(pid from)} = ($pid, $from);
    return;
}

sub together_read {                       # ($one): what one request begun in a run of its own has written so far, read; done when it is all here or too large
    my ($read) = @_;
    my $n = sysread($read->{from}, $read->{said}, 262144, length $read->{said});
    return if !defined $n && ($!{EINTR} || $!{EAGAIN});
    return if $n && length $read->{said} <= $FETCH_BYTES + $WROTE_ROOM;
    $read->{done} = 1; close $read->{from}; waitpid $read->{pid}, 0;
    return;
}

sub fetched_together {                    # ([$url, $where, $most, $for], ...): [$got, $why, $from] of each, as fetch returns them, in the order asked
    my @jobs = map { my $had = $AHEAD{ $_->[0] }; $had && $had->{key} eq ahead_key($_) ? { job => $_, %{ delete $AHEAD{ $_->[0] } } } : { job => $_, said => '' } } @_;    # one begun ahead for this very request is taken, running or done (sub ahead_begin)
    my @waiting = grep { !$_->{pid} } @jobs;
    my $until = now() + $FETCH_SECONDS + 5;
    while (grep { !$_->{done} } @jobs) {
        while (@waiting && (grep { $_->{pid} && !$_->{done} } @jobs) < $PREFETCH_AT_ONCE) {
            my $one = shift @waiting;
            together_started($one);
        }
        my @running = grep { $_->{pid} && !$_->{done} } @jobs or next;
        if (now() >= $until || !alive()) { for (@running) { kill 'KILL', -$_->{pid}; kill 'KILL', $_->{pid}; waitpid $_->{pid}, 0; close $_->{from}; @$_{qw(done why)} = (1, 'the site did not answer in time') } next }
        my $ready = '';
        vec($ready, fileno $_->{from}, 1) = 1 for @running;
        select($ready, undef, undef, 1) > 0 or next;
        together_read($_) for grep { vec($ready, fileno $_->{from}, 1) } @running;
    }
    return map {
        my $one = $_;
        if ($one->{why}) { [undef, $one->{why}] }
        else {
            my ($head, $got) = split /\n/, $one->{said}, 2;
            my ($length, $peer, $why) = split /\t/, $head // '', 3;
            !(defined $length && $length =~ /^\d+$/ && defined $got && length $got == $length) ? [undef, 'the request could not be made'] : length($why // '') ? [undef, $why] : [$got, undef, $peer];
        }
    } @jobs;
}

# A request begun ahead still waited for its own start: a copy of lzrprf, then
# curl in its container, 37 ms of the 63 yle.fi's style sheet took (measured
# 2026-11-25). So while the page's own answer is fetched, $FETCHERS_READY
# copies are made that each start their curl and wait to be told one
# address, on a pipe from this process alone. Told one, a copy makes the
# very request sub together_started's copy makes, with the curl that waits
# in it; never told, it is ended with the visit, having asked nothing.
my $FETCHERS_READY = 2;                   # DECLARED(yle.fi names one style sheet on its own host and most pages one to three; each copy that waits is a process and a curl)

sub fetchers_for {                        # ($where, $most, $for): copies begun for requests that differ in their address alone
    my ($where, $most, $for) = @_;
    fetchers_dropped();
    for (1 .. $FETCHERS_READY) {
        pipe(my $told, my $tell) or return;
        pipe(my $from, my $to) or return;
        my $pid = fork // return;
        if (!$pid) {
            setpgrp(0, 0);                # a group of its own, so the curl it starts ends with it
            spare_dropped(); curl_ended($CURL_SPARE); undef $CURL_SPARE;
            close $_ for $tell, $from;
            $RUN = getppid();
            curl_for(1);
            my ($url, $until) = ('', now() + $FETCH_SECONDS);
            while (alive() && now() < $until && $url !~ /\n/) {
                my $ready = '';
                vec($ready, fileno $told, 1) = 1;
                next unless select($ready, undef, undef, 1) > 0;
                sysread($told, $url, 4096, length $url) or last;
            }
            if ($url =~ s/\n\z// && length $url) {
                together_said($to, $url, $where, $most, $for);
            }
            curl_ended($CURL_SPARE);
            POSIX::_exit(0);
        }
        close $_ for $told, $to;
        push @FETCHERS, { pid => $pid, tell => $tell, from => $from, where => $where, key => ahead_key([undef, undef, $most, $for]) };
    }
    return;
}

sub fetcher_taken {                       # ($one): a copy that waits for this very request but its address is told it, and the request is begun; else nothing
    my ($one) = @_;
    my ($url, $where) = @{ $one->{job} };
    return if $url =~ /[\x00-\x20\x7f]/;
    my ($at) = grep { $FETCHERS[$_]{where} == $where && $FETCHERS[$_]{key} eq ahead_key($one->{job}) } 0 .. $#FETCHERS;
    defined $at or return;
    my $had = splice @FETCHERS, $at, 1;
    my $sent = syswrite($had->{tell}, "$url\n") // 0;
    close $had->{tell};
    if ($sent != length($url) + 1) { kill 'KILL', -$had->{pid}; kill 'KILL', $had->{pid}; waitpid $had->{pid}, 0; close $had->{from}; return }
    @$one{qw(pid from)} = @$had{qw(pid from)};
    return 1;
}

sub fetchers_dropped {                    # every copy that still waits is ended, with its curl
    for my $one (splice @FETCHERS) { kill 'KILL', -$one->{pid}; kill 'KILL', $one->{pid}; waitpid $one->{pid}, 0; close $_ for @$one{qw(tell from)} }
    return;
}

# Requests begun ahead of the run that names them. The answer of a page
# names its style sheets, and a sheet names its web fonts, before the
# application's run says so: on yle.fi each waited a run and then a
# connection, 110 ms of the first drawing (measured 2026-11-25). The moment
# the answer is here, the sheets it names on the page's own host are begun,
# and the moment the sheets are here, the fonts their @font-face rules name
# there, each the very request sub sheeted and sub fonted make, held to the
# same lists first, its lines in the log first. When the run then names it,
# sub fetched_together takes the one begun; one the run never names is ended
# with the visit, unread.                                           # [C14] [C30] [C5]
sub ahead_key { my ($job) = @_; join "\t", map { ref $_ ? "@$_" : $_ // '-' } @$job[2, 3] }    # what besides its address makes two such requests the same: its limits and what it is for

sub ahead_begin {                         # ($what, $page, $kept, [$url, $where, $most, $for], ...): each begun as sub fetched_together would, unless one is, or $PREFETCH_AT_ONCE are
    my ($what, $page, $kept, @jobs) = @_;
    open my $request, '>>', "$DIR/busy" or return;
    flock $request, LOCK_SH or return;    # as in visit: no line of these requests falls into a clearing of the log
    for my $job (@jobs) {
        next if $AHEAD{ $job->[0] };
        last if keys %AHEAD >= $PREFETCH_AT_ONCE;
        record("the page $page names the $what $job->[0]; lzrprf fetches it ahead, for when $APP asks for it", $kept) or return;    # [C5] written down first, connected second
        my $style = $job->[3] && $job->[3][0] eq 'style';    # a style sheet's own line, the one sub sheeted writes before it asks: written here, before this asks, and not again there
        if ($style) { record("$job->[0] -> lzrprf connects to the first that answers of: " . join(', ', map { $_->{text} } @{ $job->[1] }), $kept) or return }
        my $one = { job => $job, said => '', key => ahead_key($job), logged => $style ? 1 : 0 };
        together_started($one);
        $AHEAD{ $job->[0] } = $one if $one->{pid};
    }
    return;
}

sub ahead_sheets {                        # the style sheets the page's answer names on its own host, begun
    my ($url, $host, $got, $kept, $where) = @_;
    my $body = body_of($got) // return;
    $body =~ s{<(noscript|template)\b.*?</\1\s*>}{}gis;
    my (@jobs, %once);
    while ($body =~ /<link\b([^>]{0,2000})>/gi) {
        my $attributes = $1;
        next unless $attributes =~ /(?:^|\s)rel\s*=\s*["']?\s*stylesheet\s*["']?(?:\s|\/|\z)/i;
        my ($href) = $attributes =~ /(?:^|\s)href\s*=\s*(?:"([^"]{1,2000})"|'([^']{1,2000})'|([^\s"'>]{1,2000}))/i or next;
        $href = (grep { defined } $href, $2, $3)[0] // next;
        $href =~ s/&amp;/&/g;
        my ($to, $there) = address(resolved($url, $href)) or next;
        next if $there ne $host || $once{$to}++ || listed($to) || filter_said($to, 'stylesheet', $host);    # [C14] its own host alone; [C23] [C27] as sub sheeted holds it
        push @jobs, [$to, $where, undef, ['style', $host]];
        last if @jobs >= 8;
    }
    @AHEAD_SHEETS = map { $_->[0] } @jobs;
    timed("ahead-sheets $$ " . scalar @jobs) if $TIMED;
    ahead_begin('style sheet', $url, $kept, @jobs);
    fetchers_dropped();                   # a copy that waited for a sheet the answer does not name
    return;
}

sub ahead_fonts {                         # ($host, $where, $kept, [$sheet, $answer], ...): the web fonts the sheets' @font-face rules name on the page's own host, begun
    my ($host, $where, $kept, @sheets) = @_;
    prefetch_go('', $PREFETCH_NAMED->{page}, 'found') if $PREFETCH_NAMED && %FINDING;    # what the page names on other hosts, looked up since its answer came: begun now
    my (@jobs, %once);
    for my $sheet (@sheets) {
        my ($from, $answer) = @$sheet;
        my $at = index $answer, "\r\n\r\n";
        while ($at >= 0 && $answer =~ /\@font-face\s*\{([^{}]{1,4000})\}/gi) {
            my $rule = $1;
            next if $-[0] < $at;
            next if $rule =~ /unicode-range\s*:\s*([^;]{1,400})/i && $1 !~ /U\+0{0,4}(?:0|20)-0{0,2}(?:7[EF]|FF)\b/i;    # a face for other letters than a page's plain ones is asked for when it is needed
            my ($src) = $rule =~ /url\(\s*["']?([^"')\s]{1,2000}\.(?:woff2|woff|ttf|otf)(?:\?[^"')\s]{0,400})?)["']?\s*\)/i or next;
            my ($to, $there) = address(resolved($from, $src)) or next;
            next if $there ne $host || $once{$to}++ || listed($to) || filter_said($to, 'font', $host);    # [C30] its own origin alone; [C23] [C27] as sub fonted holds it
            push @jobs, [$to, $where, [$FONT_BYTES, $FONT_SECONDS], ['font', $host]];
            last if @jobs >= $FONTS;
        }
    }
    timed("ahead-fonts $$ " . scalar @jobs) if $TIMED;
    return ahead_begin('web font', "https://$host/", $kept, @jobs);
}
