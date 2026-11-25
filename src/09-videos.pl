# A video of the page shown, when you click its place V [C22]: the kth MP4
# file or HLS stream of the page's =videos line, which the application named
# as it names pictures. Nothing of it is fetched before you click. Then it is fetched
# once, the way a picture is (sub pictured): a path from the page's own
# host, or an address on another site only when it stands in the page's
# own text, at most $PICTURE_SITES other sites for one page's pictures and
# videos together, "Block pictures from other sites" stops every one, its
# lines in the log first, through Tor when Tor is on, and never inside your
# own network. The request is the fixed request of a picture, with no Range:
# the whole file in one answer, at most $VIDEO_BYTES in $VIDEO_SECONDS, or
# the box says it is too large; an address ending .m3u8 is asked for at
# most $HLS_PLAYLIST, and so is an answer whose type says it is a playlist.
# An answer is refused as soon as its first bytes are not "HTTP/1.1 200 "
# (a 1xx head in front of it too, as sub body_of plays no other answer), and
# so is one whose head does not end within 64 KiB, an MP4 file's as well as
# a playlist's, so no head is long enough to hide a playlist's type. An
# answer that begins as an HLS playlist does
# ("#EXTM3U") is a stream, which sub hls_fetched follows and joins into one
# file. Any other answer that is not 200 or does not begin as an MP4 file
# does ("ftyp" as its first box) is no video. The window is given its bytes
# in base64, $VIDEO_FRAME at a time, "video TAB K begin LENGTH" (with " ts"
# after it for a joined MPEG-TS stream), parts, then "end", or "video TAB K
# none WORDS" for one line in the box; a stream locked by a key is said in
# the bottom bar too. The window holds the file in its memory and hands it to the system's
# video player, whose decoder service decodes it: a site's bytes now reach
# the operating system's decoder through the window, and nothing else of a
# site does (README, [C22]).
sub videoed {
    my ($k) = @_;
    $VIDEO_CLICKED = $k;
    my $back = strip_back();
    my $shown = $SHOWN;
    my $entry = $shown && $shown->{videos} ? $shown->{videos}[$k] : undef;
    my $none = sub { window("video $TAB $k none $_[0]"); $back->() };    # the one line the box shows in place of the video
    return $none->('This video is no longer on the page shown.') unless defined $entry;    # nothing is fetched
    my $host = $shown->{host};
    if (listed($entry =~ m{^/} ? "https://$host$entry" : $entry)) { refused("a video the page $host names", (keeping())[0]) or return $none->($UNWRITTEN); return $none->("$REFUSED $REFUSED_HELP") }    # [C23] nothing is looked up or fetched, and the box says why
    my ($url, $there) = $entry =~ m{^/} ? ("https://$host$entry") : address($entry);    # another host: checked as a typed address is
    return $none->('lzrprf does not fetch this address.') unless defined $url;
    if (my $filter = filter_said($url, 'media', $host)) { record("$url not fetched: $filter", (keeping())[0]) or return $none->($UNWRITTEN); return $none->("This video is not fetched: $filter.") }    # [C27] after [C23]: nothing is looked up or fetched
    my $other = defined $there && elsewhere($there, $host);
    open my $request, '>>', "$DIR/busy" or return $none->($UNWRITTEN);
    flock $request, LOCK_SH or return $none->($UNWRITTEN);    # as in visit: no line of this request falls into a clearing of the log
    my ($kept) = keeping();
    record("you clicked a video of the page $host: $url", $kept) or return $none->($UNWRITTEN);    # [C5] before the name is even looked up
    my $refused = sub { record("$url not fetched: $_[0]", $kept) or return $none->($UNWRITTEN); return $none->(ucfirst "$_[0].") };
    return $refused->("videos from other sites are blocked (Block pictures from other sites, in the cogwheel's menu, holds for videos too)") if $other && !pictures_elsewhere();    # [C4]
    return $refused->("the page $host does not name that address in its text") if $other && !named_in((body_of($shown->{got}) // '') =~ s/&amp;/&/gr, $there, $url);    # [C4] the application named it, and may be hostile
    my $sites = $shown->{sites} //= [];
    return $refused->("the page $host asks more than $PICTURE_SITES other sites for its pictures and videos, and lzrprf asks at most $PICTURE_SITES for one page") if $other && !grep({ $_ eq $there } @$sites) && @$sites >= $PICTURE_SITES;    # [C4]
    my $on = $there // $host;
    if ($on ne $host) { record("the page $host names a video on $on: $url", $kept) or return $none->($UNWRITTEN) }
    my $shield = shield_said($url);
    return $refused->(shield_why($shield)) if $shield ne 'allow';    # [C28] before a video's DNS lookup
    busy($TOR_WANTED ? "Asking Tor for $on." : "Looking up $on.");
    my ($to, $where_why) = $TOR_WANTED ? tor_where($on) : find($on);    # looked up at each click, the page's own host too: Tor turned on since the visit is taken, and a yes you gave once for a host of your own network is not
    if ($to && grep { $_->{own} } @$to) { ($to, $where_why) = (undef, "$on leads inside your own network (" . join(', ', map { $_->{text} } @$to) . '), where no video is fetched') }    # [C8] never for a video, and nothing is asked
    return $refused->($where_why // "$on is at no address lzrprf has") unless $to;
    push @$sites, $on if $other && !grep { $_ eq $on } @$sites;
    my $connects = $TOR_WANTED ? 'through Tor, one circuit for ' . ($there // $host) : 'to the first that answers of: ' . join(', ', map { $_->{text} } @$to);
    record("$url -> lzrprf connects $connects", $kept) or return $none->($UNWRITTEN);    # [C5] written down first, connected second
    busy("Fetching the video: $url");
    my ($until, $stop, $listed) = (now() + $VIDEO_SECONDS, video_stop(), $url =~ m{^https://[^/?]*/[^?]*\.m3u8(?:\?|\z)}i);    # one clock for all of this video: a stream's playlists and segments too are fetched within its 120 seconds
    my ($typed, $over) = (undef, undef);    # whether the answer's head says it is an HLS playlist, and whether more of it came than a playlist is read ('status' when it does not begin as an answer 200, 'head' when its head ran past 64 KiB)
    my $heard = sub {                     # the stop of the first request: yours, an answer that does not begin "HTTP/1.1 200 ", a head longer than 64 KiB, or a playlist by its type that grows past $HLS_PLAYLIST on the wire (the address's name already capped it when it ends .m3u8)
        return 1 if $stop->();
        my ($so_far) = @_;
        return 0 if $listed || !$so_far || defined $typed && !$typed || length $$so_far < 13;
        if (substr($$so_far, 0, 13) ne 'HTTP/1.1 200 ') { $over = 'status'; return 1 }    # sub body_of plays no other answer, so none other is read on: a 1xx head in front, in whatever spelling curl passes over, ends the request here with the rest
        my $end = index($$so_far, "\r\n\r\n");
        if (($end < 0 ? length $$so_far : $end + 4) > 65536) { $over = 'head'; return 1 }    # the head ends within 64 KiB of the answer's first byte, or it is refused: no head is long enough to pass the cap below unread
        return 0 if $end < 0;
        $typed //= substr($$so_far, 0, $end) =~ m{^content-type:[ \t]*(?:application/vnd\.apple\.mpegurl|application/x-mpegurl|audio/mpegurl|audio/x-mpegurl)[ \t]*(?:;|\r?$)}mi ? 1 : 0;
        return $over = $typed && length($$so_far) - $end - 4 > $HLS_PLAYLIST ? 1 : 0;
    };
    my ($got, $why, $from) = fetch($url, $to, undef, undef, [$listed ? $HLS_PLAYLIST : $VIDEO_BYTES, $VIDEO_SECONDS], $heard);    # [C6] [C7] the fixed request, no Range; an address that ends in .m3u8 is asked for no more than a playlist, and so is an answer whose type says it is one
    ($why, $listed) = $over eq 'status' ? ('the site did not answer it with the file (200)', 0) : $over eq 'head' ? ("the site's answer has a head longer than the 64 KiB lzrprf reads", 0) : ('the answer is larger than lzrprf takes', 1) if $over;
    if (defined $why && $why eq 'you stopped it') { record("$url failed: you stopped it", $kept) or return $none->($UNWRITTEN); window("video $TAB $k stopped"); return $back->() }    # its mark is back, and a click fetches it again
    my $body = $why ? undef : body_of($got);
    my $large = defined $why && $why eq 'the answer is larger than lzrprf takes';
    my ($kind, $how) = ('', '');          # " ts" for an MPEG-TS stream, which the window plays as one; and the words of the note on what of a stream was played
    if (defined $body && $body =~ /\A(?:\xEF\xBB\xBF)?#EXTM3U\r?\n/ || $large && $listed) {    # an HLS playlist, by what the site answered, not by its name (sub hls_fetched)
        my ($stream, $words, $locked);
        if ($large) { $words = 'this playlist is larger than the ' . ($HLS_PLAYLIST >> 10) . ' KiB lzrprf reads' }
        else {
            record("$url answered: a playlist of " . length($body) . " bytes from $from", $kept) or return $none->($UNWRITTEN);
            ($stream, $words, $locked, $kind, $how) = hls_fetched($url, $to, $connects, $body, $kept, $until, $stop);
        }
        return $none->($UNWRITTEN) if defined $words && $words eq $UNWRITTEN;
        if (defined $words && $words eq $REFUSED_WHY) {    # [C23] an address the playlist names is on the list: the box says so as for a listed video, naming no address
            close $request;
            window("video $TAB $k none " . (refused('an address a playlist of a video names', $kept) // return $none->($UNWRITTEN)));
            return $back->();
        }
        if (defined $words && $words eq 'you stopped it') { record("$url failed: you stopped it", $kept) or return $none->($UNWRITTEN); window("video $TAB $k stopped"); return $back->() }
        if (defined $words) {
            record("$url not played: $words", $kept) or return $none->($UNWRITTEN);
            close $request;
            window("video $TAB $k none " . ucfirst "$words.");
            return $back->($locked ? "A video of this page is locked ($locked): lzrprf plays no video locked by DRM or a key." : undef);    # [C22] said in the bottom bar too, where it stays for the page
        }
        if ($kind eq ' ts' && ts_sounds($stream)) {    # [C24] a stream with sound, which the window's player reads only as an MP4
            busy("Making an MP4 of the video's stream: $url");
            my ($mp4, $failed) = system_converted($stream);
            if (!defined $mp4) {
                record("$url not played: a stream of " . length($stream) . " bytes$how, which $failed", $kept) or return $none->($UNWRITTEN);
                close $request;
                window("video $TAB $k none This stream has sound, and the system could not make an MP4 of it for the window.");
                return $back->();
            }
            ($how, $kind) = ("$how, made into an MP4 by the system's avconvert from those " . length($stream) . " bytes, its pictures and sound copied as they came", '');
            $stream = $mp4;
        }
        record("$url played: a stream of " . length($stream) . " bytes$how; the window plays it", $kept) or return $none->($UNWRITTEN);
        $body = $stream;
    } else {
        $why //= !defined $body ? 'the site did not answer it with the file (200)' : substr($body, 4, 4) ne 'ftyp' ? 'it is not an MP4 file or an HLS playlist' : undef;
        record("$url " . (defined $why ? 'failed: ' . ($large ? "the video is larger than the $VIDEO_BYTES bytes lzrprf takes" : $why) : 'answered: ' . length($got) . " bytes from $from; the window plays it"), $kept) or return $none->($UNWRITTEN);
        return $none->($large ? 'This video is larger than the ' . ($VIDEO_BYTES >> 20) . ' MiB lzrprf hands to the window.' : 'No video: ' . $why . '.') if defined $why;
    }
    close $request;
    window("video $TAB $k begin " . length($body) . $kind);
    for (my $at = 0; $at < length $body; $at += $VIDEO_FRAME) { window("video $TAB $k part " . encode_base64(substr($body, $at, $VIDEO_FRAME), '')) }
    window("video $TAB $k end");
    video_sound_kept($k, \$body, $url);    # [C22] for its sound, which plays in the sound process once you turn it on
    noted("The video $url came: " . length($body) . " bytes$how, played in the window by the system.");
    return $back->();
}

# An HLS stream of a video you clicked [C22], from its playlist: lzrprf
# follows it itself, as Safari's native HLS does, and hands the window one
# file. Every address a playlist names (each quality's playlist, the stream's
# start, EXT-X-MAP, and each segment) is made whole against the address of
# the playlist that names it (sub hls_address) and taken only when it is
# https, on port 443, on the very host of the first playlist: nothing of a
# stream changes the site or the scheme, and every address of a playlist is
# checked before the first of them is fetched. A master playlist offers at
# most $HLS_VARIANTS qualities; one is chosen up front, the middle of those at
# or under $HLS_BITRATE bits a second (the lower of two in the middle), or the
# lowest when none is, and only it is fetched. A playlist is at most
# $HLS_PLAYLIST bytes and lists at most $HLS_SEGMENTS segments. A locked
# stream is refused before anything more of it is fetched: an EXT-X-KEY or
# EXT-X-SESSION-KEY whose METHOD is not NONE (AES-128, SAMPLE-AES, FairPlay's
# com.apple.streamingkeydelivery). A stream in parts of a file
# (EXT-X-BYTERANGE), which a request with no Range cannot take, is refused
# too. The segments are fetched in order, each written in the log first, by
# the fixed request of a picture, at the addresses the host was looked up at
# for this click (through Tor when it is on), within the one clock and cap
# of the video ($VIDEO_SECONDS, $VIDEO_BYTES, the playlists counted in); when
# the cap or the clock is reached, or a later segment fails, what came is
# played and the note says how much. MPEG-TS segments are joined into one
# MPEG-TS file; fragmented MP4 segments follow their start into one
# fragmented MP4 file. The system's player plays either as one file through
# the window's loader: it does not take an HLS stream's segments from a
# loader at all ("custom url not redirect", CoreMediaErrorDomain -12881,
# measured 2026-11-21 on macOS 27.2), and the window has no network of its
# own to give it. A live stream (no EXT-X-ENDLIST) plays the segments it
# listed at the click, once. Nothing of it is written to a file. Returns the
# stream, no words, '', the kind (" ts" or '') and the words of what was
# played; or nothing and why it is not played, with the key's METHOD for a
# locked stream.
sub hls_fetched {
    my ($url, $to, $connects, $text, $kept, $until, $stop) = @_;
    my ($on) = $url =~ m{^https://([^/?]+)};
    my $left = $VIDEO_BYTES - length $text;
    my $failed = sub { $_[0] eq 'the answer is larger than lzrprf takes' ? 'this stream is larger than the ' . ($VIDEO_BYTES >> 20) . ' MiB lzrprf takes' : now() >= $until - 0.5 ? "this stream took more than the $VIDEO_SECONDS seconds lzrprf gives a video" : "a part of this stream failed: $_[0]" };
    my $get = sub {                       # one more address of the stream, on the host looked up for the click: written in the log first; its body, or nothing and why
        my ($address, $what, $most) = @_;
        my $seconds = $until - now();
        return (undef, "this stream took more than the $VIDEO_SECONDS seconds lzrprf gives a video") if $seconds < 0.5;
        return (undef, 'the answer is larger than lzrprf takes') if $left <= 0;
        record("$address -> lzrprf connects $connects, for $what of the stream $url", $kept) or return (undef, $UNWRITTEN);    # [C5] written down first, connected second
        my ($got, $why) = fetch($address, $to, undef, undef, [$most && $most < $left ? $most : $left, sprintf('%.1f', $seconds)], $stop);    # [C6] [C7]
        my $body = defined $why ? undef : body_of($got);
        $why //= 'the site did not answer it with the file (200)' unless defined $body;
        record("$address " . (defined $why ? "failed: $why" : 'answered: ' . length($body) . ' bytes'), $kept) or return (undef, $UNWRITTEN);
        return (undef, $why) if defined $why;
        $left -= length $body;
        return $body;
    };
    my @lines = hls_lines($text) or return (undef, 'this playlist is not one lzrprf reads');
    my $locked = hls_locked(@lines);
    return (undef, "this video is locked ($locked), and lzrprf plays no locked video", $locked) if $locked;
    my ($playlist, $how, $apart) = ($url, '', 0);
    if (grep { /^#EXT-X-STREAM-INF:/ } @lines) {    # a master playlist: its qualities
        my (@offered, @named, %sound);
        for my $i (0 .. $#lines) {
            if ($lines[$i] =~ /^#EXT-X-MEDIA:(.*)/) {    # a rendition apart: its address is checked as any, and it is never fetched
                my %is = hls_attributes($1);
                push @named, $is{URI} if defined $is{URI};
                push @{ $sound{ $is{'GROUP-ID'} // '' } }, defined $is{URI} if ($is{TYPE} // '') eq 'AUDIO';
            }
            next unless $lines[$i] =~ /^#EXT-X-STREAM-INF:(.*)/;
            my %is = hls_attributes($1);
            my $uri = $lines[$i + 1];
            return (undef, 'this playlist names a quality with no address') unless defined $uri && $uri !~ /^#/;
            return (undef, 'this playlist names a quality without its BANDWIDTH') unless ($is{BANDWIDTH} // '') =~ /^[0-9]{1,10}\z/;
            push @offered, { bits => $is{BANDWIDTH}, uri => $uri, sound => $is{AUDIO} };
        }
        return (undef, "this playlist offers more than the $HLS_VARIANTS qualities lzrprf reads") if @offered > $HLS_VARIANTS;
        for my $uri (map({ $_->{uri} } @offered), @named) { my $at = hls_address($uri, $url, $on); return (undef, $REFUSED_WHY) if hls_listed($uri, $url, $on); defined $at or return (undef, hls_away($uri, $on)) }    # [C22] every address, before any is fetched; [C23] a listed one is refused before anything names its host
        my @by = sort { $a->{bits} <=> $b->{bits} } @offered;
        my @under = grep { $_->{bits} <= $HLS_BITRATE } @by;
        my $chosen = @under ? $under[$#under >> 1] : $by[0];
        my $rate = sprintf('%.2f Mbit/s', $chosen->{bits} / 1e6);
        $playlist = hls_address($chosen->{uri}, $url, $on);
        $how = ", the quality of $rate (" . (1 + grep { $_->{bits} < $chosen->{bits} } @by) . ' of ' . @by . ')';
        my $group = $sound{ $chosen->{sound} // "\n" };
        $apart = $group && !grep { !$_ } @$group;    # its sound only in streams apart, which lzrprf does not join
        my ($media, $why) = $get->($playlist, "the playlist of the quality of $rate", $HLS_PLAYLIST);
        return (undef, $why eq 'the answer is larger than lzrprf takes' ? 'this playlist is larger than the ' . ($HLS_PLAYLIST >> 10) . ' KiB lzrprf reads' : $why =~ /^(?:\Q$UNWRITTEN\E|you stopped it)\z/ ? $why : $failed->($why)) unless defined $media;
        @lines = hls_lines($media) or return (undef, 'the playlist of its quality is not one lzrprf reads');
        return (undef, 'the playlist of its quality offers qualities again') if grep { /^#EXT-X-STREAM-INF:/ } @lines;
        $locked = hls_locked(@lines);
        return (undef, "this video is locked ($locked), and lzrprf plays no locked video", $locked) if $locked;
    }
    return (undef, 'this stream is in parts of a file (EXT-X-BYTERANGE), which lzrprf does not fetch') if grep { /^#EXT-X-BYTERANGE:/ || /^#EXT-X-MAP:.*BYTERANGE=/ } @lines;
    my ($start, @segments);
    for (@lines) {
        if (/^#EXT-X-MAP:(.*)/) {
            my %is = hls_attributes($1);
            return (undef, 'this stream names a start (EXT-X-MAP) with no address') unless defined $is{URI};
            return (undef, 'this stream has more than one start (EXT-X-MAP), which lzrprf does not join') if defined $start && $start ne $is{URI};
            $start = $is{URI};
        }
        elsif (!/^#/) { push @segments, $_ }
    }
    return (undef, "this stream lists more than the $HLS_SEGMENTS segments lzrprf reads") if @segments > $HLS_SEGMENTS;
    return (undef, 'this stream lists no segment') unless @segments;
    my @at;
    for my $uri (defined $start ? $start : (), @segments) { my $at = hls_address($uri, $playlist, $on); return (undef, $REFUSED_WHY) if hls_listed($uri, $playlist, $on); push @at, $at // return (undef, hls_away($uri, $on)) }    # [C22] every address, before any is fetched; [C23] a listed one is refused before anything names its host
    shield_asked(@at);                    # [C28] every part of the stream judged before the first is fetched
    my $stream = '';
    if (defined $start) {
        my ($first, $why) = $get->(shift @at, 'the start of its segments');
        return (undef, $why =~ /^(?:\Q$UNWRITTEN\E|you stopped it)\z/ ? $why : $failed->($why)) unless defined $first;
        return (undef, 'the start of this stream is not an MP4 file') unless substr($first, 4, 4) eq 'ftyp';
        $stream = $first;
    }
    my ($came, $short) = (0, '');
    for my $n (0 .. $#at) {
        my ($piece, $why) = $get->($at[$n], 'segment ' . ($n + 1) . ' of ' . @at);
        if (!defined $piece) {
            return (undef, $why) if $why eq $UNWRITTEN || $why eq 'you stopped it';
            return (undef, $failed->($why)) unless $came;
            $short = '; ' . $failed->($why) =~ s/^this stream/the rest/r =~ s/^a part of this stream failed/the rest was not fetched/r;
            last;
        }
        return (undef, 'segment ' . ($n + 1) . ' of this stream is neither MPEG-TS nor a part of an MP4 file') unless defined $start ? substr($piece, 4, 4) =~ /^(?:styp|moof|sidx|emsg|prft)\z/ : length($piece) >= 188 && substr($piece, 0, 1) eq "\x47" && (length($piece) < 376 || substr($piece, 188, 1) eq "\x47");
        $stream .= $piece;
        $came++;
    }
    my $live = !grep { $_ eq '#EXT-X-ENDLIST' } @lines;
    $how .= ", $came of its " . @at . ' segments' . ($live ? ' listed when you clicked, of a live stream,' : '') . (defined $start ? ' after its start, as one MP4 file' : ', as one MPEG-TS file') . $short . ($apart ? '; its sound is a stream apart, which lzrprf does not join, so it plays without sound' : '');
    return ($stream, undef, '', defined $start ? '' : ' ts', $how);
}

# The lines of an HLS playlist (RFC 8216 §4.1), or none when it is not one
# lzrprf reads: at most $HLS_PLAYLIST bytes of text, with no byte below a
# space but tab and the ends of lines, no line longer than $HLS_LINE, its
# first line #EXTM3U. Blank lines are taken out, and the spaces at the two
# ends of a line. Every pattern here and in sub hls_attributes reads a line
# once from its start: none goes back over what it read, so a playlist the
# site made to be slow to read is read as fast as any (a line of 262,000
# spaces took a pattern that went back about 15 minutes).
sub hls_lines {
    my ($text) = @_;
    $text =~ s/\A\xEF\xBB\xBF//;
    return if length($text) > $HLS_PLAYLIST || $text =~ /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/;
    my @lines;
    for my $line (split /\n/, $text) {
        return if length $line > $HLS_LINE;    # refused before anything else reads it
        my ($from, $to) = (0, length $line);
        $from++ while $from < $to && substr($line, $from, 1) =~ tr/ \t//;
        $to-- while $to > $from && substr($line, $to - 1, 1) =~ tr/ \t\r//;
        push @lines, substr($line, $from, $to - $from) if $to > $from;
    }
    return unless @lines && $lines[0] eq '#EXTM3U';
    return @lines;
}

# The attributes of one tag of a playlist: NAME=value, or NAME="text" (RFC
# 8216 §4.2), the first of a name when it stands twice.
sub hls_attributes {
    my ($list) = @_;
    my %is;
    while ($list =~ /\G[ \t]*+([A-Z0-9-]++)=("[^"\r\n]*+"|[^",]*+)[ \t]*+(?:,|\z)/gc) {    # possessive: nothing read is read again
        my ($name, $value) = ($1, $2);
        if (substr($value, 0, 1) eq '"') { $value = substr($value, 1, -1) }
        else { my $to = length $value; $to-- while $to && substr($value, $to - 1, 1) =~ tr/ \t//; $value = substr($value, 0, $to) }    # the spaces after an unquoted value
        $is{$name} //= $value;
    }
    return %is;
}

# The METHOD of a key that locks a stream, when one does: an EXT-X-KEY or
# EXT-X-SESSION-KEY whose METHOD is not NONE, with FairPlay named when its
# KEYFORMAT is com.apple.streamingkeydelivery; '' when none does. [C22]
sub hls_locked {
    for (@_) {
        next unless /^#EXT-X-(?:SESSION-)?KEY:(.*)/;
        my %is = hls_attributes($1);
        my $method = $is{METHOD} // '';
        next if $method eq 'NONE';
        $method =~ s/[^A-Za-z0-9-]//g;
        return 'EXT-X-KEY METHOD=' . (length $method ? substr($method, 0, 20) : '?') . (($is{KEYFORMAT} // '') eq 'com.apple.streamingkeydelivery' ? ', FairPlay' : '');
    }
    return '';
}

# An address a playlist names, made whole against the address of that
# playlist (RFC 3986 §5.2: a whole https address, //host/path, /path, ?query
# or a path beside the playlist's, with . and .. taken out), and taken only
# as a typed address is (sub address) and only on the host $on: so by
# https, on port 443, never on another site. Nothing when it is not. [C22]
sub hls_address {
    my ($ref, $base, $on) = @_;
    return if $ref =~ /[^\x21-\x7e]/ || length $ref > 2000;
    my $whole = hls_whole($ref, $base, $on) // return;
    my ($head, $path, $query) = $whole =~ m{^(https://[^/?]+)(/[^?]*)?(\?.*)?\z}s or return;    # another scheme is no address here
    my @kept;
    my @parts = split m{/}, $path // '/', -1;
    for my $i (1 .. $#parts) {
        if ($parts[$i] eq '..') { pop @kept if @kept }
        elsif ($parts[$i] ne '.') { push @kept, $parts[$i] }
        push @kept, '' if $i == $#parts && ($parts[$i] eq '.' || $parts[$i] eq '..');
    }
    my ($url, $there) = address($head . '/' . join('/', @kept) . ($query // '')) or return;
    return $there eq $on ? $url : undef;
}

# The whole address a playlist's reference stands for: as written when it
# names its own scheme (https:// with //), else where it leads on the
# playlist's host. Shared by sub hls_address and sub hls_listed.
sub hls_whole {
    my ($ref, $base, $on) = @_;
    $ref =~ s/#.*//s;
    my ($beside) = $base =~ m{^https://[^/?]+(/[^?]*)} or return;
    return $ref =~ m{^[A-Za-z][A-Za-z0-9+.-]*:} ? $ref : $ref =~ m{^//} ? "https:$ref" : $ref =~ m{^/} ? "https://$on$ref" : $ref =~ m{^\?} ? "https://$on$beside$ref" : "https://$on" . ($beside =~ s{[^/]*\z}{}r) . $ref;
}

# [C23] Whether an address a playlist names is on the list, read from the
# reference itself and not from what hls_address made of it: sub address gives
# nothing for a listed address, so a listed path on the playlist's own host
# would otherwise read as one lzrprf does not follow. Asked before sub
# hls_away, whose words name the host, so a listed host or path is never named
# in the window or the log: the box gets the sentence of [C23].
sub hls_listed {
    my ($ref, $base, $on) = @_;
    my $whole = hls_whole($ref, $base, $on) // $ref;    # whatever its bytes or its length: sub listed reads it loosely, and one too long to read is listed
    return listed($whole);
}

# Why an address a playlist names is not taken, in a few words that name
# its scheme and its host and nothing more: never its path, its query or a
# name and password before its host, which may hold a key of the site's,
# and which a log of hosts alone must not hold [C12]. An address on the
# playlist's own host written with HTTPS in capitals is not taken either:
# sub address takes https in small letters alone, so it fails closed, and is
# said as an address lzrprf does not follow. [C22]
sub hls_away {
    my ($ref, $on) = @_;
    my ($scheme) = $ref =~ m{^([A-Za-z][A-Za-z0-9+.-]{0,15}):};
    my ($there) = $ref =~ m{^(?:[A-Za-z][A-Za-z0-9+.-]*:)?//(?:[^/?#@]*+@)?([^/?#:@]{1,253})};
    return $REFUSED_WHY if listed($ref) || defined $there && listed("https://$there/");    # [C23] a listed host is never named here, however hls_listed was reached
    $there = lc($there =~ s/[^\x21-\x7e]/?/gr) if defined $there;
    my $where = (defined $scheme ? lc($scheme) . ':' : '') . (defined $there ? "//$there" : '');
    return "this playlist names an address that is not https ($where), and lzrprf follows a stream only by https" if defined $scheme && lc($scheme) ne 'https';
    return "this playlist names an address on another site ($there), and lzrprf follows a stream only on the site of its playlist, $on" if defined $there && $there ne $on;
    return 'this playlist names an address lzrprf does not follow' . (length $where ? " ($where)" : '');
}

# Whether you stopped the video being fetched: "video stop", said from its
# box while it loads, as "tor off" is heard while Tor connects (sub tor_on).
# The window is listened to at most four times a second, and only for what
# it said since: what it said before, and anything but the stop, is kept in
# its order for the loop of sub behind. A window that is gone stops it too.
sub video_stop {
    my $next = 0;
    return sub {
        return 0 if now() < $next || !$FROM && !@EVENTS;    # "lzrprf try": the test's next line, when there is one
        $next = now() + 0.25;
        my ($before, $stop, @heard) = ([splice @HELD], 0);
        my $wait = 0.01;
        while ($FROM || @EVENTS) {        # every line that is ready, read before the stop is looked for, so a stop behind another line is never left for the next poll
            my $event = hear($wait);
            if (!defined $event) { $stop = 1; last }    # the window is gone
            last unless length $event;
            if ($event eq 'video stop' && !$stop) { $stop = 1 } else { push @heard, $event }    # what came after the stop is for after this fetch, a second stop too
            $wait = 0.001;
            last if now() > $next;        # a quarter of a second at most: the rest is read at the next poll
        }
        @HELD = (@$before, @heard);
        return $stop;
    };
}

# Whether the page's own text names an address of another site as it is:
# "//", the host in any case, then the path and query exactly, and nothing
# that could still be part of an address right after it (any character an
# address may hold, RFC 3986), so a page that names /a.png?x=1 does not name
# /a.png?x= or /a.png, nor /a.png when it names /a.png;x or /a.png(1). Two
# ends are read as the page wrote them: an address that opens after ' ends
# at the next ', as in src='...', and one that opens after ( ends at ), as
# in url(...). $text is the body of the page's answer, without the site's
# headers, &amp; read as &. [C4]
sub named_in {
    my ($text, $there, $url) = @_;
    my $rest = substr($url, 8 + length $there);
    my $more = qr{[A-Za-z0-9._~/%?=&,;+!*'()\@\$:\[\]-]};
    return $text =~ m{(?:(')|(\()|)(?i:https:)?(?i://\Q$there\E)\Q$rest\E(?(1)(?='|(?!$more))|(?(2)(?=\)|(?!$more))|(?!$more)))};
}

# Whether a picture's host is another site than the page's: neither the page's
# host, nor that host without "www." (example.com for a page of
# www.example.com), nor a name under it (sub under). [C4]
sub elsewhere {
    my ($there, $host) = @_;
    return $there ne $host && $there ne ($host =~ s/^www\.//r) && !under($there, $host);
}

# Whether a host is a name under a page's host: the page's host with "www."
# taken off, a dot before it, and one name or more in front. Only who holds a
# name can give out the names under it, so a picture there comes from the site
# you visit, and such a host is not counted among the $PICTURE_SITES other
# sites a page's pictures may come from. [C4]
sub under {
    my ($there, $host) = @_;
    my $own = $host =~ s/^www\.//r;
    return $own =~ /\./ && length $there > length($own) + 1 && substr($there, -length($own) - 1) eq ".$own";
}

