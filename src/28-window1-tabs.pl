// The window, continued from 28-window.pl (taken out of it at 800+ lines, HC-0856): a tab pressed,
// dragged along the strip and pulled out of the window. Dragging a tab only ever moves the tab: the
// strip says no to macOS moving the window from a press on it (mouseDownCanMoveWindow, at LzrprfTabs),
// and nothing here moves the window while a tab is held. The strip beside the tabs still moves the
// window, through windowHeld, as a title bar does.
//
// A tab pressed and let go where it was pressed is chosen. Dragged along the strip it is moved among
// the tabs: it follows the pointer, the others make room, and where it is let go it stays ("tab move").
function slotOf(from, dx, wide, count) { return Math.max(0, Math.min(count - 1, Math.round((from * wide + dx) / wide))); }    // the place among count tabs that a tab dragged dx points from place "from" is over
function placeOf(k, from, to) { return k == from ? to : from < to && k > from && k <= to ? k - 1 : to < from && k >= to && k < from ? k + 1 : k; }    // where the tab at place k stands once the one at "from" has gone to "to"
function tabLeft(i, wide) {    // where a tab is drawn: at its place, or, while one is dragged, the held one under the pointer and the others where they would stand; pulled out, the others close up behind it
    if (!drag) return TABS_X + i * wide;
    if (i == drag.tab) return Math.max(TABS_X, Math.min(TABS_X + (tabs.length - 1) * wide, TABS_X + i * wide + drag.dx));
    return TABS_X + placeOf(i, drag.tab, drag.out ? tabs.length - 1 : drag.slot) * wide;
}

// A tab pulled away from the strip, more than PULL_OUT points above or below where it was pressed, or
// out past any side of the window, and let go there becomes a window of its own, where it was let go:
// lzrprf is told "tab out N X Y W H" and starts a second lzrprf for it (sub tab_out). While it is away
// it is drawn as the small window it will be, a few points lower, at once. The only tab of a window is
// drawn so too, and the window stays where it is while it is held; let go away, that tab is already a
// window of its own, so its window is put there, under the pointer as a new window would be, and its
// page goes with it, neither fetched again nor laid out again.
var PULL_OUT = 54;    // DECLARED(54 points: past the strip's 42 from any place in it, so a tab dragged along the strip never leaves it by a tremble)
function pulledOut(dy) { return Math.abs(dy) > PULL_OUT; }
function outsideOf(at, f) { return at.x < f.x || at.x > f.x + f.w || at.y < f.y || at.y > f.y + f.h; }    // a point of the screen beyond the window's frame f
function pulledFrame(f, start, at, i, wide) {    // the new window: this one's size, placed so the tab is under the pointer as it was here, the first of its strip
    return [Math.round(at.x - (start.x - f.x) + i * wide), Math.round(at.y - (start.y - f.y)), Math.round(f.w), Math.round(f.h)].join(' ');
}

function tabHeld(i) {
    var was = selected, kept = i != selected ? tabChosen(i) : null;    // chosen on the way down: the strip and the tab's kept drawing show in the frame of the press
    var start = $.NSEvent.mouseLocation, wide = tabWide(), f = win.frame, from = { x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height }, at = start, alone = tabs.length < 2;
    for (;;) {    // until the button is let go: 6 is a drag of the left button, 2 its release
        var next = win.nextEventMatchingMaskUntilDateInModeDequeue((1 << 6) | (1 << 2), $.NSDate.distantFuture, $('NSEventTrackingRunLoopMode'), true);
        if (!next || next.isNil() || next.type == 2) break;
        at = $.NSEvent.mouseLocation;
        var dx = at.x - start.x, dy = at.y - start.y, out = (pulledOut(dy) || outsideOf(at, from)) && (alone || takes());    // the only tab goes out by moving its own window, which asks lzrprf nothing
        if (!drag && (Math.abs(dx) < 5 && !out || !takes() && !out || alone && !out)) continue;    // DECLARED(5 points: a press that only trembles is a click, not a drag); the only tab has no other place in the strip
        drag = { tab: i, dx: dx, slot: out || alone ? i : slotOf(i, dx, wide, tabs.length), out: out };
        tabsView.needsDisplay = true;
        tabsView.displayIfNeeded;
    }
    var to = drag ? drag.slot : i, away = !!drag && drag.out;
    drag = null;
    tabsView.needsDisplay = true;
    if (away && alone) {    // the only tab let go away: its window is put where the new one would open, once, at the release
        var put = pulledFrame(from, start, at, i, wide).split(' ');
        win.setFrameOrigin($.NSMakePoint(+put[0], +put[1]));
        if (kept !== null) tabSaid('tab select ' + i, undefined, kept);
        return frameSaid();
    }
    if (!takes()) { if (kept !== null) tabSaid('tab select ' + i, undefined, kept); return; }    // lzrprf is busy: the tab chosen is said when it is free
    if (away) { pulling = i; return tabSaid('tab out ' + i + ' ' + pulledFrame(from, start, at, i, wide)); }    // let go away from the strip: a window of its own; the strip lets it go once lzrprf says the tabs without it
    var told = was;    // the tab lzrprf has chosen
    if (to != i) {    // the strip shows the new order at once; lzrprf moves the tab and tells the tabs again
        var one = tabs.splice(i, 1)[0];
        tabs.splice(to, 0, one);
        shares[selected] = shareNow();
        while (shares.length < tabs.length) shares.push(0);
        shares.splice(to, 0, shares.splice(i, 1)[0]);
        while (drawings.length < tabs.length) drawings.push(null);
        drawings.splice(to, 0, drawings.splice(i, 1)[0]);
        told = placeOf(was, i, to);
        selected = to;    // the tab held is the chosen one
        pageScrollTabbed();
        moving = true;
        sent('tab move ' + i + ' ' + to);
    }
    if (to != told) tabSaid('tab select ' + to, undefined, !!kept);
}


// The first press on a window that is not in front (Henry, 2026-11-24): it brings the window forward and
// does what it presses, at once, as a button of the system's does, so a tab is chosen, a button pressed
// and the bar takes the caret with one press. AppKit hands that press to the view under it only when
// the view takes the first mouse, and hands it once: never again after the window has come forward. A
// tab pressed so is held as any press is (tabHeld), so a drag still moves the tab alone. Hovers need no
// focus either: every tracking area is active in front or not (tracked), and tooltips show while the
// application is not in front (allowsToolTipsWhenApplicationIsInactive). The pointer only passing over
// the window never brings it forward: that would take the keyboard from the application being typed in.
//
// The band of the title bar, the top 32 points where the tabs are, is the exception: there AppKit asks
// the strip whether it takes the first mouse, hears yes, and keeps the press for the title bar all the
// same (measured in selftest: the same press 16 points lower is handed over). So each press AppKit asks
// about waits for the end of its turn of the run loop; a press the strip took by then is done (firstAgain),
// and one it never got is done here, once (firstMissed): held, as any press of the strip; already let go,
// as a click, with no hold.
var firstLost = null, firstDone = null, firstHand = null;
function clickThrough(methods) { methods['acceptsFirstMouse:'] = { types: ['bool', ['id']], implementation: function (event) { return firstTaken(event); } }; return methods; }
function firstTaken(event) { firstWaits(event); return true; }    // one function, so selftest can count each time AppKit asks
function firstWaits(event) {
    if (!event || event.isNil() || event.type != 1) return;    // 1: the left button pressed
    firstLost = event;
    firstHand = firstHand || $.LzrprfFirst.alloc.init;
    firstHand.performSelectorWithObjectAfterDelay('missed:', $(), 0);
}
function firstAgain(event) {    // at each press the strip takes: nothing waits any more; whether it is the press already done for the band
    firstLost = null;
    return !!firstDone && event.timestamp == firstDone.timestamp && event.eventNumber == firstDone.eventNumber;
}
function firstMissed() {
    var event = firstLost;
    firstLost = null;
    if (!event || !win || event.windowNumber != win.windowNumber) return;
    var over = win.contentView.superview.hitTest(event.locationInWindow);
    if (over.isNil() || !over.isEqual(tabsView)) return;
    firstClicked(event);
    firstDone = event;
}
function firstClicked(event) {
    if ($.NSEvent.pressedMouseButtons & 1) return tabClicked(event);    // still held: a drag moves the tab, as any press of the strip
    var hit = tabAt(event), i = hit[0];
    if (dotAt(pointIn(tabsView, event)) >= 0 || i == tabs.length || hit[1]) return tabClicked(event);    // a dot, the + and a tab's x hold nothing
    if (i < 0 || i == selected) return;    // beside the tabs, or the tab shown: bringing the window forward was all of it
    var kept = tabChosen(i);
    if (!takes()) { if (kept !== null) tabSaid('tab select ' + i, undefined, kept); return; }
    tabSaid('tab select ' + i, undefined, !!kept);
}
busyClass({ name: 'LzrprfFirst', superclass: 'NSObject', methods: { 'missed:': { types: ['void', ['id']], implementation: function (sender) { firstMissed(); } } } });
// The address bar's first press selects the whole address, so it copies at once; a press while the bar is edited places the
// caret where it lands, as any field does (Henry, 2026-11-25). Find's field keeps a field's own press.
function barSelectsAll(field) {
    if (!bar || !field.isEqual(bar) || !bar.enabled) return false;
    var editor = bar.currentEditor;
    if (editor && !editor.isNil()) return false;
    win.makeFirstResponder(bar);
    bar.selectText(null);
    belt.needsDisplay = true;
    return true;
}
busyClass({ name: 'LzrprfField', superclass: 'NSTextField', methods: clickThrough({}) });    // the bar and Find's field
// The bar's press is taken by a cover lying over it, never by the field: no class here calls ObjC.super (release 74 hung on
// it). Not edited, the press selects the whole address; edited, the press goes to the field editor, which places the caret
// where it lands, selects a word on two presses and a stretch on a drag, as a field does.
var barCover;
function coverPressed(event, right) {
    if (!bar || !bar.enabled) return;
    if (barSelectsAll(bar) && !right) return;
    var editor = bar.currentEditor;
    if (!editor || editor.isNil()) return;
    if (right) editor.rightMouseDown(event); else editor.mouseDown(event);
}
busyClass({ name: 'LzrprfCover', superclass: 'NSView', methods: clickThrough({
    'resetCursorRects': { implementation: function () { this.addCursorRectCursor(this.bounds, $.NSCursor.IBeamCursor); } },
    'rightMouseDown:': { implementation: function (event) { coverPressed(event, true); } },
    'mouseDown:': { implementation: function (event) { pressSeen(event); coverPressed(event); } }
}) });
// The question about scripts never holds the page (sub permit_button), and it does not hold the tabs either (Henry, 2026-11-25):
// a press on the strip under its veil is its default answer, Deny Once, as when nobody answers, and then the press the strip
// takes as any other: a tab chosen, closed, made or dragged. Every other modal keeps its veil whole.
var permitAsked = 0;    // the number of the question about scripts last shown (permitTold)
function veilPressed(event) {
    if (!modalOpen || (modalKind != 'permit' && modalKind != 'tall') || permitAsked != asked || !tabsView) return;
    var at = tabsView.convertPointFromView(event.locationInWindow, null), size = tabsView.bounds.size;
    if (at.x < 0 || at.y < 0 || at.x > size.width || at.y > size.height) return;
    closeModal();
    say('button ' + permitAsked + ' 1');
    tabsView.mouseDown(event);
}
// [C26] The question about scripts can be minimized (ticket 1230): Minimize closes it unanswered, so the page and the window go
// on as with Deny Once, the answer when nobody answers, and the LZRDFNDR icon brings it back while it is still the newest
// question. A newer question, or the page going on to another, ends it: lzrprf takes no late answer (sub permit_visited).
var permitLater = null;    // lzrprf sends only one unanswered script question at a time
function permitLaterSet(question) {
    permitLater = question;
    if (toolIcon) toolIcon.needsDisplay = true;
}
function permitLaterBadge(size) {
    if (!permitLater || permitLater.number != asked) return;
    var bubble = $.NSMakeRect(size.width - 12, size.height - 12, 11, 11);
    GREEN.setFill;
    $.NSBezierPath.bezierPathWithOvalInRect(bubble).fill;
    centred(styled('1', inked(sans(8, true), DARK)), bubble.origin.x + 5.5, bubble.origin.y, 0);
}
function permitShow(parts, number, scripts) {
    // Forget is a choice of the site's LZRDFNDR settings, not of the question (Henry, 2026-11-26).
    var answerByPosition = [4, 3, 2, 1];
    var choices = ASK_PILLS.map(function (choice, i) {
        return [choice[0], function () { permitLaterSet(null); closeModal(); say('button ' + number + ' ' + answerByPosition[i]); }];
    });
    choices.push(['Minimize', function () {
        permitLaterSet({ parts: parts, number: number, scripts: scripts });
        modalFrom = toolIcon;
        closeModal();
    }]);
    modal('LZRDFNDR scripts', parts[1] || '', choices, scripts.length ? 'permit' : 'tall');
    if (parts.essential) webWarning('script', function () { permitShow(parts, number, scripts); });
    if (!scripts.length) return;
    panelText.string = $(permitCodeText(scripts));
    panelText.font = mono(11.5);
    panelText.textColor = WHITE;
    panelText.scrollRangeToVisible($.NSMakeRange(0, 0));
}
function permitReopened() {    // true when the LZRDFNDR icon brought a minimized question back
    if (!permitLater || permitLater.number != asked) { permitLaterSet(null); return false; }
    var later = permitLater; permitLaterSet(null);
    flyNext = { icon: toolIcon, at: Date.now() };
    permitShown = later.scripts; permitAsked = later.number;
    permitShow(later.parts, later.number, later.scripts);
    firstFlown();
    return true;
}
