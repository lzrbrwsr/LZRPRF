# The live debug link [C31]. Off until you switch it on in the cogwheel's menu
# ("Live debug link"), in a window that is neither incognito nor Tor; on, it
# holds for $LINK_SECONDS and then ends by itself, and the same row turns it
# off sooner. While it is on, and only then:
#   - lzrprf writes the timeline of each load (the lines scripts/load-timeline.pl
#     writes, "[load-timeline] event=KIND key=value ... | words", each with
#     session=link-ID) and its errors to a spool of its own, link/spool;
#   - a process of its own, one at a time, sends that spool every few seconds
#     to the LZRBRWSR project's staging ingest ($LINK_BASE), as a fixed request
#     is sent (sub fixed: written in your log first, curl in its container),
#     and the answer carries the commands waiting for this link, if any;
#   - lzrprf runs a command only when it is signed for namespace
#     $LINK_NAMESPACE by an approval key lzrprf carries (sub signature_holds,
#     the verifier container of the updates), names this link's id, has a
#     nonce never seen before and an expiry in the next $LINK_COMMAND_SECONDS.
#     Anything else is refused and written down: the link fails closed.
#     On this Mac a command may also be laid as a file, link/command.NAME,
#     once a plain file link/local exists: it is the same signed block and
#     passes the same checks (no command runs unsigned), it is only taken
#     within a fraction of a second, and the link's lines are then also
#     written to link/local.log, so a measuring loop here waits for no send.
#     The commands are six, and only these: open an address in a new tab,
#     reload the tab shown, measure the load of an address, a snapshot of the
#     tabs and timings, the verbosity of the lines, and a picture of the
#     window as it draws itself (never a capture of the screen). None runs a
#     program, reads a file or reaches a shell.
# What is sent: times, an address's scheme, host and path (parts of a path
# that look like a token withheld), status codes, sizes, errors in lzrprf's
# own words with every address cut so. Never: cookies, what you type or
# paste, form contents, the text of a page, a query or a fragment. The window
# shows a badge with the link's id and its end the whole time, and each
# command is written in the log and said in the badge.
# SYNC: managed-projects/lzrbrwsr/architecture/live-debug-link.md ; src/28-window-link.pl ;
#       the staging ingest of the box (system/lzrbrwsr-staging, its /link door) ; managed-projects/lzrbrwsr/sign/server.mjs (POST /debug) ;
#       managed-projects/lzrbrwsr/scripts/debug-link.sh ; managed-projects/lzrbrwsr/docs/load-speed.md (the line format)
my $LINK_BASE = 'https://staging.lzrbrwsr.com/link/';    # [C31] the one place the link sends to
my $LINK_HOST = 'staging.lzrbrwsr.com';
my $LINK_NAMESPACE = 'lzrbrwsr-debug-link';    # [C31] what a command's signature says it was made for: a release approval never holds as a command, nor a command as an approval
my $LINK_SECONDS = 24 * 3600;             # DECLARED([C31] how long the link holds once switched on)
my $LINK_COMMAND_SECONDS = 900;           # DECLARED([C31] the latest a command's expiry may be, from now)
my $LINK_SPOOL_BYTES = 4 * 1024 * 1024;   # DECLARED([C31] the most the spool holds while nothing is sent; lines past it are counted and dropped)
my $LINK_BATCH_BYTES = 768 * 1024;        # DECLARED([C31] the most one send carries: the ingest takes 1 MiB)
my $LINK_SHOT_SECONDS = 5;                # DECLARED([C31] the least time between two pictures of the window)
my $LINK_LOCAL_BYTES = 16 * 1024 * 1024;  # DECLARED([C31] the most link/local.log holds; lines past it are left out of it)
my $LINK_LOCAL_WAIT = 0.2;               # DECLARED([C31] seconds between two looks for a command laid on this Mac while the local lane is on)
my %LINK = (verbosity => 1);              # [C31] this process's view of the link: on, id, key, until, the child sending, when next
my %LINK_ORIG;                            # [C31] the subs the link wraps while it is on, as they were

sub link_folder { return "${\ shared()}/link" }
sub link_state {                          # [C31] the link as its file holds it, read at most once in two seconds: (id, key, until) or nothing while it is off
    return if $INCOGNITO || $TOR_WINDOW || $LINK{child};
    my $now = time;
    if (!defined $LINK{read} || $now - $LINK{read} >= 2) {
        $LINK{read} = $now;
        my ($id, $key, $until, $verbosity);
        if (open my $in, '<', link_folder() . '/on') { (<$in> // '') =~ /\A([0-9a-f]{12}) ([0-9a-f]{64}) ([0-9]{10}) ([012])\n?\z/ and ($id, $key, $until, $verbosity) = ($1, $2, $3, $4); close $in }
        my $was = $LINK{id};
        @LINK{qw(id key until verbosity)} = ($id, $key, $until, $verbosity // 1);
        my $near = $id ? link_plain(link_folder() . '/local') : undef;
        $LINK{local} = !defined $near ? 0 : $near ? 2 : 1;    # the local lane: asked for on this Mac by a plain file of yours beside the link's own; a file that holds anything asks for this Mac only (2): no line is kept for the sender and nothing is sent
        if ($id && $until <= $now) { link_off('its 24 hours were over'); return }
        if (!$id && $was) { window('link off') }
        elsif ($id && ($was // '') ne $id) { window("link on $id $until") }    # switched on in another window of yours: this one shows the badge too
        link_wrap() if $id;
    }
    return $LINK{id} ? @LINK{qw(id key until)} : ();
}
sub link_on { return scalar(() = link_state()) ? 1 : 0 }
sub link_random { my ($n) = @_; open my $in, '<', '/dev/urandom' or return; my $got = ''; read($in, $got, $n) == $n or return; close $in; return unpack 'H*', $got }

sub link_menu {                           # [C31] "menu debug-link" from the cogwheel's menu: on when off, off when on
    return idle('The live debug link is not available in an incognito or Tor window: it would write and send, and such a window does neither.') if $INCOGNITO || $TOR_WINDOW;
    return link_off('you turned it off in the cogwheel\'s menu') if link_on();
    my ($id, $key) = (link_random(6), link_random(32));
    return idle('The live debug link could not be turned on: no random number was read.') unless $id && $key;
    my $dir = link_folder();
    mkdir $dir, 0700 unless -d $dir;
    my $until = time + $LINK_SECONDS;
    unlink "$dir/on.new";
    return idle('The live debug link could not be turned on: its setting could not be written.') unless put("$dir/on.new", O_EXCL, "$id $key $until 1") && rename("$dir/on.new", "$dir/on");
    undef $LINK{read};
    link_state();
    noted("you turned the live debug link on: link $id, until " . strftime('%Y-%m-%d %H:%M UTC', gmtime $until) . "; timings, hosts and paths, status codes, sizes and errors go to $LINK_HOST");
    my ($release) = eval { beside() };
    my @u = POSIX::uname();
    link_line('INFO', 'start', 'the live debug link was switched on in the window', release => $release // '-', darwin => $u[2] // '-', arch => $u[4] // '-');
    $LINK{next} = 0;    # the badge was shown by link_state, which saw the link newly on
    return idle("The live debug link $id is on until " . strftime('%H:%M', localtime $until) . ": the times of each load, addresses without their queries, status codes, sizes and errors go to the LZRBRWSR project, never your cookies, what you type or the text of a page. It turns itself off after 24 hours; turn it off sooner in the cogwheel's menu.");
}
sub link_off {                            # [C31] off: its file and its spool removed, the window told; nothing more is sent
    my ($why) = @_;
    my $dir = link_folder();
    my $id = $LINK{id} // '';
    unlink "$dir/on", "$dir/spool", glob("$dir/spool.*"), glob("$dir/shot.*"), "$dir/local", "$dir/local.log", glob("$dir/command.*");
    undef $LINK{local};
    @LINK{qw(id key until)} = ();
    undef $LINK{read};
    window('link off');
    noted("the live debug link $id is off: $why");
    return idle("The live debug link is off ($why). Nothing more is sent.");
}
sub link_told { my @on = link_state(); window(@on ? "link on $on[0] $on[2]" : 'link off') unless $INCOGNITO || $TOR_WINDOW }    # [C31] at a window's start: the badge, when the link is on

# ---- the lines: the load-timeline format, nothing typed, no query ------------------------------------------
sub link_url {                            # [C31] scheme, host, port and path; a path's token-like parts withheld; no user, query or fragment
    my ($u) = @_;
    return '-' unless defined $u && length $u;
    my ($scheme, $host, $port, $path) = $u =~ m{\A([A-Za-z][A-Za-z0-9+.\-]{0,15})://(?:[^/?#\@]*\@)?([A-Za-z0-9.\-\[\]:]{1,253}?)(?::([0-9]{1,5}))?(/[^?#]*)?(?:[?#].*)?\z}s or return '{unparsed}';
    $path = join '/', map { link_tokenish($_) ? '{withheld}' : $_ } split m{/}, ($path // ''), -1;
    $path =~ s/[^A-Za-z0-9\/._\-~%+:,;=!\$&'()*\[\]{}]/_/g;
    $path = substr($path, 0, 200) if length $path > 200;
    return lc($scheme) . '://' . lc($host) . (defined $port ? ":$port" : '') . $path;
}
sub link_tokenish { my ($w) = @_; return $w =~ /\@/ || length($w) >= 24 && $w =~ /[0-9]/ && $w =~ /[A-Za-z]/ || length($w) >= 32 ? 1 : 0 }
sub link_words {                          # [C31] lzrprf's own words: each address cut as link_url, quoted parts and token-like words withheld, the home folder as ~
    my ($s, $n) = @_;
    return '' unless defined $s;
    my $home = (getpwuid $<)[7] // '';
    $s =~ s/\Q$home\E/~/g if length $home;
    $s =~ s{\b[A-Za-z][A-Za-z0-9+.\-]{0,15}://[^\s"'<>]+}{link_url($&)}ge;
    $s =~ s/"[^"]*"|(?<![A-Za-z])'[^']*'(?![A-Za-z])/{quoted}/g;
    $s = join ' ', map { link_tokenish($_) ? '{withheld}' : $_ } split / /, $s;
    $s =~ s/[^\x20-\x7e]/?/g;
    $n //= 300;
    return length $s > $n ? substr($s, 0, $n) . '...' : $s;
}
sub link_value { my ($v) = @_; $v = '-' unless defined $v && length $v; $v =~ s/[^A-Za-z0-9_.:\/{}%~+,=\-]/_/g; return length $v > 300 ? substr($v, 0, 300) : $v }
sub link_stamp { my $t = Time::HiRes::time(); return strftime('%Y-%m-%dT%H:%M:%S', gmtime int $t) . sprintf('.%03dZ', ($t - int $t) * 1000) }
sub link_line {                           # [C31] one line to the spool: LEVEL, event, words, fields; errors at every verbosity, the timeline at 1 and 2, steps at 2
    my ($level, $event, $words, @fields) = @_;
    return unless $LINK{id} && !$LINK{child};
    return if $LINK{verbosity} == 0 && $level !~ /\A(?:WARN|ERROR|FATAL)\z/ && $event ne 'start' && $event ne 'command';
    return if $event eq 'step' && $LINK{verbosity} < 2;
    my $text = link_stamp() . " $level [load-timeline] event=$event session=link-$LINK{id} pid=$$";
    while (my ($k, $v) = splice @fields, 0, 2) { $text .= " $k=" . link_value($v) }
    $text .= ' | ' . link_words($words, 400);
    $text = substr($text, 0, 1990) if length $text > 1990;
    my $dir = link_folder();
    if ($LINK{local} && sysopen(my $near, "$dir/local.log", O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0600)) { syswrite($near, "$text\n") if (-s $near // 0) < $LINK_LOCAL_BYTES; close $near }    # the local lane reads the same line here, at once
    return 1 if ($LINK{local} // 0) == 2;    # this Mac only: no line leaves it
    sysopen(my $out, "$dir/spool", O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0600) or return;
    if ((-s $out // 0) > $LINK_SPOOL_BYTES) { $LINK{dropped}++; close $out; return }
    syswrite($out, "$text\n");
    close $out;
    return 1;
}

# ---- the wrappers, put in place the first time the link is seen on ----------------------------------------
sub link_wrap {
    return if $LINK{wrapped}++;
    my $ms = sub { int((Time::HiRes::time() - $_[0]) * 1000) };
    my $t = sub { defined $LINK{go_at} ? int((Time::HiRes::time() - $LINK{go_at}) * 1000) : '-' };
    link_around('go', sub {
        my ($a) = @_;
        @LINK{qw(go_at go_url drawn)} = (Time::HiRes::time(), link_url($a->[0]), undef);
        link_line('INFO', 'go', "a load began: $LINK{go_url}", url => $LINK{go_url}, why => link_words($a->[1] // '-', 60), (defined $LINK{measure} ? (measure => $LINK{measure}) : ()));
    }, sub {
        my ($a, $r, $began, $error) = @_;
        link_line($error ? 'ERROR' : 'INFO', 'load', 'a load ended' . ($error ? ': ' . link_words($error, 200) : ''), url => $LINK{go_url}, run => 0, first_drawing_ms => $LINK{drawn} // '-', loading_line_end_ms => $ms->($began), finished => $error ? 0 : 1, (defined $LINK{measure} ? (measure => delete $LINK{measure}) : ()));
        push @{ $LINK{loads} }, [$LINK{go_url}, $LINK{drawn} // '-', $ms->($began)];
        shift @{ $LINK{loads} } while @{ $LINK{loads} } > 10;
    });
    link_around('fetch', undef, sub {
        my ($a, $r, $began, $error) = @_;
        my $got = $r->[0];
        my ($status) = defined $got ? $got =~ m{\AHTTP/1\.[01] ([1-5][0-9][0-9])} : ();
        link_line(defined $got && !$error ? 'INFO' : 'WARN', 'request', defined $got ? 'a request was answered' : 'a request failed: ' . link_words($error // $r->[1] // 'no reason given', 200),
            url => link_url($a->[0]), run => 0, t_ms => $t->(), end_ms => $ms->($began), bytes => defined $got ? length $got : 0, status => $status // '-', kind => $a->[7] ? 'fixed' : $a->[2] ? 'page-script' : $a->[3] ? 'page' : 'resource');
    });
    link_around('find', undef, sub { my ($a, $r, $began) = @_; link_line('INFO', 'lookup', 'a name was looked up', host => link_value($a->[0]), run => 0, t_ms => $t->(), end_ms => $ms->($began), addresses => ref $r->[0] ? scalar @{ $r->[0] } : 0) });
    link_around('contained', undef, sub { my ($a, $r, $began, $error) = @_; link_line($error ? 'ERROR' : 'INFO', 'application_run', 'a run of the application in its container' . ($error ? ': ' . link_words($error, 200) : ''), url => link_url($a->[0]), run => 0, t_ms => $t->(), end_ms => $ms->($began)) });
    link_around('fault', sub { link_line('ERROR', 'error', 'the program\'s run ended without a page: ' . link_words($_[0][0] // '', 60), kind => 'fault') }, undef);
    link_around('unheard', sub { link_line('ERROR', 'error', 'an error of lzrprf\'s own, after which the window went on: ' . link_words($_[0][1] // '', 300), kind => 'lzrprf') }, undef);
    link_around('timed', sub { link_line('DEBUG', 'step', 'lzrprf reached a step', step => link_value(($_[0][0] // '') =~ s/ .*//r), t_ms => $t->()) if $LINK{verbosity} >= 2 }, undef);
    link_around('window', sub { $LINK{drawn} //= $t->() if defined $LINK{go_at} && ($_[0][0] // '') =~ /\A(?:page|layers|laid|relaid)\b/ }, sub { my ($a, $r, $began) = @_; return unless defined $LINK{go_at} && ($a->[0] // '') =~ /\A(page|layers|laid|relaid)\b/; my ($kind, $bytes) = ($1, 0); $bytes += 1 + length for @$a; link_line('INFO', 'list', 'a list was handed to the window', kind => $kind, run => 0, t_ms => $t->(), end_ms => $ms->($began), lines => scalar @$a, bytes => $bytes) });    # how much each list is and how long the window took to take it: a write waits while the window is busy
}
sub link_around {                         # [C31] the sub $name, wrapped: each call is the same call with the same arguments and context, and the link's own lines never change what it does
    my ($name, $before, $after) = @_;
    no strict 'refs';
    my $orig = defined &{"main::$name"} ? \&{"main::$name"} : return;
    $LINK_ORIG{$name} = $orig;
    no warnings 'redefine';
    *{"main::$name"} = sub {
        goto &$orig unless $LINK{id} && !$LINK{child} && !$LINK{inside};
        my $args = [@_];
        { local $LINK{inside} = 1; eval { $before->($args) if $before; 1 } }    # what a wrapper does itself is never a line of the link
        my ($want, $began, $ok, @r) = (wantarray, Time::HiRes::time());
        if ($want) { $ok = eval { @r = &$orig; 1 } } elsif (defined $want) { $ok = eval { $r[0] = &$orig; 1 } } else { $ok = eval { &$orig; 1 } }
        my $error = $ok ? undef : $@;
        { local $LINK{inside} = 1; eval { $after->($args, \@r, $began, $error) if $after; 1 } }
        die $error unless $ok;
        return $want ? @r : $r[0];
    };
}

# ---- sending and the commands -----------------------------------------------------------------------------
sub link_due { my ($other) = @_; my $on = link_on(); return $other unless $on || !$INCOGNITO && !$TOR_WINDOW && !$LINK{child} && -e link_folder() . '/local'; my $mine = $on ? ($LINK{next} // 0) - time : 5; $mine = 1 if $mine < 1; $mine = $LINK_LOCAL_WAIT if $on && $LINK{local}; return defined $other && $other < $mine ? $other : $mine }    # off, with the lane of this Mac asked for once (the file local): a look every 5 s, so an idle window sees the switch turned on
sub link_watch {                          # [C31] from sub behind's quiet moments: what the sender brought, then the next send when it is due
    return unless $LINK{sending} || link_on();
    link_reaped();
    link_local() if $LINK{local} && link_on();
    return if ($LINK{local} // 0) == 2;    # this Mac only: no sender is started
    return if $LINK{sending} || time < ($LINK{next} // 0) || !link_on();
    my $dir = link_folder();
    open(my $lock, '>>', "$dir/sender.lock") or return;
    return unless flock($lock, LOCK_EX | LOCK_NB);    # another window of yours is sending: this one waits for its next turn
    my $fast = time - ($LINK{last_command} // 0) < 600 || time + $LINK_SECONDS - $LINK{until} < 600;
    $LINK{next} = time + ($fast ? 5 : 15);
    rename "$dir/spool", "$dir/spool.$$." . time if -s "$dir/spool";
    my ($body, @taken) = ('');
    for my $part (sort glob("$dir/spool.*")) { last if length($body) > $LINK_BATCH_BYTES; open my $in, '<', $part or next; local $/; $body .= <$in> // ''; close $in; push @taken, $part }
    $body .= link_stamp() . " WARN [load-timeline] event=dropped session=link-$LINK{id} pid=$$ lines=$LINK{dropped} | the spool was full while nothing was sent\n" if delete $LINK{dropped};
    my @shots = sort glob("$dir/shot.*");
    my ($id, $key) = @LINK{qw(id key)};
    my $child = fork;
    return unless defined $child;
    if (!$child) {
        $LINK{child} = 1;
        my $got = fixed("the live debug link sent " . ($body =~ tr/\n//) . " line(s) and asked for commands: $LINK_BASE$id", "$LINK_BASE$id", $LINK_HOST, { method => 'POST', body => "key $key\n$body", type => 'text/plain' });
        my ($status, undef, $answer) = defined $got ? @{ live_parts($got, 'POST') // [] } : ();
        if (($status // '') =~ /\A2/) { unlink @taken; put("$dir/answer.$$", O_EXCL, $answer // '') }
        elsif (($status // '') =~ /\A(?:401|403|410)\z/) { put("$dir/answer.$$", O_EXCL, "refused $status") }
        for my $shot (@shots) {
            open my $in, '<', $shot or next; local $/; my $text = <$in> // ''; close $in;
            fixed("the live debug link sent a picture of the window: $LINK_BASE$id/shot", "$LINK_BASE$id/shot", $LINK_HOST, { method => 'POST', body => "key $key\n$text", type => 'text/plain' });
            unlink $shot;
        }
        POSIX::_exit(0);
    }
    $LINK{sending} = $child;
    close $lock;
    return;
}
sub link_plain { my ($file) = @_; my @is = lstat $file; return @is && -f _ && $is[3] == 1 && $is[4] == $< ? $is[7] : undef }    # [C31] a plain file of yours that no link leads elsewhere: its size
sub link_local {                          # [C31] the local lane: commands laid in link/command.* on this Mac are taken at once, each the same signed block and checked as one the ingest hands on
    my $dir = link_folder();
    my $taken = 0;
    for my $file (sort glob("$dir/command.*")) {
        last if ++$taken > 4;
        my $size = link_plain($file);
        my $block = '';
        if (defined $size && $size <= 4096 && sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW)) { local $/; $block = <$in> // ''; close $in }
        unlink $file;
        link_command($block) if $block =~ /\Alzrbrwsr-debug-link 1 [^\n]{1,2100}\n-----BEGIN SSH SIGNATURE-----\n(?:[A-Za-z0-9+\/=]{1,76}\n){1,30}-----END SSH SIGNATURE-----\n\z/;
    }
    return $taken;
}
sub link_reaped {                         # [C31] the sender's answer: the commands in it, each checked before it is run
    my $pid = $LINK{sending} or return;
    return unless waitpid($pid, POSIX::WNOHANG()) == $pid;
    undef $LINK{sending};
    my $file = link_folder() . "/answer.$pid";
    open(my $in, '<', $file) or return;
    my $answer = do { local $/; <$in> } // '';
    close $in;
    unlink $file;
    return link_off("the LZRBRWSR ingest refused this link ($1)") if $answer =~ /\Arefused ([0-9]{3})/;
    my @blocks = $answer =~ /^(lzrbrwsr-debug-link 1 [^\n]{1,2100}\n-----BEGIN SSH SIGNATURE-----\n(?:[A-Za-z0-9+\/=]{1,76}\n){1,30}-----END SSH SIGNATURE-----\n)/mg;
    link_command($_) for @blocks[0 .. ($#blocks < 3 ? $#blocks : 3)];
}
sub link_checked {                        # [C31] a command and its signature: (verb, argument, nonce) when every check holds, else (nothing, why)
    my ($block) = @_;
    my ($command, $signature) = $block =~ /\A([^\n]+)\n(-----BEGIN SSH SIGNATURE-----\n.*)\z/s or return (undef, 'it is not a command and a signature');
    my ($id, $nonce, $expires, $verb, $arg) = $command =~ /\Alzrbrwsr-debug-link 1 ([0-9a-f]{12}) ([0-9a-f]{16,32}) ([0-9]{10}) (open|reload|measure|snapshot|verbosity|shot)(?: ([\x21-\x7e]{1,2000}))?\z/ or return (undef, 'it is not in the one form a command has');
    return (undef, 'it names another link') unless $id eq ($LINK{id} // '');
    my $now = time;
    return (undef, 'it expired') if $expires <= $now;
    return (undef, "its expiry is more than $LINK_COMMAND_SECONDS seconds away") if $expires > $now + $LINK_COMMAND_SECONDS;
    my %arg_ok = (open => qr{\Ahttps://[\x21-\x7e]+\z}, measure => qr{\Ahttps://[\x21-\x7e]+\z}, reload => qr{\A\z}, snapshot => qr{\A\z}, verbosity => qr{\A[012]\z}, shot => qr{\A(?:page|window)(?:,private)?\z});
    return (undef, "its argument is not one $verb takes") unless ($arg // '') =~ $arg_ok{$verb};
    my $seen = link_folder() . '/nonces';
    my @kept;
    if (open my $in, '<', $seen) { @kept = grep { /\A[0-9a-f]{16,32} ([0-9]{10})\z/ && $1 > $now } map { s/\n\z//r } <$in>; close $in }
    return (undef, 'its nonce was seen before') if grep { (split / /)[0] eq $nonce } @kept;
    return (undef, 'its signature does not hold for an approval key lzrprf carries, made for the debug link') unless signature_holds($command, $signature, $LINK_NAMESPACE, 'ECDSA', approval_keys());
    unlink "$seen.new";
    return (undef, 'its nonce could not be written down, so it is not run') unless put("$seen.new", O_EXCL, @kept[($#kept > 200 ? $#kept - 200 : 0) .. $#kept], "$nonce $expires") && rename("$seen.new", $seen);
    return ($verb, $arg // '', $nonce);
}
sub link_command {                        # [C31] one command: checked, written down, said in the badge, then run
    my ($block) = @_;
    my ($verb, $arg, $nonce) = link_checked($block);
    if (!$verb) {
        my $why = $arg;
        noted("the live debug link refused a command: $why");
        link_line('WARN', 'command', "a command was refused: $why", verdict => 'refused');
        window("link said refused a command: $why");
        return;
    }
    $LINK{last_command} = time;
    $LINK{next} = 0;
    my $shown = $verb . (length $arg ? ' ' . link_url($arg) : '');
    $shown = "$verb $arg" if $verb eq 'verbosity' || $verb eq 'shot';
    noted("the live debug link ran a signed command: $shown");
    link_line('INFO', 'command', "a signed command was run: $shown", verb => $verb, nonce => $nonce, verdict => 'run');
    window("link said $shown");
    if ($verb eq 'open' || $verb eq 'measure') {
        my ($url) = address($arg);
        return link_line('WARN', 'command', 'the address is not one lzrprf fetches', verb => $verb, nonce => $nonce) unless $url;
        $LINK{measure} = $nonce if $verb eq 'measure';
        my $was = $TAB;
        tabbed('new'); relaid();
        my $mine = $TABS[$TAB];
        go($url, 'the live debug link opened it (a signed command)');
        return unless $verb eq 'measure';    # a page that was only measured leaves no tab behind: its tab is closed when its load ended, and the tab shown before is shown again
        my ($at) = grep { $TABS[$_] == $mine } 0 .. $#TABS;
        return unless defined $at && @TABS > 1;
        tabbed('close', $at);
        tabbed('select', $was) if $was < @TABS && $was != $TAB;
        return relaid();
    }
    return navigated('reload') if $verb eq 'reload';
    if ($verb eq 'verbosity') {
        $LINK{verbosity} = $arg;
        my $dir = link_folder();
        unlink "$dir/on.new";
        put("$dir/on.new", O_EXCL, "$LINK{id} $LINK{key} $LINK{until} $arg") && rename("$dir/on.new", "$dir/on");
        return;
    }
    if ($verb eq 'snapshot') {
        my $n = 0;
        link_line('INFO', 'snapshot', 'the tabs of this window, and the last loads', tabs => scalar @TABS, shown => $TAB, live => scalar @LIVE, nonce => $nonce);
        link_line('INFO', 'snapshot_tab', 'a tab', tab => $n++, url => link_url($_->{url})) for @TABS;
        link_line('INFO', 'snapshot_load', 'a recent load', url => $_->[0], first_drawing_ms => $_->[1], loading_line_end_ms => $_->[2]) for @{ $LINK{loads} || [] };
        return;
    }
    if ($verb eq 'shot') {
        return link_line('WARN', 'command', "a picture was asked again within $LINK_SHOT_SECONDS seconds; none was taken", nonce => $nonce) if time - ($LINK{shot_at} // 0) < $LINK_SHOT_SECONDS;
        $LINK{shot_at} = time;
        my ($which) = $arg =~ /\A(page|window)/;
        return window("link shot $nonce $which");    # a private window is never on the link, so ",private" changes nothing here, and is written down as asked
    }
}
sub link_drew {                           # [C31] "link drew MS" from the window: a list was drawn, and its drawing took MS; said only while the link is on, written during a measured load
    my ($took) = @_;
    return unless link_on() && defined $LINK{go_at};
    link_line('INFO', 'drew', 'the window drew a list', run => 0, t_ms => int((Time::HiRes::time() - $LINK{go_at}) * 1000), draw_ms => $took);
}

sub link_shot {                           # [C31] "link shot NONCE PNG-IN-BASE64" from the window: its own drawing, kept for the sender
    my ($nonce, $text) = @_;
    return unless link_on();
    return link_line('WARN', 'shot', 'the window\'s picture was not a PNG lzrprf sends', nonce => $nonce) unless support_picture($text);
    my $file = link_folder() . "/shot.$nonce";
    put($file, O_EXCL, "shot $nonce", $text) or return;
    my $here = ($LINK{local} // 0) == 2;    # asked for this Mac only: the picture stays in its file, for whoever asked
    noted("the live debug link took a picture of the window for command $nonce: " . int(length($text) * 3 / 4) . ' bytes, ' . ($here ? 'kept on this Mac and sent nowhere' : 'sent with the next lines'));
    link_line('INFO', 'shot', 'a picture of the window was taken from its own drawing', nonce => $nonce, bytes => int(length($text) * 3 / 4));
    window($here ? 'link said screenshot kept here' : 'link said screenshot sent');
    $LINK{next} = 0;
}
