# The pointer over a page kept running, in the window: the part of the window's
# text that moves, presses and the cursor use, joined after the rest of it by
# sub run (04-start.pl). The view of a laid page (LzrprfLaid) is given its
# moves, its release, its drags and its cursor here; each does nothing but on
# a page kept running ("live on") that is not a terminal's tab, while no modal
# is open.
#   a move: "page move X Y", in the laid page's points after scrolling, as a
#     click is, at most once a frame: the newest place waits for the frame and
#     a press or a release says it first;
#   on a site's page, the primary button: "page down X Y" when pressed and
#     "page up X Y" when let go, in place of "page click X Y"; between them the
#     drag is told as moves, held to the page's edges, so the page has the
#     pointer to its release (pointer capture); the home page and a video's
#     place keep their click;
#   the pointer leaving the page with no button down: "page out";
#   lzrprf's "cursor T NAME" shows the cursor NAME (CSS cursor, one of
#     POINTER_CURSORS) over the page of tab T; a name it has no cursor for,
#     and every tab told nothing since another tab or a new page was shown,
#     shows the arrow, as the page expects: it tells no first "default".
# The address bar takes a press over more than its pill shows (Henry, 2026-11-20:
# a bit hard to hit): PILL_REACH points around the pill on every side focus the
# field as a press inside it does (pillReach, used by beltClicked).
sub window_pointer_text {
    return <<'END';
// A picture sent once. lzrprf writes "picture NAME WIDE HIGH", the picture's rows and a line ".", once for
// each decoded picture, and every list places it after that by a line "N<name>,x,y,w,h,wide,high" (with the
// four numbers of a fit after it), which holds no row: a page's lists and a page loaded again carry the
// rows once. The bitmaps are kept by name, at most NAMED_MOST of them and NAMED_BYTES of pixels: beyond that
// the ones no list placed for longest go, never one the list drawn last placed. A name the window does not
// hold is drawn as a grey box and asked for once with "page refresh" (lzrprf then sends the rows of the
// whole list again); a second list that still lacks one is not asked for again, so nothing can loop.
var pictureNames = Object.create(null), naming = null, namedTick = 0, namedMissing = false, namedAsked = false;
var NAMED_MOST = 512, NAMED_BYTES = 512 * 1024 * 1024;    // DECLARED(the most bitmaps of pictures kept by name in one window, and the most bytes of their pixels: a front page holds about 40 pictures and 25 MB)
function pictureBegun(rest) { var p = /^([0-9a-f]{9,24}) ([1-9]\d{0,3}) ([1-9]\d{0,3})$/.exec(rest); naming = p ? [p[1], +p[2], +p[3]] : ['', 0, 0]; list = []; }
function pictureKept(rows) {
    var spec = naming;
    naming = null;
    if (!spec[0]) return;
    try { pictureNames[spec[0]] = { image: picture(spec[1], spec[2], rows), bytes: spec[1] * spec[2] * 4, used: namedTick }; } catch (fault) { delete pictureNames[spec[0]]; }    // rows that are no picture: its places stay grey
}
// A picture's rounded edge (a Q line before its N: x, y, w, h and the horizontal and vertical radius of the
// top-left, top-right, bottom-right and bottom-left corners, px of the laid page, whose y grows downward): a
// path the picture is drawn inside, so a picture in a box with rounded corners has them, as the box has.
function roundedOp(op, q) { if (q && op[2] == 'M') op.round = roundEdge(q); return op; }
function roundEdge(q) {
    var x = q[0], y = q[1], w = q[2], h = q[3], r = q.slice(4, 12).map(function (v) { return Math.max(0, v); }), k = 0.4477, p = $.NSBezierPath.bezierPath;
    var f = Math.min(1, w / Math.max(1e-6, r[0] + r[2]), w / Math.max(1e-6, r[4] + r[6]), h / Math.max(1e-6, r[1] + r[7]), h / Math.max(1e-6, r[3] + r[5]));    // radii that would overlap scaled down together (CSS Backgrounds 3 5.5)
    r = r.map(function (v) { return v * f; });
    var at = function (a, b) { return $.NSMakePoint(a, b); }, curve = function (to, c1, c2) { p.curveToPointControlPoint1ControlPoint2(to, c1, c2); };
    p.moveToPoint(at(x + r[0], y));
    p.lineToPoint(at(x + w - r[2], y)); curve(at(x + w, y + r[3]), at(x + w - r[2] * k, y), at(x + w, y + r[3] * k));
    p.lineToPoint(at(x + w, y + h - r[5])); curve(at(x + w - r[4], y + h), at(x + w, y + h - r[5] * k), at(x + w - r[4] * k, y + h));
    p.lineToPoint(at(x + r[6], y + h)); curve(at(x, y + h - r[7]), at(x + r[6] * k, y + h), at(x, y + h - r[7] * k));
    p.lineToPoint(at(x, y + r[1])); curve(at(x + r[0], y), at(x, y + r[1] * k), at(x + r[0] * k, y));
    p.closePath;
    return p;
}
function clippedTo(path, draw) {    // draw() inside path, when there is one; the clip ends with it
    if (!path) return draw();
    var context = $.NSGraphicsContext.currentContext;
    context.saveGraphicsState;
    try { path.addClip; draw(); } finally { context.restoreGraphicsState; }
}
function namedOp(line, grey) {    // the drawing of a line N: the kept bitmap in its place, as a line M with rows is drawn, or a grey box when the window does not hold it
    var parts = line.slice(1).split(','), n = parts.slice(1).map(Number), one = pictureNames[parts[0]];
    if (!one) { namedMissing = true; return [n[1], n[3], 'G', n[0], n[2], grey]; }
    one.used = namedTick;
    return [n[1], n[3], 'M', n[0], n[2], one.image, n.length > 9 ? $.NSMakeRect(n[6] / 100, n[5] - (n[7] + n[9]) / 100, n[8] / 100, n[9] / 100) : $.NSZeroRect];
}
function namedSettled() {    // after a list is drawn: a missing bitmap asked for once, and the kept ones bounded
    if (namedMissing && !namedAsked) { namedAsked = true; say('page refresh ' + selected); } else if (!namedMissing) namedAsked = false;
    namedMissing = false;
    var names = Object.keys(pictureNames), bytes = 0;
    names.forEach(function (name) { bytes += pictureNames[name].bytes; });
    if (names.length > NAMED_MOST || bytes > NAMED_BYTES) names.filter(function (name) { return pictureNames[name].used != namedTick; }).sort(function (a, b) { return pictureNames[a].used - pictureNames[b].used; }).forEach(function (name) {
        if (names.length <= NAMED_MOST && bytes <= NAMED_BYTES) return;
        bytes -= pictureNames[name].bytes; delete pictureNames[name]; names.pop();
    });
    namedTick++;
}
var POINTER_CURSORS = { 'default': 'arrowCursor', pointer: 'pointingHandCursor', text: 'IBeamCursor', 'vertical-text': 'IBeamCursorForVerticalLayout', crosshair: 'crosshairCursor', move: 'openHandCursor', grab: 'openHandCursor', grabbing: 'closedHandCursor', 'not-allowed': 'operationNotAllowedCursor', 'no-drop': 'operationNotAllowedCursor', copy: 'dragCopyCursor', alias: 'dragLinkCursor', 'context-menu': 'contextualMenuCursor', 'col-resize': 'resizeLeftRightCursor', 'row-resize': 'resizeUpDownCursor', 'ew-resize': 'resizeLeftRightCursor', 'ns-resize': 'resizeUpDownCursor', 'e-resize': 'resizeRightCursor', 'w-resize': 'resizeLeftCursor', 'n-resize': 'resizeUpCursor', 's-resize': 'resizeDownCursor' };    // as lzrprf %CURSORS
var pointerAt = null, pointerDue = false, pointerHeld = false, pointerShapes = {}, pointerHand = null;    // the newest place not yet said, a frame asked for, the button down on the page, the cursor of each tab as lzrprf told it
ObjC.registerSubclass({ name: 'LzrprfPointer', superclass: 'NSObject', methods: {
    'due:': { types: ['void', ['id']], implementation: function (sender) { pointerDue = false; pointerSaid(); } }
} });
function pointerMethods(methods) {    // the methods of LzrprfLaid, with the pointer's own added
    var pressed = methods['mouseDown:'].implementation, dragged = methods['mouseDragged:'] && methods['mouseDragged:'].implementation;
    methods['mouseDown:'] = { types: ['void', ['id']], implementation: function (event) { if (!pointerPressed(event)) pressed(event); } };
    methods['mouseDragged:'] = { types: ['void', ['id']], implementation: function (event) { if (pointerHeld) pointerMoved(event); else if (dragged) dragged(event); } };
    methods['mouseMoved:'] = { types: ['void', ['id']], implementation: function (event) { pointerMoved(event); } };
    methods['mouseUp:'] = { types: ['void', ['id']], implementation: function (event) { pointerReleased(event); } };
    methods['mouseExited:'] = { types: ['void', ['id']], implementation: function (event) { pointerLeft(); } };
    methods['resetCursorRects'] = { implementation: function () { pointerCursorRects(); } };
    return methods;
}
var PILL_REACH = 6;    // DECLARED(the points around the address bar's pill that take its press: past the pill's 36 by a finger's slip, and short of the reload arrow's reach at 125 and of the 56 point row's edges, which still move the window)
function pillReach() { return { x: PILL.origin.x - PILL_REACH, y: PILL.origin.y - PILL_REACH, w: PILL.size.width + 2 * PILL_REACH, h: PILL.size.height + 2 * PILL_REACH }; }    // the address bar's hit rectangle in the bar's row
function pillHit(at) { var r = pillReach(); return at.x >= r.x && at.x <= r.x + r.w && at.y >= r.y && at.y <= r.y + r.h; }
function pointerFree() { return liveOn && !trmnlKeys && sheet && !asking && !modalOpen; }    // [1235] also while lzrprf is busy (a page that keeps loading, as yle.fi does): the lines wait in the pipe in their order and lzrprf hands them to the page when it reads them; only a question or a sheet holds the page's pointer
function pointerPlace(event, held) {    // "X Y" in the laid page's points, or null outside it; held: kept to its edges instead
    var at = pointIn(canvas, event), x = Math.round(at.x), y = Math.round(at.y), wide = Math.min(sheet.wide, 200001), high = Math.min(sheet.high, 200001);
    if (held) { x = Math.max(0, Math.min(wide - 1, x)); y = Math.max(0, Math.min(high - 1, y)); }
    return x < 0 || y < 0 || x >= wide || y >= high ? null : x + ' ' + y;
}
function pointerSaid() {    // the newest place that waits, now
    if (pointerAt !== null && pointerFree()) say('page move ' + pointerAt);
    pointerAt = null;
}
function pointerMoved(event) {
    if (!pointerFree()) return;
    var at = pointerPlace(event, pointerHeld);
    if (at === null) return pointerLeft();
    pointerAt = at;
    if (pointerDue) return;
    pointerDue = true;
    pointerHand = pointerHand || $.LzrprfPointer.alloc.init;
    pointerHand.performSelectorWithObjectAfterDelay('due:', $(), SCROLL_FRAME);
}
function pointerPressed(event) {    // whether the press is the pointer's: on a site's page kept running, where no video is
    if (!pointerFree() || !current) return false;
    if (videoClicked(pointIn(canvas, event))) return true;    // [C22] a video's place is the window's own
    var at = pointerPlace(event, false);
    if (at === null) return true;
    win.makeFirstResponder(canvas);
    pointerSaid();    // a move that waits goes first: the lines keep their order
    pointerHeld = true;
    say('page down ' + at);
    return true;
}
function pointerReleased(event) {
    if (!pointerHeld) return;
    pointerHeld = false;
    if (!pointerFree()) return;
    pointerSaid();
    say('page up ' + pointerPlace(event, true));
}
function pointerLeft() {
    if (pointerHeld || !pointerFree()) return;
    pointerAt = null;
    say('page out');
}
function pointerShaped(rest) {    // lzrprf's "cursor T NAME"
    var n = /^(0|[1-9][0-9]?) ([a-z-]{1,16})$/.exec(rest);
    if (!n || !POINTER_CURSORS[n[2]] || pointerShapes[n[1]] == n[2]) return;
    pointerShapes[n[1]] = n[2];
    if (+n[1] == selected && canvas) win.invalidateCursorRectsForView(canvas);
}
function pointerReset() {    // another tab, a new page or no page kept running: the arrow, until a page asks for another
    pointerShapes = {};
    if (canvas && win) win.invalidateCursorRectsForView(canvas);
}
function pointerCursorRects() {    // the cursor over the page shown, the arrow but on a page kept running that asked for another
    var name = liveOn && !trmnlKeys ? pointerShapes[selected] : null;
    if (name && name != 'default') canvas.addCursorRectCursor(canvas.visibleRect, $.NSCursor[POINTER_CURSORS[name]]);
}
// A page loaded again is shown from where it was read: the place in its own pixels at the press, kept for each
// drawing of the same address in the same tab that comes within RELOAD_PLACE_MS, since a page arrives in several
// (its first list, then with its pictures and what its scripts made). It is let go the moment the view stands
// anywhere but where the last of these drawings put it: you scrolled, and the page is yours again.
var reloadPlace = null, RELOAD_PLACE_MS = 20000;    // DECLARED(the longest a page loaded again takes to arrive whole and still be put back where it was read)
function reloadPlaced() {    // the place a new drawing is shown from, or null when none is kept for it
    var keep = reloadPlace;
    if (!keep) return null;
    if (keep.tab != selected || keep.address != current || Date.now() > keep.until || keep.last !== null && sheet && Math.round(canvas.visibleRect.origin.y) != keep.last) { reloadPlace = null; return null; }
    return keep;
}

// "runs TAB K" (sub window_changed): the list the window holds with K stretches of it changed at once. The
// first K lines say each stretch, "FIRST DROP COUNT", in the order of the list and by places in the list
// held; the lines after them are the new lines of every stretch, one after another. null for anything that
// does not fit the list held: the caller then asks for the whole list ("page refresh").
function runsOf(old, lines, k) {
    var out = [], from = 0, at = k;
    if (!old || k < 1 || k > lines.length) return null;
    for (var i = 0; i < k; i++) {
        var h = /^(\d{1,6}) (\d{1,6}) (\d{1,6})$/.exec(lines[i]);
        if (!h) return null;
        var first = +h[1], drop = +h[2], count = +h[3];
        if (first < from || first + drop > old.length || at + count > lines.length) return null;
        for (var n = from; n < first; n++) out.push(old[n]);
        for (var m = 0; m < count; m++) out.push(lines[at + m]);
        from = first + drop; at += count;
    }
    if (at != lines.length) return null;
    for (var r = from; r < old.length; r++) out.push(old[r]);
    return out;
}
END
}
