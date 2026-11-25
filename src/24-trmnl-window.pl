
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
#   a right press: "page context X Y"; lzrprf answers with a menu to show
#     there ("trmnlmenu X Y" and its items, sub trmnl_menu_offered), and the
#     item you choose is said as "page menu ID" (Copy and Paste of that menu
#     are the window's own copy and paste, above);
#   a press on File or View in the terminal's bar is a press like any other,
#     and lzrprf answers it with that menu the same way;
#   a key of TRMNL_SHORTCUTS, while the terminal has the keyboard: "page tkey
#     ID", and the key goes nowhere else (24-trmnl-panes.pl lists them).
sub window_trmnl_text {
    return <<'END';
var TRMNL_PASTE = 65536, trmnlCopyAsked = 0, trmnlWheelHeld = 0, trmnlDragSaid = '';    // DECLARED(lzrprf $TRMNL_PASTE)
var TRMNL_SHORTCUTS = { 'c \\': 'split-right', 'cs d': 'split-down', 'cs w': 'close-pane', 'cs left': 'focus-left', 'cs right': 'focus-right', 'cs up': 'focus-up', 'cs down': 'focus-down',
    'ct left': 'size-left', 'ct right': 'size-right', 'ct up': 'size-up', 'ct down': 'size-down', 'ct =': 'equalise', 'ts t': 'tab-new', 'ts w': 'tab-close',
    't pagedown': 'tab-next', 't pageup': 'tab-prev', 'ts pagedown': 'tab-right', 'ts pageup': 'tab-left', 'c s': 'save' };    // DECLARED(lzrprf %TRMNL_KEYED): none of them is a key of the window's menus
var TRMNL_NAMED_KEYS = { 123: 'left', 124: 'right', 125: 'down', 126: 'up', 116: 'pageup', 121: 'pagedown' }, TRMNL_KEY_GLYPHS = { left: 0xF702, right: 0xF703, down: 0xF701, up: 0xF700, pageup: 0xF72C, pagedown: 0xF72D };
var trmnlOffered = [], trmnlHand = null;
function trmnlMethods(methods) {    // the methods of LzrprfLaid, with the terminal's own added
    methods['scrollWheel:'] = { types: ['void', ['id']], implementation: function (event) { if (!trmnlWheeled(event)) canvas.nextResponder.scrollWheel(event); } };    // on any other page the wheel goes where it always went
    var pressed = methods['mouseDown:'].implementation, typed = methods['keyDown:'].implementation;
    methods['mouseDown:'] = { types: ['void', ['id']], implementation: function (event) { trmnlDragSaid = ''; pressed(event); } };    // a press starts a selection afresh
    methods['mouseDragged:'] = { types: ['void', ['id']], implementation: function (event) { trmnlDragged(event); } };
    methods['rightMouseDown:'] = { types: ['void', ['id']], implementation: function (event) { if (!trmnlContext(event)) canvas.nextResponder.rightMouseDown(event); } };    // on any other page a right press goes where it always went
    methods['keyDown:'] = { types: ['void', ['id']], implementation: function (event) { if (!trmnlShortcut(event)) typed(event); } };
    methods['performKeyEquivalent:'] = { types: ['bool', ['id']], implementation: function (event) { return trmnlShortcut(event); } };    // a key with Command reaches a view before the window's menus: only the terminal's own keys are taken here
    methods['copy:'] = { types: ['void', ['id']], implementation: function (sender) { trmnlCopy(); } };
    methods['paste:'] = { types: ['void', ['id']], implementation: function (sender) { trmnlPaste(); } };
    methods['validateMenuItem:'] = { types: ['bool', ['id']], implementation: function (item) { return trmnlKeys && !modalOpen; } };    // Copy and Paste, the two items of the menu this view answers
    return methods;
}
function trmnlTakes() { return trmnlKeys && liveOn && sheet && free && !modalOpen && canvas && win.firstResponder.isEqual(canvas); }    // the terminal is shown and has the keyboard
function trmnlKeyOf(event) {    // a key as TRMNL_SHORTCUTS names it: its modifiers (c Command, t Control, o Option, s Shift) and the key
    var flags = event.modifierFlags, mods = (flags & CMD ? 'c' : '') + (flags & CONTROL ? 't' : '') + (flags & OPTION ? 'o' : '') + (flags & SHIFT ? 's' : '');
    var key = TRMNL_NAMED_KEYS[event.keyCode] || String(event.charactersIgnoringModifiers.js || '').toLowerCase();
    return mods + ' ' + key;
}
function trmnlShortcut(event) {
    if (!trmnlTakes() || event.type != 10) return false;    // 10: a key pressed
    var name = TRMNL_SHORTCUTS[trmnlKeyOf(event)];
    if (!name) return false;
    say('page tkey ' + name);
    return true;
}
function trmnlContext(event) {
    if (!trmnlKeys || !liveOn || !sheet || !free || modalOpen) return false;
    win.makeFirstResponder(canvas);
    var at = pointIn(canvas, event), x = Math.round(at.x), y = Math.round(at.y);
    if (x >= 0 && y >= 0 && x < sheet.wide && y < sheet.high) say('page context ' + x + ' ' + y);
    return true;
}
function trmnlTold(word, rest) {    // what lzrprf says of a terminal's tab alone
    if (word == 'trmnlcopy') trmnlCopied(rest);
    else if (word == 'trmnlmenu') trmnlMenu(rest);
}
function trmnlHint(item, id) {    // the key of an item, shown beside it as the window's menus show theirs
    Object.keys(TRMNL_SHORTCUTS).forEach(function (key) {
        if (TRMNL_SHORTCUTS[key] != id) return;
        var parts = key.split(' '), mods = parts[0], glyph = TRMNL_KEY_GLYPHS[parts[1]];
        item.keyEquivalent = $(glyph ? String.fromCharCode(glyph) : parts[1]);
        item.keyEquivalentModifierMask = (/c/.test(mods) ? CMD : 0) | (/t/.test(mods) ? CONTROL : 0) | (/o/.test(mods) ? OPTION : 0) | (/s/.test(mods) ? SHIFT : 0);
    });
}
function trmnlMenu(rest) {    // "X Y", then each item as ID|WORDS|1 or 0 (offered or not), "-" a line between: shown at that point of the page
    if (!trmnlKeys || !liveOn || !sheet || modalOpen || !canvas) return;
    var items = rest.split('\t'), at = /^(\d{1,5}) (\d{1,5})$/.exec(items.shift() || '');
    if (!at) return;
    var menu = $.NSMenu.alloc.initWithTitle($(''));
    menu.autoenablesItems = false;
    menu.appearance = $.NSAppearance.appearanceNamed($('NSAppearanceNameDarkAqua'));
    if (!trmnlHand) trmnlHand = $.LzrprfTrmnlHand.alloc.init;
    trmnlOffered = [];
    items.forEach(function (one) {
        if (one == '-') return menu.addItem($.NSMenuItem.separatorItem);
        var f = /^([a-z]{1,8}(?:-[a-z]{1,8})?)\|([A-Za-z ]{1,40})\|([01])$/.exec(one);
        if (!f) return;
        var item = menu.addItemWithTitleActionKeyEquivalent($(f[2]), 'trmnlPicked:', $(''));
        trmnlHint(item, f[1]);
        item.target = trmnlHand;
        item.tag = trmnlOffered.length;
        item.enabled = f[3] == '1';
        trmnlOffered.push(f[1]);
    });
    menu.popUpMenuPositioningItemAtLocationInView($(), $.NSMakePoint(+at[1], +at[2]), canvas);
}
function trmnlPicked(item) {    // an item chosen: Copy and Paste are the window's own, any other is said to lzrprf, which takes only what it offered
    var id = trmnlOffered[item.tag];
    trmnlOffered = [];
    if (!id || !trmnlKeys || modalOpen) return;
    if (id == 'copy') return trmnlCopy();
    if (id == 'paste') return trmnlPaste();
    say('page menu ' + id);
}
ObjC.registerSubclass({ name: 'LzrprfTrmnlHand', superclass: 'NSObject', methods: {
    'trmnlPicked:': { types: ['void', ['id']], implementation: function (item) { trmnlPicked(item); } }
} });
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
