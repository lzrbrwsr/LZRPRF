# LZRDFNDR scripts (until release 77 named Script permissions) [C26]. LZRBRWSR runs no script you have not allowed
# (managed-projects/lzrbrwsr/architecture/script-permissions.md, docs/script-permissions.md, RULES.md). Two layers
# decide and either one alone refuses: lzrprf, which holds the only policy and
# the only store, and the engine, which asks before any text becomes code and
# runs nothing without an answer. A script is named by its kind, the origin
# its bytes came from ("inline" for bytes in the page), the SHA-256 of its
# bytes and the capabilities it asks. The site is the page's origin.
#
# The policy, in order (sub permit_decided): a Deny of yours (a rule, or
# your Deny in this window) refuses, whatever E1 and E2 would say; a site
# whose scripts may not run at all ("page deny", sub permit_site) runs none.
# A site may run scripts when you allowed it (an Always rule of yours for
# it, or Allow Once for this visit), or, while you have no rule for it, in
# lzrprf's sandbox (E1, switched on unless you switched it off, or a curated
# rule for it), never on a page for signing in. Then, in this order:
#   E1  an inline or same-origin script, not data: or blob:, asking only for
#       capabilities of low risk (%PERMIT_E1), runs ("once"); in the sandbox
#       its requests are held to @PERMIT_SANDBOX (sub live_fetched);
#   E2  a curated rule names it (sub curated): reviewed, signed with the
#       release, switched on, by SHA-256 or by a reviewed path pattern;
#   E3  an Always rule of yours whose capabilities cover those asked, then
#       your Allow Once;
# and anything else is denied at once and kept to put to you once the page is
# drawn. No question ever holds a page: on an Allow lzrprf loads the page
# again with what you allowed. A changed SHA-256, or capabilities no rule
# names, is a new script.
#
# The store, "$DIR/scripts", one rule a line:
#   always|deny TAB site TAB class TAB script origin TAB sha256 TAB caps TAB date
# The class is the kind asked when you answered: "code" (inline, external,
# module, handler, worker, import) or "strings" (eval, function, timer), so
# that a script allowed to run is still asked before it turns text into code.
# lzrprf alone writes it, beside the old file and through to the disk, and
# only once there is a rule; a file that is a link, of another owner, with a
# second name, larger than $PERMIT_FILE_BYTES, with more than $PERMIT_RULES
# rules or with one line of another form is not read: none of its rules then
# counts, which means you are asked, never that anything runs, and it is
# never written over. An incognito window reads the file of the folder its
# settings come from and keeps every rule of its own in its memory only.
# A rule holds for the kinds of its class (sub permit_kinds); a line of
# another form, the six fields of before the class among them, is no form.
sub permit_rules {                        # [C26] the rules: [always|deny, site, class, script origin, sha256, caps, date, "file" or "memory"] each, the file's first; and whether a file is there that was not read
    my @held = map { [@$_] } @PERMIT_HELD;
    my $file = kept_in() . '/scripts';
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return (\@held, -l $file || -e _ ? 1 : 0);
    my @is = stat $in;
    return (\@held, 1) unless @is && -f _ && $is[3] == 1 && $is[4] == $< && $is[7] <= $PERMIT_FILE_BYTES;
    my $text = '';
    while (1) {
        my $got = sysread($in, $text, 65536, length $text);
        return (\@held, 1) if !defined $got || length $text > $PERMIT_FILE_BYTES;
        last unless $got;
    }
    return (\@held, 1) unless $text eq '' || $text =~ /\n\z/;
    my @file;
    for (split /\n/, $text) {
        my @rule = /\A(always|deny)\t(https:\/\/$NAME)\t(code|strings)\t($PERMIT_ORIGIN)\t([0-9a-f]{64})\t($PERMIT_CAPS)\t([0-9]{4}-[0-9]{2}-[0-9]{2})\z/ or return (\@held, 1);
        return (\@held, 1) if lc($rule[1]) ne $rule[1] || lc($rule[3]) ne $rule[3] || @file >= $PERMIT_RULES;
        push @file, [@rule, 'file'];
    }
    return ([@file, @held], 0);
}

sub permit_written {                      # [C26] the rules of the file, written beside it and through to the disk, then given its name in one step; with none, the file is removed
    my (@rules) = @_;
    my $file = "$DIR/scripts";
    if (!@rules) { return 1 unless -e $file || -l $file; unlink $file or return 0; synced(); return 1 }
    unlink "$file.new";
    unless (put("$file.new", O_EXCL, map { join "\t", @$_[0 .. 6] } @rules)) { unlink "$file.new"; return 0 }
    unless (rename "$file.new", $file) { unlink "$file.new"; return 0 }
    synced();
    return 1;
}

sub permit_stored {                       # [C26] a change of the rules, made by $how on them as read again under the lock of the settings: written when the file can be, in this window's memory when not (an incognito window, a file that is not read). A rule of a file that is not written never changes. Returns "file" or "memory", or nothing when nothing was changed
    my ($how) = @_;
    my $lock = $INCOGNITO ? 1 : keep_lock();
    return unless $lock;
    my ($rules, $unread) = permit_rules();
    my $memory = $INCOGNITO || $unread;
    my $was = join "\n", map { join "\t", @$_ } grep { $_->[7] eq 'file' } @$rules;
    $how->($rules, $memory) or return;
    $_->[7] //= $memory ? 'memory' : 'file' for @$rules;
    my @file = grep { $_->[7] eq 'file' } @$rules;
    if ($was ne join "\n", map { join "\t", @$_ } @file) { return if $memory || @file > $PERMIT_RULES || !permit_written(@file) }
    @PERMIT_HELD = grep { $_->[7] eq 'memory' } @$rules;
    return $memory ? 'memory' : 'file';
}

sub permit_covers {                       # [C26] whether the capabilities a rule names cover those asked ("-": none)
    my ($has, $asks) = @_;
    my %has = map { $_ => 1 } split /,/, $has eq '-' ? '' : $has;
    return !grep { !$has{$_} } split /,/, $asks eq '-' ? '' : $asks;
}

sub permit_site {                         # [C26] whether a site may run scripts at all ("page allow") on the page at $url: "person", an Always rule of yours for it or your Allow Once of the visit shown; "sandbox", no rule of yours, and E1 is on or a curated rule names the site, on a page that is not for signing in and of a site you did not deny in this window; nothing, "page deny"
    my ($site, $rules, $url) = @_;
    return 'person' if $PERMIT_ONCE{$site} || grep { $_->[0] eq 'always' && $_->[1] eq $site } @$rules;
    return '' if permit_signin($url) || ($PERMIT_DENIED{$site} && $PERMIT_DENIED{$site}{''});
    my $layers = permit_layers();
    return 'sandbox' if $layers->{e1} || grep { $_->{site} eq $site } curated_on($layers);
    return '';
}

sub permit_signin {                       # [C26] whether the page at $url is for signing in: its page held a password field, its host begins with a label of signing in, or a segment of its path is one
    my ($url) = @_;
    return 1 unless defined $url;
    return 1 if $PERMIT_PASSWORD{$url};
    my ($host, $path) = $url =~ m{\Ahttps://([^/?#:]+)(?::[0-9]+)?([^?#]*)} or return 1;
    return 1 if $SIGNIN_HOSTS{ lc((split /\./, $host)[0] // '') };
    return scalar grep { $SIGNIN_PATHS{ lc((split /\./, $_)[0] // '') } } split m{/}, $path;
}

sub permit_password {                     # [C26] a page answer, as curl gave it, that holds a password field: its address is kept for this window as one for signing in
    my ($url, $got) = @_;
    return unless defined $got && $got =~ /<input\b[^>]*\btype\s*=\s*["']?password\b/i;
    %PERMIT_PASSWORD = () if keys %PERMIT_PASSWORD >= $PERMIT_SEEN_MOST;
    $PERMIT_PASSWORD{$url} = 1;
}

sub permit_seen {                         # [C26] one decision of the sandbox (E1) or of a curated rule (E2), kept in this window's memory for Script permissions: the newest first, counted, at most $PERMIT_SEEN_MOST
    my ($layer, $site, $what, $said) = @_;
    my ($had) = grep { $_->[0] eq $layer && $_->[1] eq $site && $_->[2] eq $what && $_->[3] eq $said } @PERMIT_SEEN;
    @PERMIT_SEEN = grep { $_ != ($had // 0) } @PERMIT_SEEN;
    unshift @PERMIT_SEEN, [$layer, $site, $what, $said, ($had ? $had->[4] : 0) + 1];
    splice @PERMIT_SEEN, $PERMIT_SEEN_MOST if @PERMIT_SEEN > $PERMIT_SEEN_MOST;
}

sub permit_info {                         # [C26] what lzrprf saw of one script, kept the first time: its name, inline or external, its size and the first $PERMIT_SOURCE_MOST bytes of its source
    my ($site, $origin, $sha, $name, $where, $text) = @_;
    my $key = "$site $origin $sha";
    return if $PERMIT_INFO{$key};
    %PERMIT_INFO = () if keys %PERMIT_INFO >= $PERMIT_RULES;
    $text //= '';
    $PERMIT_INFO{$key} = { name => $name, where => $where, bytes => length $text, source => substr($text, 0, $PERMIT_SOURCE_MOST), unfetched => $where eq 'unfetched' ? 1 : 0 };
}

sub permit_tracker {                      # [C26] who runs the scripts of the host a name begins with, when @PERMIT_TRACKERS knows it, or ''
    my ($name) = @_;
    my ($host) = lc($name) =~ m{\A([a-z0-9.-]+)};
    return '' unless defined $host;
    my ($known) = grep { $host eq $_->[0] || substr($host, -length($_->[0]) - 1) eq ".$_->[0]" } @PERMIT_TRACKERS;
    return $known ? $known->[1] : '';
}

sub permit_named {                        # [C26] a script by its name (host and path, its query left out, or an inline script of the page by the start of its SHA-256), inline or external, its size in bytes (0 when not seen) and who runs it when known
    my ($site, $kind, $origin, $sha) = @_;
    my $info = $PERMIT_INFO{"$site $origin $sha"};
    my ($host) = $site =~ m{\Ahttps://(.*)\z};
    my $name = $info ? $info->{name} : $origin eq 'inline' ? ($kind eq 'handler' ? 'handler ' : 'inline script ') . substr($sha, 0, 12) . " in $host" : $origin =~ m{\Ahttps://(.*)\z} ? "a script from $1, " . substr($sha, 0, 12) : "a $origin script, " . substr($sha, 0, 12);
    return ($name, $origin eq 'inline' ? 'inline' : $info && $info->{unfetched} ? 'external, size unknown, not fetched' : 'external', $info ? $info->{bytes} : 0, permit_tracker($origin eq 'inline' ? '' : $name =~ s/\Aa script from //r));
}

sub permit_part {                         # [C26] one part the strip took out of the page at $url ($at: its host and path), by its name: [kind, origin, identity, name, where, text]. A script file is named by its address resolved against the page, its query left out, and is never fetched for it: its identity is the SHA-256 of "src " and that address, so a Deny Always of it holds on the next visit. An address of no origin a rule can hold is named as the text it is
    my ($url, $at, $kind, $sha, $text, $label) = @_;
    if ($kind eq 'src') {
        (my $value = $text) =~ s/&amp;/&/gi;
        $value =~ s/\A[\x00-\x20]+|[\x00-\x20]+\z//g;
        my $to = resolved($url, $value) =~ s/[?#].*\z//sr;
        my ($origin, $host, $path) = $to =~ m{\A(https://([^/?#]+))([^?#]*)\z};
        return ['external', $origin, Digest::SHA::sha256_hex("src $to"), $host . (length $path ? $path : '/'), 'unfetched', ''] if defined $origin && $origin =~ /\A$PERMIT_ORIGIN\z/;
        my ($scheme) = $to =~ /\A(data|blob):/;
        return ['external', "$scheme:", Digest::SHA::sha256_hex("src $to"), "a $scheme: script address", 'unfetched', ''] if $scheme;
        ($kind, $sha, $label) = ('handler', Digest::SHA::sha256_hex($value), 'script address');
        $text = $value;
    }
    return [$kind, 'inline', $sha, "$label " . substr($sha, 0, 12) . " in $at", 'inline', $text];
}

sub permit_decision {                     # [C26] your decision on one script of a site, as LZRDFNDR's On Websites says it: "allowed always", "denied always", "allowed once", "denied once" or "no decision"; and the number of the rule of yours, or -1
    my ($site, $class, $origin, $sha, $rules) = @_;
    for my $n (0 .. $#$rules) {
        my $r = $rules->[$n];
        return ($r->[0] eq 'always' ? 'allowed always' : 'denied always', $n) if $r->[1] eq $site && $r->[2] eq $class && $r->[3] eq $origin && $r->[4] eq $sha;
    }
    return ('denied once', -1) if $PERMIT_DENIED{$site} && $PERMIT_DENIED{$site}{"$class $origin $sha"};
    for my $once (grep { $_ } $PERMIT_ONCE{$site}, $PERMIT_NEXT{$site}) {
        return ('allowed once', -1) if grep { my ($k, $o, $s) = split / /; permit_class($k) eq $class && $o eq $origin && $s eq $sha } keys %{ $once->{keys} };
    }
    return ('no decision', -1);
}

sub sites_told {                          # [C26] LZRDFNDR's On Websites: "sites begin", then for each site in order "sites site SITE", and under it "sites script N<tab>SITE<tab>NAME<tab>inline|external<tab>BYTES<tab>WHO<tab>CLASS<tab>DECISION" for each script put to you in this window and each rule of yours; then "sites end"
    my ($keys, $all, $lines) = sites_listed();
    window('sites begin', @$lines, 'sites end');
}

sub sites_listed {                        # [C26] the scripts of On Websites, each site's together in the order of their keys: the keys, the scripts by key, and the lines that tell them
    my ($rules) = permit_rules();
    my %all = %PERMIT_WEB;
    $all{ join "\t", @$_[1 .. 4] } //= [$_->[1], $_->[2] eq 'strings' ? 'eval' : $_->[3] eq 'inline' ? 'inline' : 'external', @$_[3, 4, 5]] for @$rules;
    my @keys = sort keys %all;
    my ($n, $was, @lines) = (0, '');
    for my $key (@keys) {
        my ($site, $kind, $origin, $sha) = @{ $all{$key} };
        my $class = permit_class($kind);
        push @lines, "sites site $site" if $site ne $was;
        $was = $site;
        my ($name, $where, $bytes, $who) = permit_named($site, $kind, $origin, $sha);
        push @lines, 'sites script ' . join("\t", $n++, $site, $name, $where, $bytes, $who, $class, (permit_decision($site, $class, $origin, $sha, $rules))[0]);
    }
    return \@keys, \%all, \@lines;
}

sub sites_decide {                        # [C26] [C4] a decision changed in LZRDFNDR's On Websites, for the script numbered $n as sites_told last numbered it: "always" or "deny" keeps a rule of yours for it, "forget" takes away every decision of yours for it; then the list is told again
    my ($n, $to) = @_;
    my ($keys, $all) = sites_listed();    # numbered as sites_told numbered them
    my $key = $keys->[$n];
    my $words = 'Nothing was changed: that script is no longer in the list.';
    if (defined $key) {
        my ($site, $kind, $origin, $sha, $caps) = @{ $all->{$key} };
        my $class = permit_class($kind);
        my $date = strftime('%Y-%m-%d', gmtime);
        delete $PERMIT_DENIED{$site}{"$class $origin $sha"} if $PERMIT_DENIED{$site};
        for my $once (grep { $_ } $PERMIT_ONCE{$site}, $PERMIT_NEXT{$site}) { delete $once->{keys}{$_} for grep { my ($k, $o, $s) = split / /; permit_class($k) eq $class && $o eq $origin && $s eq $sha } keys %{ $once->{keys} } }
        my $done = permit_stored(sub {
            my ($rules, $memory) = @_;
            my $had = @$rules;
            @$rules = grep { !($_->[1] eq $site && $_->[2] eq $class && $_->[3] eq $origin && $_->[4] eq $sha && !($memory && $_->[7] eq 'file')) } @$rules;
            push @$rules, [$to, $site, $class, $origin, $sha, $caps // '-', $date] if $to ne 'forget';
            return $to ne 'forget' || $had != @$rules;
        });
        my ($name) = permit_named($site, $kind, $origin, $sha);
        $words = $to eq 'forget' ? "No decision of yours is kept for $name: it is asked about again." : $done ? "$name is now " . ($to eq 'always' ? 'allowed' : 'denied') . ' always.' : 'Nothing was changed: the scripts file could not be written.';
        noted("LZRDFNDR On Websites: $words");
    }
    sites_told();
    return idle($words);
}

# The two switches of the layers, in the plain file scriptlayers of yours, one
# a line: "e1 off" switches the sandbox off, and "curated off TAB site TAB
# script origin TAB identity TAB class" switches one curated rule off. No file
# means the sandbox is on and every curated rule is; the file is written only
# while something is switched off. It is read strictly, as the scripts file
# is: a file that does not read switches the sandbox and every curated rule
# off, so you are asked, never that anything runs. An incognito window reads
# it and keeps what is chosen in it in its memory only.
sub permit_layers {                       # [C26] {e1 => 1 or 0, off => {"SITE TAB ORIGIN TAB IDENTITY TAB CLASS" => 1}, unread => 1 when a file is there that does not read}
    return { e1 => $HELD_LAYERS->{e1}, off => { %{ $HELD_LAYERS->{off} } }, unread => 0 } if $INCOGNITO && $HELD_LAYERS;
    my $file = kept_in() . '/scriptlayers';
    my %layers = (e1 => 1, off => {}, unread => 0);
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return -l $file || -e _ ? { e1 => 0, off => {}, unread => 1, all => 1 } : \%layers;
    my @is = stat $in;
    my $text = '';
    my $bad = { e1 => 0, off => {}, unread => 1, all => 1 };
    return $bad unless @is && -f _ && $is[3] == 1 && $is[4] == $< && $is[7] <= $PERMIT_FILE_BYTES && defined sysread($in, $text, $PERMIT_FILE_BYTES + 1) && length $text <= $PERMIT_FILE_BYTES && ($text eq '' || $text =~ /\n\z/);
    for (split /\n/, $text) {
        if ($_ eq 'e1 off') { $layers{e1} = 0; next }
        my ($key) = /\Acurated off\t(https:\/\/$NAME\t(?:inline|https:\/\/$NAME(?::[0-9]{1,5})?)\t(?:sha256 [0-9a-f]{64}|path \/[!-~]{1,300})\t(?:code|strings))\z/ or return $bad;
        return $bad if keys %{ $layers{off} } >= $CURATED_MOST;
        $layers{off}{$key} = 1;
    }
    return \%layers;
}

sub permit_layers_kept {                  # [C26] the switches written as $layers says, under the lock of the settings: the file removed when nothing is switched off; in an incognito window held in its memory. Returns "file" or "memory", or nothing when it could not be written
    my ($layers) = @_;
    if ($INCOGNITO) { $HELD_LAYERS = { e1 => $layers->{e1} ? 1 : 0, off => { %{ $layers->{off} } } }; return 'memory' }
    my $file = "$DIR/scriptlayers";
    my @lines = (($layers->{e1} ? () : 'e1 off'), map { "curated off\t$_" } sort keys %{ $layers->{off} });
    if (!@lines) { return 'file' unless -e $file || -l $file; unlink $file or return; synced(); return 'file' }
    unlink "$file.new";
    unless (put("$file.new", O_EXCL, @lines) && rename("$file.new", $file)) { unlink "$file.new"; return }
    synced();
    return 'file';
}

# E2, the curated rules: reviewed rules of site scripts, kept in lzrprf's
# repository in rules/, one file per site, and joined in the order of their
# names into one file, permit-rules, that the release's signed manifest names
# by its SHA-256 (RULES.md has the form). The installer keeps that file beside
# lzrprf with the manifest and both its signatures (release.manifest,
# release.manifest.sig, release.manifest.approval). lzrprf uses a curated rule
# only when all four are plain files of yours; the manifest is in its one form
# (sub manifest_read); the approval holds for an approval key and the
# signature for the release key lzrprf carries (sub signature_holds, macOS's
# own ssh-keygen in the verifier container); the manifest is of the release
# the application's release file names; and it names permit-rules by the
# SHA-256 of the file beside it. Anything else, and every curated rule is
# unused: you are asked, never that anything runs. The expiry of the manifest
# is not held against rules already installed with it. In the file, a site's
# part whose rule is unreviewed, grants a capability that is not of low risk,
# names a path pattern too wide, a site for signing in, or any line of another
# form, is not used at all; the other parts are.
sub curated {                             # [C26] E2: the curated rules, read and checked once a window (see above)
    return $CURATED if $CURATED;
    $CURATED = { rules => [], parts => [], why => '' };
    my $no = sub { $CURATED->{why} = $_[0]; return $CURATED };
    my %text;
    for my $name ('permit-rules', 'release.manifest', 'release.manifest.sig', 'release.manifest.approval') {
        my $file = "$ROOT/$name";
        sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return $no->(-l $file || -e $file ? "$file is not a plain file of yours" : "there is no $name beside lzrprf, so no curated rule is used");
        my @is = stat $in;
        return $no->("$file is not a plain file of yours") unless @is && -f _ && $is[3] == 1 && $is[4] == $<;
        my $most = $name eq 'permit-rules' ? $CURATED_BYTES : $name eq 'release.manifest' ? $MANIFEST_MOST : $SIGNATURE_MOST;
        return $no->("$file is larger than lzrprf reads") if $is[7] > $most;
        my $got = '';
        while (1) { my $n = sysread($in, $got, 65536, length $got); return $no->("$file could not be read") unless defined $n; last unless $n; return $no->("$file is larger than lzrprf reads") if length $got > $most }
        $text{$name} = $got;
    }
    my ($manifest, $why) = manifest_read($text{'release.manifest'});
    return $no->("release.manifest: $why") unless $manifest;
    return $no->('the manifest is not approved with an approval key lzrprf carries') unless signature_holds($text{'release.manifest'}, $text{'release.manifest.approval'}, $APPROVAL_NAMESPACE, 'ECDSA', approval_keys());
    return $no->('the signature of the manifest does not hold for the release key lzrprf carries') unless signature_holds($text{'release.manifest'}, $text{'release.manifest.sig'}, $RELEASE_NAMESPACE, 'ED25519', release_key());
    my ($release) = beside();
    return $no->('the application\'s release file names no release, so lzrprf cannot tell the manifest is of this one') if !defined $release && (release_lines() || $PROGRAM =~ m{\.app/Contents/MacOS/});
    return $no->("the manifest is of release $manifest->{release}, and the application is release $release") if defined $release && $release != $manifest->{release};
    my $named = $manifest->{files}{'permit-rules'} // return $no->('the signed manifest names no permit-rules');
    return $no->('permit-rules is another file than the signed manifest names') unless $named eq Digest::SHA::sha256_hex($text{'permit-rules'});
    my ($rules, $parts, $bad) = curated_read($text{'permit-rules'});
    return $no->("permit-rules is not in its form: $bad") if defined $bad;
    @$CURATED{qw(rules parts)} = ($rules, $parts);
    return $CURATED;
}

sub curated_read {                        # [C26] E2: the parts of a file of curated rules, each "lzrprf permit rules 1" and its rules (RULES.md); returns [rules used], [[site, "used" or "ignored", why]] and why the file as a whole is in no form, or nothing
    my ($text) = @_;
    return ([], [], 'it holds a byte that is not printable or does not end in a line end') unless $text eq '' || $text =~ /\A[\x20-\x7e\n]*\n\z/;
    my (@rules, @parts, $part);
    my $now = time;
    my $done = sub {
        return unless $part;
        my @mine = @{ $part->{rules} };
        my $why = $part->{why} // (!@mine ? 'it holds no rule' : '');
        my $site = @mine ? $mine[0]{site} : $part->{site} // '-';    # a part none of whose rules is used is named by the site its first rule says
        $why ||= 'its rules are of more than one site' if grep { $_->{site} ne $site } @mine;
        push @parts, [$site, length $why ? 'ignored' : 'used', length $why ? $why : 'reviewed and signed'];
        push @rules, @mine unless length $why;
    };
    my @lines = split /\n/, $text;
    while (@lines) {
        my $line = shift @lines;
        next if $line eq '' || $line =~ /\A# [\x20-\x7e]{0,300}\z/;
        if ($line eq 'lzrprf permit rules 1') { $done->(); $part = { rules => [] }; next }
        return ([], [], "a line of no form where a part or a rule begins: $line") unless $part && $line eq 'rule';
        my %rule;
        for my $field (qw(site script-origin script class caps justification source reviewer reviewed)) {
            my $got = shift(@lines) // '';
            my ($value) = $got =~ /\A\Q$field\E ([\x20-\x7e]{1,400})\z/ or return ([], [], "a rule without its field $field in its place");
            $rule{$field} = $value;
        }
        $part->{site} //= $rule{site};
        return ([], [], 'a rule that does not end with "end"') unless (shift(@lines) // '') eq 'end';
        my $one = curated_rule(\%rule, $now);
        if (!ref $one) { $part->{why} //= $one; next }
        return ([], [], "more than $CURATED_MOST rules") if @rules + @{ $part->{rules} } >= $CURATED_MOST;
        push @{ $part->{rules} }, $one;
    }
    $done->();
    return (\@rules, \@parts, undef);
}

sub curated_rule {                        # [C26] E2: one rule's fields checked, as a rule lzrprf can use; or why it may never be used
    my ($r, $now) = @_;
    my ($site) = $r->{site} =~ m{\A(https://$NAME)\z} or return 'its site is not an https origin of small letters';
    return 'its site is not an https origin of small letters' if lc $site ne $site;
    return 'its site is one for signing in' if $SIGNIN_HOSTS{ (split /\./, substr($site, 8))[0] };
    my ($origin) = $r->{'script-origin'} =~ m{\A(inline|https://$NAME(?::[0-9]{1,5})?)\z} or return 'its script origin is neither inline nor an https origin';
    return 'its script origin is neither inline nor an https origin' if lc $origin ne $origin;
    my ($kind, $id, $reason);
    if ($r->{script} =~ /\Asha256 ([0-9a-f]{64})\z/) { ($kind, $id) = ('sha256', $1) }
    elsif ($r->{script} =~ m{\Apath ((?:/[A-Za-z0-9._~*-]{1,128}){2,16}) reason ([\x20-\x7e]{8,300})\z}) { ($kind, $id, $reason) = ('path', $1, $2) }
    else { return 'it names no script identity: a SHA-256, or a path pattern with its reason' }
    if ($kind eq 'path') {
        my @segments = split m{/}, substr($id, 1);
        return 'a path pattern is not for a script of an inline origin' if $origin eq 'inline';
        return 'its path pattern does not end in .js or .mjs' unless $id =~ /\.m?js\z/;
        return 'its path pattern has more than two "*"' if ($id =~ tr/*//) > 2;
        return 'its path pattern names no fixed folder, so it would hold for a whole domain' unless grep { !/\*/ } @segments[0 .. $#segments - 1];
        return 'its path pattern has a segment that is only "*"' if grep { $_ eq '*' } @segments;
    }
    my ($class) = $r->{class} =~ /\A(code|strings)\z/ or return 'its class is neither code nor strings';
    my ($caps) = $r->{caps} =~ /\A($PERMIT_CAPS)\z/ or return 'its capabilities are not names';
    for my $cap (split /,/, $caps eq '-' ? '' : $caps) {
        return "it grants $cap, which no script permission covers (C5)" if ($PERMIT_CAPS{$cap} // '') eq 'c5';
        return "it grants $cap, which only you grant" if ($PERMIT_CAPS{$cap} // '') eq 'person';
        return "it grants $cap, a capability lzrprf does not know" unless $PERMIT_CAPS{$cap};
    }
    return 'its justification is too short to say why' if length $r->{justification} < 12;
    return 'it names no source inspected' if length $r->{source} < 8;
    return 'it is unreviewed' if $r->{reviewer} =~ /\A\s*(?:unreviewed|-|none)?\s*\z/i;
    my @date = $r->{reviewed} =~ /\A([0-9]{4})-([0-9]{2})-([0-9]{2})\z/ or return 'its review date is not a date';
    my $when = eval { Time::Local::timegm(0, 0, 0, $date[2], $date[1] - 1, $date[0]) } // return 'its review date is not a date';
    return 'its review date is later than today' if $when > $now + 86400;
    my $pattern = $kind eq 'path' ? join('', map { $_ eq '*' ? '[A-Za-z0-9._~-]{1,128}' : quotemeta } split /(\*)/, $id) : undef;
    return { site => $site, origin => $origin, kind => $kind, id => $id, reason => $reason, class => $class, caps => $caps, justification => $r->{justification},
        source => $r->{source}, reviewer => $r->{reviewer}, reviewed => $r->{reviewed}, pattern => $pattern, key => "$site\t$origin\t$kind $id\t$class" };
}

sub curated_on {                          # [C26] E2: the curated rules in use and not switched off by you
    my ($layers) = @_;
    $layers //= permit_layers();
    return if $layers->{all};
    return grep { !$layers->{off}{ $_->{key} } } @{ curated()->{rules} };
}

sub permit_curated {                      # [C26] E2: the curated rule that holds for this script on the page at $url, or nothing: of its site and class, of a kind its class holds for, of its origin, its bytes by their SHA-256 or the path they were fetched from by its pattern, the capabilities asked covered; never on a page for signing in
    my ($site, $kind, $origin, $sha, $caps, $url) = @_;
    return if permit_signin($url);
    my $class = permit_class($kind);
    for my $rule (curated_on()) {
        next unless $rule->{site} eq $site && $rule->{class} eq $class && $rule->{origin} eq $origin && grep({ $_ eq $kind } permit_kinds($class, $origin)) && permit_covers($rule->{caps}, $caps);
        return $rule if $rule->{kind} eq 'sha256' ? $rule->{id} eq $sha : ($PERMIT_PATHS{"$site $origin $sha"} // '') =~ /\A$rule->{pattern}\z/;
    }
    return;
}

sub permit_refused {                      # [C26] bytes you denied for the class of this kind: a Deny rule of the site for them, whatever capabilities it names, or your Deny in this window
    my ($site, $kind, $origin, $sha, $rules) = @_;
    my $class = permit_class($kind);
    return 1 if $PERMIT_DENIED{$site} && $PERMIT_DENIED{$site}{"$class $origin $sha"};
    return scalar grep { $_->[0] eq 'deny' && $_->[1] eq $site && $_->[2] eq $class && $_->[3] eq $origin && $_->[4] eq $sha } @$rules;
}

sub permit_decided {                      # [C26] the policy, in its order, for a script on the page at $url: "always", "once" or "deny"; in a list, also the layer that decided: "e1", "e2", "e3", or "none" for a deny no rule of yours names
    my ($site, $kind, $origin, $sha, $caps, $rules, $url) = @_;
    my $said = sub { return wantarray ? @_ : $_[0] };
    return $said->('deny', 'e3') if permit_refused($site, $kind, $origin, $sha, $rules);    # your Deny wins over E1 and E2
    my $layer = permit_site($site, $rules, $url);
    return $said->('deny', 'none') unless $layer;
    my $class = permit_class($kind);
    return $said->('once', 'e1') if ($layer eq 'person' || permit_layers()->{e1}) && $kind =~ /\A(?:inline|external|module|handler)\z/ && ($origin eq 'inline' || $origin eq $site) && permit_covers(join(',', keys %PERMIT_E1), $caps);    # E1: never data: or blob:, which are neither
    return $said->('once', 'e2') if permit_curated($site, $kind, $origin, $sha, $caps, $url);    # E2, a curated rule
    return $said->('always', 'e3') if grep { $_->[0] eq 'always' && $_->[1] eq $site && $_->[2] eq $class && $_->[3] eq $origin && $_->[4] eq $sha && permit_covers($_->[5], $caps) } @$rules;    # E3, your rules, of the class asked
    my $once = $PERMIT_ONCE{$site};
    return $said->('once', 'e3') if $once && grep { my ($k, $o, $s, $c) = split / /; $k eq $kind && $o eq $origin && $s eq $sha && permit_covers($c, $caps) } keys %{ $once->{keys} };    # your Allow Once, of the kind asked
    return $said->('deny', 'none');
}

sub permit_queued {                       # [C26] a script no rule allows, kept to put to you once the visit shown is drawn: of that visit's site only, once each, at most $PERMIT_QUEUE, and nothing you denied in this window
    my ($site, $kind, $origin, $sha, $caps) = @_;
    my $ask = $PERMIT_ASK;
    return unless $ask && $ask->{site} eq $site && !($PERMIT_DENIED{$site} && ($PERMIT_DENIED{$site}{''} || $PERMIT_DENIED{$site}{permit_class($kind) . " $origin $sha"}));
    my $key = "$kind $origin $sha $caps";
    return if $ask->{items}{$key} || keys %{ $ask->{items} } >= $PERMIT_QUEUE;
    $ask->{items}{$key} = [$kind, $origin, $sha, $caps];
}

# The frame of a page run, after its style sheets: "=permits N", then N
# lines, at most $PERMITS_MOST with this one: "page allow" or "page deny",
# then "always KIND ORIGIN SHA256" or "deny KIND ORIGIN SHA256" for each
# decision lzrprf holds for the site (your rules, and a curated rule by
# SHA-256 while the site may run scripts), a Deny first. A rule is told for each
# kind of its class (sub permit_kinds); Allow Once is told as "always", for
# the kind it was given to and this visit only. What does not fit is asked by the page (sub
# live_permitted) and answered by the same rules.
sub permit_page {                         # [C26] the frame for a page run of $url; with "page deny" the answer, $$got, loses its scripts first (sub permit_stripped)
    my ($url, $got) = @_;
    my ($host) = $url =~ m{^https://([^/?#:]+)};
    $host = lc($host // '');
    my $site = "https://$host";
    permit_password($url, $$got);         # a page with a password field is one for signing in: no sandbox and no curated rule
    my ($rules) = permit_rules();
    my $allowed = permit_site($site, $rules, $url);
    my %line;
    my $one = sub { my ($word, $id) = @_; $line{$id} = $word if $word eq 'deny' || !$line{$id} };
    my $put = sub { my ($word, $class, $origin, $sha) = @_; $one->($word, "$_ $origin $sha") for permit_kinds($class, $origin) };
    $put->(@$_[0, 2, 3, 4]) for grep { $_->[1] eq $site } @$rules;
    $put->('always', @$_{qw(class origin id)}) for $allowed && !permit_signin($url) ? grep { $_->{site} eq $site && $_->{kind} eq 'sha256' } curated_on() : ();    # E2: a curated rule by SHA-256; one by path pattern is answered when the page asks (sub live_permitted)
    $one->('always', join ' ', (split / /)[0 .. 2]) for keys %{ ($PERMIT_ONCE{$site} // {})->{keys} // {} };
    $put->('deny', split / /) for grep { length } keys %{ $PERMIT_DENIED{$site} // {} };
    my ($stripped, $count, $inline) = permit_stripped($$got);
    my ($path) = $url =~ m{\Ahttps://[^/?#]+(/[^?#]*)};
    my @parts = map { permit_part($url, $host . ($path // '/'), @$_) } @$inline;    # [C26] every part taken out by its name: [kind, origin, identity, name, where, text]
    permit_info($site, @$_[1 .. 5]) for @parts;    # each one's name and source, for the question about it
    if (!$allowed) {
        if ($count) {
            $$got = $stripped;
            if ($PERMIT_ASK && $PERMIT_ASK->{site} eq $site) {
                $PERMIT_ASK->{stripped} = $count - grep { permit_refused($site, @$_[0 .. 2], $rules) } @parts;    # a part a Deny Always of yours names is not asked about again
                permit_queued($site, @$_[0 .. 2], '-') for @parts;
            }
            noted("lzrprf took $count script " . ($count == 1 ? 'part' : 'parts') . " out of $url before it was laid out: the scripts of $host are not allowed");
        }
    }
    my @lines = sort { ($line{$b} eq 'deny') <=> ($line{$a} eq 'deny') || $a cmp $b } keys %line;
    splice @lines, $PERMITS_MOST - 1 if @lines > $PERMITS_MOST - 1;
    @lines = ('page ' . ($allowed ? 'allow' : 'deny'), map { "$line{$_} $_" } @lines);
    return '=permits ' . @lines . "\n" . join('', map { "$_\n" } @lines);
}

sub permit_stripped {                     # [C26] an answer as curl gave it, with the scripts taken out of its body (sub permit_body) and its length said anew; the same answer when nothing was taken out. Returns it, how many parts were taken out, and [kind, sha256, text] of each inline script and handler
    my ($got) = @_;
    my $before = '';
    while ($got =~ s{\A(HTTP/1\.[01] 1[0-9][0-9][^\r\n]*\r\n(?:[^\r\n]+\r\n)*\r\n)}{}) { $before .= $1 }    # an interim answer goes before the answer
    my ($head, $body) = $got =~ m{\A(HTTP/1\.[01] [0-9]{3}[^\r\n]*\r\n(?:[^\r\n]+\r\n)*)\r\n(.*)\z}s or return ($before . $got, 0, []);
    return ($before . $got, 0, []) if $head =~ m{^content-type:[ \t]*(?:image|audio|video|font)/}mi;    # bytes that are no document
    my $text = $body;
    $text = unchunked($body) if $head =~ /^transfer-encoding:[ \t]*chunked[ \t]*\r?$/mi;
    $text = undef if $head =~ /^content-encoding:[ \t]*(?!identity\b)[^\s]/mi;    # lzrprf asks for none (Accept-Encoding: identity) and reads none
    my ($html, $count, $inline) = defined $text ? permit_body($text) : ('', length($body) ? 1 : 0, []);    # a body lzrprf cannot read is not handed over
    return ($before . $got, 0, []) unless $count;
    $head =~ s/^(?:content-length|transfer-encoding|content-encoding):[^\r\n]*\r\n//mgi;
    return ("$before${head}Content-Length: " . length($html) . "\r\n\r\n$html", $count, $inline);
}

sub permit_body {                         # [C26] a document with every script element, every attribute named on..., every srcdoc and every attribute whose value is a javascript: or vbscript: address taken out, read once from its start to its end; it will never read exactly as the engine's parser does, which refuses on its own. Returns it, how many parts were taken out, and [kind, sha256, text] of each script element's text that names no src and of each handler's text as written
    my ($html) = @_;
    my ($out, $count, @inline) = ('', 0);
    my $rest = sub {                      # what follows a tag's name up to its ">", which is passed: a quoted value holds a ">", and one never closed runs to the end, as a browser reads it. A step at a time, so a tag of a million quoted values costs what its bytes do
        my $from = pos($html);
        1 while $html =~ /\G[^>"']+/gc || $html =~ /\G"[^"]*(?:"|\z)/gc || $html =~ /\G'[^']*(?:'|\z)/gc;
        my $attrs = substr($html, $from, pos($html) - $from);
        return ($attrs, $html =~ /\G>/gc ? '>' : '');
    };
    pos($html) = 0;
    while (pos($html) < length $html) {
        if ($html =~ /\G([^<]+)/gc) { $out .= $1; next }
        if ($html =~ /\G(<!--.*?(?:-->|\z))/gcs) { $out .= $1; next }
        if ($html =~ /\G<script(?=[\s\/>]|\z)/gci) {
            my ($attrs) = $rest->();
            my $from = pos($html);
            my $to = $html =~ /\G.*?(?=<\/script[\s\/>])/gcsi ? pos($html) : length $html;
            my ($src) = map { defined ? $_ : () } $attrs =~ /(?:\A|[\s"'\/])src\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]*))/i;
            push @inline, defined $src ? ['src', '', $src, ''] : ['inline', Digest::SHA::sha256_hex(substr($html, $from, $to - $from)), substr($html, $from, $to - $from), 'inline script'];    # a script file by its address, which is not fetched
            pos($html) = $to;
            $html =~ /\G<\/script[^>]*>?/gci;
            $count++;
            next;
        }
        if ($html =~ /\G<([A-Za-z][^\s\/>]*)/gc) {
            my $name = $1;
            my ($attrs, $end) = $rest->();
            my ($kept, $n, @parts) = permit_tag($attrs);
            push @inline, map { [$_->[0], Digest::SHA::sha256_hex($_->[1]), $_->[1], $_->[2]] } @parts;
            $count += $n;
            $out .= '<' . $name . ($n ? $kept : $attrs) . $end;
            next;
        }
        $html =~ /\G</gc;
        $out .= '<';
    }
    return ($out, $count, \@inline);
}

sub permit_tag {                          # [C26] a tag's attributes without those that would run: named on..., srcdoc, or holding a javascript: or vbscript: address; how many were taken out; and the text of each handler as written
    my ($attrs) = @_;
    my ($kept, $n, @handlers) = ('', 0);
    pos($attrs) = 0;
    while ($attrs =~ /\G([\s\/]*)([^\s\/>=]+|=[^\s\/>=]*)((?:\s*=\s*(?:"([^"]*)(?:"|\z)|'([^']*)(?:'|\z)|([^\s>]*)))?)/gc) {
        my ($gap, $name, $value, $said) = ($1, $2, $3, $4 // $5 // $6 // '');
        if ($name =~ /\Aon/i) { push @handlers, ['handler', $said, 'handler']; $n++; next }
        if (lc $name eq 'srcdoc') { push @handlers, ['inline', $said, 'srcdoc']; $n++; next }    # a frame's document: its scripts are named by the document's identity
        if (length $value && permit_scripted($said)) { push @handlers, ['handler', $said, 'script address']; $n++; next }
        $kept .= (length $gap ? $gap : ' ') . $name . $value;
    }
    return ($kept . substr($attrs, pos($attrs) // 0), $n, @handlers);
}

sub permit_scripted {                     # [C26] whether an attribute's value is an address that runs a script, read as a browser reads it: character references decoded, every space and control character dropped, any case; also as the address of a refresh ("0;url=javascript:...")
    my ($value) = @_;
    $value =~ s/&#[xX]0*([0-9a-fA-F]{1,6});?/hex($1) > 0x10ffff ? '' : chr hex $1/ge;
    $value =~ s/&#0*([0-9]{1,7});?/$1 > 0x10ffff ? '' : chr $1/ge;
    $value =~ s/&colon;/:/gi;
    $value =~ s/&(?:tab|newline);//gi;
    $value =~ s/[\x00-\x20\x7f]+//g;
    return lc($value) =~ /(?:\A|url=)['"]?(?:javascript|vbscript):/;
}

sub live_permitted {                      # [C26] "=permit KIND ORIGIN SHA256 CAPS" of a page: answered at once, "=permitted always", "once" or "deny" (sub permit_decided), one answer for each in its order; what no rule allows is denied and kept to put to you once the page is drawn, so no question ever holds a page
    my ($live, $line) = @_;
    my ($kind, $origin, $sha, $caps) = $line =~ /\A=permit ($PERMIT_KIND) ($PERMIT_ORIGIN) ([0-9a-f]{64}) ($PERMIT_CAPS)\z/ or return live_end($live, 'it wrote a line of no form');
    return live_end($live, "it asked more than $LIVE_PERMIT_MOST times whether a script may run") if ++$live->{permits} > $LIVE_PERMIT_MOST;
    $origin = lc $origin;
    my $site = "https://$live->{host}";
    my ($rules) = permit_rules();
    my ($said, $layer) = permit_decided($site, $kind, $origin, $sha, $caps, $rules, $live->{url});
    permit_queued($site, $kind, $origin, $sha, $caps) if $said eq 'deny' && !permit_refused($site, $kind, $origin, $sha, $rules);
    my $what = "$kind script " . ($origin eq 'inline' ? 'in the page' : "from $origin") . ' ' . substr($sha, 0, 12);
    permit_seen($layer, $site, $what, 'ran') if $layer =~ /\Ae[12]\z/;    # [C26] what E1 and E2 decided, for Script permissions
    permit_seen('e1', $site, $what, 'asked') if $said eq 'deny' && $layer eq 'none' && permit_site($site, $rules, $live->{url}) eq 'sandbox';
    noted("the page $live->{url} asked to run a script ($kind, " . ($origin eq 'inline' ? 'in the page' : "from $origin") . ", capabilities $caps): " . ($said eq 'deny' ? 'not run' : "run ($said, " . { e1 => 'E1, the sandbox', e2 => 'E2, a curated rule', e3 => 'E3, your rule' }->{$layer} . ')'));
    return live_sent($live, "=permitted $said\n");
}

sub permit_visited {                      # [C26] a visit begins: what you allowed once for its site is for this visit, and what its page asks is put to you once it is drawn
    my ($url, $host) = @_;
    my $site = "https://$host";
    delete $PERMIT_DENIED{$site};         # Deny Once held for the visit it was given in, and no longer
    if (my $next = delete $PERMIT_NEXT{$site}) { $PERMIT_ONCE{$site} = $next } else { delete $PERMIT_ONCE{$site} }
    $PERMIT_ROUND = defined $PERMIT_RELOAD && $PERMIT_RELOAD eq $url ? $PERMIT_ROUND + 1 : 0;
    undef $PERMIT_RELOAD;
    $PERMIT_ASK = { site => $site, url => $url, items => {}, stripped => 0, refused => 0, boxed => 0 };
}

sub permits_asked {                       # [C26] once the page is drawn: its scripts no rule allows, and what was taken out of it or refused, put to you, each by its name and with its source: Deny Once, Deny Always, Allow Once, Always Allow. Deny Once is the first button and the answer when nobody answers; Deny Always keeps a deny rule, and a script a deny rule names is never put to you again. Returns true when the page is to be loaded again with what you allowed
    my $ask = $PERMIT_ASK or return 0;
    return 0 unless ($TABS[$TAB]{url} // '') eq $ask->{url};
    my $site = $ask->{site};
    my ($rules) = permit_rules();
    my $allowed = permit_site($site, $rules, $ask->{url});
    my @items = grep { permit_decided($site, @$_, $rules, $ask->{url}) eq 'deny' && !permit_refused($site, @$_[0 .. 2], $rules) } map { $ask->{items}{$_} } sort keys %{ $ask->{items} };
    my $blocked = $allowed || ($PERMIT_DENIED{$site} && $PERMIT_DENIED{$site}{''}) ? 0 : $ask->{stripped} + $ask->{refused};
    my $boxed = $allowed eq 'sandbox' ? $ask->{boxed} // 0 : 0;    # what the sandbox refused: said when you are asked, never a question of its own
    ($ask->{items}, $ask->{stripped}, $ask->{refused}, $ask->{boxed}) = ({}, 0, 0, 0);
    return 0 unless @items || $blocked;
    my ($host) = $site =~ m{^https://(.*)\z};
    my (@from, @text);                    # each script by its name, where it is, its size and who runs it when known; a script that wants to turn text into code (class "strings") is named on its own
    for my $item (@items) {
        my ($name, $where, $bytes, $who) = permit_named($site, @$item[0 .. 2]);
        push @{ permit_class($item->[0]) eq 'strings' ? \@text : \@from }, "$name (" . join(', ', $where, ($bytes ? "$bytes bytes" : ()), (length $who ? $who : ())) . ')';
        $PERMIT_WEB{ join "\t", $site, permit_class($item->[0]), @$item[1, 2] } //= [$site, @$item];    # for LZRDFNDR's On Websites
    }
    %PERMIT_WEB = () if keys %PERMIT_WEB > $PERMIT_RULES;
    my $words = "$host has scripts that did not run. " . (@from ? 'Not allowed: ' . join('; ', @from) . '. ' : '') . (@text ? 'Scripts that want to turn text into code (eval): ' . join('; ', @text) . '. ' : '') . ($blocked ? "lzrprf took $blocked script " . ($blocked == 1 ? 'part' : 'parts') . ' out of the page or refused ' . ($blocked == 1 ? 'it' : 'them') . '. ' : '')
        . ($allowed eq 'sandbox' ? (permit_layers()->{e1} ? "Its own scripts ran in lzrprf's sandbox" : "The scripts its curated rules name ran in lzrprf's sandbox") . ($boxed ? ", which refused $boxed " . ($boxed == 1 ? 'request' : 'requests') . ' to send or to fetch from another site' : '') . '. ' : '')
        . 'Deny Once keeps them from running on this visit; Deny Always keeps a deny rule in LZRDFNDR scripts. Allow Once runs them on this visit' . ($allowed eq 'sandbox' ? ', outside the sandbox' : '') . '; Always Allow keeps a rule in LZRDFNDR scripts' . ($allowed eq 'sandbox' ? ', and the site leaves the sandbox.' : '.');
    my $i = 0;
    window(map { my ($name, $where, $bytes, $who) = permit_named($site, @$_[0 .. 2]); my $info = $PERMIT_INFO{"$site $_->[1] $_->[2]"}; my $source = $info ? $info->{source} : '';
        'permitscript ' . join("\t", $i++, $name, $where, $bytes, $who, length $source, MIME::Base64::encode_base64($source, '')) } @items);    # [C26] each script with its source, shown in the question as text that never runs
    my $press = asked("permit $site\t$words", 'Deny Once', 'Deny Always', 'Allow Once', 'Always Allow');
    if ($press == 1 || $press == 2) {
        $PERMIT_DENIED{$site}{''} = 1 unless $allowed;    # not asked again on this visit
        $PERMIT_DENIED{$site}{permit_class($_->[0]) . " $_->[1] $_->[2]"} = 1 for @items;
        if ($press == 1) { noted("you did not allow the scripts of $host on this visit (Deny Once): nothing is kept, and the next visit asks again"); return 0 }
        my $date = strftime('%Y-%m-%d', gmtime);
        my $kept = !@items ? '' : permit_stored(sub {
            my ($rules, $memory) = @_;
            for my $item (@items) {
                my ($kind, $origin, $sha, $caps) = @$item;
                my $class = permit_class($kind);
                @$rules = grep { !($_->[1] eq $site && $_->[2] eq $class && $_->[3] eq $origin && $_->[4] eq $sha && !($memory && $_->[7] eq 'file')) } @$rules;
                push @$rules, ['deny', $site, $class, $origin, $sha, $caps, $date];
            }
            return 1;
        }) // '';
        my $said = !@items ? 'The page named no script to keep a deny rule for, so nothing is kept and the next visit asks again.' : $kept eq 'file' ? 'Kept as deny rules in LZRDFNDR scripts: they are not asked about again.' : $kept eq 'memory' ? ($INCOGNITO ? 'Kept in the memory of this incognito window only.' : kept_in() . "/scripts is not a file lzrprf reads, so the deny rule is kept in this window's memory only.") : 'The deny rule could not be written, so they are refused on this visit only.';
        noted("you denied the scripts of $host always: $said");
        idle($said);
        return 0;
    }
    $press -= 1;                          # Allow Once and Always Allow, as they were numbered before Deny Always stood beside Deny
    $PERMIT_NEXT{$site} = { keys => { %{ ($PERMIT_ONCE{$site} // {})->{keys} // {} }, map { (join(' ', @$_) => 1) } @items } };    # also after Always Allow: what could not be kept still runs on the reload
    my $kept = '';
    if ($press == 3 && @items) {
        my $date = strftime('%Y-%m-%d', gmtime);
        $kept = permit_stored(sub {
            my ($rules, $memory) = @_;
            for my $item (@items) {
                my ($kind, $origin, $sha, $caps) = @$item;
                my $class = permit_class($kind);    # the class of the kind asked: an Always for a script's code never lets it turn text into code
                my @caps = split /,/, $caps eq '-' ? '' : $caps;
                @$rules = grep {
                    my $same = $_->[1] eq $site && $_->[2] eq $class && $_->[3] eq $origin && $_->[4] eq $sha && !($memory && $_->[7] eq 'file');
                    push @caps, split /,/, $_->[5] eq '-' ? '' : $_->[5] if $same && $_->[0] eq 'always';
                    !$same;
                } @$rules;
                my %seen;
                my @all = grep { !$seen{$_}++ } sort @caps;
                push @$rules, ['always', $site, $class, $origin, $sha, @all > 32 ? $caps : join(',', @all) || '-', $date];
            }
            return 1;
        }) // '';
    }
    my $said = $press == 2 ? 'Allowed on this visit.' : !@items ? 'The page named no script to keep a rule for yet, so its scripts run on this visit, and what they ask is put to you again.' : $kept eq 'file' ? 'Kept in LZRDFNDR scripts.' : $kept eq 'memory' ? ($INCOGNITO ? 'Kept in the memory of this incognito window only.' : kept_in() . "/scripts is not a file lzrprf reads, so the rule is kept in this window's memory only.") : 'The rule could not be written, so they run on this visit only.';
    noted("you allowed the scripts of $host " . ($press == 2 ? 'once' : 'always') . ": $said");
    if ($PERMIT_ROUND >= $PERMIT_ROUNDS) { idle("$said Reload the page to run them."); return 0 }    # your Allow loaded this address again often enough in a row: the next is yours
    $PERMIT_RELOAD = $ask->{url};
    idle("$said lzrprf loads the page again.");
    return 1;
}

sub permits_later {                       # [C26] what a page kept running asked meanwhile, put to you after it answered; on an Allow it is loaded again
    return unless $PERMIT_ASK && (%{ $PERMIT_ASK->{items} } || $PERMIT_ASK->{refused});
    go($PERMIT_ASK->{url}, 'you reloaded') if permits_asked();
}

sub scripts_set {                         # [C26] [C4] Script permissions, from the cogwheel's menu: "list"; "revoke" and "set" (to always or deny) of the rule numbered $n in the list; "reset", every rule of yours removed; "e1" on or off; "curated" $n on or off. The list is told again after each
    my ($what, $n, $to) = @_;
    my $words = '';
    if ($what eq 'e1' || $what eq 'curated') { $words = scripts_layer($what, $n, $to) }    # E1's switch, or a curated rule's (E2)
    elsif ($what ne 'list') {
        my $date = strftime('%Y-%m-%d', gmtime);
        my $done = permit_stored(sub {
            my ($rules, $memory) = @_;
            if ($what eq 'reset') { my $had = @$rules; @$rules = $memory ? grep { $_->[7] eq 'file' } @$rules : (); return $had != @$rules || !$memory }
            return 0 unless $rules->[$n];
            if ($what eq 'revoke') { splice @$rules, $n, 1 } else { @{ $rules->[$n] }[0, 6] = ($to, $date) }
            return 1;
        });
        my $unread = (permit_rules())[1];
        $words = !$done ? ($INCOGNITO ? "$UNKEPT: a rule of the scripts file is not changed in it. Nothing was changed." : $unread ? kept_in() . '/scripts is not a file lzrprf reads, so it is not changed. Nothing was changed.' : 'Nothing was changed: that rule is no longer there, or the scripts file could not be written.')
            : $what eq 'reset' ? ($done eq 'memory' ? "Every script permission of this window's memory is removed." : 'Every script permission is removed.')
            : $what eq 'revoke' ? 'The rule is removed: its script is asked about again.'
            : "The rule now says $to.";
    }
    scripts_told();
    my ($rules) = permit_rules();
    return idle(length $words ? $words : 'LZRDFNDR scripts: ' . @$rules . (@$rules == 1 ? ' rule.' : ' rules.'));
}

sub scripts_layer {                       # [C26] [C4] a switch of Script permissions: "e1" on or off, the sandbox; "curated" N on or off, the curated rule numbered N in the list. Kept under the lock of the settings (sub permit_layers_kept). Returns what to say
    my ($what, $n, $to) = @_;
    my $lock = $INCOGNITO ? 1 : keep_lock();
    return 'Nothing was changed: the lock of the settings could not be taken.' unless $lock;
    my $layers = permit_layers();
    return kept_in() . '/scriptlayers is not a file lzrprf reads, so the sandbox and every curated rule stay off. Nothing was changed.' if $layers->{unread};
    my $rule;
    if ($what eq 'e1') { $layers->{e1} = $to eq 'on' ? 1 : 0 }
    else {
        $rule = curated()->{rules}[$n] or return 'Nothing was changed: that curated rule is no longer there.';
        if ($to eq 'off') { $layers->{off}{ $rule->{key} } = 1 } else { delete $layers->{off}{ $rule->{key} } }
    }
    my $kept = permit_layers_kept($layers) or return 'Nothing was changed: the file scriptlayers could not be written.';
    my $where = $kept eq 'memory' ? ' in this incognito window only' : '';
    return $what eq 'e1' ? ($to eq 'on' ? "The sandbox is on$where: a site's own scripts run in it until you keep a rule for the site." : "The sandbox is off$where: a site with no rule of yours runs no script until you allow it.")
        : "The curated rule for $rule->{origin} on $rule->{site} is $to$where.";
}

sub scripts_told {                        # [C26] the list page: "scripts begin", "scripts rule N<tab>always|deny<tab>SITE<tab>CLASS<tab>ORIGIN<tab>SHA256<tab>CAPS<tab>DATE<tab>file|memory" for each rule of yours (E3); "scripts e1 on|off" and "scripts sandbox NAME<tab>runs|asks|refused|off<tab>WORDS" for each line of the sandbox's table (E1); "scripts curated N<tab>on|off<tab>SITE<tab>CLASS<tab>ORIGIN<tab>IDENTITY<tab>CAPS<tab>REVIEWER<tab>DATE" for each curated rule in use, "scripts part SITE<tab>used|ignored<tab>WHY" for each part of the file and "scripts curatedwhy WHY" when none is used (E2); "scripts seen LAYER<tab>SITE<tab>WHAT<tab>SAID<tab>COUNT" for the newest decisions of E1 and E2; then "scripts end", or "scripts end unread" when a scripts file is there and not read
    my ($rules, $unread) = permit_rules();
    my $layers = permit_layers();
    my $curated = curated();
    my $n = 0;
    window('scripts begin', (map { 'scripts rule ' . join("\t", $_, @{ $rules->[$_] }) } 0 .. $#$rules),
        'scripts e1 ' . ($layers->{e1} ? 'on' : 'off'), (map { 'scripts sandbox ' . join("\t", @$_) } @PERMIT_SANDBOX),
        (map { 'scripts curated ' . join("\t", $n++, $layers->{all} || $layers->{off}{ $_->{key} } ? 'off' : 'on', @$_{qw(site class origin)}, "$_->{kind} $_->{id}", @$_{qw(caps reviewer reviewed)}) } @{ $curated->{rules} }),
        (map { 'scripts part ' . join("\t", @$_) } @{ $curated->{parts} }), (length $curated->{why} ? "scripts curatedwhy $curated->{why}" : ()),
        (map { 'scripts seen ' . join("\t", @$_) } @PERMIT_SEEN), 'scripts end' . ($unread ? ' unread' : ''));
}

