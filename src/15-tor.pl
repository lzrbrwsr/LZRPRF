# Tor, on one click. The client is Arti, the Tor Project's own, built from
# source and put beside the program by the installer, named in the release file like every file
# there (sub paired) and compared again before it starts. It runs only between "tor on" and
# "tor off" from the window, or until the window ends: nothing of it is held before or after. It
# runs in a container of its own: it reads its program, the system's libraries and one folder of
# lzrprf's, $DIR/tor, where it keeps the directory of relays it downloaded; it connects out over
# TCP and listens on the loopback alone. lzrprf hands it the host name over SOCKS5 and carries
# the bytes as for any request; nothing is looked up on this computer, and every site goes out
# under its own SOCKS name, so two sites never share a circuit. A small shell stands between
# lzrprf and the client and ends it when lzrprf's end of a pipe closes, so a window that ends in
# any way ends its Tor too. While Tor is wanted and not ready, nothing is fetched: never directly.
my $TOR_CONTAINER = <<'END';
(version 1)
(deny default)
(allow process-exec (literal (param "BIN")))
(allow process-fork)
(allow signal (target self))
(allow sysctl-read)
(allow file-read* file-map-executable
  (subpath "/usr/lib") (subpath "/System/Library") (subpath "/System/Cryptexes")
  (subpath "/Library/Apple/System/Library") (subpath "/private/var/db/dyld")
  (literal (param "BIN")))
(allow file-read-data (literal "/"))
(allow file-read-metadata (literal "/") (literal "/private") (literal "/private/tmp") (literal "/tmp")
  (literal "/private/var") (literal "/var") (literal "/Users") (literal "/private/etc") (literal "/etc"))
(allow file-read* (literal "/dev/urandom") (literal "/dev/random") (literal "/dev/null"))
(allow file-write-data (literal "/dev/null"))
(allow file-read* file-write* (subpath (param "DATA")))
(allow file-read-metadata (path-ancestors (param "DATA")))
(allow network-outbound (remote tcp "*:*"))
(allow network-bind network-inbound (local tcp "localhost:*"))
END
my $TOR_SECONDS = 90;                     # DECLARED(the most a start may take; a cold start measured 2 to 4 s, a slow network takes longer)
my @TOR_STEPS = (                         # the client's own log lines, each the first of a step the window shows
    [qr/Looking for a consensus|usable directory from cache|good directory from cache|Fetching a consensus/, 1, 10, 'Reading the directory of relays'],
    [qr/Downloading certificates/, 2, 30, 'Checking the directory'],
    [qr/Downloading microdescriptors/, 3, 55, 'Learning the relays'],
    [qr/Marked consensus usable|Directory is complete|enough information to build circuits/, 4, 85, 'Building circuits'],
    [qr/Sufficiently bootstrapped; proxy now functional/, 5, 100, 'Connected to Tor'],
);
sub tor_client {                        # the client, and whether it is a test's stand-in
    if ($TRY && open my $instead, '<', "$ROOT/torclient") { chomp(my $line = <$instead> // ''); return ($line, 1) }    # "lzrprf try" only: the test's stand-in, a perl script
    return (dirname($PROGRAM) . '/arti', 0);
}
sub tor_where { return (undef, $REFUSED_WHY) if listed($_[0]); return (undef, 'this Tor window is not open for browsing, so nothing was fetched: not through Tor, and not directly') if $TOR && $TOR_SESSION && $TOR_SESSION->{phase} ne 'browsing'; return $TOR ? [{ tor => 1, host => $_[0], text => 'Tor' }] : (undef, 'Tor is on and not connected, so nothing was fetched: not through Tor, and not directly') }    # [C23] Tor is not asked for a listed host
sub tor_on {                              # [C17] started on request only, in its own container, and checked against the release file
    return window('tor on') if $TOR;
    jar_end();                            # [C17] a new identity, a new jar: none of the window before it goes through Tor
    $TOR_WANTED = 1;
    return tor_failed('LZRTNNL is not installed: add it in Add or remove LZR modules') unless part_on('lzrtnnl');
    if (my $why = tnnl_ready()) { return tor_failed($why) }    # with the VPN, Tor starts only while it is there
    my ($bin, $stand_in) = tor_client();
    my ($named) = map { /^file arti ([0-9a-f]{64})$/ ? $1 : () } release_lines();
    return tor_failed("the Tor client is not beside $APP: this release has none") unless -f $bin && ($stand_in || -x _);    # a stand-in is run by perl
    return tor_failed('the Tor client is another file than the release names') if !$TRY && ($named // '') ne (sum_of($bin) // '');
    my $data = "$DIR/tor";
    mkdir $data, 0700;
    return tor_failed("lzrprf could not make the folder $data") unless -d $data && !-l $data;
    unlink "$data/port", "$data/log";
    open my $cfg, '>', "$data/config.toml" or return tor_failed("lzrprf could not write $data/config.toml");
    print $cfg join("\n", '[proxy]', 'socks_listen = "127.0.0.1:auto"', 'dns_listen = 0', '[logging]', 'console = "info"', '[storage]', qq{cache_dir = "$data/cache"}, qq{state_dir = "$data/state"}, qq{port_info_file = "$data/port"},
        '[address_filter]', 'allow_onion_addrs = true', '[preemptive_circuits]', 'disable_at_threshold = 2', 'initial_predicted_ports = [443]', 'min_exit_circs_for_port = 1', 'prediction_lifetime = "10 minutes"',
        '[circuit_timing]', 'disused_circuit_timeout = "5 minutes"', '[system]', 'max_files = 1024', 'memory.max = "64 MiB"', 'memory.low_water = "48 MiB"', tnnl_lines(), '');    # with the VPN, [channel]: every connection through lzrprf's relay
    close $cfg;
    pipe(my $hold, my $guard) or return tor_failed('lzrprf could not start the Tor client');
    open my $log, '>', "$data/log" or return tor_failed("lzrprf could not write $data/log");
    my $pid = fork // return tor_failed('lzrprf could not start the Tor client');
    if (!$pid) {
        close $guard;
        my @client = $stand_in ? ('/usr/bin/perl', $bin) : ('/usr/bin/sandbox-exec', '-D', "BIN=$bin", '-D', "DATA=$data", '-p', tnnl_container($TOR_CONTAINER), $bin);    # a test's stand-in is a script, which the container (one named program, nothing it starts) cannot run: the selftest tries the container on its own
        become($hold, $log, $log, '/bin/sh', '-c', '"$@" & child=$!; read held; kill $child; wait', 'lzrprf-tor', @client, 'proxy', '-c', "$data/config.toml");
    }
    close $hold;
    close $log;
    select((select($guard), $| = 1)[0]);    # autoflush
    $TOR = { pid => $pid, guard => $guard };
    record("you turned Tor on: lzrprf starts the Tor client, $bin, in its own container" . (tnnl_on() ? ", through the VPN on " . tnnl_said() . " alone" : '')) or return tor_off('the log could not be written');
    window('tor step 0 0 Starting the Tor client');
    my ($until, $read, $step) = (now() + $TOR_SECONDS, 0, 0);
    while (now() < $until) {
        my $event = hear(0.2);
        return tor_off('the window closed') unless defined $event;
        if ($event eq 'tor off') {
            return tor_off('you stopped Tor before it connected') unless $TOR_SESSION;
            my $asking = now();           # [C17] Stop Tor while a Tor window connects: asked as from the ready modal; Stop Tor ends the window here (sub leave), Cancel goes on connecting
            tor_session_asked();
            $until += now() - $asking;    # the time the question stood is not taken from the start
            next;
        }
        push @HELD, $event if length $event;    # the rest is heard once Tor is connected or stopped
        return if tnnl_watch();           # the VPN dropped while Tor started: stopped, and still wanted
        return tor_failed('the Tor client ended') if waitpid($pid, 1) == $pid;    # 1: WNOHANG
        open my $in, '<', "$data/log" or next;
        seek $in, $read, 0;
        while (my $line = <$in>) {
            last unless $line =~ /\n\z/;
            $read += length $line;
            return tor_failed('Tor could not build a circuit') if $line =~ /circuit build retry limit|Unable to bootstrap/;
            for my $one (grep { $_->[1] > $step && $line =~ $_->[0] } @TOR_STEPS) { $step = $one->[1]; window("tor step $one->[1] $one->[2] $one->[3]") }
        }
        if ($step == 5 && open my $port, '<', "$data/port") {
            my ($number) = (join '', <$port>) =~ /"socks"[^\]]*?127\.0\.0\.1:(\d{1,5})"/s;
            next unless $number;
            $TOR->{port} = $number;
            record('Tor is connected: every address is fetched through it from here on, one circuit for each site') or return tor_off('the log could not be written');
            window('tor on');
            return idle('Tor is connected. Every address is fetched through it, one circuit for each site, and nothing is looked up on this Mac.');
        }
    }
    return tor_failed("Tor did not connect in $TOR_SECONDS seconds");
}
sub tor_failed {
    my ($why) = @_;
    tor_off();
    $TOR_WANTED = 1;                      # still wanted: nothing is fetched directly until Tor is turned off
    record("Tor did not connect: $why");
    window("tor failed $why");
    return idle("Tor did not connect: $why. Nothing is fetched until it connects or you turn it off.");
}
sub tor_off {
    my ($why) = @_;
    tnnl_relay_end();                     # LZRTNNL's relay goes with the client: no watch of a VPN outlives the Tor it carried
    jar_end() if $TOR;                    # [C17] the identity's jar ends with it, written nowhere
    $TOR_WANTED = 0;
    my $was = $TOR or return defined $why ? (window('tor off'), idle('Tor is off.')) : ();
    $TOR = undef;
    close $was->{guard};                  # the shell between ends the client as its pipe closes
    my $until = now() + 3;
    while (now() < $until) { last if waitpid($was->{pid}, 1) == $was->{pid}; Time::HiRes::sleep(0.05) }
    if (waitpid($was->{pid}, 1) == 0) { kill 'KILL', $was->{pid}; waitpid($was->{pid}, 0) }
    return unless defined $why;
    record("Tor is off: $why");
    window('tor off');
    return idle('Tor is off: every address is fetched directly again.');
}
# One connection through Tor: to the client on the loopback, then SOCKS5 with the host name, and
# the site's host as the user name, so Tor gives each site its own circuit.
sub tor_reach {
    my ($host, $until) = @_;
    return if listed($host);              # [C23] Tor is never asked for a listed host, an onion address or any other, whatever led here
    return unless $TOR && $TOR->{port} && waitpid($TOR->{pid}, 1) == 0;
    socket(my $tor, AF_INET, SOCK_STREAM, 0) or return;
    connect($tor, pack_sockaddr_in($TOR->{port}, inet_aton('127.0.0.1'))) or return;    # the loopback: this computer, never the internet
    my $said = sub {
        my ($send, $want) = @_;
        syswrite($tor, $send) == length $send or return '' if length $send;
        my $got = '';
        while (length $got < $want) {
            my $ready = '';
            vec($ready, fileno $tor, 1) = 1;
            my $left = $until - now();
            return '' if $left <= 0 || select($ready, undef, undef, $left) <= 0;
            sysread($tor, $got, $want - length $got, length $got) or return '';
        }
        return $got;
    };
    return unless $said->("\x05\x01\x02", 2) eq "\x05\x02";
    return unless $said->(pack('C C/a* C/a*', 1, substr($host, 0, 255), 'lzrbrwsr'), 2) eq "\x01\x00";
    my $head = $said->(pack('C4 C/a* n', 5, 1, 0, 3, $host, 443), 4);
    return unless length $head == 4 && substr($head, 0, 2) eq "\x05\x00";
    my $kind = ord substr($head, 3, 1);
    my $rest = $kind == 1 ? 6 : $kind == 4 ? 18 : $kind == 3 ? 2 + ord $said->('', 1) : return;
    return unless length $said->('', $rest) == $rest;
    unblocked($tor);
    return ($tor, 'Tor');
}

# The Tor window [C17]. Tor never carries a window that is not one: the onion icon of such a window
# opens a Tor window apart from it (sub tor_window_opened), a second lzrprf with a fresh incognito
# folder of its own, so no cookie, cache, storage or kept answer of the first reaches it, and nothing
# of it reaches the first. Its steps come in one order, held by sub tor_phase: made; connecting, while
# Tor starts; sealed, once it is connected and the window is shown to reach nothing past it (a name is
# not looked up, a direct connection is refused: sub tor_sealed); browsing, the only phase in which an
# address is fetched. Its end, by Tor off after your yes or by the window closing: closing, from which
# no new navigation or request is taken; ended, every page and its processes ended and shown gone;
# wiped, its data removed from its folder and its tables in memory emptied; checked, nothing of either
# left; released, only then Tor is turned off. The folder itself, with Tor's own directory of relays,
# goes last, as every incognito folder does (sub leave).
my $TOR_STOP_ASK = 'Stopping Tor: a. all tabs of this window will be closed; b. Tor will be disconnected and this incognito window will be closed, with all it held removed. Stop Tor?';    # [C17] the words of Stop Tor's question, in the window's Tor modal
my %TOR_ORDER = (made => 'connecting closing', connecting => 'sealed closing', sealed => 'browsing closing', browsing => 'closing', closing => 'ended', ended => 'wiped', wiped => 'checked', checked => 'released', released => '');
sub tor_phase {                           # [C17] the next step of the Tor window, when it may follow the one it is in: true, and it is that step now; else false, and nothing changes
    my ($to) = @_;
    my $from = $TOR_SESSION->{phase} // return 0;
    return 0 unless grep { $_ eq $to } split / /, $TOR_ORDER{$from} // '';
    $TOR_SESSION->{phase} = $to;
    return 1;
}

sub tor_window_opened {                   # [C17] the onion icon of a window that is not a Tor window, or File > New Tor Window in any window: a Tor window apart from it, and this one as it was
    window('tor off') unless $TOR_WINDOW;    # the onion of a Tor window stays as its own Tor says
    return idle('LZRTNNL is not installed, so no Tor window opens. Add it in Add or remove LZR modules, in the cogwheel menu.') unless part_on('lzrtnnl');
    return idle('A Tor window was asked for: "lzrprf try" starts none. Tor never carries this window.') if $TRY;
    return idle('No Tor window was started: lzrprf could not start a process.') unless apart(undef, '/usr/bin/perl', $SELF, 'tor', defined $PROFILE ? ('--profile', $PROFILE) : (), $PROGRAM, @ARGUMENTS);
    return idle('A Tor window is opening, apart from this one. It shares nothing with this window, and Tor never carries this one.');
}

sub tor_session_on {                      # [C17] Tor connected for the Tor window, sealed, and only then open for browsing
    tor_phase('connecting') if $TOR_SESSION->{phase} eq 'made';
    return idle('This Tor window is closing.') unless $TOR_SESSION->{phase} eq 'connecting' || $TOR_SESSION->{phase} eq 'browsing';
    window('torsession connecting') if $TOR_SESSION->{phase} eq 'connecting';
    tor_on();
    return unless $TOR && $TOR->{port} && $TOR_SESSION->{phase} eq 'connecting';
    tor_phase('sealed');
    if (my $why = tor_sealed()) { record("the Tor window was not sealed: $why"); return tor_session_end("it was not sealed: $why") }
    tor_phase('browsing');
    window('torsession browsing');
    record('the Tor window is sealed: no name is looked up on this Mac and no connection goes past Tor; it browses from here on');
    return idle('Tor is connected, and this window reaches nothing past it. Every address is fetched through Tor, one circuit for each site.');
}

sub tor_sealed {                          # [C17] why the Tor window could still reach the network past Tor, or nothing
    my (undef, $why) = find('example.test');
    return 'a name could be looked up on this Mac' unless defined $why;
    return 'a direct connection could still be made' unless $TOR_SESSION;    # sub reach refuses every address while a Tor window is open
    return 'Tor is not the one way out' unless ($TOR_WANTED && $TOR && $TOR->{port});
    return;
}

sub tor_session_asked {                   # [C17] Stop Tor in a Tor window, asked in its Tor modal: the window is closed whole first, after your yes
    return idle('Tor stays on, and this Tor window stays open.') unless ask($TOR_STOP_ASK, 'Cancel', 'Stop Tor') == 2;
    record('you closed the Tor window');
    leave();
}

sub tor_session_tables {                  # [C17] how many entries the Tor window's tables in memory hold
    return @LIVE + @CLOSED + @SESSION + @WAY + @PICTURED + @PERMIT_SEEN + @FILTER_SEEN + @PERMIT_HELD + @HELD + @LATER + keys(%PERMIT_PASSWORD) + keys(%PERMIT_PATHS) + keys(%PERMIT_DENIED) + keys(%PERMIT_NEXT) + keys(%PERMIT_ONCE) + keys(%PERMIT_INFO) + keys(%PERMIT_WEB) + listed_said() + @MARKS + length($TITLED)
        + (grep { length($_->{url} // '') || @{ $_->{visited} // [] } } @TABS) + (defined $SHOWN) + (defined $FLAGGED) + (defined $PERMIT_ASK) + (defined $NEXT);
}

sub tor_session_files {                   # [C17] what its folder holds besides Tor's own folder and the files of its life (held, behind, sweeper, torwindow)
    opendir my $in, $DIR or return ();
    return grep { !/^\.\.?\z/ && !/^(?:tor|held|behind|sweeper|torwindow)\z/ } readdir $in;
}

sub tor_told { print "$_\n" for @_; return }    # [C17] lines to the window in a Tor window's end: a window already gone does not cut the end short, as sub window would (sub leave)

sub tor_session_end {                     # [C17] the end of a Tor window, step by step, each after the one before held
    my ($why) = @_;
    return unless $TOR_SESSION && tor_phase('closing');
    tor_told('torsession closing');
    record("the Tor window closes: $why. No new navigation or request is taken");
    my @processes = grep { defined } map { @$_{qw(page keeper)} } @LIVE;
    live_end($_, 'the Tor window closed', 1) for @{ [@LIVE] };
    jar_end();                            # its cookies with its pages, written nowhere
    kill 'KILL', $witness if $witness;
    my @left = grep { kill 0, $_ } @processes;
    kill 'KILL', @left if @left;
    waitpid $_, 0 for @left;
    tor_phase('ended');
    tor_told('torsession ended ' . scalar(grep { kill 0, $_ } @processes));
    if ($TRY) { print STDERR "test session $_\n" for @SESSION }    # "lzrprf try" only: what the window's log held, for the test to read, written before it is emptied
    remove_tree("$DIR/$_", { safe => 0 }) for tor_session_files();
    @$_ = () for \@LIVE, \@CLOSED, \@SESSION, \@WAY, \@PICTURED, \@PERMIT_SEEN, \@FILTER_SEEN, \@PERMIT_HELD, \@HELD, \@LATER;
    undef $_ for $PERMIT_UNREAD, $PERMIT_STRIPPED; %$_ = () for \%PERMIT_PASSWORD, \%PERMIT_PATHS, \%PERMIT_DENIED, \%PERMIT_NEXT, \%PERMIT_ONCE, \%PERMIT_INFO, \%PERMIT_WEB;
    @MARKS = ();
    listed_said(1);
    ($TAB, $TITLED, @TABS) = (0, '', fresh_tab());
    ($SHOWN, $FLAGGED, $PERMIT_ASK, $NEXT) = ();
    tor_phase('wiped');
    tor_told('torsession wiped');
    my ($files, $tables) = (scalar(tor_session_files()), tor_session_tables());
    tor_phase('checked');
    tor_told("torsession checked $files $tables");
    return tor_told('torsession held') if $files || $tables;    # not all of it is gone: Tor is not released by this step, and the window's end takes it with the folder (sub leave)
    tor_phase('released');
    tor_off();
    tor_told('torsession released', 'tor off');
    return;
}

