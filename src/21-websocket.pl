# The renderer's bounded WebSocket protocol. Permission to open a transport requires
# trusted kept-app provenance. Ordinary pages receive a failed socket rather than losing the page.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrcht-discord-web.md
sub ws_asked {
    my ($held) = @_;
    my $end = index $held, "\n";
    return length($held) <= 4120 ? 0 : [''] if $end < 0;
    return [''] if $end > 4120;
    my $line = substr($held, 0, $end);
    my ($verb, $id, $rest) = $line =~ /\A=(wsopen|wssend|wsclose) ([1-9][0-9]{0,9}) (.*)\z/ or return [''];
    return [''] if $id > 4294967295;
    my $size = 0;
    if ($verb eq 'wsopen') {
        return [''] unless $rest =~ /\A[\x21-\x7e]{1,3584}(?: [!#$%&'*+\-.^_\x60|~0-9A-Za-z,]{1,511})?\z/;
    } elsif ($verb eq 'wssend') {
        ($size) = $rest =~ /\A(?:text|binary) (0|[1-9][0-9]{0,4})\z/ or return [''];
        return [''] if $size > 65536;
    } else {
        ($size) = $rest =~ /\A(?:1000|[34][0-9]{3}) (0|[1-9][0-9]{0,2})\z/ or return [''];
        return [''] if $size > 123;
    }
    return 0 if length($held) < $end + 1 + $size;
    return [$line, substr($held, $end + 1, $size), $end + 1 + $size];
}

sub ws_request {
    my ($live, $line, $body) = @_;
    if (my ($id, $url, $offered) = $line =~ /\A=wsopen ([0-9]+) ([^ ]+)(?: (.+))?\z/) {
        return if ws_open($live, $id, $url, $offered);
        return live_sent($live, "=wsfailed $id\n");
    }
    my ($id) = $line =~ /\A=ws(?:send|close) ([0-9]+) /;
    return ws_page_frame($live, $id, $line, $body);
}

# RFC 6455 section 5. The client never negotiates extensions. Incoming frames are
# unmasked; outgoing frames always carry a fresh unpredictable mask.
my $WS_DOWN = 1024 * 1024;
my $WS_UP = 64 * 1024;
sub ws_frame {
    my ($opcode, $body, $mask) = @_;
    return unless length($mask // '') == 4 && length($body) <= $WS_UP;
    my $len = length $body;
    my $header = $len < 126 ? pack('CC', 0x80 | $opcode, 0x80 | $len)
        : $len <= 65535 ? pack('CCn', 0x80 | $opcode, 0xfe, $len)
        : pack('CCNN', 0x80 | $opcode, 0xff, 0, $len);
    my $key = substr($mask x int(($len + 3) / 4), 0, $len);
    return $header . $mask . ($body ^ $key);
}

sub ws_read_frame {
    my ($buffer) = @_;
    return 0 if length($$buffer) < 2;
    my ($flags, $len) = unpack 'CC', $$buffer;
    my ($fin, $op, $at) = ($flags >> 7, $flags & 15, 2);
    return unless !($flags & 0x70) && !($len & 0x80) && ($op <= 2 || $op >= 8 && $op <= 10);
    return if $op >= 8 && (!$fin || $len > 125);
    if ($len == 126) {
        return 0 if length($$buffer) < 4;
        ($len, $at) = (unpack('n', substr($$buffer, 2, 2)), 4);
        return if $len < 126;
    } elsif ($len == 127) {
        return 0 if length($$buffer) < 10;
        my ($high, $low) = unpack('NN', substr($$buffer, 2, 8));
        return if $high || $low < 65536;
        ($len, $at) = ($low, 10);
    }
    return if $len > $WS_DOWN;
    return 0 if length($$buffer) < $at + $len;
    my $body = substr($$buffer, $at, $len);
    substr($$buffer, 0, $at + $len, '');
    return [$fin, $op, $body];
}

sub ws_valid_text {
    my ($body) = @_;
    require Encode;
    return eval { Encode::decode('UTF-8', $body, Encode::FB_CROAK()); 1 };
}

sub ws_endpoint {
    my ($app, $url, $offered) = @_;
    return unless $url =~ m{\Awss://([a-zA-Z0-9.-]+)(?::443)?([/?][\x21-\x7e]*)?\z};
    my ($host, $path) = (lc($1), $2 // '/');
    return unless $host eq $app->{spec}{socket_host} && $app->{spec}{hosts}{$host};
    return if $path =~ /[#\\]/;
    $path = "/$path" if $path =~ /^\?/;
    my @protocols = defined $offered && $offered ne '-' ? split(/,/, $offered, -1) : ();
    my %seen;
    return if grep { !length || $seen{$_}++ } @protocols;
    return ($host, $path, \@protocols);
}

sub ws_open {
    my ($live, $id, $url, $offered) = @_;
    my $app = $live->{kept_app} or return;
    return if $INCOGNITO || $TOR_WANTED || $TOR_WINDOW || $TOR_SESSION || !$live->{until};
    return if exists $app->{sockets}{$id};
    my $count = keys %{ $app->{sockets} };
    return page_cap_refused($app->{spec}{name}, 'open-sockets', $count + 1, $app->{spec}{sockets}, 'sockets',
        'The kept app would exceed its concurrent WebSocket allowance.') if $count >= $app->{spec}{sockets};
    my ($host, $path, $protocols) = ws_endpoint($app, $url, $offered);
    return unless $host && kept_app_budget($app, 1, 0);
    my $address = "https://$host$path";
    return if listed($address) || shield_said($address) ne 'allow';
    return unless eval { require IO::Socket::SSL; 1 };
    my $random = link_random(16) // return;
    my $key = MIME::Base64::encode_base64(pack('H*', $random), '');
    return unless record("the kept app asked to open a secure WebSocket to $host");
    my ($where) = find($host);
    return unless $where && !grep { $_->{own} } @$where;
    return unless record("the kept app connects to $host at the first public address that answers: " . join(', ', map { $_->{text} } @$where));
    my $until = now() + $FETCH_SECONDS;
    my ($raw) = reach($where, $until);
    return unless $raw;
    my $socket = IO::Socket::SSL->start_SSL($raw,
        SSL_startHandshake => 0, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
        SSL_ca_file => $ROOTS, SSL_hostname => $host, SSL_verifycn_name => $host,
        SSL_verifycn_scheme => 'http', SSL_version => 'SSLv23:!SSLv2:!SSLv3:!TLSv1:!TLSv1_1');
    if (!$socket) { close $raw; return }
    unblocked($socket);
    my $offer = @$protocols ? 'Sec-WebSocket-Protocol: ' . join(', ', @$protocols) . "\r\n" : '';
    my $cookie = kept_app_jar($app, sub { jar_cookie($address, 0, { top => $app->{spec}{start}, method => 'GET' }) });
    my $request = "GET $path HTTP/1.1\r\nHost: $host\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" .
        "Origin: https://discord.com\r\nSec-WebSocket-Key: $key\r\nSec-WebSocket-Version: 13\r\n$offer" . (defined $cookie ? "$cookie\r\n" : '') . "\r\n";
    $app->{sockets}{$id} = { socket => $socket, until => $until, phase => 'tls', in => '', out => $request,
        accept => MIME::Base64::encode_base64(Digest::SHA::sha1($key . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'), ''),
        offered => { map { $_ => 1 } @$protocols }, host => $host };
    return 1;
}

sub ws_upgrade {
    my ($ws) = @_;
    my $end = index($ws->{in}, "\r\n\r\n");
    return length($ws->{in}) <= 16384 ? 0 : undef if $end < 0;
    return if $end > 16384;
    my @lines = split /\r\n/, substr($ws->{in}, 0, $end + 4, '');
    return unless (shift(@lines) // '') =~ /\AHTTP\/1\.1 101(?: [\x20-\x7e]*)?\z/;
    my %headers;
    for my $line (@lines) {
        my ($name, $value) = $line =~ /\A([A-Za-z0-9-]+):[ \t]*([\x20-\x7e]*?)[ \t]*\z/ or return;
        $name = lc $name;
        return if exists $headers{$name} && $name =~ /\A(?:upgrade|connection|sec-websocket-)/;
        $headers{$name} = $value;
    }
    return unless lc($headers{upgrade} // '') eq 'websocket'
        && grep { $_ eq 'upgrade' } split /\s*,\s*/, lc($headers{connection} // '');
    return if ($headers{'sec-websocket-accept'} // '') ne $ws->{accept} || exists $headers{'sec-websocket-extensions'};
    my $picked = $headers{'sec-websocket-protocol'};
    return if defined $picked && !$ws->{offered}{$picked};
    $ws->{selected} = $picked // '-';
    return 1;
}

sub ws_reply {
    my ($live, $bytes) = @_;
    return if $live->{ended};
    $live->{input_held} //= '';
    return live_end($live, 'it does not read its WebSocket replies') if length($live->{input_held}) + length($bytes) > 2 * $WS_DOWN;
    $live->{input_held} .= $bytes;
    live_flushed($live);
    return;
}

sub ws_close_socket {
    my ($live, $id, $code, $reason) = @_;
    my $ws = delete $live->{kept_app}{sockets}{$id} or return;
    close $ws->{socket};
    if ($ws->{phase} eq 'open' || $ws->{phase} eq 'closing') {
        $code //= 1006;
        $reason //= '';
        return ws_reply($live, "=wsclose $id $code " . length($reason) . "\n$reason");
    }
    return ws_reply($live, "=wsfailed $id\n");
}

sub ws_queue_frame {
    my ($ws, $op, $body) = @_;
    return if length($ws->{out}) + length($body) + 14 > $WS_DOWN;
    my $random = link_random(4) // return;
    my $frame = ws_frame($op, $body, pack('H*', $random)) // return;
    $ws->{out} .= $frame;
    return 1;
}

sub ws_page_frame {
    my ($live, $id, $line, $body) = @_;
    my $ws = $live->{kept_app} && $live->{kept_app}{sockets}{$id} or return;
    if ($line =~ /\A=wsclose [0-9]+ ([0-9]+) /) {
        my $code = $1;
        return ws_close_socket($live, $id) unless $ws->{phase} eq 'open' && ws_valid_text($body) && ws_queue_frame($ws, 8, pack('n', $code) . $body);
        $ws->{phase} = 'closing';
        $ws->{until} = now() + 5;
        return;
    }
    return unless $ws->{phase} eq 'open';
    my $text = $line =~ / text /;
    return ws_close_socket($live, $id) if $text && !ws_valid_text($body) || !ws_queue_frame($ws, $text ? 1 : 2, $body);
    return;
}

sub ws_frames_heard {
    my ($live, $id, $ws) = @_;
    for (1 .. 32) {
        my $frame = ws_read_frame(\$ws->{in});
        return ws_close_socket($live, $id) unless defined $frame;
        return unless $frame;
        my ($fin, $op, $body) = @$frame;
        if ($op == 8) {
            return ws_close_socket($live, $id) if length($body) == 1;
            my ($code, $reason) = length($body) ? (unpack('n', $body), substr($body, 2)) : (1005, '');
            return ws_close_socket($live, $id) unless ($code == 1005 && !length($body) ||
                ($code >= 1000 && $code <= 1014 && $code != 1004 && $code != 1005 && $code != 1006 || $code >= 3000 && $code <= 4999)
                    && ws_valid_text($reason));
            return ws_close_socket($live, $id, $code, $reason) if $ws->{phase} eq 'closing' && !length($ws->{out});
            return ws_close_socket($live, $id) if $ws->{phase} eq 'open' && !ws_queue_frame($ws, 8, $body);
            @$ws{qw(phase close_code close_reason until)} = ('closing', $code, $reason, now() + 5);
            return;
        }
        if ($op == 9) { return ws_close_socket($live, $id) unless ws_queue_frame($ws, 10, $body); next }
        next if $op == 10 || $ws->{phase} eq 'closing';
        if ($op) {
            return ws_close_socket($live, $id) if defined $ws->{message};
            @$ws{qw(message message_kind)} = ('', $op);
        }
        return ws_close_socket($live, $id) unless defined $ws->{message} && length($ws->{message}) + length($body) <= $WS_DOWN;
        $ws->{message} .= $body;
        next unless $fin;
        my $message = delete $ws->{message};
        my $kind = $ws->{message_kind} == 1 ? 'text' : 'binary';
        return ws_close_socket($live, $id) if $kind eq 'text' && !ws_valid_text($message);
        ws_reply($live, "=wsmsg $id $kind " . length($message) . "\n$message");
        return if $live->{ended};
    }
    return;
}

sub ws_pump {
    my ($live) = @_;
    my $app = $live->{kept_app} or return;
    for my $id (keys %{ $app->{sockets} }) {
        return if $live->{ended};
        ws_step($live, $id, $app->{sockets}{$id});
    }
    return;
}

sub ws_step {
    my ($live, $id, $ws) = @_;
    my $socket = $ws->{socket};
    return ws_close_socket($live, $id) if $ws->{until} <= now();
    if ($ws->{phase} eq 'tls') {
        if (!$socket->connect_SSL()) {
            return if $socket->want_read || $socket->want_write;
            return ws_close_socket($live, $id);
        }
        $ws->{phase} = 'upgrade';
    }
    if (length $ws->{out}) {
        my $wrote = $socket->syswrite($ws->{out});
        return ws_close_socket($live, $id) unless $wrote || !defined $wrote && ($socket->want_read || $socket->want_write || $!{EAGAIN} || $!{EINTR});
        substr($ws->{out}, 0, $wrote, '') if $wrote;
    }
    return ws_close_socket($live, $id, $ws->{close_code}, $ws->{close_reason}) if defined $ws->{close_code} && !length $ws->{out};
    my $got = $socket->sysread(my $part, 65536);
    if ($got) {
        return ws_close_socket($live, $id) unless kept_app_budget($live->{kept_app}, 0, $got);
        my $queued = length($ws->{in}) + $got;
        if ($queued > $WS_DOWN + 65546) {
            page_cap_refused($live->{kept_app}{spec}{name}, 'socket-read-buffer', $queued, $WS_DOWN + 65546, 'bytes',
                'The WebSocket was closed because its incoming buffer would exceed the limit.');
            return ws_close_socket($live, $id);
        }
        $ws->{in} .= $part;
    } elsif (defined $got || !($socket->want_read || $socket->want_write || $!{EAGAIN} || $!{EINTR})) {
        return ws_close_socket($live, $id);
    }
    if ($ws->{phase} eq 'upgrade') {
        my $fit = ws_upgrade($ws);
        return ws_close_socket($live, $id) unless defined $fit;
        return unless $fit;
        return ws_close_socket($live, $id) unless record("the kept app opened a verified secure WebSocket to $ws->{host}");
        @$ws{qw(phase until)} = ('open', $live->{kept_app}{until});
        ws_reply($live, "=wsopened $id $ws->{selected}\n");
        return if $live->{ended};
    }
    return ws_frames_heard($live, $id, $ws);
}

sub ws_end {
    my ($live) = @_;
    my $app = $live->{kept_app} or return;
    close $_->{socket} for values %{ $app->{sockets} };
    $app->{sockets} = {};
    kept_app_jar($app, sub { jar_end(); return });
    return;
}
