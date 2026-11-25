# The list. lzrprf never opens an address on the list of child sexual abuse
# material and other illegal content, and nothing it runs can get past it:
# every request of every page goes through lzrprf, which alone looks a name
# up, starts curl and asks Tor to connect. The list is one file, blocklist,
# beside lzrprf itself, read once when a window starts and held in memory. It
# holds digests and no address: of an onion address, the MD5 of its last two
# labels ("<56 characters>.onion"), as Ahmia publishes its list; of a host,
# the SHA-256 of its name in small letters; of an address, the SHA-256 of
# its host and path with its query, "host/path?query", without https://, the
# port or the part after #. So the file says no address to whoever reads it,
# and an address is matched here, on this computer, by computing its digests
# and looking them up: no address and no digest of one is sent anywhere.
# The file is plain text: its first line "lzrprf blocklist 2 form 2" (the
# layout, then the form of the addresses, $LIST_FORM), then lines "# " that
# say where its parts come from, then four parts in this order, each a line
# "onion-md5 N", "host-sha256 N", "url-sha256 N" or "query-sha256 N" and N
# digests in small hex letters, one a line, in increasing order and each
# once; query-sha256 holds "host/path" of each listed address with a query. A
# part of another length, a digest out of order or a line in another form is
# a damaged list. The application's release file names the list's SHA-256
# in a line "blocklist <sha256>", as it names lzrprf's, and a list that is
# another file is no list. Without a list that is held, lzrprf opens nothing:
# the window says why (sub behind), and "sub listed" says yes to everything.
# There is no setting, no variable and no button that changes any of it.  # [C23]
sub list_read {                           # [C23] true when the list is held: read now, the first time
    return 1 if $LIST_HELD;
    return 0 if defined $LIST_WHY;
    my $file = dirname($SELF) . '/blocklist';
    my $no = sub { $LIST_WHY = $_[0]; %LISTED = (); return 0 };
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return $no->(-l $file ? "$file is a link, and lzrprf reads its list from a plain file" : "$file is not there");
    my @is = stat $in;
    return $no->("$file is not a plain file") unless -f _;
    return $no->("$file is larger than lzrprf reads") if $is[7] > $LIST_BYTES;
    binmode $in;
    my $text = '';
    while (1) {
        my $got = sysread($in, $text, 1048576, length $text);
        return $no->("$file could not be read") unless defined $got;
        last unless $got;
        return $no->("$file is larger than lzrprf reads") if length $text > $LIST_BYTES;
    }
    close $in;
    if (length $PROGRAM) {               # a window: the list must be the one the application's release file names, when there is such a file (sub paired holds the rest of that file)
        my @lines = release_lines();
        my ($named) = map { /^blocklist ([0-9a-f]{64})$/ ? $1 : () } @lines;
        return $no->("the application's release file names no list, so lzrprf cannot tell that $file is the one installed with it") if !defined $named && (@lines || $PROGRAM =~ m{\.app/Contents/MacOS/});
        return $no->("$file is another file than the application's release file names") if defined $named && $named ne Digest::SHA::sha256_hex($text);
    }
    $text =~ s/\Alzrprf blocklist 2 form ([1-9][0-9]{0,3})\n(?:# [\x20-\x7e]{0,300}\n){0,100}// or return $no->("$file does not begin as a list of lzrprf");
    return $no->("$file was made for form $1 of the addresses, and this lzrprf matches form $LIST_FORM") if $1 != $LIST_FORM;
    my $count = 0;
    for my $part (['onion', 'onion-md5', 32], ['host', 'host-sha256', 64], ['url', 'url-sha256', 64], ['query', 'query-sha256', 64]) {
        my ($kind, $word, $hex) = @$part;
        $text =~ s/\A\Q$word\E (0|[1-9][0-9]{0,7})\n// or return $no->("$file has no part $word where it belongs");
        my $n = $1;
        my $digests = substr($text, 0, $n * ($hex + 1), '');
        return $no->("$file is cut short in its part $word") if length $digests != $n * ($hex + 1);
        return $no->("$file holds a line in its part $word that is no digest") unless $digests =~ /\A(?:[0-9a-f]{$hex}\n)*\z/;
        my $all = pack 'H*', $digests =~ tr/\n//dr;
        my $wide = $hex / 2;
        for my $at (1 .. $n - 1) { return $no->("$file holds its part $word out of order") unless substr($all, ($at - 1) * $wide, $wide) lt substr($all, $at * $wide, $wide) }
        $LISTED{$kind} = $all;
        $count += $n;
    }
    return $no->("$file holds more after its last part") if length $text;
    ($LIST_HELD, $LIST_COUNT) = (1, $count);
    return 1;
}

sub list_has {                            # [C23] whether one digest is in one part of the list: a search by halves of the sorted part, at most 21 steps for a million
    my ($kind, $digest) = @_;
    my $all = $LISTED{$kind} // return 0;
    my $wide = length $digest;
    my ($low, $high) = (0, int(length($all) / $wide));
    while ($low < $high) {
        my $mid = ($low + $high) >> 1;
        my $order = substr($all, $mid * $wide, $wide) cmp $digest;
        return 1 unless $order;
        if ($order < 0) { $low = $mid + 1 } else { $high = $mid }
    }
    return 0;
}

# The one form of an address the list's digests are made of (README, "The
# digests"), for hosts and addresses alike: the host in small letters, its
# %-escapes read and its dots at either end taken away; the path read
# segment by segment, a segment's ";" and what follows dropped, an escape of
# a letter, digit, "-", ".", "_" or "~" read, every other escape written in
# capitals and every other byte escaped in capitals ("%2F" and "%5C" stay
# escapes and never split a path), empty segments, "." and ".." taken away
# as a browser and a server take them, and a backslash read as "/"; the
# query split at "&" and ";", "+" read as a space, each part written the
# same way but with "=" kept, the empty ones and the repeated ones dropped
# and the rest in sorted order. So "/./a//b/../x;y/" is "/a/x", "%78" is
# "x", "/a b" is "/a%20b" and "?b=2&a=1&a=1" is "?a=1&b=2". An address too
# long to be read gives no host (undef), and sub listed refuses it. It is read loosely, as no address lzrprf fetches is (any
# scheme, a name and password before the host, a port), so whatever could
# stand for a listed address in front of you is held to the list. The same
# text is run by scripts/blocklist.pl of the application, so a list made
# from plain addresses and the matching here agree by construction.  # [C23]
sub url_form {
    my ($text) = @_;
    return unless defined $text;
    utf8::encode($text) if utf8::is_utf8($text);    # bytes, as they go on the wire
    $text =~ s/^[ \t\r\n]+|[ \t\r\n]+$//g;
    $text = "https:$text" if $text =~ m{^//};
    $text = "https://$text" unless $text =~ m{^[A-Za-z][A-Za-z0-9+.-]*:};
    my ($host, $path, $query) = $text =~ m{^[A-Za-z][A-Za-z0-9+.-]*://(?:[^/?#\@]*\@)?(\[[^\]]*\]|[^/?#:\@\\]*)(?::[^/?#\\]*)?([^?#]*)(?:\?([^#]*))?}s or return;
    $host =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    $host = lc $host;
    $host =~ s/^\.+|\.+$//g;
    return unless length $host;
    return (undef) unless length $host <= 1000 && length($path) + length($query // '') <= 8192;    # too long to be read: listed, never let past
    my $unreserved = join '', 'A' .. 'Z', 'a' .. 'z', '0' .. '9', '-._~';    # the bytes an address may carry plain or escaped with the same meaning (RFC 3986 2.3): written plain
    my $plain = sub {                     # one segment or query part: unreserved escapes read, every other escape and byte in capital %XX, and the bytes of $keep as they are
        my ($part, $keep) = @_;
        $part =~ s{%([0-9A-Fa-f]{2})|(.)}{my ($hex, $byte) = ($1, $2); my $char = defined $hex ? chr hex $hex : $byte; index($unreserved, $char) >= 0 || (!defined $hex && index($keep, $char) >= 0) ? $char : sprintf('%%%02X', ord $char)}gse;
        return $part;
    };
    my @path;
    for my $segment (split m{[/\\]}, $path) {
        $segment = $plain->($segment =~ s/;.*//sr, '');
        next if $segment eq '' || $segment eq '.';
        if ($segment eq '..') { pop @path; next }
        push @path, $segment;
    }
    my %seen;
    return ($host, '/' . join('/', @path), join('&', sort grep { length && !$seen{$_}++ } map { $plain->(s/\+/%20/gr, '=') } split /[&;]/, $query // ''));
}

# Whether an address is listed: what was typed, a bookmark, what a redirect
# names, the address of a picture, a style sheet, a video or of what a page
# asks for, or a host alone, in the form above. An onion address is held to
# the list by its last two labels, any other host by itself and by every
# name it stands under, and an address by its path with every choice of its
# query's parts (so a listed query with parts added or repeated is still
# listed; with more than $QUERY_SUBSETS parts, a path that has any listed
# query is refused whole; the choices are tried only on a path the query
# part names, so any other address costs one search), then by that path and every path above it down to
# the first segment without one: a listed page is listed with whatever is put
# after it. "host/" listed blocks that one page; a whole host is blocked by
# the host part. An address too long to be read is listed. While no list is
# held, every address is.                                                 # [C23]
my %LISTED_SAID;                          # [C23] what sub listed said of each text since the list was read: the list never changes while it is held, so a page that names one address a thousand times costs one match
sub listed_said { %LISTED_SAID = () if $_[0]; return scalar keys %LISTED_SAID }    # [C17] how many texts it holds what sub listed said of; a true argument empties it first (a Tor window's end, sub tor_session_end)
sub listed {
    my ($text) = @_;
    return 1 unless list_read();
    return 0 unless $LIST_COUNT && defined $text;
    %LISTED_SAID = () if keys %LISTED_SAID >= 4096;    # held small: a page of many addresses starts the memory afresh
    return listed_now($text) if length $text > 2100;    # a text longer than any address lzrprf fetches is matched each time and not kept: the memory holds at most 4096 texts of 2100 bytes
    return $LISTED_SAID{$text} //= listed_now($text);
}
sub listed_now {                          # [C23] the match itself, for sub listed
    my ($text) = @_;
    my ($host, $path, $query) = url_form($text) or return 0;
    return 1 unless defined $host;        # too long to be read in the form of the list: refused rather than let past
    my @labels = split /\./, $host;
    return 1 if @labels >= 2 && $labels[-1] eq 'onion' && list_has(onion => Digest::MD5::md5("$labels[-2].onion"));    # an onion address and every name under it
    for my $at (0 .. ($#labels > 1 ? $#labels - 1 : 0)) { return 1 if list_has(host => Digest::SHA::sha256(join '.', @labels[$at .. $#labels])) }    # the host, and every name it stands under but the last label alone
    if (length $query) {
        return 1 if list_has(url => Digest::SHA::sha256("$host$path?$query"));    # the query as it is
        if (list_has(query => Digest::SHA::sha256("$host$path"))) {    # only a path that has a listed query is tried further: one search for every other address
            my @parts = split /&/, $query;
            return 1 if @parts > $QUERY_SUBSETS;    # too many parts to try each choice: refused whole
            for my $choice (1 .. (1 << @parts) - 2) { return 1 if list_has(url => Digest::SHA::sha256("$host$path?" . join '&', @parts[grep { $choice >> $_ & 1 } 0 .. $#parts])) }    # every other choice of the parts, in their sorted order
        }
    }
    return 1 if list_has(url => Digest::SHA::sha256("$host$path"));
    my @segments = split m{/}, substr($path, 1);
    for my $n (reverse 1 .. ($#segments < 64 ? $#segments : 64)) { return 1 if list_has(url => Digest::SHA::sha256("$host/" . join('/', @segments[0 .. $n - 1]))) }    # every path above it down to its first segment, of a longer one the 64 nearest the host: "host/" alone is never a parent
    return 0;
}

# A line for the log, or for this window's lines in memory, that names no
# listed address: one that does is given as the sentence of a refusal, whole,
# and nothing of the line it stood for is kept. Each word of it that could be
# a host or an address is held to the list. This is the last of the checks:
# every place that refuses a listed address does so before it writes a line,
# and this one holds should a line ever be written otherwise.            # [C23]
sub unlisted {
    my ($line) = @_;
    return $line unless $LIST_HELD && $LIST_COUNT;    # a list of nothing names nothing; with no list held nothing is fetched or written for a page
    for my $word ($line =~ m{([A-Za-z][A-Za-z0-9+.-]*://[^\s"'<>]+|[A-Za-z0-9%_-]+(?:\.[A-Za-z0-9%_-]+)+)}g) {
        return "an address on the list was named here, and is not written: $REFUSED" if listed($word);
    }
    return $line;
}

sub refused {                             # [C23] a listed address refused: the sentence, in the log with no address, and the words for the window after it; $what says what it was, in words that name no address
    my ($what, $kept) = @_;
    record((defined $what ? "$what: " : '') . $REFUSED, $kept) or return;
    return "$REFUSED $REFUSED_HELP";
}

sub barred {                              # [C23] a visit to a listed address: the tab is left showing no address and no page, nothing of it is kept in the tab or its history, and the window says why
    my $tab = $TABS[$TAB];
    live_end($_, 'its tab went elsewhere') for grep { $_->{tab} && $_->{tab} == $tab } @LIVE;
    @$tab{qw(url title secure)} = ('', '', undef);
    window('address ', "title $TAB ", "page $TAB", '.', 'secure none');
    nav_told();
    my $says = refused(undef) // return idle($UNWRITTEN);
    return idle($says);
}

# LZRDFNDR's blocked page [C28]. The application judges every page against LZRDFNDR's lists
# (lzrbrwsr src/page/shield.rs) before it reads any of it, and for a page they block it writes one
# line and nothing else: "=flagged", the confidence, the list's name, the category in words and the
# address with only its host and path, each checked here to its form and length. The detection is
# the application's; lzrprf holds no list of it and passes only this line on. Nothing of the page
# is drawn and none of it runs: the window shows a red page of its own over the whole page, with
# two buttons, Close the Tab, the first and the answer when the time is over, and Report False
# Positive Anonymously. There is no button that shows the page. A report is shown whole before it
# is sent and is sent only on Send: the category, the list, the confidence and the host and path,
# and nothing else; it goes to the address the release file names in a line "flagreport", through
# Tor when Tor is on, and not at all when Tor is on and not connected. Either way the tab closes.
sub flag_of {                             # [C28] a =flagged line in its one form: {confidence, list, category, context}; else nothing
    my ($wrote) = @_;
    my ($confidence, $list, $category, $context) = $wrote =~ /\A=flagged (high|medium) ([a-z0-9-]{1,40})\t([a-z ,-]{1,80})\t([\x21-\x7e]{1,300})\n\z/ or return;
    return { confidence => $confidence, list => $list, category => $category, context => $context };
}

sub flagged_by {                          # [C28] the run's =flagged line checked and kept: 'flagged', or 'unfit' for a line out of its form
    $FLAGGED = flag_of($_[0]) // return 'unfit';
    return 'flagged';
}

# Before anything is sent [C28]. An address is judged by LZRDFNDR before lzrprf looks its name up or
# fetches it: a page you visit, a picture, a style sheet, a video and each part of a stream, and what
# a page kept running asks for. lzrprf hands the application the addresses alone, one a line, in a
# run of its own in the page container (LZRPRF_JUDGE=1, at most 64 a run), and reads one line back
# for each: "=allow", or the =flagged line, held to its form, for an address its lists block, or
# "=unfit". A block sends nothing to that site; neither does an answer in no form, a run that did
# not end well, or an address not judged. The application's lists stay its own: what lzrprf learns
# is the verdict alone. The fixed addresses of the release file are the maker's and are not asked.
sub shield_asked {                        # [C28] each address not judged yet in this window, asked of the application in runs of at most 64
    return if $SHIELD_CHILD;              # a picture child keeps exactly the verdicts inherited from its parent
    my $today = int(time / 86400);
    %SHIELD_SAID = () if $today != $SHIELD_DAY || keys(%SHIELD_SAID) + @_ > $SHIELD_CACHE;
    $SHIELD_DAY = $today;
    my %once;
    my @new = grep { defined && !exists $SHIELD_SAID{$_} && !$once{$_}++ } @_;
    splice @new, $SHIELD_CACHE if @new > $SHIELD_CACHE;    # a later fetch asks again for an uncached address
    return unless @new;
    my $read_asked = $READ_ASKED;         # a judging run is not the page whose script request is being read
    while (my @these = splice @new, 0, 64) {
        my ($wrote) = contained($these[0], join('', map { "$_\n" } @these), undef, 0, 'judge');
        my @said = split /(?<=\n)/, $wrote // '';
        next unless @said == @these && !grep { $_ ne "=allow\n" && $_ ne "=unfit\n" && !flag_of($_) } @said;    # all in their form, or none is taken
        $SHIELD_SAID{$these[$_]} = $said[$_] for 0 .. $#these;
    }
    $READ_ASKED = $read_asked;
    return;
}

sub shield_said {                         # [C28] what LZRDFNDR said of one address, asked first if it was not: 'allow', 'flagged' (and $FLAGGED is what it said), or 'unjudged'
    my ($url) = @_;
    shield_asked($url);
    my $said = $SHIELD_SAID{$url} // return 'unjudged';
    return 'allow' if $said eq "=allow\n";
    return 'unjudged' unless flag_of($said);
    flagged_by($said);
    return 'flagged';
}

sub shield_why {                          # [C28] why nothing was sent, for the log and the bar
    my ($said) = @_;
    return $said eq 'flagged' ? "LZRDFNDR blocked it as $FLAGGED->{category}, by its list $FLAGGED->{list} ($FLAGGED->{confidence} confidence); nothing was sent to that site" : 'LZRDFNDR could not judge the address, so nothing was sent to that site';
}

sub flag_shown {                          # [C28] the red page for the page blocked, then the tab closes
    my ($url) = @_;
    my $flag = $FLAGGED;
    window("page $TAB", '.');             # the tab's page is emptied: nothing of the blocked page is drawn, before or after
    $DRAWN = 0;
    $TABS[$TAB]{title} = 'Content flagged';
    window("title $TAB Content flagged");
    record("$url was not shown: LZRDFNDR blocked it as $flag->{category}, by its list $flag->{list} ($flag->{confidence} confidence)") or return idle($UNWRITTEN);
    my $press = asked("flagged $flag->{category}", 'Close the Tab', 'Report False Positive Anonymously');
    flag_report($flag) if $press == 2;
    $FLAGGED = undef;
    tabbed('close', $TAB);
    return;
}

sub flag_door {                           # [C28] where a report of a wrong block goes: the release file's "flagreport" address, a plain path, or nothing
    my ($line) = map { /^flagreport (https:\/\/\S+)$/ ? $1 : () } release_lines();
    my ($url, $host) = address($line // '');
    return unless $url && $url eq $line && $url =~ m{^https://[^/?#]+(?:/[A-Za-z0-9_-]+)+$};
    return ($url, $host);
}

sub flag_report {                         # [C28] the report previewed whole, and sent only on Send
    my ($flag) = @_;
    my ($url, $host) = flag_door() or return idle('This release names no address for reports of a wrong block, so nothing was sent.');
    return idle('Tor is on and not connected, so the report was not sent: from a Tor window it goes through Tor or not at all.') if ($TOR_WANTED || $TOR_SESSION) && !($TOR && $TOR->{port});
    my $body = "lzrdfndr report 1\ncategory $flag->{category}\nlist $flag->{list}\nconfidence $flag->{confidence}\ncontext $flag->{context}\n";
    return idle('Nothing was sent.') unless asked(join("\t", "flagreport $flag->{category}", @$flag{qw(list confidence context)}, $host . ($TOR_WANTED ? ' through Tor' : '')), 'Cancel', 'Send') == 2;
    busy("Sending the report to $host.");
    my $got = fixed("you sent a report of a wrong block: $flag->{category}, $flag->{list}, $flag->{context}: $url", $url, $host, { method => 'POST', body => $body, type => 'text/plain' });
    return idle($UNSAID ? 'lzrprf tried to send the report. Whether it arrived is not shown: the line that says how it ended could not be written to the log.' : 'The report could not be sent. The log says why.') unless defined $got;
    my ($status) = @{ live_parts($got, 'POST') // [] };
    return idle(($status // '') eq '204' ? 'The report was sent, with nothing that names you.' : 'The report address did not take it' . (($status // '') eq '429' ? ': too many reports reached it just now.' : '.'));
}
