# Pages kept running with their tabs (sub contained). Each is bound to the tab
# it was shown in; at most $LIVE_MOST run at once, and the oldest is ended
# when one more is kept. A page is ended, with "=end" and then for certain,
# when its tab goes elsewhere or is closed, when the sessions are cleared,
# when it was laid out anew, when it wrote anything out of its form, more than
# $LIVE_BYTES in all or more than $PAGE_BYTES in one answer, after
# $LIVE_SECONDS, and when the window closes. Its last good drawing stays.
sub live_of { my ($tab) = @_; my ($live) = grep { $_->{tab} && $_->{tab} == $tab } @LIVE; return $live }

sub live_kept {
    my ($live, $tab, $lines, $paths, $host, $decoded, $shown, $videos) = @_;
    $live->{raw} = [grep { !/^U/ } @$lines];    # the checked page before picture substitution, for later splices
    $live->{plain} = $shown == $lines;    # no picture in it: what is shown is what was checked (sub live_patched)
    my @made;                             # what the page is made of, the U lines of its first list: an answer is checked with them, as the first list was
    for (@$lines) { last unless /^U/; push @made, $_ }
    @$live{qw(tab made paths host pictures shown videos)} = ($tab, \@made, [@$paths], $host, $decoded // {}, $shown, [@{ $videos // [] }]);
    $live->{laid} = ($lines->[scalar @made] // '') =~ /^(L[0-9]+x[0-9]+)$/ ? $1 : '';    # [C18] the size it was laid at, when it was laid: a drawing of another height has its end somewhere else (sub live_answered)
    push @LIVE, $live;
    live_end($LIVE[0], 'more pages were kept running than lzrprf keeps') while @LIVE > $LIVE_MOST;
}

sub live_dropped {                        # a run that kept its page and is not shown: ended at once; the words, when there are any, are said
    my ($live, $words) = @_;
    live_end($live, 'it is not shown', 1) if $live;
    return defined $words ? idle($words) : undef;
}

sub live_told {                           # the window is told whether the page shown is kept running, and whether a text field of it has the focus: "live on|off 1|0"
    my $live = live_of($TABS[$TAB]);
    my @now = $TABS[$TAB]{trmnl} ? ('on', 1, 'trmnl') : $live ? ('on', $live->{focus} ? 1 : 0) : ('off', 0);    # [C29] a terminal's tab takes every key, and keys held with Control
    return if "@now" eq "@LIVE_TOLD";
    @LIVE_TOLD = @now;
    window("live @now");
}

sub live_end {                            # "=end" for the page, then its keeper and the page are ended, the keeper first (sub contained); $now: at once, and nothing said to the window
    my ($live, $why, $now) = @_;
    @LIVE = grep { $_ != $live } @LIVE;
    delete @$live{qw(unknown unknown_more)};    # what it counted of lines lzrprf does not know goes with it
    return if $live->{ended}++;
    my $gone = 0;
    syswrite($live->{relay}, "=end\n");    # never waited for: a page that reads nothing is ended below all the same
    close $live->{relay};
    my $until = now() + ($now ? 0 : $LIVE_END_SECONDS);
    while (!$gone && (my $left = $until - now()) > 0) {    # the page is given a moment to end by itself: its end is the end of what it writes. The window is never kept waiting for it: once the window says anything, the page is ended at once
        last if $FROM && index($FROM_HELD, "\n") >= 0;
        my $ready = '';
        vec($ready, fileno $live->{from}, 1) = 1;
        vec($ready, fileno $FROM, 1) = 1 if $FROM;
        select($ready, undef, undef, $left) > 0 or next;
        last if $FROM && vec($ready, fileno $FROM, 1) && !vec($ready, fileno $live->{from}, 1);
        next unless vec($ready, fileno $live->{from}, 1);
        my $more = sysread($live->{from}, my $rest, 65536);
        $gone = 1 if defined $more ? !$more : !$!{EINTR};
    }
    kill 'KILL', $live->{keeper};         # the keeper first: it acts on the page's number, and is gone before the system may give that number to another process
    waitpid $live->{keeper}, 0;
    kill 'KILL', $live->{page};
    waitpid $live->{page}, 0;
    close $_ for @$live{qw(from hold)};
    return if $now;
    window("live end $why; " . ($gone ? 'it ended by itself' : 'lzrprf ended it'));
    live_told();
}

sub live_read {                           # what a page kept running wrote, held until it is a whole answer; its end is noted
    my ($live) = @_;
    my $got = sysread($live->{from}, $live->{held}, 65536, length $live->{held});
    return if !defined $got && $!{EINTR};
    $live->{gone} = 1 unless $got;
    my $at = now();
    $live->{bytes} -= ($at - ($live->{bytes_at} // $at)) * $PAGE_BYTES;    # bounded drawing rate, not a character-count deadline
    $live->{bytes} = 0 if $live->{bytes} < 0;
    $live->{bytes_at} = $at;
    $live->{bytes} += $got // 0;
    $live->{heard} = now();
}

sub live_due {                            # a page kept running has a whole answer held (up to a line "=ready"), ended, wrote too much, or its time is over
    my ($live) = @_;
    return 1 if defined $live->{whole} || $live->{gone} || $live->{bytes} > $LIVE_BYTES || length $live->{held} > $PAGE_BYTES || now() >= $live->{until};
    if (defined(my $asked = live_asked($live))) { return $asked ? 1 : 0 }    # [C19] a request, due once it is all there
    if (substr($live->{held}, 0, 7) eq "=ready\n") { $live->{whole} = -1; return 1 }
    my $at = index($live->{held}, "\n=ready\n", $live->{looked} > 7 ? $live->{looked} - 7 : 0);
    $live->{looked} = length $live->{held};
    return 0 if $at < 0;
    $live->{whole} = $at;
    return 1;
}

sub live_turn {
    my @due = grep { live_due($_) } @LIVE;
    $_->{starting} ? home_arrived($_) : live_answered($_) for @due;
    live_scroll_told($_) for grep { (live_scroll_left($_) // 1) <= 0 } @LIVE;    # [C18] a place of the page's own scroll that waited for the frame to be over
}

# A request of a page kept running ([C19]). While it is kept, and while it is
# read before its first list (sub contained), the page may write, in place of
# an answer, one request at a time, and waits for its reply before it writes
# anything else (src/page/scripted.rs):
#
#   =fetch METHOD BODYLEN TYPE [DEST] URL   then exactly BODYLEN bytes of its body
#       METHOD   GET, HEAD or POST
#       BODYLEN  0 to $LIVE_FETCH_UP, and 0 for GET and HEAD
#       TYPE     "-", or for a POST one of text/plain,
#                application/x-www-form-urlencoded and application/json
#       DEST     what the answer is for: data, script, module, worker,
#                frame or image; a line without it is data, as before [C26]
#       URL      printable, at most 8192 bytes
#
# A script, module or worker of a site whose scripts are not allowed is not
# fetched at all, and one whose bytes a rule of yours denies is fetched,
# hashed and not handed over: both are told "=fetched 403 0 0" [C26]. A
# frame of such a site comes with its scripts taken out. A POST to another
# host than the page's asks you first, in lzrprf's strip, and while the page
# is read, before it is shown, it is refused: no script permission covers it
# [C5]. While the page runs in lzrprf's sandbox (E1: its site has no rule of
# yours, sub permit_site), a POST to any origin and every request to another
# origin that is not a script or module are refused with no question, told
# "=fetched 403 0 0", and never fetched or sent (@PERMIT_SANDBOX) [C26].
#
# The page may ask, the same way, whether a script may run [C26]:
#
#   =permit KIND ORIGIN SHA256 CAPS   answered "=permitted always", "once" or
#                                     "deny" at once (sub live_permitted)
#
# The address is checked as one typed into the bar is (sub address: https, a
# host by its name, port 443), the count of the page's requests against
# $LIVE_FETCH_MOST, then it is written down first [C5] and looked up or asked
# of Tor as a typed one [C17]; a host that is not on the public internet is
# refused, as for the fixed addresses, since no question is asked for a page.
# It is fetched by sub fetch, the one place that connects [C6], with the fixed
# request [C7] and only what $ask adds there. Whatever comes of it, the page
# is written exactly one reply, on its input, through the keeper:
#
#   =fetched STATUS HEADLEN BODYLEN  then HEADLEN bytes of "name: value" lines,
#                                    each ending in a line end, then BODYLEN
#                                    bytes of the body
#
# STATUS is the answer's, 200 to 599; the lines are only those of
# content-type and of the five access-control-allow-origin,
# -allow-credentials, -allow-methods, -allow-headers and -expose-headers,
# names in small letters, printable values, at most $LIVE_HEAD_BYTES in all;
# the body is the answer's, its chunks joined, at most $PAGE_BYTES; a HEAD has
# none. A request refused, failed, or answered in another form is told
# "=fetched 0 0 0". A request line of no form ends the page.
sub live_asked {                          # [C19] the request at the front of what the page wrote: nothing when there is none, 0 while it is not all there, else [its line, its body, the bytes it takes], or [its line] when it is of no form
    my ($live) = @_;
    my $permit = substr($live->{held}, 0, 8) eq '=permit ';    # [C26] a question whether a script may run: one line, no body
    if (substr($live->{held}, 0, 7) eq '=early ') {    # the page as it is before its scripts run: one line "=early BYTES", then that many bytes of a list, answered with nothing (sub live_early)
        my $end = index $live->{held}, "\n";
        return $end < 0 && length $live->{held} <= 32 ? 0 : [''] if $end < 0 || $end > 32;
        my ($size) = substr($live->{held}, 0, $end) =~ /^=early ([1-9][0-9]{0,7})\z/ or return [''];
        return [''] if $size > $PAGE_BYTES;
        return 0 if length($live->{held}) < $end + 1 + $size;
        return ['=early', substr($live->{held}, $end + 1, $size), $end + 1 + $size];
    }
    my $soon = substr($live->{held}, 0, 6) eq '=soon ';    # [C19] a request the page's script set going, told ahead: one line, no body, answered with nothing (sub prefetch_soon)
    return unless $permit || $soon || substr($live->{held}, 0, 7) eq '=fetch ';
    my $end = index $live->{held}, "\n";
    if ($end < 0 || $end > $LIVE_FETCH_LINE) { return $end < 0 && length $live->{held} <= $LIVE_FETCH_LINE ? 0 : [''] }
    my $line = substr($live->{held}, 0, $end);
    return [$line, '', $end + 1] if $permit || $soon;
    my ($size) = $line =~ /^=fetch [A-Z]{1,8} (0|[1-9][0-9]{0,5}) / or return [$line];
    return [$line] if $size > $LIVE_FETCH_UP;
    return 0 if length($live->{held}) < $end + 1 + $size;
    return [$line, substr($live->{held}, $end + 1, $size), $end + 1 + $size];
}

# The page before its scripts run. A run that has the network writes, once and
# before it reads its scripts, the list of the page as its markup and its
# style sheets alone lay it ("=early", the application's src/page/mod.rs).
# It is checked as every list is (sub checked) and drawn at once, with a grey
# box in the place of each picture, and nothing is fetched for it: what you
# read is on the screen while the page's scripts are fetched and run, and the
# run's own first list is drawn over it when it comes. Only on a visit, for
# the page being read, never a home, and once a run. Measured 2026-11-25 on
# yle.fi: its first list came 1.1 s after the address was typed, 0.9 s of
# that its scripts.
sub live_early {
    my ($live, $body) = @_;
    timed('early-here ' . length $body) if $TIMED;
    return if $live->{until} || $live->{home} || $live->{early}++ || $OUTRUN;
    my ($tally, $titled, @fonts) = ($LAID_TALLY, $TITLED, @FONTS_NAMED);    # what sub checked says again: this list is not the run's own
    my ($lines, $hosts, $paths) = checked($body);
    ($LAID_TALLY, $TITLED, @FONTS_NAMED) = ($tally, $titled, @fonts);
    timed('early-checked ' . ($lines ? scalar @$lines : 'unfit')) if $TIMED;
    return unless $lines && @$lines;
    my ($sent) = pictured($lines, $paths, $live->{host}, undef, undef, pictures_so_far($live->{host}));    # nothing is fetched for this one
    window("page $TAB", @$sent, '.');
    $DRAWN = 1;
    timed('list-early');
    prefetch_go('', $live->{url}, 'found') if $PREFETCH_NAMED && %FINDING;    # and what the page names on other hosts, looked up since its run began (sub prefetch_later): since release 101 that is after sub ahead_fonts, which began them before, so yle.fi's two fonts were asked for by the page first, one after the other, 200 ms its scripts waited (measured 2026-11-25); here and not before the list, where waiting for a name held the first drawing 20 ms
    pictures_ahead($lines, $paths, $live->{host}, $sent);    # its pictures begin now, while its scripts run
    return;
}

my %LIVE_PASSED = map { $_ => 1 } qw(content-type access-control-allow-origin access-control-allow-credentials access-control-allow-methods access-control-allow-headers access-control-expose-headers);    # [C19] the headers a page is handed of an answer: its type, and what the CORS check of its engine reads

sub live_fetched {                        # [C19]
    timed('live-asked') if $TIMED;
    pictures_pumped();
    my ($live, $asked) = @_;
    my ($line, $body, $took) = @$asked;
    return live_end($live, 'it wrote a line of no form') unless defined $took;
    substr($live->{held}, 0, $took, '');
    $live->{looked} = 0;
    return live_early($live, $body) if $line eq '=early';
    return live_permitted($live, $line) if substr($line, 0, 8) eq '=permit ';
    if (substr($line, 0, 6) eq '=soon ') { $line =~ m{^=soon (script|image|data) ([\x21-\x7e]{1,8192})$} or return live_end($live, 'it wrote a line of no form'); return prefetch_soon($live, $1, $2) }
    return live_replied($live, 0, '', '') if $live->{home};    # the local home has no network door, including absolute script requests    # [C26]
    my ($method, $size, $type, $dest, $as, $to) = $line =~ m{^=fetch (GET|HEAD|POST) (0|[1-9][0-9]{0,5}) (-|text/plain|application/x-www-form-urlencoded|application/json) (?:(data|script|module|worker|frame|image) )?(?:as ([a-z]{1,16}) )?([\x21-\x7e]{1,8192})$} or return live_end($live, 'it wrote a line of no form');
    return live_end($live, 'it wrote a line of no form') if $method ne 'POST' && ($size || $type ne '-');
    $dest //= 'data';                     # [C26] a line of an application from before the destination word
    return live_end($live, 'it wrote a line of no form') if defined $as && !identity_word($as);    # [C7] D19: an identity lzrprf holds no header set for is no request at all
    my ($url, $host) = address($to);
    my $filter = $url && !listed($to) ? filter_said($url, $FILTER_DEST{$dest}, $live->{host}) : undef;    # [C27] after [C23] and before the sandbox and every script permission: what a list blocks is never fetched, and decides nothing of [C26]
    my $site = "https://$live->{host}";
    my $code = $dest =~ /^(?:script|module|worker)$/;    # [C26] bytes that would run: hashed, and refused when the policy denies them
    my ($rules) = permit_rules();
    my $allowed = permit_site($site, $rules, $live->{url});    # [C26] "person", "sandbox" or nothing
    my $boxed = !$url || defined $filter || $allowed ne 'sandbox' ? '' : $method eq 'POST' ? 'post' : $host ne $live->{host} && $dest !~ /^(?:script|module)$/ ? 'fetch-other' : '';    # [C26] E1: what of the sandbox's table this request is, when the table refuses it
    $boxed = '' if $boxed && sandbox_says($boxed) ne 'refused';
    my $away = $url && !$boxed && !defined $filter && $method eq 'POST' && $host ne $live->{host};    # [C5] a POST to another host than the page's: never covered by a script permission
    my $sent = $away && $live->{until} ? ask("The page $live->{host} wants to send something to $host, another host. No script permission covers that. Send it this once?", "Don't send", 'Send') : 0;    # asked before the log is held, so a question left open keeps nothing waiting; a page that is still read, before it is shown, is not asked for
    my ($status, $head, $answer, $why) = (0, '', '');
    my ($kept) = keeping();               # read once, as in visit
    open my $request, '>>', "$DIR/busy" or return live_replied($live, 0, '', '');
    flock $request, LOCK_SH or return live_replied($live, 0, '', '');    # as in visit: no line of this request falls into a clearing of the log
    if (listed($to)) { refused("the page $live->{host} asked for an address", $kept); return live_replied($live, 0, '', '') }    # [C23] refused as an address lzrprf does not fetch is, with no address written
    if (!$url) {
        record("the page $live->{url} asked for an address lzrprf does not fetch; refused", $kept);
        return live_replied($live, 0, '', '');
    }
    if (defined $filter) { record("the page $live->{url} asked for $url; not fetched: $filter", $kept); return live_replied($live, 0, '', '') }    # [C27] nothing is looked up or fetched
    my $asked_for = "the page $live->{url} asked for $url ($method" . ($host eq $live->{host} ? '' : ", from $live->{host}") . ($dest eq 'data' ? '' : ", $dest") . ')';
    if ($boxed) {                         # [C26] E1: refused with no question, and never fetched or sent
        record("$asked_for; refused: the page runs in lzrprf's sandbox, which " . ($boxed eq 'post' ? 'sends no POST' : 'fetches nothing else of another origin'), $kept);
        permit_seen('e1', $site, ($boxed eq 'post' ? 'a POST to ' : 'a request to ') . "https://$host", 'refused');
        $PERMIT_ASK->{boxed}++ if $PERMIT_ASK && $PERMIT_ASK->{site} eq $site;
        return live_replied($live, 403, '', '');
    }
    if ($away && $sent != 2) {            # [C5]
        record("$asked_for; refused: " . ($live->{until} ? 'you did not let it send to another host' : 'a page that is still read is not let send to another host'), $kept);
        return live_replied($live, 0, '', '');
    }
    record("you let the page $live->{url} send to $host, this once", $kept) or return live_replied($live, 0, '', '') if $away;
    if ($code && !$allowed) {             # [C26] not fetched at all: the site's scripts do not run
        record("$asked_for; refused: the scripts of $live->{host} are not allowed", $kept);
        $PERMIT_ASK->{refused}++ if $PERMIT_ASK && $PERMIT_ASK->{site} eq $site && !($PERMIT_DENIED{$site} && $PERMIT_DENIED{$site}{''});
        return live_replied($live, 403, '', '');
    }
    record($asked_for, $kept) or return live_replied($live, 0, '', '');    # [C5] before the name is even looked up
    $why = "the page asked for more than $LIVE_FETCH_MOST addresses" if ++$live->{fetches} > $LIVE_FETCH_MOST;
    if (!$why) { my $shield = shield_said($url); $why = shield_why($shield) if $shield ne 'allow' }    # [C28] before any DNS lookup, including requests while a page is still being read
    my $where;
    my $sent_ask = { method => $method, type => $type, body => $body, origin => $host eq $live->{host} ? undef : "https://$live->{host}", cookie => scalar(sso_cookie($url, $live->{host})), top => $allowed eq 'sandbox' ? undef : $live->{url}, as => $as, dest => $dest, from => $live->{host} };
    prefetch_go($url, $live->{url}) if !$why && $dest =~ /^(?:script|module)$/;    # [C19] its first external script shows the page runs them: the others it names are fetched ahead now
    my @ahead = $why ? () : prefetch_take($url, $sent_ask, $live->{until});    # [C19] this very request, fetched ahead while the page was read (sub prefetch_begin): judged, looked up and written down before it was made
    timed(join q{ }, "asked $$", @ahead ? "ahead" : "now", $dest // "plain", $host eq $live->{host} ? "own" : "other", $url =~ m{([A-Za-z0-9.-]{1,24})\z}) if $TIMED;    # "lzrprf try" with "times": which of the page's requests were here already (scripts/load-timeline.pl)
    record("$url was fetched ahead for the page: " . ($ahead[1] ? "failed: $ahead[1]" : 'answered: ' . length($ahead[0]) . " bytes from $ahead[2]"), $kept) or return live_replied($live, 0, '', '') if @ahead;
    ($why, $where) = ($ahead[1], 1) if @ahead;
    ($where, $why) = $TOR_WANTED ? tor_where($host) : find($host) unless $why || @ahead;    # [C17] with Tor on, nothing is looked up on this computer
    $why = 'that host is not on the public internet' if !@ahead && !$why && $where && $PEER eq '-' && grep { $_->{own} } @$where;    # [C8] no question is asked for a page's request: it is refused
    my ($got, $from);
    ($got, $from) = @ahead[0, 2] if @ahead && !$why;
    if (!$why && !@ahead) {
        record("$url -> lzrprf connects " . ($TOR_WANTED ? "through Tor, one circuit for $host" : 'to the first that answers of: ' . join(', ', map { $_->{text} } @$where)), $kept) or return live_replied($live, 0, '', '');    # [C5] written down first, connected second
        ($got, $why, $from) = fetch($url, $where, { method => $method, type => $type, body => $body, origin => $host eq $live->{host} ? undef : "https://$live->{host}", cookie => scalar(sso_cookie($url, $live->{host})), top => $allowed eq 'sandbox' ? undef : $live->{url}, as => $as, dest => $dest, from => $live->{host} });    # [C6] [C7] cookies only of a provider you connected, and only from a page of that provider's own family (sub sso_cookie)
        prefetch_keep($url, $sent_ask, $got, $from) if !$why && $allowed eq 'sandbox' && !$live->{until};    # [C19] kept for the page's next layout in this visit, only while it is read
    }
    sso_heard($url, $got, $live->{host}) unless $why;    # [C7] as in visit, for a page of the provider's own family alone
    if (!$why) {
        my $parts = live_parts($got, $method);
        if ($parts) { ($status, $head, $answer) = @$parts } else { $why = 'the answer is in no form lzrprf hands a page' }
    }
    my $sha = !$why && $code ? Digest::SHA::sha256_hex($answer) : '';
    if (length $sha && permit_refused($site, $dest eq 'script' ? 'external' : $dest, "https://$host", $sha, $rules)) {    # [C26] the bytes themselves, whoever serves them
        record("$url answered $status: " . length($answer) . " bytes, not handed to the page: a rule of yours denies these bytes", $kept);
        return live_replied($live, 403, '', '');
    }
    if (length $sha) {                    # [C26] where these bytes came from, for a curated rule by path pattern (E2)
        %PERMIT_PATHS = () if keys %PERMIT_PATHS >= $PERMIT_RULES;
        $PERMIT_PATHS{"$site https://$host $sha"} = $url =~ m{\Ahttps://[^/?#]+(/[^?#]*)} ? $1 : '/';
        permit_info($site, "https://$host", $sha, $host . $PERMIT_PATHS{"$site https://$host $sha"}, 'external', $answer);    # [C26] its name and source, for the question about it
    }
    ($answer) = permit_body($answer) if !$why && $dest eq 'frame' && !$allowed;    # [C26] a frame of a site whose scripts are not allowed, with them taken out
    record("$url " . ($why ? "failed: $why" : "answered $status: " . length($answer) . " bytes to the page from $from"), $kept) or return live_replied($live, 0, '', '');    # an answer whose line could not be recorded is not handed over
    close $request;
    return live_replied($live, $why ? (0, '', '') : ($status, $head, $answer));
}

sub live_parts {                          # [C19] an answer as curl gave it raw: [status, the header lines the page is handed, the body]; nothing when it is in no such form
    my ($got, $method) = @_;
    1 while $got =~ s{\AHTTP/1\.[01] 1[0-9][0-9][^\r\n]*\r\n(?:[^\r\n]+\r\n)*\r\n}{};    # an interim answer goes before the answer
    my ($status, $head, $body) = $got =~ m{\AHTTP/1\.[01] ([2-5][0-9][0-9])[^\r\n]*\r\n((?:[^\r\n]+\r\n)*)\r\n(.*)\z}s or return;
    $body = '' if $method eq 'HEAD';
    $body = unchunked($body) // return if $head =~ /^transfer-encoding:[ \t]*chunked[ \t]*\r?$/mi && length $body;
    return if length $body > $PAGE_BYTES;
    my $lines = '';
    for (split /\r\n/, $head) {
        my ($name, $value) = /^([!#\$%&'*+.^_\x60|~0-9A-Za-z-]+):[ \t]*(.*?)[ \t]*$/ or next;    # a token (RFC 9110 5.6.2), its grave accent written as \x60
        $name = lc $name;
        next unless $LIVE_PASSED{$name} && $value =~ /^[\x20-\x7e]*$/;
        my $one = "$name: $value\n";
        last if length($lines) + length($one) > $LIVE_HEAD_BYTES;
        $lines .= $one;
    }
    return [$status, $lines, $body];
}

sub unchunked {                           # a body sent in chunks, its chunks joined; nothing when it is in no such form
    my ($body) = @_;
    my ($whole, $at) = ('', 0);
    while (1) {
        substr($body, $at) =~ /\A([0-9a-fA-F]{1,8})[^\r\n]*\r\n/ or return;
        my $n = hex $1;
        $at += length $&;
        last unless $n;
        return unless length($body) >= $at + $n + 2 && substr($body, $at + $n, 2) eq "\r\n";
        $whole .= substr($body, $at, $n);
        $at += $n + 2;
    }
    return $whole;
}

sub live_replied {                        # [C19] the one reply to a request, through the keeper as it takes it, within $FETCH_SECONDS; a page that does not take it is ended
    my ($live, $status, $head, $body) = @_;
    return live_sent($live, "=fetched $status " . length($head) . ' ' . length($body) . "\n$head$body");
}

sub live_sent {                           # [C19] a reply written to a page kept running, through the keeper as it takes it, within $FETCH_SECONDS; a page that does not take it is ended
    my ($live, $reply) = @_;
    $reply = (delete($live->{input_held}) // '') . $reply;    # an input tail always precedes a reply; never splice a reply into a partial input line
    my $until = now() + $FETCH_SECONDS;
    while (length $reply) {
        my $took = syswrite($live->{relay}, $reply);
        if ($took) { substr($reply, 0, $took, ''); next }
        return live_end($live, 'it does not read what it is given') unless !defined $took && ($!{EAGAIN} || $!{EINTR});
        my ($ready, $left) = ('', $until - now());
        return live_end($live, 'it does not read what it is given') if $left <= 0 || !alive();
        vec($ready, fileno $live->{relay}, 1) = 1;
        select(undef, $ready, undef, $left > 1 ? 1 : $left);
    }
    $live->{heard} = now();
    return;
}

