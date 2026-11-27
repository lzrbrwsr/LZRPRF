# The window. This text is run by the system's own osascript, in the window
# container. It makes one window with the application's name: the bar on top,
# lzrprf's strip under it, the page below, and under the page a pane that
# lists what the application says the page is made of. It draws the five
# kinds of line that "checked" let through, as characters with a look: a
# paragraph with its indent, text in a font and a colour, a line end, a row
# of spaces on grey as large as a picture would be, and in the pane a row
# for each thing: the name of its kind before the first of that kind, then
# its name, its version, and whether the application says it supports it.
# Or a laid page, in a view of its own in the place of the text: rectangles,
# runs of text and pictures made from their pixels where the application
# laid them out (see "sub laid" and "function laid").
# No picture file is read or decoded and no address is followed; a video you
# clicked is the one file of a site the window holds, and the system decodes
# it [C22]. A link is
# coloured text that does nothing when it is clicked, and the page's own menu
# holds "Copy" and nothing that opens anything; a laid page has no menu.
sub window_text {
    return <<'END';
ObjC.import('Cocoa');
// AutoFill stays off (ticket 1543, 2026-11-27): macOS asks com.apple.SafariPlatformSupport.Helper for a remote view
// on every text field that takes the keys; the window's container refuses that lookup (as it should: the passwords
// helper is not the window's), and AppKit tried again and again, making and tearing down remote views at 100% of a
// core until the window stopped answering. Registered for this process alone, before any field is made; nothing is
// written to anyone's defaults.
$.NSUserDefaults.standardUserDefaults.registerDefaults($({ NSAutoFillHeuristicsEnabled: false, NSEnableTextInputContextBasedAutoFill: false, NSAutoFillPanelEnabled: false, NSAutoFillRequiresTextContentTypeForOneTimeCodeOnMac: true }));    // AppKit's own switches (macOS 26): its AutoFill heuristics, the panel, and one-time codes only where a field asks for them
// THE BUSY METER (ticket 1543: the window spun at 90% of a core while it drew nothing, and once froze for 10 s). Every
// method this window gives the system (ObjC.registerSubclass: its drawings, presses, timers and delayed calls) is timed;
// once BUSY_EVERY_MS has passed, when the methods together took more than BUSY_SHARE of it, one line "frames busy
// TOTAL_MS SPAN_MS NAME=CALLS/MS;..." names the five that took most, and lzrprf writes it to the link's log.
var busySay = typeof say == 'function' ? say : null;    // the window's own say, taken as the script starts (a function declaration is there already): code that catches what the window says by putting its own say in place never catches the meter's report, which on a busy Mac broke checks of exact words (Ticket #1549)
var BUSY_EVERY_MS = 5000, BUSY_SHARE = 0.2, busyMeter = {}, busyFrom = Date.now();    // DECLARED(5 s: a spin shows within one look; a fifth of a core: well above an idle window, well below a spin)
function busyClass(spec) {    // every window class is registered through here (ObjC.registerSubclass itself cannot be replaced: JXA holds it read-only)
    Object.keys(spec.methods || {}).forEach(function (selector) {
        var method = spec.methods[selector], body = method.implementation, key = (spec.name || '').replace(/^Lzrprf/, '') + '.' + selector;
        if (typeof body != 'function') return;
        method.implementation = function () {
            var began = Date.now();
            try { return body.apply(this, arguments); }
            finally { var one = busyMeter[key] || (busyMeter[key] = [0, 0]), now = Date.now(); one[0]++; one[1] += now - began; if (now - busyFrom >= BUSY_EVERY_MS) busyTold(now); }
        };
    });
    return ObjC.registerSubclass(spec);
}
function busyTold(now) {
    var span = now - busyFrom, keys = Object.keys(busyMeter), total = keys.reduce(function (sum, k) { return sum + busyMeter[k][1]; }, 0), calls = keys.reduce(function (sum, k) { return sum + busyMeter[k][0]; }, 0);
    if ((total > span * BUSY_SHARE || calls > span / 4) && busySay) busySay('frames busy ' + Math.min(total, 999999) + ' ' + Math.min(span, 999999) + ' ' + keys.sort(function (a, b) { return busyMeter[b][1] - busyMeter[a][1] || busyMeter[b][0] - busyMeter[a][0]; }).slice(0, 5).map(function (k) { return k.replace(/[^\x21-\x7e]/g, '') + '=' + busyMeter[k][0] + '/' + busyMeter[k][1]; }).join(';').slice(0, 600));
    busyMeter = {}; busyFrom = now;
}
var TORWINDOW = false, TOR_APART = 'Tor opens a Tor window of its own, apart from this one: it shares nothing with this window, and Tor never carries this one.';    // [C17] a Tor window: lzrprf says so as the window's second word, "tor"
var INCOGNITO = false, UNKEPT_TIP = 'An incognito window writes nothing, so it adds no bookmark and imports none.';    // an incognito window [C16]: lzrprf says so as the window's second word
var PULLED = false;    // T5 (Henry, 2026-11-26): a window a tab was pulled out into is its own process, which macOS showed as a second app named osascript; it runs as an accessory, with no Dock or menu-bar icon of its own
var NAME = 'lzrprf', app, win, bar, logs, words, first, second, scroll, page, under, made, hand, asking = false, asked = 0, list = null;
var to = $.NSFileHandle.fileHandleWithStandardOutput, from = $.NSFileHandle.fileHandleWithStandardInput, held = $.NSMutableData.data;
var looks = {}, paragraphs = {};
var canvas, sheet = null, inks = {}, typefaces = {}, space = null;    // the view of a laid page, the laid page it shows, and what drawing it needs more than once
var again = false, viewing = '';    // the list being drawn is the page shown laid out again at a new width ("relaid"); the size of the page's view last told to lzrprf
// Each tab's last drawing, kept so that a tab chosen again is shown in the frame it was chosen in, before lzrprf hears of it:
// [tab] = { lines, sheet (the laid page made of them, once it was shown), share (where it was read), address, used }, for the
// DRAWINGS_MOST tabs shown last. lzrprf names the tab each list is for ("page N", "relaid N"): a list for a tab that is not in
// front goes to its kept drawing and not to the screen. A press of the strip made while lzrprf is busy is never dropped: the
// tab shows at once, and the newest such press is said to lzrprf the moment it is free (pendingTab: { line, to }).
var drawings = [], DRAWINGS_MOST = 8, drawnLines = [], drawnUsed = 0, pendingTab = null, perlTab = 0, listFor = 0;    // DECLARED(8 drawings: the tabs a person moves among, as lzrprf keeps 8 lists)
var NEWLINE = null;    // a line end as bytes, made once (the "heard:" of the window's hand)
var tabsView, belt, cog, faces = null, star, marksView, stripBack, veil, panel, panelTitle, panelSub, panelScroll, panelText, panelButtons = [], modalActions = [], modalOpen = false, modalKind = 'small';    // lzrprf's chrome: the tab strip, the bar's row, the star, the cogwheel, the bookmarks bar, the modal over everything
var form, nameLabel, nameField, addressLabel, addressField, folderLabelView, folderPop, newFolderField, editing = null;    // the bookmark modal's fields; the bookmark it changes, or null for a new one
var zooms = [], reopening = false, pulling = null;    // each tab's zoom in percent (zoomOf); a closed tab asked back, whose place the strip makes when lzrprf tells the tabs; the address a pulled tab's window opens with
var tabGen = 0, shownGen = 0;    // each tab of the strip is stamped with a number of its own when the window makes it (tabsTold): a tab that takes the index of the shown one closed is told from it by that, not by the index
var tabs = [{ title: '', gen: 0 }], selected = 0, shares = [], closing = null, restoring = null, free = false, focusing = false, drag = null, moving = false;    // the tabs as lzrprf last told them; where each was read, as a share of its page's height
var marks = [], folders = [], marksOn = false, marksPlaced = [], current = '', hover = { tab: -1, cog: false, faces: false, star: false, mark: -1, dot: -1, nav: -1, lock: false, home: -1, list: -1, cogRow: -1, logIcon: false, techIcon: false, torIcon: false, toolIcon: false, suggest: -1, wiz: -1 };    // the bookmarks and their folders as lzrprf last told them; the address shown in the bar; what the pointer is over
var TABS_HIGH = 42, BAR_ROW = 56, MARKS_ROW = 30, STRIP = 30, TOP = TABS_HIGH + BAR_ROW, MARGIN = 22, RADIUS = 16, PILL = null, GREEN, DIM, YELLOW, WHITE, DARK, GREY, LINE, GLASS, GLASS_HI, ICON, EDGE, FILL, HALO, FAINT;    // the heights of the strip of tabs, the bar's row, the bookmarks bar and lzrprf's strip, in points; the clear margin the frame's glow is drawn in, the frame's corners; the bar's pill; the laser's colours
// Where the pointer is, in a view's own coordinates. It is converted from the window's content view, a view
// this script keeps, and never from a nil: a nil made in the script can reach AppKit as a stray pointer and end
// the window in -[NSView ancestorSharedWithView:] (KERN_INVALID_ADDRESS, seen on mouse moves while installing,
// 2026-11-20). The content view stands at the window's origin and is not flipped, so its points are the window's.
var frameView = null;
function pointIn(view, event) { return view.convertPointFromView(event.locationInWindow, frameView || view); }

var root, homeView, listScroll, listView, secureBox, secureScroll, secureText, secureTech, secureBrief = '', engineField, listing = null, logParts = null, logRows = [], logNote = '', logLaid = null, logClosing = false, briefNext = null, pageShown = false, navState = [0, 0, 0], searchSet = false, searchNext = null, secureLines = null, securePinned = false, scriptRules = [], scriptsUnread = false, scriptLayers = { e1: 'off', sandbox: [], curated: [], parts: [], why: '', seen: [] }, filterState = { on: false, why: '', ms: 0, lists: [], commit: '', counts: [], allow: [], seen: [], unread: false };    // the frame every view stands in, the home page, the list page, the lock's panel; which list is open; whether a page is drawn; what back, forward and reload would do; whether a search engine is chosen and what follows its choice; the lock's lines

function say(line) { if (!behindEnded) to.writeData($(line + '\n').dataUsingEncoding(4)); }    // once lzrprf is gone a write to its pipe would end the window (signal PIPE: osascript has no handler for it), so nothing is written

// A page kept running with its tab (lzrprf's "live on"): a click in it is told to lzrprf as "page click X Y", in
// CSS pixels of the laid page, which are the laid view's own bounds after lzrprf's scrolling; it then has the
// keyboard, and a key is told as "page key NAME" (one printable character, or a name below, " shift" when shift
// is held), and what the writing system finishes (a letter such as ä) as "page text TEXT" while a text field of the
// page has the focus ("live on 1"). Nothing is told while lzrprf is busy or asks, and nothing with Command or
// Control, which are the menus'. lzrprf checks every line again and hands the page nothing else.
var liveOn = false, liveFocus = false, trmnlKeys = false;    // trmnlKeys: the tab shown is a terminal ("live on 1 trmnl"), which takes keys held with Control too [C29]
var PAGE_KEYS = { 53: 'Escape', 36: 'Enter', 76: 'Enter', 48: 'Tab', 51: 'Backspace', 117: 'Delete', 126: 'ArrowUp', 125: 'ArrowDown', 123: 'ArrowLeft', 124: 'ArrowRight', 115: 'Home', 119: 'End', 116: 'PageUp', 121: 'PageDown', 49: 'Space' };    // the keys by their key codes on a Mac keyboard
function liveTold(rest) {
    var parts = rest.split(' '), was = liveOn;
    if (parts[0] != 'on' && parts[0] != 'off') return;    // "live end ...": lzrprf's words why a page kept running ended; "live off" follows
    liveOn = parts[0] == 'on'; liveFocus = liveOn && parts[1] == '1'; trmnlKeys = liveOn && (parts[2] == 'trmnl' || parts[2] == 'cht'); chtTab = trmnlKeys && parts[2] == 'cht'; if (trmnlKeys && canvas) win.makeFirstResponder(canvas);    // a terminal opened or chosen has the keyboard at once
    if (!liveOn && canvas && win.firstResponder.isEqual(canvas)) win.makeFirstResponder(win);
    if (liveOn && !was) pageScrollTell(true);    // a page kept running is told where it is shown at its start
    if (!liveOn && homeLoading && pageShown) { homeLoading = false; pieces(); }    // a home tab shown again whose page no longer runs: its drawing, not the picture of a home (homeKept)
}

// The layers of the page kept running ([C18]; lzrprf's "layers T ITEMS", src/page/layers.rs): what of the page
// its program draws as layers the window keeps and moves, frame by frame, without a drawing. They stand in one view
// over the laid page and inside it, its size in the page's own pixels, so they scroll and zoom with it and the
// scroll view cuts them to the page's place: the bar, the strip, the tabs and every modal stand over them, as over
// the page. Each line is applied at once in one transaction with Core Animation's own animations off, so a move is
// where the page put it and not a slide toward it. A shape's glow is drawn once and kept (shouldRasterize); a
// particle source is an emitter of the system's, which moves its particles on its own. They are let go with the
// line "tabs" (another tab, or this one shown again, whose page then makes its own again), with a new page, and
// once no page is kept running. A line for a tab not shown, or an item of a layer the window does not hold, is
// passed over: lzrprf checked each before it was sent.
var layerHost = null, layerRoot = null, layerOf = {}, layerKit = null;
function layersKit() {    // the classes and the Core Graphics calls the layers need, bound once
    if (layerKit) return layerKit;
    ObjC.bindFunction('CGColorCreateSRGB', ['id', ['double', 'double', 'double', 'double']]);
    ObjC.bindFunction('CGPathCreateMutable', ['id', []]);
    ObjC.bindFunction('CGPathMoveToPoint', ['void', ['id', 'void *', 'double', 'double']]);
    ObjC.bindFunction('CGPathAddLineToPoint', ['void', ['id', 'void *', 'double', 'double']]);
    ObjC.bindFunction('CGPathAddQuadCurveToPoint', ['void', ['id', 'void *', 'double', 'double', 'double', 'double']]);
    ObjC.bindFunction('CGPathAddCurveToPoint', ['void', ['id', 'void *', 'double', 'double', 'double', 'double', 'double', 'double']]);
    ObjC.bindFunction('CGPathCloseSubpath', ['void', ['id']]);
    ObjC.bindFunction('CGImageCreateCopy', ['id', ['void *']]);    // the dot handed to Core Animation as an object; the calls tile() makes keep the forms Cocoa gives them, never bound again here
    if (!space) space = $.CGColorSpaceCreateWithName($.kCGColorSpaceSRGB);
    var dot = $.CGBitmapContextCreate(null, 16, 16, 8, 64, space, 8194);    // a particle: a soft white dot, 16 by 16, alpha premultiplied
    for (var r = 8; r >= 1; r--) { $.CGContextSetRGBFillColor(dot, 1, 1, 1, 0.16); $.CGContextAddArc(dot, 8, 8, r, 0, 6.2832, 0); $.CGContextFillPath(dot); }
    busyClass({ name: 'LzrprfLayers', superclass: 'NSView', methods: {
        'isFlipped': { implementation: function () { return true; } },    // the same top-down coordinates as the laid page and its pointer events
        'hitTest:': { implementation: function (point) { return $(); } }    // no press is its own: every one goes to the laid page under it
    } });
    var named = function (n) { return $.NSClassFromString($(n)); };    // Core Animation's classes by name: the window imports Cocoa alone
    layerKit = { layer: named('CALayer'), shape: named('CAShapeLayer'), text: named('CATextLayer'), emitter: named('CAEmitterLayer'), cell: named('CAEmitterCell'), deal: named('CATransaction'), dot: $.CGImageCreateCopy($.CGBitmapContextCreateImage(dot)), inks: {} };
    return layerKit;
}

function layersHost() {    // the view the layers stand in, over the laid page and the size of it; made again when it is not there
    var k = layersKit();
    if (!layerHost) {
        layerRoot = k.layer.layer;
        layerHost = $.LzrprfLayers.alloc.initWithFrame($.NSMakeRect(0, 0, 1, 1));
        layerHost.layer = layerRoot;    // a view that hosts this layer: it draws nothing of its own and takes no press
        layerHost.wantsLayer = true;
        layerHost.clipsToBounds = true;
        layerHost.autoresizingMask = 18;    // as wide and as tall as the page's view
    }
    // AppKit maps the root layer to this flipped view; do not flip the layer independently.
    layerRoot.masksToBounds = true;    // nothing of a layer outside the page's own place; both set after AppKit took the layer, which sets them its own way
    if (!layerHost.superview || layerHost.superview.isNil() || !layerHost.superview.isEqual(canvas)) canvas.addSubview(layerHost);
    layersFitted(); return layerHost;
}
function layersFitted() { if (layerHost && layerHost.superview && !layerHost.superview.isNil() && layerHost.superview.isEqual(canvas)) layerHost.frame = canvas.bounds; }    // the layers' view as large as the laid page's points, set again at every fit: layers made while a resize held the fit back (sizing) were given the size before, and masked to it the scene went blank

function layersClear() {    // every layer let go, and those still to be made
    layerQueue = []; layerReadyOwed = false;
    if (!layerRoot) return;
    layerOf = {};
    var gone = layerRoot.sublayers;
    if (gone && !gone.isNil()) gone.js.slice().forEach(function (one) { one.removeFromSuperlayer; });
}

function layerInk(hex) {    // a colour of rrggbbaa as Core Graphics takes it, or nothing for "-"; each made once
    if (hex == '-') return $();
    var k = layersKit();
    if (!k.inks[hex]) {
        var n = parseInt(hex, 16);
        k.inks[hex] = $.CGColorCreateSRGB((n >>> 24 & 255) / 255, (n >>> 16 & 255) / 255, (n >>> 8 & 255) / 255, (n & 255) / 255);
    }
    return k.inks[hex];
}

function layerPath(text) {    // an outline "M1,2L3,4Q..C..Z" as a CGPath, and the box its points stand in
    var p = $.CGPathCreateMutable(), box = [Infinity, Infinity, -Infinity, -Infinity], re = /([MLQCZ])([-0-9.,]*)/g, m;
    var see = function (n) { for (var i = 0; i + 1 < n.length; i += 2) { box[0] = Math.min(box[0], n[i]); box[1] = Math.min(box[1], n[i + 1]); box[2] = Math.max(box[2], n[i]); box[3] = Math.max(box[3], n[i + 1]); } };
    while ((m = re.exec(text))) {
        var n = m[2] ? m[2].split(',').map(Number) : [];
        see(n);
        if (m[1] == 'M') $.CGPathMoveToPoint(p, null, n[0], n[1]);
        else if (m[1] == 'L') $.CGPathAddLineToPoint(p, null, n[0], n[1]);
        else if (m[1] == 'Q') $.CGPathAddQuadCurveToPoint(p, null, n[0], n[1], n[2], n[3]);
        else if (m[1] == 'C') $.CGPathAddCurveToPoint(p, null, n[0], n[1], n[2], n[3], n[4], n[5]);
        else $.CGPathCloseSubpath(p);
    }
    if (!(box[0] <= box[2])) box = [0, 0, 0, 0];
    return { path: p, box: box };
}

function layerShaped(one, path, width, glow) {    // a shape's outline and the box its layer is drawn in: the outline's, wide enough for its stroke and its glow
    var made = layerPath(path), b = made.box, pad = width / 2 + glow * 2 + 2;
    one.layer.path = made.path; one.at = [b[0] - pad, b[1] - pad];
    one.layer.bounds = $.NSMakeRect(one.at[0], one.at[1], b[2] - b[0] + 2 * pad, b[3] - b[1] + 2 * pad);
    layerMoved(one);
}

function layerGlow(l, hex, radius, fresh) {    // fresh: a layer just made, which has no glow until it is given one
    if (hex == '-' || !(radius > 0)) { if (!fresh) { l.shadowOpacity = 0; l.shouldRasterize = false; } return; }
    l.shadowColor = layerInk(hex); l.shadowOpacity = 1; l.shadowRadius = radius; l.shadowOffset = $.NSMakeSize(0, 0);
    l.shouldRasterize = true; l.rasterizationScale = 2;    // the glow is drawn once; a move or a change of opacity reuses it
}

function layerMoved(one) {    // a layer at its transform: x' = a x + c y + e in its parent's space. Core Animation turns a layer about its anchor, which stands at its bounds' corner: the corner's place is put where the transform takes it
    var m = one.m, l = one.layer;
    if (one.kind == 'e') { l.emitterPosition = $.NSMakePoint(m[4], m[5]); return; }    // a source takes its place from its transform; its particles stay where they flew
    if (!one.anchored) { l.anchorPoint = $.NSMakePoint(0, 0); l.position = $.NSMakePoint(0, 0); one.anchored = true; }    // once: after it a move is one call, the corner's place carried by the transform's own translation
    l.affineTransform = { a: m[0], b: m[1], c: m[2], d: m[3], tx: m[0] * one.at[0] + m[2] * one.at[1] + m[4], ty: m[1] * one.at[0] + m[3] * one.at[1] + m[5] };
}

function layerWideFont(size, weight) { return wide(size, weight); }
function layerText(one, size, weight, wide, anchor, hex, glowc, glowr, words, spacing) {    // a text: its baseline at its origin, standing where the anchor says
    var t = one.inner, font = wide == 'w' ? layerWideFont(size, +weight >= 6 ? 0.4 : 0) : $.NSFont.fontWithNameSize($(+weight >= 6 ? 'Arial-BoldMT' : 'ArialMT'), size), ascent = font.ascender;
    var look = inked(font, colour(hex));
    look.setObjectForKey($.NSNumber.numberWithDouble(+spacing || 0), $.NSKernAttributeName);
    var text = styled(words, look), w = Math.max(4, text.size.width - (+spacing || 0));
    t.string = text; t.font = font; t.fontSize = size; t.foregroundColor = layerInk(hex); t.contentsScale = 2;
    t.alignmentMode = $('left'); t.anchorPoint = $.NSMakePoint(0, 0);
    t.bounds = $.NSMakeRect(0, 0, w + 2, size * 1.4);
    t.position = $.NSMakePoint(anchor == 'm' ? -w / 2 : anchor == 'e' ? -w : 0, -ascent);
    t.affineTransform = { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 };

    layerGlow(t, glowc, glowr);
    one.text = [size, weight, wide, anchor, hex, glowc, glowr, words, +spacing || 0];
    one.wide = w; one.ascent = ascent;
}

function layerWords(one, words) {
    var u = one.text;
    layerText(one, u[0], u[1], u[2], u[3], u[4], u[5], u[6], words, u[8]);
}

function layerNew(id, parent, kind, f, rest) {    // one "n" item: a layer of its kind under its parent
    var k = layersKit(), up = parent == '0' ? { layer: layerRoot } : layerOf[parent], one = { kind: kind, m: [1, 0, 0, 1, 0, 0], at: [0, 0], up: parent };
    if (!up) return;
    if (kind == 'g') one.layer = k.layer.layer;
    else if (kind == 'k') { one.layer = k.layer.layer; one.at = [+f[0], +f[1]]; one.layer.bounds = $.NSMakeRect(+f[0], +f[1], +f[2], +f[3]); one.layer.masksToBounds = true; }
    else if (kind == 's') {
        var l = one.layer = k.shape.layer;
        l.fillColor = layerInk(f[0]); l.strokeColor = layerInk(f[1]); l.lineWidth = +f[2];    // each call to Core Animation costs about 50 microseconds here: what a new layer already is (butt caps, miter joins, non-zero fill, no glow) is not set again
        if (f[3] == 'r' || f[3] == 's') { l.lineCap = $(f[3] == 'r' ? 'round' : 'square'); if (f[3] == 'r') l.lineJoin = $('round'); }
        if (f[4] == 'e') l.fillRule = $('even-odd');
        layerGlow(l, f[5], +f[6], true);
        one.glow = +f[6]; one.width = +f[2];
        layerShaped(one, f[7], one.width, one.glow);
    } else if (kind == 't') {
        one.layer = k.layer.layer; one.inner = k.text.layer;
        one.layer.addSublayer(one.inner);
        layerText(one, +f[0], f[1], f[2], f[3], f[4], f[6], +f[7], rest, +f[5]);
    } else if (kind == 'e') {
        var e = one.layer = k.emitter.layer, c = k.cell.emitterCell, life = Math.max(0.05, +f[2]);
        c.contents = k.dot; c.birthRate = 1; c.lifetime = life; c.lifetimeRange = life * 0.4;
        c.velocity = +f[3]; c.velocityRange = +f[3] * 0.4; c.emissionRange = +f[4]; c.emissionLongitude = +f[5];
        c.xAcceleration = +f[6]; c.yAcceleration = +f[7]; c.scale = +f[8] / 16; c.scaleRange = +f[8] / 64; c.scaleSpeed = -(+f[8] / 16) / life / 2; c.alphaSpeed = -1 / life;
        c.color = layerInk(f[0]);
        c.redSpeed = +f[9] || 0; c.greenSpeed = +f[10] || 0; c.blueSpeed = +f[11] || 0;
        e.emitterCells = $([c]); e.emitterShape = $('point'); e.renderMode = $('additive'); e.birthRate = +f[1];
        e.beginTime = $.NSProcessInfo.processInfo.systemUptime;    // Core Animation's clock (CACurrentMediaTime): it starts now, not as if it had run before
    } else return;
    if (kind != 's') layerMoved(one);    // a shape was put at its place with its outline
    up.layer.addSublayer(one.layer); layerOf[id] = one;
}

// The items are made in the order they came, for at most LAYER_TURN_MS of each turn of the window and at least one
// item a turn (on a busy Mac the transaction's own start can outlast the turn, and a turn that made none starved), in
// one transaction with Core Animation's animations off: a press never waits behind a whole scene (a home's 290 layers
// held the window 350 to 400 ms, 2026-11-23). A scene made from nothing is shown whole, then said ready (homeSceneReady).
var layerQueue = [], layerPumping = false, layerReadyOwed = false, LAYER_TURN_MS = 6;    // DECLARED(6 ms: a third of a 60 Hz frame, the rest left to the press and the drawing)
function layersApply(items) {
    if (!layerPumping && layerHost && !Object.keys(layerOf).length) layerHost.hidden = true;
    layerQueue.push.apply(layerQueue, items.split(';')); if (!layerPumping) layersPumped();
}
function layersPumped() {
    if (!layerQueue.length) { layerPumping = false; return; } var k = layersKit(), until, i = 0;    // a turn owed from before, whose queue a drain laid since, lays nothing
    k.deal.begin; k.deal.setDisableActions(true); until = Date.now() + LAYER_TURN_MS;    // the turn starts once the transaction is open, and lays at least one item: a slow begin on a busy Mac never leaves a turn that lays nothing, over and over
    try { do layerItem(layerQueue[i++]); while (i < layerQueue.length && Date.now() < until); } finally { k.deal.commit; layerQueue.splice(0, i); }
    layerPumping = layerQueue.length > 0;
    if (layerPumping) return hand.performSelectorWithObjectAfterDelay('layersPumped:', $(), 0);
    if (layerHost) layerHost.hidden = false;
    if (layerReadyOwed) { layerReadyOwed = false; homeSceneReady(); }
}
function layerItem(item) {
    var w = item.split(' '), op = w[0], id = w[1], one = layerOf[id];
    if (op == 'n') { if (!one) layerNew(id, w[2], w[3], w.slice(4), w.slice(12).join(' ')); return; }
    if (!one) return;
    if (op == 'm') { one.m = w.slice(2, 8).map(Number); layerMoved(one); }
    else if (op == 'o') one.layer.opacity = +w[2];
    else if (op == 'd' && one.kind == 's') layerShaped(one, w[2], one.width, one.glow);
    else if (op == 'f' && one.kind == 's') { one.layer.fillColor = layerInk(w[2]); one.layer.strokeColor = layerInk(w[3]); one.layer.lineWidth = +w[4]; one.width = +w[4]; one.glow = +w[6]; layerGlow(one.layer, w[5], +w[6]); }
    else if (op == 'f' && one.kind == 't') { var t = one.text; layerText(one, +w[4], t[1], t[2], t[3], w[2], w[5], +w[6], t[7], t[8]); }
    else if (op == 'c' && one.kind == 't') layerWords(one, w.slice(2).join(' '));
    else if (op == 'r' && one.kind == 'e') one.layer.birthRate = +w[2];
    else if (op == 'x') layerGone(id);
}

function layerGone(id) {    // a layer and all it holds let go: what it holds found by the parents the window keeps, not asked of Core Animation layer by layer
    var one = layerOf[id], gone = {}, more = true; if (!one) return;
    one.layer.removeFromSuperlayer; gone[id] = true;
    while (more) { more = false; for (var other in layerOf) if (!gone[other] && gone[layerOf[other].up]) more = gone[other] = true; }
    for (var g in gone) delete layerOf[g];
}

function layersTold(rest) {    // "layers T ITEMS" for the tab shown, onto the laid page shown
    var at = rest.indexOf(' ');
    if (at < 0 || +rest.slice(0, at) != selected || !sheet || !canvas || !scroll.documentView.isEqual(canvas)) return;
    layersHost(); layersApply(rest.slice(at + 1));
}

// Where the page kept running is shown from, told to lzrprf as "page scroll T X Y" for the tab T shown, in whole
// CSS pixels of the laid page (the laid view's own bounds, which are the page's pixels at every zoom), at most
// 200000 each way: after each drawing of the page shown, when a page is kept running ("live on"), and as you
// scroll, at most once a frame (the bounds of the scroll view's clip, heard as they change, said on the next
// frame; a frame due when another tab is chosen says nothing). lzrprf asks the window to show the page of tab T
// from where its script scrolled it with "scroll T X Y", just before the drawing of the same answer when there
// is one; the window says that place back at once, scrolls there, and once the drawing that follows is drawn
// (which keeps where it was read, as a share of the page) scrolls there again, so the drawing is shown from the
// page's own place and nothing older is said. It keeps that place for the next drawing too, until you scroll
// elsewhere. A line for a tab not shown is passed over. Nothing is said while no page is kept running, or the
// page shown is not a laid one.
var scrollSaid = null, scrollDue = false, scrollGen = 0, scrollDueGen = 0, scrollWanted = null, SCROLL_FRAME = 1 / 60;    // DECLARED(one frame of the screen: the most often a page is told it moved)
// Ticket 1530: the frames of a scroll, measured where they are made. Each burst of scrolling (moves with less than
// FRAMES_QUIET_MS between them) keeps the time each drawRect of the page took and the gaps between the moves; when it
// ends, one line "frames scroll MOVES DRAWS P50_US P95_US MAX_US LATE" goes to lzrprf, which writes it to the link's log.
// LATE counts the gaps over FRAMES_LATE_MS: a frame the screen showed twice. Nothing is kept past the line.
var frames = null, FRAMES_QUIET_MS = 400, FRAMES_LATE_MS = 25, FRAMES_MOST = 2048;    // DECLARED(400 ms: past a momentum's last move; 25 ms: one and a half frames at 60 Hz; 2048 draws: past a 30 s burst)
function framesNow() { return $.NSDate.timeIntervalSinceReferenceDate * 1000; }
function framesMoved() {
    var t = framesNow();
    if (!frames) { frames = { moves: 0, draws: [], late: 0, last: t }; hand.performSelectorWithObjectAfterDelay('framesDue:', $(), FRAMES_QUIET_MS / 1000); }
    else if (t - frames.last > FRAMES_LATE_MS) frames.late++;
    frames.moves++; frames.last = t;
}
function framesDrawn(ms) { if (frames && frames.draws.length < FRAMES_MOST) frames.draws.push(ms); }
function framesDue() {
    if (!frames) return;
    var idle = framesNow() - frames.last;
    if (idle < FRAMES_QUIET_MS) return hand.performSelectorWithObjectAfterDelay('framesDue:', $(), (FRAMES_QUIET_MS - idle) / 1000 + 0.01);
    var d = frames.draws.slice().sort(function (a, b) { return a - b; }), us = function (q) { return d.length ? Math.round(d[Math.min(d.length - 1, Math.floor(q * d.length))] * 1000) : 0; };
    say('frames scroll ' + Math.min(frames.moves, 99999) + ' ' + d.length + ' ' + Math.min(us(0.5), 999999) + ' ' + Math.min(us(0.95), 999999) + ' ' + Math.min(us(1), 999999) + ' ' + Math.min(frames.late, 99999));
    frames = null;
}
function pageScrollNow() {
    if (!sheet || !canvas || !scroll.documentView.isEqual(canvas)) return null;
    var at = canvas.visibleRect.origin;
    return Math.min(200000, Math.max(0, Math.round(at.x))) + ' ' + Math.min(200000, Math.max(0, Math.round(at.y)));
}
function pageScrollTell(fresh) {
    if (fresh) scrollSaid = null;
    if (!liveOn) return;
    var now = pageScrollNow();
    if (now === null || now == scrollSaid) return;
    scrollSaid = now;
    scrollWanted = null;    // you scrolled elsewhere: the page's own place is not kept for the next drawing
    say('page scroll ' + selected + ' ' + now);
}
function pageScrollMoved() {
    if (scrollDue) return;
    scrollDue = true; scrollDueGen = scrollGen;
    hand.performSelectorWithObjectAfterDelay('pageScrollDue:', $(), SCROLL_FRAME);
}
function pageScrollFrame() {    // the frame after a move: said, unless another tab was chosen since it was asked for
    var mine = scrollDue && scrollDueGen == scrollGen;
    scrollDue = false;
    if (mine) pageScrollTell(false);
}
function pageScrollTabbed() {    // another tab is shown: a frame asked for the one before says nothing, and nothing said of it counts
    scrollGen++; scrollDue = false;
    scrollSaid = null; scrollWanted = null;
}
function pageScrollApply(at) {
    if (!sheet || !canvas || !scroll.documentView.isEqual(canvas)) return;
    var n = at.split(' ');
    scrollSaid = at;    // where the page itself is: when the view stops elsewhere (a shorter view), that is said as a scroll
    canvas.scrollPoint($.NSMakePoint(+n[0], +n[1]));
}
function pageScrollTo(rest) {
    var n = /^(0|[1-9][0-9]?) (0|[1-9][0-9]{0,5}) (0|[1-9][0-9]{0,5})$/.exec(rest);
    if (!n || +n[1] != selected || +n[2] > 200000 || +n[3] > 200000) return;
    scrollWanted = n[2] + ' ' + n[3]; scrollSaid = scrollWanted;
    say('page scroll ' + selected + ' ' + scrollWanted);    // said back at once: lzrprf passes over what the window said before this
    pageScrollApply(scrollWanted);
}
function pageClicked(event) {
    if (sheet && !modalOpen && videoClicked(pointIn(canvas, event))) return;    // [C22] a video's place is the window's own
    if (!liveOn || !sheet || !free || modalOpen) return;
    win.makeFirstResponder(canvas);
    var at = pointIn(canvas, event), x = Math.round(at.x), y = Math.round(at.y);
    if (x < 0 || y < 0 || x >= sheet.wide || y >= sheet.high || x > 200000 || y > 200000) return;
    if (!current) homePress = { x: x, y: y, at: Date.now() };
    say('page click ' + x + ' ' + y);
}
function pageKey(event) {
    if (!liveOn || !sheet || !free || modalOpen) return;
    var flags = event.modifierFlags, shift = (flags & SHIFT) ? ' shift' : '', named = PAGE_KEYS[event.keyCode], typed = event.characters.js;
    if ((flags & CMD) || (flags & CONTROL) && !trmnlKeys) return; if (flags & CONTROL) { var bare = event.charactersIgnoringModifiers.js.toLowerCase(); return /^[a-z@\[\\\]^_ ]$/.test(bare) ? say('page ctrl ' + (bare == ' ' ? '@' : bare)) : undefined; }    // [C29] in a terminal, Control-C and the rest: the one control character each makes
    if (findOpen && event.keyCode == 53) return findClosed();    // Escape closes Find before the page is handed it
    if (named) return say('page key ' + named + shift);
    if (/^[\x21-\x7e]$/.test(typed)) return say('page key ' + typed + shift);
    if (!liveFocus) return;
    var text = '', bytes = 0;
    Array.from(typed.replace(/[\x00-\x1f\x7f-\x9f\u00ad\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff\ufff9-\ufffb]/g, '')).some(function (one) {
        var size = encodeURIComponent(one).replace(/%[0-9A-F]{2}/g, 'x').length;    // its bytes in UTF-8
        if (bytes + size > 1024) { say('page text ' + text); text = ''; bytes = 0; }    // DECLARED(lzrprf $LIVE_TEXT: preserve all chunks, on UTF-8 boundaries)
        text += one; bytes += size; return false;
    });
    if (text) say('page text ' + text);
}

// What lzrprf says, one line at a time.
var listPatch = null, homeAvailable = false;
function heard(line) {
    if (list) {
        if (line != '.') return list.push(line);
        var lines = list;
        list = null; if (naming) return pictureKept(lines);    // the rows of a picture sent once (28-window-pointer.pl)
        if (typeof listPatch != 'undefined' && listPatch) {
            var old = listFor == selected ? drawnLines : drawings[listFor] && drawings[listFor].lines, patch = listPatch;
            listPatch = null;
            var whole = patch.length == 1 ? runsOf(old, lines, patch[0]) : !old || patch[0] > old.length || patch[1] > old.length - patch[0] ? null : old.slice(0, patch[0]).concat(lines, old.slice(patch[0] + patch[1]));
            if (!whole) { say('page refresh ' + listFor); again = false; return; } lines = whole;
        }
        if (listFor != selected && listFor >= 0 && listFor < tabs.length) {    // a list for a tab that is not in front: it becomes that tab's kept drawing, and the screen stays as it is
            var before = drawings[listFor];
            keep(listFor, { lines: lines, sheet: null, share: again && before ? before.share : shares[listFor] || 0, address: before ? before.address : '' });
            again = false;
            scrollWanted = null;
            return;
        }
        drawnLines = lines;
        try { var drewAt = typeof linkId != 'undefined' && linkId ? Date.now() : 0; draw(lines); if (drewAt) say('link drew ' + (Date.now() - drewAt)); } catch (fault) { drawnLines = []; unlaid(); page.string = $(''); listed([]); say('fault ' + String(fault).replace(/[^\x20-\x7e]/g, '?').slice(0, 200)); }
        again = false;
        if (scrollWanted !== null) { pageScrollApply(scrollWanted); pageScrollTell(false); }    // the page's own place, which its drawing came with: shown from there, and said only where the view stops elsewhere
        else pageScrollTell(true);    // where this drawing is shown from: lzrprf hands a page only what it was not told already
        if (pageShown != lines.length > 0) { pageShown = lines.length > 0; pieces(); }
        return;
    }
    var at = line.indexOf(' '), word = at < 0 ? line : line.slice(0, at), rest = at < 0 ? '' : line.slice(at + 1);
    var aside = selected != perlTab;    // the window shows a tab lzrprf has not been told of yet: what lzrprf says of its own tab's bar, lock and arrows is said again once it is told
    if (word == 'tabs' || (word == 'page' && (/^\d{1,2}$/.test(rest) ? +rest : perlTab) == selected) || (word == 'live' && rest.slice(0, 3) != 'on ')) { layersClear(); pointerReset(); if (word == 'page') inspectClose(); }    // [C18] another tab, a new page shown, or no page kept running: the layers go, and the pointer's shape is the arrow again (the sound process lets every sound go too, told by lzrprf [C12])
    if (word == 'picture') pictureBegun(rest); else if (word == 'page' || word == 'relaid') { list = []; again = word == 'relaid'; listFor = /^\d{1,2}$/.test(rest) ? +rest : perlTab; perlTab = listFor; }
    else if (word == 'patch' || word == 'runs') { var p = (word == 'patch' ? /^(\d{1,2}) (\d{1,6}) (\d{1,6})$/ : /^(\d{1,2}) (\d{1,3})$/).exec(rest); if (p) { listFor = +p[1]; listPatch = word == 'patch' ? [+p[2], +p[3]] : [+p[2]]; list = []; again = true; } }    // runs: several stretches in one list (runsOf, 28-window-pointer.pl)
    else if (word == 'busy' || word == 'idle') { if (word == 'busy') restoring = null; else logClosing = false; strip(rest.split('\t'), word == 'idle', false); toastSaid(briefShown || rest.split('\t')[0]); briefShown = null; }    // busy: a new page is coming, from its top
    else if (word == 'tabs') { tabsTold(rest); if (!inspectFits(inspectUI)) inspectClose(); }
    else if (word == 'title') { var gap = rest.indexOf(' '), which = +rest.slice(0, gap); if (tabs[which]) tabs[which].title = rest.slice(gap + 1); tabsView.needsDisplay = true; } else if (word == 'trmnlcopy' || word == 'trmnlmenu') trmnlTold(word, rest);    // [C29] the text you copied in a terminal's tab, a menu to show there
    else if (word == 'install') installTold(rest); else if (word == 'updateoffer') updateOfferTold(rest);
    else if (word == 'checked') checkedTold(rest); else if (word == 'release') releaseNumber = rest;    // for About (28-window-menu.pl)
    else if (word == 'licence') licenceTold(rest);
    else if (word == 'profiles') profilesTold(rest);
    else if (word == 'sso') ssoTold(rest);
    else if (word == 'support') supportTold(rest);
    else if (word == 'tor') torTold(rest);
    else if (word == 'torsession') { if (rest == 'made') tnnlShown(); else torSessionTold(rest); } else if (word == 'tnnl') tnnlTold(rest); else if (word == 'parts') partsTold(rest);    // LZRTNNL's modal, before Tor connects, and the modules installed (28-window2.pl)
    else if (word == 'tool') toolTold(rest);
    else if (word == 'game' && /^helper [01]$/.test(rest)) { gameHelper = gameStaged = rest == 'helper 1'; toolItems = null; if (modalOpen && modalKind == 'tool' && toolTab == 'other') toolChanged(); else if (toolView) toolView.needsDisplay = true; } else if (word == 'defender') defenderTold(rest);    // H-0071: LZRDFNDR's satellite in the minigame, as lzrprf keeps it (gamehelper)
    else if (word == 'home' && rest == 'available') { homeAvailable = true; if (!current && free && !pageShown) homeAsked(false); }
    else if (word == 'home' && rest == 'ready') homeSceneReady();
    else if (word == 'startup' && rest == 'ready') { startupReady = true; if (startupRequested) shown(); }
    else if (word == 'homeaction' && !current && pageShown) {
        if (rest == 'search') { homeActionShot('search'); searched(); }
        else if (rest == 'marks' || rest == 'tabs') listOpened(rest);
        else if (rest == 'new') { homeActionShot('new'); newTab(); }
    }
    else if (word == 'welcome') welcomeTold(rest);
    else if (word == 'alert') modal('LZRBRWSR', rest, [['OK', function () { }]], 'small');    // ticket 1535: a fault or a refusal someone must read, in the standard modal
    else if (word == 'brief') briefNext = rest;    // the few words the strip shows in place of the next line's; the line in full is the strip's tip
    else if (word == 'log') logTold(rest);
    else if (word == 'ask') { if (!startupReady) { startupReady = true; if (startupRequested) shown(); } asked++; if (logClosing) { briefNext = null; say('button ' + asked + ' 1'); } else if (torAsking) torAsked(rest.split('\t')); else askModal(rest.split('\t')); }    // the log page was closed: what lzrprf still asks about the log is answered by the first button, which changes nothing; Stop Tor's question stands in the Tor modal
    else if (word == 'address' && aside) { if (drawings[perlTab]) drawings[perlTab].address = rest; }
    else if (word == 'address') { bar.stringValue = $(rest); current = rest; listing = null; suggestHidden(); pieces(); redrawn(); }
    else if (word == 'nav' && aside) { }
    else if (word == 'nav') { navState = rest.split(' ').map(Number); belt.needsDisplay = true; }
    else if (word == 'search') { searchSet = rest != 'none' ? searchSet || rest == 'set' : false; if (rest == 'ask') { searchNext = 'go ' + bar.stringValue.js.replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 2100); engineAsked(); } }
    else if (word == 'secure' && aside) { }
    else if (word == 'secure') { if (rest == 'begin') { secureLines = []; secureBrief = ''; } else if (rest.slice(0, 6) == 'brief ' && secureLines) secureBrief = rest.slice(6); else if (rest.slice(0, 5) == 'line ' && secureLines) secureLines.push(rest.slice(5)); else if (rest == 'none') { secureLines = null; secureBrief = ''; } if (!secureBox.hidden && rest != 'begin' && rest.slice(0, 5) != 'line ') secureShown(); }
    else if (word == 'marks') { if (rest == 'begin') { marks = []; folders = []; markCount = 0; folderAt = {}; } else { listSized(); redrawn(); } }
    else if (word == 'history') historyTold(rest);
    else if (word == 'import') importTold(rest);
    else if (word == 'mark') markTold(rest);
    else if (word == 'pictures') { picturesRow = true; picturesBlocked = rest == 'block'; if (cogOpen) cogPlaced(); }
    else if (word == 'marksbar') { marksOn = rest == 'on'; marksView.hidden = !marksOn; if (barMenuItem) barMenuItem.title = $(barToggleWords(marksOn, true)); place(); }
    else if (word == 'flagged' || word == 'flagreport') flagTold(word, rest);    // [C28] LZRDFNDR's red page, and the report of a wrong block before it is sent
    else if (word == 'permit') { if (/^answered [0-9]+$/.test(rest)) { if (permitLater && rest == 'answered ' + permitLater.number) permitLaterSet(null); if (rest == 'answered ' + asked && permitAsked == asked && (modalKind == 'permit' || modalKind == 'tall')) closeModal(); } else permitTold(rest); }    // [C26] lzrprf's question about the scripts of the page shown
    else if (word == 'permitscript') permitScriptTold(rest);    // [C26] one script of that question, with its source
    else if (word == 'scripts') scriptsTold(rest);    // [C26] the list of LZRDFNDR scripts
    else if (word == 'webquestion') webQuestionTold(rest);
    else if (word == 'sends') sendsTold(rest);
    else if (word == 'essential') essentialTold(rest);
    else if (word == 'sites') sitesTold(rest);    // [C26] LZRDFNDR's On Websites
    else if (word == 'redirects') redirectsTold(rest);    // [C4] LZRDFNDR's Redirects
    else if (word == 'filters') filtersTold(rest);    // [C27] the list page of Filters
    else if (word == 'layers') layersTold(rest);    // [C18] the layers of the page kept running
    else if (word == 'live') { liveTold(rest); if (!liveOn || trmnlKeys) inspectClose(); } else if (word == 'inspect') inspectTold(rest);
    else if (word == 'video') videoTold(rest);
    else if (word == 'scroll') pageScrollTo(rest); else if (word == 'cursor') pointerShaped(rest);    // the pointer's shape over the page (28-window-pointer.pl)
    else if (word == 'quit') app.terminate($());
    told(word, rest);
}

// lzrprf's strip: its words, and for a question two buttons. While a question
// is open, or lzrprf is busy, the bar takes nothing. Only the strip's own views
// change here: the window is laid out again (place) only when the strip changes
// its height, for a question, and the chrome is drawn again only when whether it
// takes a press changed, so "busy" and "idle" cost the few views they change.
// Ticket 1535: lzrprf's passing words (busy, idle) in a brief toast at the top of the page, under the bar, which never
// covers the tabs and takes no press (a label, neither editable nor selectable, which takes no press of its own).
var toast = null, briefShown = null, toastAt = 0, TOAST_MS = 2600;    // DECLARED(2.6 s: long enough to read a short line, short enough to stay out of the way)
function toastSaid(text) {
    text = String(text || '').trim();
    if (!text || !root) return;
    if (!toast) {
        toast = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 10, 10));
        toast.editable = false; toast.selectable = false; toast.bezeled = false; toast.drawsBackground = true;
        toast.backgroundColor = $.NSColor.colorWithWhiteAlpha(0.12, 0.88); toast.textColor = $.NSColor.whiteColor;
        toast.font = $.NSFont.systemFontOfSize(12); toast.alignment = 1; toast.wantsLayer = true; toast.layer.cornerRadius = 8;
        root.addSubview(toast);
    }
    toast.stringValue = $(text.slice(0, 160));
    var all = root.frame.size, wide = Math.min(all.width - 40, Math.max(120, text.slice(0, 160).length * 7 + 24));
    toast.frame = $.NSMakeRect((all.width - wide) / 2, all.height - TOP - 34, wide, 24);    // under the tabs, the bar and the bookmarks
    toast.hidden = false; toastAt = Date.now();
    hand.performSelectorWithObjectAfterDelay('toastDue:', $(), TOAST_MS / 1000);
}
function toastDue() { if (toast && Date.now() - toastAt >= TOAST_MS - 50) toast.hidden = true; }
function strip(parts, open, question) {
    var wasAsking = asking, wasFree = free;
    asking = question;
    free = !!open && !question;    // the tabs, the cogwheel and the bar take something only while lzrprf waits for it
    briefShown = briefNext;
    words.stringValue = $(briefNext !== null ? briefNext : parts[0] || '');
    words.toolTip = $(briefNext !== null ? parts[0] || '' : '');
    briefNext = null;
    loadingSet(!open && !question);    // and while it works, the line along the bar
    first.title = $(parts[1] || ''); second.title = $(parts[2] || '');
    first.hidden = !question; second.hidden = !question || !parts[2];
    bar.enabled = free && !modalOpen;
    logs.enabled = (free || listing == 'log') && !modalOpen;    // the log's icon closes the log page too, also while lzrprf asks about the log
    if (!free) suggestHidden();
    if (wasAsking != asking) place();
    else if (wasFree != free) redrawn();
    stripBack.needsDisplay = true;
    if (free && !asking && pendingTab) {    // a press of the strip made while lzrprf was busy: said now, the tab it chose already shown
        var press = pendingTab;
        pendingTab = press.after || null;    // a press made behind a new tab already shown waits for the next moment lzrprf is free
        shares[selected] = shareNow();
        if (press.closed !== undefined) closing = press.closed;
        sent(press.line);
        return;
    }
    if (free && !modalOpen && searchSet && searchNext) {    // a search engine was just chosen: the bar to type into, or the words typed before it was asked for
        var next = searchNext;
        searchNext = null;
        if (next == 'focus') barChosen();
        else if (next.length > 3) { bar.stringValue = $(next.slice(3)); sent(next); }
    }
    else if (free && !modalOpen && (focusing || win.firstResponder.isEqual(win))) { win.makeFirstResponder(bar); focusing = false; }    // a new tab: the bar, to type into
    if (free && !current && !pageShown && !listing && homeAvailable) homeAsked(false);
}

// The window from the top: the strip of tabs (the window's own three dots at its left), the bar's
// row (back, forward and reload, the bar as a pill with the lock and the star in it, the cogwheel
// at the right), the bookmarks bar when it is shown, the page with the pane under it and Log at its
// bottom right, and lzrprf's strip at the very bottom. A tab with no page shows the home page in
// place of the page and the pane; the bookmarks or the tabs page stands there too while it is open.
// Everything sits in a frame with a glowing edge (glassPlaced) that is the window's own edge: nothing
// of the window lies outside what you see, so its sides are held where they are seen. The views
// stand MARGIN points inside it; that band is the frame's edge, where a press resizes the window,
// and its beam glows inward only. All of it is set again whenever the window's size or the strip changes.
function place() {
    if (!homeView) return;    // a size told before the window's views are made
    var outer = win.contentView.frame.size;
    MARGIN = (win.styleMask & 16384) ? 0 : 5;    // full screen: no band. DECLARED(the band of the edge a press resizes from: 5 points is as wide as the macOS window edge one grabs, and holds the beam and its inward glow)
    root.frame = $.NSMakeRect(MARGIN + 1, MARGIN + 1, Math.max(1, outer.width - 2 * MARGIN - 2), Math.max(1, outer.height - 2 * MARGIN - 2));
    glassPlaced();
    win.invalidateCursorRectsForView(frameView);    // the sides' pointers follow the new size (frameCursors)
    TOP = TABS_HIGH + BAR_ROW + (marksOn ? MARKS_ROW : 0);
    var all = root.frame, wide = all.size.width, high = all.size.height, tall = 0;    // no footer: the strip stands only while lzrprf asks you something, and the page takes its place otherwise
    var row = high - TABS_HIGH - BAR_ROW, pillAt = 146, pillWide = Math.max(160, wide - pillAt - 64 - 64 - (profilesOn ? 34 : 0));    // LZRDFNDR and Tor take 64 points from the bar, and the Profiles icon, when there is one, 34
    PILL = $.NSMakeRect(pillAt, 10, pillWide, 36);    // in the bar's row
    tabsView.frame = $.NSMakeRect(0, high - TABS_HIGH, wide, TABS_HIGH);
    belt.frame = $.NSMakeRect(0, row, wide, BAR_ROW);
    var inset = INCOGNITO ? 96 : 0;    // DECLARED(the incognito label: its mark, 22 points, and the word at 12 points, about 62, with a gap after)
    bar.frame = $.NSMakeRect(pillAt + 42 + inset, row + 18, pillWide - 42 - 44 - inset, 20); if (barCover) barCover.frame = bar.frame;
    star.frame = $.NSMakeRect(pillAt + pillWide - 40, row + 13, 30, 30);
    cog.frame = $.NSMakeRect(wide - 50, row + 13, 30, 30);
    if (faces) faces.frame = $.NSMakeRect(wide - 84, row + 13, 30, 30);
    marksView.frame = $.NSMakeRect(0, row - MARKS_ROW, wide, MARKS_ROW);
    stripBack.frame = $.NSMakeRect(0, 0, wide, tall);
    stripBack.hidden = true;    // ticket 1535 (Henry): no black strip at all; questions stand in the modal, words in the toast
    words.hidden = true; first.hidden = true; second.hidden = true;    // what lzrprf says between questions is in the log and in the lock's panel (its first row), never in a footer
    words.frame = asking ? $.NSMakeRect(20, 10, wide - 340, tall - 18) : $.NSMakeRect(20, 6, wide - 168, 17);
    first.frame = $.NSMakeRect(wide - 304, (tall - 30) / 2, 132, 30);
    second.frame = $.NSMakeRect(wide - 162, (tall - 30) / 2, 138, 30);
    var pageTop = high - TOP;
    scroll.frame = $.NSMakeRect(0, tall, wide, Math.max(1, pageTop - tall));
    var icons = wide - 50 - (profilesOn ? 34 : 0);    // just right of the bar, left of the Profiles icon and the cogwheel: LZRDFNDR, then Tor
    toolIcon.frame = $.NSMakeRect(icons - (partOn('lzrtnnl') ? 64 : 32), row + 16, 26, 24); toolIcon.hidden = !partOn('lzrdfndr');    // a module that is not installed shows no icon (28-window2.pl)
    torIcon.frame = $.NSMakeRect(icons - 32, row + 16, 26, 24); torIcon.hidden = !partOn('lzrtnnl');
    homeView.frame = $.NSMakeRect(0, tall, wide, Math.max(1, pageTop - tall));
    listScroll.frame = homeView.frame;
    pieces();
    listSized();
    if (sizingNow) [tabsView, belt, marksView].forEach(function (one) { one.needsDisplay = true; }); else redrawn();    // while you resize only the views whose width changes are drawn again, the rest at the release (sizing)
    fit(true);
    securePlaced();
    techPlaced();
    suggestPlaced();
    cogPlaced();
    wordsPlaced(); findPlaced();
    placeModal();
}

// No footer, and no note under the bar (Henry, 2026-11-24: "we dont need that information"): what lzrprf says
// between questions is in the log and in the lock's panel, the zoom shows in the page's size, and a tip is the
// tooltip of its row. While lzrprf works (it said busy, and asks nothing), a thin line grows along the bar's lower
// edge, quickly at first and never to its end, and goes when lzrprf is idle again.
var loadingAt = 0, LOADING_STEP = 0.1;    // DECLARED(0.1 s: ten steps a second, a line the eye sees grow)
function wordsTold(text) { words.stringValue = $(text); }    // a tip: the strip's words, seen with the next question's strip; the row's tooltip says it at once
function loadingSet(on) {
    if (on == !!loadingAt) return;
    loadingAt = on ? Date.now() : 0;
    $.NSObject.cancelPreviousPerformRequestsWithTargetSelectorObject(hand, 'loadingTicked:', $());
    if (on) hand.performSelectorWithObjectAfterDelay('loadingTicked:', $(), LOADING_STEP);
    belt.needsDisplay = true;
}
function loadingTicked() { if (!loadingAt) return; belt.needsDisplay = true; hand.performSelectorWithObjectAfterDelay('loadingTicked:', $(), LOADING_STEP); }
function loadingShare() { return loadingAt ? Math.min(0.92, 1 - Math.exp(-(Date.now() - loadingAt) / 2500)) : 0; }    // DECLARED(2.5 s: most of the line by a typical page's load, and never all of it)

// Which of the page, the home page and a list page stands between the bar's row and the strip.
function pieces() {
    var home = !current && (!pageShown || homeLoading) && !listing;
    homeView.hidden = !home; listScroll.hidden = !listing;
    scroll.hidden = home || !!listing;    // the log is in the cogwheel's menu (Show log), and what the page is made of is the last row of the lock's panel
    homeView.needsDisplay = true;
    if (home && free && homeAvailable) homeAsked(false);
}

function look(font, size, kind) {
    var key = font + ' ' + size + ' ' + kind;
    if (!looks[key]) {
        var how = $.NSMutableDictionary.alloc.init, face = $.NSFont.fontWithNameSize($(font), size);
        how.setObjectForKey(face.isNil() ? $.NSFont.systemFontOfSize(size) : face, $.NSFontAttributeName);
        if (kind == 1) how.setObjectForKey($.NSNumber.numberWithInt(1), $.NSUnderlineStyleAttributeName);
        if (kind == 2) how.setObjectForKey($.NSColor.colorWithWhiteAlpha(0.55, 0.4), $.NSBackgroundColorAttributeName);
        how.setObjectForKey(kind == 1 ? $.NSColor.linkColor : kind == 3 ? $.NSColor.colorWithWhiteAlpha(0.55, 1) : $.NSColor.textColor, $.NSForegroundColorAttributeName);
        looks[key] = how;
    }
    return looks[key];
}

function paragraph(style, depth) {
    var key = style + depth;
    if (!paragraphs[key]) {
        var set = $.NSMutableParagraphStyle.alloc.init, step = 22 * depth, item = Math.max(step - 16, 4);
        set.firstLineHeadIndent = style == 'l' ? item : step;
        set.headIndent = style == 'l' ? item + 13 : step;
        set.paragraphSpacing = style == 'l' ? 3 : style == '1' ? 8 : style == '2' || style == '3' ? 6 : 9;
        set.paragraphSpacingBefore = style == '1' ? 10 : style == '2' || style == '3' ? 8 : 0;
        paragraphs[key] = set;
    }
    return paragraphs[key];
}

function named(bold, italic, fixed) {
    return fixed ? (bold ? (italic ? 'Menlo-BoldItalic' : 'Menlo-Bold') : italic ? 'Menlo-Italic' : 'Menlo-Regular')
        : (bold ? (italic ? 'Arial-BoldItalicMT' : 'Arial-BoldMT') : italic ? 'Arial-ItalicMT' : 'ArialMT');
}

// A laid page: the application said where every rectangle, run of text and picture stands.
// It is drawn in a view of its own in the place of the text, one CSS pixel to one point of
// the page and the whole scaled to the width of the window: smaller when the window is
// narrower, never larger until the window is half as wide again as the page. Each line is
// made ready here, and only drawn when the view draws, where what is outside what it draws
// is passed over. A picture is made from its bytes as they are: they are pixels already.
function laid(lines, first) {
    var previous = again ? sheet : null, old = previous || sheet;    // old: the page drawn until now, whose bitmaps a new page takes where a tile's place and rows are the same (a reload, a step within one site)
    if (!previous || Object.keys(inks).length > 256 || Object.keys(typefaces).length > 256) { inks = {}; typefaces = {}; }    // reuse ordinary pages; a changing page retains at most one checked frame plus 256 cached looks
    var size = /^L(\d+)x(\d+)$/.exec(lines[first]), next = { wide: +size[1], high: +size[2], ops: [], tiles: Object.create(null), saved: Object.create(null), buckets: {}, spanning: [] }, characters = 0;
    var grey = $.NSColor.colorWithWhiteAlpha(0.55, 0.4), kept = {}, roundNext = null;    // the tiles of this page, by number: [wide, high, bitmap]
    for (var at = first + 1; at < lines.length; at++) {
        var line = lines[at], kind = line.charAt(0), saved = previous && previous.saved && previous.saved[line], roundFor = roundNext; if (kind != 'Q') roundNext = null;    // a rounded edge is for the very next line alone
        if (saved && /[RGVX]/.test(kind)) { next.ops.push(saved); next.saved[line] = saved; if (kind == 'X') characters += saved[8].length; continue; }
        var n = kind == 'X' ? line.slice(1).split(',', 3).map(Number) : line.slice(1).split(',').map(Number);
        if (kind == 'R') next.ops.push([n[1], n[3], 'R', n[0], n[2], colour(line.split(',')[4])]);    // [top, height, kind, left, width, what draws it, ...]
        else if (kind == 'G') next.ops.push([n[1], n[3], 'G', n[0], n[2], grey]); else if (kind == 'N') next.ops.push(roundedOp(namedOp(line, grey, next, old), roundFor)); else if (kind == 'Q') roundNext = n;    // a picture placed by its name, cut to the rounded edge a Q line before it gave (28-window-pointer.pl)
        else if (kind == 'V') next.ops.push([n[1], n[3], 'V', n[0], n[2], n[4]]);    // a video's place and its number: a play mark over its poster, drawn by videoMark, and the video once clicked
        else if (kind == 'M' || kind == 'K') {
            var s = kind == 'K' && n[5] == 2 ? 2 : 1, height = kind == 'M' ? n[5] : n[4] * s, rows = lines.slice(at + 1, at + 1 + height), before = old && old.tiles && old.tiles[line];
            var same = before && before.rows.length == rows.length && before.rows.every(function (row, i) { return row === rows[i]; });
            var image = same ? before.image : kind == 'M' ? picture(n[4], n[5], rows) : { wide: n[3] * s, high: n[4] * s, rows: rows, made: null };    // a tile is made from its rows the first time the view draws it (sub paint), so a page's first frame waits for the tiles it shows, not for all of them: decoding is 1.5 ms a tile, 40 ms for a page of 26 (measured 2026-11-24); lzrprf checked every row before it was handed over
            var op = same ? before.op : kind == 'M' ? [n[1], n[3], 'M', n[0], n[2], image, n.length > 9 ? $.NSMakeRect(n[6] / 100, n[5] - (n[7] + n[9]) / 100, n[8] / 100, n[9] / 100) : $.NSZeroRect] : [n[2], n[4], 'M', n[1], n[3], image];    // an object-fit's part of the picture: its rows run down, the image's own space up
            next.tiles[line] = { rows: rows, image: image, op: op }; next.ops.push(op);
            if (kind == 'K') kept[n[0]] = [n[3], n[4], image];
            at += height;
        }
        else if (kind == 'J') next.ops.push([n[2], kept[n[0]][1], 'M', n[1], kept[n[0]][0], kept[n[0]][2]]);    // a placed tile draws the bitmap of its K: 32 bitmaps at most, however often they are placed
        else if (kind == 'X') {
            var parts = line.slice(1).split(','), text = parts.slice(5).join(','), high = n[2], look = face(parts[3].charCodeAt(0) - 64, high, parts[4]);
            characters += text.length;
            next.ops.push([n[1] - high * 1.25, high * 1.75, 'X', n[0], 0, $(text), look[0], n[1] - look[1], text]);    // drawn from its top: its baseline is the font's ascent below that; the text as it is, for Find
        } else throw 'a laid page holds a line of another kind';
        if (/[RGVX]/.test(kind)) next.saved[line] = next.ops[next.ops.length - 1];
    }
    next.ops.forEach(function (op, i) {
        if (op[1] > 16384) { next.spanning.push(i); return; }    // a tall background is indexed once, never in hundreds of buckets
        for (var b = Math.floor(op[0] / 256); b <= Math.floor((op[0] + op[1]) / 256); b++) (next.buckets[b] || (next.buckets[b] = [])).push(i);
    });
    var kept = restoring === null ? reloadPlaced() : (reloadPlace = null), share = restoring !== null ? restoring : again && sheet && sheet.high > 0 ? Math.min(1, Math.max(0, canvas.visibleRect.origin.y / sheet.high)) : 0;    // a tab chosen again is shown where it was read in it; a page laid out again at a new width where it was read, as a share of its height; a new page from its top
    var restoringWas = restoring; restoring = null;
    sheet = next; pageBack(false);
    if (again) videosPlaced(); else videosEnded();    // [C22] the same page at another width, or drawn again by its scripts, keeps its videos playing
    if (!scroll.documentView.isEqual(canvas)) scroll.documentView = canvas;
    if (previous && previous.wide == next.wide && previous.high == next.high) {
        var touched = [];
        for (var i = 0; i < Math.max(previous.ops.length, next.ops.length); i++) {
            if (previous.ops[i] === next.ops[i]) continue;
            if (previous.ops[i]) touched.push(previous.ops[i]);
            if (next.ops[i]) touched.push(next.ops[i]);
        }
        touched.forEach(function (op) { canvas.setNeedsDisplayInRect($.NSMakeRect(0, op[0] - 2, next.wide, op[1] + 4)); });
    } else {
        // Ticket 1536: a page drawn again at the same width while it loads keeps the place read, in points, not its share of the
        // height: a page growing under the view moved what was read down by share x the growth at every drawing (the jerk).
        var held = again && previous && previous.wide == next.wide && !kept && restoringWas === null ? Math.round(canvas.visibleRect.origin.y) : null;
        fit(); canvas.scrollPoint($.NSMakePoint(0, kept ? kept.y : held !== null ? held : Math.round(share * sheet.high)));
    }
    if (kept) kept.last = Math.round(canvas.visibleRect.origin.y); listed(lines.slice(0, first));    // where the view stands now: a shorter drawing stops short, and the next one is put at the place again
    if (findOpen) findRun(); namedSettled();
    drawn(lines.length, characters);
}

function unlaid() {
    sheet = null;
    videosEnded();
    if (canvas && !scroll.documentView.isEqual(page)) scroll.documentView = page;
    scroll.backgroundColor = page.backgroundColor;    // the glass, as round the page's text
}
function pageBack(look) {    // the room beside a laid page shows its colour: its canvas (its first rectangle, over its top and its width), else, looked at, the colour of its right edge in view at two of three heights, else the glass
    var op = sheet && sheet.ops[0], c = op && op[2] == 'R' && op[0] <= 0 && op[3] <= 0 && op[4] >= sheet.wide ? op[5] : null, v = canvas.visibleRect;
    var at = function (k) { var r = $.NSMakeRect(sheet.wide - 1, v.origin.y + v.size.height * k, 1, 1), rep = canvas.bitmapImageRepForCachingDisplayInRect(r); canvas.cacheDisplayInRectToBitmapImageRep(r, rep); return rep.colorAtXY(0, 0); };
    if (!c && look && sheet && scroll.documentView.isEqual(canvas)) { var high = at(0.1), low = at(0.9); c = high.isEqual(low) ? high : at(0.5); }
    scroll.backgroundColor = c || page.backgroundColor;
}

// The size of the page's view, in points, told to lzrprf as "view W H" when it changed: lzrprf
// lays the page shown out again at that width (its sub relaid). Two whole numbers, and 2 after them on a retina screen.
function view() {
    if (typeof homeAvailable != 'undefined' && homeAvailable && !current && pageShown && liveOn && !listing) homeAsked(false);
    var size = scroll.contentSize, z = zoomOf(selected), line = 'view ' + zoomWidth(size.width, z) + ' ' + zoomWidth(size.height, z) + (typeof win != 'undefined' && win && win.backingScaleFactor > 1.5 ? ' 2' : '');    // a page zoomed in is laid for a narrower page, zoomed out for a wider one
    if (line == viewing) return;
    viewing = line;
    say(line);
}

// A new size is told to lzrprf once it has rested for 120 ms, a drag paused too, so the page is laid at its width while the
// button is held and a release there costs only the swap (sub relaid); or at once when a resize ends or full screen does.
// While you resize, by the band of the frame's edge (frameClicked) or the system's own, a step moves views and layers and
// draws only what came newly into view: the page keeps the size it was drawn at, the room beside it shows its own colour
// (pageBack), and it is fitted once at the release; scaled and drawn whole at every step, a drag lagged, white where it grew.
var sizingNow = false, sizedArea = 0;
function sizing(on) {    // true or false: a resize begins or ends; nothing: how much of the page's view was drawn while it was resized, in views
    if (on === undefined) return (sizedArea / Math.max(1, canvas.visibleRect.size.width * canvas.visibleRect.size.height)).toFixed(2);
    if (on != sizingNow) { if (on) { pageBack(true); sizedArea = 0; } sizingNow = on; if (!on) { redrawn(); fit(true); } }
}
function resting() { $.NSObject.cancelPreviousPerformRequestsWithTargetSelectorObject(hand, 'viewed:', $()); hand.performSelectorWithObjectAfterDelayInModes('viewed:', $(), 0.12, $([$.NSRunLoopCommonModes])); }    // in every mode: also while a drag holds the button
function viewNow() { $.NSObject.cancelPreviousPerformRequestsWithTargetSelectorObject(hand, 'viewed:', $()); view(); }

function fit(placed) {    // placed: for a new size of the window, which draws again only a page whose size changed
    if (!sheet || sizingNow) return;
    var room = scroll.contentSize.width, scale = fitScale(room, sheet.wide, zoomOf(selected)), was = canvas.frame.size, laid = canvas.bounds.size;
    if (placed && was.width == sheet.wide * scale && was.height == sheet.high * scale && laid.width == sheet.wide && laid.height == sheet.high) return layersFitted();
    canvas.setFrameSize($.NSMakeSize(sheet.wide * scale, sheet.high * scale));
    canvas.setBoundsSize($.NSMakeSize(sheet.wide, sheet.high)); layersFitted();
    canvas.needsDisplay = true;
}

// Zoom (Cmd-plus, Cmd-minus, Cmd-0), for each tab. The page is laid out for the width the zoom
// means, the page's room divided by it, on the road every size takes ("view W H", sub relaid), and
// drawn scaled to fill the room, so its text flows anew as in other browsers. lzrprf lays a page
// at a step of 160 points and between 320 and 1600 wide (sub viewing), so a zoom shows as near as
// those steps let it: at some widths 110 percent is laid as 100 is.
var ZOOMS = [50, 67, 80, 90, 100, 110, 125, 150, 175, 200];
function zoomOf(n) { return zooms[n] || 100; }
function zoomNext(now, by) { var k = ZOOMS.indexOf(now); return !by || k < 0 ? 100 : ZOOMS[Math.max(0, Math.min(ZOOMS.length - 1, k + by))]; }    // the next step in or out, held at the ends; 0 is the page's own size
function zoomWidth(points, zoom) { return Math.max(1, Math.round(points * 100 / zoom)); }    // the size a page is laid at for room of this many points
function fitScale(room, wide, zoom) {    // how much a page laid this wide is scaled: to fill the room; a page far narrower than the room (beyond 1600) is shown at the zoom, not blown up
    var z = zoom / 100, scale = room / wide;
    return scale > 1.1 * z && room <= wide * 1.5 * z ? z : scale;
}
function zoomed(by) {
    if (modalOpen) return;
    var was = zoomOf(selected), now = zoomNext(was, by);
    while (zooms.length < tabs.length) zooms.push(100);
    zooms[selected] = now;
    if (now != was) { fit(); view(); }
}

// Find in page (Cmd-F): a small bar at the top right of the page with its field, which match is
// shown of how many ("3 of 17"), previous, next and close. It looks through the text of the drawing
// shown, capitals and small letters alike, marks every match and the current one more strongly, and
// scrolls the current one into view. A match within one run of text is found; one across two runs
// is not. It says nothing to lzrprf, fetches nothing and writes nothing.
var findBox = null, findField = null, findOpen = false, findHits = [], findAt = -1, FIND_WIDE = 360, FIND_HIGH = 36, FIND_MOST = 1000, FIND_ALL = null, FIND_NOW = null;    // DECLARED(1000 matches marked at most: a page of one common letter stays quick)
function findIn(texts, needle) {    // every match of needle in the texts, none overlapping: [which text, where in it]
    var hits = [], low = needle.toLowerCase();
    if (!low.length) return hits;
    texts.forEach(function (text, k) {
        var line = String(text).toLowerCase(), at = line.indexOf(low);
        while (at >= 0 && hits.length < FIND_MOST) { hits.push([k, at]); at = line.indexOf(low, at + low.length); }
    });
    return hits;
}
function findStep(at, count, by) { return count ? ((at < 0 ? (by > 0 ? -1 : 0) : at) + by + count) % count : -1; }    // the match after or before, round from the last to the first
function findSaid(at, count) { return count ? (at + 1) + ' of ' + count : 'No match'; }
function findRun() {
    var needle = findField ? findField.stringValue.js : '';
    findHits = [];
    if (sheet && scroll.documentView.isEqual(canvas)) {
        var ops = sheet.ops.filter(function (op) { return op[2] == 'X'; });
        findIn(ops.map(function (op) { return op[8]; }), needle).forEach(function (hit) {
            var op = ops[hit[0]], before = $(op[8].slice(0, hit[1])).sizeWithAttributes(op[6]).width, wide = $(op[8].substr(hit[1], needle.length)).sizeWithAttributes(op[6]).width;
            findHits.push({ x: op[3] + before, y: op[0] + op[1] / 7, w: Math.max(2, wide), h: op[1] * 5 / 7 });    // the band of the letters: the op is 1.75 lines high from 1.25 above the baseline
        });
    } else if (pageShown && !scroll.hidden) findIn([page.string.js], needle).forEach(function (hit) { findHits.push({ range: [hit[1], needle.length] }); });
    findAt = findHits.length ? 0 : -1;
    findShown();
}
function findShown() {
    if (findBox) findBox.needsDisplay = true;
    if (canvas) canvas.needsDisplay = true;
    var manager = page.layoutManager;
    manager.removeTemporaryAttributeForCharacterRange($.NSBackgroundColorAttributeName, $.NSMakeRange(0, page.string.length));
    findHits.forEach(function (hit, i) { if (hit.range) manager.addTemporaryAttributeValueForCharacterRange($.NSBackgroundColorAttributeName, i == findAt ? FIND_NOW : FIND_ALL, $.NSMakeRange(hit.range[0], hit.range[1])); });
    var one = findHits[findAt];
    if (!one) return;
    if (one.range) page.scrollRangeToVisible($.NSMakeRange(one.range[0], one.range[1]));
    else canvas.scrollRectToVisible($.NSMakeRect(one.x - 40, one.y - 80, one.w + 80, one.h + 160));
}
function findMarked(top, bottom) {    // drawn over the laid page: every match, the current one stronger
    if (!findOpen) return;
    findHits.forEach(function (hit, i) {
        if (hit.range || hit.y > bottom || hit.y + hit.h < top) return;
        (i == findAt ? FIND_NOW : FIND_ALL).setFill;
        $.NSRectFillUsingOperation($.NSMakeRect(hit.x - 1, hit.y, hit.w + 2, hit.h), 2);
    });
}
function findOpened() {
    if (modalOpen || !findBox) return;
    findOpen = true;
    findBox.hidden = false;
    findPlaced();
    win.makeFirstResponder(findField);
    var editor = findField.currentEditor;
    if (editor && !editor.isNil()) editor.selectAll($());
    findRun();
}
function findClosed() {
    if (!findOpen) return;
    findOpen = false;
    findBox.hidden = true;
    findHits = [];
    findAt = -1;
    findShown();
    win.makeFirstResponder(win);
}
function findMoved(by) {
    if (!findOpen) return findOpened();
    if (!findHits.length) return findRun();
    findAt = findStep(findAt, findHits.length, by);
    findShown();
}
function findPlaced() {
    if (!findBox) return;
    var area = scroll.frame;
    findBox.frame = $.NSMakeRect(Math.max(0, area.origin.x + area.size.width - FIND_WIDE - 18), area.origin.y + area.size.height - FIND_HIGH - 8, FIND_WIDE, FIND_HIGH);
    findField.frame = $.NSMakeRect(14, 8, FIND_WIDE - 14 - 186, 20);
}
function findChevron(cx, cy, way) { var p = $.NSBezierPath.bezierPath; p.moveToPoint($.NSMakePoint(cx - 5, cy - 2.5 * way)); p.lineToPoint($.NSMakePoint(cx, cy + 2.5 * way)); p.lineToPoint($.NSMakePoint(cx + 5, cy - 2.5 * way)); return p; }
function paintFind() {
    var size = findBox.frame.size, mid = size.height / 2, box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(0.5, 0.5, size.width - 1, size.height - 1), 10, 10);
    FILL.setFill;
    box.fill;
    glass(box, false);
    stroked(box, EDGE, 1);
    var said = findField.stringValue.js ? findSaid(findAt, findHits.length) : '', look = inked(sans(12), GREY);
    $(said).drawAtPointWithAttributes($.NSMakePoint(size.width - 98 - $(said).sizeWithAttributes(look).width, mid - 8), look);
    [findChevron(size.width - 80, mid, 1), findChevron(size.width - 54, mid, -1), crossed(size.width - 22, mid, 4.2)].forEach(function (p, k) { stroked(p, k < 2 && !findHits.length ? GREY : ICON, 1.4); });
}
function findClicked(event) {    // previous, next, close: the three at the bar's right end
    var at = pointIn(findBox, event), w = findBox.frame.size.width;
    if (Math.abs(at.x - (w - 80)) <= 12) findMoved(-1);
    else if (Math.abs(at.x - (w - 54)) <= 12) findMoved(1);
    else if (Math.abs(at.x - (w - 22)) <= 12) findClosed();
}

// lzrprf's chrome, drawn by this window alone and never by a page: the frame with its glowing edge,
// the strip of tabs, the bar's row, the bookmarks bar, the home page, the lists, the lock's panel,
// lzrprf's strip and the modal. A tab's title is the page's =title line as lzrprf checked it, drawn
// as plain text on one line and cut at its end. Every press here is one line to lzrprf in a shape it
// checks ("tab ...", "nav ...", "search ...", "menu ...", "mark ...", "button N K"), and only while
// lzrprf waits for one: after it, nothing is taken until lzrprf says it is idle again. The look is
// the neon laser: near black glass, thin cyan beams with their glow, light grey line icons, the
// system's face, and the logo in its wide cut with letters set far apart; drawn here on the
// processor, with no blur of the system's, which would need the graphics card's compiler.
function laser() {
    function rgb(r, g, b, a) { return $.NSColor.colorWithSRGBRedGreenBlueAlpha(r / 255, g / 255, b / 255, a === undefined ? 1 : a); }
    GREEN = rgb(72, 221, 255); DIM = rgb(40, 128, 150); YELLOW = rgb(255, 196, 92); WHITE = rgb(236, 242, 246); DARK = rgb(8, 11, 14);
    TOR_BLUE = rgb(70, 150, 255);    // Tor on: its own blue, never the beam's cyan, the same in an incognito window
    FIND_ALL = rgb(255, 214, 0, 0.38); FIND_NOW = rgb(255, 140, 0, 0.72);    // Find's marks over the page: every match, and the current one
    GREY = rgb(138, 150, 158); LINE = rgb(40, 49, 56); GLASS = rgb(72, 221, 255, 0.035); GLASS_HI = rgb(72, 221, 255, 0.08);
    ICON = rgb(206, 214, 220); EDGE = rgb(66, 76, 84); FILL = rgb(15, 19, 23); HALO = rgb(72, 221, 255, 0.55); FAINT = rgb(72, 221, 255, 0.16);
    if (INCOGNITO) {    // an incognito window glows violet, never in the beam's cyan, so it is told apart at a glance
        GREEN = rgb(196, 132, 255); DIM = rgb(112, 76, 160); GLASS = rgb(196, 132, 255, 0.035); GLASS_HI = rgb(196, 132, 255, 0.08);
        HALO = rgb(196, 132, 255, 0.55); FAINT = rgb(196, 132, 255, 0.16);
    }
}
function tint(a) { return INCOGNITO ? $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.77, 0.52, 1, a) : $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.28, 0.87, 1, a); }    // the beam's glow, at a strength
function masked(cx, cy, k) {    // the incognito mark: a mask's line, its two eyes cut out; k scales it
    var p = $.NSBezierPath.bezierPath;
    function at(x, y) { return $.NSMakePoint(cx + x * k, cy + y * k); }
    p.moveToPoint(at(-9, 2.5));
    p.curveToPointControlPoint1ControlPoint2(at(9, 2.5), at(-4, 5.5), at(4, 5.5));
    p.curveToPointControlPoint1ControlPoint2(at(0, -3), at(10, -5), at(3, -6));
    p.curveToPointControlPoint1ControlPoint2(at(-9, 2.5), at(-3, -6), at(-10, -5));
    p.closePath;
    p.appendBezierPathWithOvalInRect($.NSMakeRect(cx - 6.6 * k, cy - 1.2 * k, 4.4 * k, 2.8 * k));
    p.appendBezierPathWithOvalInRect($.NSMakeRect(cx + 2.2 * k, cy - 1.2 * k, 4.4 * k, 2.8 * k));
    return p;
}

function mono(size, bold) {
    var one = $.NSFont.monospacedSystemFontOfSizeWeight(size, bold ? 0.4 : 0);
    if (one.isNil()) one = $.NSFont.fontWithNameSize($(bold ? 'Menlo-Bold' : 'Menlo-Regular'), size);
    return one;
}

function sans(size, bold) { return $.NSFont.systemFontOfSizeWeight(size, bold ? 0.23 : 0); }    // the system's face, regular or medium

function wide(size, weight) {    // the system's face in its expanded width, for the logo; the plain face where the system has no width
    var one = null;
    try { one = $.NSFont.systemFontOfSizeWeightWidth(size, weight, 0.2); } catch (fault) { one = null; }
    return !one || one.isNil() ? $.NSFont.systemFontOfSizeWeight(size, weight) : one;
}

function glow(colour, blur) { var one = $.NSShadow.alloc.init; one.shadowColor = colour; one.shadowBlurRadius = blur; one.shadowOffset = $.NSMakeSize(0, 0); one.set; }

function glass(path, hi) {    // a pane of glass: a soft cyan wash, lighter at its top
    var wash = $.NSGradient.alloc.initWithStartingColorEndingColor(hi ? GLASS_HI : GLASS, $.NSColor.colorWithWhiteAlpha(0, 0));
    wash.drawInBezierPathAngle(path, -90);
}

function inked(font, colour, cut) {
    var how = $.NSMutableDictionary.alloc.init;
    how.setObjectForKey(font, $.NSFontAttributeName);
    how.setObjectForKey(colour, $.NSForegroundColorAttributeName);
    if (cut) { var set = $.NSMutableParagraphStyle.alloc.init; set.lineBreakMode = 4; how.setObjectForKey(set, $.NSParagraphStyleAttributeName); }
    return how;
}

function styled(text, how) {    // an attributed string: this macOS bridges no initWithString... for it, so it is made empty, given its text, then its attributes
    var one = $.NSMutableAttributedString.alloc.init;
    one.replaceCharactersInRangeWithString($.NSMakeRange(0, 0), $(text));
    one.setAttributesRange(how, $.NSMakeRange(0, one.length));
    return one;
}

function spaced(text, font, colour, kern) {    // letters set apart by kern points, as the logo's are
    var how = inked(font, colour);
    how.setObjectForKey($.NSNumber.numberWithDouble(kern), $.NSKernAttributeName);
    return styled(text, how);
}

function centred(said, cx, y, kern) { var size = said.size; said.drawAtPoint($.NSMakePoint(Math.round(cx - (size.width - kern) / 2), y)); }    // the space after the last letter is not counted

function stroked(path, colour, width, halo, blur) {    // a line, with its glow when halo is a colour
    $.NSGraphicsContext.saveGraphicsState;
    if (halo) glow(halo, blur || 6);
    colour.setStroke;
    path.lineWidth = width;
    path.lineCapStyle = 1;
    path.lineJoinStyle = 1;
    path.stroke;
    $.NSGraphicsContext.restoreGraphicsState;
}

function titled(item, words) { item.attributedTitle = styled(words, inked(sans(13), WHITE)); }

function sent(line) { free = false; bar.enabled = false; logs.enabled = false; redrawn(); say(line); }
function redrawn() { [tabsView, belt, cog, faces, star, marksView, homeView, listView, cogBox, logs, techs, torIcon, torView, toolIcon, toolView, suggestBox, wizardView].forEach(function (one) { if (one) one.needsDisplay = true; }); }
function takes() { return free && !modalOpen; }    // whether the chrome takes a press now

// The frame: the window is clear outside its rounded corners, and at its very edge stands the glass every view stands on,
// its rounded edge a thin cyan beam whose glow falls inward, so nothing is drawn, or reserved, outside what you see. The
// window server draws it: the glass is a gradient layer, and the beam one small picture of its corners and sides, drawn
// once for each scale and stretched between them (contentsCenter). A new size moves three layers and draws nothing; drawn
// anew for each size into a bitmap of the whole window, the glow took 100 to 450 ms a step of a resize (measured 2026-11-24).
var glassView = null, glassParts = null, beamFor = 0, BEAM_CORNER = 40;    // DECLARED(40 points: the corner's radius and the glow's 9 points of blur, all inside the piece's corner)
function glassPlaced() {
    var k = layersKit(), out = frameView.bounds, scale = win.backingScaleFactor, s = 2 * BEAM_CORNER + 2;
    if (!glassView) {    // under every view; it takes no press, so the band's presses are the frame's (frameClicked)
        glassView = $.LzrprfLayers.alloc.initWithFrame(out); glassView.layer = k.layer.layer; glassView.wantsLayer = true; frameView.addSubviewPositionedRelativeTo(glassView, -1, root);
        glassParts = [$.NSClassFromString($('CAGradientLayer')).layer, k.layer.layer]; glassParts.forEach(function (one) { glassView.layer.addSublayer(one); });
        glassParts[0].colors = $([layerInk('0f1317ff'), layerInk('06080aff')]); glassParts[0].masksToBounds = true;    // the glass, a shade lighter at its top
    }
    var glass = glassParts[0], beam = glassParts[1], top = glass.contentsAreFlipped ? 0 : 1;
    k.deal.begin; k.deal.setDisableActions(true);
    glassView.frame = out; glassView.layer.backgroundColor = MARGIN ? layerInk('00000003') : $();    // the band all but clear: a point with nothing drawn passes the mouse to the window under it, so its sides could not be held to resize. DECLARED(3 of 255, the least the screen keeps for certain, never seen)
    glass.frame = MARGIN ? $.NSInsetRect(out, 0.75, 0.75) : $.NSInsetRect(root.frame, -0.5, -0.5); glass.cornerRadius = MARGIN ? RADIUS : 0;    // DECLARED(0.75: half the beam's faint 1.5-point width, so the whole line is inside the window)
    glass.startPoint = $.NSMakePoint(0.5, top); glass.endPoint = $.NSMakePoint(0.5, 1 - top); beam.hidden = !MARGIN; beam.frame = out;    // full screen: no band and no beam
    if (MARGIN && beamFor != scale) { beamFor = scale; beam.contents = beamPiece(s, scale); beam.contentsScale = scale; beam.contentsCenter = $.NSMakeRect(BEAM_CORNER / s, BEAM_CORNER / s, 2 / s, 2 / s); }
    k.deal.commit;
}
function beamPiece(s, scale) {    // the beam round a box of s points, its glow clipped inside, in pixels at the window's scale
    var rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(null, s * scale, s * scale, 8, 4, true, false, $.NSCalibratedRGBColorSpace, 0, 0), was = $.NSGraphicsContext.currentContext, piece = $.NSImage.alloc.initWithSize($.NSMakeSize(s, s));
    rep.size = piece.size; $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));
    try { var path = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSInsetRect($.NSMakeRect(0, 0, s, s), 0.75, 0.75), RADIUS, RADIUS); path.addClip; stroked(path, FAINT, 3, GREEN, 9); stroked(path, GREEN, 1.5, GREEN, 4.5); }
    finally { $.NSGraphicsContext.currentContext.flushGraphics; $.NSGraphicsContext.setCurrentContext(was); }
    piece.addRepresentation(rep); return piece;
}

// The band of the frame's edge holds its sides: pressed there and dragged, the window is resized from
// that side, from a corner within two corner radii of one; anywhere else on the frame it is moved.
function edgesAt(p, r, corner) {
    var e = { left: p.x < r.x, right: p.x > r.x + r.w, bottom: p.y < r.y, top: p.y > r.y + r.h };
    if (e.left || e.right) { if (p.y < r.y + corner) e.bottom = true; if (p.y > r.y + r.h - corner) e.top = true; }
    if (e.top || e.bottom) { if (p.x < r.x + corner) e.left = true; if (p.x > r.x + r.w - corner) e.right = true; }
    return e;
}

function resizedFrame(e, f, dx, dy, minW, minH) {    // the frame f, its held sides moved by the pointer's dx, dy, never under the least size; the sides not held stay where they were
    var n = { x: f.x, y: f.y, w: f.w, h: f.h };
    if (e.right) n.w = Math.max(minW, f.w + dx);
    if (e.left) { n.w = Math.max(minW, f.w - dx); n.x = f.x + f.w - n.w; }
    if (e.top) n.h = Math.max(minH, f.h + dy);
    if (e.bottom) { n.h = Math.max(minH, f.h - dy); n.y = f.y + f.h - n.h; }
    return n;
}

function frameClicked(event) {
    var r = root.frame, p = frameView.convertPointFromView(event.locationInWindow, $());
    var e = MARGIN ? edgesAt({ x: p.x, y: p.y }, { x: r.origin.x, y: r.origin.y, w: r.size.width, h: r.size.height }, RADIUS * 2) : null;
    if (!e || !(e.left || e.right || e.top || e.bottom)) return windowHeld(event);
    var w0 = win.frame, f = { x: w0.origin.x, y: w0.origin.y, w: w0.size.width, h: w0.size.height }, start = $.NSEvent.mouseLocation, least = win.minSize, mask = (1 << 6) | (1 << 2), mode = $('NSEventTrackingRunLoopMode'), next, more;
    sizing(true);
    do {    // the drag, until the button is let go: 6 is a drag of the left button, 2 its release; of the steps queued meanwhile only the newest, and the frame and what it holds shown at once, together
        next = win.nextEventMatchingMaskUntilDateInModeDequeue(mask, $.NSDate.distantFuture, mode, true);
        while (next && !next.isNil() && next.type != 2 && (more = win.nextEventMatchingMaskUntilDateInModeDequeue(mask, $.NSDate.distantPast, mode, true)) && !more.isNil()) next = more;
        var at = $.NSEvent.mouseLocation, n = resizedFrame(e, f, at.x - start.x, at.y - start.y, least.width, least.height);
        win.setFrameDisplay($.NSMakeRect(n.x, n.y, n.w, n.h), true);
        layersKit().deal.flush;
    } while (next && !next.isNil() && next.type != 2);
    sizing(false);
    viewNow();
    frameSaid();
}

function frameCursors() {    // the pointer shows which way a side resizes, over the band of each side's edge
    if (!MARGIN || !root) return;
    var b = frameView.bounds, r = root.frame, x0 = r.origin.x, y0 = r.origin.y, x1 = x0 + r.size.width, y1 = y0 + r.size.height, c = RADIUS * 2;
    var across = $.NSCursor.resizeLeftRightCursor, along = $.NSCursor.resizeUpDownCursor;
    frameView.addCursorRectCursor($.NSMakeRect(0, y0 + c, x0, Math.max(0, y1 - y0 - 2 * c)), across);
    frameView.addCursorRectCursor($.NSMakeRect(x1, y0 + c, b.size.width - x1, Math.max(0, y1 - y0 - 2 * c)), across);
    frameView.addCursorRectCursor($.NSMakeRect(x0 + c, 0, Math.max(0, x1 - x0 - 2 * c), y0), along);
    frameView.addCursorRectCursor($.NSMakeRect(x0 + c, y1, Math.max(0, x1 - x0 - 2 * c), b.size.height - y1), along);
}

// The size and place the window opens at: as the last window was left (sub frame_kept), kept on a
// screen that is there now and no larger than it; "full" opens it as large as the desktop lets it.
function fitted(f, v, minW, minH) {
    var w = Math.min(Math.max(f.w, minW), v.w), h = Math.min(Math.max(f.h, minH), v.h);
    return { x: Math.min(Math.max(f.x, v.x), v.x + v.w - w), y: Math.min(Math.max(f.y, v.y), v.y + v.h - h), w: w, h: h };
}

function opened(kept) {
    var screens = $.NSScreen.screens, screen = $.NSScreen.mainScreen, m = /^(-?[0-9]+) (-?[0-9]+) ([0-9]+) ([0-9]+)$/.exec(kept);
    if (kept == 'full' && screen && !screen.isNil()) return win.setFrameDisplay(screen.visibleFrame, false);
    if (!m || !screen || screen.isNil()) return win.center;
    var f = { x: +m[1], y: +m[2], w: +m[3], h: +m[4] }, cx = f.x + f.w / 2, cy = f.y + f.h / 2;
    for (var i = 0; i < screens.count; i++) {
        var o = screens.objectAtIndex(i).visibleFrame;
        if (cx >= o.origin.x && cx <= o.origin.x + o.size.width && cy >= o.origin.y && cy <= o.origin.y + o.size.height) { screen = screens.objectAtIndex(i); break; }
    }
    var v = screen.visibleFrame, n = fitted(f, { x: v.origin.x, y: v.origin.y, w: v.size.width, h: v.size.height }, win.minSize.width, win.minSize.height);
    win.setFrameDisplay($.NSMakeRect(n.x, n.y, n.w, n.h), false);
}

var frameLast = '';
function frameSaid() { $.NSObject.cancelPreviousPerformRequestsWithTargetSelectorObject(hand, 'framed:', $()); hand.performSelectorWithObjectAfterDelay('framed:', $(), 0.6); }    // said to lzrprf once the window has rested from a move or a resize, not at every step of it

function framed() {
    var f = win.frame, s = win.screen, v = s && !s.isNil() ? s.visibleFrame : null;
    var full = (win.styleMask & 16384) || v && f.size.width >= v.size.width - 1 && f.size.height >= v.size.height - 1;
    var line = 'frame ' + (full ? 'full' : [f.origin.x, f.origin.y, f.size.width, f.size.height].map(Math.round).join(' '));
    if (line != frameLast) { frameLast = line; say(line); }
}

// The tabs.
function tabsTold(rest) {
    var told = rest.split(' '), count = +told[0], now = +told[1], chosen = !!pendingTab && pendingTab.to !== undefined;
    if (pulling !== null) { if (count < tabs.length) closing = pulling; pulling = null; }    // a tab pulled out is gone only when lzrprf could start its window
    if (!chosen && now != selected && selected !== closing && selected < tabs.length) keep(selected, keptNow());    // the tab leaving the screen (for a new tab, or after one closed) keeps its drawing
    if (closing !== null) {
        [tabs, shares, drawings, zooms].forEach(function (all) { all.splice(closing, 1); });
        if (chosen && pendingTab.to > closing) pendingTab.to--;
        closing = null;
    }
    if (reopening && count > tabs.length) {    // the closed tab put in again at its place: what the strip keeps of the tabs after it moves along one
        [shares, drawings, zooms].forEach(function (all) { while (all.length < tabs.length) all.push(all == zooms ? 100 : all == shares ? 0 : null); all.splice(now, 0, all == zooms ? 100 : all == shares ? 0 : null); });
        if (chosen && pendingTab.to >= now) pendingTab.to++;
        tabs.splice(now, 0, { title: '', gen: ++tabGen });
    }
    reopening = false;
    while (tabs.length < count) tabs.push({ title: '', gen: ++tabGen });
    tabs.length = count;
    [shares, drawings, zooms].forEach(function (all) { if (all.length > count) all.length = count; });
    perlTab = now;
    if (moving) moving = false; else if (!chosen) restoring = shares[now] || 0;    // a tab only moved along the strip: the page shown stays where it is read
    var was = selected, wasGen = shownGen;
    selected = chosen ? Math.min(pendingTab.to, count - 1) : now;    // a tab chosen while lzrprf was busy stays chosen: lzrprf is told of it when it is free
    shownGen = tabs[selected] ? tabs[selected].gen : -1;
    if (selected != was || shownGen != wasGen) pageScrollTabbed();    // the shown tab closed and the next took its index: another tab all the same, so nothing said of the closed one's scroll is kept
    redrawn();
    view();    // the tab shown now has its own zoom: lzrprf lays its page at the width that means
}

// A tab's drawing, kept (drawings), and shown again. The drawing on the screen is kept as it is: the
// laid page already made, where it is read, and the address in the bar. Only the DRAWINGS_MOST tabs
// shown last keep theirs; the others are drawn from what lzrprf sends when they are chosen.
function keptNow() { return { lines: drawnLines, sheet: sheet && scroll.documentView.isEqual(canvas) ? sheet : null, share: shareNow(), address: current }; }
function keep(at, one) {
    if (at < 0) return;
    if (!one.lines.length) { drawings[at] = null; return; }    // no page is no drawing: lzrprf says what such a tab shows
    one.used = ++drawnUsed;
    drawings[at] = one;
    var held = [];
    drawings.forEach(function (d, i) { if (d && i != at) held.push(i); });
    held.sort(function (a, b) { return drawings[a].used - drawings[b].used; });
    while (held.length > DRAWINGS_MOST - 1) drawings[held.shift()] = null;
}
function shownAgain(one) {
    drawnLines = one.lines;
    videosEnded();    // the videos were the page shown before
    var first = 0;
    while (first < one.lines.length && one.lines[first].charAt(0) == 'U') first++;
    if (one.sheet) {    // the laid page as it was made: nothing of it is made again
        sheet = one.sheet;
        if (!scroll.documentView.isEqual(canvas)) scroll.documentView = canvas;
        fit(); pageBack(false);    // the room beside the page is this page's, never the colour of the tab before
        canvas.scrollPoint($.NSMakePoint(0, Math.round(one.share * sheet.high)));
        listed(one.lines.slice(0, first));
    } else {
        restoring = one.share;
        try { draw(one.lines); } catch (fault) { drawnLines = []; unlaid(); page.string = $(''); listed([]); }
        restoring = null;
        if (sheet && scroll.documentView.isEqual(canvas)) one.sheet = sheet;
    }
    bar.stringValue = $(one.address || '');
    current = one.address || '';
    pageShown = one.lines.length > 0;
    listing = null;
    pieces();
    if (findOpen) findRun();
}
// A tab chosen in the window: the strip shows it at once, with its kept drawing, or with no page until
// lzrprf sends one. Returns whether a kept drawing was shown, which lzrprf is told ("kept").
function tabChosen(n) {
    if (n == selected || n < 0 || n >= tabs.length) return false;
    shares[selected] = shareNow();
    keep(selected, keptNow());
    selected = n;
    pageScrollTabbed();
    tabsView.needsDisplay = true;
    var one = drawings[n];
    if (one) { one.used = ++drawnUsed; shownAgain(one); homeKept(one); return true; }
    drawnLines = [];
    unlaid();
    page.string = $('');
    listed([]);
    if (pageShown) { pageShown = false; pieces(); }
    if (findOpen) findRun();
    return false;
}

function shareNow() { return sheet && sheet.high > 0 && scroll.documentView.isEqual(canvas) ? Math.min(1, Math.max(0, canvas.visibleRect.origin.y / sheet.high)) : 0; }

// A press of the strip, said to lzrprf: at once when it is free, else the moment it is (strip). A tab
// chosen is shown in this very frame (tabChosen), whatever lzrprf is doing; kept says whether the
// press already showed it; a tab closed while lzrprf is free leaves the strip in this frame too, the next
// shown with its kept drawing (tabClosed). Only an open question or modal takes the press instead.
function tabSaid(line, closed, kept) {
    torAskCancelled();    // a Tor question stands in its own modal, not in asking: answered by Cancel, its first button, before the modal steps aside
    if (asking && !askAnswered(1)) return;    // no box holds the tabs: a question standing is answered by its first button, the answer when nobody answers
    if (modalOpen && modalActions.length) closeModal();    // and a modal steps aside; the installer's while it runs (no button) still holds them
    if (modalOpen || asking) return;
    if (closed !== undefined && tabs.length < 2 && /^tab close /.test(line)) { win.performClose($()); return; }    // T6 (Henry, 2026-11-26): closing the last tab closes the window, as the red dot does, and no empty tab is opened in its place
    var chose = /^tab select (\d+)$/.exec(line), to = chose ? +chose[1] : undefined;
    if (chose && kept === undefined) kept = tabChosen(to); else if (closed !== undefined && takes() && tabClosed(closed)) { kept = true; closed = undefined; }
    if (kept && line.slice(0, 4) == 'tab ') line += ' kept';
    if (!takes()) { var press = { line: line, to: to, closed: closed }; if (pendingTab && pendingTab.made) { if (closed === undefined) pendingTab.after = press; } else pendingTab = press; return; }    // the newest press waits for lzrprf, and is never dropped; behind a new tab already shown, it is said after that tab
    shares[selected] = shareNow();
    if (closed !== undefined) closing = closed;
    sent(line);
}
function tabClosed(n) {    // the tab n out of the strip now, as lzrprf takes it out (sub tabbed); false, and nothing done, when the tab shown next has no kept drawing
    var next = selected > n || selected > tabs.length - 2 ? selected - 1 : selected, one = selected == n ? drawings[next < n ? next : next + 1] : null;
    if (tabs.length < 2 || n >= tabs.length || (selected == n && !one)) return false;
    [tabs, shares, drawings, zooms].forEach(function (all) { all.splice(n, 1); });
    selected = next; shownGen = tabs[next].gen; perlTab = next; tabsView.needsDisplay = true;
    if (one) { layersClear(); pageScrollTabbed(); one.used = ++drawnUsed; shownAgain(one); homeKept(one); }
    return true;
}

function newTab() { if (!modalOpen && !asking && tabs.length < 32 && !(pendingTab && pendingTab.made)) { focusing = true; var now = takes(); tabSaid('tab new'); if (now) tabMade(); else if (pendingTab && pendingTab.line == 'tab new') { tabMade(); pendingTab.made = true; } } }    // while lzrprf is busy too: the new tab is in the strip at once, and said when lzrprf is free
function tabMade() {    // the new tab in the strip in this very frame, with the picture of a home, before lzrprf says so (tabsTold): it said so 20 to 140 ms later (measured 2026-11-23)
    keep(selected, keptNow()); [shares, drawings, zooms].forEach(function (all) { while (all.length <= tabs.length) all.push(all == zooms ? 100 : all == shares ? 0 : null); });
    tabs.push({ title: '', gen: ++tabGen }); selected = perlTab = tabs.length - 1; shownGen = tabs[selected].gen; tabsView.needsDisplay = true;
    layersClear(); pageScrollTabbed(); drawnLines = []; unlaid(); page.string = $(''); listed([]); bar.stringValue = $(''); current = ''; pageShown = false; pieces();
}
function reopenTab() { if (takes() && tabs.length < 32) { reopening = true; shares[selected] = shareNow(); sent('tab reopen'); } }    // Cmd-Shift-T: lzrprf keeps the closed tabs, and says the tabs again

// The window's own three dots at the left of the strip: close, minimise, full screen. Then the
// tabs side by side, each at most 260 points wide, all shrinking to share the strip when there are
// many; the + after the last. A tab is a soft trapezoid: the chosen one is outlined by the beam and
// opens into the bar's row under it, the others are a faint line.
var TABS_X = 84;
function tabWide() { return Math.max(1, Math.min(260, Math.floor((tabsView.frame.size.width - TABS_X - 48) / tabs.length))); }
function closable(wide, on) { return wide - 2 >= 64 || (on && wide - 2 >= 40); }

function dotAt(at) {    // which of the three dots is under a point of the strip, or -1
    for (var k = 0; k < 3; k++) if (Math.abs(at.x - (22 + k * 20)) <= 8 && Math.abs(at.y - tabsView.frame.size.height / 2) <= 8) return k;
    return -1;
}

function tabShape(x, w, high, closed) {
    var top = high - 7, s = 11, p = $.NSBezierPath.bezierPath;
    p.moveToPoint($.NSMakePoint(x - 5, 0));
    p.curveToPointControlPoint1ControlPoint2($.NSMakePoint(x + s, top), $.NSMakePoint(x + s * 0.5, 0), $.NSMakePoint(x + s * 0.3, top));
    p.lineToPoint($.NSMakePoint(x + w - s, top));
    p.curveToPointControlPoint1ControlPoint2($.NSMakePoint(x + w + 5, 0), $.NSMakePoint(x + w - s * 0.3, top), $.NSMakePoint(x + w - s * 0.5, 0));
    if (closed) p.closePath;
    return p;
}

function crossed(cx, cy, r) {
    var cross = $.NSBezierPath.bezierPath;
    cross.moveToPoint($.NSMakePoint(cx - r, cy - r)); cross.lineToPoint($.NSMakePoint(cx + r, cy + r));
    cross.moveToPoint($.NSMakePoint(cx - r, cy + r)); cross.lineToPoint($.NSMakePoint(cx + r, cy - r));
    return cross;
}

function plussed(cx, cy, r) {
    var plus = $.NSBezierPath.bezierPath;
    plus.moveToPoint($.NSMakePoint(cx - r, cy)); plus.lineToPoint($.NSMakePoint(cx + r, cy));
    plus.moveToPoint($.NSMakePoint(cx, cy - r)); plus.lineToPoint($.NSMakePoint(cx, cy + r));
    return plus;
}

function paintTabs() {
    var size = tabsView.frame.size, wide = tabWide(), high = size.height, middle = (high - 7) / 2 + 1, chosenAt = tabLeft(selected, wide);
    for (var k = 0; k < 3; k++) {
        var dot = $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(16 + k * 20, high / 2 - 6, 12, 12));
        (hover.dot == k ? ICON : $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.42, 0.45, 0.48, 1)).setFill;
        dot.fill;
        if (hover.dot >= 0) stroked(k == 0 ? crossed(22 + k * 20, high / 2, 2.6) : k == 1 ? (function () { var p = $.NSBezierPath.bezierPath; p.moveToPoint($.NSMakePoint(39, high / 2)); p.lineToPoint($.NSMakePoint(45, high / 2)); return p; })() : plussed(62, high / 2, 3), DARK, 1.3);
    }
    var seam = $.NSBezierPath.bezierPath;
    seam.moveToPoint($.NSMakePoint(0, 0.5)); seam.lineToPoint($.NSMakePoint(chosenAt - 5, 0.5));
    seam.moveToPoint($.NSMakePoint(chosenAt + wide + 1, 0.5)); seam.lineToPoint($.NSMakePoint(size.width, 0.5));
    stroked(seam, LINE, 1);
    var order = tabs.map(function (tab, i) { return i; });
    if (drag) { order.splice(drag.tab, 1); order.push(drag.tab); }    // the tab held is drawn last, over the others
    order.forEach(function (i) {
        var tab = tabs[i], x = tabLeft(i, wide) + 2, w = wide - 4, on = i == selected, hot = drag ? i == drag.tab && !on : i == hover.tab && !on;
        if (drag && drag.out && i == drag.tab) {    // pulled away: drawn as the small window it becomes, a few points lower
            var card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(x, 2, w, high - 12), 6, 6), rule = $.NSBezierPath.bezierPath;
            FILL.setFill;
            card.fill;
            stroked(card, GREEN, 1.3, GREEN, 7);
            rule.moveToPoint($.NSMakePoint(x + 1, high - 18)); rule.lineToPoint($.NSMakePoint(x + w - 1, high - 18));
            stroked(rule, EDGE, 1);
            if (w >= 40) $(tab.title || 'New Tab').drawInRectWithAttributes($.NSMakeRect(x + 10, 5, w - 20, 16), inked(sans(12), WHITE, true));
            return;
        }
        if (on || hot) {
            var body = tabShape(x, w, high, true);
            (on ? FILL : $.NSColor.colorWithWhiteAlpha(1, 0.025)).setFill;
            body.fill;
            if (on) glass(body, true);
        }
        stroked(tabShape(x, w, high, false), on ? GREEN : hot ? EDGE : LINE, on ? 1.3 : 1, on ? GREEN : null, 7);
        if (w < 40) return;
        var closer = closable(wide, on);
        $(tab.title || 'New Tab').drawInRectWithAttributes($.NSMakeRect(x + 18, middle - 9, w - 18 - (closer ? 34 : 12), 18), inked(sans(13, on), on ? WHITE : hot ? ICON : GREY, true));
        if (closer) stroked(crossed(x + w - 20, middle, 4.2), on ? ICON : GREY, 1.4);
    });
    if (tabs.length < 32) {
        var lit = takes() && hover.tab == tabs.length;
        stroked(plussed(TABS_X + tabs.length * wide + 20, middle, 7), takes() ? (lit ? WHITE : ICON) : GREY, 1.6, lit ? GREEN : null, 8);
    }
}

function tabAt(event) {    // the tab under the pointer, the number of tabs for the +, or -1; and whether it is over the tab's x
    var at = pointIn(tabsView, event), wide = tabWide(), x = at.x - TABS_X, i = Math.floor(x / wide);
    if (x >= 0 && i < tabs.length) return [i, at.x >= TABS_X + (i + 1) * wide - 34 && closable(wide, i == selected)];
    var px = TABS_X + tabs.length * wide + 6;
    return [at.x >= px && at.x <= px + 30 && tabs.length < 32 ? tabs.length : -1, false];
}

function tabClicked(event) {
    if (firstAgain(event)) return; secureHidden();    // the band of the title bar: a press done once already (28-window1-tabs.pl)
    var dot = dotAt(pointIn(tabsView, event));
    if (dot == 0) return win.performClose($());
    if (dot == 1) return win.performMiniaturize($());
    if (dot == 2) return win.toggleFullScreen($());
    var hit = tabAt(event);
    if (hit[0] < 0) return windowHeld(event);    // the strip is the window's title bar
    if (hit[0] == tabs.length) return newTab();
    if (hit[1]) return tabSaid('tab close ' + hit[0], hit[0]);
    tabHeld(hit[0]);
}

// The whole top of the window moves it: the frame, the strip of tabs beside the tabs, the bar's row
// beside its buttons and its pill, the bookmarks bar beside its bookmarks. Pressed there and dragged,
// the window follows; pressed twice, it zooms, as a title bar does. Only here: the views of the top say
// no to macOS moving the window on its own (mouseDownCanMoveWindow), so a press on a tab moves the tab
// alone (HC-0856; the tabs themselves, in 28-window1-tabs.pl).
function windowHeld(event) { return event.clickCount == 2 ? win.performZoom($()) : win.performWindowDragWithEvent(event); }

// The bar's row: back, forward and reload at its left, then the bar, a pill of dark glass with the
// lock at its start and the star at its end; a cyan beam glows along the pill's lower edge, and
// all round it while the bar is typed into. The pill is a larger place to click than the bar looks:
// a click on it that is no button puts the caret into the bar, at its start when left of it and at
// its end otherwise. The rest of the row moves the window (windowHeld).
function typing() { var editor = bar.currentEditor; return !!editor && !editor.isNil(); }

function navAt(at) { for (var k = 0; k < 3; k++) if (Math.abs(at.x - (28 + k * 40)) <= 17 && Math.abs(at.y - BAR_ROW / 2) <= 16) return k; return -1; }
function lockAt(at) { return at.x >= PILL.origin.x + 6 && at.x <= PILL.origin.x + 36 && at.y >= PILL.origin.y && at.y <= PILL.origin.y + PILL.size.height; }
function navOn(k) { return k == 0 && listing == 'log' ? !modalOpen : takes() && (k == 0 ? navState[0] || !!listing : !!navState[k]); }

function arrowed(cx, cy, way) {    // a line arrow, pointing left (-1) or right (1)
    var p = $.NSBezierPath.bezierPath, tip = cx + 8 * way;
    p.moveToPoint($.NSMakePoint(cx - 8 * way, cy)); p.lineToPoint($.NSMakePoint(tip, cy));
    p.moveToPoint($.NSMakePoint(tip - 6.5 * way, cy + 6.5)); p.lineToPoint($.NSMakePoint(tip, cy)); p.lineToPoint($.NSMakePoint(tip - 6.5 * way, cy - 6.5));
    return p;
}

function reloaded(cx, cy) {    // a circle open at its upper right, its head turning clockwise
    var p = $.NSBezierPath.bezierPath, r = 8, start = 62, a = start * Math.PI / 180, tip = $.NSMakePoint(cx + r * Math.cos(a), cy + r * Math.sin(a));
    p.appendBezierPathWithArcWithCenterRadiusStartAngleEndAngleClockwise($.NSMakePoint(cx, cy), r, start, start + 290, false);
    var ux = -Math.sin(a), uy = Math.cos(a);    // back along the turn from the head, which turns clockwise
    [0.65, -0.65].forEach(function (turn) {
        var bx = ux * Math.cos(turn) - uy * Math.sin(turn), by = ux * Math.sin(turn) + uy * Math.cos(turn);
        p.moveToPoint(tip); p.lineToPoint($.NSMakePoint(tip.x + 6 * bx, tip.y + 6 * by));
    });
    return p;
}

function locked(cx, cy) {
    var p = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(cx - 6, cy - 7, 12, 9.5), 2, 2);
    p.moveToPoint($.NSMakePoint(cx - 3.8, cy + 2.5));
    p.lineToPoint($.NSMakePoint(cx - 3.8, cy + 4.5));
    p.appendBezierPathWithArcWithCenterRadiusStartAngleEndAngleClockwise($.NSMakePoint(cx, cy + 4.5), 3.8, 180, 0, true);
    p.lineToPoint($.NSMakePoint(cx + 3.8, cy + 2.5));
    p.moveToPoint($.NSMakePoint(cx, cy - 3.6)); p.lineToPoint($.NSMakePoint(cx, cy - 1.6));
    return p;
}

function paintBelt() {
    var size = belt.frame.size, on = typing(), cy = size.height / 2, pill = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(PILL, 18, 18);
    [arrowed(28, cy, -1), arrowed(68, cy, 1), reloaded(108, cy)].forEach(function (icon, k) {
        var can = navOn(k), hot = can && hover.nav == k;
        stroked(icon, hot ? WHITE : can ? ICON : EDGE, 1.6, hot ? GREEN : null, 8);
    });
    FILL.setFill;
    pill.fill;
    stroked(pill, on ? DIM : bar.enabled ? EDGE : LINE, 1, on ? GREEN : null, 4);
    if (true) {    // the beam along the lower edge, brightest in its middle, fading at both ends; longer while the bar is typed into
        var from = PILL.origin.x + PILL.size.width * (on ? 0.06 : 0.3), to = PILL.origin.x + PILL.size.width - 18, mid = (from + to) / 2, y = PILL.origin.y - 0.2, clear = tint(0);
        var core = $.NSBezierPath.bezierPath;    // one glow under the middle, then the line itself as two smooth gradients meeting there
        core.moveToPoint($.NSMakePoint(from + (to - from) * 0.25, y + 0.7)); core.lineToPoint($.NSMakePoint(to - (to - from) * 0.25, y + 0.7));
        stroked(core, FAINT, 1, GREEN, 9);
        $.NSGradient.alloc.initWithStartingColorEndingColor(clear, GREEN).drawInRectAngle($.NSMakeRect(from, y, mid - from, 1.4), 0);
        $.NSGradient.alloc.initWithStartingColorEndingColor(GREEN, clear).drawInRectAngle($.NSMakeRect(mid, y, to - mid, 1.4), 0);
    }
    if (loadingAt) {    // lzrprf works: the thin line along the bar's lower edge, as far as it has grown
        var grown = $.NSBezierPath.bezierPath, left = PILL.origin.x + 18;
        grown.moveToPoint($.NSMakePoint(left, PILL.origin.y + 1.5)); grown.lineToPoint($.NSMakePoint(left + (PILL.size.width - 36) * loadingShare(), PILL.origin.y + 1.5));
        stroked(grown, WHITE, 2, GREEN, 6);
    }
    var lockLit = hover.lock || securePinned;
    stroked(locked(PILL.origin.x + 21, cy), lockLit ? GREEN : ICON, 1.4, lockLit ? GREEN : null, 6);
    if (INCOGNITO) {    // "Incognito", with its mask, between the lock and the address
        stroked(masked(PILL.origin.x + 52, cy, 0.95), GREEN, 1.2, GREEN, 5);
        $('Incognito').drawAtPointWithAttributes($.NSMakePoint(PILL.origin.x + 66, cy - 8), inked(sans(12, true), GREEN));
    }
    $.NSColor.colorWithWhiteAlpha(1, 0.06).setStroke;
    $.NSBezierPath.strokeLineFromPointToPoint($.NSMakePoint(0, 0.5), $.NSMakePoint(size.width, 0.5));
}

function beltClicked(event) {
    var at = pointIn(belt, event), nav = navAt(at);
    if (nav >= 0) { secureHidden(); return navPressed(nav); }
    if (lockAt(at)) return secureToggled();
    secureHidden();
    if (!pillHit(at)) return windowHeld(event);    // beside the pill, the few points around it that take its press (pillReach) and the buttons, the row moves the window
    if (!bar.enabled || barSelectsAll(bar)) return;    // the first press beside the field selects the whole address too (barSelectsAll, 28-window1-tabs.pl)
    win.makeFirstResponder(bar);
    var editor = bar.currentEditor;
    if (editor && !editor.isNil()) editor.selectedRange = $.NSMakeRange(at.x < bar.frame.origin.x ? 0 : bar.stringValue.length, 0);
    belt.needsDisplay = true;
}

function navPressed(k) {
    if (!navOn(k)) return;
    if (k == 0 && listing == 'log') return logClosed();
    if (k == 0 && listing) { listing = null; return place(); }    // back from the bookmarks or the tabs page to what the tab shows
    reloadPlace = k == 2 && sheet && canvas && scroll.documentView.isEqual(canvas) ? { address: current, tab: selected, y: Math.round(canvas.visibleRect.origin.y), last: null, until: Date.now() + RELOAD_PLACE_MS } : null; sent('nav ' + ['back', 'forward', 'reload'][k]);    // a page loaded again is shown where it was read (reloadPlaced, 28-window-pointer.pl)
}

// The cogwheel: a thin line gear of eight teeth around a ring, light grey, with the beam's glow under
// the pointer. Its menu.
function paintCog() {
    var size = cog.frame.size, cx = size.width / 2, cy = size.height / 2, outer = 10, inner = 7.6, path = $.NSBezierPath.bezierPath, lit = takes();
    for (var k = 0; k < 8; k++) {
        var mid = k * Math.PI / 4, half = 0.2, slope = 0.12;
        [[inner, mid - half - slope], [outer, mid - half], [outer, mid + half], [inner, mid + half + slope]].forEach(function (one, j) {
            var point = $.NSMakePoint(cx + one[0] * Math.cos(one[1]), cy + one[0] * Math.sin(one[1]));
            if (k == 0 && j == 0) path.moveToPoint(point); else path.lineToPoint(point);
        });
    }
    path.closePath;
    path.appendBezierPathWithOvalInRect($.NSMakeRect(cx - 3.2, cy - 3.2, 6.4, 6.4));
    stroked(path, hover.cog && lit ? WHITE : lit ? ICON : GREY, 1.4, hover.cog && lit ? GREEN : null, 8);
}

// The cogwheel's menu: a panel of the window's own glass under the cogwheel, its right edge on the
// cogwheel's, so it opens inside the window and never over its border; a window too low for it
// has it rise over the bar, still inside. Each item has the keys that do it too, as in Chrome. A
// press outside it closes it and reaches nothing under it, as a menu's does.
var cogBox = null, cogCatch = null, cogOpen = false, cogMode = 'cog', COG_ROW = 32, COG_PAD = 8, COG_ROW_LEAST = 22, cogRow = 32, cogScroll = 0, cogScrollMost = 0;    // cogRow: the rows' height for this opening, COG_ROW, or less down to COG_ROW_LEAST in a window too low for the menu, so that every row is inside the window and pressed where it is drawn    // cogMode: the cogwheel's menu ("cog"), or the Profiles list ("profiles"), which is drawn and pressed the same way
// Each item: its words, its keys or what it says on the right, whether it is on now, what it does, why an incognito window
// does not do it, and its icon: a line icon in the item's grey, and in the beam's blue with its glow while the item is on.
// A toggle's words say what pressing it does now: the bar and the log are shown and hidden by the same
// press (the menu bar's item is retitled when lzrprf says "marksbar"), and pictures from other sites
// are blocked and allowed by the same press, a row shown only once lzrprf says "pictures". Bookmarks and Show All Tabs
// open their page either way, so their words stay.
function barToggleWords(on, menu) { return (on ? 'Hide' : 'Show') + (menu ? ' Bookmarks Bar' : ' bookmarks bar'); }
function logToggleWords(open) { return (open ? 'Hide' : 'Show') + ' log'; }
function picturesToggleWords(blocked) { return (blocked ? 'Allow' : 'Block') + ' pictures from other sites'; }
var picturesBlocked = false, picturesRow = false;    // what lzrprf last said: "pictures block" or "pictures allow"; allowed until it says. The row is shown only once lzrprf says it, which it does when it fetches by that choice
var barMenuItem = null;
function cogItems() {
    if (cogMode == 'profiles') return profileItems();
    if (cogMode == 'sso') return ssoItems();
    return [['New Incognito Window', '⇧⌘N', INCOGNITO, function () { say('incognito'); }, '', 'mask'],
        ['Profiles...', profileOf('this') ? profileOf('this').name : '', false, INCOGNITO || !profilesOn ? function () { wordsTold(PROFILE_TIP); } : function () { facesOpened(false); }, INCOGNITO || !profilesOn ? PROFILE_TIP : '', 'face'],
        [barToggleWords(marksOn, false), '⇧⌘B', marksOn, function () { if (takes()) sent('menu bookmarks-bar'); }, '', 'bar'],
        picturesRow ? [picturesToggleWords(picturesBlocked), '', picturesBlocked, function () { if (takes()) sent('menu pictures'); }, '', 'picture'] : null,
        ['Bookmarks', '⌥⌘B', listing == 'marks', function () { if (takes()) listOpened('marks'); }, '', 'ribbon'],
        ['Import bookmarks...', '', modalKind == 'wizard' && modalOpen, INCOGNITO ? function () { wordsTold(UNKEPT_TIP); } : importOpened, INCOGNITO ? UNKEPT_TIP : '', 'tray'],
        ['Search engine...', '', false, function () { if (takes()) engineAsked(); }, '', 'lens'],
        ['LZRDFNDR scripts...', '', listing == 'scripts', function () { if (takes()) sent('scripts list'); }, '', 'brace'],
        ['Filters...', '', listing == 'filters', function () { if (takes()) sent('filters list'); }, '', 'funnel'],
        ['Clear browsing history', '⇧⌘⌫', false, clearing, '', 'bin'],
        ['Make current page the home page', '', false, function () { if (takes()) sent('menu home'); }, '', 'house'],
        [logToggleWords(listing == 'log'), '', listing == 'log', function () { logPressed(); }, '', 'page'],
        ['Check for updates', checkedWords(), false, INCOGNITO ? function () { wordsTold(UNKEPT_TIP); } : function () { if (takes()) say('update-check'); }, INCOGNITO ? UNKEPT_TIP : '', 'turn'], ['Add or remove LZR modules...', '', modalOpen && modalKind == 'modules', INCOGNITO ? function () { wordsTold(UNKEPT_TIP); } : modulesOpened, INCOGNITO ? UNKEPT_TIP : '', 'plus'],
        [licenceMonth ? 'Support member licence' : 'Enter licence code...', licenceMonth ? 'since ' + licenceMonth : '', modalOpen && modalKind == 'licence', INCOGNITO ? function () { wordsTold(SUPPORT_TIP); } : licenceOpened, INCOGNITO ? SUPPORT_TIP : '', 'key'],
        ['Support request...', supportTicket != '-' ? 'answer kept' : '', modalOpen && modalKind == 'support', supportWhy() ? function () { wordsTold(supportWhy()); } : supportOpened, supportWhy(), 'bubble']].filter(function (one) { return one; });
}

// When lzrprf last looked for a newer release ("checked EPOCH RESULT", "checked never", or "checked none" without a
// release file), shown on the right of Check for updates: the time today, else the day.
var lastChecked = 'never';
function checkedTold(rest) { lastChecked = rest; if (cogOpen) cogPlaced(); }
function checkedWords() {
    var m = /^([0-9]+) (same|newer|failed)/.exec(lastChecked);
    if (!m) return lastChecked == 'none' ? '' : 'never checked';
    var at = new Date(+m[1] * 1000), now = new Date(), two = function (n) { return (n < 10 ? '0' : '') + n; };
    var when = at.toDateString() == now.toDateString() ? two(at.getHours()) + ':' + two(at.getMinutes()) : at.getDate() + ' ' + ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][at.getMonth()];
    return (m[2] == 'newer' ? 'newer found, ' : m[2] == 'failed' ? 'failed, ' : 'checked ') + when;
}

// The menu's line icons, drawn in a box of 14 points around (cx, cy).
function cogIcon(name, cx, cy, colour, on) {
    var p = $.NSBezierPath.bezierPath, P = function (x, y) { return $.NSMakePoint(cx + x, cy + y); }, line = function (a, b, c, d) { p.moveToPoint(P(a, b)); p.lineToPoint(P(c, d)); };
    var oval = function (x, y, w, h) { p.appendBezierPathWithOvalInRect($.NSMakeRect(cx + x, cy + y, w, h)); }, box = function (x, y, w, h, rad) { p.appendBezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(cx + x, cy + y, w, h), rad, rad); };
    if (name == 'mask') { line(-7, 1, 7, 1); box(-4, 1, 8, 4.5, 1.5); oval(-6, -6, 4.6, 4.6); oval(1.4, -6, 4.6, 4.6); line(-1.4, -3.7, 1.4, -3.7); }
    else if (name == 'bar') { box(-7, -5.5, 14, 11, 2); line(-7, 2, 7, 2); }
    else if (name == 'picture') { box(-7, -5.5, 14, 11, 2); p.moveToPoint(P(-5, -3.5)); p.lineToPoint(P(-1, 1)); p.lineToPoint(P(1.5, -1.5)); p.lineToPoint(P(3, 0)); p.lineToPoint(P(5, -3.5)); oval(2, 1.5, 2.5, 2.5); }
    else if (name == 'ribbon') { p.moveToPoint(P(-4.5, 7)); p.lineToPoint(P(4.5, 7)); p.lineToPoint(P(4.5, -7)); p.lineToPoint(P(0, -3)); p.lineToPoint(P(-4.5, -7)); p.closePath; }
    else if (name == 'tray') { line(0, 7, 0, -2); line(-3.5, 1.5, 0, -2); line(3.5, 1.5, 0, -2); p.moveToPoint(P(-7, -2)); p.lineToPoint(P(-7, -6.5)); p.lineToPoint(P(7, -6.5)); p.lineToPoint(P(7, -2)); }
    else if (name == 'lens') { oval(-6.5, -1.5, 8.5, 8.5); line(0.8, -0.8, 6.5, -6.5); }
    else if (name == 'bin') { line(-6.5, 4.5, 6.5, 4.5); line(-2, 6.5, 2, 6.5); p.moveToPoint(P(-5, 4.5)); p.lineToPoint(P(-4, -6.5)); p.lineToPoint(P(4, -6.5)); p.lineToPoint(P(5, 4.5)); line(-1.5, 2, -1.5, -4.5); line(1.5, 2, 1.5, -4.5); }
    else if (name == 'house') { p.moveToPoint(P(-7, 0)); p.lineToPoint(P(0, 6.5)); p.lineToPoint(P(7, 0)); p.moveToPoint(P(-5, 1.5)); p.lineToPoint(P(-5, -6.5)); p.lineToPoint(P(5, -6.5)); p.lineToPoint(P(5, 1.5)); }
    else if (name == 'page') { p.moveToPoint(P(-5, 7)); p.lineToPoint(P(2, 7)); p.lineToPoint(P(5, 4)); p.lineToPoint(P(5, -7)); p.lineToPoint(P(-5, -7)); p.closePath; line(-2.5, 2, 2.5, 2); line(-2.5, -1, 2.5, -1); line(-2.5, -4, 1, -4); }
    else if (name == 'turn') { p.appendBezierPathWithArcWithCenterRadiusStartAngleEndAngleClockwise(P(0, 0), 6, 60, 330, false); line(6 * Math.cos(-30 * Math.PI / 180), 6 * Math.sin(-30 * Math.PI / 180), 6 * Math.cos(-30 * Math.PI / 180) + 2.6, -3 + 3.4); line(6 * Math.cos(-30 * Math.PI / 180), 6 * Math.sin(-30 * Math.PI / 180), 6 * Math.cos(-30 * Math.PI / 180) - 3.4, -3 + 0.6); }
    else if (name == 'key') { oval(-7, -1, 7, 7); line(0, 2.5, 7, 2.5); line(4, 2.5, 4, -0.5); line(6.5, 2.5, 6.5, 0); }
    else if (name == 'face') { oval(-3.5, 1, 7, 7); p.moveToPoint(P(-7, -7)); p.curveToPointControlPoint1ControlPoint2(P(7, -7), P(-6, 0), P(6, 0)); }
    else if (name == 'plus') { line(-6, 0, 6, 0); line(0, -6, 0, 6); }
    else if (name == 'brace') { p.moveToPoint(P(-2, 7)); p.curveToPointControlPoint1ControlPoint2(P(-4, 0), P(-5, 6), P(-3, 1)); p.lineToPoint(P(-6, 0)); p.moveToPoint(P(-4, 0)); p.curveToPointControlPoint1ControlPoint2(P(-2, -7), P(-3, -1), P(-5, -6)); p.moveToPoint(P(2, 7)); p.curveToPointControlPoint1ControlPoint2(P(4, 0), P(5, 6), P(3, 1)); p.lineToPoint(P(6, 0)); p.moveToPoint(P(4, 0)); p.curveToPointControlPoint1ControlPoint2(P(2, -7), P(3, -1), P(5, -6)); }    // [C26] Script permissions: a pair of braces
    else if (name == 'funnel') { p.moveToPoint(P(-7, 6)); p.lineToPoint(P(7, 6)); p.lineToPoint(P(1.5, -0.5)); p.lineToPoint(P(1.5, -6.5)); p.lineToPoint(P(-1.5, -4.5)); p.lineToPoint(P(-1.5, -0.5)); p.closePath; }
    else if (name == 'pen') { p.moveToPoint(P(-6, -6)); p.lineToPoint(P(-6, -3)); p.lineToPoint(P(4, 7)); p.lineToPoint(P(7, 4)); p.lineToPoint(P(-3, -6)); p.closePath; }
    else if (name == 'bubble') { box(-7, -3, 14, 10, 3); p.moveToPoint(P(-3, -3)); p.lineToPoint(P(-5, -7)); p.lineToPoint(P(0, -3)); }
    stroked(p, colour, 1.3, on ? GREEN : null, on ? 7 : 0);
}

function cogClicked() {
    if (cogOpen) return cogHidden();
    if (!takes()) return;
    cogMode = 'cog';
    secureHidden();
    techHidden();
    suggestHidden();
    cogOpen = true;
    hover.cogRow = -1;
    cogCatch.hidden = false;
    cogBox.hidden = false;
    cogPlaced();
}

function cogPlaced() {
    if (!cogOpen || !cogBox) return;
    var items = cogItems(), w = 0, all = root.frame.size, anchor = (cogMode == 'profiles' || cogMode == 'sso') && faces && !faces.hidden ? faces : cog, at = anchor.convertRectToView(anchor.bounds, root);    // the Profiles list opens under its own icon
    items.forEach(function (one) { w = Math.max(w, $(one[0]).sizeWithAttributes(inked(sans(13), WHITE)).width + (one[1] ? $(one[1]).sizeWithAttributes(inked(sans(12), GREY)).width + 28 : 0)); });
    w = Math.ceil(Math.max(270, w + 56));
    var fit = function (room) { return Math.min(COG_ROW, Math.floor((room - 2 * COG_PAD) / Math.max(1, items.length))); };
    cogRow = fit(at.origin.y - 6 - 8);    // under its icon, down to 8 points above the window's bottom
    if (cogRow < COG_ROW_LEAST) cogRow = Math.max(COG_ROW_LEAST, fit(all.height - 16));    // no room under the icon at the least height: the menu rises over the bar, inside the window
    var whole = items.length * cogRow + 2 * COG_PAD, h = Math.min(whole, Math.max(2 * COG_PAD + cogRow, all.height - 16)), x = Math.max(8, Math.min(all.width - w - 8, at.origin.x + at.size.width - w)), y = Math.max(8, Math.min(all.height - 8 - h, at.origin.y - 6 - h));
    cogScrollMost = whole - h;    // rows that do not fit at the least height, as a long Profiles list in a low window: the box scrolls by the wheel and the keys
    cogScroll = Math.max(0, Math.min(cogScroll, cogScrollMost));
    cogCatch.frame = $.NSMakeRect(0, 0, all.width, all.height);
    cogBox.frame = $.NSMakeRect(x, y, w, h);
    cogBox.needsDisplay = true;
}

function cogHidden() {
    if (!cogBox || !cogOpen) return;
    cogOpen = false;
    cogScroll = 0;
    cogMode = 'cog';
    hover.cogRow = -1;
    cogBox.hidden = true;
    cogCatch.hidden = true;
    redrawn();
}

function cogRowAt(event) {
    var at = pointIn(cogBox, event), size = cogBox.frame.size, i = Math.floor((size.height - COG_PAD + cogScroll - at.y) / cogRow);
    var edge = cogScrollMost > 0 ? COG_PAD / 2 : 0;    // a box that scrolls draws its rows within its edge alone: a press in the edge is not a half-hidden row's
    return at.x >= 0 && at.x <= size.width && at.y >= edge && at.y <= size.height - edge && i >= 0 && i < cogItems().length ? i : -1;
}

function cogScrolled(by, event) {    // the box moved by this many points, down the list when more than 0; the row under the pointer is lit again
    var was = cogScroll;
    cogScroll = Math.max(0, Math.min(cogScrollMost, cogScroll + by));
    if (cogScroll == was) return;
    if (event) hover.cogRow = cogRowAt(event);
    cogBox.needsDisplay = true;
}

function cogWheeled(event) { cogScrolled(-event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : cogRow), event); }

function cogKeyed(code) {    // whether a key pressed anywhere in the window is the open box's: while it scrolls, the arrows by a row, Page Up and Page Down by what is seen, Home and End to the ends, Escape closes it; every other key, and every key while it fits or is shut, goes on where it was going
    if (!cogOpen || cogScrollMost <= 0) return false;
    if (code == 53) { cogHidden(); return true; }
    var seen = cogBox.frame.size.height - 2 * COG_PAD - cogRow, moves = { 125: cogRow, 126: -cogRow, 121: seen, 116: -seen, 119: cogScrollMost, 115: -cogScrollMost };
    if (!(code in moves)) return false;
    hover.cogRow = -1;
    cogScrolled(moves[code], null);
    return true;
}

function cogComposing() {    // a word being composed in a text field by an input method (marked text): its keys are the input method's, never the box's
    var typing = typeof win != 'undefined' && win ? win.firstResponder : null;
    return !!typing && !typing.isNil() && !!typing.respondsToSelector('hasMarkedText') && !!typing.hasMarkedText;
}

function cogMenuClicked(event) {
    var i = cogRowAt(event), at = pointIn(cogBox, event), h = cogBox.frame.size.height;
    if (i < 0 && cogScrollMost > 0 && at.y > h - COG_PAD / 2) return cogScrolled(-cogRow, event);    // a press on the top chevron shows one row more above
    if (i < 0 && cogScrollMost > 0 && at.y < COG_PAD / 2) return cogScrolled(cogRow, event);    // and on the bottom one, one row more below
    if (i < 0) return;
    var act = cogItems()[i][3];
    cogHidden();
    act();
}

function paintCogMenu() {
    var size = cogBox.frame.size, box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(0.5, 0.5, size.width - 1, size.height - 1), 12, 12);
    $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.035, 0.045, 0.055, 0.98).setFill;
    box.fill;
    glass(box, true);
    stroked(box, GREEN, 1.1);
    $.NSGraphicsContext.saveGraphicsState;
    if (cogScrollMost > 0) $.NSBezierPath.bezierPathWithRect($.NSMakeRect(0, COG_PAD / 2, size.width, size.height - COG_PAD)).addClip;    // a box that scrolls draws its rows within its edge alone
    cogItems().forEach(function (one, i) {
        var top = size.height - COG_PAD - (i + 1) * cogRow + cogScroll, mid = top + cogRow / 2, hot = i == hover.cogRow;
        if (top + cogRow < 0 || top > size.height) return;    // scrolled out of the box
        if (hot) {
            var pill = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(6, top + 2, size.width - 12, cogRow - 4), 8, 8);
            glass(pill, true);
            $.NSGraphicsContext.saveGraphicsState; glow(GREEN, 6); DIM.setStroke; pill.stroke; $.NSGraphicsContext.restoreGraphicsState;
        }
        cogIcon(one[5], 21, mid, one[2] ? GREEN : one[4] ? GREY : hot ? WHITE : ICON, !!one[2]);    // the item that is on now glows in the beam's blue
        $(one[0]).drawAtPointWithAttributes($.NSMakePoint(38, mid - 8.5), inked(sans(13), one[4] ? GREY : hot ? WHITE : one[2] && (cogMode == 'profiles' || cogMode == 'sso') ? GREEN : ICON));    // in the Profiles list, this window's profile is in the beam's blue    // an item an incognito window does not do is grey, its reason in its tooltip
        if (one[1]) { var keys = $(one[1]), kw = keys.sizeWithAttributes(inked(sans(12), GREY)).width; keys.drawAtPointWithAttributes($.NSMakePoint(size.width - 16 - kw, mid - 8), inked(sans(12), GREY)); }
    });
    $.NSGraphicsContext.restoreGraphicsState;
    [[cogScroll > 0, size.height - 3, 1], [cogScroll < cogScrollMost, 3, -1]].forEach(function (mark) {    // a small chevron at an edge with rows past it, pointing out of the box ("^" at the top, the view not flipped)
        if (!mark[0]) return;
        var p = $.NSBezierPath.bezierPath, cx = size.width / 2;
        p.moveToPoint($.NSMakePoint(cx - 5, mark[1] - 2 * mark[2])); p.lineToPoint($.NSMakePoint(cx, mark[1] + 1 * mark[2])); p.lineToPoint($.NSMakePoint(cx + 5, mark[1] - 2 * mark[2]));
        stroked(p, GREY, 1.3);
    });
}

function clearing() {
    if (!takes()) return;
    modal('Clear browsing history', 'Clear history empties the list of addresses each tab went to; the pages shown stay. Clear history and sessions also drops every page lzrprf keeps for a tab and every cookie of this window\'s sites. The log is cleared by its own button.',
        [['Cancel', closeModal], ['Clear history', function () { closeModal(); sent('menu clear-history'); }], ['Clear history and sessions', sessionsWarned]], 'small');
}

function sessionsWarned() {
    modal('Clear history and sessions?', 'This will require logging in again on all pages: the history, every page lzrprf keeps for a tab and every cookie of this window\'s sites are cleared. A provider you connected in the Profiles list keeps its sign-in (Remove it there). Proceed?',
        [['Cancel', closeModal], ['Proceed', function () { closeModal(); drawings = []; sent('menu clear-sessions'); }]], 'small');
}

// The support member licence: "Enter licence code" opens one field, and the code typed goes to lzrprf ("licence set
// CODE"), which checks it and keeps it, or says why not ("licence kept MONTH", "licence refused WORDS"). With a code
// kept, the item says since when the browser is a support member's, and the panel can remove it ("licence remove").
// An incognito window offers neither this nor a support request: both keep something.
var licenceField, supportScroll, supportText, supportTick, supportPreview;    // the views of the two panels, made with the window
var licenceMonth = '', licenceWaiting = false, SUPPORT_TIP = 'An incognito window writes nothing, so it keeps no licence code and sends no support request.';
function licenceTold(rest) {
    var at = rest.indexOf(' '), word = at < 0 ? rest : rest.slice(0, at), more = at < 0 ? '' : rest.slice(at + 1);
    if (word == 'kept') licenceMonth = more;
    else if (word == 'none' || word == 'off') licenceMonth = '';
    var open = modalOpen && modalKind == 'licence';
    if (word == 'refused' && open) { licenceWaiting = false; panelSub.stringValue = $(more); panelSub.textColor = YELLOW; buttons(licenceChoices()); }
    else if ((word == 'kept' || word == 'none') && open) { licenceWaiting = false; licenceShown(word == 'kept' ? 'The code is kept. ' : 'The code was removed. '); }
    if (cogOpen) cogPlaced();
}
function licenceChoices() {
    if (licenceMonth) return [['Close', closeModal], ['Remove code', licenceRemoved]];
    return [['Cancel', closeModal], ['Check and keep', licenceChecked]];
}
function licenceShown(before) {
    modal('Enter licence code', licenceMonth ? (before || '') + 'This browser is a support member\'s, since ' + licenceMonth + '. Your support requests carry the code, so they are answered first. The code is kept in ~/.lzrprf/licence; Remove code removes it and the file.'
        : (before || '') + 'Enter the support member licence code you got when you bought the browser. It is checked on this Mac, and kept in ~/.lzrprf/licence. Your support requests then carry it, so they are answered first.', licenceChoices(), 'licence');
    licenceField.hidden = !!licenceMonth;
    licenceField.stringValue = $('');
    if (!licenceMonth) win.makeFirstResponder(licenceField);
}
function licenceOpened() { if (takes()) licenceShown(''); }
function licenceChecked() {
    if (licenceWaiting) return;
    var typed = licenceField.stringValue.js.replace(/\s+/g, ' ').trim();
    if (!typed) { panelSub.stringValue = $('Type or paste your licence code first.'); panelSub.textColor = YELLOW; return; }
    if (!/^[0-9A-Za-z \-]{1,200}$/.test(typed)) { panelSub.stringValue = $('That is not a licence code: a code has 120 letters and digits, in groups of 5.'); panelSub.textColor = YELLOW; return; }
    licenceWaiting = true;
    panelSub.stringValue = $('Checking the code on this Mac.');
    panelSub.textColor = WHITE;
    buttons([['Cancel', closeModal]]);
    say('licence set ' + typed);
}
function licenceRemoved() { if (licenceWaiting) return; licenceWaiting = true; buttons([['Close', closeModal]]); say('licence remove'); }

// Profiles: the icon left of the cogwheel, and the list it opens, drawn as the cogwheel's menu is. lzrprf tells the
// list ("profiles begin", "profiles one ID this|open|shut NAME" for each, "profiles end") at the start and after each
// change, and again when the icon is pressed ("profile list"), so which profile has a window open is said as it is
// now. This window's profile is highlighted and does nothing when pressed; another opens in a new window ("profile
// open ID"). "New profile..." takes a name in one field ("profile new<TAB>NAME"); "Rename or remove..." turns each
// row into a press that opens the same field for that profile, with Rename ("profile rename<TAB>ID<TAB>NAME") and,
// for a profile that is not the first and has no window open, Remove ("profile remove ID"), which lzrprf asks about
// once in the strip. lzrprf checks every word again and says why when it did nothing ("profiles refused WORDS").
// An incognito window is told no profile: it shows no icon, and the cogwheel's item only says why.
var profileField, profiles = [], profilesNext = null, profilesOn = false, profileManage = false, profileWaiting = false, profileEditing = null;
var PROFILES_MOST = 16, PROFILE_NAME = 32, PROFILE_TIP = 'An incognito window has no profile: it keeps nothing, and opens no profile.';    // DECLARED(lzrprf $PROFILES_MOST and $PROFILE_NAME)
function profileText(name) { return Array.from(String(name).replace(/[\x00-\x1f\x7f-\x9f\u00ad\u061c\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff\ufff9-\ufffb]/g, '')).slice(0, PROFILE_NAME).join(''); }    // a name as text to draw, never as anything else: lzrprf sends only plain names, and this takes out what is not one
function profileOf(state) { return profiles.filter(function (one) { return one.state == state; })[0]; }
function profilesTold(rest) {
    var at = rest.indexOf(' '), word = at < 0 ? rest : rest.slice(0, at), more = at < 0 ? '' : rest.slice(at + 1), was = profilesOn;
    if (word == 'begin') profilesNext = [];
    else if (word == 'one' && profilesNext) { var m = /^(first|[0-9a-f]{12}) (this|open|shut) (.+)$/.exec(more); if (m && profilesNext.length < PROFILES_MOST) profilesNext.push({ id: m[1], state: m[2], name: profileText(m[3]) }); }
    else if (word == 'end' && profilesNext) {
        profiles = profilesNext;
        profilesNext = null;
        profilesOn = !INCOGNITO && profiles.length > 0;
        if (faces) { faces.hidden = !profilesOn; faces.toolTip = $(profileOf('this') ? 'Profiles. This window is ' + profileOf('this').name + '.' : 'Profiles'); }
        if (profileWaiting && modalOpen && modalKind == 'profile') { profileWaiting = false; closeModal(); }
        if (was != profilesOn) place();
    }
    else if (word == 'refused') { profileWaiting = false; if (modalOpen && modalKind == 'profile') { panelSub.stringValue = $(more); panelSub.textColor = YELLOW; buttons(profileChoices()); } }
    if (cogOpen) cogPlaced();
}
function profileItems() {    // the rows of the Profiles list, in the form of the cogwheel's items
    var rows = profiles.map(function (one) {
        var act = profileManage ? function () { profileNamed(one); } : one.state == 'this' ? function () { } : function () { if (takes()) sent('profile open ' + one.id); };
        return [one.name, one.state == 'this' ? 'this window' : one.state == 'open' ? 'open' : '', one.state == 'this', act, '', 'face'];
    });
    var full = profiles.length >= PROFILES_MOST ? 'There are ' + PROFILES_MOST + ' profiles, the most there may be. Remove one to make another.' : '';
    rows.push(['New profile...', '', false, full ? function () { wordsTold(full); } : function () { profileNamed(null); }, full, 'plus']);
    rows.push([profileManage ? 'Done' : 'Rename or remove...', '', profileManage, function () { profileManage = !profileManage; facesOpened(profileManage); }, '', 'pen']);
    if (!profileManage) rows.push(['Connect seamless SSO accounts...', '', false, function () { ssoOpened(); }, '', 'key']);
    return rows;
}

// Connected sign-ins, from the Profiles list: lzrprf tells them ("sso begin", "sso one KEY connected|connecting|none NAME"
// for each provider, "sso end") at the start, after each change and when the list is opened ("sso list"); in an
// incognito window or with Tor on it says only why there are none ("sso off WHY"). A provider not connected says
// Connect ("sso connect KEY"): lzrprf opens the provider's own sign-in page in a new tab, and the row says Connected
// once lzrprf saw the provider's session begin. A connected one says Remove ("sso remove KEY"), which lzrprf asks
// about once in the strip. The window holds no cookie and no value of one: only these names and states.
var ssoList = [], ssoNext = null, ssoOff = '', SSO_MOST = 8;
function ssoTold(rest) {
    var at = rest.indexOf(' '), word = at < 0 ? rest : rest.slice(0, at), more = at < 0 ? '' : rest.slice(at + 1);
    if (word == 'begin') ssoNext = [];
    else if (word == 'one' && ssoNext) { var m = /^([a-z]{1,16}) (connected|connecting|none) (.+)$/.exec(more); if (m && ssoNext.length < SSO_MOST) ssoNext.push({ key: m[1], state: m[2], name: profileText(m[3]) }); }
    else if (word == 'end' && ssoNext) { ssoList = ssoNext; ssoNext = null; ssoOff = ''; }
    else if (word == 'off') { ssoList = []; ssoOff = String(more).replace(/[\x00-\x1f\x7f-\x9f]/g, '').slice(0, 200); }
    if (cogOpen && cogMode == 'sso') cogPlaced();
}
function ssoItems() {    // the rows of the sign-ins, in the form of the cogwheel's items
    if (ssoOff) return [[ssoOff, '', false, function () { words.stringValue = $(ssoOff); }, ssoOff, 'key'], ['Back', '', false, function () { facesOpened(false); }, '', 'face']];
    var rows = ssoList.map(function (one) {
        var connected = one.state == 'connected';
        var act = connected ? function () { if (takes()) { cogHidden(); sent('sso remove ' + one.key); } } : function () { if (takes()) { cogHidden(); sent('sso connect ' + one.key); } };
        return [one.name, connected ? 'Connected: Remove' : one.state == 'connecting' ? 'Signing in: Connect' : 'Not connected: Connect', connected, act, '', 'key'];
    });
    rows.push(['Back', '', false, function () { facesOpened(false); }, '', 'face']);
    return rows;
}
function ssoOpened() {    // the sign-ins, open at once in place of the Profiles list; lzrprf's fresh list redraws it when it comes
    if (!takes()) return;
    secureHidden();
    techHidden();
    suggestHidden();
    cogMode = 'sso';
    cogOpen = true;
    cogCatch.hidden = false;
    cogBox.hidden = false;
    hover.cogRow = -1;
    cogPlaced();
    say('sso list');
}
function paintFaces() {    // the Profiles icon: a head and shoulders in a thin line, as the cogwheel is drawn
    var size = faces.frame.size, cx = size.width / 2, cy = size.height / 2, path = $.NSBezierPath.bezierPath, lit = takes(), over = hover.faces && lit;
    path.appendBezierPathWithOvalInRect($.NSMakeRect(cx - 4, cy + 0.5, 8, 8));
    path.moveToPoint($.NSMakePoint(cx - 8.5, cy - 9));
    path.curveToPointControlPoint1ControlPoint2($.NSMakePoint(cx + 8.5, cy - 9), $.NSMakePoint(cx - 7.5, cy - 0.5), $.NSMakePoint(cx + 7.5, cy - 0.5));
    stroked(path, over ? WHITE : lit ? ICON : GREY, 1.4, over ? GREEN : null, 8);
}
function facesClicked() {
    if (cogOpen && cogMode == 'profiles') return cogHidden();
    facesOpened(false);
}
function facesOpened(manage) {    // the Profiles list, open at once; lzrprf's fresh list redraws it when it comes
    if (!takes() || !profilesOn) return;
    if (cogOpen) cogHidden();
    secureHidden();
    techHidden();
    suggestHidden();
    cogMode = 'profiles';
    profileManage = !!manage;
    cogOpen = true;
    hover.cogRow = -1;
    cogCatch.hidden = false;
    cogBox.hidden = false;
    cogPlaced();
    say('profile list');
}
function profileChoices() {
    var one = profileEditing;
    if (!one) return [['Cancel', closeModal], ['Make and open', profileSaid]];
    return one.id == 'first' || one.state != 'shut' ? [['Cancel', closeModal], ['Rename', profileSaid]] : [['Cancel', closeModal], ['Remove...', profileRemoveSaid], ['Rename', profileSaid]];
}
function profileNamed(one) {    // the one field: a new profile's name (one null), or another name for this one
    if (!takes()) return;
    profileEditing = one;
    profileWaiting = false;
    var about = !one ? 'A profile is a browser of its own: its own bookmarks, history, log, home page and search, kept apart from every other profile. Type its name, at most ' + PROFILE_NAME + ' characters. It opens in a new window.'
        : 'Type a new name for ' + one.name + ', at most ' + PROFILE_NAME + ' characters.' + (one.id == 'first' ? ' The first profile is never removed: its folder also holds what belongs to the whole installation.' : one.state != 'shut' ? ' It has a window open, so it cannot be removed now.' : ' Remove deletes its bookmarks, history, log and all that is kept for it; lzrprf asks once more.');
    modal(one ? 'Rename or remove a profile' : 'New profile', about, profileChoices(), 'profile');
    profileField.stringValue = $(one ? one.name : '');
    win.makeFirstResponder(profileField);
}
function profileFit(typed) {    // the name as lzrprf takes it, or why not, in lzrprf's own words (sub profile_fit)
    if (/[\x00-\x1f\x7f-\x9f\u00ad\u061c\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff\ufff9-\ufffb]/.test(typed)) return { why: 'A profile name holds no control or format character.' };
    var name = typed.replace(/\s+/g, ' ').trim(), count = Array.from(name).length;
    if (!count) return { why: 'Type a name for the profile first.' };
    if (count > PROFILE_NAME) return { why: 'A profile name is at most ' + PROFILE_NAME + ' characters. That one has ' + count + '.' };
    return { name: name };
}
function profileSaid() {
    if (profileWaiting) return;
    var fit = profileFit(profileField.stringValue.js);
    if (fit.why) { panelSub.stringValue = $(fit.why); panelSub.textColor = YELLOW; return; }
    profileWaiting = true;
    panelSub.stringValue = $(profileEditing ? 'Renaming the profile.' : 'Making the profile.');
    panelSub.textColor = WHITE;
    buttons([['Cancel', closeModal]]);
    say(profileEditing ? 'profile rename\t' + profileEditing.id + '\t' + fit.name : 'profile new\t' + fit.name);
}
function profileRemoveSaid() { if (profileWaiting || !profileEditing) return; var id = profileEditing.id; closeModal(); sent('profile remove ' + id); }    // lzrprf says what is deleted, and asks once

// A support request: a box for your words, which says before Send exactly what is sent and where, and a box to tick
// for a picture of this window, off at first. The picture is the window's own drawing of itself, made into a
// picture here when the panel opens (windowPicture), never a capture of the screen, and it is shown small under the
// box while it is ticked. Send hands lzrprf the words and, when ticked, the picture, in base64 ("support send WORDS
// PICTURE|-"); lzrprf sends them to the one address the application names and says what came back ("support sent
// TICKET priority|plain none|accepted|refused", "support failed WORDS"). The reference and its key stay with lzrprf;
// "Read the answer" asks it to read the answer ("support read"), which comes as lines "support thread", "support
// message" and "support thread end".
var supportHost = '', supportRelease = '', supportOff = 'none', supportTicket = '-', supportWaiting = false, supportShot = null, supportThread = null, SUPPORT_PICTURE_MOST = 2 * 1024 * 1024, SUPPORT_TEXT_MOST = 4000;    // DECLARED(lzrprf $SUPPORT_PICTURE and $SUPPORT_TEXT)
function supportWhy() { return INCOGNITO || supportOff == 'incognito' ? SUPPORT_TIP : supportOff ? 'This application names no address for support requests.' : ''; }
function supportTold(rest) {
    var parts = rest.split(' '), open = modalOpen && modalKind == 'support';
    if (parts[0] == 'on') { supportHost = parts[1] || ''; supportRelease = parts[2] || ''; supportOff = ''; }
    else if (parts[0] == 'off') supportOff = parts[1] || 'none';
    else if (parts[0] == 'kept') supportTicket = /^[A-Za-z0-9_-]{22}$/.test(parts[1]) ? parts[1] : '-';
    else if (parts[0] == 'failed') supportWaiting = false;
    if (parts[0] == 'failed' && open) { supportWritten(); panelSub.stringValue = $(rest.slice(7)); panelSub.textColor = YELLOW; }
    else if (parts[0] == 'failed' && modalOpen && modalKind == 'big') { panelSub.stringValue = $(rest.slice(7)); panelSub.textColor = YELLOW; }
    else if (parts[0] == 'sent' && open) { supportWaiting = false; supportDone(parts[1], parts[2] == 'priority', parts[3]); }
    else if (parts[0] == 'thread' && parts[1] == 'end') { if (supportThread) supportRead(supportThread); supportThread = null; }
    else if (parts[0] == 'thread') supportThread = { status: parts[1], reason: decoded(parts[2] || ''), messages: [] };
    else if (parts[0] == 'message' && supportThread) supportThread.messages.push({ author: parts[1], at: parts[2], body: decoded(parts[3] || '') });
    if (cogOpen) cogPlaced();
}
function decoded(text) {    // base64 of UTF-8, as text
    var data = $.NSData.alloc.initWithBase64EncodedStringOptions($(text), 0);
    if (!data || data.isNil()) return '';
    var said = $.NSString.alloc.initWithDataEncoding(data, 4);
    return said && !said.isNil() ? said.js : '';
}
function supportAbout() {
    return 'Write what went wrong, or what you would like the browser to do. ' + (licenceMonth ? 'It is sent to ' + supportHost + ' with your licence code, which ties it to your purchase: remove the code first to send without it. This is all that is sent:\n' : 'It is sent anonymously to ' + supportHost + ', and this is all that is sent:\n')
        + '• your words\n• one line with the release number: Release ' + supportRelease + '\n'
        + (licenceMonth ? '• your licence code, so it is answered first\n' : '')
        + '• the picture of this window, only when you tick it below. It shows the page in the window and the address in its bar.\n'
        + 'No address of a page besides what that picture shows, no history, no name of this Mac or of you. That host sees your internet address, as every site does.';
}
function windowPicture() {    // the window's own drawing of itself, at one pixel a point, made smaller until its PNG is one lzrprf sends; null when none is
    var r = root.bounds, big = root.bitmapImageRepForCachingDisplayInRect(r);
    if (!big || big.isNil()) return null;
    var localPane = inspectUI && inspectUI.pane, locallyHidden = localPane && localPane.hidden;
    if (localPane) localPane.hidden = true;
    try { root.cacheDisplayInRectToBitmapImageRep(r, big); }
    finally { if (localPane) localPane.hidden = locallyHidden; }
    for (var scale = 1; scale >= 0.25; scale /= 2) {
        var w = Math.max(1, Math.round(r.size.width * scale)), h = Math.max(1, Math.round(r.size.height * scale));
        var rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(null, w, h, 8, 4, true, false, $('NSDeviceRGBColorSpace'), 0, 0);
        if (!rep || rep.isNil()) return null;
        $.NSGraphicsContext.saveGraphicsState;
        $.NSGraphicsContext.currentContext = $.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep);
        big.drawInRect($.NSMakeRect(0, 0, w, h));
        $.NSGraphicsContext.restoreGraphicsState;
        var png = rep.representationUsingTypeProperties(4, $({}));    // 4: PNG
        if (png && !png.isNil() && png.length > 0 && png.length <= SUPPORT_PICTURE_MOST) return png;
    }
    return null;
}
function supportOpened() {
    if (!takes()) return;
    supportShot = windowPicture();    // before the panel is over the window: the picture holds the window and not the panel
    supportText.string = $('');
    supportTick.state = 0;
    supportWritten();
    win.makeFirstResponder(supportText);
}
function supportWritten() {    // the panel with the box: Cancel, Read the answer when a request is kept, Send
    var choices = [['Cancel', closeModal]];
    if (supportTicket != '-') choices.push(['Read the answer', supportAsked]);
    choices.push(['Send', supportSent]);
    modal('Support or feature request', supportAbout(), choices, 'support');
    supportTick.enabled = !!supportShot;
    supportTick.title = $(supportShot ? 'Attach a picture of this window. It shows the page in it and the address in its bar.' : 'No picture of this window could be made.');
    supportTicked();
}
function supportTicked() {    // the picture is shown only while it is ticked, so what would leave is seen before Send
    var on = supportTick.state == 1 && !!supportShot;
    supportPreview.image = on ? $.NSImage.alloc.initWithData(supportShot) : $();
    supportPreview.hidden = !on || !(modalOpen && modalKind == 'support');
}
function supportWords() { return supportText.string.js.replace(/\r\n?/g, '\n').replace(/^\s+|\s+$/g, ''); }
function supportSent() {
    if (supportWaiting) return;
    var text = supportWords(), most = SUPPORT_TEXT_MOST - ('\n\nRelease ' + supportRelease).length;
    if (!text) { panelSub.stringValue = $('Write what the request is about first.'); panelSub.textColor = YELLOW; return; }
    if (Array.from(text).length > most) { panelSub.stringValue = $('Your words are longer than ' + most + ' characters. Make them shorter.'); panelSub.textColor = YELLOW; return; }
    var picture = supportTick.state == 1 && supportShot ? supportShot.base64EncodedStringWithOptions(0).js : '-';
    supportWaiting = true;
    panelSub.stringValue = $('Sending to ' + supportHost + '.');
    panelSub.textColor = WHITE;
    buttons([['Cancel', closeModal]]);
    say('support send ' + $(text).dataUsingEncoding(4).base64EncodedStringWithOptions(0).js + ' ' + picture);
}
function supportDone(ticket, priority, licence) {
    supportShot = null;
    modal('Support or feature request', 'Sent. Its reference is ' + ticket + '.' + (licence == 'accepted' ? ' It went with your licence code, so it is answered first.' : licence == 'refused' ? ' Your licence code was not taken, so it goes without priority.' : '')
        + '\nTo read the answer later, open Support request from the cogwheel and press Read the answer. lzrprf keeps the reference and its key in ~/.lzrprf/support, and asks ' + supportHost + ' for the answer only when you press it.',
        [['Close', closeModal], ['Read the answer', supportAsked]], 'support');
    supportScroll.hidden = true; supportTick.hidden = true; supportPreview.hidden = true;
}
function supportAsked() {
    if (supportWaiting) return;
    supportWaiting = true;
    modal('Your support request', 'Asking ' + supportHost + ' for the answer.', [['Close', function () { supportWaiting = false; closeModal(); }]], 'big');
    say('support read');
}
function supportRead(thread) {
    supportWaiting = false;
    var says = { open: 'It waits for an answer.', answered: 'It is answered.', resolved: 'It is resolved.', rejected: 'It was closed without a change.' }[thread.status] || '';
    modal('Your support request', 'Reference ' + supportTicket + '. ' + says + (thread.reason ? ' ' + thread.reason : ''), [['Forget it', supportForgotten], ['Write again', function () { closeModal(); supportOpened(); }], ['Close', closeModal]], 'big');
    panelText.string = $(thread.messages.map(function (one) { return (one.author == 'user' ? 'You' : 'Support') + (one.at != '-' ? ', ' + one.at.replace('T', ' ') + ' UTC' : '') + '\n' + one.body; }).join('\n\n'));
    panelText.textColor = WHITE;
}
function supportForgotten() { closeModal(); say('support forget'); }

// Bookmarks, as lzrprf read them from their folder and told them: "marks begin", "mark F FOLDER",
// "mark B N FOLDER<tab>NAME<tab>ADDRESS", "marks end".
// lzrprf tells them in each folder's order (its .order), a folder before what is in it, so the order
// they are told in is the order they are shown in: bookmarks and folders mixed, as in Chrome.
var markCount = 0, folderAt = {};    // how many were told; where each folder stood in that order
function markTold(rest) {
    if (rest.charAt(0) == 'F') { folderAt[rest.slice(2)] = markCount++; return folders.push(rest.slice(2)); }
    var gap = rest.indexOf(' ', 2), parts = rest.slice(gap + 1).split('\t');
    marks.push({ id: +rest.slice(2, gap), folder: parts[0], name: parts[1], url: parts[2], at: markCount++ });
}

function inFolder(path) {    // what is in a folder, its folders and bookmarks in the order lzrprf told them
    var all = folders.filter(function (f) { return f.slice(0, path.length + 1) == path + '/' && f.indexOf('/', path.length + 1) < 0; }).map(function (f) { return { folder: f, name: f.slice(path.length + 1), at: folderAt[f] }; });
    return all.concat(marks.filter(function (m) { return m.folder === path; }).map(function (m) { return { mark: m, name: m.name, at: m.at }; })).sort(function (a, b) { return a.at - b.at; });
}

function marked() { for (var i = 0; i < marks.length; i++) if (marks[i].url == current) return marks[i]; return null; }

// The star at the end of the bar: a light grey line, or filled with the beam and glowing when the
// address shown is a bookmark.
function paintStar() {
    var size = star.frame.size, cx = size.width / 2, cy = size.height / 2, path = $.NSBezierPath.bezierPath, kept = !!current && !!marked(), lit = takes() && !INCOGNITO;    // incognito: grey, its tooltip says why
    for (var k = 0; k < 10; k++) {
        var turn = Math.PI / 2 + k * Math.PI / 5, r = k % 2 ? 3.4 : 8, point = $.NSMakePoint(cx + r * Math.cos(turn), cy + r * Math.sin(turn));
        if (k == 0) path.moveToPoint(point); else path.lineToPoint(point);
    }
    path.closePath;
    if (kept) { $.NSGraphicsContext.saveGraphicsState; glow(GREEN, 8); GREEN.setFill; path.fill; $.NSGraphicsContext.restoreGraphicsState; }
    stroked(path, kept ? GREEN : hover.star && lit ? WHITE : lit ? ICON : GREY, 1.3, kept || hover.star && lit ? GREEN : null, 7);
}

var BAR = 'Bookmarks bar';    // the folder the bookmarks bar shows (lzrprf's $BAR)
function folderLabel(path) { return path ? path.split('/').join(' / ') : 'Other bookmarks'; }

function starClicked() {
    if (INCOGNITO) { wordsTold(UNKEPT_TIP); return; }    // [C16] no bookmark is written by an incognito window
    if (!takes() || !current) return;
    var one = marked();
    editing = one ? one.id : null;
    modal(one ? 'Edit bookmark' : 'Add bookmark', one ? 'This page is a bookmark. Change it, or remove it.' : 'A bookmark is kept in ' + 'your lzrprf folder, as a name and an address. The bookmarks bar shows the ones in its folder.',
        [['Cancel', closeModal]].concat(one ? [['Remove', function () { closeModal(); sent('mark remove ' + one.id); }]] : []).concat([['Save', markSave]]), 'form');
    nameField.stringValue = $(one ? one.name : tabs[selected] && tabs[selected].title || current);
    addressField.stringValue = $(one ? one.url : current);
    folderPop.removeAllItems;
    var places = [BAR, ''].concat(folders.filter(function (f) { return f != BAR; }));    // the bar's folder first, as Chrome offers it, then the top, then each folder
    places.forEach(function (path) { folderPop.addItemWithTitle($(folderLabel(path))); folderPop.lastItem.representedObject = $(path); });
    folderPop.addItemWithTitle($('New folder...'));
    folderPop.selectItemAtIndex(one ? Math.max(0, places.indexOf(one.folder)) : 0);
    newFolderField.stringValue = $('');
    newFolderField.hidden = true;
    win.makeFirstResponder(nameField);
}

function folderChosen() { newFolderField.hidden = folderPop.indexOfSelectedItem != folderPop.numberOfItems - 1; if (!newFolderField.hidden) win.makeFirstResponder(newFolderField); }

var FOLDER = /^(?:[A-Za-z0-9_-][A-Za-z0-9 ._-]{0,63}(?:\/[A-Za-z0-9_-][A-Za-z0-9 ._-]{0,63}){0,3})?$/;
function markSave() {
    var fresh = !newFolderField.hidden, folder = fresh ? newFolderField.stringValue.js.trim() : folderPop.selectedItem.representedObject.js;
    var name = nameField.stringValue.js.replace(/[\x00-\x1f\x7f]/g, ' ').trim().slice(0, 200), address = addressField.stringValue.js.trim().replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 2100);
    if (!FOLDER.test(folder)) { panelSub.stringValue = $('A folder is a name of letters, digits, space, dot, underscore or hyphen, not beginning with a dot or a space; names joined by / make a folder inside a folder, at most four deep.'); panelSub.textColor = YELLOW; return; }
    if (!address) { panelSub.stringValue = $('A bookmark needs an address.'); panelSub.textColor = YELLOW; return; }
    closeModal();
    sent('mark save\t' + (editing === null ? '-' : editing) + '\t' + folder + '\t' + (name || address) + '\t' + address);
}

// The bookmarks bar, under the bar's row when it is shown: the bookmarks and folders at the top,
// side by side; a folder opens a menu of what is in it, a folder in it a menu of its own. What does
// not fit is in the menu of the last place.
function marksAtTop() { return inFolder(BAR); }    // what is in the bar's folder, in its order

function marksLaid() {
    var room = marksView.frame.size.width - 12, x = 12, placed = [], items = marksAtTop();
    for (var i = 0; i < items.length; i++) {
        var w = Math.min(180, Math.ceil($(items[i].name).sizeWithAttributes(inked(sans(12.5), WHITE)).width) + 36);
        if (x + w > room - (i < items.length - 1 ? 40 : 0)) { placed.push({ x: x, w: 34, more: items.slice(i), name: '>>' }); break; }
        placed.push({ x: x, w: w, item: items[i] });
        x += w + 4;
    }
    return placed;
}

function paintMarks() {
    var size = marksView.frame.size, high = size.height;
    marksPlaced = marksLaid();    // on the frame's glass, with no fill of its own
    if (!marksPlaced.length) $('No bookmarks in the bookmarks bar yet: the star beside the address adds the page shown.').drawAtPointWithAttributes($.NSMakePoint(16, high / 2 - 7), inked(sans(12), GREY));
    marksPlaced.forEach(function (one, i) {
        var hot = i == hover.mark && takes(), pill = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(one.x, 4, one.w, high - 8), 9, 9);
        if (hot) { glass(pill, true); $.NSGraphicsContext.saveGraphicsState; glow(GREEN, 6); DIM.setStroke; pill.stroke; $.NSGraphicsContext.restoreGraphicsState; }
        if (one.more) return $('>>').drawAtPointWithAttributes($.NSMakePoint(one.x + 9, high / 2 - 7), inked(sans(12.5, true), GREEN));
        var mark = one.item.mark, glyph = $.NSBezierPath.bezierPath, gy = high / 2;
        if (mark) {    // a bookmark's ribbon, as on the home page
            [[9.5, 5.5], [9.5, -5.5], [13, -2.5], [16.5, -5.5], [16.5, 5.5]].forEach(function (p, j) { var at = $.NSMakePoint(one.x + p[0], gy + p[1]); if (j) glyph.lineToPoint(at); else glyph.moveToPoint(at); });
            glyph.closePath;
        } else {    // a folder: a tab on a rounded box
            glyph.appendBezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(one.x + 8, gy - 4.5, 12, 8.5), 1.6, 1.6);
            glyph.moveToPoint($.NSMakePoint(one.x + 8.5, gy + 4)); glyph.lineToPoint($.NSMakePoint(one.x + 9.5, gy + 5.5)); glyph.lineToPoint($.NSMakePoint(one.x + 13, gy + 5.5)); glyph.lineToPoint($.NSMakePoint(one.x + 14, gy + 4));
        }
        stroked(glyph, hot ? GREEN : ICON, 1.2, hot ? GREEN : null, 5);
        $(one.item.name).drawInRectWithAttributes($.NSMakeRect(one.x + 26, gy - 8.5, one.w - 31, 17), inked(sans(12.5), hot ? WHITE : ICON, true));
    });
    LINE.setStroke;
    $.NSBezierPath.strokeLineFromPointToPoint($.NSMakePoint(0, 0.5), $.NSMakePoint(size.width, 0.5));
}

function markAt(event) {
    var at = pointIn(marksView, event);
    for (var i = 0; i < marksPlaced.length; i++) if (at.x >= marksPlaced[i].x && at.x < marksPlaced[i].x + marksPlaced[i].w) return i;
    return -1;
}

function folderMenu(path, items) {    // the menu of a folder: its folders, each with a menu of its own, then its bookmarks
    var menu = $.NSMenu.alloc.initWithTitle($(''));
    menu.autoenablesItems = false;
    menu.appearance = $.NSAppearance.appearanceNamed($('NSAppearanceNameDarkAqua'));
    (items || inFolder(path)).forEach(function (one) {
        var item = menu.addItemWithTitleActionKeyEquivalent($(one.name), one.mark ? 'markMenu:' : null, $(''));
        titled(item, one.name);
        if (one.mark) { item.target = hand; item.tag = one.mark.id; }
        else item.submenu = folderMenu(one.folder);
    });
    if (!menu.numberOfItems) { var none = menu.addItemWithTitleActionKeyEquivalent($('(empty)'), null, $('')); none.enabled = false; }
    return menu;
}

function marksClicked(event) {
    var i = markAt(event);
    if (i < 0) return windowHeld(event);    // beside its bookmarks, the bookmarks bar moves the window
    if (!takes()) return;
    var one = marksPlaced[i];
    if (one.item && one.item.mark) return sent('mark open ' + one.item.mark.id);
    folderMenu(one.item ? one.item.folder : '', one.more).popUpMenuPositioningItemAtLocationInView($(), $.NSMakePoint(one.x, -2), marksView);
}

// A neutral place until the application's contained home has drawn. Home geometry, lettering,
// graphics and game rules live in the private program; the keeper has only this local request.
function paintHome() {
    if (!homePreview) return;
    var b = homeView.bounds;
    if (homePreview.size.width == b.size.width && homePreview.size.height == b.size.height)
        homePreview.drawInRectFromRectOperationFractionRespectFlippedHints(b, $.NSZeroRect, 2, 1, true, $());
}
function homeAt(event) { return -1; }
function homeKept(one) { if (!one.address && homePreview) { homeLoading = true; homeSceneGen = -1; pieces(); } }    // a home tab shown again: the picture of its scene until its layers are made again in the background (homeSceneReady)
function homeClicked(event) {
    if (!takes()) return;
    var at = pointIn(homeView, event);
    homePendingPress = { x: Math.round(at.x), y: Math.round(homeView.flipped ? at.y : homeView.bounds.size.height - at.y) };
    homeAsked(false);
}
function pressSeen(event) { }    // chrome never fires a page's effects; the page receives only its own pointer events
var homeRequestKey = '', homePreview = null, homeLoading = false, startupReady = false, startupRequested = false, homePress = null, homePendingPress = null, homeSceneGen = -1;
function homeAsked(game) {
    var size = homeView.frame.size, key = (tabs[selected] ? tabs[selected].gen : shownGen) + ':' + Math.round(size.width) + ':' + Math.round(size.height);
    if (!game && key == homeRequestKey) return;
    homeRequestKey = key;
    if (!pageShown || homeSceneGen != (tabs[selected] ? tabs[selected].gen : shownGen)) { homeLoading = true; pieces(); }
    say('home ' + Math.round(size.width) + ' ' + Math.round(size.height) + (game ? ' game' : ''));
}

// Keep only the first checked, fully assembled local scene as a per-window preview. The picture
// comes from the private program, stays in memory and is never a website or another profile's.
function homeSceneReady() {
    if (layerPumping) { layerReadyOwed = true; return; }
    if (current || !pageShown || !layerRoot || !Object.keys(layerOf).length) return;
    homeSceneGen = tabs[selected] ? tabs[selected].gen : shownGen;
    homeLoading = false; pieces(); layersKit().deal.flush;
    var b = canvas.bounds, size = homeView.frame.size;
    if (!homePreview || homePreview.size.width != size.width || homePreview.size.height != size.height) {
        var rep = canvas.bitmapImageRepForCachingDisplayInRect(b);
        canvas.cacheDisplayInRectToBitmapImageRep(b, rep);
        homePreview = $.NSImage.alloc.initWithSize(size); homePreview.addRepresentation(rep);
    }
    if (homePendingPress) {
        homePress = { x: homePendingPress.x, y: homePendingPress.y, at: Date.now() };
        say('page click ' + homePress.x + ' ' + homePress.y); homePendingPress = null;
    }
    startupReady = true;
    if (startupRequested && !win.visible) shown();
}

function searched() { if (takes()) { if (searchSet) barChosen(); else engineAsked(); } }

// Only a recent click in the home page fires the beam of its search or + to the bar or the new tab; it takes no press.
// It is a path of Core Animation that the window server runs on its own clock (H-0069): the beam was drawn here a
// frame at a time, and opening the tab or the bar, which holds this thread just then, cut it off midway. Its head
// runs the whole way, its tail follows it in, and a glint lights where it lands. The same in every kind of window.
var shot = null, shotView = null, shotParts = null, SHOT_FLY = 0.11, SHOT_FLASH = 0.12;
function homeActionShot(action) {
    if (!homePress || Date.now() - homePress.at > 1000 || !flightAllowed()) return;
    var target = action == 'search' ? bar : tabsView, k = layersKit(), now = $.NSProcessInfo.processInfo.systemUptime;    // Core Animation's clock
    var to = action == 'search' ? searchPlaceholderCenter(bar)
        : $.NSMakePoint(TABS_X + (tabs.length + 0.5) * Math.max(1, Math.min(260, Math.floor((tabsView.frame.size.width - TABS_X - 48) / (tabs.length + 1)))), tabsView.frame.size.height / 2);
    if (!shotView) { shotView = $.LzrprfLayers.alloc.initWithFrame(root.bounds); shotView.layer = k.layer.layer; shotView.wantsLayer = true; root.addSubview(shotView); shotParts = [k.shape.layer, k.shape.layer]; shotParts.forEach(function (one) { shotView.layer.addSublayer(one); }); }
    shotView.frame = root.bounds; shotView.hidden = false;
    shot = { from: canvas.convertPointToView($.NSMakePoint(homePress.x, homePress.y), shotView), to: target.convertPointToView(to, shotView), began: Date.now() };
    var beam = shotParts[0], glint = shotParts[1], at = function (p) { return Math.round(p.x * 10) / 10 + ',' + Math.round(p.y * 10) / 10; };
    k.deal.begin; k.deal.setDisableActions(true);
    beam.path = layerPath('M' + at(shot.from) + 'L' + at(shot.to)).path; beam.fillColor = $(); beam.strokeColor = layerInk('ecf2f6ff'); beam.lineWidth = 1.2; beam.lineCap = $('round');
    layerGlow(beam, INCOGNITO ? 'c485ffb3' : '47ddffb3', 5); beam.shouldRasterize = false;    // its stroke changes every frame: the glow is drawn with it
    var x = shot.to.x, y = shot.to.y, d = function (dx, dy) { return at({ x: x + dx, y: y + dy }); };
    glint.path = layerPath('M' + d(-2, 0) + 'Q' + d(-2, -2) + ',' + d(0, -2) + 'Q' + d(2, -2) + ',' + d(2, 0) + 'Q' + d(2, 2) + ',' + d(0, 2) + 'Q' + d(-2, 2) + ',' + d(-2, 0) + 'Z').path; glint.fillColor = layerInk('ecf2f6ff');    // a dot 4 points across
    beam.strokeStart = 1; beam.strokeEnd = 1; glint.opacity = 0;    // what is left once it ran: nothing lit
    shot.runs = [[beam, 'strokeEnd', 0, 1, 0, SHOT_FLY], [beam, 'strokeStart', 0, 1, SHOT_FLY / 2, SHOT_FLY], [glint, 'opacity', 1, 0, SHOT_FLY, SHOT_FLASH]].map(function (r) {    // the head to the target, the tail half a flight behind it all the way in, the glint
        var a = $.NSClassFromString($('CABasicAnimation')).animationWithKeyPath($(r[1]));
        a.fromValue = $.NSNumber.numberWithDouble(r[2]); a.toValue = $.NSNumber.numberWithDouble(r[3]); a.duration = r[5];
        if (r[4]) { a.beginTime = now + r[4]; if (r[1] == 'strokeStart') a.fillMode = $('backwards'); }    // the tail waits at the press; the glint is unlit until the head lands
        r[0].addAnimationForKey(a, $(r[1])); return r.slice(1);
    });
    k.deal.commit; k.deal.flush;    // handed to the window server now, before the tab or the bar is opened
    $.NSObject.cancelPreviousPerformRequestsWithTargetSelectorObject(hand, 'shotEnded:', $());
    hand.performSelectorWithObjectAfterDelay('shotEnded:', $(), SHOT_FLY * 1.5 + SHOT_FLASH);
}
function shotEnded() { shot = null; if (shotView) shotView.hidden = true; }

function barChosen() { win.makeFirstResponder(bar); var editor = bar.currentEditor; if (editor && !editor.isNil()) editor.selectAll($()); belt.needsDisplay = true; }

function engineAsked() {
    var picked = function (name) { return function () { closeModal(); searchNext = searchNext || 'focus'; sent('search ' + name); }; };
    modal('Choose your search engine', 'Words you type into the address bar that are not an address are searched with it. You can change it later from the cogwheel. Nothing is sent until you choose.',
        [['Cancel', function () { searchNext = null; closeModal(); }], ['Custom...', engineOwn], ['Google', picked('google')], ['DuckDuckGo', picked('duckduckgo')], ['Brave', picked('brave')]], 'small');
}

function engineOwn() {
    modal('Custom search engine', 'Give the address a search is made at, with %s where your words go, for example\nhttps://search.example.com/search?q=%s\nIt must begin with https://, name a host by its name and not by a number, use port 443, be plain characters without a space, and hold %s exactly once. Your words are percent-encoded in its place.',
        [['Cancel', function () { searchNext = null; closeModal(); }], ['Back', engineAsked], ['Save', engineSaved]], 'engine');
    engineField.stringValue = $('');
    win.makeFirstResponder(engineField);
}

function engineSaved() {
    var text = engineField.stringValue.js.trim();
    if (!/^https:\/\/[\x21-\x7e]+$/i.test(text) || text.split('%s').length != 2) { panelSub.stringValue = $('That is not a search address lzrprf takes: https://, plain characters without a space, and %s exactly once, for example https://search.example.com/search?q=%s'); panelSub.textColor = YELLOW; return; }
    closeModal();
    searchNext = searchNext || 'focus';
    sent('search custom\t' + text);
}

// The bookmarks page and the tabs page, where the page stands, left by the back arrow: every
// bookmark under its folder, or every tab; a press opens the bookmark or chooses the tab.
function listOpened(which) { listing = which; secureHidden(); techHidden(); suggestHidden(); place(); listView.scrollPoint($.NSMakePoint(0, 0)); }

function listRows() {
    if (listing == 'tabs') return tabs.map(function (tab, i) { return { tab: i, name: tab.title || 'New Tab', sub: i == selected ? 'The tab chosen now' : 'Tab ' + (i + 1) }; });
    if (listing == 'scripts') return scriptRows();
    if (listing == 'filters') return filterRows();
    var rows = [];
    [''].concat(folders).forEach(function (folder) {    // each folder in the order told, a folder before what is in it
        var in_ = marks.filter(function (m) { return m.folder === folder; });
        if (folder) rows.push({ heading: folderLabel(folder) });
        in_.forEach(function (m) { rows.push({ mark: m.id, name: m.name, sub: m.url }); });
    });
    return rows;
}

function listPlaced() {    // each row with its top, in the list's flipped view
    if (listing == 'log') return { rows: [], end: logPlaced().end };
    var rows = listRows(), y = 132, wide = Math.min(760, listScroll.frame.size.width - 64), x = Math.round((listScroll.frame.size.width - wide) / 2);
    rows.forEach(function (row) { row.y = y; row.x = x; row.w = wide; row.h = row.heading ? 36 : 54; y += row.h + (row.heading ? 0 : 8); });
    return { rows: rows, end: y + 40 };
}

function listSized() { if (listView) listView.setFrameSize($.NSMakeSize(listScroll.contentSize.width, Math.max(listScroll.contentSize.height, listPlaced().end))); }

function paintList(dirty) {
    if (!listing) return;
    if (listing == 'log') return paintLog(dirty);
    var size = listView.frame.size, cx = size.width / 2, laid = listPlaced(), count = laid.rows.filter(function (r) { return !r.heading; }).length, lit = takes();
    var title = spaced(listing == 'tabs' ? 'TABS' : listing == 'scripts' ? 'LZRDFNDR SCRIPTS' : listing == 'filters' ? 'FILTERS' : 'BOOKMARKS', wide(26, -0.4), WHITE, 12);
    title.drawAtPoint($.NSMakePoint(Math.round(cx - (title.size.width - 12) / 2), 34));
    var about = listing == 'filters' ? (filterState.on ? filterState.lists.length + (filterState.lists.length == 1 ? ' list' : ' lists') + '. ' : 'Nothing is filtered. ') + 'A filter blocks requests only: it never lets a script run. The back arrow returns to the page.' : listing == 'scripts' ? (scriptsUnread ? 'The scripts file is not a file lzrprf reads, so none of its rules counts: every script is asked about. ' : '') + scriptRules.length + (scriptRules.length == 1 ? ' rule' : ' rules') + '. The back arrow returns to the page.' : listing == 'tabs' ? count + (count == 1 ? ' tab' : ' tabs') + '. The back arrow returns to the page.' : count ? count + (count == 1 ? ' bookmark' : ' bookmarks') + '. The back arrow returns to the page.' : 'No bookmarks yet: the star in the address bar keeps the page shown. The back arrow returns to the page.';
    centred(styled(about, inked(sans(12.5), GREY)), cx, 80, 0);
    laid.rows.forEach(function (row, i) {
        if (row.heading) return spaced(row.heading.toUpperCase(), sans(11, true), GREEN, 1.6).drawAtPoint($.NSMakePoint(row.x + 4, row.y + 14));
        var hot = lit && hover.list == i, box = $.NSMakeRect(row.x, row.y, row.w, row.h), card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(box, 11, 11);
        $.NSGraphicsContext.saveGraphicsState;
        if (hot) glow(GREEN, 10);
        FILL.setFill;
        card.fill;
        $.NSGraphicsContext.restoreGraphicsState;
        stroked(card, hot ? GREEN : row.tab === selected ? DIM : LINE, hot ? 1.3 : 1, hot ? GREEN : null, 6);
        var icon = row.tab !== undefined ? $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(row.x + 18, row.y + 19, 16, 13), 3, 3) : ribbonGlyph(row.x + 26, row.y + 27);
        $.NSGraphicsContext.saveGraphicsState;
        var turn = $.NSAffineTransform.transform;    // the view is flipped: the icons are drawn the right way up
        turn.translateXByYBy(0, 2 * row.y + row.h);
        turn.scaleXByYBy(1, -1);
        turn.concat;
        stroked(icon, hot ? WHITE : ICON, 1.4);
        $.NSGraphicsContext.restoreGraphicsState;
        var room = row.w - 70 - scriptPills(row).length * 72;    // [C26] a rule keeps its right end for its buttons
        $(row.name).drawInRectWithAttributes($.NSMakeRect(row.x + 50, row.y + 9, room, 19), inked(sans(13.5, true), WHITE, true));
        $(row.sub).drawInRectWithAttributes($.NSMakeRect(row.x + 50, row.y + 29, room, 17), inked(sans(11.5), GREY, true));
        scriptPills(row).forEach(function (pill) {
            var on = pill.word.toLowerCase() == row.word, shape = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(pill.x, pill.y, pill.w, pill.h), 13, 13);
            stroked(shape, on ? GREEN : DIM, 1);
            var said = styled(pill.word, inked(sans(11.5, true), on ? GREEN : WHITE));
            said.drawAtPoint($.NSMakePoint(Math.round(pill.x + (pill.w - said.size.width) / 2), pill.y + 6));
        });
    });
}

// The log page: what lzrprf did for this window, and the last of the log it keeps on this
// computer, as lzrprf told them: "log begin", "log note TEXT" (what is kept, in full), then for
// each part "log part NAME" and its lines "log line WHEN<tab>WHAT", oldest first, and "log end",
// which shows the page. "log shut" closes it. The page lies over what the tab shows, which stays
// as it is under it. Its Close button, the log's icon in the strip, the menu's line and the back
// arrow each close it; a question lzrprf still asks about the log then is answered by its first
// button, which changes nothing.
function logTold(rest) {
    if (rest == 'begin') { logParts = []; return; }
    if (rest == 'shut') { if (listing == 'log') { listing = null; place(); } return; }
    if (!logParts) return;
    var kind = rest.slice(0, 5), gap = rest.indexOf('\t');
    if (kind == 'note ') logNote = rest.slice(5);
    else if (kind == 'part ') logParts.push({ heading: rest.slice(5), lines: [] });
    else if (kind == 'line ' && logParts.length) logParts[logParts.length - 1].lines.push({ when: rest.slice(5, gap < 0 ? rest.length : gap), what: gap < 0 ? '' : rest.slice(gap + 1) });
    else if (rest == 'end') {
        logRows = [];
        logParts.forEach(function (part) { logRows.push({ heading: part.heading }); logRows = logRows.concat(part.lines.reverse()); });    // the newest line first: the page opens at its top
        logParts = null;
        logLaid = null;
        logClosing = false;
        listOpened('log');
        logs.enabled = !modalOpen;
    }
}

function logPressed() {    // the log's icon and the menu's line: the page opens, and closes again
    if (modalOpen) return;
    if (listing == 'log') return logClosed();
    if (logs.enabled) { techHidden(); sent('log'); }
}

function logClosed() {
    if (listing != 'log') return;
    listing = null;
    if (asking) { logClosing = true; say('button ' + asked + ' 1'); }
    place();
}

function logWhen(when) {    // the time on this computer's clock: of today the hour, the minute and the second, of another day the day as well
    var at = new Date(when), two = function (n) { return (n < 10 ? '0' : '') + n; };
    if (isNaN(at.getTime())) return when.slice(0, 19);
    var hour = two(at.getHours()) + ':' + two(at.getMinutes());
    return at.toDateString() == new Date().toDateString() ? hour + ':' + two(at.getSeconds()) : two(at.getDate()) + '.' + two(at.getMonth() + 1) + '. ' + hour;
}

function logInk(what) {    // what went wrong or was refused in the warning's colour, what you did in white, an answer in the beam's, the rest quiet
    return /failed: |refused|could not|did not|was not|not cleared/.test(what) ? YELLOW : /^[Yy]ou /.test(what) ? WHITE : / answered/.test(what) ? GREEN : / -> lzrprf connects /.test(what) ? GREY : ICON;
}

function logShut(laid) { return $.NSMakeRect(laid.x + laid.w - 88, 30, 88, 30); }    // the Close button, at the top of the page on the box's right edge

function logPlaced() {    // the box and each line with its top and height, in the list's flipped view; measured once for a width
    var wide = Math.min(900, listScroll.frame.size.width - 64);
    if (logLaid && logLaid.w == wide) return logLaid;
    var x = Math.round((listScroll.frame.size.width - wide) / 2), y = 132 + 16, rows = [], room = wide - 36 - 92, lines = 0;
    logRows.forEach(function (row, i) {
        if (row.heading) {
            if (lines == 0 && rows.length) { rows.push({ none: true, y: y }); y += 24; }
            if (rows.length) y += 12;
            rows.push({ heading: row.heading, y: y });
            y += 28;
            lines = 0;
            return;
        }
        var said = styled(row.what, inked(mono(11.5), logInk(row.what))), high = Math.max(15, Math.ceil(said.boundingRectWithSizeOptions($.NSMakeSize(room, 4000), 1).size.height));
        rows.push({ when: logWhen(row.when), said: said, y: y, h: high });
        y += high + 7;
        lines++;
    });
    if (lines == 0) { rows.push({ none: true, y: y }); y += 24; }
    var note = styled(logNote, inked(sans(11.5), GREY)), noteHigh = logNote ? Math.ceil(note.boundingRectWithSizeOptions($.NSMakeSize(wide - 8, 4000), 1).size.height) : 0;
    logLaid = { w: wide, x: x, top: 132, rows: rows, room: room, boxEnd: y + 9, note: note, noteHigh: noteHigh, end: y + 9 + 18 + noteHigh + 40 };
    return logLaid;
}

function paintLog(dirty) {
    var size = listView.frame.size, cx = size.width / 2, laid = logPlaced();
    var from = dirty && dirty.origin ? dirty.origin.y - 4 : 0, to = dirty && dirty.size ? dirty.origin.y + dirty.size.height + 4 : laid.end;    // only the lines in what is drawn anew: a long log scrolls as fast as a short one
    var title = spaced('LOG', wide(26, -0.4), WHITE, 12);
    title.drawAtPoint($.NSMakePoint(Math.round(cx - (title.size.width - 12) / 2), 34));
    centred(styled('What this window did.', inked(sans(12.5), GREY)), cx, 80, 0);
    var shut = logShut(laid), hot = hover.list == -2, pill = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(shut, 15, 15);
    $.NSGraphicsContext.saveGraphicsState;
    if (hot) glow(GREEN, 10);
    FILL.setFill;
    pill.fill;
    $.NSGraphicsContext.restoreGraphicsState;
    stroked(pill, hot ? GREEN : DIM, hot ? 1.3 : 1, hot ? GREEN : null, 6);
    var cross = $.NSBezierPath.bezierPath, mx = shut.origin.x + 20, my = shut.origin.y + 15;
    cross.moveToPoint($.NSMakePoint(mx - 4, my - 4)); cross.lineToPoint($.NSMakePoint(mx + 4, my + 4));
    cross.moveToPoint($.NSMakePoint(mx + 4, my - 4)); cross.lineToPoint($.NSMakePoint(mx - 4, my + 4));
    stroked(cross, hot ? WHITE : GREEN, 1.5);
    styled('Close', inked(sans(12.5, true), WHITE)).drawAtPoint($.NSMakePoint(shut.origin.x + 34, shut.origin.y + 7));
    var card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(laid.x, laid.top, laid.w, laid.boxEnd - laid.top), 12, 12);
    FILL.setFill;
    card.fill;
    stroked(card, LINE, 1);
    laid.rows.forEach(function (row) {
        if (row.y > to || row.y + (row.h || 28) < from) return;
        if (row.heading) return spaced(row.heading.toUpperCase(), sans(10.5, true), GREEN, 1.6).drawAtPoint($.NSMakePoint(laid.x + 18, row.y + 4));
        if (row.none) return styled('Nothing yet.', inked(sans(11.5), GREY)).drawAtPoint($.NSMakePoint(laid.x + 18, row.y));
        styled(row.when, inked(mono(11), GREY)).drawAtPoint($.NSMakePoint(laid.x + 18, row.y));
        row.said.drawInRect($.NSMakeRect(laid.x + 18 + 92, row.y, laid.room, row.h + 2));
    });
    if (laid.noteHigh) laid.note.drawInRect($.NSMakeRect(laid.x + 4, laid.boxEnd + 18, laid.w - 8, laid.noteHigh + 2));
}

function listAt(event) {
    if (listing == 'log') { var on = pointIn(listView, event), shut = logShut(logPlaced()); return on.x >= shut.origin.x && on.x < shut.origin.x + shut.size.width && on.y >= shut.origin.y && on.y < shut.origin.y + shut.size.height ? -2 : -1; }
    var at = pointIn(listView, event), rows = listPlaced().rows;
    for (var i = 0; i < rows.length; i++) if (!rows[i].heading && at.y >= rows[i].y && at.y < rows[i].y + rows[i].h && at.x >= rows[i].x && at.x < rows[i].x + rows[i].w) return i;
    return -1;
}

function listClicked(event) {
    if (listing == 'log') { if (listAt(event) == -2) logClosed(); return; }    // the one thing on the log page that takes a press, also while lzrprf asks about the log
    var i = listAt(event), row = i >= 0 ? listPlaced().rows[i] : null;
    if (!row || !takes()) return;
    if (row.reset) return sent('scripts reset');    // [C26]
    if (row.rule !== undefined || row.layer || row.info || row.flist !== undefined || row.fallow !== undefined || row.fseen !== undefined) {
        var at = pointIn(listView, event), hit = scriptPills(row).filter(function (pill) { return at.x >= pill.x && at.x < pill.x + pill.w && at.y >= pill.y && at.y < pill.y + pill.h; })[0];
        if (!hit) return;
        if (row.flist !== undefined) return sent('filters switch ' + row.flist + ' ' + hit.word.toLowerCase());    // [C27] one list's switch
        if (row.fallow !== undefined) return sent('filters revoke ' + row.fallow);    // [C27] what you let through, revoked
        if (row.fseen !== undefined) return sent('filters allow ' + row.fseen);    // [C27] a blocked request's host let through on its site
        if (row.layer == 'e1') return sent('scripts e1 ' + hit.word.toLowerCase());    // the sandbox's switch (E1)
        if (row.layer == 'curated') return sent('scripts curated ' + row.n + ' ' + hit.word.toLowerCase());    // one curated rule's switch (E2)
        sent(hit.word == 'Revoke' ? 'scripts revoke ' + row.rule : 'scripts set ' + row.rule + ' ' + hit.word.toLowerCase());
        return;
    }
    if (row.mark !== undefined) { listing = null; place(); return sent('mark open ' + row.mark); }
    listing = null;
    place();
    if (row.tab != selected) tabSaid('tab select ' + row.tab);
}

// The lock at the start of the bar. Under the pointer, or pressed, it shows what lzrprf saw of the
// connection the page shown came over, as lzrprf told it: "secure begin", "secure line TEXT" for
// each line ("# HEADING" or "NAME: VALUE"), "secure end"; or "secure none" when no page is shown.
// A press keeps the panel open until the next press anywhere in the chrome.
// Its first row is how the site answered the page shown ("secure brief 200 \u00b7 61049 ms \u00b7 950 kB": status, time,
// size), as the footer said it before there was none; its last row opens what the page is made of.
function secureSaid() {
    var said = $.NSMutableAttributedString.alloc.init, add = function (text, font, colour, kern) { said.appendAttributedString(kern ? spaced(text, font, colour, kern) : styled(text, inked(font, colour))); };
    if (secureBrief) { add(secureBrief + '\n', sans(13, true), GREEN); add('how the site answered: its status, the time it took and its size\n\n', sans(11), GREY); }    // the first row: what the footer said once
    add(secureLines ? 'Encrypted connection' : 'No connection', sans(15, true), WHITE);
    add(secureLines ? '\nThe page shown came over https, checked by lzrprf.\n' : '\nThis tab shows no page, so there is no connection to tell of.\n', sans(12), GREY);
    (secureLines || []).forEach(function (line) {
        if (line.charAt(0) == '#') return add('\n' + line.slice(2).toUpperCase() + '\n', sans(10.5, true), GREEN, 1.2);
        var gap = line.indexOf(': ');
        if (gap > 0) { add(line.slice(0, gap) + '   ', sans(12), GREY); add(line.slice(gap + 2) + '\n', sans(12), WHITE); }
        else add(line + '\n', sans(12), WHITE);
    });
    return said;
}

function secureShown() {
    secureText.textStorage.setAttributedString(secureSaid());
    secureBox.hidden = false;
    securePlaced();
}

function securePlaced() {
    if (!secureBox || secureBox.hidden) return;
    var all = root.frame.size, w = Math.min(600, all.width - 40), top = all.height - TABS_HIGH - BAR_ROW + PILL.origin.y - 4;
    secureText.textContainer.containerSize = $.NSMakeSize(w - 40, 100000);
    secureText.layoutManager.ensureLayoutForTextContainer(secureText.textContainer);
    var used = secureText.layoutManager.usedRectForTextContainer(secureText.textContainer).size.height, h = Math.max(80, Math.min(top - 12, used + 44 + 40));    // and 40 points for its last row, what the page is made of
    secureBox.frame = $.NSMakeRect(Math.max(12, Math.min(PILL.origin.x - 10, all.width - w - 12)), top - h, w, h);
    secureScroll.frame = $.NSMakeRect(18, 56, w - 36, h - 72);
    secureText.setFrameSize($.NSMakeSize(w - 36, Math.max(h - 72, used + 8)));
    secureTech.frame = $.NSMakeRect(14, 14, w - 28, 30);
    secureBox.needsDisplay = true;
}

function secureHidden() { if (!secureBox) return; securePinned = false; secureBox.hidden = true; belt.needsDisplay = true; }
function secureToggled() { if (securePinned) return secureHidden(); techHidden(); securePinned = true; secureShown(); belt.needsDisplay = true; }

function paintSecure() {
    var size = secureBox.frame.size, box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(0.5, 0.5, size.width - 1, size.height - 1), 14, 14);
    $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.035, 0.045, 0.055, 0.98).setFill;
    box.fill;
    glass(box, true);
    stroked(box, GREEN, 1.1);
}

// The two icons at the right end of lzrprf's strip, each a thin light grey line drawn with the
// beam's glow under the pointer: the log (a sheet with lines of text), which shows lzrprf's log
// where the page stands, and what the page is made of (three layers), which opens its panel.
function logGlyph(cx, cy) {
    var p = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(cx - 5.5, cy - 7, 11, 14), 2, 2);
    [3, 0, -3].forEach(function (dy, i) { p.moveToPoint($.NSMakePoint(cx - 2.6, cy + dy)); p.lineToPoint($.NSMakePoint(cx + (i == 2 ? 0.6 : 2.6), cy + dy)); });
    return p;
}

function techGlyph(cx, cy) {
    var p = $.NSBezierPath.bezierPath;
    [[cx, cy + 6.5], [cx + 7.5, cy + 3], [cx, cy - 0.5], [cx - 7.5, cy + 3]].forEach(function (one, i) { if (i) p.lineToPoint($.NSMakePoint(one[0], one[1])); else p.moveToPoint($.NSMakePoint(one[0], one[1])); });
    p.closePath;
    [-0.6, -4.2].forEach(function (dy) { p.moveToPoint($.NSMakePoint(cx - 7.5, cy + dy + 0.1)); p.lineToPoint($.NSMakePoint(cx, cy + dy - 3.4)); p.lineToPoint($.NSMakePoint(cx + 7.5, cy + dy + 0.1)); });
    return p;
}

function paintIcon(view, glyph, hot, on, lit) {
    var size = view.frame.size, cx = size.width / 2, cy = size.height / 2;
    if (hot && on) { var back = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1, 1, size.width - 2, size.height - 2), 7, 7); glass(back, true); }
    stroked(glyph(cx, cy), lit ? GREEN : hot && on ? WHITE : on ? ICON : EDGE, 1.3, lit || hot && on ? GREEN : null, 7);
}

// The application's tool. Its icon stands left of Tor's in the bottom bar. A press asks lzrprf to
// open it ("tool open"); lzrprf answers with a list between "tool begin" and "tool end": the
// tool's title, its words, the words of its buttons, and its rows, each with the application's
// tag, title and sentence, and lzrprf's own words for what ticking it would change. All of it is
// drawn as text. A row is ticked by a click; the button that changes something takes a press once
// a row is ticked, and then shows only the ticked rows with lzrprf's words for each change, and
// asks once more. Only "tool act" and "tool undo", with the numbers of the ticked rows, change
// anything, and lzrprf checks each against what it saw itself (sub tool_may). H-0072: the panel opens
// in the press's own frame with the last list read (or none yet), held busy until lzrprf's new one
// replaces it, so nothing is ticked against an old look; measured, the wait for lzrprf's answer was the lag.
var gameHelper = false, gameStaged = false, TOOL_READING = 'Reading this computer', tool = null, toolIn = null, toolIcon = null, toolScroll = null, toolView = null, toolCopy = null, toolWaiting = false, toolBack = 0, toolItems = null, TOOL_WIDE = 800, TOOL_HIGH = 660;    // DECLARED(as wide as its three buttons side by side, and as tall as most laptop windows leave)
function toolPressed(tab) {    // TAB: the tab it opens on, On Your Computer unless named ("other": the minigame's Setup LZRDFNDR)
    if (modalOpen) { if (modalKind == 'tool') { if (webReturn) webReviewEnded(false); else closeModal(); } return; } if (permitReopened()) return;    // a minimized question about scripts comes back first (28-window1-tabs.pl)
    techHidden(); secureHidden(); suggestHidden();
    toolWaiting = true; toolBack = 0; toolIcon.needsDisplay = true;
    say('tool open');    // first: lzrprf reads while the panel is made
    if (INCOGNITO) return;    // an incognito window has no tool: lzrprf says why, and no panel opens and shuts
    tool = tool || { title: TOOL_TITLE, words: '', head: '', said: '', buttons: {}, rows: [] };
    tool.rows.forEach(function (row) { row.on = false; }); tool.busy = TOOL_READING; tool.reading = true; tool.confirm = false; tool.copied = ''; toolAll = false; TOOL_WIDE = 800;
    flyNext = { icon: toolIcon, at: Date.now() }; toolTab = tab == 'other' ? 'other' : 'computer'; gameStaged = gameHelper; modal(TOOL_TITLE, '', toolChoices(), 'tool'); toolChanged(); firstFlown();
}
function toolTold(rest) {
    var at = rest.indexOf(' '), word = at < 0 ? rest : rest.slice(0, at), more = at < 0 ? '' : rest.slice(at + 1);
    if (word == 'begin') toolIn = { title: '', words: '', head: '', said: '', buttons: {}, rows: [] };
    else if (word == 'none') { toolWaiting = false; toolIn = null; tool = null; if (modalOpen && modalKind == 'tool') closeModal(); }    // no list: lzrprf's strip says why
    else if (word == 'back') { toolBack = +more || 0; if (toolIcon) { toolIcon.toolTip = $(toolBack + (toolBack == 1 ? ' launchd job you switched off was' : ' launchd jobs you switched off were') + ' switched on again by something else, and switched off again'); toolIcon.needsDisplay = true; } }
    else if (word == 'busy') { if (tool && modalOpen && modalKind == 'tool') { tool.busy = more; toolChanged(); } }
    else if (word == 'noted' || word == 'proc') procsTold(word, more);    // Show all processes (HC-0843): a process of the list, and lzrprf's word on a note
    else if (word == 'show') { if (!modalOpen) toolPressed(more); }    // the game page's Activate LZRDFNDR, or its Setup LZRDFNDR ("show other", on the Other tab): as a press on the icon, unless a panel is open already
    else if (!toolIn) return;
    else if (word == 'title' || word == 'words' || word == 'head' || word == 'said') toolIn[word] = more;
    else if (word == 'button') { var gap = more.indexOf(' '); if (gap > 0) toolIn.buttons[more.slice(0, gap)] = more.slice(gap + 1); }
    else if (word == 'row') { var parts = more.split('\t'), lead = parts[0].split(' '); if (parts.length == 5 && lead.length == 2) toolIn.rows.push({ i: +lead[0], mode: lead[1], tag: parts[1], title: parts[2], detail: parts[3], fact: parts[4], on: false }); }
    else if (word == 'end') {
        tool = toolIn; toolIn = null; tool.busy = ''; tool.confirm = false;
        toolIcon.toolTip = $(tool.title);
        if (modalOpen && modalKind == 'tool') { panelTitle.stringValue = $(TOOL_TITLE); toolChanged(); }
        else if (toolWaiting && !modalOpen) { flyNext = { icon: toolIcon, at: Date.now() }; toolTab = 'computer'; gameStaged = gameHelper; modal(TOOL_TITLE, '', toolChoices(), 'tool'); toolChanged(); firstFlown(); }
        toolWaiting = false;
    }
}
// The copy button above the list: the title and the description of each row you ticked, under one
// sentence of ours, go to the clipboard, so you can paste them where you like (to an AI agent, for
// one) and learn more of them. It takes a press only while a row is ticked. A press on it, or on the
// copy button of the question about scripts, is the only thing that writes to the clipboard;
// clipboardWrite is that one write, for both (selftest puts its own in its place).
var TOOL_TITLE = 'LZRDFNDR \u2014 Spyware and Scripts', toolTab = 'computer', toolTabs = [], sitesIn = null, sitesList = null;    // the panel's three tabs: On Your Computer, the application's list; On Websites, the scripts of each site and your decision on each; Redirects, every redirect put to you and your decision on each
var TOOL_TABS = ['computer', 'websites', 'other'], redirectsIn = null, redirectsList = null;
var TOOL_COPY_WORDS = 'Copy found apps information to clipboard', TOOL_COPY_LEAD = 'These apps were found using LZRDFNDR by LZRBRWSR. We recommend analyzing and understanding what they are so you can make an informed choice to disable or keep them:';
var clipboardWrite = function (text) { var board = $.NSPasteboard.generalPasteboard; board.clearContents; return !!board.setStringForType($(text), $('public.utf8-plain-text')); };
function toolPicked() { return tool ? tool.rows.filter(function (row) { return row.on; }) : []; }
function toolCopyText() { return [TOOL_COPY_LEAD].concat(toolPicked().map(function (row) { return row.title + ': ' + row.detail; })).join('\n'); }
function toolCopied() {
    if (!tool || tool.busy || tool.confirm || !modalOpen || modalKind != 'tool' || !toolPicked().length) return;
    tool.copied = clipboardWrite(toolCopyText()) ? 'Copied to clipboard' : 'The clipboard did not take it';
    toolEnabled();
}
function toolTicked(mode) { return tool ? tool.rows.filter(function (row) { return row.on && row.mode == mode; }) : []; }
function toolNumbers(mode) { return toolTicked(mode).map(function (row) { return row.i; }).join(','); }
function toolChoices() {
    if (tool && toolTab == 'other') return [['Close', closeModal], [gameStaged ? 'Switch on' : 'Switch off', gameApplied]];    // the sentry's box ticked or not stages the choice, and this button applies it
    if (toolTab == 'websites') return [[webReturn ? 'Back' : 'Close', webReturn ? function () { webReviewEnded(false); } : closeModal], ['Save', essentialSave]];
    if (!tool || toolTab != 'computer') return [['Close', closeModal]];
    if (tool.confirm) return [['Back', toolBacked], ['Switch off ' + toolTicked('act').length, toolConfirmed]];
    var out = [['Close', closeModal]];
    if (tool.buttons.undo && tool.rows.some(function (row) { return row.mode == 'undo'; })) out.push([tool.buttons.undo, toolUndone]);
    if (tool.buttons.sense) out.push([tool.buttons.sense, toolSensed]);
    if (tool.buttons.act && tool.rows.some(function (row) { return row.mode == 'act'; })) out.push([tool.buttons.act, toolActed]);
    return out;
}
function toolEnabled() {    // which buttons take a press now: the one that changes something only once a row of its kind is ticked, none but Close while lzrprf works
    var acts = toolTicked('act').length, undos = toolTicked('undo').length;
    panelButtons.forEach(function (one, k) { var act = modalActions[k]; one.enabled = act == closeModal || !!tool && (!tool.busy || toolTab == 'other') && (act == gameApplied ? gameStaged != gameHelper : act == toolActed || act == toolConfirmed ? acts > 0 : act == toolUndone ? undos > 0 : true); });
    toolTabs.forEach(function (one, k) {    // the three tabs: not on the question; the one shown in the beam's colour
        one.hidden = !tool || !!tool.confirm || !!webReturn || !modalOpen || modalKind != 'tool';
        one.bezelColor = TOOL_TABS[k] == toolTab ? $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.05, 0.42, 0.52, 1) : $.NSColor.clearColor;
        one.state = TOOL_TABS[k] == toolTab ? 1 : 0;
    });
    if (toolCopy) {    // the copy button: not on the question, not on On Websites, and a press only while a row is ticked
        toolCopy.hidden = !tool || !!tool.confirm || !modalOpen || modalKind != 'tool' || toolTab != 'computer';
        toolCopy.enabled = !!tool && !tool.busy && !tool.confirm && toolPicked().length > 0;
        toolCopy.title = $(tool && tool.copied || TOOL_COPY_WORDS);
        procsEnabled();
    }
}
function toolChanged() {
    if (!tool || !modalOpen || modalKind != 'tool') return;
    toolItems = null; buttons(toolChoices()); toolEnabled(); toolSized();
}
function toolSized() {
    if (!toolScroll || !tool) return;
    toolItems = null; var room = toolScroll.contentSize;
    toolView.setFrameSize($.NSMakeSize(room.width, Math.max(room.height, toolLaid().high))); toolView.needsDisplay = true;
}
function toolTabbed(which) {    // a tab pressed: On Websites asks lzrprf for its scripts each time it is shown
    if (!tool || tool.busy && !tool.reading || tool.confirm || !modalOpen || modalKind != 'tool' || toolTab == which) return;
    toolTab = which;
    if (which == 'websites') webRead();
    gameStaged = gameHelper; toolChanged(); toolView.scrollPoint($.NSMakePoint(0, 0));
}
// [C26] On Websites, as lzrprf tells it: "sites begin", "sites site SITE", "sites script N<tab>SITE<tab>NAME<tab>inline|external<tab>
// BYTES<tab>WHO<tab>CLASS<tab>DECISION" for each script under its site, then "sites end", which shows it. A pill of a script says
// "scripts decide N always|deny|forget"; lzrprf changes the decision and tells the list again.
function sitesTold(rest) {
    var gap = rest.indexOf(' '), word = gap < 0 ? rest : rest.slice(0, gap), more = gap < 0 ? '' : rest.slice(gap + 1), f = more.split('\t');
    if (word == 'begin') sitesIn = [];
    else if (!sitesIn) return;
    else if (word == 'site') sitesIn.push({ site: more });
    else if (word == 'script' && f.length == 8 && /^\d{1,4}$/.test(f[0])) sitesIn.push({ n: +f[0], site: f[1], name: f[2], where: f[3], bytes: +f[4] || 0, who: f[5], cls: f[6], decision: f[7] });
    else if (word == 'end') { sitesList = sitesIn; sitesIn = null; if (modalOpen && modalKind == 'tool' && toolTab == 'websites') toolChanged(); }
}
// [C4] Redirects, as lzrprf tells it: "redirects begin", "redirects site SITE", "redirects one N<tab>SITE<tab>STATUS<tab>FROM<tab>TO<tab>
// DECISION<tab>FIT" for each redirect under its site, then "redirects end", which shows it. A pill says "redirects decide N proceed|cancel|forget".
function redirectsTold(rest) {
    var gap = rest.indexOf(' '), word = gap < 0 ? rest : rest.slice(0, gap), more = gap < 0 ? '' : rest.slice(gap + 1), f = more.split('\t');
    if (word == 'begin') redirectsIn = [];
    else if (!redirectsIn) return;
    else if (word == 'site') redirectsIn.push({ site: more });
    else if (word == 'one' && f.length == 7 && /^\d{1,4}$/.test(f[0])) redirectsIn.push({ n: +f[0], site: f[1], status: f[2], name: f[3], to: f[4], decision: f[5], fit: f[6] == '1' });
    else if (word == 'end') { redirectsList = redirectsIn; redirectsIn = null; if (modalOpen && modalKind == 'tool' && toolTab == 'websites') toolChanged(); }
}
function gameApplied() { if (gameStaged == gameHelper) return; gameHelper = gameStaged; say('game helper ' + (gameStaged ? 'on' : 'off')); toolChanged(); }    // H-0071: the sentry as staged, shown at once and kept by lzrprf, whose "game helper 0|1" wins
function toolBacked() { tool.confirm = false; toolChanged(); }
function toolActed() { if (!toolTicked('act').length) return; tool.confirm = true; toolChanged(); toolView.scrollPoint($.NSMakePoint(0, 0)); }
function toolConfirmed() { var which = toolNumbers('act'); if (!which) return; tool.confirm = false; tool.busy = 'Switching off what you ticked'; say('tool act ' + which); toolChanged(); }
function toolUndone() { var which = toolNumbers('undo'); if (!which) return; tool.busy = 'Switching on again what you ticked'; say('tool undo ' + which); toolChanged(); }
function toolSensed() { tool.busy = toolAll ? 'Reading every process of this computer' : 'Reading the processes and the launchd jobs of this computer'; say(toolAll ? 'tool all' : 'tool sense'); toolChanged(); }

function toolLaid() {    // what the list draws, from its top: each piece with where it begins and how tall it is
    if (toolItems) return toolItems;
    var w = toolScroll.contentSize.width - 2, y = 2, items = [], inner = w - 52;
    function tall(text, font, width) { return Math.ceil(styled(text, inked(font, WHITE)).boundingRectWithSizeOptions($.NSMakeSize(width, 4000), 1).size.height); }
    function note(text, font, colour, gap) { if (!text) return; var h = tall(text, font, w - 8); items.push({ text: text, font: font, colour: colour, y: y, h: h }); y += h + gap; }
    if (toolTab == 'other' && !tool.confirm) {
        note('LZRDFNDR minigame', sans(16, true), WHITE, 12);
        note('Burn the letters on the home page, then defend the name. Music is available in the game.', sans(13), GREY, 12);
        var said = "Ticked, LZRDFNDR's satellite stands sentry in the home page's minigame and shoots every saucer before it reaches the name; unticked, it never plays. Tick or untick it, then press " + (gameStaged ? 'Switch on.' : 'Switch off.'), detail = tall(said, sans(11.5), inner), high = 11 + 19 + detail + 11;
        items.push({ row: { on: gameStaged, mode: gameHelper ? 'undo' : 'act', tag: gameHelper ? 'on' : 'off', title: 'LZRDFNDR minigame sentry', detail: said, fact: '' }, game: true, y: y, h: high, detail: detail, fact: 0 });    // H-0071: a box as a row of On Your Computer; its tag says what is switched now
        toolItems = { items: items, high: y + high + 10, wide: w }; return toolItems;
    }
    if (toolTab == 'websites' && !tool.confirm) {
        y = webLaid(items, w, tall, defendLaid(items, w, tall, 2));
        toolItems = { items: items, high: y + 2, wide: w };
        return toolItems;
    }
    if (tool.confirm) note('You are about to switch these off. Under each row lzrprf says, in its own words, what it will change and nothing else: a launchd job of your account is switched off and kept off until you switch it on again here, and a process is asked to end. An app that needs what you switch off may start it again or stop working until you switch it on again. Each change is written in the log first.', sans(13), WHITE, 14);
    else {
        y = defendLaid(items, w, tall, y); note(tool.words, sans(13), WHITE, 12);
        note(tool.said, sans(12.5), YELLOW, 12);
    }
    note(tool.busy, sans(12.5, true), GREEN, 12);
    var rows = tool.confirm ? toolTicked('act') : tool.rows;
    if (!tool.confirm && tool.head && rows.length) note(tool.head, sans(14, true), WHITE, 10);
    rows.forEach(function (row) {
        var detail = tall(row.detail, sans(11.5), inner), fact = tool.confirm && row.fact ? tall(row.fact, mono(10.5), inner) + 6 : 0, h = 11 + 19 + detail + fact + 11;
        items.push({ row: row, y: y, h: h, detail: detail, fact: fact });
        y += h + 8;
    });
    y = procsLaid(items, y, w);    // Show all processes: every process under the rows
    toolItems = { items: items, high: y + 2, wide: w };
    return toolItems;
}
function paintTool() {
    if (!tool) return;
    var laid = toolLaid(), w = laid.wide, seen = toolView.visibleRect;
    laid.items.forEach(function (one) {
        if (one.y + one.h < seen.origin.y - 4 || one.y > seen.origin.y + seen.size.height + 4) return;    // only what shows is drawn
        if (one.essentialHead) return webPaintHead(one, w);
        if (one.web) return webPaintRow(one, w);
        if (one.proc || one.procs) return paintProc(one, w);
        if (!one.row) return styled(one.text, inked(one.font, one.colour)).drawInRect($.NSMakeRect(4, one.y, w - 8, one.h + 2));
        var row = one.row, can = row.mode != 'none', card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1.5, one.y + 0.5, w - 3, one.h - 1), 10, 10);
        FILL.setFill; card.fill;
        if (row.on) glass(card, true);
        stroked(card, row.on ? GREEN : LINE, row.on ? 1.2 : 1, row.on ? GREEN : null, 5);
        if (can && !tool.confirm) {    // the box that is ticked
            var box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(14.5, one.y + 12.5, 16, 16), 4, 4);
            if (row.on) {
                GREEN.setFill; box.fill;
                var tick = $.NSBezierPath.bezierPath;
                tick.moveToPoint($.NSMakePoint(18.5, one.y + 20.5)); tick.lineToPoint($.NSMakePoint(21.5, one.y + 24)); tick.lineToPoint($.NSMakePoint(27, one.y + 17));
                stroked(tick, DARK, 1.8);
            }
            else stroked(box, ICON, 1.2);
        }
        var tag = styled(row.tag.toUpperCase(), inked(sans(9.5, true), row.mode == 'undo' ? GREEN : can ? YELLOW : GREY)), tagWide = Math.ceil(tag.size.width);
        tag.drawAtPoint($.NSMakePoint(w - 16 - tagWide, one.y + 14));
        $(row.title).drawInRectWithAttributes($.NSMakeRect(42, one.y + 10, w - 42 - 28 - tagWide, 19), inked(sans(13.5, true), can ? WHITE : GREY, true));
        styled(row.detail, inked(sans(11.5), GREY)).drawInRect($.NSMakeRect(42, one.y + 30, w - 54, one.detail + 2));
        if (one.fact) styled(row.fact, inked(mono(10.5), DIM)).drawInRect($.NSMakeRect(42, one.y + 30 + one.detail + 6, w - 54, one.fact));
    });
}
function toolClicked(event) {
    if (!tool || tool.confirm || tool.busy && toolTab != 'other') return;
    var at = pointIn(toolView, event), items = toolLaid().items; if (defendClicked(at, items)) return; if (toolTab == 'other') { items.forEach(function (one) { if (one.game && at.y >= one.y && at.y < one.y + one.h) { gameStaged = !gameStaged; toolChanged(); } }); return; }    // the sentry's box: staged, applied by Switch on or Switch off (gameApplied)
    if (toolTab == 'websites') { webClick(at, items, toolLaid().wide); return; }
    if (procClicked(at, items)) return;
    for (var k = 0; k < items.length; k++) {
        var one = items[k];
        if (!one.row || one.row.mode == 'none' || at.y < one.y || at.y >= one.y + one.h) continue;
        one.row.on = !one.row.on; tool.copied = '';
        toolEnabled(); toolView.needsDisplay = true; return;
    }
}
function toolParts(cx, cy) {    // a satellite, tilted, its two panels out; and the beam it sends down (the button is flipped: y grows down, so y is turned here)
    var c = Math.SQRT1_2, at = function (x, y) { return $.NSMakePoint(cx + c * (x + y), cy - c * (y - x)); };
    var body = $.NSBezierPath.bezierPath, beam = $.NSBezierPath.bezierPath;
    function box(path, x0, y0, x1, y1) { path.moveToPoint(at(x0, y0)); path.lineToPoint(at(x1, y0)); path.lineToPoint(at(x1, y1)); path.lineToPoint(at(x0, y1)); path.closePath; }
    function line(path, x0, y0, x1, y1) { path.moveToPoint(at(x0, y0)); path.lineToPoint(at(x1, y1)); }
    box(body, -2.5, -2.5, 2.5, 2.5);
    box(body, -9.5, -2, -4, 2);
    box(body, 4, -2, 9.5, 2);
    line(body, -4, 0, -2.5, 0);
    line(body, 2.5, 0, 4, 0);
    line(body, -6.75, -2, -6.75, 2);
    line(body, 6.75, -2, 6.75, 2);
    line(body, 0, 2.5, 0, 4.5);
    line(beam, 0, -4, 0, -7);
    line(beam, 0, -8.5, 0, -11);
    line(beam, -1.8, -12, 1.8, -12);
    return [body, beam];
}
function toolIconDrawn(view) {
    var size = view.frame.size, cx = size.width / 2, cy = size.height / 2, hot = hover.toolIcon && !modalOpen, lit = modalOpen && modalKind == 'tool', parts = toolParts(cx, cy);
    if (hot) glass($.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1, 1, size.width - 2, size.height - 2), 7, 7), true);
    stroked(parts[0], lit ? GREEN : hot ? WHITE : ICON, 1.2, lit || hot ? GREEN : null, 7);
    stroked(parts[1], toolBack ? YELLOW : GREEN, 1.3, toolBack ? YELLOW : GREEN, 5);
    permitLaterBadge(size);
}
// What the page is made of, in the modal every other panel uses (centred, over the veil), larger
// than the others: the application's list as lzrprf checked it, and lzrprf's sentence that it
// checked the form of the list and not its truth. The last row of the lock's panel opens it, flying out of
// where that row stood; Close or Escape closes it, with no flight back, the row being gone.
var techOpen = false, TECH_WIDE = 900, TECH_HIGH = 720;    // DECLARED(as wide as a list row of 120 characters reads at 12.5 points, and as tall as most laptop windows leave)
function techToggled() {
    if (techOpen) return techHidden();
    if (modalOpen) return;
    secureHidden();
    suggestHidden();
    modal('What this page is made of', '', [['Close', techHidden]], 'tech');
    techOpen = true;
    under.hidden = false;
    placeModal();
}

function techHidden() {
    if (!techOpen) return;
    if (modalOpen && modalKind == 'tech') flyBack();
    techOpen = false;
    under.hidden = true;
    if (modalOpen && modalKind == 'tech') closeModal();
}

function techPlaced() { if (techOpen) placeModal(); }

// Suggestions under the bar while you type, as in Chrome: the pages shown in this window (lzrprf
// tells each, "history add ADDRESS<tab>TITLE", and "history clear" when the history is cleared;
// kept in the window's memory only) and the bookmarks, whose host or title begins with what is
// typed first, then those that hold it anywhere. Up and down move, Return opens, Escape closes, a
// press opens. Opening one puts its address in the bar and sends it as if it had been typed
// ("go ADDRESS"): lzrprf checks it as every typed address [C4].
var history = [], HISTORY_MOST = 500, SUGGEST_MOST = 8, SUGGEST_ROW = 46, SUGGEST_PAD = 6, suggestBox = null, suggestions = [], suggestSel = -1, suggestOpen = false;    // DECLARED(500 pages: more than 32 tabs of 100 addresses ever show at once in practice; 8 rows as Chrome shows)
function historyTold(rest) {
    if (rest == 'clear') { history = []; return suggestHidden(); }
    if (rest.slice(0, 4) != 'add ') return;
    var gap = rest.indexOf('\t', 4), url = gap < 0 ? rest.slice(4) : rest.slice(4, gap), title = gap < 0 ? '' : rest.slice(gap + 1);
    history = [{ url: url, title: title }].concat(history.filter(function (one) { return one.url != url; })).slice(0, HISTORY_MOST);
}

function bare(url) { return url.replace(/^https:\/\//i, '').replace(/^www\./i, '').replace(/\/$/, ''); }

function suggested(text) {
    var q = text.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, ''), seen = {}, found = [];
    if (!q) return [];
    function score(url, title) {
        var b = bare(url).toLowerCase(), t = (title || '').toLowerCase();
        if (b.indexOf(q) == 0) return 0;    // the host begins with it
        if (t.indexOf(q) == 0 || (' ' + t).indexOf(' ' + q) > 0) return 1;    // the title, or a word of it, begins with it
        return b.indexOf(q) >= 0 || t.indexOf(q) >= 0 ? 2 : -1;
    }
    history.forEach(function (one, i) { var s = score(one.url, one.title); if (s >= 0) { seen[one.url] = found.length; found.push({ url: one.url, title: one.title, kind: 'h', score: s, at: i }); } });
    marks.forEach(function (m, i) {
        var s = score(m.url, m.name);
        if (s < 0) return;
        if (seen[m.url] !== undefined) { var was = found[seen[m.url]]; was.kind = 'b'; was.title = was.title || m.name; was.score = Math.min(was.score, s); return; }
        seen[m.url] = found.length;
        found.push({ url: m.url, title: m.name, kind: 'b', score: s, at: HISTORY_MOST + i });
    });
    return found.sort(function (a, b) { return a.score - b.score || a.at - b.at; }).slice(0, SUGGEST_MOST);
}

function suggestUpdate() {
    if (!bar.enabled || !typing() || modalOpen) return suggestHidden();
    suggestions = suggested(bar.stringValue.js);
    suggestSel = -1;
    hover.suggest = -1;
    if (!suggestions.length) return suggestHidden();
    techHidden();
    secureHidden();
    suggestOpen = true;
    suggestBox.hidden = false;
    suggestPlaced();
}

function suggestHidden() { if (!suggestBox || !suggestOpen) return; suggestOpen = false; suggestSel = -1; suggestBox.hidden = true; }

function suggestPlaced() {
    if (!suggestBox || !suggestOpen || !PILL) return;
    var h = suggestions.length * SUGGEST_ROW + 2 * SUGGEST_PAD, top = belt.frame.origin.y + PILL.origin.y - 5;
    suggestBox.frame = $.NSMakeRect(PILL.origin.x, Math.max(8, top - h), PILL.size.width, Math.min(h, top - 8));
    suggestBox.needsDisplay = true;
}

function clockGlyph(cx, cy) {    // a page shown earlier: a clock
    var p = $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(cx - 6.5, cy - 6.5, 13, 13));
    p.moveToPoint($.NSMakePoint(cx, cy + 3.8)); p.lineToPoint($.NSMakePoint(cx, cy)); p.lineToPoint($.NSMakePoint(cx + 2.8, cy - 1.8));
    return p;
}

function ribbonGlyph(cx, cy) {    // a bookmark: its ribbon, as on the bookmarks bar
    var p = $.NSBezierPath.bezierPath;
    [[-3.5, 6], [-3.5, -6], [0, -3], [3.5, -6], [3.5, 6]].forEach(function (o, i) { var at = $.NSMakePoint(cx + o[0], cy + o[1]); if (i) p.lineToPoint(at); else p.moveToPoint(at); });
    p.closePath;
    return p;
}

function paintSuggest() {
    var size = suggestBox.frame.size, box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(0.5, 0.5, size.width - 1, size.height - 1), 14, 14);
    $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.035, 0.045, 0.055, 0.98).setFill;
    box.fill;
    glass(box, true);
    stroked(box, GREEN, 1.1);
    suggestions.forEach(function (one, i) {
        var top = size.height - SUGGEST_PAD - (i + 1) * SUGGEST_ROW, mid = top + SUGGEST_ROW / 2, hot = i == suggestSel || i == hover.suggest;
        if (hot) {
            var pill = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(6, top + 2, size.width - 12, SUGGEST_ROW - 4), 10, 10);
            glass(pill, true);
            $.NSGraphicsContext.saveGraphicsState; glow(GREEN, 6); (i == suggestSel ? GREEN : DIM).setStroke; pill.stroke; $.NSGraphicsContext.restoreGraphicsState;
        }
        stroked(one.kind == 'b' ? ribbonGlyph(26, mid) : clockGlyph(26, mid), hot ? GREEN : ICON, 1.3, hot ? GREEN : null, 5);
        $(one.title || bare(one.url)).drawInRectWithAttributes($.NSMakeRect(48, mid + 1, size.width - 64, 18), inked(sans(13.5, hot), WHITE, true));
        $(bare(one.url)).drawInRectWithAttributes($.NSMakeRect(48, mid - 16, size.width - 64, 16), inked(sans(11.5), hot ? GREEN : GREY, true));
    });
}

function suggestAt(event) {
    var at = pointIn(suggestBox, event), size = suggestBox.frame.size, i = Math.floor((size.height - SUGGEST_PAD - at.y) / SUGGEST_ROW);
    return at.x >= 0 && at.x <= size.width && i >= 0 && i < suggestions.length ? i : -1;
}

function suggestGo(url) {    // as Return in the bar: the address goes to lzrprf as typed
    suggestHidden();
    bar.stringValue = $(url);
    if (asking || !bar.enabled) return;
    bar.enabled = false;
    say('go ' + url.replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 2100));
}

function suggestClicked(event) { var i = suggestAt(event); if (i >= 0) suggestGo(suggestions[i].url); }

function suggestKey(name) {    // a key the bar's editor was given: true when the suggestions took it
    if (name == 'moveDown:' || name == 'moveUp:') {
        if (!suggestOpen) { suggestUpdate(); return suggestOpen; }
        suggestSel = name == 'moveDown:' ? Math.min(suggestions.length - 1, suggestSel + 1) : Math.max(-1, suggestSel - 1);
        suggestBox.needsDisplay = true;
        return true;
    }
    if (name == 'cancelOperation:' && suggestOpen) { suggestHidden(); return true; }
    if (name == 'insertNewline:' && suggestOpen && suggestSel >= 0) { suggestGo(suggestions[suggestSel].url); return true; }
    if (name == 'insertNewline:') suggestHidden();
    return false;
}

// Import bookmarks: one modal, each choice one line to lzrprf, which reads the files [C15]. "import
// sources" lists the browsers on this Mac ("import source KEY NAME" each, then "import step source");
// a browser chosen sends "import profiles KEY" ("import profile N NAME" each, "import step profile");
// a profile or a file chosen is imported at once ("import go KEY N", or "import path PATH" for a file
// typed), and "import done" closes the modal while the strip says what came in. "import refused
// WORDS" is one sentence, said in yellow on the step it came from. "import ask KEY FOLDER" means
// macOS kept the reader out of that browser: the system's Open panel opens at FOLDER, and its
// answer goes back as "import allowed KEY PATH" (the folder chosen) or "import denied KEY".
var wiz = null, wizardView = null, pathField = null, WIZ_ROW = 54;
function importOpened() {
    if (!takes()) return;
    wiz = { step: 'wait', from: 'source', sources: [], profiles: [], comingSources: [], comingProfiles: [], note: '', comingNote: '', key: '', label: '', pick: -1, error: '', waiting: 'Looking for browsers.' };
    wizardShown();
    sent('import sources');
}

function importTold(rest) {
    if (!wiz) return;
    var at = rest.indexOf(' '), word = at < 0 ? rest : rest.slice(0, at), more = at < 0 ? '' : rest.slice(at + 1), gap = more.indexOf(' ');
    if (word == 'begin') { wiz.comingSources = []; wiz.comingProfiles = []; wiz.comingNote = ''; return; }
    if (word == 'source') return wiz.comingSources.push({ key: more.slice(0, gap), name: more.slice(gap + 1) });
    if (word == 'profile') { var parts = more.slice(gap + 1).split('\t'); return wiz.comingProfiles.push({ name: parts[0], sub: parts[1] || '' }); }    // after a tab, what tells two profiles alike apart: the account's address, or the folder
    if (word == 'note') { wiz.comingNote = more; return; }    // one short line over the profiles: their names could not be read
    if (word == 'done') { wiz = null; if (modalOpen && modalKind == 'wizard') closeModal(); return; }
    if (word == 'refused') { wiz.error = more; wiz.step = wiz.from; return wizardShown(); }
    if (word == 'ask') return wizAsk(more.slice(0, gap), more.slice(gap + 1));
    if (word != 'step') return;
    wiz.error = '';
    if (more == 'source') wiz.sources = wiz.comingSources;
    if (more == 'profile') { wiz.profiles = wiz.comingProfiles; wiz.note = wiz.comingNote; }
    wiz.pick = -1;
    wiz.step = more;
    wizardShown();
}

function wizardShown() {
    if (!wiz || modalOpen && modalKind != 'wizard') return;
    var s = wiz.step, file = wiz.key == 'file';
    if (s == 'wait') modal('Import bookmarks', wiz.waiting, [['Cancel', closeModal]], 'wizard');
    else if (s == 'source') modal('Import bookmarks', 'Choose a browser.', [['Cancel', closeModal]], 'wizard');
    else modal(wiz.label, file ? 'Choose a file, or type its path.' : 'Choose a profile.', [['Cancel', closeModal], ['Back', wizBack]].concat(file ? [['Import', wizTyped]] : []), 'wizard');
    if (wiz.error) { panelSub.stringValue = $(wiz.error); panelSub.textColor = YELLOW; }
    else if (s == 'profile' && !file && wiz.note) { panelSub.stringValue = $(wiz.note); panelSub.textColor = YELLOW; }
    pathField.hidden = !(s == 'profile' && file);
    if (!pathField.hidden) pathField.stringValue = $('');
    placeModal();
    wizardView.needsDisplay = true;
}

function wizChose(i) {    // a browser chosen shows its profiles; a profile or a file chosen is imported at once
    if (!free || !wiz) return;    // lzrprf is still busy with the step before
    var s = wiz.step, one = s == 'source' ? wiz.sources[i] : null;
    if (s == 'source' && one) { wiz.key = one.key; wiz.label = one.name; wiz.from = 'source'; wiz.step = 'wait'; wiz.waiting = 'Reading ' + one.name + '.'; wizardShown(); return sent('import profiles ' + one.key); }
    if (s == 'profile' && i < wiz.profiles.length) { wiz.from = 'profile'; wiz.step = 'wait'; wiz.waiting = 'Importing from ' + wiz.profiles[i].name + '.'; wizardShown(); return sent('import go ' + wiz.key + ' ' + i); }
}

function wizTyped() {    // Import beside a path typed: that file is imported at once
    var typed = !wiz || pathField.hidden ? '' : pathField.stringValue.js.trim();
    if (!free || !typed) return;
    wiz.from = 'profile'; wiz.step = 'wait'; wiz.waiting = 'Importing.';
    wizardShown();
    sent('import path ' + typed.replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 1000));
}

function allowWords(label) { return 'Choose Allow to let LZRBRWSR try to read ' + label + "'s bookmarks."; }

function wizAsk(key, folder) {    // macOS kept the reader out: the browser's own folder in the Open panel, whose Allow is the one consent macOS takes for it short of Full Disk Access
    if (!wiz || key != wiz.key || folder.charAt(0) != '/') return;
    if (!modalOpen || modalKind != 'wizard') return wizClosed();    // the wizard is not on the window: no panel opens for it
    wiz.step = 'wait';
    wiz.waiting = allowWords(wiz.label);
    wizardShown();
    allowPanel(folder, wiz.waiting, function (path) { wizAllowed(key, path); }, function (how) { wizAllowed(key, '', how); });
}

function wizClosed() {    // the wizard closed (Cancel, or another modal in its place): nothing lzrprf says of this import later opens it or a panel again, and lzrprf drops an Open panel it asked for
    if (!wiz) return;
    wiz = null;
    say('import cancel');
}

function allowPanel(folder, words, then, unshown) {    // the system's Open panel on the window: at that folder, one folder and no file, its button "Allow"; unshown("failed") when it could not be shown, unshown("at-once") when it closed before anyone could choose, which is how a panel the window's container does not allow may end
    var opened = Date.now();
    try {
        var panel = $.NSOpenPanel.openPanel;
        panel.canChooseDirectories = true;
        panel.canChooseFiles = false;
        panel.allowsMultipleSelection = false;
        panel.canCreateDirectories = false;
        panel.resolvesAliases = false;
        panel.prompt = $('Allow');
        panel.message = $(words);
        panel.directoryURL = $.NSURL.fileURLWithPathIsDirectory($(folder), true);
        panel.beginSheetModalForWindowCompletionHandler(win, function (answer) { if (answer != 1 && Date.now() - opened < 400) return unshown('at-once'); then(answer == 1 && !panel.URL.isNil() ? panel.URL.path.js : ''); });
    } catch (e) { unshown('failed'); }
}

function wizAllowed(key, path, unshown) {    // Allow sends the folder chosen, which lzrprf compares with the one it asked for; Cancel sends no folder, and a panel that could not be shown says how
    if (!wiz || key != wiz.key) return;
    wiz.waiting = 'Reading ' + wiz.label + '.';
    wizardShown();
    sent(path ? 'import allowed ' + key + ' ' + path.replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 1001) : 'import denied ' + key + (unshown ? ' ' + unshown : ''));
}

function wizBack() {
    if (!wiz) return;
    wiz.error = '';
    wiz.step = 'source';
    wiz.pick = -1;
    wizardShown();
}

function wizRows() {    // the choices of the step, two to a row
    if (!wiz) return [];
    var size = wizardView.frame.size, gap = 12, w = Math.floor((size.width - gap) / 2), rows = [];
    var items = wiz.step == 'source' ? wiz.sources : wiz.step == 'profile' ? wiz.profiles : [];
    items.forEach(function (one, i) { var r = Math.floor(i / 2); if ((r + 1) * (WIZ_ROW + 10) - 10 <= size.height) rows.push({ i: i, x: (i % 2) * (w + gap), y: r * (WIZ_ROW + 10), w: w, h: WIZ_ROW }); });
    return rows;
}

function monogram(one, cx, cy, colour, hot) {    // a browser's mark: its first letter in a ring of the beam; a file a sheet with a folded corner
    if (one.key == 'file') {
        var p = $.NSBezierPath.bezierPath;
        [[-6, 8], [2, 8], [7, 3], [7, -8], [-6, -8]].forEach(function (o, i) { var at = $.NSMakePoint(cx + o[0], cy - o[1]); if (i) p.lineToPoint(at); else p.moveToPoint(at); });
        p.closePath; p.moveToPoint($.NSMakePoint(cx + 2, cy - 8)); p.lineToPoint($.NSMakePoint(cx + 2, cy - 3)); p.lineToPoint($.NSMakePoint(cx + 7, cy - 3));
        return stroked(p, colour, 1.3, hot ? GREEN : null, 5);
    }
    stroked($.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(cx - 12, cy - 12, 24, 24)), colour, 1.2, hot ? GREEN : null, 5);
    var letter = styled(one.name.charAt(0), inked(sans(12.5, true), colour)), size = letter.size;
    letter.drawAtPoint($.NSMakePoint(cx - size.width / 2, cy - size.height / 2));
}

function paintWizard() {
    if (!wiz) return;
    var size = wizardView.frame.size, s = wiz.step;
    if (s != 'source' && s != 'profile') return;
    if (s == 'profile' && !wiz.profiles.length) return $('No file was found in Downloads, Desktop or Documents.').drawInRectWithAttributes($.NSMakeRect(4, 4, size.width - 8, 60), inked(sans(13), GREY));
    wizRows().forEach(function (row) {
        var one = s == 'source' ? wiz.sources[row.i] : { name: wiz.profiles[row.i].name, sub: wiz.profiles[row.i].sub, key: wiz.key == 'file' ? 'file' : 'profile' };
        var picked = row.i == wiz.pick, hot = hover.wiz == row.i, card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(row.x + 0.5, row.y + 0.5, row.w - 1, row.h - 1), 11, 11);
        $.NSGraphicsContext.saveGraphicsState;
        if (picked) glow(GREEN, 10);
        FILL.setFill;
        card.fill;
        $.NSGraphicsContext.restoreGraphicsState;
        if (picked || hot) glass(card, true);
        stroked(card, picked ? GREEN : hot ? DIM : LINE, picked ? 1.3 : 1);
        $.NSGraphicsContext.saveGraphicsState;
        var turn = $.NSAffineTransform.transform;    // the view is flipped: the marks are drawn the right way up
        turn.translateXByYBy(0, 2 * row.y + row.h);
        turn.scaleXByYBy(1, -1);
        turn.concat;
        monogram({ key: one.key, name: one.name || '?' }, row.x + 30, row.y + row.h / 2, picked ? GREEN : ICON, picked);
        $.NSGraphicsContext.restoreGraphicsState;
        var sub = s == 'profile' ? (wiz.key == 'file' ? 'A bookmarks file' : one.sub || wiz.label) : one.key == 'file' ? 'Exported by a browser' : 'On this Mac';
        $(one.name).drawInRectWithAttributes($.NSMakeRect(row.x + 54, row.y + 9, row.w - 64, 19), inked(sans(13.5, true), WHITE, true));
        $(sub).drawInRectWithAttributes($.NSMakeRect(row.x + 54, row.y + 29, row.w - 64, 17), inked(sans(11.5), GREY, true));
    });
}

function wizAt(event) {
    var at = pointIn(wizardView, event), rows = wizRows();
    for (var k = 0; k < rows.length; k++) if (at.x >= rows[k].x && at.x < rows[k].x + rows[k].w && at.y >= rows[k].y && at.y < rows[k].y + rows[k].h) return rows[k].i;
    return -1;
}

function wizClicked(event) {
    var i = wizAt(event);
    if (i < 0 || !wiz) return;
    wiz.pick = i;
    wizardView.needsDisplay = true;
    wizChose(i);
}

// The modal: centred over the whole window, over a veil that takes every click, so nothing under
// it, the page or the chrome, is reached while it is open. Kinds: small, tall (a redirect), form
// (a bookmark), big (the installer).
// Tor, on one click [C17]. The onion is grey while Tor is off; a window that is not a Tor window asks lzrprf for one apart.
// The Tor window opens first, and only once it is on the screen ("torsession connecting", torShown) its modal flies out of
// the onion: five stations on one beam, each lit as the client's own log says it got there ("tor step N PERCENT WORDS"),
// a pulse running to the next, its words and share under the beam. "tor on" flares the last station and the modal stays:
// OK closes it, Stop Tor asks lzrprf, whose question stands in the modal (torAsked); Cancel returns here, Stop Tor shows
// the stop on a beam of its own, each station lit as lzrprf says its step is done, at most one each TOR_SEEN so each is
// seen, and the window closes after the last (torPaced). "tor failed WHY" stops the pulse in yellow and says why; nothing
// is fetched until Tor connects. With Reduce motion on, nothing pulses or flares: the stations still light.
var TOR_STATIONS = ['Directory', 'Certificates', 'Relays', 'Circuits', 'Ready'], TOR_STOPS = ['Tabs', 'Data', 'Tor', 'Window'], TOR_STOP_WORDS = ['Closing all tabs', 'Removing what the window held', 'Disconnecting Tor', 'Closing the window', 'The window is closed'], TOR_RUN = 0.9, TOR_BEAT = 1.4, TOR_FLARE = 0.9, TOR_QUIET = 95, TOR_SEEN = 0.35;    // DECLARED(seconds: a pulse from one station to the next; one breath of the onion while it connects; the flare of the last station on ready; how long the onion breathes after lzrprf last said a step, longer than lzrprf's $TOR_SECONDS, so a word that never came cannot keep it breathing; and the least a stop station stands lit before the next, so a stop done in milliseconds is still seen step by step)
function wordsPlaced() {    // lzrprf's words along the strip, in the room the icons leave
    if (!words || !root) return;
    words.frame = $.NSMakeRect(20, 6, Math.max(1, root.frame.size.width - 168), 17);
}

var torState = 'off', torStep = 0, torPct = 0, torWords = '', torLitAt = 0, torTimer = null, torIcon = null, torView = null, TOR_BLUE, torAsking = false, torHeld = false, torQueue = [], torPacing = false;
function torPressed() { if (modalOpen) return; if (!TORWINDOW) { say('tor on'); words.stringValue = $(TOR_APART); return; } if (torState == 'off') torStarted(); torShown(); }    // [C17] a window that is not a Tor window: lzrprf opens one apart from it, and this one stays as it was
function torShown() {    // [C17] the Tor modal, only in a Tor window already on the screen: while it is not, or another modal stands, it is looked at again a moment later
    if (!TORWINDOW || modalOpen && modalKind == 'tor') return;
    if (!win.visible || modalOpen) { if (torState == 'starting') hand.performSelectorWithObjectAfterDelay('torShown:', $(), 0.1); return; }
    techHidden(); secureHidden(); suggestHidden();
    flyNext = { icon: torIcon, at: Date.now() };
    modal(torTitle(), '', torChoices(), 'tor');
    torTicking();
}
function torTitle() { return { starting: 'Connecting to Tor', on: 'Tor is ready', failed: 'Tor did not connect', stopping: 'Stopping Tor' }[torState] || 'Tor'; }
function torChoices() { return torAsking || torState == 'stopping' ? [] : [['Stop Tor', torStopAsked], torState == 'on' ? ['OK', closeModal] : torState == 'failed' ? ['Try again', tnnlAgain] : ['Hide', closeModal]]; }    // no button while lzrprf is asked or the stop runs
function torStarted() { torState = 'starting'; torStep = 0; torPct = 0; torWords = 'Starting the Tor client'; torLitAt = Date.now(); say('tor on'); torChanged(); }
function torStopAsked() { torAsking = true; say('tor off'); torChanged(); }    // lzrprf asks first (sub tor_session_asked), and its question stands in this modal
var torAskNumber = 0;
function torAskCancelled() {    // ticket 1535: a tab pressed while lzrprf's "Stop Tor?" stands answers it with its first button, Cancel, so the question never holds the tabs
    if (!torAsking || !torAskNumber) return false;
    torAsking = false; say('button ' + torAskNumber + ' 1'); torAskNumber = 0;
    return true;
}
function torAsked(parts) {    // [C17] lzrprf's question of Stop Tor, in the modal: its first button (Cancel) returns to the modal of Tor, its second (Stop Tor) shows the stop
    var number = asked; torAskNumber = number;
    var answer = function (i) { return function () {
        torAsking = false; torAskNumber = 0; say('button ' + number + ' ' + i);
        if (i == 2) { torState = 'stopping'; torStep = 0; torHeld = false; torWords = TOR_STOP_WORDS[0]; torLitAt = Date.now(); }
        modal(torTitle(), '', torChoices(), 'tor'); torChanged(); }; };
    modal('Stop Tor?', parts[0], parts.slice(1).map(function (title, i) { return [title, answer(i + 1)]; }), 'small');
}
// lzrprf's own questions (the report of a page the window could not draw, and every other ask) stand in the modal
// every other box of the window uses, not in the black strip at the bottom (Henry, 2026-11-27, ticket 1535). The
// title is the words up to their first question mark, the rest the words under it. A press answers as the strip's
// buttons did; a tab closed or a page asked for while it stands answers it with its first button, the answer when
// nobody answers, so no box holds the window (askAnswered, from the tab strip and the bar).
var askNumber = 0;
function askModal(parts) {
    var words = parts[0] || '', q = words.indexOf('?'), number = asked;
    var title = q > 0 && q < 160 ? words.slice(0, q + 1) : 'LZRBRWSR', about = q > 0 && q < 160 ? words.slice(q + 1).trim() : words;
    askNumber = number;
    asking = true; free = false; bar.enabled = false;
    var answer = function (i) { return function () { askAnswered(i); }; };
    modal(title, about, parts.slice(1).filter(function (t) { return t; }).map(function (t, i) { return [t, answer(i + 1)]; }), 'ask');
}
function askAnswered(i) {    // true when a question stood and is answered now
    if (!askNumber || askNumber != asked) { askNumber = 0; return false; }
    askNumber = 0; asking = false;
    if (modalOpen && modalKind == 'ask') closeModal();
    strip(['']); say('button ' + asked + ' ' + (i || 1));
    return true;
}

function torTold(rest) {
    var parts = rest.split(' '), word = parts[0];
    if (torState == 'stopping') return;    // the stop is lit by the steps of the window's end alone (torSessionTold)
    if (word == 'step') { torState = 'starting'; torStep = +parts[1] || 0; torPct = +parts[2] || 0; torWords = parts.slice(3).join(' '); torLitAt = Date.now(); }
    else if (word == 'on') { torState = 'on'; torStep = TOR_STATIONS.length; torPct = 100; torWords = 'Connected to Tor'; torLitAt = Date.now(); }    // the last station flares and the modal stays, with OK and Stop Tor
    else if (word == 'off') { torState = 'off'; torStep = 0; torPct = 0; torWords = ''; if (modalOpen && modalKind == 'tor') closeModal(); }
    else if (word == 'failed') { torState = 'failed'; torWords = parts.slice(1).join(' '); }
    torChanged();
}
function torSessionTold(rest) {    // [C17] the step of the Tor window lzrprf is at: said along the strip, and in a stop lit on its beam
    var parts = rest.split(' '), step = parts[0], said = { connecting: 'Connecting to Tor: nothing is fetched until it is connected and this window reaches nothing past it.', browsing: 'This Tor window reaches nothing past Tor.', closing: 'Closing the Tor window: nothing more is fetched.', ended: 'Its pages have ended.', wiped: 'All it held is removed.', released: 'The Tor window is closed and Tor is released.', held: 'Not all of the Tor window was gone: Tor is held until the window is closed.' }[step];
    if (said && words) words.stringValue = $(said);
    if (step == 'connecting') { if (torState == 'off') { torState = 'starting'; torWords = 'Starting the Tor client'; torLitAt = Date.now(); torChanged(); } torShown(); }    // the window is on the screen: only now its modal opens
    if (torState == 'stopping') torPaced({ ended: 1, checked: parts[1] == '0' && parts[2] == '0' ? 2 : undefined, released: 3, held: -1 }[step]);
}
function torPaced(step) {    // [C17] a stop step lzrprf said is done, lit in its order and never before it is said; the window closes once the last stood TOR_SEEN
    if (step !== undefined) torQueue.push(step);
    if (torPacing || !torQueue.length) return torPacing || torStep < TOR_STOPS.length || app.terminate(win);
    var next = torQueue.shift();
    if (next < 0) torHeld = true; else { torStep = Math.max(torStep, next); torWords = TOR_STOP_WORDS[torStep]; }
    torLitAt = Date.now(); torPacing = true; torChanged();
    hand.performSelectorWithObjectAfterDelay('torPaced:', $(), TOR_SEEN);
}
function torGone() { if (torState != 'stopping') return app.terminate(win); torPaced(TOR_STOPS.length); }    // lzrprf behind ended: in a stop, the last station (the window) is lit, then it closes
function torChanged() {
    if (torIcon) torIcon.toolTip = $(torState == 'on' ? 'Tor: on, every page goes through Tor' : torState == 'starting' ? 'Tor: connecting' : torState == 'failed' ? 'Tor: did not connect' : torState == 'stopping' ? 'Tor: stopping' : 'Tor: off');
    if (modalOpen && modalKind == 'tor') { panelTitle.stringValue = $(torTitle()); buttons(torChoices()); }
    torTicking();
    torRedrawn();
}
function torRedrawn() { if (torIcon) torIcon.needsDisplay = true; if (torView) torView.needsDisplay = true; }
function torMoving() { return flightAllowed() && !!win && (win.occlusionState & 2) != 0 && ((torState == 'starting' || torState == 'stopping') && Date.now() - torLitAt < TOR_QUIET * 1000 || Date.now() - torLitAt < TOR_FLARE * 1000); }    // 2: the window is seen; an animation nobody sees costs nothing
function torTicking() {
    if (torTimer || !torMoving()) return;
    torTimer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1 / 30, hand, 'torTick:', $(), true);
}
function torTicked() { torRedrawn(); if (!torMoving() && torTimer) { torTimer.invalidate; torTimer = null; } }
function torGlyph(cx, cy) {    // an onion: its outer skin, one layer inside, and its shoot (the button is flipped: y grows down, so y is turned here)
    var p = $.NSBezierPath.bezierPath, at = function (x, y) { return $.NSMakePoint(cx + x, cy - y); };
    p.moveToPoint(at(0, 6));
    p.curveToPointControlPoint1ControlPoint2(at(0, -7.5), at(8.5, 0.5), at(7.5, -7.5));
    p.curveToPointControlPoint1ControlPoint2(at(0, 6), at(-7.5, -7.5), at(-8.5, 0.5));
    p.moveToPoint(at(0, 2.5));
    p.curveToPointControlPoint1ControlPoint2(at(0, -7.5), at(4.5, -1.5), at(3.8, -7.5));
    p.curveToPointControlPoint1ControlPoint2(at(0, 2.5), at(-3.8, -7.5), at(-4.5, -1.5));
    p.moveToPoint(at(0, 6));
    p.curveToPointControlPoint1ControlPoint2(at(2.5, 9), at(0.5, 8), at(1.5, 9));
    return p;
}
function torIconDrawn(view) {
    var size = view.frame.size, cx = size.width / 2, cy = size.height / 2, hot = hover.torIcon && !modalOpen;
    if (hot) glass($.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1, 1, size.width - 2, size.height - 2), 7, 7), true);
    if (torState == 'on') return stroked(torGlyph(cx, cy), TOR_BLUE, 1.4, TOR_BLUE, 9);    // on: the blue glow
    if (torState == 'failed') return stroked(torGlyph(cx, cy), YELLOW, 1.3, null, 0);
    if (torState == 'starting' || torState == 'stopping') {    // connecting or stopping: the onion breathes in blue
        var beat = flightAllowed() ? 0.5 + 0.5 * Math.sin(Date.now() / 1000 * 2 * Math.PI / TOR_BEAT) : 0.5;
        return stroked(torGlyph(cx, cy), TOR_BLUE.colorWithAlphaComponent(0.4 + 0.6 * beat), 1.3, beat > 0.6 ? TOR_BLUE : null, 4 + 5 * beat);
    }
    stroked(torGlyph(cx, cy), hot ? WHITE : GREY, 1.3, hot ? GREEN : null, 7);    // off: grey
}
function torBeamDrawn(view) {
    var size = view.bounds.size, w = size.width, h = size.height, now = Date.now(), moving = flightAllowed();
    var stopping = torState == 'stopping', stations = stopping ? TOR_STOPS : TOR_STATIONS, colour = torState == 'failed' || torHeld ? YELLOW : TOR_BLUE, n = stations.length, left = 46, right = w - 46, gap = (right - left) / (n - 1), y = Math.round(h * 0.58), R = 7;
    var lit = Math.min(n - 1, torStep - 1), next = torState == 'starting' || stopping ? lit + 1 : -1, xs = stations.map(function (one, i) { return left + gap * i; });
    centred(styled(stopping ? 'Every tab of this window closes and all it held is removed; then Tor is disconnected.' : 'Every page goes through three Tor relays, so a site sees a Tor exit and never this computer.', inked(sans(12), GREY)), w / 2, h - 22, 0);
    centred(styled(stopping ? 'The window closes last.' : 'It does not hide what you type into a site you sign in to.', inked(sans(12), GREY)), w / 2, h - 40, 0);
    var line = function (from, to, c, width, halo, blur) { var p = $.NSBezierPath.bezierPath; p.moveToPoint($.NSMakePoint(from, y)); p.lineToPoint($.NSMakePoint(to, y)); stroked(p, c, width, halo, blur); };
    line(left, right, EDGE, 1.2, null, 0);    // the beam, the whole way, unlit
    if (lit >= 0) line(left, xs[lit], colour, 1.6, colour, 8);    // lit up to the last station reached
    if (next >= 0 && next < n && moving) {    // the pulse, running from the last station reached to the one the client works on
        var from = lit >= 0 ? xs[lit] : left - 30, t = (now / 1000 % TOR_RUN) / TOR_RUN, e = 1 - Math.pow(1 - t, 2), x = from + (xs[next] - from) * e;
        var trail = $.NSGradient.alloc.initWithStartingColorEndingColor(colour.colorWithAlphaComponent(0), colour);
        trail.drawInRectAngle($.NSMakeRect(Math.max(from, x - 46), y - 1, Math.max(1, x - Math.max(from, x - 46)), 2), 0);
        $.NSGraphicsContext.saveGraphicsState; glow(colour, 10); colour.setFill; $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(x - 3, y - 3, 6, 6)).fill; $.NSGraphicsContext.restoreGraphicsState;
    }
    xs.forEach(function (x, i) {
        var dot = $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(x - R, y - R, 2 * R, 2 * R)), reached = i <= lit;
        $.NSGraphicsContext.saveGraphicsState; FILL.setFill; dot.fill; $.NSGraphicsContext.restoreGraphicsState;
        if (reached) {
            $.NSGraphicsContext.saveGraphicsState; glow(colour, 9); colour.colorWithAlphaComponent(0.85).setFill; $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(x - R + 3, y - R + 3, 2 * R - 6, 2 * R - 6)).fill; $.NSGraphicsContext.restoreGraphicsState;
            stroked(dot, colour, 1.3, colour, 6);
        }
        else if (i == next) stroked(dot, colour.colorWithAlphaComponent(moving ? 0.35 + 0.45 * (0.5 + 0.5 * Math.sin(now / 1000 * 2 * Math.PI / TOR_BEAT)) : 0.6), 1.3, null, 0);    // the station being worked on breathes
        else stroked(dot, EDGE, 1.2, null, 0);
        if (i == n - 1 && torState == 'on' && moving && now - torLitAt < TOR_FLARE * 1000) {    // ready: the last station flares
            var f = (now - torLitAt) / 1000 / TOR_FLARE, ring = R + 22 * (1 - Math.pow(1 - f, 3));
            stroked($.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(x - ring, y - ring, 2 * ring, 2 * ring)), colour.colorWithAlphaComponent(1 - f), 1.6, colour, 12);
        }
        centred(styled(stations[i], inked(sans(11, reached), reached ? WHITE : GREY)), x, y - R - 22, 0);
    });
    var said = torState == 'failed' ? 'Tor did not connect: ' + torWords : torWords + (torState == 'starting' || torState == 'on' ? '   ' + torPct + '%' : '');
    if (said) centred(styled(said, inked(sans(14, true), torState == 'failed' || torHeld ? YELLOW : WHITE)), w / 2, 12, 0);
}

function modal(title, about, choices, kind) {
    welcoming = false;
    installState = '';
    webWarningHidden();    // set again by installTold when this modal is the installer's
    cogHidden();
    modalOpen = true;
    modalKind = kind;
    panelTitle.stringValue = $(title);
    panelTitle.textColor = WHITE;
    panelSub.stringValue = $(about);
    panelSub.textColor = WHITE;
    panelSub.hidden = kind == 'tech' || kind == 'tor' || kind == 'tool';    // the list says its own first sentence; Tor's beam says its own words
    torView.hidden = kind != 'tor';
    toolScroll.hidden = kind != 'tool';
    toolCopy.hidden = kind != 'tool';
    procsEnabled();
    toolTabs.forEach(function (one) { one.hidden = kind != 'tool'; });
    permitCopy.hidden = kind != 'permit';
    permitCopy.title = $(PERMIT_COPY_WORDS);
    panelText.string = $('');
    panelScroll.hidden = kind != 'big' && kind != 'permit';
    form.hidden = kind != 'form';
    engineField.hidden = kind != 'engine';
    licenceField.hidden = kind != 'licence';
    profileField.hidden = kind != 'profile';
    supportScroll.hidden = kind != 'support';
    supportTick.hidden = kind != 'support';
    supportPreview.hidden = true;
    wizardView.hidden = kind != 'wizard'; partsShown(kind);
    pathField.hidden = true;
    veil.hidden = false;
    secureHidden();
    techHidden();
    suggestHidden();
    bar.enabled = false;
    logs.enabled = false;
    win.makeFirstResponder($());
    redrawn();
    buttons(choices);
    flyOut();
}

// A modal has a way out from the keyboard. Return (and Enter) presses its button where it has one alone (Got it,
// Close, Cancel). Escape presses the one that closes it or steps back (Cancel, Close, Got it, Hide, Back, OK), and in
// lzrprf's own questions (Scripts, Redirect) their first, the answer when nobody answers. Return never presses one
// of several buttons: there the last can grant (Always Allow), clear (Proceed) or choose (a search engine), which
// no key pressed by habit may do. The installer's modal while it runs has no button and no key. A view of no
// size in the veil hears the two keys (LzrprfKeys), so they work while the veil is up and never otherwise, and in
// a window that is not in front too, where a button hears no key of its own.
var MODAL_ESCAPES = ['Cancel', 'Close', 'Got it', 'Hide', 'Back', 'OK', 'Later'], modalEscape = -1, modalKeys = null;
function modalKeyed(event) {
    if (!modalOpen || !veil || veil.hidden || (event.modifierFlags & (CMD | CONTROL | OPTION))) return false;
    var code = event.keyCode, which = (code == 36 || code == 76) && modalActions.length == 1 ? 0 : code == 53 ? modalEscape : -1;    // 36: Return, 76: Enter, 53: Escape
    var act = which >= 0 ? modalActions[which] : null;
    if (!act) return false;
    act();
    return true;
}

function buttons(choices) {
    panelButtons.forEach(function (one) { one.removeFromSuperview; });
    panelButtons = [];
    modalActions = [];
    modalEscape = -1;
    choices.forEach(function (choice, i) {
        var one = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 32));
        one.title = $(choice[0]);
        one.bezelStyle = 1;
        one.font = sans(13, i == choices.length - 1);
        if (choices.length == 1 || (modalKind == 'flag' && i == 0)) one.keyEquivalent = $('\r');    // Return presses it, and it is drawn as the button Return presses; [C28] on LZRDFNDR's page the first, Close the Tab or Cancel
        if (modalEscape < 0 && (isWebQuestion() ? choice[0] == 'Deny once' : modalKind == 'tall' || modalKind == 'flag' ? i == 0 : MODAL_ESCAPES.indexOf(choice[0]) >= 0)) modalEscape = i;
        if (modalKind == 'flag') { one.font = sans(13, i == 0); if (i == 0) one.bezelColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.55, 0.05, 0.05, 1); }    // [C28] the first is the primary one there
        else if (i == choices.length - 1 && choices.length > 1) one.bezelColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.05, 0.42, 0.52, 1);    // the step forward, in the beam's colour; the step back stays plain
        one.target = hand;
        one.action = 'modalPress:';
        one.tag = i;
        panel.addSubview(one);
        panelButtons.push(one);
        modalActions.push(choice[1]);
    });
    placeModal();
}

function closeModal() {
    if (!modalOpen) return;
    if (modalKind == 'wizard') wizClosed();
    var back = flyBack();    // before anything in the panel changes, so the picture that flies is the panel as it was
    if (techOpen) { techOpen = false; under.hidden = true; }
    modalOpen = false;
    webWarningHidden();
    veil.hidden = !back;
    bar.enabled = free;
    logs.enabled = free || listing == 'log';
    redrawn();
    if (free) win.makeFirstResponder(bar);
}

// A modal opened from an icon of the bottom bar flies out of that icon into its place, and back
// into it when it closes, so the eye sees where it came from and where it went. One picture of the
// panel is taken once the modal is laid out and drawn larger (or smaller) each frame, eased, for
// FLIGHT_SECONDS; the panel itself is hidden meanwhile. Nothing grows faint: the picture is whole the whole
// way, and the veil is there from the first frame to the last. Every icon of the
// bar flies the same way: a press names its icon in flyNext, and the modal that opens within
// FLIGHT_ASKED milliseconds takes it. With Reduce motion on, nothing flies. A frame that fails ends
// the flight, so its timer never outlives it.
var FLIGHT_SECONDS = 0.16, FLIGHT_ASKED = 3000, flyNext = null, modalFrom = null, flight = null, flyer;    // DECLARED(0.16 s: ten frames at 60 a second, a movement the eye follows and never waits for)
function boxOf(rect) { return { x: rect.origin.x, y: rect.origin.y, w: rect.size.width, h: rect.size.height }; }
function flightAllowed() { return !$.NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion; }
function flyOut() {
    var asked = flyNext && Date.now() - flyNext.at < FLIGHT_ASKED ? flyNext.icon : null, box = asked && flyNext.box;    // box: where a row of a panel the modal closed stood when it was pressed
    flyNext = null;
    modalFrom = asked && (box || !asked.hidden) ? asked : null;
    if (!modalFrom || !flightAllowed()) return flightEnded();
    flightBegun(box || boxOf(modalFrom.frame), boxOf(panel.frame), true);    // the picture is taken at the first frame, once the caller has laid the panel out
}
function firstFlown() { if (flight && flight.opening && !flight.began) flew(Date.now()); }    // H-0072: the first frame in the press's own turn, once laid out: the timer's first beat came 50 to 250 ms late behind lzrprf's lines, and the panel stood unflown meanwhile
function flyBack() {
    if (flight && !flight.opening) return true;
    var to = modalFrom;
    modalFrom = null;
    if (!to || to.isHiddenOrHasHiddenAncestor || !flightAllowed() || !veil || veil.hidden) { flightEnded(); return false; }
    flightBegun(boxOf(panel.frame), boxOf(to.frame), false);
    flew(Date.now());    // the picture now, while the panel is as it was
    return true;
}
function flightBegun(from, to, opening) {
    if (flight) flight.timer.invalidate;
    if (!flyer) { flyer = $.NSImageView.alloc.initWithFrame($.NSMakeRect(0, 0, 10, 10)); flyer.imageScaling = 1; flyer.imageFrameStyle = 0; }
    flyer.removeFromSuperview;
    root.addSubview(flyer);    // last, over the veil
    flyer.hidden = true;
    flight = { from: from, to: to, opening: opening, began: 0, timer: $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1 / 60, hand, 'flown:', $(), true) };
}
function flew(now) {
    if (!flight) return;
    if (!flight.began || flight.coarse) {    // the first frame: the panel's picture, then the panel goes clear
        var r = panel.bounds, k = flight.opening && !flight.began ? 0.25 : 1, rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel($(), Math.ceil(r.size.width * k), Math.ceil(r.size.height * k), 8, 4, true, false, $('NSCalibratedRGBColorSpace'), 0, 0);
        // H-0072: a picture at the screen's two pixels a point took 70 to 90 ms before anything moved. An opening flies a quarter picture (6 ms) while it is still small, then one pixel a point (19 ms) from the second frame; the picture only moves, and the panel itself ends it.
        rep.size = r.size; panel.hidden = false; panel.cacheDisplayInRectToBitmapImageRep(r, rep);
        var picture = $.NSImage.alloc.initWithSize(r.size); picture.addRepresentation(rep); flyer.image = picture;
        panel.hidden = true; flyer.hidden = false;
        flight.coarse = k < 1; flight.began = flight.began || now;
    }
    var t = Math.max(0, Math.min(1, (now - flight.began) / 1000 / FLIGHT_SECONDS));
    var e = flight.opening ? 1 - Math.pow(1 - t, 3) : t * t * t;    // out of the icon fast and settling; into it slowly, then quickly
    var a = flight.from, b = flight.to, at = function (one, two) { return one + (two - one) * e; };
    flyer.frame = $.NSMakeRect(at(a.x, b.x), at(a.y, b.y), Math.max(1, at(a.w, b.w)), Math.max(1, at(a.h, b.h)));
    if (t >= 1) flightEnded();
}
function flightEnded() {
    if (flight) flight.timer.invalidate;
    var was = flight;
    flight = null;
    if (flyer) flyer.hidden = true;
    if (!panel) return;
    panel.hidden = false;
    if (was && !was.opening) { veil.hidden = !modalOpen; redrawn(); }
}

function placeModal() {
    if (!veil) return;
    var all = root.frame, wide = all.size.width, high = all.size.height, M = 18, big = modalKind == 'big';    // M: the room around the panel its glow is drawn in
    var wizard = modalKind == 'wizard', tech = modalKind == 'tech', tor = modalKind == 'tor', w = Math.min(big || modalKind == 'permit' ? 780 : wizard ? 660 : tech ? TECH_WIDE : tor ? 640 : modalKind == 'tool' ? TOOL_WIDE : modalKind == 'support' ? 640 : 580, wide - 48), h = big ? Math.min(welcoming ? 820 : 560, high - 48) : modalKind == 'permit' ? Math.min(620, high - 48) : tech ? Math.min(TECH_HIGH, high - 48) : wizard ? Math.min(470, high - 48) : modalKind == 'form' ? 330 : modalKind == 'tall' ? 310 : modalKind == 'flag' ? 340 : modalKind == 'engine' || modalKind == 'licence' || modalKind == 'profile' ? 330 : modalKind == 'support' ? Math.min(620, high - 48) : tor ? 320 : modalKind == 'tool' ? Math.min(TOOL_HIGH, high - 48) : modalKind == 'modules' ? Math.min(400, high - 48) : modalKind == 'tnnl' ? Math.min(tnnlVpn ? 420 : 250, high - 48) : 230;
    veil.frame = $.NSMakeRect(0, 0, wide, high - TABS_HIGH);    // the tab strip stays free under every modal: a tab can always be chosen or closed (Henry, 2026-11-27, ticket 1535)
    panel.frame = $.NSMakeRect(Math.round((wide - w) / 2) - M, Math.round((high - h) / 2) - M, w + 2 * M, h + 2 * M);
    panel.needsDisplay = true;
    panelTitle.frame = $.NSMakeRect(M + 26, M + h - 52, w - 52, 28);
    panelSub.frame = big ? $.NSMakeRect(M + 26, M + h - 98, w - 52, 42) : wizard ? $.NSMakeRect(M + 26, M + h - 108, w - 52, 52) : modalKind == 'form' ? $.NSMakeRect(M + 26, M + h - 84, w - 52, 30) : modalKind == 'engine' || modalKind == 'licence' || modalKind == 'profile' ? $.NSMakeRect(M + 26, M + 112, w - 52, h - 172) : modalKind == 'support' ? $.NSMakeRect(M + 26, M + h - 196, w - 52, 136) : $.NSMakeRect(M + 26, M + 64, w - 52, h - 124);
    engineField.frame = $.NSMakeRect(M + 26, M + 68, w - 52, 26);
    licenceField.frame = $.NSMakeRect(M + 26, M + 68, w - 52, 26);
    profileField.frame = $.NSMakeRect(M + 26, M + 68, w - 52, 26);
    supportScroll.frame = $.NSMakeRect(M + 26, M + 210, w - 52, Math.max(60, h - 196 - 8 - 210));    // the box for the words, between what is sent and the picture
    supportTick.frame = $.NSMakeRect(M + 26, M + 62, w - 52, 22);
    supportPreview.frame = $.NSMakeRect(M + 26, M + 90, Math.min(200, w - 52), 112);
    var withPath = !pathField.hidden;
    pathField.frame = $.NSMakeRect(M + 26, M + 66, w - 52, 26);
    var more = 0;    // what the wizard says in yellow takes the room it needs from the list under it
    if (wizard && wiz && wiz.error) { var rows = 0; wiz.error.split('\n').forEach(function (line) { rows += Math.max(1, Math.ceil(line.length * 7 / (w - 52))); }); more = Math.max(0, Math.min(rows * 17 + 4 - 52, h - 64 - 116 - 60)); }
    if (more) { var sub = panelSub.frame; panelSub.frame = $.NSMakeRect(sub.origin.x, sub.origin.y - more, sub.size.width, sub.size.height + more); }
    wizardView.frame = $.NSMakeRect(M + 26, M + 64 + (withPath ? 38 : 0), w - 52, Math.max(40, h - 64 - 116 - more - (withPath ? 38 : 0)));
    panelScroll.frame = $.NSMakeRect(M + 26, M + 64, w - 52, Math.max(40, h - 170));
    if (modalKind == 'permit') {    // the question about scripts: its words at the top, the source of each script under them, the copy button left of the answers
        panelSub.frame = $.NSMakeRect(M + 26, M + h - 196, w - 52, 140);
        panelScroll.frame = $.NSMakeRect(M + 26, M + 64, w - 52, Math.max(40, h - 196 - 8 - 64));
    }
    if (permitCopy) permitCopy.frame = $.NSMakeRect(M + 26, M + 18, 150, 32);
    toolTabs.forEach(function (one, k) { var width = (w - 52) / toolTabs.length; one.frame = $.NSMakeRect(M + 26 + k * width, M + h - 92, width - 10, 28); });
    form.frame = $.NSMakeRect(M + 26, M + 64, w - 52, h - 154);
    torView.frame = $.NSMakeRect(M + 26, M + 64, w - 52, Math.max(40, h - 128));
    toolCopy.frame = $.NSMakeRect(M + 26, M + 62, Math.min(w - 52, 380), 32);    // above the panel's own buttons, which already fill their row
    toolScroll.frame = $.NSMakeRect(M + 26, M + 104, w - 52, Math.max(40, h - 204));
    if (modalKind == 'tool') toolSized();
    if (tech) {    // the list fills the panel between its title and its Close button
        var listHigh = Math.max(40, h - 134);
        under.frame = $.NSMakeRect(M + 26, M + 64, w - 52, listHigh);
        made.textContainer.containerSize = $.NSMakeSize(w - 68, 100000);
        made.layoutManager.ensureLayoutForTextContainer(made.textContainer);
        made.setFrameSize($.NSMakeSize(w - 52, Math.max(listHigh, made.layoutManager.usedRectForTextContainer(made.textContainer).size.height + 12)));
    }
    var fw = w - 52 - 90;
    [[nameLabel, nameField], [addressLabel, addressField], [folderLabelView, folderPop]].forEach(function (row, i) {
        var y = h - 154 - 34 - i * 40;
        row[0].frame = $.NSMakeRect(0, y + 4, 84, 20);
        row[1].frame = $.NSMakeRect(90, y, i == 2 ? Math.min(fw, 260) : fw, 26);
    });
    newFolderField.frame = $.NSMakeRect(90 + Math.min(fw, 260) + 10, h - 154 - 34 - 80, Math.max(80, fw - Math.min(fw, 260) - 10), 26);
    var x = M + w - 26;
    for (var i = panelButtons.length - 1; i >= 0; i--) {
        var bw = Math.max(96, panelButtons[i].title.js.length * 8 + 34);
        x -= bw;
        panelButtons[i].frame = $.NSMakeRect(x, M + 18, bw, 32);
        x -= 10;
    }
    webQuestionPlaced(M, w, h);
    procsPlaced(M, w);
}

function paintPanel() {
    var size = panel.frame.size, box = $.NSMakeRect(18, 18, size.width - 36, size.height - 36), path = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(box, 16, 16);
    $.NSGraphicsContext.saveGraphicsState;
    glow(HALO, 20);
    $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.035, 0.045, 0.055, 0.98).setFill;
    path.fill;
    $.NSGraphicsContext.restoreGraphicsState;
    glass(path, true);
    stroked(path, GREEN, 1.2, GREEN, 5);
}

function paintBack() {    // behind lzrprf's strip at the bottom: a faint line over it
    var size = stripBack.frame.size;
    $.NSColor.colorWithWhiteAlpha(1, 0.06).setStroke;
    $.NSBezierPath.strokeLineFromPointToPoint($.NSMakePoint(0, size.height - 0.5), $.NSMakePoint(size.width, size.height - 0.5));
}

// A redirect, as lzrprf asks about it: "redirect STATUS<tab>FROM<tab>TO<tab>BUTTONS...". A press
// answers lzrprf's question by its number, as a button of the strip does.
// [C26] lzrprf's question about the scripts of the page shown, once it is drawn: "permitscript I<tab>NAME<tab>inline|external<tab>
// BYTES<tab>WHO<tab>SHOWN<tab>SOURCE" for each script, its source as base64 of its first SHOWN bytes, then "permit SITE<tab>WORDS<tab>
// Deny Once<tab>Deny Always<tab>Allow Once<tab>Always Allow", in its own modal. Deny Once is the first button, the answer when nobody
// answers. The source of each script is shown under the words as plain text in a text view that is not editable: it is selected
// and copied as text, and nothing of it ever runs (no script engine is in this window). Its copy button writes it to the clipboard
// on a press, and nothing else does.
var permitScripts = [], permitShown = [], permitCopy = null, PERMIT_COPY_WORDS = 'Copy source';
function permitScriptTold(rest) {
    var f = rest.split('\t');
    if (f.length != 7 || !/^\d{1,2}$/.test(f[0])) return;
    if (f[0] == '0') permitScripts = [];
    permitScripts.push({ name: f[1], where: f[2], bytes: +f[3] || 0, who: f[4], shown: +f[5] || 0, source: f[6] ? sourceDecoded(f[6]) : '' });
}
function sourceDecoded(text) {    // base64 of a script's bytes, as text: UTF-8, else Latin-1, which reads any bytes
    var data = $.NSData.alloc.initWithBase64EncodedStringOptions($(text), 0);
    if (!data || data.isNil()) return '';
    var said = $.NSString.alloc.initWithDataEncoding(data, 4);
    if (!said || said.isNil()) said = $.NSString.alloc.initWithDataEncoding(data, 5);
    return said && !said.isNil() ? said.js : '';
}
function permitCodeText(scripts) {    // the code block: each script under a line naming it, and a line saying where its source was cut
    return scripts.map(function (one) {
        var about = [one.where].concat(one.bytes ? [one.bytes + ' bytes'] : [], one.who ? [one.who] : []).join(', ');
        return '// ' + one.name + ' (' + about + ')\n' + (one.shown ? one.source : '// lzrprf has no source of this script to show') + (one.shown && one.bytes > one.shown ? '\n// cut here: the first ' + one.shown + ' of its ' + one.bytes + ' bytes are shown' : '');
    }).join('\n\n');
}
function permitTold(rest) {
    asked++;
    permitLaterSet(null); var parts = rest.split('\t'); parts.essential = essentialScriptPrompt; essentialScriptPrompt = false;
    permitShow(parts, permitAsked = asked, permitShown = permitScripts);    // drawn by permitShow (28-window1-tabs.pl), which also minimizes it
    permitScripts = [];
}
function permitCopied() { if (modalOpen && modalKind == 'permit' && permitShown.length) permitCopy.title = $(clipboardWrite(permitCodeText(permitShown)) ? 'Copied' : 'Not copied'); }

// [C26] [C4] LZRDFNDR scripts (named Script permissions until release 77), a list page like the bookmarks: "scripts begin", "scripts rule N<tab>always|deny<tab>SITE<tab>
// CLASS<tab>ORIGIN<tab>SHA256<tab>CAPS<tab>DATE<tab>file|memory" for each rule of the person's (E3); "scripts e1 on|off" and
// "scripts sandbox NAME<tab>VERDICT<tab>WORDS" (E1); "scripts curated N<tab>on|off<tab>SITE<tab>CLASS<tab>ORIGIN<tab>IDENTITY<tab>
// CAPS<tab>REVIEWER<tab>DATE", "scripts part SITE<tab>used|ignored<tab>WHY" and "scripts curatedwhy WHY" (E2); "scripts seen
// LAYER<tab>SITE<tab>WHAT<tab>SAID<tab>COUNT", what E1 and E2 decided with no question; then "scripts end" or "scripts end unread", which shows it.
function scriptsTold(rest) {
    var gap = rest.indexOf(' '), word = gap < 0 ? rest : rest.slice(0, gap), f = gap < 0 ? [] : rest.slice(gap + 1).split('\t');
    if (rest == 'begin') { scriptRules = []; scriptLayers = { e1: 'off', sandbox: [], curated: [], parts: [], why: '', seen: [] }; return; }
    if (word == 'rule') { scriptRules.push({ n: +f[0], d: f[1], site: f[2], cls: f[3], origin: f[4], sha: f[5], caps: f[6], date: f[7], where: f[8] }); return; }
    if (word == 'e1') { scriptLayers.e1 = f[0]; return; }
    if (word == 'sandbox') { scriptLayers.sandbox.push({ name: f[0], said: f[1], words: f[2] || '' }); return; }
    if (word == 'curated') { scriptLayers.curated.push({ n: +f[0], on: f[1], site: f[2], cls: f[3], origin: f[4], id: f[5] || '', caps: f[6], reviewer: f[7], date: f[8] }); return; }
    if (word == 'part') { scriptLayers.parts.push({ site: f[0], said: f[1], why: f[2] || '' }); return; }
    if (word == 'curatedwhy') { scriptLayers.why = rest.slice(gap + 1); return; }
    if (word == 'seen') { scriptLayers.seen.push({ layer: f[0], site: f[1], what: f[2], said: f[3], count: f[4] }); return; }
    if (rest.slice(0, 3) != 'end') return;
    scriptsUnread = rest == 'end unread';
    if (listing == 'scripts') { listSized(); redrawn(); } else listOpened('scripts');
}

function scriptRows() {    // [C26] the rows of the page, under a heading for each layer, in the order lzrprf decides: the sandbox (E1), the curated rules (E2), the person's rules (E3)
    var rows = [{ heading: 'Sandbox (E1)' }, { layer: 'e1', word: scriptLayers.e1, name: 'Sandbox   ' + (scriptLayers.e1 == 'on' ? 'On' : 'Off'),
        sub: scriptLayers.e1 == 'on' ? 'A site with no rule of yours runs its own scripts in lzrprf\'s sandbox, which sends no POST, fetches nothing else of another origin, sends no cookie and keeps nothing' : 'Off: a site with no rule of yours runs no script until you allow it' }];
    scriptLayers.sandbox.forEach(function (b) { rows.push({ info: true, name: b.name + '   ' + b.said, sub: b.words }); });
    rows.push({ heading: 'Curated rules (E2)' });
    if (!scriptLayers.curated.length) rows.push({ info: true, name: 'No curated rule is used', sub: scriptLayers.why || 'The release names no curated rule' });
    scriptLayers.curated.forEach(function (c) { rows.push({ layer: 'curated', n: c.n, word: c.on, name: c.site + '   ' + (c.on == 'on' ? 'On' : 'Off'), sub: (c.origin == 'inline' ? 'in the page' : c.origin) + '   ' + (c.cls == 'strings' ? 'text into code (eval)' : 'its code') + '   ' + c.id.slice(0, 40) + '   ' + (c.caps == '-' ? 'no capabilities' : c.caps) + '   reviewed by ' + c.reviewer + ' ' + c.date }); });
    scriptLayers.parts.filter(function (p) { return p.said != 'used'; }).forEach(function (p) { rows.push({ info: true, name: p.site + '   ignored', sub: p.why }); });
    rows.push({ heading: 'Your rules (E3)' });
    if (scriptRules.length) rows.push({ reset: true, name: 'Reset all', sub: 'Removes every script permission of yours: each script is asked about again' });
    scriptRules.forEach(function (r) {    // each rule, as lzrprf told it
        rows.push({ rule: r.n, word: r.d, name: r.site + '   ' + (r.d == 'always' ? 'Always' : 'Deny'), sub: (r.origin == 'inline' ? 'in the page' : r.origin) + '   ' + (r.cls == 'strings' ? 'text into code (eval)' : 'its code') + '   ' + r.sha.slice(0, 12) + '   ' + (r.caps == '-' ? 'no capabilities' : r.caps) + '   ' + r.date + (r.where == 'memory' ? '   this window only' : '') });
    });
    if (scriptLayers.seen.length) rows.push({ heading: 'Decided with no question' });
    scriptLayers.seen.forEach(function (d) { rows.push({ info: true, name: d.site + '   ' + d.said + '   ' + d.layer.toUpperCase(), sub: d.what + (d.count > 1 ? '   ' + d.count + ' times' : '') }); });
    return rows;
}

function scriptPills(row) {    // a rule's three buttons at its right end: Always, Deny, Revoke; a switch's two: On, Off
    var words = row.rule !== undefined ? ['Always', 'Deny', 'Revoke'] : row.layer || row.flist !== undefined ? ['On', 'Off'] : row.fallow !== undefined ? ['Revoke'] : row.fseen !== undefined ? ['Allow'] : [];
    return words.map(function (word, k) { return { word: word, x: row.x + row.w - 16 - (words.length - k) * 72 + 8, y: row.y + 14, w: 64, h: 26 }; });
}

// [C27] [C4] Filters, a list page like LZRDFNDR scripts: "filters begin", "filters state on<tab>MS" or "filters state off<tab>WHY",
// "filters list N<tab>on|off<tab>NAME<tab>RULES<tab>SKIPPED", "filters commit HEX", "filters count KIND<tab>N", "filters allow
// N<tab>SITE<tab>HOST<tab>file|memory" and "filters seen N<tab>current|recent<tab>PAGE<tab>ADDRESS<tab>TYPE<tab>RULE<tab>LIST";
// then "filters end" or "filters end unread", which shows it.
function filtersTold(rest) {
    var gap = rest.indexOf(' '), word = gap < 0 ? rest : rest.slice(0, gap), f = gap < 0 ? [] : rest.slice(gap + 1).split('\t');
    if (rest == 'begin') { filterState = { on: false, why: '', ms: 0, lists: [], commit: '', counts: [], allow: [], seen: [], unread: false }; return; }
    if (word == 'state') { filterState.on = f[0] == 'on'; if (filterState.on) filterState.ms = +f[1]; else filterState.why = f[1] || ''; return; }
    if (word == 'list') { filterState.lists.push({ n: +f[0], on: f[1], name: f[2], rules: f[3], skipped: f[4] }); return; }
    if (word == 'commit') { filterState.commit = f[0] || ''; return; }
    if (word == 'count') { filterState.counts.push(f[0] + ' ' + f[1]); return; }
    if (word == 'allow') { filterState.allow.push({ n: +f[0], site: f[1], host: f[2], where: f[3] }); return; }
    if (word == 'seen') { filterState.seen.push({ n: +f[0], when: f[1], page: f[2], url: f[3], type: f[4], rule: f[5], list: f[6] }); return; }
    if (rest.slice(0, 3) != 'end') return;
    filterState.unread = rest == 'end unread';
    if (listing == 'filters') { listSized(); redrawn(); } else listOpened('filters');
}

function filterRows() {    // [C27] the rows of the page: the lists and where they came from, what you let through, the requests blocked on the page shown and before it
    var rows = [{ heading: 'Lists' }];
    if (!filterState.on) rows.push({ info: true, name: 'Nothing is filtered', sub: filterState.why });
    filterState.lists.forEach(function (l) { rows.push({ flist: l.n, word: l.on, name: l.name + '   ' + (l.on == 'on' ? 'On' : 'Off'), sub: l.rules + ' rules used, ' + l.skipped + ' lines not used' + (filterState.commit ? '   uAssets ' + filterState.commit.slice(0, 12) : '') }); });
    if (filterState.counts.length) rows.push({ info: true, name: 'Lines by kind' + (filterState.on ? '   read in ' + filterState.ms + ' ms' : ''), sub: filterState.counts.join(', ') });
    rows.push({ heading: 'Let through by you' });
    if (!filterState.allow.length) rows.push({ info: true, name: filterState.unread ? 'The file filterlayers is not read' : 'Nothing', sub: 'Allow on a blocked request lets its host through on its site' });
    filterState.allow.forEach(function (a) { rows.push({ fallow: a.n, name: a.host + '   on ' + a.site, sub: a.where == 'memory' ? 'this window only' : 'kept until you revoke it' }); });
    rows.push({ heading: 'Blocked' });
    if (!filterState.seen.length) rows.push({ info: true, name: 'Nothing blocked in this window', sub: 'Each blocked request shows here with the rule and the list that blocked it' });
    filterState.seen.forEach(function (b) { rows.push({ fseen: b.n, name: b.url, sub: (b.when == 'current' ? 'this page' : b.page) + '   ' + b.type + '   ' + b.rule + '   ' + b.list }); });
    return rows;
}

// [C28] LZRDFNDR's red page over the whole window: "flagged CATEGORY", with lzrprf's two buttons, Close the Tab
// (the first: Return, Escape and the time running out press it) and Report False Positive Anonymously. No button
// shows the page; the page under the veil is empty. "flagreport CATEGORY<tab>LIST<tab>CONFIDENCE<tab>PAGE<tab>HOST"
// shows the report whole before it is sent, with Cancel first and Send.
function flagTold(word, rest) {
    asked++;
    var parts = rest.split('\t'), number = asked;
    var answer = function (i) { return function () { closeModal(); say('button ' + number + ' ' + i); }; };
    if (word == 'flagged') modal('LZRDFNDR \u2014 CONTENT FLAGGED', 'This content has been blocked by LZRDFNDR because it was identified as potentially harmful or prohibited.\n\nDetected category: ' + parts[0], [['Close the Tab', answer(1)], ['Report False Positive Anonymously', answer(2)]], 'flag');
    else modal('Report False Positive Anonymously', 'This is the whole report. Nothing is sent until you press Send.\n\nCategory: ' + parts[0] + '\nList: ' + parts[1] + '\nConfidence: ' + parts[2] + '\nPage: ' + parts[3] + '\n\nIt goes to ' + parts[4] + '. It holds no address of yours, no history and nothing of the page, and the page is not opened again.', [['Cancel', answer(1)], ['Send', answer(2)]], 'flag');
    if (panelButtons[0]) win.makeFirstResponder(panelButtons[0]);
}

// The installer's run, as lzrprf tells it: "install begin", "install sum HEX", "install line C TEXT"
// (C one letter for a colour the installer asked for, or "-"), "install end done|failed WORDS".
// The modal has no button while it runs.
var INKS = { r: [1, 0.36, 0.36], g: [0, 1, 0.255], y: [1, 0.93, 0.25], b: [0.45, 0.65, 1], m: [1, 0.45, 1], c: [0.35, 1, 1], w: [1, 1, 1], '-': [0.78, 0.92, 0.8] };
function installTold(rest) {
    var gap = rest.indexOf(' '), word = gap < 0 ? rest : rest.slice(0, gap), more = gap < 0 ? '' : rest.slice(gap + 1);
    if (word == 'begin') { modal('Installing a newer release', 'The installer runs here by itself and asks nothing. This cannot be closed until it ends.', [], 'big'); installState = 'fetch'; }
    else if (!modalOpen || modalKind != 'big') return;
    else if (word == 'runs' || word == 'told') installState = word == 'told' && more.slice(-10) == ' undrained' ? 'runs' : word;    // the installer was started; lzrprf stops while it runs, and a process of its own reads its lines on, or none could be started (undrained)
    else if (word == 'sum') { var checksum = more.split('\t'); panelSub.stringValue = $('Installer SHA-256: ' + checksum[0] + (checksum[1] ? '\nCompare the install.sh entry at ' + checksum[1] : '')); }
    else if (word == 'line') installLine(more.slice(2), more.charAt(0));
    else if (word == 'end') {
        var done = more.slice(0, 5) == 'done ';
        installState = 'ended';
        panelTitle.stringValue = $(done ? 'The install is done' : 'The install failed');
        panelTitle.textColor = done ? WHITE : YELLOW;
        panelSub.stringValue = $(done ? 'The new release is in place. Close LZRBRWSR, or close it and start the new release now.' : 'Nothing more runs. What the installer printed is below, and kept in ~/.lzrprf/install.txt.');
        buttons(done ? [['Close', function () { app.terminate(win); }], ['Close and restart', function () { say('restart'); buttons([]); }]] : [['Close', closeModal]]);
    }
}

// The welcome after an install or update, as lzrprf tells it: "welcome begin RELEASE", then lines
// "welcome line K TEXT" (K: n what is new, g what is kept from you, y what is not, b one point under the
// last of them), then "welcome end", which gives the one button. Got it says "welcomed".
function welcomeTold(rest) {
    var gap = rest.indexOf(' '), word = gap < 0 ? rest : rest.slice(0, gap), more = gap < 0 ? '' : rest.slice(gap + 1);
    if (word == 'begin') { modal('Welcome to LZRBRWSR release ' + more, 'Once after every install or update: what is new, and what LZRBRWSR does and does not do for you.', [], 'big'); welcomeInk = GREEN; welcoming = true; placeModal(); }
    else if (!modalOpen || modalKind != 'big') return;
    else if (word == 'line') {
        var kind = more.charAt(0), text = more.slice(2), store = panelText.textStorage, heading = kind != 'b';
        if (heading) welcomeInk = kind == 'y' ? YELLOW : kind == 'n' ? CYAN_INK : GREEN;
        var one = styled((store.length ? (heading ? '\n\n' : '\n') : '') + (heading ? text : '\u2022  ' + text), inked(sans(heading ? 14 : 12.5, heading), heading ? welcomeInk : WHITE)), lines = $.NSMutableParagraphStyle.alloc.init;
        lines.headIndent = heading ? 0 : 14;    // a point that runs over a line goes on under its text, not under its dot
        lines.paragraphSpacing = heading ? 4 : 3;
        one.addAttributeValueRange($.NSParagraphStyleAttributeName, lines, $.NSMakeRange(0, one.length));
        store.appendAttributedString(one);
    }
    else if (word == 'end') { startupReady = true; if (startupRequested) shown(); panelText.scrollRangeToVisible($.NSMakeRange(0, 0)); buttons([['Got it', function () { closeModal(); say('welcomed'); }]]); }    // behind waits for this acknowledgement before it can make the home: its complete dialog must be visible first
}
// lzrprf behind this window is gone: the end of its pipe. From here on nothing is said to it (sub say). The window
// goes with it, except while the installer's modal is open and its install has not ended: then the modal says what is
// true of the installer, by what lzrprf said last, and keeps one button, Close, which ends the window. After the
// install's end the window goes too, as after "Close and restart", whose restart waits for the window to be gone.
var installState = '', behindEnded = false, BEHIND_GONE = {
    fetch: 'lzrprf behind this window ended before the installer ran. Nothing was changed.',
    runs: 'lzrprf behind this window ended while the installer ran. Nothing reads what it prints now, so it may stop at its next line; what it printed so far is in ~/.lzrprf/install.txt.',
    told: 'lzrprf behind this window ended. The installer goes on by itself, and each line it prints goes on into ~/.lzrprf/install.txt.'
};
function behindGone() {
    behindEnded = true;
    if (modalOpen && modalKind == 'tor') return torGone();    // [C17] a Tor window's stop: its last station is lit before it closes
    if (!(modalOpen && modalKind == 'big' && BEHIND_GONE[installState])) { app.terminate(win); return; }
    panelTitle.stringValue = $('lzrprf behind this window ended');
    panelTitle.textColor = YELLOW;
    panelSub.stringValue = $(BEHIND_GONE[installState]);
    installLine(BEHIND_GONE[installState], 'y');
    buttons([['Close', function () { app.terminate(win); }]]);
}
var welcomeInk = null, welcoming = false, CYAN_INK = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.35, 1, 1, 1);

function installLine(text, ink) {
    var rgb = INKS[ink] || INKS['-'], store = panelText.textStorage;
    store.appendAttributedString(styled((store.length ? '\n' : '') + text, inked(mono(11), $.NSColor.colorWithSRGBRedGreenBlueAlpha(rgb[0], rgb[1], rgb[2], 1))));
    panelText.scrollRangeToVisible($.NSMakeRange(store.length, 0));
}

// Where the pointer is, for the glow of what it is over; over the lock it also shows the lock's panel.
function hovered(view, event) {
    try { hoveredOver(view, event); } catch (e) { }    // a pointer move that cannot be followed only leaves the hover as it was: it never ends the window
}

function hoveredOver(view, event) {
    var was = JSON.stringify(hover);
    if (view == 'tabs') { hover.tab = event ? tabAt(event)[0] : -1; hover.dot = event ? dotAt(pointIn(tabsView, event)) : -1; }
    else if (view == 'marks') hover.mark = event ? markAt(event) : -1;
    else if (view == 'home') hover.home = event ? homeAt(event) : -1;
    else if (view == 'list') hover.list = event ? listAt(event) : -1;
    else if (view == 'cogmenu') { hover.cogRow = event ? cogRowAt(event) : -1; var why = hover.cogRow >= 0 ? cogItems()[hover.cogRow][4] : ''; cogBox.toolTip = why ? $(why) : $(); }
    else if (view == 'suggest') hover.suggest = event ? suggestAt(event) : -1;
    else if (view == 'wiz') hover.wiz = event ? wizAt(event) : -1;
    else if (view == 'belt') {
        var at = event ? pointIn(belt, event) : null, over = !!at && lockAt(at);
        hover.nav = at ? navAt(at) : -1;
        if (over != hover.lock && !securePinned) { if (over) secureShown(); else secureBox.hidden = true; }
        hover.lock = over;
    }
    else hover[view] = !!event;
    if (JSON.stringify(hover) != was) redrawn();
}

function tracked(view) { view.addTrackingArea($.NSTrackingArea.alloc.initWithRectOptionsOwnerUserInfo($.NSZeroRect, 0x1 | 0x2 | 0x80 | 0x200, view, $())); }    // entered and exited, moved, in front or not (Henry 2026-11-24: hovers need no focus), over the view as it is

function colour(hex) {
    if (!inks[hex]) inks[hex] = $.NSColor.colorWithSRGBRedGreenBlueAlpha(parseInt(hex.slice(0, 2), 16) / 255, parseInt(hex.slice(2, 4), 16) / 255,
        parseInt(hex.slice(4, 6), 16) / 255, hex.length > 6 ? parseInt(hex.slice(6, 8), 16) / 255 : 1);
    return inks[hex];
}

function face(flags, size, hex) {
    var key = flags + ' ' + size + ' ' + hex;
    if (!typefaces[key]) {
        var how = $.NSMutableDictionary.alloc.init, one = $.NSFont.fontWithNameSize($(named(flags & 1, flags & 2, flags & 4)), size);
        if (one.isNil()) one = $.NSFont.systemFontOfSize(size);
        how.setObjectForKey(one, $.NSFontAttributeName);
        how.setObjectForKey(colour(hex), $.NSForegroundColorAttributeName);    // a link too: the page chose its colour, and a white link on a blue button stays white
        if (flags & 8) how.setObjectForKey($.NSNumber.numberWithInt(1), $.NSUnderlineStyleAttributeName);
        if (flags & 16) how.setObjectForKey($.NSNumber.numberWithInt(1), $.NSStrikethroughStyleAttributeName);    // line-through (laid.rs looks 16)
        typefaces[key] = [how, one.ascender];
    }
    return typefaces[key];
}

// Red, green, blue and how opaque, a byte each, not multiplied by how opaque (alpha last in
// Core Graphics' words, 3): the rows are joined and given to the system as an image of that many
// pixels. No decoder reads them.
function picture(wide, high, rows) {
    var all = wide % 3 ? $.NSMutableData.dataWithCapacity(wide * high * 4) : $.NSData.alloc.initWithBase64EncodedStringOptions($(rows.map(function (row) { return row.slice(1); }).join('')), 0);    // a row of a width in threes ends in no "=", so the rows joined are one base64 text, decoded by one call to the system: row by row a front page's 18 pictures took 629 ms, joined 59 ms (measured 2026-11-25)
    if (all.isNil()) throw 'a picture is not base64'; if (wide % 3) rows.forEach(function (row) {
        var bytes = $.NSData.alloc.initWithBase64EncodedStringOptions($(row.slice(1)), 0);
        if (bytes.isNil()) throw 'a row of a picture is not base64';
        all.appendData(bytes);
    });
    if (rows.length != high || all.length != wide * high * 4) throw 'a picture is not as large as it says';
    return bitmap(all, wide, high);
}

// A tile: red, green and blue, a byte each, and no alpha, since a tile is opaque. Its rows have
// no "=", so joined they are one base64 text, decoded once: a handful of calls to the system for
// the tile, where a picture makes some for every row. Three bytes a pixel is not how the screen
// is drawn, though: such an image needs the graphics card to be taught a new step, and the
// teacher is a service the window's container does not reach, so the window would close the
// moment a tile came on the screen. The tile is therefore drawn once, on the processor, into
// the Mac's own form (blue, green, red, alpha, premultiplied: Core Graphics' 8194), the form
// every picture on the screen already comes in.
function tile(wide, high, rows) {
    var above = '', all = $.NSData.alloc.initWithBase64EncodedStringOptions($(rows.map(function (row) { return row.length > 1 ? (above = row.slice(1)) : above; }).join('')), 0);    // a bare n is the row above again (sub laid_run)
    if (all.isNil()) throw 'a tile is not base64';
    if (rows.length != high || all.length != wide * high * 3) throw 'a tile is not as large as it says';
    if (!space) space = $.CGColorSpaceCreateWithName($.kCGColorSpaceSRGB);
    var given = $.CGDataProviderCreateWithCFData(all), flat = $.CGImageCreate(wide, high, 8, 24, wide * 3, space, 0, given, null, false, 0);
    var into = $.CGBitmapContextCreate(null, wide, high, 8, wide * 4, space, 8194);
    $.CGContextDrawImage(into, $.CGRectMake(0, 0, wide, high), flat);
    var image = $.CGBitmapContextCreateImage(into), made = $.NSBitmapImageRep.alloc.initWithCGImage(image);
    $.CGImageRelease(image);
    $.CGContextRelease(into);
    $.CGImageRelease(flat);
    $.CGDataProviderRelease(given);
    if (made.isNil()) throw 'a tile could not be made';
    return made;
}

// The bytes given to the system as an image, four a pixel (red, green, blue, alpha) in the sRGB colours.
function bitmap(all, wide, high) {
    if (!space) space = $.CGColorSpaceCreateWithName($.kCGColorSpaceSRGB);
    var given = $.CGDataProviderCreateWithCFData(all), image = $.CGImageCreate(wide, high, 8, 32, wide * 4, space, 3, given, null, false, 0), made = $.NSBitmapImageRep.alloc.initWithCGImage(image);
    $.CGImageRelease(image);
    $.CGDataProviderRelease(given);
    if (made.isNil()) throw 'a picture could not be made';
    return made;
}

// The mark on a video's place (a V line): a dark round mark with a white
// triangle in it, in the middle of the place, at most 64 points across and
// none on a place too small for one of 12. It says a video stands there; it
// is lzrprf's own drawing. Under it, once you clicked, "Loading" with the
// Stop a click there is, or lzrprf's one line why the video is not played;
// a video that plays covers it.
function videoMark(box, k) {
    var wide = box.size.width, high = box.size.height, across = Math.min(64, wide / 2, high / 2), one = videos[k];
    if (one && (one.state == 'loading' || one.state == 'none')) {
        var band = $.NSMakeRect(box.origin.x, box.origin.y + high - Math.min(high, 22), wide, Math.min(high, 22)), how = $.NSMutableDictionary.dictionary;
        $.NSColor.colorWithWhiteAlpha(0, 0.7).setFill;
        $.NSRectFillUsingOperation(band, 2);
        how.setObjectForKey($.NSFont.systemFontOfSize(11), $.NSFontAttributeName);
        how.setObjectForKey($.NSColor.whiteColor, $.NSForegroundColorAttributeName);
        $(one.state == 'loading' ? (one.stopping ? 'Stopping' : 'Loading the video: click to stop') : one.words).drawInRectWithAttributes($.NSInsetRect(band, 6, 4), how);
        if (one.state == 'none') return;
    }
    if (across < 12) return;
    var x = box.origin.x + (wide - across) / 2, y = box.origin.y + (high - across) / 2, triangle = $.NSBezierPath.bezierPath;
    $.NSColor.colorWithWhiteAlpha(0, 0.55).setFill;
    $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(x, y, across, across)).fill;
    triangle.moveToPoint($.NSMakePoint(x + across * 0.38, y + across * 0.28));
    triangle.lineToPoint($.NSMakePoint(x + across * 0.38, y + across * 0.72));
    triangle.lineToPoint($.NSMakePoint(x + across * 0.74, y + across * 0.5));
    triangle.closePath;
    $.NSColor.whiteColor.setFill;
    triangle.fill;
}

// A video you clicked (lzrprf's sub videoed, [C22]). A first click on a video's place says
// "video K" to lzrprf, which fetches the file once with a picture's checks (or follows an HLS
// stream and joins one quality of it into one file, sub hls_fetched) and hands it here in
// base64 lines ("video TAB K begin LENGTH", with " ts" for an MPEG-TS stream, parts, "end"), or
// one line of words for the box ("none"). The whole file is held in this process's memory and given to the system's player
// through a loader of this window's own on an address of its own (lzrvideo://), so the player
// reaches no network and reads no file: the system's decoder service decodes what it is handed,
// and the picture is shown in a layer in the video's place. It plays muted; the words at the
// bottom right turn the sound on and off, a click elsewhere pauses and plays, and at its end a
// click plays it again. A click while it loads stops it ("video stop", heard by lzrprf's fetch),
// and its mark is back. The bytes of at most two videos are held: a third clicked ends the one
// clicked first, and the player is answered in pieces of at most 4 MiB, never the whole rest of a
// file at once. A page laid anew, another tab or no laid page ends every video.
var videos = {}, videoSerial = 0, videoBytes = {}, videoLoader = null, videoWatch = null, videoTicking = false, videoClockHand = null;    // videos: by their number on the page: { state, words, at, stopping, data, length, name, item, player, view, sound, middle, soundOn, silent }; the clock of their sound (window_sound_text)
var VIDEO_MOST = 67108864;    // DECLARED(lzrprf $VIDEO_BYTES: the most of one video lzrprf hands over)
var VIDEO_PIECE = 4194304, VIDEO_HELD = 2, videoClicks = 0;    // the most bytes handed to the player at once; the most videos whose bytes are held; the order of the clicks
function videoAt(at) {    // the place of a video under a point of the laid page, or null
    var found = null;
    if (sheet) sheet.ops.forEach(function (op) { if (op[2] == 'V' && at.x >= op[3] && at.x < op[3] + op[4] && at.y >= op[0] && at.y < op[0] + op[1]) found = op; });
    return found;
}
function videoPlace(k) {    // the place of video k in the laid page shown, or null
    var found = null;
    if (sheet) sheet.ops.forEach(function (op) { if (op[2] == 'V' && op[5] == k) found = op; });
    return found;
}
function videoClicked(at) {    // whether the click was a video's: it is taken here and never told to a page kept running
    var op = videoAt(at);
    if (!op) return false;
    var k = op[5], one = videos[k];
    if (!one) {
        if (!free) return true;    // lzrprf is busy: the first click waits for it
        var held = Object.keys(videos).filter(function (n) { return videos[n].player || videos[n].state == 'loading'; }).sort(function (a, b) { return videos[a].at - videos[b].at; });
        while (held.length >= VIDEO_HELD) videoEnded(held.shift());    // the bytes of two are held at most: the one clicked first goes
        videos[k] = { state: 'loading', words: '', at: ++videoClicks };
        canvas.needsDisplay = true;
        say('video ' + k);
        return true;
    }
    if (one.state == 'loading' && !one.stopping) { one.stopping = true; canvas.needsDisplay = true; say('video stop'); return true; }    // the Stop of a video that loads
    if (!one.player) return true;    // stopping, or a line of words that stays
    if (at.x >= op[3] + op[4] - 74 && at.y >= op[0] + op[1] - 22) videoSoundTurned(k, one);    // the words at the bottom right: its sound plays in the sound process, the window's own player stays muted
    else if (one.state == 'ended') { one.item = videoItem(one.name); one.player.replaceCurrentItemWithPlayerItem(one.item); one.player.play; one.state = 'playing'; }
    else if (one.state == 'playing') { one.player.pause; one.state = 'paused'; }
    else { one.player.play; one.state = 'playing'; }
    videoWords(one); videoClock(k, one);    // a video whose sound is on: where its picture is now, for the sound to follow
    return true;
}
function videoTold(rest) {    // "video TAB K begin LENGTH [ts] | part BASE64 | end | none WORDS | stopped"
    var m = /^(\d{1,2}) (\d) (begin|part|end|none|stopped)(?: (.*))?$/.exec(rest);
    if (!m || +m[1] != perlTab || +m[1] != selected || !videoPlace(+m[2])) return;    // for a page no longer shown: dropped
    var k = +m[2], one = videos[k], more = m[4] || '';
    if (!one || one.state != 'loading') return;
    if (m[3] == 'stopped') delete videos[k];    // its mark is back, and a click fetches it again
    else if (m[3] == 'none') { one.state = 'none'; one.words = more.replace(/[^\x20-\x7e]/g, '?').slice(0, 200); one.data = null; }
    else if (m[3] == 'begin') {
        var told = /^([1-9][0-9]{0,8})( ts)?$/.exec(more);    // " ts": an HLS stream lzrprf joined into one MPEG-TS file; else an MP4 file, a stream's fragmented MP4 among them
        if (!told || +told[1] > VIDEO_MOST) return videoBroken(one);
        one.length = +told[1];
        one.kind = told[2] ? 'ts' : 'mp4';
        one.data = $.NSMutableData.dataWithCapacity(one.length);
    } else if (!one.data) return videoBroken(one);
    else if (m[3] == 'part') {
        var piece = /^[A-Za-z0-9+\/]+={0,2}$/.test(more) ? $.NSData.alloc.initWithBase64EncodedStringOptions($(more), 0) : $();
        if (piece.isNil() || Number(one.data.length) + Number(piece.length) > one.length) return videoBroken(one);    // a length comes over the bridge as a string
        one.data.appendData(piece);
    } else if (Number(one.data.length) != one.length) return videoBroken(one);
    else videoStarted(k, one);
    canvas.needsDisplay = true;
}
function videoBroken(one) { one.state = 'none'; one.words = 'The video came broken, and is not played.'; one.data = null; canvas.needsDisplay = true; }
function videoItem(name) {    // a new item of the system's player for a video held here
    var asset = $.NSClassFromString('AVURLAsset').URLAssetWithURLOptions($.NSURL.URLWithString($(name)), $());
    asset.resourceLoader.setDelegateQueue(videoLoader, $.NSOperationQueue.mainQueue.underlyingQueue);
    return $.NSClassFromString('AVPlayerItem').playerItemWithAsset(asset);
}
function videoReady() {    // the system's player, made ready once, the first time a video came
    if (videoLoader) return;
    $.NSBundle.bundleWithPath('/System/Library/Frameworks/AVFoundation.framework').load;
    busyClass({ name: 'LzrprfVideoLoader', protocols: ['AVAssetResourceLoaderDelegate'], methods: {
        'resourceLoader:shouldWaitForLoadingOfRequestedResource:': { types: ['bool', ['id', 'id']], implementation: function (loader, request) {
            var data = videoBytes[ObjC.unwrap(request.request.URL.absoluteString)];
            if (!data) return false;    // an address of no video held here: the player is told no
            var info = request.contentInformationRequest, asked = request.dataRequest, all = Number(data.length);
            if (!info.isNil()) { info.contentType = $(/\.ts$/.test(ObjC.unwrap(request.request.URL.absoluteString)) ? 'public.mpeg-2-transport-stream' : 'public.mpeg-4'); info.contentLength = all; info.byteRangeAccessSupported = true; }    // the player reads either as one file (an HLS stream's segments it never takes from a loader)
            if (!asked.isNil()) {
                var from = Math.min(Number(asked.requestedOffset), all), length = Math.min(asked.requestsAllDataToEndOfResource ? all - from : Number(asked.requestedLength), all - from, VIDEO_PIECE);    // a piece: the player asks again for what follows
                asked.respondWithData(data.subdataWithRange($.NSMakeRange(from, length)));
            }
            request.finishLoading;
            return true;
        } }
    } });
    busyClass({ name: 'LzrprfVideoWatch', methods: {
        'ended:': { types: ['void', ['id']], implementation: function (note) {
            Object.keys(videos).forEach(function (k) { var one = videos[k]; if (one.item && note.object.isEqual(one.item)) { one.state = 'ended'; videoWords(one); videoClock(k, one); } });
        } }
    } });
    busyClass({ name: 'LzrprfVideoView', superclass: 'NSView', methods: {
        'isFlipped': { implementation: function () { return true; } },    // measured from its top, as the laid page is
        'hitTest:': { implementation: function (point) { return $(); } }    // no press is its own, nor its words': every one goes to the laid page under it
    } });
    videoLoader = $.LzrprfVideoLoader.alloc.init;
    videoWatch = $.LzrprfVideoWatch.alloc.init;
    $.NSNotificationCenter.defaultCenter.addObserverSelectorNameObject(videoWatch, 'ended:', $('AVPlayerItemDidPlayToEndTimeNotification'), $());
}
function videoStarted(k, one) {
    videoReady();
    one.name = 'lzrvideo://v/' + (++videoSerial) + (one.kind == 'ts' ? '.ts' : '.mp4');
    videoBytes[one.name] = one.data;
    one.data = null;
    one.item = videoItem(one.name);
    one.player = $.NSClassFromString('AVPlayer').playerWithPlayerItem(one.item);
    one.player.setMuted(true);
    one.view = $.LzrprfVideoView.alloc.initWithFrame($.NSMakeRect(0, 0, 10, 10));
    var layer = $.NSClassFromString('AVPlayerLayer').playerLayerWithPlayer(one.player);    // no colour is given to a layer here: a CGColor handed over the bridge ends osascript (seen 2026-11-21)
    layer.videoGravity = $('AVLayerVideoGravityResizeAspect');
    one.shown = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 10, 10));
    one.shown.layer = layer;
    one.shown.wantsLayer = true;
    one.view.addSubview(one.shown);
    one.sound = videoLabel(one.view, 11);
    one.middle = videoLabel(one.view, 14);
    canvas.addSubview(one.view);
    one.state = 'playing';
    videoPlaced(k, one);
    one.player.play;
}
function videoLabel(over, size) {    // white words on a dark band, over the video
    var label = $.NSTextField.labelWithString($(''));
    label.drawsBackground = true;
    label.backgroundColor = $.NSColor.colorWithWhiteAlpha(0, 0.6);
    label.textColor = $.NSColor.whiteColor;
    label.alignment = 1;    // centred
    label.font = $.NSFont.systemFontOfSize(size);
    over.addSubview(label);
    return label;
}
function videoPlaced(k, one) {    // the view of a video in its place, at the place's size in CSS pixels, measured from its top
    var op = videoPlace(k);
    if (!op || !one.view) return;
    var w = op[4], h = op[1];
    one.view.frame = $.NSMakeRect(op[3], op[0], w, h);
    one.shown.frame = $.NSMakeRect(0, 0, w, h);
    one.sound.frame = $.NSMakeRect(Math.max(0, w - 74), Math.max(0, h - 22), Math.min(68, w), 16);    // the bottom right, where a click turns the sound on and off (videoClicked)
    one.middle.frame = $.NSMakeRect(Math.max(0, w / 2 - 50), Math.max(0, h / 2 - 10), Math.min(100, w), 20);
    videoWords(one);
}
function videoWords(one) {
    if (!one.sound) return;
    one.sound.stringValue = $(one.silent ? 'No sound' : one.soundOn ? 'Sound on' : 'Sound off');
    one.middle.stringValue = $(one.state == 'paused' ? 'Paused' : one.state == 'ended' ? 'Play again' : '');
    one.middle.hidden = one.state == 'playing';
}
function videosPlaced() {    // the page laid out again at another width, or drawn again by its scripts: each video goes to its new place, or ends when it has none
    Object.keys(videos).forEach(function (k) { if (!videoPlace(+k)) videoEnded(k); else videoPlaced(+k, videos[k]); });
}
function videoEnded(k) {
    var one = videos[k];
    delete videos[k];
    if (!one) return;
    if (one.player) { one.player.pause; one.player.replaceCurrentItemWithPlayerItem($()); }
    if (one.view) one.view.removeFromSuperview;
    if (one.name) delete videoBytes[one.name]; videoGone(k, one);    // its MP4 and its sound let go behind the window too
}
function videosEnded() { Object.keys(videos).forEach(videoEnded); }

// What the view draws of a laid page: white, then in their order the lines that reach into
// what it draws. A fault here is said as one in "draw" is, and the page goes.
function paint(dirty) {
    var top = dirty.origin.y, bottom = top + dirty.size.height; if (sizingNow) sizedArea += dirty.size.width * dirty.size.height;
    $.NSColor.whiteColor.setFill;
    $.NSRectFill(dirty);
    if (!sheet) return;
    try {
        $.NSGraphicsContext.currentContext.imageInterpolation = 3;    // high: a picture scaled into its box is smoothed, not blocky
        var seen = {}, visible = sheet && sheet.spanning ? sheet.spanning.slice() : [];
        visible.forEach(function (i) { seen[i] = true; });
        if (sheet.buckets) {
            for (var b = Math.floor(top / 256); b <= Math.floor(bottom / 256); b++) (sheet.buckets[b] || []).forEach(function (i) { if (!seen[i]) { seen[i] = true; visible.push(i); } });
            visible.sort(function (a, b) { return a - b; });    // preserve paint order across bucket boundaries
        } else visible = sheet.ops.map(function (_, i) { return i; });
        visible.forEach(function (i) {
            var op = sheet.ops[i];
            if (op[0] > bottom || op[0] + op[1] < top) return;
            if (op[2] == 'X') return op[5].drawAtPointWithAttributes($.NSMakePoint(op[3], op[7]), op[6]);
            var box = $.NSMakeRect(op[3], op[0], op[4], op[1]);
            if (op[2] == 'M') return clippedTo(op.round, function () { (op[5].rows ? op[5].made || (op[5].made = tile(op[5].wide, op[5].high, op[5].rows)) : op[5]).drawInRectFromRectOperationFractionRespectFlippedHints(box, op[6] || $.NSZeroRect, 2, 1, true, $()); });    // a tile is made here once, the first time it is drawn (sub laid)
            if (op[2] == 'V') return videoMark(box, op[5]);
            op[5].setFill;
            $.NSRectFillUsingOperation(box, 2);    // over what is under it, so a colour that is partly clear shows the page through it
        });
        findMarked(top, bottom);
    } catch (fault) {
        sheet = null;
        hand.performSelectorWithObjectAfterDelay('unlaid:', $(), 0);    // the view is not taken away while it draws
        say('fault ' + String(fault).replace(/[^\x20-\x7e]/g, '?').slice(0, 200));
    }
}

// The page: the lines lzrprf let through, as characters with a look.
function draw(lines) {
    var first = 0;
    while (first < lines.length && lines[first].charAt(0) == 'U') first++;
    if (first < lines.length && lines[first].charAt(0) == 'L') return laid(lines, first);
    unlaid();
    var text = '', runs = [], blocks = [], block = null, style = 'p', of = [];
    function put(chars, font, size, kind) { runs.push([text.length, chars.length, font, size, kind]); text += chars; }
    function begin(next, depth) {
        if (block) { put('\n', 'ArialMT', 14, 0); block[1] = text.length - block[0]; }
        style = next;
        block = [text.length, 0, next, depth];
        blocks.push(block);
        if (next == 'l') put('• ', 'ArialMT', 14, 0);
        if (next == 'r') put(new Array(41).join('─'), 'ArialMT', 10, 3);
    }
    lines.forEach(function (line) {
        var kind = line.charAt(0);
        if (kind == 'U') return of.push(line);
        if (kind == 'P') return begin(line.charAt(1), +line.charAt(2));
        if (!block) begin('p', 0);
        if (kind == 'T') {
            var flags = line.charCodeAt(1) - 64, head = style == '1' || style == '2' || style == '3';
            var size = style == '1' ? 24 : style == '2' ? 19 : style == '3' ? 16 : 14, fixed = (flags & 4) || style == 'c';
            var bold = (flags & 1) || head, italic = flags & 2;
            var font = named(bold, italic, fixed);
            put(line.slice(2), font, fixed ? size - 1.5 : size, flags & 8 ? 1 : 0);
        } else if (kind == 'B') put(' ', 'ArialMT', 14, 0);
        else if (kind == 'I') {
            // Arial's line is 1.15 of its size high and its space 0.278 wide: spaces that do not
            // break, in the size that makes the line as high as the box, fill the box.
            var box = /^I(\d+)x(\d+)$/.exec(line), high = box[2] / 1.15;
            put(new Array(Math.max(1, Math.round(box[1] / (high * 0.278))) + 1).join(' '), 'ArialMT', high, 2);
            put(' ', 'ArialMT', 14, 0);
        }
    });
    if (block) block[1] = text.length - block[0];
    var all = $.NSMutableAttributedString.alloc.init;
    all.beginEditing;
    all.replaceCharactersInRangeWithString($.NSMakeRange(0, 0), $(text));
    runs.forEach(function (run) { all.addAttributesRange(look(run[2], run[3], run[4]), $.NSMakeRange(run[0], run[1])); });
    blocks.forEach(function (one) { all.addAttributeValueRange($.NSParagraphStyleAttributeName, paragraph(one[2], one[3]), $.NSMakeRange(one[0], one[1])); });
    all.endEditing;
    page.textStorage.setAttributedString(all);
    page.scrollRangeToVisible($.NSMakeRange(0, 0));
    listed(of);
    if (findOpen) findRun();
    drawn(lines.length, text.length);
}

// The panel of what the page is made of (the second icon in lzrprf's strip): what the application says the page is made of. A row for each
// thing: the name of its kind in front of the first of that kind, then its name, its version
// in grey, and whether the application says its own code supports it. These are the
// application's words, in plain characters: lzrprf checked their form and not their truth,
// and the panel says so in its first line. A list holds 120 lines at most (the same number
// as "checked" holds a list to), and a full one says that there may be more.
var KINDS = { d: 'Document', c: 'CSS', j: 'JavaScript', l: 'Libraries', m: 'Media and formats', a: 'Web APIs', s: 'Security and transport', x: 'Metadata' };
function listed(lines) {
    var text = '', runs = [], kind = '', head, held = 0;
    var LOOKS = { ArialMT0: inked(sans(12.5), WHITE), ArialMT3: inked(sans(12), GREY), 'Arial-BoldMT0': inked(sans(12, true), GREEN) };    // the panel's looks for the pane's old ones: the words, a version or a no in grey, a yes in the beam
    function put(chars, font, look) { runs.push([text.length, chars.length, font == 'Arial-BoldMT' && chars == KINDS[kind] ? spaced(chars, sans(10.5, true), GREEN, 1.2).attributesAtIndexEffectiveRange(0, null) : LOOKS[font + look] || LOOKS.ArialMT0]); text += chars; }
    lines.forEach(function (line) { if (line.charAt(2) == '+') held++; });
    put(lines.length ? 'What ' + NAME + ' says this page is made of: ' + lines.length + (lines.length == 1 ? ' thing' : ' things') + ', ' + held + ' of them supported by ' + NAME + ' itself, as it says.' + (lines.length == 120 ? ' A list holds 120 at most, so there may be more.' : '') + ' lzrprf checked the form of this list, not whether it is true.'
        : 'Here ' + NAME + ' lists what it says a page is made of. Nothing is listed for what is shown now.', 'ArialMT', 3);
    head = text.length;
    lines.forEach(function (line) {
        var tab = line.indexOf('\t'), name = line.slice(3, tab < 0 ? line.length : tab), version = tab < 0 ? '' : line.slice(tab + 1), yes = line.charAt(2) == '+';
        put('\n', 'ArialMT', 0);
        if (line.charAt(1) != kind) { kind = line.charAt(1); put(KINDS[kind] || '?', 'Arial-BoldMT', 0); }
        put('\t', 'ArialMT', 0);
        put(name, 'ArialMT', 0);
        if (version) put(' ' + version, 'ArialMT', 3);
        put('   supported by ' + NAME + ': ' + (yes ? 'true' : 'false'), yes ? 'Arial-BoldMT' : 'ArialMT', yes ? 0 : 3);
    });
    var all = $.NSMutableAttributedString.alloc.init, set = $.NSMutableParagraphStyle.alloc.init;
    set.headIndent = 176;
    set.tabStops = $.NSArray.arrayWithObject($.NSTextTab.alloc.initWithTextAlignmentLocationOptions(0, 176, $.NSDictionary.dictionary));
    set.paragraphSpacingBefore = 5;
    all.beginEditing;
    all.replaceCharactersInRangeWithString($.NSMakeRange(0, 0), $(text));
    runs.forEach(function (run) { all.addAttributesRange(run[2], $.NSMakeRange(run[0], run[1])); });
    if (text.length > head) all.addAttributeValueRange($.NSParagraphStyleAttributeName, set, $.NSMakeRange(head, text.length - head));
    all.endEditing;
    made.textStorage.setAttributedString(all);
    made.scrollRangeToVisible($.NSMakeRange(0, 0));
    techPlaced();
}

// Every view's drawRect: goes through here. What a painting function throws
// inside drawRect: would leave through AppKit, which ends the whole window
// (+[NSApplication _crashOnException:] from _NSViewDrawRect: the window of
// 2026-11-21 05:14 ended 0.6 s after it opened, on its first drawing). Here
// it is caught: what the view painted before the fault stays, the rest of it
// is not drawn this once, and the graphics state it changed is given back.
// The first fault of each view is said to lzrprf behind the window, which
// keeps it in the log.
var undrawnSaid = {};
function viewDrawn(view, paintIt) {
    $.NSGraphicsContext.saveGraphicsState;
    try { paintIt(); } catch (fault) {
        if (undrawnSaid[view]) return;
        undrawnSaid[view] = true;
        try { say('undrawn ' + view + ' ' + String(fault).replace(/[^\x20-\x7e]/g, '?').slice(0, 200)); } catch (lost) { }
    } finally { $.NSGraphicsContext.restoreGraphicsState; }
}

busyClass({ name: 'LzrprfPage', superclass: 'NSTextView', methods: clickThrough({
    // The browser's own Copy and local Inspect actions.
    'menuForEvent:': { types: ['id', ['id']], implementation: function (event) { return inspectMenu(true); } }
}) });

// Ticket 1530 part 2 (Henry: "momentum a bit faster"): after the scroll view took a momentum move of a fling (the page's
// wheel hands it on, 24-trmnl-window.pl), the page goes MOMENTUM_EXTRA further, clamped to the page. No class calls
// ObjC.super for it: the move is added on the clip view the scroll view has just moved.
var MOMENTUM_EXTRA = 0.25;    // DECLARED(Henry asked for a bit faster: a quarter more distance per momentum move)
function momentumMore(event) {
    if (!event.momentumPhase || !event.hasPreciseScrollingDeltas || !scroll.documentView.isEqual(canvas)) return;
    var clip = scroll.contentView, at = clip.bounds.origin, room = Math.max(0, canvas.frame.size.height - clip.bounds.size.height);
    var y = Math.max(0, Math.min(room, at.y - event.scrollingDeltaY * MOMENTUM_EXTRA));
    if (y == at.y) return;
    clip.scrollToPoint($.NSMakePoint(at.x, y)); scroll.reflectScrolledClipView(clip);
}
busyClass({ name: 'LzrprfLaid', superclass: 'NSView', methods: pointerMethods(trmnlMethods({    // and a terminal's wheel, drag, copy and paste [C29], and the pointer's moves, release and cursor (28-window-pointer.pl)
    // A laid page is measured from its top, as the application laid it out. It has no menu of its own.
    'isFlipped': { implementation: function () { return true; } },
    'isOpaque': { implementation: function () { return true; } },    // paint() fills white under everything: the compositor blends nothing under it
    'drawRect:': { implementation: function (dirty) { viewDrawn('laid', function () { var began = framesNow(); paint(dirty); framesDrawn(framesNow() - began); }); } },
    'acceptsFirstResponder': { implementation: function () { return liveOn; } },    // the keyboard only for a page kept running
    'mouseDown:': { implementation: function (event) { pageClicked(event); } },
    'acceptsFirstMouse:': { types: ['bool', ['id']], implementation: function (event) { return true; } },    // H-0074, and Henry 2026-11-24: the press that brings the window forward is the page's too, a site's page as the home (clickThrough, 28-window1-tabs.pl); an incognito window is a process of its own that macOS does not bring forward, so a first press there was lost
    'keyDown:': { implementation: function (event) { pageKey(event); } }
})) });

busyClass({ name: 'LzrprfFrame', superclass: 'NSView', methods: clickThrough({
    'mouseDownCanMoveWindow': { types: ['bool', []], implementation: function () { return false; } },    // HC-0856: macOS never moves the window from a press here on its own; windowHeld moves it where nothing else is pressed
    'mouseDown:': { implementation: function (event) { pressSeen(event); frameClicked(event); } },    // it draws nothing: the glass and the beam are layers (glassPlaced)
    'resetCursorRects': { implementation: function () { frameCursors(); } }
}) });

busyClass({ name: 'LzrprfHome', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('home', function () { paintHome(); }); } },
    'mouseDown:': { implementation: function (event) { pressSeen(event); homeClicked(event); } },
    'acceptsFirstMouse:': { types: ['bool', ['id']], implementation: function (event) { return true; } },    // the press that brings the window to the front is the home page's too, as its lasers saw it when they took presses before the window did
    'mouseMoved:': { implementation: function (event) { hovered('home', event); } },
    'mouseExited:': { implementation: function (event) { hovered('home', null); } }
} });

busyClass({ name: 'LzrprfList', superclass: 'NSView', methods: clickThrough({
    'isFlipped': { implementation: function () { return true; } },
    'drawRect:': { implementation: function (dirty) { viewDrawn('list', function () { paintList(dirty); }); } },
    'mouseDown:': { implementation: function (event) { listClicked(event); } },
    'mouseMoved:': { implementation: function (event) { hovered('list', event); } },
    'mouseExited:': { implementation: function (event) { hovered('list', null); } }
}) });

busyClass({ name: 'LzrprfCogMenu', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('cogmenu', function () { paintCogMenu(); }); } },
    'mouseDown:': { implementation: function (event) { cogMenuClicked(event); } },
    'acceptsFirstMouse:': { types: ['bool', ['id']], implementation: function (event) { return true; } },
    'mouseMoved:': { implementation: function (event) { hovered('cogmenu', event); } },
    'mouseExited:': { implementation: function (event) { hovered('cogmenu', null); } },
    'scrollWheel:': { implementation: function (event) { cogWheeled(event); } },    // a box that fits does not move
    'performKeyEquivalent:': { types: ['bool', ['id']], implementation: function (event) { return !(event.modifierFlags & (1 << 18 | 1 << 19 | 1 << 20)) && !cogComposing() && cogKeyed(event.keyCode); } }    // a key press the window offers its views as a key equivalent: the box takes its own keys, pressed with no Control, Option or Command, while it scrolls, and the keyboard never moves. Whether a window offers plain keys here while the bar is typed into only a real Mac shows; if it does not, the keys do nothing and the wheel and the chevrons still scroll (a key watch through NSEvent is not used: a JavaScript block cannot hand an event back to AppKit)
} });

// Under the cogwheel's open menu, over all else: a press anywhere outside the menu closes it and reaches nothing.
busyClass({ name: 'LzrprfCatch', superclass: 'NSView', methods: {
    'mouseDown:': { implementation: function (event) { cogHidden(); } },
    'rightMouseDown:': { implementation: function (event) { cogHidden(); } },
    'scrollWheel:': { implementation: function (event) { cogHidden(); } }
} });

busyClass({ name: 'LzrprfLogIcon', superclass: 'NSButton', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('logicon', function () { paintIcon(logs, logGlyph, hover.logIcon, logs.enabled, false); }); } },
    'mouseEntered:': { implementation: function (event) { hovered('logIcon', event); } },
    'mouseExited:': { implementation: function (event) { hovered('logIcon', null); } }
}) });

busyClass({ name: 'LzrprfTechIcon', superclass: 'NSButton', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('techicon', function () { paintIcon(techs, techGlyph, hover.techIcon, !modalOpen, techOpen); }); } },
    'mouseEntered:': { implementation: function (event) { hovered('techIcon', event); } },
    'mouseExited:': { implementation: function (event) { hovered('techIcon', null); } }
}) });


busyClass({ name: 'LzrprfTorIcon', superclass: 'NSButton', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('toricon', function () { torIconDrawn(torIcon); }); } },
    'mouseEntered:': { implementation: function (event) { hovered('torIcon', event); } },
    'mouseExited:': { implementation: function (event) { hovered('torIcon', null); } }
}) });

busyClass({ name: 'LzrprfToolIcon', superclass: 'NSButton', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('toolicon', function () { toolIconDrawn(toolIcon); }); } },
    'mouseEntered:': { implementation: function (event) { hovered('toolIcon', event); } },
    'mouseExited:': { implementation: function (event) { hovered('toolIcon', null); } }
}) });


busyClass({ name: 'LzrprfTool', superclass: 'NSView', methods: clickThrough({
    'isFlipped': { implementation: function () { return true; } },
    'drawRect:': { implementation: function (dirty) { viewDrawn('tool', function () { paintTool(); }); } },
    'mouseDown:': { implementation: function (event) { toolClicked(event); } }
}) });

busyClass({ name: 'LzrprfTorBeam', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('torbeam', function () { torBeamDrawn(torView); }); } }
} });

busyClass({ name: 'LzrprfSuggest', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('suggest', function () { paintSuggest(); }); } },
    'mouseDown:': { implementation: function (event) { suggestClicked(event); } },
    'mouseMoved:': { implementation: function (event) { hovered('suggest', event); } },
    'mouseExited:': { implementation: function (event) { hovered('suggest', null); } }
}) });

busyClass({ name: 'LzrprfWizard', superclass: 'NSView', methods: clickThrough({
    'isFlipped': { implementation: function () { return true; } },
    'drawRect:': { implementation: function (dirty) { viewDrawn('wizard', function () { paintWizard(); }); } },
    'mouseDown:': { implementation: function (event) { wizClicked(event); } },
    'mouseMoved:': { implementation: function (event) { hovered('wiz', event); } },
    'mouseExited:': { implementation: function (event) { hovered('wiz', null); } }
}) });

busyClass({ name: 'LzrprfFind', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('find', function () { paintFind(); }); } },
    'mouseDown:': { implementation: function (event) { findClicked(event); } }
}) });

busyClass({ name: 'LzrprfSecure', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('secure', function () { paintSecure(); }); } },
    'mouseDown:': { implementation: function (event) { } }
} });

busyClass({ name: 'LzrprfTabs', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('tabs', function () { paintTabs(); }); } },
    'mouseDownCanMoveWindow': { types: ['bool', []], implementation: function () { return false; } },    // HC-0856: macOS never moves the window from a press here on its own; windowHeld moves it where nothing else is pressed
    'mouseDown:': { implementation: function (event) { pressSeen(event); tabClicked(event); } },
    'mouseMoved:': { implementation: function (event) { hovered('tabs', event); } },
    'mouseExited:': { implementation: function (event) { hovered('tabs', null); } }
}) });

busyClass({ name: 'LzrprfBelt', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('belt', function () { paintBelt(); }); } },
    'mouseDownCanMoveWindow': { types: ['bool', []], implementation: function () { return false; } },    // HC-0856: macOS never moves the window from a press here on its own; windowHeld moves it where nothing else is pressed
    'mouseDown:': { implementation: function (event) { pressSeen(event); beltClicked(event); } },
    'mouseMoved:': { implementation: function (event) { hovered('belt', event); } },
    'mouseExited:': { implementation: function (event) { hovered('belt', null); } }
}) });

busyClass({ name: 'LzrprfCog', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('cog', function () { paintCog(); }); } },
    'mouseDown:': { implementation: function (event) { pressSeen(event); cogClicked(); } },
    'acceptsFirstMouse:': { types: ['bool', ['id']], implementation: function (event) { return true; } },    // the press that brings the window to the front opens the menu too, as a button of the system's does
    'mouseEntered:': { implementation: function (event) { hovered('cog', event); } },
    'mouseExited:': { implementation: function (event) { hovered('cog', null); } }
} });

busyClass({ name: 'LzrprfFaces', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('faces', function () { paintFaces(); }); } },
    'mouseDown:': { implementation: function (event) { pressSeen(event); facesClicked(); } },
    'mouseEntered:': { implementation: function (event) { hovered('faces', event); } },
    'mouseExited:': { implementation: function (event) { hovered('faces', null); } }
}) });

busyClass({ name: 'LzrprfStar', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('star', function () { paintStar(); }); } },
    'mouseDown:': { implementation: function (event) { pressSeen(event); starClicked(); } },
    'mouseEntered:': { implementation: function (event) { hovered('star', event); } },
    'mouseExited:': { implementation: function (event) { hovered('star', null); } }
}) });

busyClass({ name: 'LzrprfMarks', superclass: 'NSView', methods: clickThrough({
    'drawRect:': { implementation: function (dirty) { viewDrawn('marks', function () { paintMarks(); }); } },
    'mouseDownCanMoveWindow': { types: ['bool', []], implementation: function () { return false; } },    // HC-0856: macOS never moves the window from a press here on its own; windowHeld moves it where nothing else is pressed
    'mouseDown:': { implementation: function (event) { pressSeen(event); marksClicked(event); } },
    'mouseMoved:': { implementation: function (event) { hovered('marks', event); } },
    'mouseExited:': { implementation: function (event) { hovered('marks', null); } }
}) });

busyClass({ name: 'LzrprfBack', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('back', function () { paintBack(); }); } }
} });

// The veil under the modal takes every click and scroll, so nothing under it is reached.
busyClass({ name: 'LzrprfVeil', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('veil', function () { (modalOpen && modalKind == 'flag' ? $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.72, 0.04, 0.04, 1) : $.NSColor.colorWithWhiteAlpha(0, 0.62)).setFill; $.NSRectFillUsingOperation(dirty, 2); }); } },
    'mouseDown:': { implementation: function (event) { veilPressed(event); } },    // the tab strip still takes a press under the question about scripts (veilPressed, 28-window1-tabs.pl)
    'rightMouseDown:': { implementation: function (event) { } },
    'scrollWheel:': { implementation: function (event) { } }
} });

busyClass({ name: 'LzrprfKeys', superclass: 'NSView', methods: {    // of no size, in the veil: Return and Escape of a modal (function modalKeyed)
    'performKeyEquivalent:': { types: ['bool', ['id']], implementation: function (event) { return modalKeyed(event); } },
    'hitTest:': { implementation: function (point) { return $(); } }
} });

busyClass({ name: 'LzrprfPanel', superclass: 'NSView', methods: {
    'drawRect:': { implementation: function (dirty) { viewDrawn('panel', function () { paintPanel(); }); } },
    'mouseDown:': { implementation: function (event) { } }
} });
busyClass({ name: 'LzrprfHand', superclass: 'NSObject', methods: {
    'windowWillReturnFieldEditor:toObject:': { types: ['id', ['id', 'id']], implementation: function (sender, client) { return typingView(); } },    // every text field of the window is typed into through this one, which asks no language service
    'windowDidResize:': { types: ['void', ['id']], implementation: function (note) { place(); resting(); frameSaid(); } },
    'windowDidBecomeKey:': { types: ['void', ['id']], implementation: function () { say('window focus 1'); } },
    'windowDidResignKey:': { types: ['void', ['id']], implementation: function () { say('window focus 0'); } },
    'windowDidMove:': { types: ['void', ['id']], implementation: function (note) { frameSaid(); } },
    'shotEnded:': { types: ['void', ['id']], implementation: function () { shotEnded(); } },
    'framed:': { types: ['void', ['id']], implementation: function (sender) { framed(); } },
    'windowWillStartLiveResize:': { types: ['void', ['id']], implementation: function (note) { sizing(true); } },
    'windowDidEndLiveResize:': { types: ['void', ['id']], implementation: function (note) { sizing(false); viewNow(); } },
    'windowDidChangeBackingProperties:': { types: ['void', ['id']], implementation: function (note) { glassPlaced(); view(); } },    // a move to a screen of another scale: the page is drawn again at its pixels
    'windowDidEnterFullScreen:': { types: ['void', ['id']], implementation: function (note) { viewNow(); frameSaid(); } },
    'windowDidExitFullScreen:': { types: ['void', ['id']], implementation: function (note) { viewNow(); frameSaid(); } },    // full screen keeps the system's own options, which hide the menu bar and show it at the top: options of its own (auto-hide toolbar on a window with no toolbar) hung a window that opened in full screen (release 131, 2026-11-26)
    'viewed:': { types: ['void', ['id']], implementation: function (sender) { view(); } },
    'pageScrolled:': { types: ['void', ['id']], implementation: function (note) { framesMoved(); pageScrollMoved(); } },
    'pageScrollDue:': { types: ['void', ['id']], implementation: function (sender) { pageScrollFrame(); } },
    'toastDue:': { types: ['void', ['id']], implementation: function (sender) { try { toastDue(); } catch (lost) { } } },    // OBSERVABILITY-EXEMPT(a toast left up a moment longer)
    'framesDue:': { types: ['void', ['id']], implementation: function (sender) { try { framesDue(); } catch (fault) { frames = null; } } },
    'unlaid:': { types: ['void', ['id']], implementation: function (sender) { unlaid(); page.string = $(''); listed([]); } },
    // Return sends the typed address; nonplain characters make the entire address invalid.
    'go:': { types: ['void', ['id']], implementation: function (sender) {
        var typed = bar.stringValue.js.replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 2100);
        if (!typed.length || asking || !bar.enabled) return;
        bar.enabled = false;
        say('go ' + typed);
    } },
    'first:': { types: ['void', ['id']], implementation: function (sender) { if (asking) { strip(['']); say('button ' + asked + ' 1'); } } },
    'second:': { types: ['void', ['id']], implementation: function (sender) { if (asking) { strip(['']); say('button ' + asked + ' 2'); } } },
    'log:': { types: ['void', ['id']], implementation: function (sender) { logPressed(); } },
    'techs:': { types: ['void', ['id']], implementation: function (sender) { flyNext = { icon: secureTech, at: Date.now(), box: boxOf(secureTech.convertRectToView(secureTech.bounds, root)) }; techToggled(); } },
    'flown:': { types: ['void', ['id']], implementation: function (timer) { try { flew(Date.now()); } catch (fault) { flightEnded(); } } },
    'tor:': { types: ['void', ['id']], implementation: function (sender) { torPressed(); } },
    'tool:': { types: ['void', ['id']], implementation: function (sender) { toolPressed(); } },
    'toolCopy:': { types: ['void', ['id']], implementation: function (sender) { toolCopied(); } },
    'toolAll:': { types: ['void', ['id']], implementation: function (sender) { procsPressed(); } }, 'procNote:': { types: ['void', ['id']], implementation: function (sender) { procNoted(); } },
    'essentialReview:': { types: ['void', ['id']], implementation: function () { webReviewOpened(); } },
    'toolTab:': { types: ['void', ['id']], implementation: function (sender) { toolTabbed(TOOL_TABS[sender.tag] || 'computer'); } },
    'permitCopy:': { types: ['void', ['id']], implementation: function (sender) { permitCopied(); } },
    'torTick:': { types: ['void', ['id']], implementation: function (timer) { try { torTicked(); } catch (fault) { torTimer.invalidate; torTimer = null; } } },
    'windowDidChangeOcclusionState:': { types: ['void', ['id']], implementation: function (note) { torTicking(); } },    // the onion breathes again once the window is seen again
    'torShown:': { types: ['void', ['id']], implementation: function (sender) { torShown(); } },
    'torPaced:': { types: ['void', ['id']], implementation: function (sender) { torPacing = false; torPaced(); } },
    'importing:': { types: ['void', ['id']], implementation: function (sender) { if (!INCOGNITO) importOpened(); } },
    'incognito:': { types: ['void', ['id']], implementation: function (sender) { say('incognito'); } },    // lzrprf starts a second lzrprf, in incognito: this process starts nothing
    'controlTextDidChange:': { types: ['void', ['id']], implementation: function (note) { if (note.object.isEqual(bar)) suggestUpdate(); else if (findField && note.object.isEqual(findField)) findRun(); } },
    'control:textView:doCommandBySelector:': { types: ['bool', ['id', 'id', 'SEL']], implementation: function (control, view, command) {    // up, down, Escape and Return in the bar, for its suggestions; Return, Shift-Return and Escape in Find's field
        var name = typeof command == 'string' ? command : $.NSStringFromSelector(command).js;
        if (findField && control.isEqual(findField)) {
            if (name == 'insertNewline:') { findMoved(app.currentEvent.modifierFlags & SHIFT ? -1 : 1); return true; }
            if (name == 'cancelOperation:') { findClosed(); return true; }
            return false;
        }
        if (!control.isEqual(bar)) return false;
        return suggestKey(name);
    } },
    'newTab:': { types: ['void', ['id']], implementation: function (sender) { newTab(); } },
    'closeTab:': { types: ['void', ['id']], implementation: function (sender) { tabSaid('tab close ' + selected, selected); } },
    'reopenTab:': { types: ['void', ['id']], implementation: function (sender) { reopenTab(); } },
    'finding:': { types: ['void', ['id']], implementation: function (sender) { findOpened(); } },
    'findNext:': { types: ['void', ['id']], implementation: function (sender) { findMoved(1); } },
    'findPrevious:': { types: ['void', ['id']], implementation: function (sender) { findMoved(-1); } },
    'zoomIn:': { types: ['void', ['id']], implementation: function (sender) { zoomed(1); } },
    'zoomOut:': { types: ['void', ['id']], implementation: function (sender) { zoomed(-1); } },
    'zoomReset:': { types: ['void', ['id']], implementation: function (sender) { zoomed(0); } },
    'loadingTicked:': { types: ['void', ['id']], implementation: function (sender) { loadingTicked(); } }, 'layersPumped:': { types: ['void', ['id']], implementation: function (sender) { layersPumped(); } },
    'clearing:': { types: ['void', ['id']], implementation: function (sender) { clearing(); } }, 'cookieSite:': { types: ['void', ['id']], implementation: function (sender) { cookieSite(); } },
    'homing:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) sent('menu home'); } },
    'back:': { types: ['void', ['id']], implementation: function (sender) { navPressed(0); } },
    'forward:': { types: ['void', ['id']], implementation: function (sender) { navPressed(1); } },
    'reload:': { types: ['void', ['id']], implementation: function (sender) { navPressed(2); } },
    'bookmarks:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) listOpened('marks'); } },
    'engine:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) engineAsked(); } },
    'marksBar:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) sent('menu bookmarks-bar'); } },
    'markThis:': { types: ['void', ['id']], implementation: function (sender) { starClicked(); } },
    'settings:': { types: ['void', ['id']], implementation: function (sender) { cogClicked(); } },
    'tabsPage:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) listOpened('tabs'); } },
    'nextTab:': { types: ['void', ['id']], implementation: function (sender) { tabMoved(1); } },
    'previousTab:': { types: ['void', ['id']], implementation: function (sender) { tabMoved(-1); } },
    'tabNumber:': { types: ['void', ['id']], implementation: function (sender) { var n = sender.tag < 0 ? tabs.length - 1 : sender.tag; if (!modalOpen && !asking && n >= 0 && n < tabs.length && n != selected) tabSaid('tab select ' + n); } },
    'markMenu:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) sent('mark open ' + sender.tag); } },
    'folderChosen:': { types: ['void', ['id']], implementation: function (sender) { folderChosen(); } },
    'controlTextDidBeginEditing:': { types: ['void', ['id']], implementation: function (note) { belt.needsDisplay = true; } },
    'controlTextDidEndEditing:': { types: ['void', ['id']], implementation: function (note) { if (note.object.isEqual(bar)) suggestHidden(); belt.needsDisplay = true; } },
    'modalPress:': { types: ['void', ['id']], implementation: function (sender) { var act = modalActions[sender.tag]; if (modalOpen && act) act(); } },
    'supportTicked:': { types: ['void', ['id']], implementation: function (sender) { supportTicked(); } },
    'bar:': { types: ['void', ['id']], implementation: function (sender) { if (bar.enabled) win.makeFirstResponder(bar); } },
    'applicationShouldTerminateAfterLastWindowClosed:': { types: ['bool', ['id']], implementation: function (sender) { return true; } },
    // What lzrprf wrote, as it comes. Only the new bytes are looked at for a line end, and only the whole
    // lines are read as text: a line that comes in many pieces (a picture's) is not read again with every
    // piece. A line that is no UTF-8 is read as Latin-1, and a line whose handling fails is passed over:
    // neither keeps the lines after it from being heard, and the window is always told of the next bytes.
    'heard:': { types: ['void', ['id']], implementation: function (note) {
        var data = from.availableData;
        if (data.length == 0) { behindGone(); return; }    // lzrprf is gone: so is its window, unless the installer's modal is open
        try {
            if (!NEWLINE) NEWLINE = $('\n').dataUsingEncoding(4);
            held.appendData(data);    // a length and a place in bytes come from the bridge as text: each is made a number before it is added to
            while (+data.length >= 16384 && +held.length < 8388608 && held.rangeOfDataOptionsRange(NEWLINE, 0, $.NSMakeRange(+held.length - 1, 1)).length == 0) { data = from.availableData; if (data.length == 0) break; held.appendData(data); }    // a full read that ends inside a line: the rest of that line is on its way (lzrprf writes whole lines, in one write a list), so it is read here and now, up to 8 MiB at a time, and the lines are made text once for all of it. Read by read, each with its own turn of the window's loop and its own text, a front page's 22 MB of picture rows took the window over a second for every list (measured in the real browser, 2026-11-25); so read, 0.2 s
            var end = held.rangeOfDataOptionsRange(NEWLINE, 1, $.NSMakeRange(0, +held.length));    // 1: from the end
            if (end.length > 0) {
                var upto = +end.location, whole = held.subdataWithRange($.NSMakeRange(0, upto));
                held = $.NSMutableData.dataWithData(held.subdataWithRange($.NSMakeRange(upto + 1, held.length - upto - 1)));
                var text = $.NSString.alloc.initWithDataEncoding(whole, 4);
                if (text.isNil()) text = $.NSString.alloc.initWithDataEncoding(whole, 5);
                text.js.split('\n').forEach(function (line) { try { heard(line); } catch (fault) { } });
            }
        } finally {
            from.waitForDataInBackgroundAndNotify;
        }
    } }
} });

// Every text view of the window, and the one every text field is typed into, is kept away from the
// system's language services: no spelling or grammar checking, no correction, no text replacement,
// no completion, no quotes or dashes made smart, no links or data found. The window's container lets
// it look up none of those services (the list of its container), so a view that asked would only
// be refused, after a wait, with an error in the log. Selftest holds that each is made through here.
function unchecked(view) {
    view.continuousSpellCheckingEnabled = false;
    view.grammarCheckingEnabled = false;
    view.automaticSpellingCorrectionEnabled = false;
    view.automaticTextReplacementEnabled = false;
    view.automaticQuoteSubstitutionEnabled = false;
    view.automaticDashSubstitutionEnabled = false;
    view.automaticTextCompletionEnabled = false;
    view.automaticLinkDetectionEnabled = false;
    view.automaticDataDetectionEnabled = false;
    return view;
}

var fieldEditor = null;    // the text view every text field of the window is typed into, made once
function typingView() {
    if (!fieldEditor) { fieldEditor = unchecked($.NSTextView.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 20))); fieldEditor.fieldEditor = true; }
    return fieldEditor;
}

function button(title, action) {
    var one = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 30));
    one.title = $(title);
    one.bezelStyle = 1;
    one.target = hand;
    one.action = action;
    one.autoresizingMask = 1 | 8;
    root.addSubview(one);
    return one;
}

// The menus, with Chrome's keys for what LZRBRWSR has (Chrome for Mac's own list): Cmd-F, Cmd-G and
// Shift-Cmd-G, Cmd-plus, Cmd-minus and Cmd-0, Cmd-Shift-T, Cmd-L,
// Cmd-[ and Cmd-], Cmd-R, Cmd-T, Cmd-W, Cmd-D, Cmd-Shift-B, Cmd-Option-B, Cmd-Shift-Delete,
// Cmd-Comma, Cmd-1 to Cmd-8, Cmd-9, Ctrl-Tab, Ctrl-Shift-Tab, Cmd-Option-Right and Left,
// Cmd-Shift-A. Each does only what its button does, and only when the chrome takes a press.
var CMD = 1 << 20, SHIFT = 1 << 17, OPTION = 1 << 19, CONTROL = 1 << 18;
function menus() {
    var main = $.NSMenu.alloc.initWithTitle($(''));
    var tabKeys = [1, 2, 3, 4, 5, 6, 7, 8].map(function (n) { return ['Tab ' + n, 'tabNumber:', String(n), true, CMD, n - 1]; }).concat([['Last Tab', 'tabNumber:', '9', true, CMD, -1]]);
    [[NAME, [['Settings...', 'settings:', ',', true], ['Quit ' + NAME, 'terminate:', 'q', false]]],
     ['Edit', [['Undo', 'undo:', 'z', false], ['Redo', 'redo:', 'Z', false], ['Cut', 'cut:', 'x', false], ['Copy', 'copy:', 'c', false], ['Paste', 'paste:', 'v', false], ['Select All', 'selectAll:', 'a', false],
        ['Find...', 'finding:', 'f', true], ['Find Next', 'findNext:', 'g', true], ['Find Previous', 'findPrevious:', 'g', true, CMD | SHIFT]]],
     ['View', [['Zoom In', 'zoomIn:', '+', true], ['Zoom In', 'zoomIn:', '=', true, CMD, 0, true], ['Zoom Out', 'zoomOut:', '-', true], ['Actual Size', 'zoomReset:', '0', true]]],
     ['Go', [['Address', 'bar:', 'l', true], ['Back', 'back:', '[', true], ['Forward', 'forward:', ']', true], ['Reload', 'reload:', 'r', true], ['Clear Browsing History...', 'clearing:', String.fromCharCode(8), true, CMD | SHIFT], ['Clear Cookies of This Site...', 'cookieSite:', '', true], ['Log', 'log:', '', true]]],
     ['Bookmarks', [['Bookmark This Tab...', 'markThis:', 'd', true], ['Show Bookmarks Bar', 'marksBar:', 'b', true, CMD | SHIFT], ['Bookmark Manager', 'bookmarks:', 'b', true, CMD | OPTION], ['Import Bookmarks...', 'importing:', '', true]]],
     ['Tab', [['Reopen Closed Tab', 'reopenTab:', 't', true, CMD | SHIFT], ['Show All Tabs', 'tabsPage:', 'a', true, CMD | SHIFT],
        ['Select Next Tab', 'nextTab:', String.fromCharCode(0xF703), true, CMD | OPTION], ['Select Previous Tab', 'previousTab:', String.fromCharCode(0xF702), true, CMD | OPTION],
        ['Next Tab', 'nextTab:', '\t', true, CONTROL], ['Previous Tab', 'previousTab:', '\t', true, CONTROL | SHIFT]].concat(tabKeys)]].forEach(function (one) {
        var item = $.NSMenuItem.alloc.init, menu = $.NSMenu.alloc.initWithTitle($(one[0]));
        one[1].forEach(function (entry) {
            var made = menu.addItemWithTitleActionKeyEquivalent($(entry[0]), entry[1], $(entry[2]));
            if (entry[3]) made.target = hand;
            if (entry[4]) made.keyEquivalentModifierMask = entry[4];
            if (entry.length > 5) made.tag = entry[5];
            if (entry[1] == 'marksBar:') { barMenuItem = made; made.title = $(barToggleWords(marksOn, true)); }    // in step with the bar, also an incognito window's
            if (entry[6]) { made.hidden = true; try { made.allowsKeyEquivalentWhenHidden = true; } catch (e) { } }    // Cmd-= zooms in too, as on keyboards where + needs Shift, without a second line in the menu
            if (INCOGNITO && (entry[1] == 'markThis:' || entry[1] == 'importing:')) { menu.autoenablesItems = false; made.enabled = false; made.toolTip = $(UNKEPT_TIP); }    // [C16]
        });
        item.submenu = menu;
        main.addItem(item);
    });
    menusMore(main); app.mainMenu = main;    // File and Help, and the name in the bar (28-window-menu.pl)
}

function tabMoved(by) { if (!modalOpen && !asking && tabs.length > 1) tabSaid('tab select ' + ((selected + by + tabs.length) % tabs.length)); }

// The test seams keep physical window ordering separate from startup readiness: a test can order an invisible real window without replacing the startup gate.
function kind() { return PULLED ? 1 : 0; }    // an application with a window and a place in the Dock; a pulled-out window an accessory (T5)
function shown() { startupRequested = true; if (startupReady) windowOrdered(); }
function windowOrdered() { win.makeKeyAndOrderFront($()); app.activateIgnoringOtherApps(true); }
function drawn(lines, characters) { }
function told(word, rest) { }

// The icon in the Dock is drawn here, a black square with the laser's cyan glint across it, so the
// window reads no picture from the closed download.
function icon(S) {
    var img = $.NSImage.alloc.initWithSize($.NSMakeSize(S, S)), side = S * 824 / 1024, c = S / 2, d = S * 0.26, n = S * 0.03, glintPath = $.NSBezierPath.bezierPath;
    img.lockFocus;
    $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.03, 0.04, 0.05, 1).setFill;
    $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect((S - side) / 2, (S - side) / 2, side, side), side * 0.225, side * 0.225).fill;
    glintPath.moveToPoint($.NSMakePoint(c + d, c + d));
    glintPath.curveToPointControlPoint1ControlPoint2($.NSMakePoint(c - d, c - d), $.NSMakePoint(c - n, c + n), $.NSMakePoint(c - n, c + n));
    glintPath.curveToPointControlPoint1ControlPoint2($.NSMakePoint(c + d, c + d), $.NSMakePoint(c + n, c - n), $.NSMakePoint(c + n, c - n));
    var shine = $.NSShadow.alloc.init;
    shine.shadowColor = tint(1);
    shine.shadowBlurRadius = S * 0.06;
    shine.shadowOffset = $.NSMakeSize(0, 0);
    shine.set;
    tint(1).setFill;
    glintPath.fill;
    $.NSColor.whiteColor.setFill;
    $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(c - S * 0.04, c - S * 0.04, S * 0.08, S * 0.08)).fill;
    img.unlockFocus;
    return img;
}

