# The window's native Inspect pane. It uses the live page relay and never evaluates JavaScript here.
# SYNC: managed-projects/lzrbrwsr/ARCHITECTURE.md §7.4 ; src/24-inspect.pl
# TRIAD(tests: managed-projects/lzrbrwsr/src/page/scripted_inspect.rs, docs: managed-projects/lzrbrwsr/ARCHITECTURE.md)
sub window_inspect_text {
    return <<'END';
var inspectUI = null, inspectHand = null, inspectSerial = 0;
var INSPECT_WARNING = 'Do not paste code you do not understand. It can act as you on this site. Type allow pasting and press Return to enable paste in this pane.';
var INSPECT_SOURCE_BYTES = 500;    // DECLARED(the bound of the checked page relay, src/24-inspect.pl)
function inspectAvailable() { return liveOn && !trmnlKeys && pageShown && free && !modalOpen; }
function inspectFits(one) { return one && liveOn && !trmnlKeys && selected == one.tab && tabs[selected] && tabs[selected].gen == one.gen && current == one.address; }
function inspectNext() { inspectSerial = inspectSerial % 999999999 + 1; return inspectSerial; }    // DECLARED(the numbered frame allows nine digits)
function inspectHex(text) {
    return encodeURIComponent(text).replace(/%([0-9a-f]{2})|./gi, function (part, byte) { return byte ? byte.toLowerCase() : part.charCodeAt(0).toString(16); });
}
function inspectText(hex) { return hex == '-' ? '' : decodeURIComponent(hex.replace(/../g, '%$&')); }
function inspectPaint(one) {
    var text = [one.note, one.logs, one.result].filter(Boolean).join('\n');
    if (String(one.output.string.js || '') == text) return;
    one.output.string = $(text);
    one.output.scrollRangeToVisible($.NSMakeRange(text.length, 0));
}
function inspectMessage(one, text) { one.note = text; inspectPaint(one); }
function inspectAsk(one, source) {
    one.pending = inspectNext();
    one.sent = Date.now();
    say('inspect ' + one.tab + ' ' + one.panel + ' ' + one.pending + ' ' + source);
}
function inspectTold(rest) {
    var one = inspectUI, reply = /^([0-9]+) ([0-9]+) ([0-9]+) (-|[0-9a-f]+) (-|[0-9a-f]+)$/.exec(rest);
    if (!inspectFits(one) || !reply || +reply[1] != one.tab || +reply[2] != one.panel || +reply[3] != one.pending) return;
    one.pending = 0;
    try {
        if (one.command !== null) one.result = '> ' + one.command + '\n' + inspectText(reply[4]);
        one.logs = inspectText(reply[5]);
    } catch (error) { inspectMessage(one, 'The page returned unreadable console text.'); }
    one.command = null;
    one.ready = true;
    inspectPaint(one);
}
function inspectTick() {
    var one = inspectUI;
    if (!inspectFits(one)) { inspectClose(); return; }
    if (modalOpen || !free) return;
    if (one.pending) {
        if (Date.now() - one.sent > 3000) inspectMessage(one, 'Waiting for the page to answer.');
        return;
    }
    if (one.ready) inspectAsk(one, '-');
}
function inspectRun() {
    var one = inspectUI;
    if (!inspectFits(one) || !inspectAvailable()) return;
    var source = String(one.input.string.js || '');
    if (!source.trim()) return;
    if (source == 'allow pasting' && !one.paste) {
        one.paste = true;
        one.input.string = $('');
        inspectMessage(one, 'Paste is enabled until this pane closes.');
        return;
    }
    if (!one.ready || one.pending) { inspectMessage(one, 'Wait for the current console request to finish.'); return; }
    var encoded;
    try { encoded = inspectHex(source); } catch (error) { inspectMessage(one, 'The command has text the console cannot read.'); return; }
    if (encoded.length > 2 * INSPECT_SOURCE_BYTES || /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(source)) {
        inspectMessage(one, 'Use up to ' + INSPECT_SOURCE_BYTES + ' UTF-8 bytes of JavaScript.');
        return;
    }
    one.command = source;
    one.input.string = $('');
    one.note = '';
    inspectPaint(one);
    inspectAsk(one, encoded);
}
function inspectPasteboard(board) {
    var one = inspectUI;
    if (!inspectFits(one) || !inspectAvailable()) return false;
    if (!one.paste) { inspectMessage(one, INSPECT_WARNING); return false; }
    var text = board.stringForType($('public.utf8-plain-text')).js;
    if (typeof text != 'string') return false;
    var old = String(one.input.string.js || ''), at = one.input.selectedRange;
    var fresh = old.slice(0, at.location) + text + old.slice(at.location + at.length);
    try {
        if (inspectHex(fresh).length > 2 * INSPECT_SOURCE_BYTES) { inspectMessage(one, 'The pasted command is too long.'); return false; }
    } catch (error) { inspectMessage(one, 'The pasted text is unreadable.'); return false; }
    one.input.string = $(fresh);
    one.input.selectedRange = $.NSMakeRange(at.location + text.length, 0);
    return true;
}
function inspectPaste() {
    if (!inspectUI || !inspectUI.paste) {
        if (inspectUI) inspectMessage(inspectUI, INSPECT_WARNING);
        return;
    }
    inspectPasteboard($.NSPasteboard.generalPasteboard);
}
busyClass({ name: 'LzrprfInspectActions', superclass: 'NSObject', methods: {
    'openInspect:': { types: ['void', ['id']], implementation: function (sender) { inspectOpen(); } },
    'runInspect:': { types: ['void', ['id']], implementation: function (sender) { inspectRun(); } },
    'closeInspect:': { types: ['void', ['id']], implementation: function (sender) { inspectClose(); } },
    'tickInspect:': { types: ['void', ['id']], implementation: function (timer) { inspectTick(); } },
    'textView:doCommandBySelector:': { types: ['bool', ['id', 'SEL']], implementation: function (view, command) {
        var name = ObjC.selectorAsString(command);
        if (name == 'insertNewline:' && !(app.currentEvent.modifierFlags & SHIFT)) { inspectRun(); return true; }
        if (name == 'cancelOperation:') { inspectClose(); return true; }
        return false;
    } }
} });
busyClass({ name: 'LzrprfInspectInput', superclass: 'NSTextView', methods: {
    'paste:': { types: ['void', ['id']], implementation: function (sender) { inspectPaste(); } },
    'pasteAsPlainText:': { types: ['void', ['id']], implementation: function (sender) { inspectPaste(); } },
    'pasteAsRichText:': { types: ['void', ['id']], implementation: function (sender) { inspectPaste(); } },
    'readSelectionFromPasteboard:': { types: ['bool', ['id']], implementation: function (board) { return inspectPasteboard(board); } },
    'readSelectionFromPasteboard:type:': { types: ['bool', ['id', 'id']], implementation: function (board, type) { return inspectPasteboard(board); } },
    'performDragOperation:': { types: ['bool', ['id']], implementation: function (drag) { return false; } }
} });
function inspectActions() {
    if (!inspectHand) inspectHand = $.LzrprfInspectActions.alloc.init;
    return inspectHand;
}
function inspectMenu(copy) {
    var menu = $.NSMenu.alloc.initWithTitle($(''));
    if (copy) menu.addItemWithTitleActionKeyEquivalent($('Copy'), 'copy:', $(''));
    if (inspectAvailable()) {
        var item = menu.addItemWithTitleActionKeyEquivalent($('Inspect'), 'openInspect:', $(''));
        item.target = inspectActions();
    }
    return menu;
}
function inspectContext(event) {
    if (!inspectAvailable()) return false;
    $.NSMenu.popUpContextMenuWithEventForView(inspectMenu(false), event, canvas);
    return true;
}
function inspectTextView(frame, editable) {
    var scroll = $.NSScrollView.alloc.initWithFrame(frame);
    scroll.autoresizingMask = 2;
    scroll.hasVerticalScroller = true;
    scroll.borderType = 1;
    var view = editable ? unchecked($.LzrprfInspectInput.alloc.initWithFrame(frame)) : unchecked($.NSTextView.alloc.initWithFrame(frame));
    view.autoresizingMask = 2;
    view.editable = editable;
    view.richText = false;
    view.backgroundColor = DARK;
    view.textColor = WHITE;
    view.insertionPointColor = WHITE;
    view.font = mono(13, false);
    view.textContainerInset = $.NSMakeSize(7, 5);
    view.unregisterDraggedTypes;
    scroll.documentView = view;
    return { view: view, scroll: scroll };
}
function inspectButton(title, action, frame) {
    var item = $.NSButton.alloc.initWithFrame(frame);
    item.title = $(title);
    item.target = inspectHand;
    item.action = action;
    item.bezelStyle = 1;
    item.autoresizingMask = 1;
    return item;
}
function inspectOpen() {
    if (!inspectAvailable()) return;
    if (inspectFits(inspectUI)) { win.makeFirstResponder(inspectUI.input); return; }
    inspectClose();
    inspectActions();
    var wide = Math.max(280, root.bounds.size.width - 44), high = 260;
    var pane = $.NSBox.alloc.initWithFrame($.NSMakeRect(22, 42, wide, high));
    pane.autoresizingMask = 2 | 32;
    pane.boxType = 4;
    pane.titlePosition = 0;
    pane.fillColor = DARK;
    pane.borderColor = EDGE;
    pane.borderWidth = 1;
    pane.cornerRadius = 10;
    var inside = pane.contentView;
    var title = $.NSTextField.labelWithString($('Inspect JavaScript'));
    title.frame = $.NSMakeRect(12, high - 31, 205, 20);
    title.font = sans(14);
    title.textColor = WHITE;
    var output = inspectTextView($.NSMakeRect(12, 66, wide - 24, high - 105), false);
    var input = inspectTextView($.NSMakeRect(12, 12, wide - 100, 44), true);
    input.view.delegate = inspectHand;
    inside.addSubview(title);
    inside.addSubview(output.scroll);
    inside.addSubview(input.scroll);
    inside.addSubview(inspectButton('Run', 'runInspect:', $.NSMakeRect(wide - 82, 15, 70, 27)));
    inside.addSubview(inspectButton('Close', 'closeInspect:', $.NSMakeRect(wide - 82, high - 34, 70, 27)));
    root.addSubviewPositionedRelativeTo(pane, -1, veil);
    var one = inspectUI = { pane: pane, input: input.view, output: output.view, tab: selected, gen: tabs[selected].gen, address: current,
        panel: inspectNext(), pending: 0, command: null, logs: '', result: '', note: '', ready: false, paste: false };
    one.timer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1, inspectHand, 'tickInspect:', $(), true);
    win.makeFirstResponder(one.input);
    inspectAsk(one, 'open');
}
function inspectClose() {
    if (!inspectUI) return;
    var one = inspectUI;
    inspectUI = null;
    if (one.timer) one.timer.invalidate;
    one.pane.removeFromSuperview;
}
END
}

# Read by selftest from the shipped source and appended only to its hidden window.
sub inspect_window_test_text {
    return <<'END';
// A hidden window in selftest. No clipboard is read and no real page script is executed here.
function inspectWindowTried() {
    var state = [liveOn, trmnlKeys, pageShown, free], saveSay = say, lines = [], answer = '';
    try {
        liveOn = pageShown = free = true;
        trmnlKeys = false;
        say = function (line) { lines.push(line); };
        var menu = page.menuForEvent(null), laid = inspectMenu(false);
        var labels = menu.numberOfItems == 2 && menu.itemAtIndex(1).title.js == 'Inspect' && laid.itemAtIndex(0).title.js == 'Inspect';
        var item = menu.itemAtIndex(1);
        item.target.openInspect(item);
        var one = inspectUI, open = lines.length == 1 && /^inspect .+ open$/.test(lines[0]);
        one.input.paste(null);
        var blocked = !one.paste && one.note == INSPECT_WARNING && lines.length == 1;
        inspectTold(one.tab + ' ' + one.panel + ' ' + one.pending + ' - -');
        one.input.string = $('allow pasting');
        inspectRun();
        var enabled = one.paste && one.input.string.js == '' && lines.length == 1;
        one.input.string = $('6 * 7');
        inspectRun();
        var sent = lines.length == 2 && lines[1].slice(-10) == '36202a2037';
        inspectTold(one.tab + ' ' + one.panel + ' ' + one.pending + ' 3432 6c6f673a206f6b');
        var output = one.output.string.js.indexOf('42') >= 0 && one.output.string.js.indexOf('log: ok') >= 0;
        liveOn = false;
        inspectTick();
        answer = [labels, open, blocked, enabled, sent, output, inspectUI === null].join(' ');
    } catch (e) { answer = 'fault ' + String(e).replace(/\s+/g, ' ').slice(0, 170); }
    finally {
        inspectClose();
        liveOn = state[0]; trmnlKeys = state[1]; pageShown = state[2]; free = state[3];
        say = saveSay;
    }
    return answer;
}
END
}
