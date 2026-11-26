
# LZRCHT, one place for your Telegram and Discord messages, in a tab
# [C32]. It starts on a press of its icon on the local home and on nothing
# else, and never in an incognito or a Tor window. Everything of it is the
# application's program core-lzrbrwsr-cht, run as three roles, each in a
# container of its own; lzrprf holds only what keeps them apart and you safe:
#
# - the drawing role, in the terminal's container ($TRMNL_CONTAINER: no
#   network, no file but its program and the system's libraries, nothing
#   started): it keeps your conversations and draws the tab as the lines of a
#   laid page, each page checked as a page is (sub laid_run). It is told the
#   tab's size, your presses and the wheel, and what the other roles may say.
# - the keeper, in that container and the config of LZRCHT
#   ($CHT_CONFIG under your home) and the files it names, to read and nothing
#   more: it says, for each platform, only whether LZRBRWSR's credentials for
#   it are in place, "=auth SERVICE 0|1". lzrprf reads of that config its
#   first line and the paths alone, never a file it names, and hands the
#   drawing role the word and nothing else (sub cht_kept).
# - a connector, one an account, in the terminal's container too: no network
#   and no file. It speaks the platform's protocol over the one connection
#   lzrprf opens and holds for it (sub cht_dialed): TCP to an IPv4 address
#   that platform publishes as its own, on a port it serves, and nothing else.
#   It is started only when the drawing role asks for it in its answer to a
#   press of yours, and only once the keeper said that platform's credentials
#   are in place. Discord publishes no addresses, and our own LZRCHT service
#   is coming, so no connector of theirs is ever given a connection.
#
# The drawing role may hand the clipboard one line of text, checked as text,
# only in its answer to a press of yours, and the window writes it only
# within five seconds of that press (sub cht_copied). Nothing reads the
# clipboard. Every line any role writes has one form, and a role that writes
# one of no form ends; the drawing role's end is LZRCHT's. Its tab ends every
# role, its connections with them, as does an address opened in it or its
# window's close. Each connection and each connector is a line of the log.
my $CHT_PROGRAM = 'core-lzrbrwsr-cht';    # its file name is the name Activity Monitor shows (docs/process-names.md)
my $CHT_CONFIG = '.config/lzrbrwsr/lzrcht.conf';    # under your home (DECLARED: src/cht/config.rs CONFIG_PATH)
my $CHT_HEAD = 'lzrcht-app-credentials 1';    # its first line (DECLARED: src/cht/config.rs HEAD)
my %CHT_NAMED = map { $_ => 1 } qw(telegram.api_id telegram.api_hash discord.client_id);    # the names of its paths (DECLARED: src/cht/config.rs locations)
my @CHT_SERVICES = qw(lzrcht telegram discord);    # in the keeper's order (DECLARED: src/cht/adapter.rs Service::ALL)
my $CHT_LINE = 65_536;                    # the longest line a role may write: a copy of one message, or a laid line
my $CHT_PAGE = 200_000;                   # the most lines of one page, and its bytes below
my $CHT_PAGE_BYTES = 16 << 20;
my $CHT_NET = 65_536;                     # the most bytes of one "=net" (DECLARED: src/cht/link.rs)
my $CHT_EVENT = 1 << 20;                  # the most bytes of one "=ev" (DECLARED: src/cht/link.rs, src/cht/main.rs)
my $CHT_HELD = 4 << 20;                   # the most held for a role or a connection before lzrprf reads no more of what feeds it
my $CHT_DIALS = 16;                       # the most connections one connector may ask for in its life
my %CHT_RANGES = (telegram => [qw(91.108.56.0/22 91.108.4.0/22 91.108.8.0/22 91.108.16.0/22 91.108.12.0/22 149.154.160.0/20 91.105.192.0/23 91.108.20.0/22 185.76.151.0/24)]);    # Telegram's own, as it publishes them (https://core.telegram.org/resources/cidr.txt, IPv4, read 2026-11-24); Discord publishes none
my @CHT_PORTS = (443, 80, 5222);          # the ports Telegram's servers serve

sub cht_opened {                          # the press: a new tab, its drawing role and its keeper started
    $CHT_OPEN = 0;
    return idle('An incognito or Tor window opens no LZRCHT: your messages would be kept on your disk, which such a window promises not to do.') if $INCOGNITO || $TOR_WINDOW;
    return idle("A window holds $TABS_MOST tabs at most: close one to open LZRCHT.") if @TABS >= $TABS_MOST;
    my ($program, $why) = cht_program();
    return idle("$why.") unless $program;
    my $draw = cht_box($program, 'draw', $TRMNL_CONTAINER, []) or return idle('LZRCHT could not be started: the system did not say that its container holds. Nothing was opened.');
    my $c = { program => $program, draw => $draw, links => {}, auth => {}, told => 0, asked => [], list => [] };
    $c->{keep} = cht_keeper($program);    # none: every platform waits for its credentials, as when none are placed
    $TABS[$TAB]{shown} = $SHOWN;
    push @TABS, fresh_tab();
    $TAB = $#TABS;
    undef $SHOWN;
    @{ $TABS[$TAB] }{qw(title cht says)} = ('LZRCHT', $c, 'LZRCHT: your messages, drawn by a container of its own that has no network; each platform connects only once it allows the connection.');
    noted('you opened LZRCHT: its drawing role and its keeper, each in a container of its own');
    tab_shown();
    live_told();
}

sub cht_program {                         # the program beside this application, as it was installed: its path, or nothing and why in full
    my $program = dirname($PROGRAM) . "/$CHT_PROGRAM";
    my ($named) = map { /^file \Q$CHT_PROGRAM\E ([0-9a-f]{64})$/ ? $1 : () } release_lines();
    return (undef, 'LZRCHT is not installed beside this application, so nothing was opened') unless -f $program && -x _;
    return (undef, 'LZRCHT is not the program this application was installed with, so nothing was opened. Installing again mends it') if $PROGRAM =~ m{\.app/Contents/MacOS/} && (!defined $named || $named ne (sum_of($program) // ''));
    return $program;
}

sub cht_box {                             # [C32] one role in its container, said by the system to be contained, handed its seal: its record, or nothing
    my ($program, $role, $profile, $defines, @words) = @_;
    return if $program =~ /["\\\n]/;
    pipe(my $in, my $to) && pipe(my $from, my $out) or return;
    my $seal = run_seal() // return;
    my $box = fork // return;
    if (!$box) {
        %ENV = (LZRPRF_SEAL => $seal);
        chdir '/';
        become($in, $out, $TRY ? \*STDERR : undef, '/bin/sh', '-c', $TRMNL_LIMITS, 'lzrprf', '/usr/bin/sandbox-exec', '-D', "APP=$program", @$defines, '-p', $profile, $program, @words);    # [C32]
    }
    close $_ for $in, $out;
    if (!inside($box)) {                  # [C3]
        kill 'KILL', $box;
        waitpid $box, 0;
        return;
    }
    fcntl($_, POSIX::F_SETFL(), O_NONBLOCK) for $to, $from;
    return { role => $role, box => $box, to => $to, from => $from, feed => "=seal $seal\n", heard => '', out => '' };
}

sub cht_keeper {                          # [C32] the keeper, which may read the config and the paths it names: lzrprf reads its first line and its paths, never a file it names
    my ($program) = @_;
    my $home = (getpwuid $<)[7] // return;
    my @read = ("$home/$CHT_CONFIG");
    if (sysopen my $in, $read[0], O_RDONLY | O_NOFOLLOW | O_NONBLOCK) {
        my $text = '';
        1 while length $text <= 4096 && sysread($in, $text, 4097 - length $text, length $text);
        my @lines = split /\n/, $text;
        my @paths;
        my $fit = length $text <= 4096 && @lines && shift(@lines) eq $CHT_HEAD;    # DECLARED: src/cht/config.rs MOST_FILE
        for (@lines) {
            next if /^\s*$/ || /^#/;
            my ($name, $path) = m{^([a-z._]{1,40}) (/[A-Za-z0-9 _.\@+~/-]{1,1024})$} or ($fit = 0, last);
            ($fit = 0, last) unless $CHT_NAMED{$name} && $path !~ m{/\.\.(?:/|$)};
            push @paths, $path;
        }
        push @read, @paths if $fit;       # a config of no form: the keeper reads it, refuses it whole, and says every platform waits
    }
    my $profile = $TRMNL_CONTAINER . '(allow file-read* ' . join(' ', map { "(literal (param \"F$_\"))" } 0 .. $#read) . ")\n";
    my $keep = cht_box($program, 'keep', $profile, [map { ('-D', "F$_=$read[$_]") } 0 .. $#read], 'keep', $read[0]) or return;
    noted('LZRCHT started its keeper, which may read its config and the ' . (@read - 1) . ' files it names, and nothing else');
    return $keep;
}

sub cht_send {                            # bytes for a role, written as it takes them
    my ($b, $bytes) = @_;
    return if $b->{ended};
    $b->{feed} .= $bytes;
    cht_fed($b);
}

sub cht_fed {
    my ($b) = @_;
    return unless !$b->{ended} && length $b->{feed};
    my $n = syswrite($b->{to}, $b->{feed});
    if (defined $n) { substr($b->{feed}, 0, $n, '') }
    elsif (!$!{EAGAIN} && !$!{EINTR}) { $b->{lost} = 'stopped reading' }
}

sub cht_tell {                            # a frame for the drawing role, which answers each with one page; what it answers to is kept, so a copy and a connector are taken only in an answer to a press
    my ($c, $frame, $kind) = @_;
    push @{ $c->{asked} }, $kind;
    cht_send($c->{draw}, $frame);
}

sub cht_sized {                           # the size of the tab, in points, to the drawing role, when it is not the size it was told last
    my ($tab) = @_;
    my $c = $tab->{cht} or return;
    my ($wide, $high) = trmnl_page();
    return if "$wide $high" eq ($c->{size} // '');
    $c->{size} = "$wide $high";
    cht_tell($c, "s $wide $high\n", 's');
}

sub cht_input {                           # [C32] what the window says in LZRCHT's tab: a press and the wheel reach its drawing role, and nothing else does
    my ($what) = @_;
    my $c = $TABS[$TAB]{cht} or return;
    if ($what =~ /^click $N $N$/ && $1 <= 200_000 && $2 <= 200_000) { cht_tell($c, "p $1 $2\n", 'p') }
    elsif ($what =~ /^wheel (-?)([1-9][0-9]{0,2})$/) { cht_tell($c, ($1 ? 'd' : 'u') . " $2\n", 'w') }
}

sub cht_shown {                           # LZRCHT's tab chosen: its last page, at the window's size
    my ($tab) = @_;
    my $c = $tab->{cht};
    window('address LZRCHT');
    cht_sized($tab);
    my ($wide, $high) = trmnl_page();
    my $list = @{ $c->{list} } ? $c->{list} : ["L${wide}x$high", "R0,0,$wide,$high,0c0f12ff"];    # before its first page: its ground (DECLARED: src/cht/paint.rs BG)
    window("page $TAB", @$list, '.');
    $c->{sent} = $list;
    $DRAWN = 1;
    window('secure none');
    nav_told();
    idle($tab->{says});
}

sub cht_units {                           # what a role wrote: its lines, and after "=net N" or "=ev N" those N bytes; and why it ended, when it did
    my ($b) = @_;
    my $got = sysread($b->{from}, $b->{heard}, 262_144, length $b->{heard});
    return ([]) if !defined $got && ($!{EAGAIN} || $!{EINTR});
    my @units;
    while (1) {
        if (my $need = $b->{need}) {
            last if length $b->{heard} < $need->[1];
            push @units, [$need->[0], substr($b->{heard}, 0, $need->[1], '')];
            delete $b->{need};
            next;
        }
        my $end = index($b->{heard}, "\n");
        last if $end < 0;
        my $line = substr($b->{heard}, 0, $end + 1, '');
        chop $line;
        return (\@units, 'wrote a line too long') if length $line > $CHT_LINE;
        if ($b->{role} eq 'link' && $line =~ /^=(net|ev) ([1-9][0-9]{0,6})$/) {
            return (\@units, 'wrote a count past its bound') if $2 > ($1 eq 'net' ? $CHT_NET : $CHT_EVENT);
            $b->{need} = [$1, 0 + $2];
            next;
        }
        push @units, [$line];
    }
    return (\@units, 'wrote a line too long') if !$b->{need} && length $b->{heard} > $CHT_LINE;
    return (\@units, $got ? undef : 'ended');
}

sub cht_drew {                            # [C32] what the drawing role wrote: whole pages, each checked; a copy and a connector asked for only in its answer to a press
    my ($tab, $c, $units) = @_;
    for (@$units) {
        my $line = $_->[0];
        if (my $page = $c->{page}) {
            return 'drew a page past its bound' if ($page->{bytes} += length $line) > $CHT_PAGE_BYTES;
            push @{ $page->{lines} }, $line;
            next if --$page->{left};
            delete $c->{page};
            cht_paged($tab, $c, $page->{lines}) or return 'drew a page that is not fit';
        }
        elsif (delete $c->{copying}) { cht_copied($tab, $line) or return 'handed a copy that is not text' }
        elsif ($line =~ /^=page ([1-9][0-9]{0,5})$/ && $1 <= $CHT_PAGE && @{ $c->{asked} }) { $c->{page} = { left => 0 + $1, lines => [], bytes => 0 } }
        elsif ($line eq '=copy 1' && ($c->{asked}[0] // '') eq 'p' && !$c->{copied}++) { $c->{copying} = 1 }
        elsif ($line =~ /^=link (lzrcht|telegram|discord) 0$/ && ($c->{asked}[0] // '') eq 'p') { cht_linked($c, $1, 0) }
        elsif ($line eq '=drawn' && @{ $c->{asked} }) { shift @{ $c->{asked} }; $c->{copied} = 0 }
        else { return 'wrote a line of no form' }
    }
    return;
}

sub cht_paged {                           # [C32] [C9] a whole page the drawing role drew: the lines of a laid page, checked as every laid line is, then drawn when its tab is shown
    my ($tab, $c, $lines) = @_;
    no warnings 'utf8';
    my ($wide, $high) = $lines->[0] =~ /^L${N}x$N$/ or return;
    return unless $wide >= 1 && $high >= 1 && $wide <= 20_000 && $high <= 20_000 && ($lines->[1] // '') =~ /^R/;
    utf8::decode($_) or return for @$lines;
    my $state = { wide => $wide, high => $high, text => 0, pixels => 0, rows => 0, row_bytes => 0, row_chars => 0, count => {}, tile => {} };
    laid_run($lines, 1, $#$lines, $state, [], []) or return;
    return if $state->{rows};             # a picture cut short
    utf8::encode($_) for @$lines;
    $c->{list} = $lines;
    return 1 unless $tab == $TABS[$TAB];
    live_window_patch($c->{sent}, $lines);
    $c->{sent} = $lines;
    $DRAWN = 1;
    return 1;
}

sub cht_copied {                          # [C32] the text of a Copy you pressed: one line, text with no control character, handed to the window, which writes it to the clipboard only within five seconds of your press
    my ($tab, $text) = @_;
    my $chars = $text;
    return unless utf8::decode($chars) && $chars !~ /\p{Cc}/;
    return 1 unless length $text && $tab == $TABS[$TAB];
    (my $said = $text) =~ s/(%)/%25/g;
    window("trmnlcopy $said");
    aside('Copied ' . length($chars) . (length($chars) == 1 ? ' character' : ' characters') . ' to the clipboard.');
    return 1;
}

sub cht_kept {                            # [C32] what the keeper said: whether each platform's credentials are in place, once each, in its order, to the drawing role as a word and nothing more
    my ($c, $units) = @_;
    for (@$units) {
        my $service = $CHT_SERVICES[$c->{told}] // return 'said more than it has to say';
        my ($placed) = $_->[0] =~ /^=auth \Q$service\E ([01])$/ or return 'wrote a line of no form';
        $c->{told}++;
        $c->{auth}{$service} = 0 + $placed;
        cht_tell($c, "a $service $placed\n", 'a');
    }
    return;
}

sub cht_linked {                          # [C32] a connector asked for in the answer to your press: started in a container with no network, once its platform's credentials are in place
    my ($c, $service, $slot) = @_;
    return if $c->{links}{"$service $slot"};
    return cht_tell($c, "x $service $slot LZRBRWSR is not yet authorized by $service\n", 'x') unless $c->{auth}{$service};
    my $link = cht_box($c->{program}, 'link', $TRMNL_CONTAINER, [], 'link', $service, $slot) or return cht_tell($c, "x $service $slot its container did not start\n", 'x');
    @$link{qw(service slot dials)} = ($service, $slot, 0);
    $c->{links}{"$service $slot"} = $link;
    noted("LZRCHT started a $service connector, in a container of its own with no network");
}

sub cht_reachable {                       # [C32] whether lzrprf opens a connection for a connector of $service to $ip, port $port: an IPv4 address in its one form inside a range that platform publishes, on a port it serves
    my ($service, $ip, $port) = @_;
    my $byte = qr/(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/;
    return 0 unless $ip =~ /\A$byte\.$byte\.$byte\.$byte\z/ && grep { $_ == $port } @CHT_PORTS;
    my $at = unpack 'N', pack 'C4', split /\./, $ip;    # numbers alone: nothing here can look a name up
    for (@{ $CHT_RANGES{$service} // [] }) {
        my ($net, $bits) = split m{/};
        my $mask = (0xffffffff << (32 - $bits)) & 0xffffffff;
        return 1 if ($at & $mask) == (unpack('N', pack 'C4', split /\./, $net) & $mask);
    }
    return 0;
}

sub cht_heard_link {                      # [C32] what a connector wrote: a connection to open, bytes for it, an event for the drawing role, or its end
    my ($c, $link, $units) = @_;
    my ($service, $slot) = @$link{qw(service slot)};
    for (@$units) {
        my ($kind, $bytes) = @$_;
        if ($kind eq 'net') { return 'wrote for a connection it does not have' unless $link->{up}; $link->{out} .= $bytes }
        elsif ($kind eq 'ev') { cht_tell($c, "e $service $slot " . length($bytes) . "\n$bytes", 'e') }
        elsif ($kind =~ /^=dial ([0-9.]{7,15}) ([1-9][0-9]{0,4})$/) {
            my ($ip, $port) = ($1, $2);
            return "asked for $ip port $port, which is no address $service publishes" unless cht_reachable($service, $ip, $port);
            return 'asked for a second connection' if $link->{sock};
            return "asked for more than $CHT_DIALS connections" if ++$link->{dials} > $CHT_DIALS;
            cht_dialed($link, $ip, $port);
        }
        elsif ($kind =~ /^=down ([\x20-\x7e]{1,200})$/) { return $1 }
        else { return 'wrote a line of no form' }
    }
    return;
}

sub cht_dialed {                          # [C32] a connector's one connection, opened and held by lzrprf as you: TCP to an address its platform publishes, a line of the log
    my ($link, $ip, $port) = @_;
    noted("LZRCHT's $link->{service} connector asked for $ip port $port, an address $link->{service} publishes: lzrprf opened that connection for it");
    socket(my $sock, AF_INET, SOCK_STREAM, 0) or return cht_send($link, "=gone no socket was to be had\n");
    fcntl($sock, POSIX::F_SETFL(), O_NONBLOCK);
    if (connect($sock, pack_sockaddr_in($port, pack 'C4', split /\./, $ip))) { @$link{qw(sock up)} = ($sock, 1); return cht_send($link, "=up\n") }    # [C32] the address cht_reachable checked, as four numbers
    return cht_send($link, "=gone the connection was refused\n") unless $!{EINPROGRESS};
    @$link{qw(sock dialing)} = ($sock, 1);
}

sub cht_hung {                            # a connector's connection closed, and the connector told why
    my ($link, $why) = @_;
    close delete $link->{sock};
    delete @$link{qw(up dialing)};
    $link->{out} = '';
    noted("a connection of LZRCHT's $link->{service} connector closed: $why");
    cht_send($link, "=gone $why\n");
}

sub cht_net {                             # a connection ready: its opening finished, bytes read for the connector, bytes written from it
    my ($link, $ready, $writable) = @_;
    my $sock = $link->{sock};
    if ($link->{dialing}) {
        return unless vec($writable, fileno $sock, 1);
        my $error = unpack 'i', getsockopt($sock, SOL_SOCKET, SO_ERROR) // pack('i', 1);
        return cht_hung($link, 'the connection could not be opened') if $error;
        delete $link->{dialing};
        $link->{up} = 1;
        return cht_send($link, "=up\n");
    }
    if (vec($ready, fileno $sock, 1)) {
        my $got = sysread($sock, my $bytes, $CHT_NET);
        return if !defined $got && ($!{EAGAIN} || $!{EINTR});
        return cht_hung($link, 'the other end closed the connection') unless $got;
        cht_send($link, "=net $got\n$bytes");
    }
    if (length $link->{out} && vec($writable, fileno $sock, 1)) {
        my $n = syswrite($sock, $link->{out});
        if (defined $n) { substr($link->{out}, 0, $n, '') }
        elsif (!$!{EAGAIN} && !$!{EINTR}) { cht_hung($link, 'the connection failed') }
    }
}

sub cht_box_end {                         # a role ended, its connection closed, and waited for
    my ($b) = @_;
    return if $b->{ended}++;
    close delete $b->{sock} if $b->{sock};
    kill 'KILL', $b->{box};
    waitpid $b->{box}, 0;
    close $_ for grep { defined } @$b{qw(to from)};
    delete @$b{qw(to from)};
}

sub cht_unlinked {                        # a connector ended: its connection with it, and the drawing role told why
    my ($c, $link, $why) = @_;
    cht_box_end($link);
    delete $c->{links}{"$link->{service} $link->{slot}"};
    noted("LZRCHT's $link->{service} connector ended: $why");
    $why =~ s/[^\x20-\x7e]//g;
    cht_tell($c, "x $link->{service} $link->{slot} $why\n", 'x');
}

sub cht_end {                             # LZRCHT ended: every role and every connection
    my ($tab, $why) = @_;
    my $c = delete $tab->{cht} or return;
    cht_box_end($_) for cht_boxes($c);
    noted("LZRCHT ended: $why");
    $tab->{says} = "LZRCHT ended: $why.";
    return unless $tab == $TABS[$TAB];
    window("page $TAB", @{ $c->{sent} // [] }, '.');
    live_told();
    idle($tab->{says});
}

sub cht_boxes { my ($c) = @_; return grep { defined && !$_->{ended} } $c->{draw}, $c->{keep}, values %{ $c->{links} } }

sub cht_select {                          # the roles' descriptors and the connections, for the wait of sub hear; what feeds a role that does not read is not read
    my ($ready, $writable) = @_;
    for my $c (map { $_->{cht} // () } @TABS) {
        my $full = length $c->{draw}{feed} > $CHT_HELD;
        for my $b (cht_boxes($c)) {
            vec($$ready, fileno $b->{from}, 1) = 1 if $b == $c->{draw} || !$full && length $b->{out} < $CHT_HELD;
            vec($$writable, fileno $b->{to}, 1) = 1 if length $b->{feed};
            my $sock = $b->{sock} or next;
            vec($$ready, fileno $sock, 1) = 1 if !$b->{dialing} && length $b->{feed} < $CHT_HELD;
            vec($$writable, fileno $sock, 1) = 1 if $b->{dialing} || length $b->{out};
        }
    }
}

sub cht_heard {                           # what the wait of sub hear found ready, for each role of each LZRCHT
    my ($ready, $writable) = @_;
    for my $tab (grep { $_->{cht} } @TABS) {
        my $c = $tab->{cht};
        for my $b (cht_boxes($c)) {
            last unless $tab->{cht};
            next if $b->{ended};
            cht_fed($b) if vec($writable, fileno $b->{to}, 1);
            cht_net($b, $ready, $writable) if $b->{sock};
            my ($units, $why) = vec($ready, fileno $b->{from}, 1) ? cht_units($b) : ([]);
            $why //= $b->{lost};
            if ($b->{role} eq 'draw') { my $wrong = cht_drew($tab, $c, $units) // $why; cht_end($tab, "its drawing container $wrong") if defined $wrong }
            elsif ($b->{role} eq 'keep') { my $wrong = cht_kept($c, $units) // $why; if (defined $wrong) { cht_box_end($b); delete $c->{keep}; noted("LZRCHT's keeper $wrong") } }
            else { my $wrong = cht_heard_link($c, $b, $units) // ($why && "its container $why"); cht_unlinked($c, $b, $wrong) if defined $wrong }
        }
    }
}

sub cht_fds { return map { my $c = $_->{cht}; $c ? map({ grep { defined } @$_{qw(to from sock)} } cht_boxes($c)) : () } @TABS }    # for a copy of lzrprf that goes on as perl: it lets go of every role and connection
