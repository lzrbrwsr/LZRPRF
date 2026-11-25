# LZRTNNL: Tor, and under it a VPN of your own (Henry, 2026-11-24, HC-0858). The decision and its
# sources: ../lzrbrwsr/architecture/lzrtnnl.md. The order is you, then the VPN, then Tor ("Tor over a
# VPN"): your provider sees that you use Tor and never where you go, Tor's guard sees the VPN's address
# and never yours, and every site keeps its own circuit, onion addresses included. A Tor window opens
# without connecting; its LZRTNNL modal offers Connect to Tor and, ticked, Use also VPN.
# The VPN is the official WireGuard app, which you install and in which you activate your provider's
# configuration file: LZRBRWSR carries no VPN client, makes no network or VPN profile of this Mac and
# asks for no right. You choose the same file in the modal; lzrprf reads its Address, Endpoint and
# AllowedIPs once, keeps those and nothing else (never the private key), and refuses a file whose
# AllowedIPs is not the whole internet (0.0.0.0/0). It then looks for the interface the app made, an
# utun whose IPv4 address is that Address (/sbin/ifconfig -v, read only), and takes its index.
# FAIL CLOSED. With the VPN, Tor reaches out only through a relay of lzrprf's own (sub tnnl_relay): a
# SOCKS5 server on the loopback, named to the client as its outbound proxy ([channel] outbound_proxy),
# that opens each connection with IP_BOUND_IF (and IPV6_BOUND_IF) set to that index, so the system
# sends it through the VPN's interface or not at all: when the VPN drops, its interface is gone, and a
# connection fails rather than taking the plain route. The relay takes numeric addresses only (Tor
# names its relays by address, so nothing is looked up), IPv6 only when the file routes ::/0, and an
# index of 0, which would bind nothing, never. The client's own container then allows it the loopback
# alone (sub tnnl_container): even a client that ignored the proxy line could not reach out past it.
# lzrprf looks at the interface every $TNNL_LOOK seconds while it is used; once it is gone, or holds
# another address, Tor is stopped and stays wanted (sub tor_failed), so nothing is fetched until you
# connect again or close the window. DNS lines of the file are ignored: Tor resolves at its exits.
# SYNC: 15-tor.pl (tor_on, tor_session_on), 28-window2.pl (the LZRTNNL modal), capabilities.json (tnnl)
my $TNNL = {};                            # file: {address, endpoint, v6}; interface, index; relay: {pid, guard, port}; next: when to look again
my $TNNL_LOOK = 2;                        # DECLARED(seconds between two looks at the VPN's interface while Tor goes through it)
my $TNNL_MOST = 65536;                    # DECLARED(the largest WireGuard file read; a provider's is under 1 KB)
my $TNNL_WAIT = 20;                       # DECLARED(the seconds the relay waits for one connection to a relay of Tor to open)
sub tnnl_on { return $TNNL->{index} ? 1 : 0 }    # true once a VPN was found for this Tor window: Tor goes through it

# The file's lines: [Interface] Address, [Peer] Endpoint and AllowedIPs. What is kept, or nothing and why.
sub tnnl_read {
    my ($text) = @_;
    my (%in, $section);
    for my $line (split /\r?\n/, $text) {
        $line =~ s/\s*[#;].*//;
        next unless $line =~ /\S/;
        if ($line =~ /^\s*\[\s*([A-Za-z]+)\s*\]\s*$/) { $section = lc $1; next }
        return (undef, 'it is not a WireGuard configuration file: a line stands before its first [Interface]') unless defined $section;
        next unless $line =~ /^\s*([A-Za-z]+)\s*=\s*(.*?)\s*$/;
        push @{ $in{"$section " . lc $1} }, map { s/^\s+|\s+$//gr } split /,/, $2;
    }
    my ($address) = map { m{^((?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3})(?:/\d{1,2})?\z} ? $1 : () } @{ $in{'interface address'} // [] };
    my @endpoints = @{ $in{'peer endpoint'} // [] };
    my @allowed = @{ $in{'peer allowedips'} // [] };
    return (undef, 'it names no IPv4 Address in [Interface]') unless defined $address;
    return (undef, 'it names no Endpoint in [Peer]') unless @endpoints;
    return (undef, 'it names more than one peer: lzrprf takes a file of one server') if @endpoints > 1;
    return (undef, 'its Endpoint is not a host and a port') unless $endpoints[0] =~ /^(?:\[[0-9A-Fa-f:.]{2,45}\]|[A-Za-z0-9.-]{1,253}):[1-9][0-9]{0,4}\z/;
    return (undef, 'its AllowedIPs is not the whole internet (0.0.0.0/0): a VPN that carries only some addresses would let Tor go out past it') unless grep { $_ eq '0.0.0.0/0' } @allowed;
    return { address => $address, endpoint => $endpoints[0], v6 => (grep { $_ eq '::/0' } @allowed) ? 1 : 0, dns => scalar @{ $in{'interface dns'} // [] } };
}

sub tnnl_asked { return window("tnnl refused $_[0]") unless $TOR_SESSION && !$TOR && $TOR_SESSION->{phase} =~ /^(?:made|connecting|browsing)\z/; return }    # the VPN is set up in a Tor window while Tor is not running in it: before it connects, or after it stopped

# "tnnl vpn file PATH": the file you chose in the modal's Open panel. Read once, and only what is kept is kept.
sub tnnl_file {
    my ($path) = @_;
    return if tnnl_asked('The VPN is chosen in a Tor window while Tor is not running.');
    sysopen(my $in, $path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return window('tnnl refused That file could not be opened. Choose the .conf file your provider gave you, the one you imported into the WireGuard app.');
    my @is = stat $in;
    return window('tnnl refused That is not a plain file, or it is larger than a WireGuard file is.') unless @is && -f _ && $is[7] <= $TNNL_MOST;
    my $text = '';
    while (sysread($in, $text, 65536, length $text)) { last if length $text > $TNNL_MOST }
    close $in;
    my ($vpn, $why) = tnnl_read($text);
    substr($text, 0) = "\0" x length $text;    # its private key is in it: the bytes are overwritten here, and never written anywhere
    return window("tnnl refused $why. Nothing was kept.") unless $vpn;
    $TNNL = { file => $vpn };
    record("you chose a WireGuard file for LZRTNNL: lzrprf keeps its address $vpn->{address} and its server $vpn->{endpoint}, and not its private key" . ($vpn->{dns} ? '; its DNS lines are not used, Tor resolves at its exits' : '')) or return window("tnnl refused $UNWRITTEN");    # [C5]
    return window("tnnl vpn read $vpn->{address} $vpn->{endpoint}" . ($vpn->{v6} ? ' v6' : ''));
}

# Which interface holds the file's address: the name and index, or nothing and why.
sub tnnl_interface {
    my ($address) = @_;
    my ($text) = said(5, '/sbin/ifconfig', '-v');
    return (undef, undef, 'this Mac did not list its network interfaces (ifconfig)') unless length $text;
    my ($name, $index, $up);
    for my $line (split /\n/, $text) {
        if ($line =~ /^([a-z]+[0-9]+): flags=[0-9a-f]+<([A-Z_,]*)>.*\bindex ([0-9]+)/) { ($name, $up, $index) = ($1, $2, $3); next }
        next unless defined $name && $line =~ /^\s+inet ([0-9.]+) / && $1 eq $address;
        return (undef, undef, "the address $address is held by $name, which is not a VPN's interface") unless $name =~ /^utun[0-9]{1,4}\z/ || ($TRY && $name eq 'lo0');    # "lzrprf try": the loopback stands in for the VPN
        return (undef, undef, "$name holds the address and is not up") unless ",$up," =~ /,UP,/ && ",$up," =~ /,RUNNING,/;
        return (undef, undef, "$name has no index") unless $index =~ /^[1-9][0-9]{0,4}\z/;
        return ($name, 0 + $index);
    }
    return (undef, undef, "no interface of this Mac holds the address $address: the VPN is not active in the WireGuard app");
}

# "tnnl vpn look": is the VPN active now? Said to the modal, which goes on to Connect only once it is.
sub tnnl_look {
    return if tnnl_asked('The VPN is looked for in a Tor window while Tor is not running.');
    return window('tnnl refused Choose your WireGuard file first.') unless $TNNL->{file};
    my ($name, $index, $why) = tnnl_interface($TNNL->{file}{address});
    return window("tnnl vpn missing $why") unless $name;
    tnnl_relay_end() if ($TNNL->{index} // $index) != $index;    # the VPN came back on another interface: a relay bound to the old one is not used again
    @$TNNL{qw(interface index)} = ($name, $index);
    record("LZRTNNL found the VPN: the interface $name (index $index) holds $TNNL->{file}{address}; Tor goes out through it alone") or return window("tnnl refused $UNWRITTEN");    # [C5]
    return window("tnnl vpn found $name $index");
}

sub tnnl_forget { tnnl_relay_end(); $TNNL = {}; return window('tnnl vpn none') }    # "tnnl vpn off": the VPN unticked before Connect

# The relay. A process of its own, forked from lzrprf: it ends when lzrprf's end of its pipe closes.
sub tnnl_relay {
    my $index = $TNNL->{index} // 0;
    return (undef, 'the VPN has no interface') unless $index =~ /^[1-9][0-9]{0,4}\z/;    # 0 would bind no interface: refused
    return ($TNNL->{relay}{port}) if $TNNL->{relay};
    my $listen;
    socket($listen, AF_INET, SOCK_STREAM, 0) && bind($listen, pack_sockaddr_in(0, inet_aton('127.0.0.1'))) && listen($listen, 16) or return (undef, 'lzrprf could not listen on the loopback for Tor');
    my ($port) = unpack_sockaddr_in(getsockname $listen);
    pipe(my $hold, my $guard) or return (undef, 'lzrprf could not start the relay');
    my $pid = fork // return (undef, 'lzrprf could not start the relay');
    if (!$pid) {
        close $guard;
        tnnl_serve($listen, $hold, $index, $TNNL->{file}{v6});
        POSIX::_exit(0);
    }
    close $hold;
    close $listen;
    $guard->autoflush(1);
    $TNNL->{relay} = { pid => $pid, guard => $guard, port => $port };
    noted("LZRTNNL's relay listens on 127.0.0.1:$port: each connection of Tor is opened through $TNNL->{interface} alone");
    return ($port);
}
sub tnnl_relay_end {
    my $was = delete $TNNL->{relay} or return;
    close $was->{guard};                  # the relay and every connection it carries end as the pipe closes
    kill 'TERM', $was->{pid};
    waitpid($was->{pid}, 0);
    return;
}

sub tnnl_serve {                          # in the relay's process: one child for each connection, all ended with it
    my ($listen, $hold, $index, $v6) = @_;
    my $nowhere = POSIX::open('/dev/null', O_RDWR) // POSIX::_exit(127);
    POSIX::dup2($nowhere, $_) for 0 .. 2;
    my %keep = map { $_ => 1 } fileno($listen), fileno($hold);
    opendir(my $fds, '/dev/fd') or POSIX::_exit(127);
    POSIX::close($_) for grep { /^\d+$/ && $_ > 2 && !$keep{$_} } readdir $fds;    # the window's pipes and every other descriptor of lzrprf: never the relay's
    my %kids;
    $SIG{TERM} = sub { kill 'KILL', keys %kids; POSIX::_exit(0) };
    while (1) {
        my $ready = '';
        vec($ready, fileno $_, 1) = 1 for $listen, $hold;
        select($ready, undef, undef, 1);
        delete $kids{$_} for grep { waitpid($_, 1) == $_ } keys %kids;
        if (vec($ready, fileno $hold, 1)) { kill 'KILL', keys %kids; POSIX::_exit(0) }    # lzrprf ended, or ended the relay
        my $client;
        next unless vec($ready, fileno $listen, 1) && accept($client, $listen);
        my $kid = fork;
        if (defined $kid && !$kid) { close $listen; tnnl_carried($client, $hold, $index, $v6); POSIX::_exit(0) }
        $kids{$kid} = 1 if $kid;
        close $client;
    }
}

sub tnnl_bound {                          # a socket of the family given, bound to the interface $index; or nothing and why
    my ($family, $index) = @_;
    return (undef, 'no interface') unless $index =~ /^[1-9][0-9]{0,4}\z/;
    socket(my $out, $family, SOCK_STREAM, 0) or return (undef, 'no socket');
    my ($level, $name) = $family == AF_INET ? (0, 25) : (41, 125);    # IPPROTO_IP IP_BOUND_IF, IPPROTO_IPV6 IPV6_BOUND_IF (netinet/in.h, netinet6/in6.h)
    setsockopt($out, $level, $name, pack('L', $index)) or return (undef, "it could not be bound to the interface ($!)");
    my $got = getsockopt($out, $level, $name);
    return (undef, 'the system did not keep the binding') unless defined $got && unpack('L', $got) == $index;
    return ($out);
}

sub tnnl_carried {                        # one connection of Tor: SOCKS5 with a numeric address, then the bytes both ways
    my ($client, $hold, $index, $v6) = @_;
    my $until = now() + $TNNL_WAIT;
    my $read = sub {
        my ($want) = @_;
        my $got = '';
        while (length $got < $want) {
            my $ready = '';
            vec($ready, fileno $client, 1) = 1;
            my $left = $until - now();
            return '' if $left <= 0 || select($ready, undef, undef, $left) <= 0;
            sysread($client, $got, $want - length $got, length $got) or return '';
        }
        return $got;
    };
    my $answer = sub { syswrite($client, pack('C4 a4 n', 5, $_[0], 0, 1, "\0\0\0\0", 0)); return };
    my ($version, $methods) = unpack 'C C', $read->(2);
    return unless ($version // 0) == 5 && $methods;
    my %offered = map { $_ => 1 } unpack 'C*', $read->($methods);
    return syswrite($client, "\x05\xff") unless $offered{0};
    syswrite($client, "\x05\x00");
    my ($v, $command, undef, $kind) = unpack 'C4', $read->(4);
    return $answer->(7) unless ($v // 0) == 5 && ($command // 0) == 1;    # CONNECT only
    $kind //= 0;
    return $answer->(8) unless $kind == 1 || $kind == 4;                 # a name is never taken: nothing is looked up
    return $answer->(2) if $kind == 4 && !$v6;                           # IPv6 only when the VPN carries it
    my $where = $read->($kind == 1 ? 4 : 16);
    my $port = unpack 'n', $read->(2);
    return unless defined $port && length $where == ($kind == 1 ? 4 : 16);
    my $family = $kind == 1 ? AF_INET : AF_INET6;
    my $text = Socket::inet_ntop($family, $where);
    return $answer->(2) unless $TRY || public($text);                     # a relay of Tor is on the public internet; "lzrprf try" tests on the loopback
    my ($out) = tnnl_bound($family, $index);
    return $answer->(1) unless $out;
    $out->blocking(0);
    connect($out, $kind == 1 ? pack_sockaddr_in($port, $where) : pack_sockaddr_in6($port, $where));
    my $ready = '';
    vec($ready, fileno $out, 1) = 1;
    my $left = $until - now();
    return $answer->(4) unless $left > 0 && select(undef, $ready, undef, $left) > 0 && !unpack('i', getsockopt($out, SOL_SOCKET, SO_ERROR) // pack('i', 1));    # it did not open through the VPN: refused, never sent another way
    $answer->(0);
    $out->blocking(1);
    while (1) {                           # the bytes, both ways, until either end closes or lzrprf ends
        my $in = '';
        vec($in, fileno $_, 1) = 1 for $client, $out, $hold;
        select($in, undef, undef, undef) > 0 or return;
        return if vec($in, fileno $hold, 1);
        for ([$client, $out], [$out, $client]) {
            my ($from, $to) = @$_;
            next unless vec($in, fileno $from, 1);
            my $n = sysread($from, my $bytes, 65536);
            return unless $n;
            my $at = 0;
            while ($at < $n) { my $w = syswrite($to, $bytes, $n - $at, $at); return unless $w; $at += $w }
        }
    }
}

# Every $TNNL_LOOK seconds while Tor goes through the VPN: still there, with its address? If not, Tor
# stops and stays wanted, so nothing is fetched. True when it dropped.
sub tnnl_due { my ($other) = @_; return $other unless tnnl_on() && $TNNL->{relay}; my $mine = ($TNNL->{next} // 0) - now(); $mine = 0.1 if $mine < 0.1; return defined $other && $other < $mine ? $other : $mine }
sub tnnl_watch {
    return 0 unless tnnl_on() && $TNNL->{relay} && now() >= ($TNNL->{next} // 0);
    $TNNL->{next} = now() + $TNNL_LOOK;
    my ($name, $index, $why) = tnnl_interface($TNNL->{file}{address});
    return 0 if defined $name && $name eq $TNNL->{interface} && $index == $TNNL->{index};
    $why //= "the address is now held by $name, another interface";
    tnnl_relay_end();
    window('tnnl vpn dropped');
    tor_failed("the VPN dropped ($why), and Tor does not go out without it. Activate the VPN in the WireGuard app and connect again, or close this window");
    return 1;
}

sub tnnl_ready {                          # why Tor may not start through the VPN now, or nothing: looked at once more as Tor starts
    return unless tnnl_on();
    my ($name, $index, $why) = tnnl_interface($TNNL->{file}{address});
    return "the VPN is not active ($why)" unless defined $name;
    return "the VPN moved to another interface ($name): choose Connect again" unless $name eq $TNNL->{interface} && $index == $TNNL->{index};
    $TNNL->{next} = now() + $TNNL_LOOK;
    return;
}

# What the Tor client is given: its proxy line, and a container that reaches the loopback alone.
sub tnnl_lines { return () unless tnnl_on(); my ($port) = tnnl_relay(); return $port ? ('[channel]', qq{outbound_proxy = "socks5://127.0.0.1:$port"}) : ('[channel]', 'outbound_proxy = "socks5://127.0.0.1:1"') }    # no relay: a port nothing listens on, and the container below still holds
sub tnnl_container {                      # the Tor container, its way out narrowed to the loopback; a text without that line loses every way out instead
    my ($text) = @_;
    return $text unless tnnl_on();
    $text =~ s/\(allow network-outbound \(remote tcp "\*:\*"\)\)/(allow network-outbound (remote tcp "localhost:*"))/ or $text =~ s/^\(allow network-outbound[^\n]*\n//mg;
    return $text;
}
sub tnnl_said { return tnnl_on() ? "$TNNL->{interface} (index $TNNL->{index})" : 'no VPN' }

# "lzrprf tnnlrelay INDEX TARGET", for the tests: the relay bound to the interface INDEX, asked once for
# TARGET (local: a listener of this command that answers; name: a host name; or ADDRESS:PORT), and what
# it answered as SOCKS5 does: 0 opened, 1 not bound, 4 not reached through that interface, 8 a name.
# "lzrprf tnnldrop FOLDER/.lzrprf" (target drop): the loopback, 127.0.0.1 on lo0, stands in for an active
# VPN; a connection is carried through the relay, and then the VPN's address leaves every interface, as
# when the VPN drops. Printed after the SOCKS answer: whether the Tor client's container goes out to the
# loopback alone and its configuration names the relay, whether the watch saw the drop, whether the carried
# connection was ended, whether the relay still takes one, and whether Tor is still wanted (nothing is
# then fetched on the clear road: sub tor_failed).
sub tnnl_tried {
    my ($index, $target) = @_;
    ($TRY, $TNNL_WAIT, $TNNL_LOOK) = (1, 2, 0);    # "lzrprf try" lets the loopback stand in for the VPN; each answer is waited for 10 s, so a busy Mac still sees the relay give up first
    my $drop = $target eq 'drop' ? 1 : 0;
    my ($name, $at, $why) = $drop ? tnnl_interface('127.0.0.1') : ("index $index", $index);
    return "the loopback could not stand in for the VPN: $why\n" unless defined $name;
    ($TNNL, $target) = ({ index => $at, interface => $name, file => { address => '127.0.0.1', v6 => 0 } }, $drop ? 'local' : $target);
    my ($port, $refused) = tnnl_relay();
    return "relay refused $refused\n" unless $port;
    my $listen = $target eq 'local' ? do { require IO::Socket::INET; IO::Socket::INET->new(Listen => 2, LocalAddr => '127.0.0.1', LocalPort => 0) } : undef;
    my ($to, $on) = $listen ? ('127.0.0.1', $listen->sockport) : $target =~ /^([0-9.]{7,15}):([0-9]{1,5})\z/;
    my $ask = $target eq 'name' ? pack('C4 C/a* n', 5, 1, 0, 3, 'example.invalid', 443) : defined $to ? pack('C4 a4 n', 5, 1, 0, 1, inet_aton($to), $on) : return "a target is local, name or ADDRESS:PORT\n";
    my $s = tnnl_dialed($port) or return "the relay could not be reached\n";
    my $within = sub { my ($from, $want) = @_; my $got = ''; my $until = now() + 10; while (length $got < $want) { my $r = ''; vec($r, fileno $from, 1) = 1; last unless select($r, undef, undef, $until - now()) > 0 && sysread($from, $got, $want - length $got, length $got) } return $got };
    syswrite($s, "\x05\x01\x00");
    my $hello = $within->($s, 2);
    syswrite($s, $ask);
    my $got = $within->($s, 10);
    my $line = 'socks ' . ($hello eq "\x05\x00" && length $got >= 2 ? ord substr($got, 1, 1) : 'none');
    if ($listen && $line eq 'socks 0') {
        my $r = '';
        vec($r, fileno $listen, 1) = 1;
        my $c = select($r, undef, undef, 10) > 0 ? $listen->accept : undef;
        syswrite($s, 'ping');
        my $there = $c ? $within->($c, 4) : '';
        syswrite($c, 'pong') if $c;
        $line .= $there eq 'ping' && $within->($s, 4) eq 'pong' ? ' carried' : ' not carried';
    }
    if ($drop) {
        my $box = tnnl_container($TOR_CONTAINER);    # the Tor client's container while the VPN is on: out to the loopback (the relay) alone
        $line .= $box =~ /^\(allow network-outbound \(remote tcp "localhost:\*"\)\)$/m && (() = $box =~ /network-outbound/g) == 1 ? ', container out to the loopback alone' : ', container out elsewhere too';
        $line .= join("\n", tnnl_lines()) eq qq{[channel]\noutbound_proxy = "socks5://127.0.0.1:$port"} ? ', Tor told to go through the relay' : ', Tor not told the relay';
        ($TNNL->{file}{address}, $TNNL->{next}) = ('192.0.2.254', 0);    # an address no interface holds: the VPN is gone
        $line .= tnnl_watch() ? ', drop seen' : ', drop not seen';
        my $r = '';
        vec($r, fileno $s, 1) = 1;
        $line .= select($r, undef, undef, 10) > 0 && !sysread($s, my $more, 1) ? ', carried connection ended' : ', carried connection still open';
        $line .= tnnl_dialed($port) ? ', relay still listening' : ', relay gone';
        $line .= $TOR_WANTED ? ', Tor still wanted' : ', Tor not wanted';
    }
    tnnl_relay_end();
    return "$line\n";
}
sub tnnl_dialed { my $s; socket($s, AF_INET, SOCK_STREAM, 0) && connect($s, pack_sockaddr_in($_[0], inet_aton('127.0.0.1'))) or return; return $s }    # the test's own connection to the relay, on the loopback
