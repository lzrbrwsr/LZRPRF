# The filter lists [C27] (docs/filters.md). uBlock Origin's
# uAssets lists, kept byte for byte in lzrprf's repository in filters/ubo/
# under their own licence (GPL-3.0), and lzrprf's own reviewed exceptions,
# filters/local-exceptions.txt, reach a computer as files beside lzrprf that
# the release's signed manifest names, each on its own line: "ubo-NAME.txt"
# for a list, "ubo-SOURCE" for the record of where they came from, and
# "filters-local.txt". lzrprf reads them only when the manifest is in its one
# form, its approval and its signature hold, it is of the application's
# release, and every list beside lzrprf is the file it names by SHA-256: as
# for the curated rules, and checked by the same subs. Anything else, and
# nothing is filtered; Filters in the cogwheel's menu says why. lzrprf is a
# generic interpreter of the published filter syntax: it reads the lists as
# data, holds no code of uBlock Origin, and does what this part says with
# each line, nothing else:
#   - a network rule (an address pattern with ||, |, ^ and *, and the options
#     of a type, of party, $domain= and $important) blocks a request it
#     matches, and an exception (@@) matches the same way and means only that
#     the request is not blocked. A blocking rule with $important wins over
#     an exception without it;
#   - every other line is counted by its kind and never used: cosmetic rules
#     (lzrprf has no place of its own to give a page styles: the =sheets
#     frame carries only the page's own sheets), scriptlets (+js) and other
#     code, procedural and HTML rules, regular expressions, $redirect,
#     $removeparam, $csp and every option lzrprf does not read, conditional
#     parts (!#if) and the lines in them, and a line that looks like a
#     permission (a line of the scripts file, of scriptlayers or of a curated
#     rule, or an option that names one), which no filter line can be.
# A request is held to the lists after [C23] and before [C26], before any
# name is looked up; a request a filter blocks is never fetched, and nothing
# a filter decides changes what [C26] decides about a script. The rules are
# indexed when the lists are read, once a window: a rule anchored at a whole
# host by that host, any other by its longest token that a request's address
# must hold, and the few with no such token are read for every request.
sub filters {                             # [C27] the filter lists, read and checked once a window: {lists => [{name, rules, counts}], host => {HOST => [entry]}, token => {TOKEN => [entry]}, loose => [entry], counts => {KIND => N}, commit, ms, why => why nothing is filtered}
    return $FILTERS if $FILTERS;
    my $began = now();
    $FILTERS = filter_empty();
    my $no = sub { my $why = $_[0]; $FILTERS = filter_empty(); $FILTERS->{why} = $why; return $FILTERS };
    my %text;
    for my $name ('release.manifest', 'release.manifest.sig', 'release.manifest.approval') {
        my ($got, $why) = beside_read($name, $name eq 'release.manifest' ? $MANIFEST_MOST : $SIGNATURE_MOST);
        return $no->("$why, so nothing is filtered") unless defined $got;
        $text{$name} = $got;
    }
    my ($manifest, $why) = manifest_read($text{'release.manifest'});
    return $no->("release.manifest: $why, so nothing is filtered") unless $manifest;
    my @named = sort grep { /\Aubo-[a-z0-9][a-z0-9.-]{0,47}\.txt\z/ || $_ eq 'filters-local.txt' } keys %{ $manifest->{files} };
    return $no->('the signed manifest names no filter list, so nothing is filtered') unless @named;
    return $no->("the signed manifest names more than $FILTER_LISTS filter lists, so nothing is filtered") if @named > $FILTER_LISTS;
    return $no->('the manifest is not approved with an approval key lzrprf carries, so nothing is filtered') unless signature_holds($text{'release.manifest'}, $text{'release.manifest.approval'}, $APPROVAL_NAMESPACE, 'ECDSA', approval_keys());
    return $no->('the signature of the manifest does not hold for the release key lzrprf carries, so nothing is filtered') unless signature_holds($text{'release.manifest'}, $text{'release.manifest.sig'}, $RELEASE_NAMESPACE, 'ED25519', release_key());
    my ($release) = beside();
    return $no->('the application\'s release file names no release, so lzrprf cannot tell the manifest is of this one, and nothing is filtered') if !defined $release && (release_lines() || $PROGRAM =~ m{\.app/Contents/MacOS/});
    return $no->("the manifest is of release $manifest->{release}, and the application is release $release, so nothing is filtered") if defined $release && $release != $manifest->{release};
    for my $name (@named, exists $manifest->{files}{'ubo-SOURCE'} ? 'ubo-SOURCE' : ()) {
        my ($got, $unread) = beside_read($name, $FILTER_BYTES);
        return $no->("$unread, so nothing is filtered") unless defined $got;
        return $no->("$name is another file than the signed manifest names, so nothing is filtered") unless Digest::SHA::sha256_hex($got) eq $manifest->{files}{$name};
        $text{$name} = $got;
    }
    ($FILTERS->{commit}) = ($text{'ubo-SOURCE'} // '') =~ /^commit ([0-9a-f]{40})$/m;
    filter_list_read($_, $text{$_}) for @named;
    $FILTERS->{ms} = int((now() - $began) * 1000);
    return $FILTERS;
}

sub filter_empty { return { lists => [], host => {}, token => {}, loose => [], parsed => {}, counts => {}, commit => undef, ms => 0, why => '' } }    # [C27] lists that filter nothing

sub beside_read {                         # [C25] one file beside lzrprf, of at most $most bytes, a plain file of yours: its bytes, or nothing and why
    my ($name, $most) = @_;
    my $file = "$ROOT/$name";
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return (undef, -l $file || -e $file ? "$file is not a plain file of yours" : "there is no $name beside lzrprf");
    my @is = stat $in;
    return (undef, "$file is not a plain file of yours") unless @is && -f _ && $is[3] == 1 && $is[4] == $<;
    return (undef, "$file is larger than lzrprf reads") if $is[7] > $most;
    my $got = '';
    while (1) { my $n = sysread($in, $got, 65536, length $got); return (undef, "$file could not be read") unless defined $n; last unless $n; return (undef, "$file is larger than lzrprf reads") if length $got > $most }
    return ($got);
}

sub filter_list_read {                    # [C27] one list, each line read once: a network rule or exception indexed, every other line counted by its kind (see above)
    my ($name, $text) = @_;
    my $k = @{ $FILTERS->{lists} };
    my %counts;
    push @{ $FILTERS->{lists} }, { name => $name, counts => \%counts };
    my $depth = 0;                        # inside a conditional part (!#if), whose condition lzrprf does not weigh: its lines are not used, on either side of its !#else
    for my $line (split /\n/, $text) {
        $line =~ s/[ \t\r]+\z//;
        next if $line eq '' || $line =~ /\A\[/;    # a header such as [Adblock Plus 2.0]
        if (substr($line, 0, 1) eq '!') {
            if ($line =~ /\A!#if\b/) { $depth++ } elsif ($line =~ /\A!#endif\b/) { $depth-- if $depth } elsif ($line =~ /\A!#include\b/) { $counts{include}++ }
            next;                         # a comment
        }
        next if $line =~ /\A#(?: |\z)/;   # a comment in the form of a hosts file
        if ($depth) { $counts{conditional}++; next }
        my ($kind, $entry, $key) = filter_line($line);
        $counts{$kind}++;
        next unless defined $entry;
        $entry = "$k $entry";
        if ($key =~ s/\Ah://) { push @{ $FILTERS->{host}{$key} }, $entry }
        elsif ($key =~ s/\At://) { push @{ $FILTERS->{token}{$key} }, $entry }
        else { push @{ $FILTERS->{loose} }, $entry }
    }
    $FILTERS->{counts}{$_} += $counts{$_} for keys %counts;
    return;
}

my %FILTER_TYPE = (script => 'script', image => 'image', stylesheet => 'stylesheet', css => 'stylesheet', font => 'font', media => 'media', subdocument => 'subdocument', frame => 'subdocument', xmlhttprequest => 'xmlhttprequest', xhr => 'xmlhttprequest', websocket => 'websocket', other => 'other');    # [C27] the types of request an option may name, by each name the syntax gives them
my %FILTER_PERMITS = map { $_ => 1 } qw(permit permits permitted permissions allow allowed allow-script run exec execute grant trusted caps capabilities always);    # [C27] option names that would read as a permission: a line that carries one is refused, never used
my %FILTER_SKIPPED = (redirect => 'redirect', 'redirect-rule' => 'redirect', rewrite => 'redirect', removeparam => 'removeparam', queryprune => 'removeparam', csp => 'csp');    # [C27] options lzrprf does not do, each counted by its own kind

sub filter_line {                         # [C27] one line of a list: its kind, and for a network rule or exception the entry kept and its index key ("h:HOST", "t:TOKEN" or "" for none)
    my ($line) = @_;
    return 'permission' if $line =~ /\A(?:always|deny)\t|\Alzrprf permit|\A(?:e1 off|curated off\t)|\A(?:rule|end)\z|\A(?:site|script-origin|script|class|caps|justification|source|reviewer|reviewed) [^#\$]/i;    # [C27] a line of the scripts file, of scriptlayers or of a curated rule: no permission is read from a filter list
    if ($line =~ /\A([^\/\$|^@#\s]*)(#@?[?\$%]?#)(.*)\z/) {    # a cosmetic rule, or code, after its hosts
        my ($sep, $rest) = ($2, $3);
        return index($sep, '%') >= 0 || $rest =~ /\A\+js\(/ ? 'scriptlet' : $rest =~ /\A\^/ ? 'html' : index($sep, '?') >= 0 ? 'procedural' : index($sep, '$') >= 0 ? 'style'
            : $rest =~ /:(?:has-text|has|xpath|matches-css(?:-before|-after)?|matches-attr|matches-path|matches-media|matches-prop|min-text-length|others|remove|remove-attr|remove-class|style|upward|watch-attr|-abp-[a-z-]+)\(/ ? 'procedural' : 'cosmetic';
    }
    $line = "||$2^" if $line =~ /\A(?:0\.0\.0\.0|127\.0\.0\.1)([ \t]+)([A-Za-z0-9.-]+)\z/;    # a line of a hosts file: its host
    my $except = $line =~ s/\A@@//;
    my ($pattern, $options) = filter_split($line);
    my $kind = $except ? 'exception' : 'network';
    return 'unsupported' if $pattern =~ /\s/;
    for my $option (length $options ? split(/,/, $options) : ()) {
        my ($word, $value) = $option =~ /\A~?([a-z0-9_-]+)(?:=(.*))?\z/i or return 'unsupported';
        $word = lc $word;
        return 'permission' if $FILTER_PERMITS{$word};
        return $FILTER_SKIPPED{$word} if $FILTER_SKIPPED{$word};
        next if $FILTER_TYPE{$word} || $word =~ /\A(?:all|third-party|3p|first-party|1p|important|match-case)\z/;
        return 'document' if $word =~ /\A(?:doc|document|popup|popunder)\z/;    # a page you open, not a request of one: lzrprf does not filter what you open
        next if ($word eq 'domain' || $word eq 'from') && defined $value && $value =~ /\A~?[a-z0-9.-]+(?:\|~?[a-z0-9.-]+)*\z/i;
        $FILTERS->{options}{$word}++;
        return 'unsupported';             # a type lzrprf never asks for ($ping, $object), a part of a page ($ghide, $elemhide), $badfilter, a domain by a pattern, and every other option
    }
    return 'regex' if $pattern =~ m{\A/.+/\z};    # a regular expression: not matched, rather than matched in a way lzrprf cannot hold fast and safe
    return 'unsupported' if $pattern eq '' || $pattern eq '*' || $pattern !~ /\A[\x21-\x7e]+\z/;
    my $p = lc $pattern;
    $p = "||$p^" if $p =~ /\A[a-z0-9-]+(?:\.[a-z0-9-]+)+\z/ && $p =~ /[a-z]/ && $p !~ /\A[0-9.]+\z/;    # a host alone, as a hosts file names one
    my $entry = ($except ? '@@' : '') . ($p eq lc $pattern ? $pattern : $p) . (length $options ? "\$$options" : '');
    return ($kind, $entry, "h:$1") if $p =~ /\A\|\|([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?=[\^\/:]|\z)/;    # anchored at a whole host
    return ($kind, $entry, filter_token($p));
}

sub filter_split { return $_[0] =~ /\A(.*)\$(~?[A-Za-z0-9_-]+(?:[=,].*)?)\z/s ? ($1, $2) : ($_[0], '') }    # [C27] a rule's pattern and its options, after its last "$" that begins an option: a "$" inside a value or a pattern is no start of options

sub filter_token {                        # [C27] the index key of a pattern that names no whole host: its longest token that a matching address must hold whole, or "" when it has none
    my ($p) = @_;
    my ($best, $at) = ('', 0);
    while ($p =~ /([a-z0-9]+)/g) {
        my ($token, $from, $to) = ($1, $-[1], $+[1]);
        my $before = $from ? substr($p, $from - 1, 1) : '';
        my $after = $to < length $p ? substr($p, $to, 1) : '';
        my $left = $from == 0 ? 0 : $before eq '*' ? 0 : $before eq '|' ? ($from == 1 || substr($p, 0, 2) eq '||' && $from == 2) : 1;
        my $right = $after eq '' ? 0 : $after eq '*' ? 0 : $after eq '|' ? $to == length($p) - 1 : 1;
        next unless $left && $right && length $token >= 2;
        my $score = $token =~ /\A(?:https?|www|com|net|org|js|html?|php|png|gif|jpe?g)\z/ ? 1 : length $token;    # a token nearly every address holds narrows nothing
        ($best, $at) = ($token, $score) if $score > $at;
    }
    return length $best ? "t:$best" : '';
}

sub filter_rule {                         # [C27] an entry made into what a request is held to, once: {x => an exception, imp, types, not, party, on, off, host => a whole host and nothing else, re}; or nothing for an entry no request matches
    my ($entry) = @_;
    my $parsed = $FILTERS->{parsed};
    return $parsed->{$entry} if exists $parsed->{$entry};
    my ($line) = $entry =~ /\A[0-9]+ (.*)\z/s;
    my %r = (x => $line =~ s/\A@@// ? 1 : 0, party => '');
    my ($pattern, $options) = filter_split($line);
    my $case = 0;
    for my $option (length $options ? split(/,/, $options) : ()) {
        my ($not, $word, $value) = $option =~ /\A(~?)([a-z0-9_-]+)(?:=(.*))?\z/i;
        $word = lc $word;
        if ($FILTER_TYPE{$word}) { $not ? ($r{not}{ $FILTER_TYPE{$word} } = 1) : ($r{types}{ $FILTER_TYPE{$word} } = 1) }
        elsif ($word eq 'third-party' || $word eq '3p') { $r{party} = $not ? '1p' : '3p' }
        elsif ($word eq 'first-party' || $word eq '1p') { $r{party} = $not ? '3p' : '1p' }
        elsif ($word eq 'all') { }       # every type: as no type named
        elsif ($word eq 'important') { $r{imp} = 1 }
        elsif ($word eq 'match-case') { $case = 1 }
        elsif ($word eq 'domain' || $word eq 'from') { for (split /\|/, lc $value) { s/\A~// ? ($r{off}{$_} = 1) : ($r{on}{$_} = 1) } }
        else { return $parsed->{$entry} = undef }
    }
    if (!$case && $pattern =~ /\A\|\|([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)\^?\z/i) { $r{host} = 1 }    # ||HOST or ||HOST^: the host index found it, nothing more to match
    else {
        my $re = join '', map { $_ eq '*' ? '.*' : $_ eq '^' ? '(?:[^A-Za-z0-9_.%-]|\z)' : quotemeta } $pattern =~ /(\*|\^|[^*^]+)/g;
        $re =~ s/\A\\\|\\\|/\\A[a-z][a-z0-9+.-]*:\/\/(?:[^\/?#]*\\.)?/ or $re =~ s/\A\\\|/\\A/;
        $re =~ s/\\\|\z/\\z/;
        $r{re} = eval { $case ? qr/$re/ : qr/$re/i } // return $parsed->{$entry} = undef;
    }
    return $parsed->{$entry} = \%r;
}

sub filter_party { my @labels = split /\./, $_[0]; return $_[0] if @labels <= 2; my $n = length $labels[-1] == 2 && $labels[-2] =~ /\A(?:co|com|net|org|gov|edu|ac|or|ne|go|nic|ltd|plc|sch)\z/ ? 3 : 2; return join '.', @labels[-$n .. -1] }    # [C27] the site a host belongs to, for first and third party: its last two labels, or three under a country's own second level (co.uk); no list of public suffixes is held

sub filter_up { my ($host) = @_; my @up = ($host); push @up, $host while $host =~ s/\A[^.]*\.(?=.)//; return @up }    # [C27] a host and every name it stands under: a.b.example.com, b.example.com, example.com, com

sub filtered {                            # [C27] what the lists say of one request of a page: (the entry that blocks it, or nothing; the exception that matched, or nothing). TYPE is one of %FILTER_TYPE's; the page is its host
    my ($url, $type, $page) = @_;
    my $f = filters();
    return if length $f->{why};
    my ($host) = $url =~ m{\Ahttps?://([^/?#:]+)}i or return;
    $host = lc $host;
    $page = lc($page // '');
    my $layers = filter_layers();
    return if $layers->{allow}{"https://$page\t$host"};
    my $lower = lc $url;
    my $third = filter_party($host) ne filter_party($page);
    my @pages = filter_up($page);
    my (%seen, $block, $vital, $except, $vital_except);
    my %token = map { $_ => 1 } $lower =~ /[a-z0-9]+/g;
    for my $entry (map({ @{ $f->{host}{$_} // [] } } filter_up($host)), map({ @{ $f->{token}{$_} // [] } } keys %token), @{ $f->{loose} }) {
        next if $seen{$entry}++;
        my ($k) = $entry =~ /\A([0-9]+) /;
        next if $layers->{off}{ $f->{lists}[$k]{name} };
        my $r = filter_rule($entry) or next;
        next if $r->{types} && !$r->{types}{$type} || $r->{not} && $r->{not}{$type};
        next if $r->{party} eq '3p' && !$third || $r->{party} eq '1p' && $third;
        next if $r->{on} && !grep({ $r->{on}{$_} } @pages) || $r->{off} && grep({ $r->{off}{$_} } @pages);
        next unless $r->{host} || $url =~ $r->{re};
        if ($r->{x}) { $except //= $entry; $vital_except //= $entry if $r->{imp} } elsif ($r->{imp}) { $vital //= $entry } else { $block //= $entry }
    }
    return ($vital && !$vital_except ? $vital : $block && !$except ? $block : undef, $except);
}

sub filter_named { my ($entry) = @_; my ($k, $line) = $entry =~ /\A([0-9]+) (.*)\z/s; return ($line =~ s/[^\x20-\x7e]/?/gr =~ s/\A(.{200}).+\z/$1.../sr, $FILTERS->{lists}[$k]{name}) }    # [C27] an entry as it is said: its line, printable and at most 200 characters, and its list

sub filter_said {                         # [C27] why a request of a page is not fetched, when a filter list blocks it: words for the log and the window, and the request kept for Filters; or nothing
    my ($url, $type, $page) = @_;
    my ($by) = filtered($url, $type, $page);
    return unless $by;
    my ($rule, $list) = filter_named($by);
    unshift @FILTER_SEEN, [lc $page, $url =~ s/[^\x20-\x7e]//gr =~ s/\A(.{300}).+\z/$1/sr, $type, $rule, $list];
    splice @FILTER_SEEN, $FILTER_SEEN_MOST if @FILTER_SEEN > $FILTER_SEEN_MOST;
    return "the filter rule $rule of $list blocks it";
}

# Your filter switches, in the plain file filterlayers of yours, one a line:
# "list off TAB NAME" switches one list off, and "allow TAB SITE TAB HOST"
# lets the requests of pages of SITE to HOST through every list. No file
# means every list is on and nothing is let through; the file is written only
# while something is switched off or let through. A file that does not read
# switches nothing off and lets nothing through, and Filters says so. An
# incognito window reads it and keeps what is chosen in it in its memory only.
sub filter_layers {                       # [C27] {off => {NAME => 1}, allow => {"SITE TAB HOST" => 1}, unread => 1 when a file is there that does not read}
    return { off => { %{ $HELD_FILTER_LAYERS->{off} } }, allow => { %{ $HELD_FILTER_LAYERS->{allow} } }, unread => 0 } if $HELD_FILTER_LAYERS;
    my $file = kept_in() . '/filterlayers';
    my %layers = (off => {}, allow => {}, unread => 0);
    my $bad = { off => {}, allow => {}, unread => 1 };
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return -l $file || -e _ ? $bad : \%layers;
    my @is = stat $in;
    my $text = '';
    return $bad unless @is && -f _ && $is[3] == 1 && $is[4] == $< && $is[7] <= $PERMIT_FILE_BYTES && defined sysread($in, $text, $PERMIT_FILE_BYTES + 1) && length $text <= $PERMIT_FILE_BYTES && ($text eq '' || $text =~ /\n\z/);
    for (split /\n/, $text) {
        if (/\Alist off\t((?:ubo-[a-z0-9][a-z0-9.-]{0,47}|filters-local)\.txt)\z/) { $layers{off}{$1} = 1; next }
        my ($key) = /\Aallow\t(https:\/\/$NAME\t$NAME)\z/ or return $bad;
        return $bad if keys %{ $layers{allow} } >= $FILTER_ALLOWS;
        $layers{allow}{ lc $key } = 1;
    }
    return \%layers;
}

sub filter_layers_kept {                  # [C27] the switches written as $layers says, under the lock of the settings: the file removed when nothing is switched; in an incognito window held in its memory. Returns "file" or "memory", or nothing when it could not be written
    my ($layers) = @_;
    if ($INCOGNITO) { $HELD_FILTER_LAYERS = { off => { %{ $layers->{off} } }, allow => { %{ $layers->{allow} } } }; return 'memory' }
    my $file = "$DIR/filterlayers";
    my @lines = ((map { "list off\t$_" } sort keys %{ $layers->{off} }), map { "allow\t$_" } sort keys %{ $layers->{allow} });
    if (!@lines) { return 'file' unless -e $file || -l $file; unlink $file or return; synced(); return 'file' }
    unlink "$file.new";
    unless (put("$file.new", O_EXCL, @lines) && rename("$file.new", $file)) { unlink "$file.new"; return }
    synced();
    return 'file';
}

sub filters_set {                         # [C27] [C4] Filters, from the cogwheel's menu: "list"; "switch" N on or off, the list numbered N; "allow" N, the host of the blocked request numbered N on its page's site; "revoke" N, what you let through numbered N. The page is told again after each
    my ($what, $n, $to) = @_;
    my $words = '';
    if ($what ne 'list') {
        my $lock = $INCOGNITO ? 1 : keep_lock();
        $words = !$lock ? 'Nothing was changed: the lock of the settings could not be taken.' : filter_changed($what, $n, $to);
    }
    filters_told();
    my $f = filters();
    return idle(length $words ? $words : length $f->{why} ? "Filters: nothing is filtered: $f->{why}." : 'Filters: ' . @{ $f->{lists} } . (@{ $f->{lists} } == 1 ? ' list.' : ' lists.'));
}

sub filter_changed {                      # [C27] one switch of Filters made and kept (sub filter_layers_kept); what to say
    my ($what, $n, $to) = @_;
    my $layers = filter_layers();
    return kept_in() . '/filterlayers is not a file lzrprf reads, so no list is off and nothing is let through. Nothing was changed.' if $layers->{unread};
    my $said;
    if ($what eq 'switch') {
        my $list = filters()->{lists}[$n] or return 'Nothing was changed: that list is no longer there.';
        if ($to eq 'off') { $layers->{off}{ $list->{name} } = 1 } else { delete $layers->{off}{ $list->{name} } }
        $said = "The list $list->{name} is $to";
    }
    elsif ($what eq 'allow') {
        my $seen = $FILTER_SEEN[$n] or return 'Nothing was changed: that request is no longer in the list.';
        my ($host) = $seen->[1] =~ m{\Ahttps?://([^/?#:]+)}i;
        return 'Nothing was changed: that request names no host lzrprf lets through.' unless defined $host && $host =~ /\A$NAME\z/ && $seen->[0] =~ /\A$NAME\z/;
        return "Nothing was changed: you let through more than $FILTER_ALLOWS hosts already." if keys %{ $layers->{allow} } >= $FILTER_ALLOWS;
        $layers->{allow}{ lc "https://$seen->[0]\t$host" } = 1;
        $said = "The requests of pages of https://$seen->[0] to " . lc($host) . ' are let through every list';
    }
    else {
        my $key = (sort keys %{ $layers->{allow} })[$n] // return 'Nothing was changed: that is no longer let through.';
        delete $layers->{allow}{$key};
        $said = 'The requests of pages of ' . ($key =~ s/\t/ to /r) . ' are held to the lists again';
    }
    my $kept = filter_layers_kept($layers) or return 'Nothing was changed: the file filterlayers could not be written.';
    return $said . ($kept eq 'memory' ? ' in this incognito window only.' : '.');
}

sub filters_told {                        # [C27] the list page: "filters begin"; "filters state on<tab>MS" or "filters state off<tab>WHY"; "filters list N<tab>on|off<tab>NAME<tab>RULES<tab>SKIPPED" for each list; "filters commit HEX" of the upstream lists; "filters count KIND<tab>N" for each kind of line; "filters allow N<tab>SITE<tab>HOST<tab>file|memory"; "filters seen N<tab>PAGE<tab>ADDRESS<tab>TYPE<tab>RULE<tab>LIST", the newest first; then "filters end" or "filters end unread"
    my $f = filters();
    my $layers = filter_layers();
    my @allow = sort keys %{ $layers->{allow} };
    my $where = $INCOGNITO ? 'memory' : 'file';
    my $current = $SHOWN ? lc($SHOWN->{host} // '') : '';
    window('filters begin', 'filters state ' . (length $f->{why} ? "off\t$f->{why}" : "on\t$f->{ms}"),
        (map { my $c = $f->{lists}[$_]{counts}; 'filters list ' . join("\t", $_, $layers->{off}{ $f->{lists}[$_]{name} } ? 'off' : 'on', $f->{lists}[$_]{name}, ($c->{network} // 0) + ($c->{exception} // 0), filter_skipped($c)) } 0 .. $#{ $f->{lists} }),
        (defined $f->{commit} ? "filters commit $f->{commit}" : ()), (map { "filters count $_\t$f->{counts}{$_}" } sort keys %{ $f->{counts} }),
        (map { 'filters allow ' . join("\t", $_, split(/\t/, $allow[$_]), $where) } 0 .. $#allow),
        (map { 'filters seen ' . join("\t", $_, ($FILTER_SEEN[$_][0] eq $current ? 'current' : 'recent'), @{ $FILTER_SEEN[$_] }) } 0 .. $#FILTER_SEEN), 'filters end' . ($layers->{unread} ? ' unread' : ''));
}

sub filter_skipped { my ($c) = @_; my $n = 0; $n += $c->{$_} for grep { $_ ne 'network' && $_ ne 'exception' } keys %$c; return $n }    # [C27] the lines of one list counted and not used

sub filters_dir {                         # [C27] "lzrprf filters DIR PAGE TYPE ADDRESS...": what the lists in DIR (every NAME.txt there, read unsigned) would do with each address as a request of TYPE from a page of the host PAGE. It decides nothing for a window: for a survey of sites and for selftest
    my ($dir, $page, $type, @urls) = @_;
    die "lzrprf: filters takes a folder, the host of a page, a type (" . join(' ', sort keys %FILTER_TYPE) . ") and addresses\n" unless -d $dir && $page =~ /\A$NAME\z/ && $FILTER_TYPE{$type} && @urls;
    $type = $FILTER_TYPE{$type};
    $HELD_FILTER_LAYERS = { off => {}, allow => {} };    # nothing of yours: no switch of any profile is read
    my $began = now();
    $FILTERS = filter_empty();
    opendir(my $in, $dir) or die "lzrprf: $dir cannot be read\n";
    my @names = sort grep { /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.txt\z/ && -f "$dir/$_" } readdir $in;
    for my $name (@names) { open(my $list, '<:raw', "$dir/$name") or die "lzrprf: $dir/$name cannot be read\n"; local $/; filter_list_read($name, <$list> // '') }
    my $loaded = now() - $began;
    my ($looked, $at) = (0, now());
    for my $url (@urls) {
        my ($by, $except) = filtered($url, $type, $page);
        print $by ? join("\t", 'blocked', filter_named($by)) : $except ? join("\t", 'excepted', filter_named($except)) : 'passed', "\t$url\n";
        $looked++;
    }
    my $took = now() - $at;
    print 'counts ', join(' ', map { "$_=$FILTERS->{counts}{$_}" } sort keys %{ $FILTERS->{counts} }), "\n";
    printf "took load_ms=%d lookups=%d lookup_us=%.1f loose=%d hosts=%d tokens=%d\n", $loaded * 1000, $looked, $looked ? $took * 1e6 / $looked : 0, scalar @{ $FILTERS->{loose} }, scalar keys %{ $FILTERS->{host} }, scalar keys %{ $FILTERS->{token} };
    return;
}

