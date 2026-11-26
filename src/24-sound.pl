# The sound process [C12]. The sound of a page kept running plays here, in
# the sound container ($SOUND_CONTAINER), never in the window, whose container
# lets no sound play. It is started on the first sound of a window, after the
# system said it is contained [C3], and ended once it says nothing has played
# for $SOUND_IDLE seconds, or with the window. lzrprf writes it the lines the
# window was written before, each checked here first (sub live_sounded):
# "sound begin T ID RATE FRAMES FROM TO", "sound part T ID BASE64", "sound
# play T ID AT", "sound stop T ID", and "sound clear", which stops and lets
# go of every sound (another tab, a new page, no page kept running). It says
# "played ID yes|no WHAT" for each play, in order: no when the system's player
# did not get ready or did not start, with what each player said, so a sound
# that is not heard is said in the log and never passed over; "idle" when
# nothing has played for the seconds it was given. In "lzrprf try" it plays
# at no volume. A sound is held in memory alone, as a WAV of its samples
# handed to the system's AVAudioPlayer as data: nothing is written. One that
# loops is played once from AT up to FROM and then from FROM to TO over and
# over. A video's sound [C22] plays here too, once you turned it on in the
# window: lzrprf hands over the MP4 it handed the window, "video begin T K
# LENGTH", parts and "video end T K", and the system's AVAudioPlayer plays its
# sound track from that data; the window's own player stays muted. "video at
# T K STATE MEDIA RATE WALL" says where the window's picture is: playing,
# paused, ended, off (its sound turned off) or gone, at MEDIA seconds into
# the video, going at RATE, read at WALL (milliseconds of the clock both
# processes share). It answers "video T K yes|no WHAT" when the sound first
# plays, then "video T K drift MS" at each clock: how far its sound was from
# the picture, before it set it right again.
my $SOUND_TEXT = <<'END';
ObjC.import('Foundation');
var from = $.NSFileHandle.fileHandleWithStandardInput, to = $.NSFileHandle.fileHandleWithStandardOutput, held = '', ended = false, quiet = false, idle = 30, busy = 0, idleSaid = false, hand = null;    // hand: the one that hears lzrprf, kept here, as the system keeps no hold of it
var sounds = {}, soundsHeld = 0, SOUNDS_HELD = 33554432, SOUND_FRAMES = 2880000, soundKit = null;    // 32 MiB: two pages' worth of lzrprf's $SOUND_BYTES; a minute at 48000 frames a second
var soundVideos = {}, SOUND_VIDEO_MOST = 67108864, SOUND_VIDEOS_HELD = 2, SOUND_VIDEO_LEAD = 0.05, SOUND_VIDEO_SLACK = 0.02;    // lzrprf's $VIDEO_BYTES, two held as in the window; a sound started 50 ms ahead, on the device's own clock; set right when 20 ms off
function soundVideoTold(rest) {    // "begin T K LENGTH | part T K BASE64 | end T K | at T K STATE MEDIA RATE WALL", checked again; a video whose parts do not add up is let go
    var m = /^(begin|part|end|at) (\d{1,2}) (\d{1,2})(?: (.*))?$/.exec(rest);
    if (!m) return;
    var key = m[2] + ' ' + m[3], what = m[1], more = m[4] || '', one = soundVideos[key];
    if (what == 'begin') {
        if (!/^[1-9]\d{0,8}$/.test(more) || +more > SOUND_VIDEO_MOST) return;
        if (one) soundVideoGone(key);
        var held = Object.keys(soundVideos).sort(function (a, b) { return soundVideos[a].at - soundVideos[b].at; });
        while (held.length >= SOUND_VIDEOS_HELD) soundVideoGone(held.shift());
        soundVideos[key] = { bytes: +more, data: $.NSMutableData.dataWithCapacity(+more), at: Date.now(), player: null, said: false };
    } else if (!one) { if (what == 'at' && /^playing /.test(more)) soundSay('video ' + key + ' no it holds no such video whole'); }
    else if (what == 'part') {
        var part = /^[A-Za-z0-9+\/]+={0,2}$/.test(more) && more.length % 4 == 0 ? $.NSData.alloc.initWithBase64EncodedStringOptions($(more), 0) : null;
        if (!part || part.isNil() || !one.data || Number(one.data.length) + Number(part.length) > one.bytes) return soundVideoGone(key);
        one.data.appendData(part);
    } else if (what == 'end') {
        if (!one.data || Number(one.data.length) != one.bytes) return soundVideoGone(key);
        if (!soundKit) { $.NSBundle.bundleWithPath('/System/Library/Frameworks/AVFoundation.framework').load; soundKit = $.NSClassFromString('AVAudioPlayer'); }
        var player = soundKit.alloc.initWithDataFileTypeHintError(one.data, $('public.mpeg-4'), null);    // its sound track, read by the system from the MP4 in memory
        one.data = null;
        if (player && !player.isNil()) { player.enableRate = true; if (quiet) player.volume = 0; one.ready = !!player.prepareToPlay; one.player = player; }
    } else soundVideoAt(key, one, more);
}
function soundVideoAt(key, one, more) {    // the picture's clock: the sound follows it, started ahead on the device's clock, and set right again once it is SOUND_VIDEO_SLACK off
    var m = /^(playing|paused|ended|off|gone) (\d{1,6}\.\d{3}) (\d{1,2}(?:\.\d{1,3})?) (\d{13})$/.exec(more), p = one.player;
    if (!m) return;
    if (m[1] == 'gone') return soundVideoGone(key);
    if (!p) { if (m[1] == 'playing' && !one.said) { one.said = true; soundSay('video ' + key + ' no it holds no sound the system can play'); } return; }
    var rate = Math.min(2, Math.max(0.5, +m[3] || 1)), media = +m[2], now = function () { return media + (Date.now() - +m[4]) / 1000 * rate; };
    if (m[1] != 'playing') { p.pause; if (m[1] != 'off') p.currentTime = media; return; }    // paused or ended where the picture is; off where it was
    if (p.playing && Math.abs(p.rate - rate) < 0.001) {
        var drift = p.currentTime - now();
        soundSay('video ' + key + ' drift ' + Math.round(drift * 1000));
        if (Math.abs(drift) < SOUND_VIDEO_SLACK) return;
    }
    p.stop; p.prepareToPlay; p.rate = rate;    // stopped and prepared again: a paused player starts at once and keeps the lead as drift (93 ms measured), a prepared one starts on the device clock (0 to 3 ms)
    var lead = SOUND_VIDEO_LEAD, set = Date.now(), late = 0;
    for (var tries = 0; tries < 2; tries++) {    // the seek itself takes time (41 to 44 ms on a busy Mac, 2026-11-26): it is taken from the lead, and a seek longer than the lead is made again with a lead twice as long as it took
        set = Date.now(); p.currentTime = now() + lead * rate; late = (Date.now() - set) / 1000;
        if (late < lead * 0.8 || tries == 1) break;    // the lead played below is the one this seek was made with (lzr3's review)
        lead = Math.min(0.5, Math.max(lead, late * 2));
    }
    var started = !!p.playAtTime(p.deviceCurrentTime + Math.max(0.002, lead - (Date.now() - set) / 1000));
    busy = Date.now();
    if (!one.said) { one.said = true; soundSay('video ' + key + (one.ready && started ? ' yes' : ' no') + ' ready=' + !!one.ready + ' started=' + started + ' length=' + Math.round(p.duration * 1000)); }
}
function soundVideoGone(key) { var one = soundVideos[key]; if (one && one.player) one.player.stop; delete soundVideos[key]; }
function soundSay(line) { to.writeData($(line + '\n').dataUsingEncoding(4)); }
function soundsClear() { Object.keys(sounds).forEach(function (k) { soundStopped(sounds[k]); }); sounds = {}; soundsHeld = 0; }
function soundStopped(one) { one.players.forEach(function (p) { p.stop; }); one.players = []; }
function soundTold(rest) {    // a line checked again: one of no form, a sound made twice, too long or past SOUNDS_HELD in all is passed over, a sound whose parts do not add up to it is let go, and every play is answered
    var m = /^(begin|part|play|stop) (\d{1,2}) ([1-9]\d{0,9})(?: (.*))?$/.exec(rest);
    if (!m) return;
    var what = m[1], id = m[3], more = m[4] || '', one = sounds[id];
    if (what == 'play' && !(one && /^\d{1,7}$/.test(more) && +more < one.bytes / 2 && Number(one.data.length) == one.bytes)) return soundSay('played ' + id + ' no it holds no such sound whole');
    if (what == 'begin') {
        var n = /^([1-9]\d{3,4}) ([1-9]\d{0,6}) (\d{1,7}) (\d{1,7})$/.exec(more);
        if (one || !n || +n[1] < 8000 || +n[1] > 96000 || +n[2] > SOUND_FRAMES || !((+n[3] == 0 && +n[4] == 0) || (+n[3] < +n[4] && +n[4] <= +n[2])) || soundsHeld + 2 * n[2] > SOUNDS_HELD) return;
        soundsHeld += 2 * n[2];
        sounds[id] = { rate: +n[1], bytes: 2 * n[2], from: +n[3], to: +n[4], data: $.NSMutableData.dataWithCapacity(2 * n[2]), players: [] };
    } else if (!one) return;
    else if (what == 'part') {
        var part = /^[A-Za-z0-9+\/]+={0,2}$/.test(more) && more.length % 4 == 0 ? $.NSData.alloc.initWithBase64EncodedStringOptions($(more), 0) : null;
        if (!part || part.isNil() || Number(one.data.length) + Number(part.length) > one.bytes) { soundStopped(one); soundsHeld -= one.bytes; delete sounds[id]; return; }    // a length comes over the bridge as a string
        one.data.appendData(part);
    }
    else if (what == 'stop') soundStopped(one);
    else soundPlayed(id, one, +more);
}
function soundPlayer(one, from, to) {    // a player of frames FROM to TO of a sound, from a WAV of them made in memory
    if (!soundKit) { $.NSBundle.bundleWithPath('/System/Library/Frameworks/AVFoundation.framework').load; soundKit = $.NSClassFromString('AVAudioPlayer'); }
    var bytes = 2 * (to - from), h = [];
    var word = function (v, size) { for (var i = 0; i < size; i++) h.push(Math.floor(v / Math.pow(256, i)) % 256); };
    var name = function (t) { for (var i = 0; i < 4; i++) h.push(t.charCodeAt(i)); };
    name('RIFF'); word(36 + bytes, 4); name('WAVE'); name('fmt '); word(16, 4); word(1, 2); word(1, 2); word(one.rate, 4); word(2 * one.rate, 4); word(2, 2); word(16, 2); name('data'); word(bytes, 4);
    var abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', head = '';
    for (var i = 0; i < h.length; i += 3) { var v = h[i] * 65536 + (h[i + 1] || 0) * 256 + (h[i + 2] || 0); head += abc[v >> 18 & 63] + abc[v >> 12 & 63] + (i + 1 < h.length ? abc[v >> 6 & 63] : '=') + (i + 2 < h.length ? abc[v & 63] : '='); }
    var wav = $.NSMutableData.dataWithData($.NSData.alloc.initWithBase64EncodedStringOptions($(head), 0));
    wav.appendData(one.data.subdataWithRange($.NSMakeRange(2 * from, bytes)));
    var player = soundKit.alloc.initWithDataError(wav, null); if (!player || player.isNil()) return null;
    if (quiet) player.volume = 0;
    one.players.push(player); return player;
}
function sounded(one, player, after, said) {    // a player starts, now or AFTER seconds from now: what it said, in frames (its length, loops, from where, after), and whether it got ready and started
    var from = player.currentTime, ready = !!player.prepareToPlay;    // prepared, then set where it starts again: a busy sound server let prepareToPlay put it back to 0 (89 frames read for 200)
    player.currentTime = from;
    var started = !!(after > 0 ? player.playAtTime(player.deviceCurrentTime + after) : player.play), f = function (seconds) { return Math.round(seconds * one.rate); };
    said.push(f(player.duration) + ':' + player.numberOfLoops + ':' + f(player.currentTime) + ':' + f(after) + ' ready=' + ready + ' started=' + started);
    return ready && started;
}
function soundPlayed(id, one, at) {    // a sound from frame AT: once to its end, or once up to its loop and then the loop for ever; answered "played ID yes|no WHAT"
    soundStopped(one);
    var frames = one.bytes / 2, from = one.from, to = one.to, said = [], well = true, made = function (a, b) { var p = soundPlayer(one, a, b); if (!p) { said.push('no player'); well = false; } return p; };
    if (!to) { var once = made(0, frames); if (once) { once.currentTime = at / one.rate; well = sounded(one, once, 0, said) && well; } }
    else {
        if (at >= to) at = from;
        var loop = made(from, to);
        if (loop) loop.numberOfLoops = -1;
        if (loop && at >= from) { loop.currentTime = (at - from) / one.rate; well = sounded(one, loop, 0, said) && well; }
        else if (loop) { var lead = made(0, from); if (lead) { lead.currentTime = at / one.rate; well = sounded(one, lead, 0, said) && well; well = sounded(one, loop, (from - at) / one.rate, said) && well; } }
    }
    if (well) busy = Date.now();
    soundSay('played ' + id + (well ? ' yes ' : ' no ') + said.join('/'));
}
function playing() { return Object.keys(sounds).some(function (k) { return sounds[k].players.some(function (p) { return p.playing; }); }) || Object.keys(soundVideos).some(function (k) { return soundVideos[k].player && soundVideos[k].player.playing; }); }
function soundHeard() {    // what lzrprf wrote: printable ASCII lines; a play whose handling failed is still answered
    var data = from.availableData;
    if (data.length == 0) { ended = true; return; }    // lzrprf closed its end: the process ends
    held += $.NSString.alloc.initWithDataEncoding(data, 5).js;
    for (var at; (at = held.indexOf('\n')) >= 0; held = held.slice(at + 1)) {
        var line = held.slice(0, at), play = /^sound play \d{1,2} ([1-9]\d{0,9}) /.exec(line);
        try { if (line == 'sound clear') { soundsClear(); Object.keys(soundVideos).forEach(soundVideoGone); } else if (line.slice(0, 6) == 'sound ') soundTold(line.slice(6)); else if (line.slice(0, 6) == 'video ') soundVideoTold(line.slice(6)); }
        catch (fault) { if (play) soundSay('played ' + play[1] + ' no it failed: ' + String(fault).replace(/[^\x20-\x7e]/g, '?').slice(0, 120)); }
    }
    from.waitForDataInBackgroundAndNotify;
}
function run(argv) {    // its name, "quiet" or "loud", and its idle seconds
    $.NSProcessInfo.processInfo.processName = $(argv[0] || 'sound');
    quiet = argv[1] == 'quiet'; idle = +argv[2] || idle; busy = Date.now();
    ObjC.registerSubclass({ name: 'LzrprfSoundHand', methods: { 'heard:': { types: ['void', ['id']], implementation: function () { soundHeard(); } } } });
    hand = $.LzrprfSoundHand.alloc.init;
    $.NSNotificationCenter.defaultCenter.addObserverSelectorNameObject(hand, 'heard:', $.NSFileHandleDataAvailableNotification, from);
    from.waitForDataInBackgroundAndNotify;
    soundSay('ready');
    while (!ended) {
        $.NSRunLoop.currentRunLoop.runModeBeforeDate($.NSDefaultRunLoopMode, $.NSDate.dateWithTimeIntervalSinceNow(1));
        if (playing()) { busy = Date.now(); idleSaid = false; }
        else if (!idleSaid && Date.now() - busy > idle * 1000) { idleSaid = true; soundSay('idle'); }    // lzrprf ends it when it has nothing unanswered for it, else it plays on
    }
    soundsClear(); Object.keys(soundVideos).forEach(soundVideoGone);
}
END

# The command of the sound process: the system's osascript in the sound
# container, under its limits, told its name, whether it plays at no volume
# ("lzrprf try"), and its idle seconds.                                 # [C12]
sub sounding {
    my ($quiet) = @_;
    return ('/bin/sh', '-c', $SOUND_LIMITS, 'lzrprf', contain($SOUND_CONTAINER, $SCRIPT), '-l', 'JavaScript', '-e', $SOUND_TEXT, $SOUND_NAME, $quiet ? 'quiet' : 'loud', $SOUND_IDLE);
}

sub sound_told {                          # [C12] sound lines of the page shown: with no window ("lzrprf try") printed for the test, else written to the sound process, started for them when it does not run
    my ($live, @lines) = @_;
    return window(@lines) unless $FROM;
    sound_started() or return;
    $SOUND->{out} .= join '', map { "$_\n" } @lines;
    push @{ $SOUND->{asked} }, map { /^sound play / ? $live->{url} : () } @lines;
    sound_flushed();
}

sub sound_started {                       # [C12] true when the sound process runs, started now when it did not; handed nothing before the system said it is contained [C3]; a start that fails is said in the log, once a window
    return 1 if $SOUND;
    my $fault = sub { record("no sound of a page is played: $_[0]") unless $SOUND_FAULTED++; return 0 };
    pipe(my $in, my $to) && pipe(my $from, my $out) or return $fault->('lzrprf could not make the pipes of its sound process');
    my $pid = fork // return $fault->('lzrprf could not start its sound process');
    become($in, $out, undef, sounding($TRY)) unless $pid;
    close $_ for $in, $out;
    if (!inside($pid)) { close $_ for $to, $from; ended($pid, 0); return $fault->('the system did not say that the sound process is contained, so it was handed nothing') }
    fcntl($_, POSIX::F_SETFL(), O_NONBLOCK) for $to, $from;
    $SOUND = { pid => $pid, to => $to, from => $from, out => '', in => '', asked => [], of => $$ };
    return 1;
}

sub sound_flushed {                       # [C12] what waits for the sound process, written as far as it takes it now; one that reads nothing more is ended
    return unless $SOUND && length $SOUND->{out};
    my $took = syswrite($SOUND->{to}, $SOUND->{out});
    if (defined $took && $took > 0) { substr($SOUND->{out}, 0, $took, '') }
    elsif (defined $took || (!$!{EAGAIN} && !$!{EINTR})) { sound_ended('it read no more of what it was handed') }
}

sub sound_heard {                         # [C12] what the sound process said, each line held to its form: a sound it did not play is said in the log, once a page
    my $got = sysread($SOUND->{from}, $SOUND->{in}, 4096, length $SOUND->{in});
    return if !defined $got && ($!{EINTR} || $!{EAGAIN});
    return sound_ended('it ended by itself') unless $got;
    while ($SOUND && (my $end = index($SOUND->{in}, "\n")) >= 0) {
        my $line = substr($SOUND->{in}, 0, $end + 1, '');
        chomp $line;
        next if $line eq 'ready';
        if ($line eq 'idle') { sound_ended() unless @{ $SOUND->{asked} } || length $SOUND->{out}; next }    # nothing it was handed is unanswered: it ends, and the next sound starts it again
        if (my ($key, $said) = $line =~ /^video ([0-9]{1,2} [0-9]{1,2}) ((?:yes|no|drift) [\x20-\x7e]{1,300})\z/) {    # [C22] a video's sound: whether it started, and how far it was from the picture at each clock
            print STDERR "sound $line\n" if $TRY;
            my $url = $SOUND->{videos}{$key} // next;
            record("the sound of the video $url is not heard: the system's player did not play it (" . substr($said, 3) . ')') if $said =~ /^no / && !$SOUND->{refused}{$url}++;
            next;
        }
        my ($n, $well, $what) = $line =~ /^played ([1-9][0-9]{0,9}) (yes|no) ([\x20-\x7e]{1,600})\z/ or return sound_ended('it said a line of no form');
        my $url = shift @{ $SOUND->{asked} } // return sound_ended('it answered a play it was not handed');
        print STDERR "sound $line\n" if $TRY;    # "lzrprf try" only: what the system's player said, for the test to read
        record("the page $url played a sound that is not heard: the system's player did not play it ($what)") if $well eq 'no' && !$SOUND->{refused}{$url}++;
    }
    sound_ended('it said a line too long') if $SOUND && length $SOUND->{in} > 4096;
}

sub video_sound_kept {                    # [C22] the MP4 of video K of the tab shown, as it was handed to the window, kept when it has a sound track, for the sound process if you turn its sound on; two at most, as the window holds
    my ($k, $body, $url) = @_;
    delete $VIDEO_SOUND{"$TAB $k"};
    return unless $$body =~ /hdlr.{8}soun/s;    # the handler of a sound track, in the MP4's description of its tracks
    my @held = sort { $VIDEO_SOUND{$a}{at} <=> $VIDEO_SOUND{$b}{at} } keys %VIDEO_SOUND;
    delete $VIDEO_SOUND{ shift @held } while @held >= 2;
    $VIDEO_SOUND{"$TAB $k"} = { body => $body, url => $url, at => now() };
}

sub video_sound_at {                      # [C22] the window's clock of video K, whose sound you turned on: its MP4 is handed to the sound process once, then each clock; "gone" lets it go here and there
    my ($k, $clock) = @_;
    my $key = "$TAB $k";
    my $held = $VIDEO_SOUND{$key};
    if ($clock =~ /^gone /) { delete $VIDEO_SOUND{$key}; return unless $SOUND && delete $SOUND->{videos}{$key} }
    elsif (!$held) { record("the video $k of the page shown has no sound lzrprf can hand to its sound process") if $clock =~ /^playing / && !$VIDEO_SOUND_SAID{$key}++; return }
    elsif (!$SOUND || !$SOUND->{videos}{$key}) {
        return if $clock =~ /^off /;
        sound_started() or return;
        my $body = $held->{body};
        $SOUND->{out} .= "video begin $key " . length($$body) . "\n";
        for (my $at = 0; $at < length $$body; $at += $VIDEO_FRAME) { $SOUND->{out} .= "video part $key " . encode_base64(substr($$body, $at, $VIDEO_FRAME), '') . "\n" }
        $SOUND->{out} .= "video end $key\n";
        $SOUND->{videos}{$key} = $held->{url};
    }
    $SOUND->{out} .= "video at $key $clock\n";
    sound_flushed();
}

sub sound_hushed {                        # [C12] another tab, a new page or no page kept running: every sound stops and goes, as the window let them go before
    return unless $SOUND;
    $SOUND->{out} .= "sound clear\n";
    delete $_->{sound_held} for @LIVE;
    delete $SOUND->{videos};              # a video's sound went with them; the window says when it is turned on again
    sound_flushed();
}

sub sound_ended {                         # [C12] the sound process is ended: its pipes closed, two seconds to end by itself, then killed; every page sends its sounds whole again; why, when it was not lzrprf's choice, said in the log
    my ($why) = @_;
    return unless $SOUND && $SOUND->{of} == $$;
    my $pid = $SOUND->{pid};
    close $_ for @$SOUND{qw(to from)};
    undef $SOUND;
    ended($pid, 2);
    delete $_->{sound_held} for @LIVE;
    record("the sound process ended: $why; a sound it was playing stopped") if defined $why;
}
