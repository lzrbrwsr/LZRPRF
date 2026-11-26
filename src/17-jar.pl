
# The cookie jar [C7] [C12] [C16] [C17]. The owner's decision of 2026-11-24: "Yes - same domain
# should keep its cookies across pages." A site's cookies go with it from page to page, and in a
# window of a profile from visit to visit, by the standard rules: host or Domain by the public
# suffix list, Path, Expires and Max-Age by the real clock, Secure, HttpOnly (never seen by a
# script) and SameSite, every cookie kept apart by the top-level site it was set under, so a site
# embedded in two sites has two sets that never meet.
#
# The jar is not here and not in a page. It is the application's own process, a run of the program
# as a page is run (LZRPRF_JAR=1, sealed the same way, in the page container with its limits: no
# network, no file, no other program), started the first time a window needs it and kept until the
# window ends. lzrprf holds no cookie of a site in its own memory: it hands the jar the address of
# each request of a page you visit and of a page kept running, with the page it is for, and asks it
# for the request's line Cookie; it hands it each Set-Cookie line of the answer; and it hands each
# page run, in front of its answer, the cookies of the page's own site its script may see (the
# frame =jar), checked here: each line of its one form, for a host the page's host matches, with no
# letter for HttpOnly, at most $JAR_MOST, all or none. A write of the page's script comes back as a
# line =keep in front of an answer, and lzrprf hands it to the jar with the page's address as
# lzrprf knows it, never one the page names. A page in the sandbox (E1) sends no cookie and writes
# none [C26].
#
# A window of a profile keeps its lasting cookies in one file of that profile, "cookies", sealed by
# the jar with a key of 32 random bytes kept beside it in "cookies.key", both mode 600 and readable
# by you alone; lzrprf writes the sealed bytes it is handed and never reads a cookie in them. Two
# windows of a profile merge what the other wrote before they write, under a lock. An incognito
# window and a Tor window give their jar no key: it seals nothing, writes nothing, and ends with
# its window; a new Tor identity starts a new jar. No jar is shared between a profile's windows and
# an incognito one, a Tor one or LZRCHT. A provider you connected keeps its own store, as before
# (sub sso_cookie): for its family's hosts the jar is not asked. Clearing the history and the
# sessions clears the jar, the file too; Clear Cookies of This Site clears one site.
my $JAR_SECONDS = 5;                     # DECLARED: the longest one line of the jar is waited for; a jar that takes longer is ended
my $JAR_TRIES = 3;                       # DECLARED: starts of the jar in one window, so one that keeps dying is not started for ever
my $JAR_MOST = 3000;                     # DECLARED: cookies handed to one page at most, the application's own bound (MOST_IN_ALL)
my $JAR_LINE = 16384;                    # DECLARED: the longest line of one cookie either way, above the application's MOST_LINE_BYTES
my $JAR_SEALED = 64 * 1024 * 1024;       # DECLARED: the longest jar file, in hex digits: above the application's largest sealed jar
my $JAR_EVERY = 2;                       # DECLARED: seconds between two writes of the file while cookies keep coming; the last is written when the window ends
my $JAR_SET_MOST = 64;                   # DECLARED: Set-Cookie lines of one answer handed to the jar
our ($JAR, $JAR_STARTS, $JAR_SAVED) = (undef, 0, 0);
our $JAR_FOLDER;
sub jar_kept { !$INCOGNITO && !$TOR_WANTED && !$TOR && !$TOR_SESSION }    # [C16] [C17] only a window of a profile keeps a cookie past its end
sub jar_directory { $JAR_FOLDER // $DIR }
sub jar_file { jar_directory() . '/cookies' }
sub jar_skips {                           # D18: a host of a provider you connected or are connecting keeps that provider's own store, and the jar is not asked
    my ($url) = @_;
    return 0 if defined $JAR_FOLDER;
    return 0 unless sso_on();
    my ($host) = $url =~ m{\Ahttps://([^/:]+)} or return 1;
    my $key = sso_of($host) // return 0;
    return sso_state($key) ne 'none';
}
sub jar_encoded { my ($text) = @_; $text =~ s/([%\x00-\x20\x7f])/sprintf('%%%02X', ord $1)/ge; return $text }    # as the application's cookie lines encode a field

sub jar_started {                         # the window's jar: running already, or started now, sealed, handed its key and its file
    return $JAR if $JAR && $JAR->{owner} == $$;
    return if $JAR_STARTS >= $JAR_TRIES || !program_same();
    $JAR_STARTS++;
    pipe(my $in, my $to) && pipe(my $from, my $out) or return;
    my $seal = run_seal() // return;
    my $box = fork // return;
    if (!$box) {
        %ENV = (LZRPRF_CONTAINED => 'jar', LZRPRF_SEAL => $seal, LZRPRF_JAR => '1');    # no address: it lays out no page
        chdir '/';
        the_program($in, $out);           # [C1] the page container, its limits and all
    }
    close $_ for $in, $out;
    if (!inside($box)) {                  # [C3] the system did not say that it is contained: nothing is handed to it
        kill 'KILL', $box;
        waitpid $box, 0;
        record('the cookie jar was not started: the system did not say that its container holds');
        return;
    }
    fcntl($_, POSIX::F_SETFL(), O_NONBLOCK) for $to, $from;
    $JAR = { box => $box, to => $to, from => $from, owner => $$, heard => '', dirty => 0, seen => '' };
    jar_wrote("=seal $seal\n") or return;
    return $JAR unless jar_kept();
    my $loaded = jar_locked(sub {
        my $key = jar_key() // return 'its key could not be read or made';
        (jar_said("=key $key\n") // '') eq "=ok\n" or return 'it did not take its key';
        return jar_merged('load');
    });
    record("the cookie jar of this window was started, but its file was not read: $loaded; it is written again at the next change") if $loaded;
    return $JAR;
}

sub jar_locked {                          # one step on the profile's jar file, under a lock against another window of the profile
    my ($step) = @_;
    sysopen(my $lock, jar_directory() . '/cookies.lock', O_WRONLY | O_CREAT | O_NOFOLLOW, 0600) or return 'its lock could not be had';
    flock $lock, LOCK_EX or return 'its lock could not be had';
    return $step->();
}

sub jar_key {                             # the profile's key for its jar file: 64 hex digits in cookies.key, made once of 32 random bytes; nothing when it is not a plain file of yours alone
    my $file = jar_directory() . '/cookies.key';
    if (sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW)) {
        my @is = stat $in;
        return unless -f _ && $is[4] == $< && !($is[2] & 077) && $is[7] <= 65;
        my $line = <$in> // '';
        return $line =~ /\A([0-9a-f]{64})\n?\z/ ? $1 : undef;
    }
    return unless $!{ENOENT};
    open my $random, '<:raw', '/dev/urandom' or return;
    read($random, my $bytes, 32) == 32 or return;
    my $key = unpack 'H*', $bytes;
    return put($file, O_EXCL, $key) ? $key : undef;
}

sub jar_stamp { my @is = lstat jar_file(); return -f _ ? "$is[1] $is[9] $is[7]" : '' }    # which file is there now: its number, its time and its length

sub jar_merged {                          # the file into the running jar when another window wrote it since: 'load' the first time; an error in words, or nothing
    my ($how) = @_;
    my $stamp = jar_stamp();
    return if $stamp eq $JAR->{seen};
    sysopen(my $in, jar_file(), O_RDONLY | O_NOFOLLOW) or return $!{ENOENT} ? undef : 'it could not be opened';
    my @is = stat $in;
    return 'it is not a plain file of yours alone' unless -f _ && $is[4] == $< && !($is[2] & 077);
    return 'it is longer than any jar' if $is[7] > $JAR_SEALED + 1;
    local $/;
    my $hex = <$in> // '';
    $hex =~ s/\s+\z//;                  # its line end: chomp takes none while the whole file is read
    $JAR->{seen} = $stamp;                # read, whatever comes of it: a file the key does not open is not read again until it changes
    my $said = jar_said(($how // 'merge') eq 'load' ? '=load' : '=merge', ' ' . time . " $hex\n") // return 'the jar did not answer';
    return $said =~ /\A=ok [0-9]+\n\z/ ? undef : $said eq "=no seal\n" ? 'its key does not open it' : 'the jar did not take it';
}

sub jar_save {                            # the jar into its file, merged first with what another window wrote since; at most every $JAR_EVERY seconds unless $now
    my ($now) = @_;
    return unless $JAR && $JAR->{owner} == $$ && $JAR->{dirty} && jar_kept();
    return if !$now && now() < $JAR_SAVED + $JAR_EVERY;
    $JAR_SAVED = now();
    my $why = jar_locked(sub {
        my $merged = jar_merged();
        open my $random, '<:raw', '/dev/urandom' or return 'no random nonce was to be had';
        read($random, my $nonce, 12) == 12 or return 'no random nonce was to be had';
        my $said = jar_said('=save ' . time . ' ' . unpack('H*', $nonce) . "\n") // return 'the jar did not answer';
        my ($sealed) = $said =~ /\A=saved ([0-9a-f]+)\n\z/ or return 'the jar did not seal it';
        my $new = jar_file() . ".new.$$";
        unlink $new;
        put($new, O_EXCL, $sealed) && rename($new, jar_file()) or (unlink($new), return 'it could not be written');
        synced(jar_directory());
        $JAR->{seen} = jar_stamp();
        $JAR->{dirty} = 0;
        return;
    });
    record("the cookies of this window were not written to its file: $why") if $why;
    return;
}

sub jar_wrote {                           # bytes to the jar within $JAR_SECONDS; false when they could not be, and then the jar is ended
    my ($bytes) = @_;
    my $until = now() + $JAR_SECONDS;
    while (length $bytes) {
        my $ready = '';
        vec($ready, fileno $JAR->{to}, 1) = 1;
        return jar_lost('it took nothing for too long') if now() >= $until;
        select(undef, $ready, undef, 0.25) > 0 or next;
        my $took = syswrite($JAR->{to}, $bytes);
        if ($took) { substr($bytes, 0, $took, '') }
        elsif (!$!{EINTR} && !$!{EAGAIN}) { return jar_lost('it stopped reading') }
    }
    return 1;
}

sub jar_line {                            # the jar's next line, with its line end, within $JAR_SECONDS and at most $most bytes; nothing when there was none, and then the jar is ended
    my ($most) = @_;
    my $until = now() + $JAR_SECONDS;
    while ((my $at = index($JAR->{heard}, "\n")) < 0) {
        return jar_lost('it wrote a line longer than any') if length $JAR->{heard} > $most;
        return jar_lost('it did not answer in time') if now() >= $until;
        my $ready = '';
        vec($ready, fileno $JAR->{from}, 1) = 1;
        select($ready, undef, undef, 0.25) > 0 or next;
        my $got = sysread($JAR->{from}, $JAR->{heard}, 1 << 20, length $JAR->{heard});
        return jar_lost('it ended') if defined $got ? !$got : !$!{EINTR} && !$!{EAGAIN};
    }
    my $at = index($JAR->{heard}, "\n");
    return jar_lost('it wrote a line longer than any') if $at >= $most;
    return substr($JAR->{heard}, 0, $at + 1, '');
}

sub jar_said {                            # one line to the jar ($word and the rest), its one line back; nothing when it did not answer in time or in form
    my ($word, $rest) = @_;
    jar_started() or return;
    jar_wrote($word . ($rest // '')) or return;
    return jar_line($word eq '=save ' || substr($word, 0, 6) eq '=save ' ? $JAR_SEALED + 64 : $JAR_LINE);
}

sub jar_lost {                            # the jar is ended, and the window goes on without it; the next need starts it again, $JAR_TRIES times a window
    my ($why) = @_;
    return unless $JAR && $JAR->{owner} == $$;
    kill 'KILL', $JAR->{box};
    waitpid $JAR->{box}, 0;
    close $_ for grep { defined } @$JAR{qw(to from)};
    undef $JAR;
    record("the cookie jar of this window was ended: $why") if defined $why;
    return;
}

sub jar_end {                             # the window ends, or its Tor identity: the jar written, then ended
    jar_save(1);
    jar_lost(undef);
    $JAR_STARTS = 0;
}

sub jar_context {                         # what the jar is told of a request: nav or sub, its method, the page it is for and who asked
    my ($url, $page, $ask) = @_;
    return ('nav', 'GET', $url, '-') if $page;
    return ('sub', $ask->{method}, $ask->{top}, $ask->{top});
}

sub jar_cookie {                          # the line Cookie the jar gives a request, or nothing
    my ($url, $page, $ask) = @_;
    return unless $JAR || jar_kept() && -e jar_file();    # no jar has started and none is kept: it holds nothing yet
    jar_merged() if jar_kept() && jar_started();
    my $said = jar_said('=ask ', join(' ', time, jar_context($url, $page, $ask), $url) . "\n") // return;
    my ($value) = $said =~ /\A=cookie ([\x20-\x7e]{1,16000})\n\z/ or return;
    return "Cookie: $value";
}

sub jar_heard {                           # each Set-Cookie line of an answer to the jar; the file written when a lasting cookie changed
    my ($url, $page, $ask, $got) = @_;
    my ($head) = $got =~ /\A(.*?)\r?\n\r?\n/s or return;
    my @set = $head =~ /^set-cookie:[ \t]*([^\r\n]{1,8192})/mgi or return;
    splice @set, $JAR_SET_MOST if @set > $JAR_SET_MOST;
    my $context = join ' ', jar_context($url, $page, $ask), $url;
    for (@set) {
        my $said = jar_said('=heard ', join(' ', time, $context, jar_encoded($_)) . "\n") // last;
        $JAR->{dirty} = 1 if $said eq "=kept\n";
    }
    jar_save();
}

sub jar_kept_write {                      # a line =keep of a page kept running: the page's script set a cookie, judged by the jar against the page's address as lzrprf knows it
    my ($live, $raw) = @_;
    if ($live->{kept_app} && !defined $JAR_FOLDER) {
        my $app = $live->{kept_app};
        return unless kept_app_valid($app, $live->{url});
        return kept_app_jar($app, sub { jar_kept_write($live, $raw) });
    }
    return if $live->{home} || jar_skips($live->{url});    # the local home has no site; a provider's family keeps its own store
    my ($rules) = permit_rules();
    return if !defined $JAR_FOLDER && permit_site("https://$live->{host}", $rules, $live->{url}) eq 'sandbox';    # [C26] E1 writes nothing for the site
    my $said = jar_said('=script ', join(' ', time, $live->{url}, $raw) . "\n") // return;
    $JAR->{dirty} = 1 if $said eq "=kept\n";
    jar_save();
}

sub jar_frame {                           # the =jar frame of a page run: the cookies of the page's own site its script may see, each checked here, all or none
    my ($url) = @_;
    return "=jar 0\n" if !$JAR && !(jar_kept() && -e jar_file()) || jar_skips($url);
    jar_merged() if jar_kept() && jar_started();
    my $said = jar_said('=page ', time . " $url\n") // return "=jar 0\n";
    my ($count) = $said =~ /\A=jar (0|[1-9][0-9]{0,3})\n\z/ or return "=jar 0\n";
    return "=jar 0\n" if $count > $JAR_MOST;
    my ($host) = $url =~ m{\Ahttps?://([^/:?#]+)} or return "=jar 0\n";
    my @lines;
    for (1 .. $count) {
        my $line = jar_line($JAR_LINE) // return "=jar 0\n";
        my ($domain) = $line =~ m{\A=cookie (?:0|[1-9][0-9]{0,11}) (?:session|-?[0-9]{1,12}) h?s?[SLND] ([\x21-\x7e]{1,253}) [^\x00-\x20\x7f]{1,4000} [^\x00-\x20\x7f]{1,16000}\n\z} or return "=jar 0\n";
        return "=jar 0\n" unless $host eq $domain || substr($host, -length(".$domain")) eq ".$domain";    # a cookie of another site never reaches a page
        push @lines, $line;
    }
    return join '', "=jar $count\n", @lines;
}

sub jar_clear {                           # every cookie of this window's kind: the jar emptied, and its file written so other windows of the profile drop theirs at their next merge
    return 0 unless $JAR || jar_kept() && -e jar_file();
    my $said = jar_said('=clear ', time . "\n") // return 0;
    my ($gone) = $said =~ /\A=ok ([0-9]+)\n\z/ or return 0;
    $JAR->{dirty} = 1;
    jar_save(1);
    return $gone;
}

sub jar_forget {                          # the cookies of one site, under every top-level site, and its cookies set under it
    my ($url) = @_;
    return 0 unless $JAR || jar_kept() && -e jar_file();
    my $said = jar_said('=forget ', time . " $url\n") // return 0;
    my ($gone) = $said =~ /\A=ok ([0-9]+)\n\z/ or return 0;
    $JAR->{dirty} = 1;
    jar_save(1);
    return $gone;
}
