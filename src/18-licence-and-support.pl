# The support member licence. "Enter licence code" in the cogwheel's menu
# opens a field for the code you got when you bought the application. A code
# is 120 letters and digits: 75 bytes written in Crockford's base32, read here
# as they are written, with case, spaces and dashes left aside, O read as 0
# and I and L as 1. One byte says its kind (17: a support member), two the
# month it was bought in (months since January 2026), eight are its own
# number, and 64 are an Ed25519 signature over the words LZRBRWSR-LICENCE-1
# and the eleven bytes before it. lzrprf checks that signature itself, with
# the public key below and the system's perl alone (Math::BigInt and
# Digest::SHA), and fetches nothing for it. A code that checks is kept in one
# plain file of yours, licence, written by lzrprf alone; removing the code
# removes the file. An incognito window offers neither this nor a support
# request: both keep something.                                          # [C16]
my $LICENCE_KEY = 'ed25519 none';         # the public key of the licence codes, as their maker publishes it: "ed25519 " and its 32 bytes in base64. "none" until it is made: a code is then checked here by its form, and by its signature where a support request goes
my $CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
my @MONTHS = qw(January February March April May June July August September October November December);
my %LICENCE_WHY = (empty => 'Type or paste your licence code first.', form => 'That is not a licence code: a code has 120 letters and digits, in groups of 5.', kind => 'That code is not a support member licence.', signature => 'That code does not check: a letter may be mistyped. Paste it as it was given to you.');

sub licence_key {                         # the 32 bytes of the public key, or nothing while there is none
    my $line = $LICENCE_KEY;
    if ($TRY && open my $in, '<', "$ROOT/licence-key") { $line = <$in> // ''; chomp $line }    # "lzrprf try" only: the test's own key, with codes it signed itself
    my ($text) = $line =~ m{^ed25519 ([A-Za-z0-9+/]{43}=)$} or return;
    my $raw = decode_base64($text);
    return length $raw == 32 ? $raw : undef;
}

sub licence_read {                        # a code as it was typed: its 75 bytes, or nothing and why ("empty", "form", "kind")
    my ($typed) = @_;
    (my $code = uc($typed // '')) =~ s/[\s-]//g;
    return (undef, 'empty') unless length $code;
    $code =~ tr/OIL/011/;
    return (undef, 'form') unless length $code == 120 && $code =~ /^[0-9A-HJKMNP-TV-Z]+$/;
    my $bytes = pack 'B600', join '', map { sprintf '%05b', index $CROCKFORD, $_ } split //, $code;
    return (undef, 'kind') unless ord $bytes == 17;
    return $bytes;
}

sub licence_written { my ($bytes) = @_; return join '-', unpack '(A5)*', join '', map { substr $CROCKFORD, oct("0b$_"), 1 } unpack '(A5)*', unpack 'B600', $bytes }    # the 75 bytes as the seller writes them: 24 groups of 5
sub licence_month { my ($bytes) = @_; my $month = unpack 'n', substr $bytes, 1, 2; return $MONTHS[$month % 12] . ' ' . (2026 + int($month / 12)) }

sub licence_checked {                     # a code typed: (its bytes, "signed" or "form" for a code checked by its form alone while there is no key), or (nothing, why)
    my ($typed) = @_;
    my ($bytes, $why) = licence_read($typed);
    return (undef, $why) unless $bytes;
    my $key = licence_key() // return ($bytes, 'form');
    return signed($key, 'LZRBRWSR-LICENCE-1' . substr($bytes, 0, 11), substr($bytes, 11)) ? ($bytes, 'signed') : (undef, 'signature');
}

# Ed25519 (RFC 8032, section 5.1.7): the signature (R, S) of a message holds
# when S is below the group's order L and S times the base point equals R plus
# h times the key, h being SHA-512 of R, the key and the message, taken modulo
# L. Here S*B and (L-h)*A are added in one pass over the bits of both
# numbers, and the sum must be R itself, byte for byte. Points are kept in
# extended coordinates (X, Y, Z, T), x = X/Z, y = Y/Z, xy = T/Z.
sub signed {
    my ($key, $message, $signature) = @_;
    require Math::BigInt;
    my $two = Math::BigInt->new(2);
    my $p = $two->copy->bpow(255)->bsub(19);
    my $order = $two->copy->bpow(252)->badd('27742317777372353535851937790883648493');
    my $inverse = sub { $_[0]->copy->bmodpow($p->copy->bsub(2), $p) };
    my $d = Math::BigInt->new(-121665)->bmul($inverse->(Math::BigInt->new(121666)))->bmod($p);
    my $number = sub { Math::BigInt->from_hex(unpack 'H*', scalar reverse $_[0]) };    # 32 bytes, the least first
    my $sum = sub {
        my ($u, $v) = @_;
        my ($m, $n) = ((($u->[1] - $u->[0]) * ($v->[1] - $v->[0])) % $p, (($u->[1] + $u->[0]) * ($v->[1] + $v->[0])) % $p);
        my ($c, $e) = ((2 * $d * $u->[3] * $v->[3]) % $p, (2 * $u->[2] * $v->[2]) % $p);
        my ($f, $g, $h, $k) = ($n - $m, $e - $c, $e + $c, $n + $m);
        return [($f * $g) % $p, ($h * $k) % $p, ($g * $h) % $p, ($f * $k) % $p];
    };
    my $point = sub {                     # 32 bytes as a point of the curve, or nothing
        my $y = $number->($_[0]);
        my $odd = $y->copy->brsft(255)->is_one;
        $y->bmod($two->copy->bpow(255));
        return if $y >= $p;
        my $xx = (($y * $y - 1) * $inverse->(($d * $y * $y + 1) % $p)) % $p;
        my $x = $xx->copy->bmodpow(($p + 3) / 8, $p);
        $x = ($x * $two->copy->bmodpow(($p - 1) / 4, $p)) % $p if ($x * $x - $xx) % $p != 0;
        return if ($x * $x - $xx) % $p != 0 || $x->is_zero && $odd;
        $x = $p - $x if $x->is_odd != $odd;
        return [$x, $y, Math::BigInt->new(1), ($x * $y) % $p];
    };
    my $base = $point->(pack 'H*', '58' . '66' x 31);
    my $held = $point->($key) or return 0;
    my $s = $number->(substr $signature, 32);
    return 0 if $s >= $order;
    my $h = $number->(Digest::SHA::sha512(substr($signature, 0, 32) . $key . $message)) % $order;
    my @adds = (undef, $base, $held, $sum->($base, $held));
    my ($one, $other) = map { substr $_->as_bin, 2 } $s, ($order - $h) % $order;
    $_ = ('0' x (256 - length)) . $_ for $one, $other;
    my $at = [Math::BigInt->new(0), Math::BigInt->new(1), Math::BigInt->new(1), Math::BigInt->new(0)];
    for my $i (0 .. 255) {
        $at = $sum->($at, $at);
        my $which = substr($one, $i, 1) + 2 * substr($other, $i, 1);
        $at = $sum->($at, $adds[$which]) if $which;
    }
    my $z = $inverse->($at->[2]);
    my ($x, $y) = (($at->[0] * $z) % $p, ($at->[1] * $z) % $p);
    $y->badd($two->copy->bpow(255)) if $x->is_odd;
    my $hex = substr $y->as_hex, 2;
    return scalar(reverse pack 'H*', ('0' x (64 - length $hex)) . $hex) eq substr($signature, 0, 32);
}

sub licence_kept {                        # the code kept, as written, and its bytes; nothing when none is kept
    return if $INCOGNITO;
    open my $in, '<', "${\ shared()}/licence" or return;
    my $line = <$in> // '';
    chomp $line;
    my ($bytes) = licence_read($line);
    return unless $bytes;
    return ($line, $bytes);
}

sub licence_told { my (undef, $bytes) = licence_kept(); window($INCOGNITO ? 'licence off' : $bytes ? 'licence kept ' . licence_month($bytes) : 'licence none') }
sub licence_refused { my ($says) = @_; window("licence refused $says"); return idle($says) }

sub licence_set {
    my ($typed) = @_;
    return licence_refused("$UNKEPT, so it keeps no licence code.") if $INCOGNITO;    # [C16]
    busy('Checking the licence code on this Mac.');
    my ($bytes, $how) = licence_checked($typed);
    return licence_refused($LICENCE_WHY{$how}) unless $bytes;
    my $month = licence_month($bytes);
    record('you entered a support member licence code: it is kept in the file licence, and is not written here') or return licence_refused('The licence code was not kept: its line could not be written to the log.');
    unlink "${\ shared()}/licence.new";
    return licence_refused('The licence code was not kept: its file could not be written.') unless put("${\ shared()}/licence.new", O_EXCL, licence_written($bytes)) && rename("${\ shared()}/licence.new", "${\ shared()}/licence");
    synced(shared());
    window("licence kept $month");
    return idle("The licence code is kept: this browser is a support member's, since $month. " . ($how eq 'signed' ? 'It was checked on this Mac. A support request you send carries it, so it is answered first.' : 'Its form was checked on this Mac; its signature is checked where a support request goes, and a request you send carries it, so it is answered first.'));
}

sub licence_removed {
    return licence_refused("$UNKEPT, so it keeps no licence code.") if $INCOGNITO;    # [C16]
    my $had = -e "${\ shared()}/licence";
    unlink "${\ shared()}/licence.new";
    return licence_refused('The licence code could not be removed: its file is still there.') if $had && !unlink "${\ shared()}/licence";
    synced(shared());
    record('you removed the support member licence code, and its file') if $had;
    window('licence none');
    return idle($had ? 'The licence code was removed, and its file with it. Support requests now go without it.' : 'No licence code was kept.');
}

# A support request. "Support request" in the cogwheel's menu opens a box for
# your words, a support question or a feature you would like. It goes to the
# one address the application's release file names for it, the line
# "support", and to no other: never a host the window or a page gives. It is
# a POST of JSON, sent as every fixed request is (sub fixed): its line in the
# log first, through the one place that connects, by curl in its container,
# with the fixed lines of [C7] and the body. The body holds exactly: "text",
# your words and then one line with the number of this release; "licence",
# the code you entered, only when one is kept; and "screenshot", a PNG of the
# window drawn by the window itself into a picture of its own, only when you
# ticked it, which shows the page in it and the address in its bar. Nothing
# else: no address of a page besides what that picture shows, no history, no
# name of this computer or of you. The window lists all
# of it before Send. The log says that a request was sent, never its words.
# The answer names the request's reference and a key, given once; both are
# kept in one plain file of yours, support, so that "Read the answer" can
# read the answer later: a GET of the reference's address under the support
# address, with the key in the line Authorization, which curl takes on its
# input, so no list of processes shows it. A request sent later replaces the
# one kept, and "Forget it" removes the file.                    # [C4] [C7]
my $SUPPORT_TEXT = 4000;                  # DECLARED(the most characters the support address takes in one request, the release line counted)
my $SUPPORT_PICTURE = 2 * 1024 * 1024;    # DECLARED(the largest PNG the support address takes)
my $SUPPORT_MESSAGES = 100;               # DECLARED(the most messages of one request the window is shown)

sub support_address {                     # the support address the release file names: (address, host), or nothing
    return if $INCOGNITO;                 # [C16]
    my ($line) = map { /^support (https:\/\/\S+)$/ ? $1 : () } release_lines();
    my ($url, $host) = address($line // '');
    return unless $url && $url eq $line && $url =~ m{^https://[^/?#]+(?:/[A-Za-z0-9_-]+)+$};    # the line as lzrprf would fetch it, and a plain path with no query: the reference is added to it
    return ($url, $host);
}

sub support_kept { return if $INCOGNITO; open my $in, '<', "${\ shared()}/support" or return; my $line = <$in> // ''; return $line =~ /^([A-Za-z0-9_-]{22}) ([A-Za-z0-9_-]{43})\n?\z/ ? ($1, $2) : () }    # the reference and the key of the request sent last
sub support_told { my (undef, $host) = support_address(); my ($ticket) = support_kept(); my ($release) = beside(); window($INCOGNITO ? 'support off incognito' : $host && defined $release ? "support on $host $release" : 'support off none', 'support kept ' . ($host && $ticket ? $ticket : '-')) }
sub support_failed { my ($says) = @_; window("support failed $says"); return idle($says) }

sub support_words {                       # the words the window sent, in base64 of UTF-8: as text with no control or format character but line ends and tabs, or nothing
    my ($text) = @_;
    return if length $text > 4 * int((4 * $SUPPORT_TEXT + 2) / 3);    # more bytes than the most characters can take, each of four bytes
    require Encode;
    $text = eval { Encode::decode('UTF-8', decode_base64($text), Encode::FB_CROAK()) } // return;
    $text =~ s/\r\n?/\n/g;
    $text =~ s/[\x00-\x08\x0b-\x1f\x7f-\x9f\x{ad}\x{200b}-\x{200f}\x{2028}-\x{202e}\x{2060}-\x{206f}\x{feff}\x{fff9}-\x{fffb}]//g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

sub support_picture {                     # a PNG as the window draws one: its signature, IHDR first and IEND last, at most $SUPPORT_PICTURE bytes; or nothing
    my ($text) = @_;
    return unless length $text <= 4 * int(($SUPPORT_PICTURE + 2) / 3) && length($text) % 4 == 0 && $text =~ /^[A-Za-z0-9+\/]+={0,2}$/;
    my $png = decode_base64($text);
    return unless length $png >= 57 && length $png <= $SUPPORT_PICTURE && substr($png, 0, 8) eq "\x89PNG\r\n\x1a\n" && substr($png, 12, 4) eq 'IHDR' && substr($png, -8, 4) eq 'IEND';
    return $png;
}

sub support_answer {                      # what the support address answered: (status, its JSON as Perl data); nothing for an answer in no such form
    my ($got, $method) = @_;
    my ($status, undef, $body) = @{ live_parts($got, $method) // [] } or return;
    require JSON::PP;
    my $data = eval { JSON::PP->new->utf8->max_depth(8)->decode($body) };
    return ($status, ref $data eq 'HASH' ? $data : undef);
}

sub support_problem {                     # why the support address took nothing, in plain words
    my ($status, $data) = @_;
    my ($first) = ref $data && ref $data->{problems} eq 'ARRAY' ? grep { defined && !ref } @{ $data->{problems} } : ();
    return 'it does not take support requests yet' if ($status // '') eq '503';
    return 'too many requests reached it just now; try again in an hour' if ($status // '') eq '429';
    return 'the request is too large' if ($status // '') eq '413';
    return 'it answered ' . ($status // 'in no form lzrprf reads') . (defined $first ? ': ' . tool_plain($first, 200) : '');
}

sub support_sent {
    my ($words, $picture) = @_;
    return support_failed("$UNKEPT, so it sends no support request.") if $INCOGNITO;    # [C16]
    my ($url, $host) = support_address() or return support_failed('This application names no address for support requests, so nothing was sent.');
    my ($release) = beside();
    return support_failed('This application has no release number, so nothing was sent.') unless defined $release;
    my $last = "Release $release";
    my $text = support_words($words) // return support_failed('Your words could not be read, so nothing was sent.');
    return support_failed('Write what the request is about first. Nothing was sent.') unless length $text;
    return support_failed('The words are longer than ' . ($SUPPORT_TEXT - length($last) - 2) . ' characters. Nothing was sent.') if length($text) + 2 + length($last) > $SUPPORT_TEXT;
    my $png;
    if ($picture ne '-') { $png = support_picture($picture) // return support_failed('The picture of the window is not one lzrprf sends, so nothing was sent.') }
    my ($code) = licence_kept();
    require JSON::PP;
    my $json = JSON::PP->new->ascii->allow_nonref;
    my $body = '{"text":' . $json->encode("$text\n\n$last") . (defined $code ? ',"licence":' . $json->encode($code) : '') . (defined $png ? ',"screenshot":"' . encode_base64($png, '') . '"' : '') . '}';
    busy("Sending your support request to $host.");
    my $got = fixed('you sent a support request' . (defined $code ? ', with your licence code' : '') . (defined $png ? ', with a picture of the window' : '') . ": $url", $url, $host, { method => 'POST', body => $body, type => 'application/json' });
    return support_failed($UNSAID ? 'lzrprf tried to send the request. Whether it arrived is not shown: the line that says how it ended could not be written to the log.' : 'The request could not be sent. The log says why.') unless defined $got;
    my ($status, $data) = support_answer($got, 'POST');
    my ($ticket, $key) = $data ? ($data->{ticket} // '', $data->{key} // '') : ('', '');
    return support_failed('The support address did not take the request: ' . support_problem($status, $data) . '.') unless ($status // '') eq '200' && $ticket =~ /^[A-Za-z0-9_-]{22}\z/ && $key =~ /^[A-Za-z0-9_-]{43}\z/;
    unlink "${\ shared()}/support.new";
    my $kept = put("${\ shared()}/support.new", O_EXCL, "$ticket $key") && rename("${\ shared()}/support.new", "${\ shared()}/support");
    synced(shared());
    my $licence = ($data->{licence} // '') =~ /^(none|accepted|refused)\z/ ? $1 : 'none';
    window("support sent $ticket " . ($data->{priority} ? 'priority' : 'plain') . " $licence", 'support kept ' . ($kept ? $ticket : '-'));
    return idle("Your support request was sent. Its reference is $ticket." . ($licence eq 'accepted' ? ' It goes with your licence code, so it is answered first.' : $licence eq 'refused' ? ' Your licence code was not taken, so it goes without priority.' : '') . ($kept ? ' Read the answer later from Support request in the cogwheel\'s menu.' : ' Its key could not be kept, so its answer cannot be read here.'));
}

sub support_read {
    return support_failed("$UNKEPT, so it reads no support request.") if $INCOGNITO;    # [C16]
    my ($url, $host) = support_address() or return support_failed('This application names no address for support requests.');
    my ($ticket, $key) = support_kept() or return support_failed('No support request is kept here.');
    require Encode;
    busy("Reading the answer to your support request from $host.");
    my $got = fixed("you read the answer to your support request: $url/$ticket", "$url/$ticket", $host, { method => 'GET', key => $key });
    return support_failed('The answer could not be read. The log says why.') unless defined $got;
    my ($status, $data) = support_answer($got, 'GET');
    return support_failed('The support address knows no request by this reference and key now.') if ($status // '') eq '404';
    return support_failed('The answer could not be read: ' . support_problem($status, $data) . '.') unless ($status // '') eq '200' && $data && ref $data->{messages} eq 'ARRAY';
    my $state = ($data->{status} // '') =~ /^(open|answered|resolved|rejected)\z/ ? $1 : 'open';
    my $shown = sub { my ($text, $most) = @_; $text = defined $text && !ref $text ? "$text" : ''; $text =~ s/[\x00-\x08\x0b-\x1f\x7f-\x9f\x{ad}\x{200b}-\x{200f}\x{2028}-\x{202e}\x{2060}-\x{206f}\x{feff}]//g; return encode_base64(Encode::encode('UTF-8', substr($text, 0, $most)), '') };    # words of the answer, shown as text and nowhere acted on
    my @messages = grep { ref eq 'HASH' } @{ $data->{messages} };
    splice @messages, 0, @messages - $SUPPORT_MESSAGES if @messages > $SUPPORT_MESSAGES;    # the newest are shown
    my @lines = ("support thread $state " . $shown->($data->{reason}, 300));
    for my $one (@messages) {
        my $author = ($one->{author} // '') =~ /^(user|support|agent)\z/ ? $1 : next;
        my $at = ($one->{at} // '') =~ /^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2})/ ? $1 : '-';
        push @lines, "support message $author $at " . $shown->($one->{body}, $SUPPORT_TEXT);
    }
    window(@lines, 'support thread end');
    return idle("The answer to your support request $ticket is shown: it is $state.");
}

sub support_forgot {
    return support_failed("$UNKEPT, so it keeps no support request.") if $INCOGNITO;    # [C16]
    my $had = -e "${\ shared()}/support";
    unlink "${\ shared()}/support.new";
    return support_failed('The support request could not be forgotten: its file is still there.') if $had && !unlink "${\ shared()}/support";
    synced(shared());
    window('support kept -');
    return idle($had ? 'The support request is forgotten here: its reference and key were removed. Its answer can no longer be read on this Mac.' : 'No support request was kept.');
}

