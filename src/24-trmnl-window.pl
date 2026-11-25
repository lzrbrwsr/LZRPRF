
# LZRTRMNL in the window [C29]: the part of the window's text that a
# terminal's tab alone uses, joined after the rest of it by sub run.
# The view of a laid page (LzrprfLaid) is given its wheel, drag, copy, paste
# and the Edit menu's check here; each does nothing but in a terminal's tab
# ("live on 1 trmnl"), where the page fills the view and has nothing of its
# own to scroll.
#   the wheel: "page wheel N", rows to look back (N > 0) or forward;
#   a drag after a press: "page drag X Y", in the page's points;
#   your copy (Cmd-C, or Copy in the Edit menu): "page copy", and the text
#     lzrprf hands back ("trmnlcopy TEXT", sub trmnl_copied) is written to the
#     clipboard only within five seconds of that copy;
#   your paste (Cmd-V, or Paste in the Edit menu): the one place the window
#     reads the clipboard, as plain text, handed to lzrprf as "page paste
#     TEXT" (sub trmnl_pasted), at most $TRMNL_PASTE bytes;
#   Copy and Paste in the Edit menu are offered only while a terminal's tab
#     is shown.
sub window_trmnl_text {
    return <<'END';
var TRMNL_PASTE = 65536, trmnlCopyAsked = 0, trmnlWheelHeld = 0, trmnlDragSaid = '';    // DECLARED(lzrprf $TRMNL_PASTE)
function trmnlMethods(methods) {    // the methods of LzrprfLaid, with the terminal's own added
    methods['scrollWheel:'] = { types: ['void', ['id']], implementation: function (event) { if (!trmnlWheeled(event)) canvas.nextResponder.scrollWheel(event); } };    // on any other page the wheel goes where it always went
    var pressed = methods['mouseDown:'].implementation;
    methods['mouseDown:'] = { types: ['void', ['id']], implementation: function (event) { trmnlDragSaid = ''; pressed(event); } };    // a press starts a selection afresh
    methods['mouseDragged:'] = { types: ['void', ['id']], implementation: function (event) { trmnlDragged(event); } };
    methods['copy:'] = { types: ['void', ['id']], implementation: function (sender) { trmnlCopy(); } };
    methods['paste:'] = { types: ['void', ['id']], implementation: function (sender) { trmnlPaste(); } };
    methods['validateMenuItem:'] = { types: ['bool', ['id']], implementation: function (item) { return trmnlKeys && !modalOpen; } };    // Copy and Paste, the two items of the menu this view answers
    return methods;
}
function trmnlWheeled(event) {
    if (!trmnlKeys || modalOpen) return false;
    var dy = event.scrollingDeltaY, rows;
    if (event.hasPreciseScrollingDeltas) { trmnlWheelHeld += dy; rows = trmnlWheelHeld > 0 ? Math.floor(trmnlWheelHeld / 16) : Math.ceil(trmnlWheelHeld / 16); trmnlWheelHeld -= rows * 16; }    // a trackpad says points: a row is 16
    else rows = dy > 0 ? Math.max(1, Math.round(dy * 3)) : dy < 0 ? Math.min(-1, Math.round(dy * 3)) : 0;    // a wheel says lines: three rows a line, as Terminal
    if (rows) say('page wheel ' + Math.max(-999, Math.min(999, rows)));
    return true;
}
function trmnlDragged(event) {
    if (!trmnlKeys || !sheet || !free || modalOpen) return;
    var at = pointIn(canvas, event), x = Math.max(0, Math.min(sheet.wide - 1, Math.round(at.x))), y = Math.max(0, Math.min(sheet.high - 1, Math.round(at.y)));
    if (x + ' ' + y == trmnlDragSaid) return;
    trmnlDragSaid = x + ' ' + y;
    say('page drag ' + trmnlDragSaid);
}
function trmnlCopy() {
    if (!trmnlKeys || modalOpen) return;
    trmnlCopyAsked = Date.now();
    say('page copy');
}
function trmnlCopied(rest) {    // lzrprf's answer to your copy: the selected text, written to the clipboard
    if (!trmnlKeys || Date.now() - trmnlCopyAsked > 5000) return;
    trmnlCopyAsked = 0;
    var text;
    try { text = decodeURIComponent(rest); } catch (fault) { return; }
    clipboardWrite(text);
}
function trmnlPaste() {
    if (!trmnlKeys || modalOpen) return;
    var got = $.NSPasteboard.generalPasteboard.stringForType($('public.utf8-plain-text'));    // [C29] the one read of the clipboard, on your paste
    if (!got || got.isNil()) return;
    var said;
    try { said = encodeURIComponent(got.js); } catch (fault) { return; }    // a lone half of a surrogate pair is no text
    if (!said) return;
    if (said.replace(/%[0-9A-F]{2}/g, 'x').length > TRMNL_PASTE) return say('page pastelong');    // its bytes in UTF-8
    say('page paste ' + said);
}
END
}
