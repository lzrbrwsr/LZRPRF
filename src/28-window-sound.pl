# The sound of a video in the window [C22]. The window's player stays muted:
# its container lets no sound play (the register of sound components is not
# among its 42 names). A click on "Sound off" turns a video's sound on, and
# from then on the window says where its picture is, "video at K STATE MEDIA
# RATE WALL", at each change and each second while it plays; lzrprf hands the
# MP4 to the sound process once and passes each clock on, and the sound
# follows the picture there (sub video_sound_at). A video with no sound track
# says "No sound" and is turned on by nothing. This text is joined after the
# window's own (sub window_text) when the window is started.
sub window_sound_text {
    return <<'END';
function videoSeconds(value) {    // a CMTime handed over as an NSValue: value (8 bytes), timescale (4), flags (4), epoch (8), little-endian; NaN when it holds no time
    var d = $.NSMutableData.dataWithLength(24), abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', b, raw = [];
    value.getValueSize(d.mutableBytes, 24); b = d.base64EncodedStringWithOptions(0).js;
    for (var i = 0; i + 3 < b.length; i += 4) { var w = abc.indexOf(b[i]) << 18 | abc.indexOf(b[i + 1]) << 12 | Math.max(0, abc.indexOf(b[i + 2])) << 6 | Math.max(0, abc.indexOf(b[i + 3])); raw.push(w >> 16 & 255, w >> 8 & 255, w & 255); }
    var n = function (at, size) { var x = 0; for (var j = size - 1; j >= 0; j--) x = x * 256 + raw[at + j]; return x; }, v = n(0, 8), scale = n(8, 4);
    if (v >= Math.pow(2, 63)) v -= Math.pow(2, 64);
    return (n(12, 4) & 1) && scale > 0 ? v / scale : NaN;
}
function videoAudible(one) {    // whether its player holds a sound track: known once the system read the MP4
    var tracks = one.item ? one.item.tracks.js : [];
    return tracks.some(function (t) { return !t.assetTrack.isNil() && t.assetTrack.mediaType.js == 'soun'; });
}
function videoSoundTurned(k, one) {    // the click on its words at the bottom right: the sound on or off, never the window's own player, which stays muted
    if (!one.soundOn && !videoAudible(one)) { one.silent = true; return; }
    one.soundOn = !one.soundOn;
    if (!one.soundOn) say('video at ' + k + ' off 0.000 0 0000000000000');    // off and gone hold no time
}
function videoClock(k, one) {    // where the picture of a video with its sound on is: the time read and the clock it was read at, together
    if (!one || !one.soundOn || !one.player) return;
    var waits = one.state == 'playing' && one.player.timeControlStatus != 2, playing = one.state == 'playing' && !waits, at = videoSeconds(one.player.valueForKey('currentTime')), wall = Date.now();
    if (!(at >= 0)) at = 0;
    say('video at ' + k + ' ' + (playing ? 'playing' : one.state == 'ended' ? 'ended' : 'paused') + ' ' + Math.min(at, 999999).toFixed(3) + ' ' + (playing ? Math.round(Math.min(Math.max(one.player.rate, 0), 99) * 1000) / 1000 : 0) + ' ' + wall);
    if (one.state == 'playing') videoTick(waits ? 0.25 : 1);    // each second while it plays; each quarter while its player waits to play
}
function videoTick(after) {
    if (videoTicking) return;
    if (!videoClockHand) {
        busyClass({ name: 'LzrprfVideoClock', methods: { 'ticked:': { types: ['void', ['id']], implementation: function () { videoTicking = false; Object.keys(videos).forEach(function (k) { videoClock(k, videos[k]); }); } } } });
        videoClockHand = $.LzrprfVideoClock.alloc.init;
    }
    videoTicking = true;
    videoClockHand.performSelectorWithObjectAfterDelay('ticked:', $(), after);
}
function videoGone(k, one) {    // lzrprf lets go of its MP4, and the sound process of its sound; a video with no sound track had none kept (sub video_sound_kept, at most two held in all)
    if (one.soundOn || videoAudible(one)) say('video at ' + k + ' gone 0.000 0 0000000000000');
}
END
}

