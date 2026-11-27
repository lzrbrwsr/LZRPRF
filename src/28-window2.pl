// The window, continued from 28-window.pl (split there at 800+ lines, HC-0843): LZRDFNDR's Show all
// processes, then the window's start (function run).
//
// Show all processes, the button at the bottom left of On Your Computer (HC-0843). A press asks lzrprf
// for "tool all": the same look and list as Recognition, and after the rows one "tool proc" line for every
// process of the computer (sub tool_procs), fifteen fields parted by tabs: PID, CPU %, memory in KiB,
// group, title, what it is, where that was read, your note, parent PID, user, started, program, command
// line, who signed it, its launchd job. The list then shows them under the rows, grouped (core processes
// first, by their names core-<realm>-<purpose>), each with its title, PID, CPU, memory, description and
// note in columns, and two controls: Copy info, which writes everything gathered of the process to the
// clipboard (through clipboardWrite, the window's one write) so it can be pasted to an agent, and the
// Notes cell, which opens a field over itself; Return keeps the note ("tool note PROGRAM<tab>TEXT",
// kept by lzrprf for every process of that program). The panel widens to PROCS_WIDE while they show.
// Nothing here changes a process: ending one stays a ticked row of the list above, confirmed.
// SYNC: 14-tool.pl (sub tool_procs, sub tool_note), ../lzrbrwsr/architecture/lzrdfndr.md §11, docs/window.md
// Clear Cookies of This Site, in the Go menu (J2, ../lzrbrwsr/architecture/cookie-jar.md): asked once, then
// "menu forget-cookies", and lzrprf clears the cookies of the shown tab's site from the jar (sub jar_forget).
function cookieSite() {
    if (!takes()) return;
    modal('Clear cookies of this site?', 'The cookies of the site in this tab are cleared, under every site you visited it from, and its pages see you as new: you may need to sign in to it again. Other sites keep theirs.',
        [['Cancel', closeModal], ['Clear cookies', function () { closeModal(); sent('menu forget-cookies'); }]], 'small');
}
var toolAll = false, toolAllButton = null, procNoteField = null, procEditing = null, PROCS_WIDE = 1120, PROCS_ROW = 40;    // DECLARED(wide enough for seven columns with a description of two lines; a row as tall as two lines of 11 points)
var PROC_GROUPS = [['core', 'Core processes'], ['lzrbrwsr', 'LZRBRWSR and lzrprf'], ['yours', 'Your apps and programs'], ['macos', 'macOS'], ['others', 'Other users']];
var PROC_FIELDS = ['pid', 'cpu', 'mem', 'group', 'title', 'about', 'source', 'note', 'ppid', 'user', 'began', 'path', 'args', 'signed', 'job'];
// The controls of a row, drawn right to left from the row's end. HC-0845 (LZRPRF wraps a process in its
// container, closes it and keeps it closed) adds its own here, beside Copy info: [words, width, what a press does].
var PROC_ACTIONS = [['Copy info', 74, procCopied]];
var PROC_COPY_LEAD = 'This process was found by LZRDFNDR in LZRBRWSR (Show all processes). Please help me understand what it is and whether I should keep it, close it, or keep it closed:';
function procsTold(word, more) {    // "tool proc ..." between "tool begin" and "tool end", and "tool noted kept|failed" after a note
    if (word == 'noted') { if (tool) { tool.said = more == 'kept' ? 'Note kept.' : 'The note could not be written.'; toolChanged(); } return; }
    var f = more.split('\t');
    if (!toolIn || f.length != PROC_FIELDS.length || !/^\d{1,7}$/.test(f[0])) return;
    var one = {};
    PROC_FIELDS.forEach(function (name, k) { one[name] = f[k]; });
    one.pid = +one.pid; one.cpu = one.cpu == '-' ? -1 : +one.cpu || 0; one.mem = one.mem == '-' ? -1 : +one.mem || 0;
    (toolIn.procs = toolIn.procs || []).push(one);
}
function procsShown() { return !!tool && toolAll && toolTab == 'computer' && !tool.confirm && !!tool.procs && tool.procs.length > 0; }
function procsPressed() {    // the button: on, lzrprf is asked for every process; off, the list shows the found apps only and asks nothing
    if (!tool || tool.busy || tool.confirm || !modalOpen || modalKind != 'tool' || toolTab != 'computer') return;
    toolAll = !toolAll; procNoteHidden();
    TOOL_WIDE = toolAll ? PROCS_WIDE : 800;
    if (toolAll) { tool.busy = 'Reading every process of this computer'; say('tool all'); }
    placeModal(); toolChanged(); toolView.scrollPoint($.NSMakePoint(0, 0));
}
function procsEnabled() {    // the button, on On Your Computer only, not on the question; its words say what a press does
    if (!toolAllButton) return;
    toolAllButton.hidden = !tool || !!tool.confirm || !modalOpen || modalKind != 'tool' || toolTab != 'computer';
    toolAllButton.enabled = !!tool && !tool.busy;
    toolAllButton.title = $(toolAll ? 'Show found apps only' : 'Show all processes');
    if (toolAllButton.hidden) procNoteHidden();
}
function procsPlaced(M, w) {    // bottom left, left of the panel's own buttons; on the row above, right of the copy button, when they leave no room
    partsPlaced(M, w);    // and the boxes of the modules modal and of LZRTNNL (below)
    if (!toolAllButton) return;
    var left = panelButtons.length ? panelButtons[0].frame.origin.x : M + w - 26, wide = 180;
    toolAllButton.frame = left - 10 - (M + 26) >= wide ? $.NSMakeRect(M + 26, M + 18, wide, 32) : $.NSMakeRect(M + 26 + Math.min(w - 52, 380) + 10, M + 62, wide, 32);
}
function procOrder(a, b) { return b.cpu - a.cpu || b.mem - a.mem || a.pid - b.pid; }
function procsLaid(items, y, w) {    // under the rows: the words, the heading of the columns, and each group with its processes
    if (!procsShown()) { if (toolAll && tool && !tool.busy && toolTab == 'computer' && !tool.confirm) { items.push({ text: 'No process was listed: lzrprf could not read them, or the application did not answer.', font: sans(12.5), colour: GREY, y: y + 8, h: 18 }); y += 34; } return y; }
    var words = 'Every process of this computer: ' + tool.procs.length + '. CPU is its share of one processor now and Memory what it holds in memory. A description comes from LZRDFNDR’s table, a core process’s name, or the manual page of its program on this Mac; nothing of this list leaves the computer. Copy info copies everything gathered of a process, to paste to an agent; click a Notes cell to write a note.';
    items.push({ text: words, font: sans(12.5), colour: WHITE, y: y + 10, h: 50 }); y += 66;
    items.push({ procs: 'head', y: y, h: 22 }); y += 26;
    PROC_GROUPS.forEach(function (group) {
        var ones = tool.procs.filter(function (one) { return one.group == group[0]; }).sort(procOrder);
        if (!ones.length) return;
        items.push({ text: group[1] + ' (' + ones.length + ')', font: sans(14, true), colour: group[0] == 'core' ? GREEN : WHITE, y: y + 6, h: 20 }); y += 30;
        ones.forEach(function (one) { items.push({ proc: one, y: y, h: PROCS_ROW }); y += PROCS_ROW + 4; });
    });
    return y + 4;
}
function procColumns(w) {    // where each column begins and how wide it is: the description takes what the others leave
    var at = 10, cols = {};
    [['title', 190], ['pid', 54], ['cpu', 54], ['mem', 74], ['about', 0], ['note', 170]].forEach(function (col) { cols[col[0]] = { x: at, w: col[1] }; at += col[1] + 10; });
    var actions = PROC_ACTIONS.reduce(function (sum, act) { return sum + act[1] + 8; }, 6), rest = w - at - actions - 6;
    cols.about.w = Math.max(80, rest); cols.note.x += cols.about.w; cols.actions = { x: w - actions, w: actions };
    return cols;
}
function procPills(one, w) { var x = w - 10; return PROC_ACTIONS.map(function (act) { x -= act[1]; var pill = { act: act, x: x, y: one.y + 8, w: act[1], h: 24 }; x -= 8; return pill; }); }
function procMemory(kib) { return kib < 0 ? '-' : kib >= 1048576 ? (kib / 1048576).toFixed(1) + ' GB' : kib >= 1024 ? (kib / 1024).toFixed(1) + ' MB' : kib + ' KB'; }
function paintProc(one, w) {
    var cols = procColumns(w), cut = function (font, colour) { return inked(font, colour, true); };
    if (one.procs == 'head') {
        [['title', 'Title'], ['pid', 'PID'], ['cpu', 'CPU'], ['mem', 'Memory'], ['about', 'Description'], ['note', 'Notes']].forEach(function (col) { $(col[1]).drawInRectWithAttributes($.NSMakeRect(cols[col[0]].x, one.y + 3, cols[col[0]].w, 16), cut(sans(11, true), GREY)); });
        return;
    }
    var p = one.proc, card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1.5, one.y + 0.5, w - 3, one.h - 1), 8, 8);
    FILL.setFill; card.fill; stroked(card, p.group == 'core' ? DIM : LINE, 1);
    var tx = cols.title.x;
    if (p.group == 'core') { var tag = styled('CORE', inked(sans(9, true), GREEN)); tag.drawAtPoint($.NSMakePoint(tx, one.y + 4)); }
    $(p.title).drawInRectWithAttributes($.NSMakeRect(tx, one.y + (p.group == 'core' ? 15 : 5), cols.title.w, 17), cut(sans(12.5, true), WHITE));
    $(p.user).drawInRectWithAttributes($.NSMakeRect(tx, one.y + 22, cols.title.w, 15), cut(sans(10.5), DIM));
    $(String(p.pid)).drawInRectWithAttributes($.NSMakeRect(cols.pid.x, one.y + 6, cols.pid.w, 16), cut(mono(11), GREY));
    $(p.cpu < 0 ? '-' : p.cpu.toFixed(1) + '%').drawInRectWithAttributes($.NSMakeRect(cols.cpu.x, one.y + 6, cols.cpu.w, 16), cut(mono(11), p.cpu >= 50 ? YELLOW : GREY));
    $(procMemory(p.mem)).drawInRectWithAttributes($.NSMakeRect(cols.mem.x, one.y + 6, cols.mem.w, 16), cut(mono(11), GREY));
    styled(p.about || 'No description known yet: Copy info gives what an agent needs to look it up.', inked(sans(11), p.about ? GREY : DIM)).drawInRect($.NSMakeRect(cols.about.x, one.y + 4, cols.about.w, one.h - 6));
    if (procEditing !== p) styled(p.note || 'Add a note', inked(sans(11), p.note ? WHITE : DIM)).drawInRect($.NSMakeRect(cols.note.x, one.y + 4, cols.note.w, one.h - 6));
    procPills(one, w).forEach(function (pill) {
        var box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(pill.x, pill.y, pill.w, pill.h), 8, 8);
        stroked(box, p.copied && pill.act[2] == procCopied ? GREEN : ICON, 1);
        var label = styled(p.copied && pill.act[2] == procCopied ? 'Copied' : pill.act[0], inked(sans(11), WHITE));
        label.drawAtPoint($.NSMakePoint(pill.x + (pill.w - label.size.width) / 2, pill.y + 4));
    });
}
function procClicked(at, items) {    // a pill of a row, or its Notes cell; true when the click was the process list's
    procNoteHidden();
    var w = toolLaid().wide, cols = procColumns(w);
    for (var k = 0; k < items.length; k++) {
        var one = items[k];
        if (!one.proc || at.y < one.y || at.y >= one.y + one.h) continue;
        var hit = procPills(one, w).filter(function (pill) { return at.x >= pill.x && at.x <= pill.x + pill.w && at.y >= pill.y && at.y <= pill.y + pill.h; })[0];
        if (hit) { hit.act[2](one.proc); return true; }
        if (at.x >= cols.note.x && at.x <= cols.note.x + cols.note.w) { procNoteOpened(one, cols); return true; }
        return true;
    }
    return false;
}
function procCopyText(p) {    // everything gathered of one process, one fact to a line
    var name = p.path.replace(/^.*\//, ''), names = [name].concat(p.signed ? [p.signed.split(' ').slice(1).join(' ')] : [], p.job ? [p.job.split(' ').slice(1).join(' ')] : []).filter(function (one, k, all) { return one && one != '-' && all.indexOf(one) == k; });
    return [PROC_COPY_LEAD, 'Title: ' + p.title, 'Process id (PID): ' + p.pid, 'Parent process id: ' + p.ppid, 'User: ' + p.user, 'Started: ' + p.began,
        'CPU: ' + (p.cpu < 0 ? 'not read' : p.cpu.toFixed(1) + '% of one processor'), 'Memory: ' + procMemory(p.mem), 'Program: ' + p.path, 'Command line: ' + (p.args || '-'),
        'Signed by: ' + (p.signed ? 'team ' + p.signed.replace(' ', ', identifier ') : 'not read'), 'Launchd job: ' + (p.job || 'none seen'), 'Group: ' + (PROC_GROUPS.filter(function (g) { return g[0] == p.group; })[0] || ['', p.group])[1],
        'Description: ' + (p.about ? p.about + ' (from ' + p.source + ')' : 'none known on this computer'), 'My note: ' + (p.note || '-'), 'Names to look it up by: ' + names.join(', ')].join('\n');
}
function procCopied(p) {
    if (!tool || tool.busy || !procsShown()) return;
    var ok = clipboardWrite(procCopyText(p));
    tool.procs.forEach(function (one) { one.copied = false; });
    p.copied = ok; tool.said = ok ? 'Copied the information of ' + p.title + ' (PID ' + p.pid + ') to the clipboard.' : 'The clipboard did not take it.';
    toolChanged();
}
function procNoteOpened(one, cols) {    // a field over the Notes cell, in the list itself; Return keeps it, a press elsewhere leaves it unkept
    procNoteHidden();
    procEditing = one.proc;
    procNoteField.frame = $.NSMakeRect(cols.note.x - 2, one.y + 6, cols.note.w + 4, 26);
    procNoteField.stringValue = $(one.proc.note || '');
    procNoteField.hidden = false;
    win.makeFirstResponder(procNoteField);
    toolView.needsDisplay = true;
}
function procNoteHidden() { if (!procNoteField || procNoteField.hidden) return; procNoteField.hidden = true; procEditing = null; if (toolView) toolView.needsDisplay = true; }
function procNoted() {    // Return in the field: the note, kept by lzrprf for every process of the same program
    var p = procEditing;
    if (!p || !tool) return procNoteHidden();
    var text = procNoteField.stringValue.js.replace(/[\x00-\x1f\x7f]+/g, ' ').replace(/^\s+|\s+$/g, '').slice(0, 500);
    tool.procs.forEach(function (one) { if (one.path == p.path) one.note = text; });
    say('tool note ' + p.path + '\t' + text);
    procNoteHidden(); toolChanged();
}
function procsMade() {    // the button and the field, made once with the panel
    toolAllButton = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 180, 32));
    toolAllButton.title = $('Show all processes'); toolAllButton.bezelStyle = 1; toolAllButton.font = sans(13); toolAllButton.target = hand; toolAllButton.action = 'toolAll:'; toolAllButton.hidden = true;
    panel.addSubview(toolAllButton);
    procNoteField = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 170, 26));
    procNoteField.font = sans(11.5); procNoteField.cell.usesSingleLineMode = true; procNoteField.cell.scrollable = true; procNoteField.placeholderString = $('A note, then Return');
    procNoteField.target = hand; procNoteField.action = 'procNote:'; procNoteField.hidden = true;
    toolView.addSubview(procNoteField);
}

// THE LZR MODULES (Henry, 2026-11-24, HC-0858). lzrprf says which parts are installed ("parts on NAME ...", from the
// record the installer and this modal share, sub parts_told); until it says, every part counts as installed. A part
// that is not installed is shown nowhere: LZRDFNDR's icon, Tor's icon, and on the home page LZRTRMNL and LZRGM (lzrprf
// tells the page, sub contained). "Add or remove LZR modules..." in the cogwheel's menu opens a modal with a box to tick
// for each part. LZRBRWSR stays ticked and cannot be unticked: this window, and the settings where the others are
// switched, are its own. Once a box differs from what is installed, "Restart with these modules" sends "parts set
// NAME ..."; lzrprf writes the record, takes away the program of a part left out, or fetches an added one through its
// signed road of an update (the installer's modal then shows), says "parts applied", and this window answers
// "restart": LZRBRWSR starts again with the new set. "parts refused WHY" stands in the modal, and nothing changed.
// SYNC: 24-parts.pl, ../lzrbrwsr/packaging/parts.sh.in, docs/window.md
var PARTS = [['lzrbrwsr', 'LZRBRWSR: the browser, its profiles and settings (always installed)'], ['lzrdfndr', 'LZRDFNDR: the tool that shows and stops what runs on this Mac'], ['lzrtrmnl', 'LZRTRMNL: the terminal tab'], ['lzrtnnl', 'LZRTNNL: Tor, with an optional VPN of your own'], ['lzrgm', 'LZRGM: the minigame of the home page']];
var MODULES_ABOUT = 'Tick the modules LZRBRWSR has. LZRBRWSR itself cannot be unticked: this window, and these settings, are its own. A module added is fetched through the signed road of an update; one removed takes its program and its menu items with it.';
var partsOn = null, partsWanted = null, partTicks = [], partsHand = null, partsSaid = '';
function partOn(name) { return !partsOn || partsOn.indexOf(name) >= 0; }
function partsTold(rest) {
    var parts = rest.split(' '), word = parts[0];
    if (word == 'on') { partsOn = parts.slice(1); if (root) place(); if (cogBox) cogBox.needsDisplay = true; return; }
    if (word == 'applied') { partsSaid = 'The modules are set. LZRBRWSR starts again with them.'; say('restart'); }
    else if (word == 'refused') partsSaid = parts.slice(1).join(' ');
    else if (word == 'install') partsSaid = 'Fetching the release through the signed road of an update.';
    if (modalOpen && modalKind == 'modules') modulesShown();
}
function modulesOpened() { if (!takes()) return; partsWanted = PARTS.map(function (one) { return partOn(one[0]); }); partsSaid = ''; modulesShown(); }
function modulesShown() { modal('Add or remove LZR modules', MODULES_ABOUT + (partsSaid ? '\n' + partsSaid : ''), modulesChoices(), 'modules'); }
function modulesChanged() { return !!partsWanted && PARTS.some(function (one, k) { return partsWanted[k] != partOn(one[0]); }); }
function modulesChoices() { return partsSaid && partsSaid.indexOf('The modules are set') == 0 ? [] : modulesChanged() ? [['Cancel', closeModal], ['Restart with these modules', modulesApplied]] : [['Close', closeModal]]; }
function modulesApplied() { partsSaid = 'Setting the modules.'; say('parts set ' + PARTS.filter(function (one, k) { return partsWanted[k]; }).map(function (one) { return one[0]; }).join(' ')); modulesShown(); }
function partTicked(sender) { var k = +sender.tag; if (k <= 0 || !partsWanted) { sender.state = 1; return; } partsWanted[k] = sender.state == 1; partsSaid = ''; panelSub.stringValue = $(MODULES_ABOUT); buttons(modulesChoices()); }
function partsShown(kind) {    // from modal(): the boxes of the modules modal and the box of LZRTNNL, each in its own kind alone
    partTicks.forEach(function (one, k) { one.hidden = kind != 'modules'; if (kind == 'modules' && partsWanted) { one.state = partsWanted[k] ? 1 : 0; one.enabled = k > 0; } });
    if (tnnlTick) { tnnlTick.hidden = kind != 'tnnl'; tnnlTick.state = tnnlVpn ? 1 : 0; tnnlTick.enabled = tnnlStep != 'busy'; }
}
function partsPlaced(M, w) {    // from placeModal, through procsPlaced: the words at the top, the boxes under them
    var h = panel.frame.size.height - 2 * M;
    if (modalKind == 'modules') { panelSub.frame = $.NSMakeRect(M + 26, M + h - 128, w - 52, 72); partTicks.forEach(function (one, k) { one.frame = $.NSMakeRect(M + 26, M + h - 170 - k * 40, w - 52, 26); }); }
    if (modalKind == 'tnnl') { panelSub.frame = $.NSMakeRect(M + 26, M + 98, w - 52, h - 156); tnnlTick.frame = $.NSMakeRect(M + 26, M + 64, w - 52, 26); }
}

// LZRTNNL IN A TOR WINDOW (Henry, 2026-11-24). A Tor window connects nothing by itself: once it is on the screen lzrprf
// says "torsession made" and its LZRTNNL modal flies out of the onion, with Connect to Tor and a box, Use also VPN.
// Ticked, the modal walks you through your own provider: the WireGuard app, its configuration file imported and
// activated there, and the same file chosen here (an Open panel; "tnnl vpn file PATH"). lzrprf reads it ("tnnl vpn read
// ADDRESS SERVER [v6]" or "tnnl refused WHY"). Connect to Tor then asks whether the VPN is active ("tnnl vpn look":
// "tnnl vpn found UTUN INDEX" or "tnnl vpn missing WHY") and only once it is says "tor on": the Tor modal and its beam
// as before. "tnnl vpn dropped" comes when the VPN went away under Tor: Tor stopped, and Try again looks for it first.
// SYNC: 16-tnnl.pl, 15-tor.pl, ../lzrbrwsr/architecture/lzrtnnl.md
var TNNL_ABOUT = 'This Tor window has not connected, and nothing is fetched until Tor is connected and the window reaches nothing past it. Connect to Tor when you are ready.';
var TNNL_VPN_ABOUT = 'Your own VPN under Tor: you, then the VPN, then Tor. Your provider sees that you use Tor and never where you go; Tor never sees your address. If the VPN drops, Tor stops and nothing goes out without it.\n1. Install the WireGuard app (App Store, by WireGuard Development Team).\n2. Import the .conf file your provider gives you (Mullvad, IVPN, Proton VPN, AirVPN and others do; its AllowedIPs must be 0.0.0.0/0), and activate it there.\n3. Choose the same file here: lzrprf keeps its address and server, never its private key.';
var tnnlTick = null, tnnlVpn = false, tnnlStep = '', tnnlSaid = '', tnnlFile = '';
function tnnlShown() {
    if (!TORWINDOW) return;
    if (!win.visible || modalOpen && modalKind != 'tor' && modalKind != 'tnnl') { partsHand.performSelectorWithObjectAfterDelay('tnnlShown:', $(), 0.1); return; }    // looked at again a moment later, as the Tor modal is
    techHidden(); secureHidden(); suggestHidden();
    flyNext = modalOpen ? null : { icon: torIcon, at: Date.now() };
    modal('LZRTNNL', tnnlAbout(), tnnlChoices(), 'tnnl');
}
function tnnlAbout() { return (tnnlVpn ? TNNL_VPN_ABOUT : TNNL_ABOUT) + (tnnlSaid ? '\n' + tnnlSaid : ''); }
function tnnlChoices() { return tnnlStep == 'busy' ? [] : tnnlVpn && !tnnlFile ? [['Hide', closeModal], ['Choose WireGuard file...', tnnlChoose]] : [['Hide', closeModal], ['Connect to Tor', tnnlConnect]]; }
function tnnlRefresh() { if (modalOpen && modalKind == 'tnnl') { panelSub.stringValue = $(tnnlAbout()); partsShown('tnnl'); buttons(tnnlChoices()); } }
function tnnlTicked(sender) { tnnlVpn = sender.state == 1; tnnlSaid = ''; if (!tnnlVpn && tnnlFile) { tnnlFile = ''; say('tnnl vpn off'); } placeModal(); tnnlRefresh(); }
function tnnlChoose() {    // the system's Open panel: one file, a WireGuard configuration
    try {
        var one = $.NSOpenPanel.openPanel;
        one.canChooseDirectories = false; one.canChooseFiles = true; one.allowsMultipleSelection = false; one.resolvesAliases = false;
        one.allowedFileTypes = $(['conf']); one.prompt = $('Choose'); one.message = $('The WireGuard file of your provider, the one you activated in the WireGuard app');
        one.beginSheetModalForWindowCompletionHandler(win, function (answer) { if (answer != 1 || one.URL.isNil()) return; tnnlStep = 'busy'; tnnlSaid = 'Reading the file.'; tnnlRefresh(); say('tnnl vpn file ' + one.URL.path.js.replace(/[^\x20-\x7e]/g, '\x7f').slice(0, 1000)); });
    } catch (e) { tnnlSaid = 'The Open panel could not be shown.'; tnnlRefresh(); }
}
function tnnlConnect() { if (!tnnlVpn) return tnnlGo(); tnnlStep = 'busy'; tnnlSaid = 'Looking for the VPN.'; tnnlRefresh(); say('tnnl vpn look'); }
function tnnlGo() { tnnlStep = ''; closeModal(); torStarted(); torShown(); }    // Tor, through the VPN when one was found: the Tor modal and its beam
function tnnlAgain() { if (!tnnlFile) return torStarted(); tnnlSaid = ''; tnnlShown(); tnnlConnect(); }    // Try again of the Tor modal: with the VPN, it is looked for first
function tnnlTold(rest) {
    var parts = rest.split(' ');
    tnnlStep = '';
    if (parts[0] == 'refused') tnnlSaid = parts.slice(1).join(' ');
    else if (parts[1] == 'read') { tnnlFile = parts[2]; tnnlSaid = 'The file names the VPN address ' + parts[2] + ' and the server ' + parts[3] + '. With it active in the WireGuard app, press Connect to Tor.'; }
    else if (parts[1] == 'missing') tnnlSaid = 'The VPN is not active: ' + parts.slice(2).join(' ') + '. Activate it in the WireGuard app, then press Connect to Tor again.';
    else if (parts[1] == 'found') return tnnlGo();
    else if (parts[1] == 'none') tnnlFile = '';
    else if (parts[1] == 'dropped') { if (words) words.stringValue = $('The VPN dropped: Tor stopped, and nothing goes out without it.'); return; }
    tnnlRefresh();
}
function partsMade() {    // the boxes of the two modals, made once with the panel, and the object their presses reach
    ObjC.registerSubclass({ name: 'LzrprfParts', superclass: 'NSObject', methods: {
        'ticked:': { types: ['void', ['id']], implementation: function (sender) { partTicked(sender); } },
        'vpn:': { types: ['void', ['id']], implementation: function (sender) { tnnlTicked(sender); } },
        'tnnlShown:': { types: ['void', ['id']], implementation: function () { tnnlShown(); } }
    } });
    partsHand = $.LzrprfParts.alloc.init;
    var tick = function (words, k, action) { var one = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 520, 26)); one.setButtonType(3); one.title = $(words); one.font = sans(13); one.tag = k; one.target = partsHand; one.action = action; one.hidden = true; panel.addSubview(one); return one; };
    partTicks = PARTS.map(function (one, k) { return tick(one[1], k, 'ticked:'); });
    tnnlTick = tick('Use also VPN: your own WireGuard VPN under Tor', 0, 'vpn:');
}

// Aim at the visible placeholder text inside the field, even when it is clipped.
function searchPlaceholderCenter(field) {
    var text = field.cell.drawingRectForBounds(field.bounds);
    var width = Math.max(0, Math.min(text.size.width, field.placeholderAttributedString.size.width));
    return $.NSMakePoint(text.origin.x + width / 2, text.origin.y + text.size.height / 2);
}

function run(argv) {
    NAME = (argv[0] || NAME).replace(/-Staging$/, ' - Staging');    // the staging application, LZRBRWSR-Staging.app, is named "LZRBRWSR - Staging" in the menu bar (Henry, 2026-11-26)
    PULLED = /\+$/.test(argv[1] || '');    // T5: "+" after the kind, said by lzrprf for a window a tab was pulled out into (sub pulled_command, --open)
    var kindWord = (argv[1] || '').replace(/\+$/, '');
    TORWINDOW = kindWord == 'tor';
    INCOGNITO = kindWord == 'incognito' || TORWINDOW;    // a Tor window is an incognito window, and more
    if (INCOGNITO) $.NSUserDefaults.standardUserDefaults.registerDefaults($({ NSQuitAlwaysKeepsWindows: false, ApplePersistenceIgnoreState: true }));    // in memory only: macOS is asked to keep no window of it to restore (and this container lets it write no file anyway)
    $.NSProcessInfo.processInfo.processName = $(NAME);
    app = $.NSApplication.sharedApplication;
    app.setActivationPolicy(kind());
    if (argv[3] !== 'bundled') menuBarNamed(NAME);
    app.applicationIconImage = icon(256);
    hand = $.LzrprfHand.alloc.init;
    app.delegate = hand;
    canvas = $.LzrprfLaid.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 640)); tracked(canvas);    // its moves and its exit, for a page kept running (28-window-pointer.pl)
    win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, 1000, 760), 15 | 32768, 2, false);    // titled, closable, minimisable, resizable, its content under the title bar
    win.title = $(INCOGNITO ? NAME + ' Incognito' : NAME);
    if (INCOGNITO) win.restorable = false;
    win.titleVisibility = 1;
    win.titlebarAppearsTransparent = true;
    [0, 1, 2].forEach(function (k) { var one = win.standardWindowButton(k); if (one && !one.isNil()) one.hidden = true; });    // the strip draws the three dots itself (paintTabs)
    win.opaque = false;
    win.hasShadow = true;    // the system's own shadow, drawn outside the window and taking no press: the frame's glow falls inward now
    win.releasedWhenClosed = false;
    win.allowsToolTipsWhenApplicationIsInactive = true;    // a tooltip shows while another application is in front (clickThrough, 28-window1-tabs.pl)
    win.minSize = $.NSMakeSize(560, 360);
    opened(argv[2] || 'none');
    win.delegate = hand;
    laser();
    win.appearance = $.NSAppearance.appearanceNamed($('NSAppearanceNameDarkAqua'));
    win.backgroundColor = $.NSColor.clearColor;
    frameView = $.LzrprfFrame.alloc.initWithFrame($.NSMakeRect(0, 0, 1000, 760));
    win.contentView = frameView;
    root = $.NSView.alloc.initWithFrame($.NSMakeRect(17, 17, 966, 726));
    win.contentView.addSubview(root);
    tabsView = $.LzrprfTabs.alloc.initWithFrame($.NSMakeRect(0, 0, 960, TABS_HIGH));
    root.addSubview(tabsView);
    belt = $.LzrprfBelt.alloc.initWithFrame($.NSMakeRect(0, 0, 960, BAR_ROW));    // under the bar and the cogwheel: what they do not take, it takes
    root.addSubview(belt);
    bar = $.LzrprfField.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 24));
    bar.placeholderAttributedString = styled('Search or enter a website', inked(sans(14), GREY));
    bar.font = sans(14);
    bar.textColor = WHITE;
    bar.bordered = false;
    bar.bezeled = false;
    bar.drawsBackground = false;
    bar.focusRingType = 1;    // none: the pill around it glows instead (paintBelt)
    bar.delegate = hand;
    bar.cell.allowsUndo = true;    // Cmd-Z and Cmd-Shift-Z undo and redo typing step by step (the Edit menu)
    bar.cell.usesSingleLineMode = true;
    bar.cell.scrollable = true;
    bar.target = hand;
    bar.action = 'go:';
    bar.enabled = false;
    bar.autoresizingMask = 2 | 8;
    root.addSubview(bar);
    barCover = $.LzrprfCover.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 24));    // over the bar: it takes the bar's press (coverPressed)
    barCover.autoresizingMask = 2 | 8;
    root.addSubview(barCover);
    star = $.LzrprfStar.alloc.initWithFrame($.NSMakeRect(0, 0, 30, 30));
    if (INCOGNITO) star.toolTip = $(UNKEPT_TIP);
    root.addSubview(star);
    cog = $.LzrprfCog.alloc.initWithFrame($.NSMakeRect(0, 0, 30, 30));
    root.addSubview(cog);
    faces = $.LzrprfFaces.alloc.initWithFrame($.NSMakeRect(0, 0, 30, 30));    // the Profiles icon: hidden until lzrprf tells the profiles, and in an incognito window always
    faces.hidden = true;
    root.addSubview(faces);
    marksView = $.LzrprfMarks.alloc.initWithFrame($.NSMakeRect(0, 0, 960, MARKS_ROW));
    marksView.hidden = true;
    root.addSubview(marksView);
    [tabsView, belt, cog, faces, star, marksView].forEach(tracked);
    stripBack = $.LzrprfBack.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 30));
    root.addSubview(stripBack);
    words = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 24));
    words.editable = false;
    words.selectable = true;
    words.bordered = false;
    words.drawsBackground = false;
    words.font = sans(11.5);
    words.textColor = GREY;
    words.cell.wraps = true;
    words.stringValue = $('lzrprf is starting ' + NAME + '.');
    words.autoresizingMask = 2 | 8;
    root.addSubview(words);
    first = button('', 'first:');
    second = button('', 'second:');
    first.hidden = true;
    second.hidden = true;
    scroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 640));
    scroll.hasVerticalScroller = true;
    // Ticket 1530: the page scrolls on Core Animation. Layer-backed, the scroll view moves what is drawn already on the
    // compositor and asks the page to draw only the strip a move uncovers, where it drew the whole view each frame.
    scroll.wantsLayer = true; canvas.wantsLayer = true;
    scroll.autoresizingMask = 2 | 16;
    page = unchecked($.LzrprfPage.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 640)));
    page.editable = false;
    page.richText = false;
    page.automaticLinkDetectionEnabled = false;
    page.automaticDataDetectionEnabled = false;
    page.displaysLinkToolTips = false;
    page.textContainerInset = $.NSMakeSize(14, 12);
    page.autoresizingMask = 2;
    page.backgroundColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.043, 0.055, 0.067, 1);    // the glass, a shade under the frame's
    scroll.backgroundColor = page.backgroundColor;
    scroll.documentView = page;
    root.addSubview(scroll);
    scroll.contentView.postsBoundsChangedNotifications = true;    // each scroll of the page's view, heard (pageScrollMoved)
    $.NSNotificationCenter.defaultCenter.addObserverSelectorNameObject(hand, 'pageScrolled:', $.NSViewBoundsDidChangeNotification, scroll.contentView);
    findBox = $.LzrprfFind.alloc.initWithFrame($.NSMakeRect(0, 0, FIND_WIDE, FIND_HIGH));    // Find's bar, over the page's top right corner
    findBox.hidden = true;
    findField = $.LzrprfField.alloc.initWithFrame($.NSMakeRect(14, 8, 160, 20));
    findField.placeholderAttributedString = styled('Find in page', inked(sans(13), GREY));
    findField.font = sans(13);
    findField.textColor = WHITE;
    findField.bordered = false;
    findField.bezeled = false;
    findField.drawsBackground = false;
    findField.focusRingType = 1;
    findField.delegate = hand;
    findField.cell.usesSingleLineMode = true;
    findField.cell.scrollable = true;
    findBox.addSubview(findField);
    root.addSubview(findBox);
    under = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 190));    // in the modal of what the page is made of (techToggled)
    under.hasVerticalScroller = true;
    under.borderType = 0;
    under.drawsBackground = false;
    made = unchecked($.LzrprfPage.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 190)));
    made.editable = false;
    made.richText = false;
    made.automaticLinkDetectionEnabled = false;
    made.automaticDataDetectionEnabled = false;
    made.displaysLinkToolTips = false;
    made.textContainerInset = $.NSMakeSize(0, 2);
    made.drawsBackground = false;
    under.documentView = made;
    logs = $.LzrprfLogIcon.alloc.initWithFrame($.NSMakeRect(0, 0, 26, 24));    // the log: never shown (it is Show log in the cogwheel's menu); kept for whether the log may be opened now
    techs = $.LzrprfTechIcon.alloc.initWithFrame($.NSMakeRect(0, 0, 26, 24));    // what the page is made of: never shown (it is the last row of the lock's panel)
    [[logs, 'log:', 'Log'], [techs, 'techs:', 'What this page is made of']].forEach(function (one) { one[0].bordered = false; one[0].title = $(''); one[0].toolTip = $(one[2]); one[0].target = hand; one[0].action = one[1]; root.addSubview(one[0]); tracked(one[0]); });
    logs.enabled = false;
    logs.hidden = true;
    techs.hidden = true;
    torIcon = $.LzrprfTorIcon.alloc.initWithFrame($.NSMakeRect(0, 0, 26, 24));    // Tor, right of the application's tool, in the bar's row: grey while off, blue while on
    torIcon.bordered = false; torIcon.title = $(''); torIcon.toolTip = $('Tor: off'); torIcon.target = hand; torIcon.action = 'tor:'; root.addSubview(torIcon); tracked(torIcon);
    toolIcon = $.LzrprfToolIcon.alloc.initWithFrame($.NSMakeRect(0, 0, 26, 24));    // the application's tool, LZRDFNDR, just right of the bar
    toolIcon.bordered = false; toolIcon.title = $(''); toolIcon.toolTip = $("The application's tool"); toolIcon.target = hand; toolIcon.action = 'tool:'; root.addSubview(toolIcon); tracked(toolIcon);
    homeView = $.LzrprfHome.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 600));
    root.addSubview(homeView);
    listScroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 600));
    listScroll.hasVerticalScroller = true;
    listScroll.drawsBackground = false;
    listScroll.hidden = true;
    listView = $.LzrprfList.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 600));
    listScroll.documentView = listView;
    root.addSubview(listScroll);
    [homeView, listView].forEach(tracked);
    secureBox = $.LzrprfSecure.alloc.initWithFrame($.NSMakeRect(0, 0, 560, 300));
    secureBox.hidden = true;
    secureScroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 520, 260));
    secureScroll.hasVerticalScroller = true;
    secureScroll.drawsBackground = false;
    secureText = unchecked($.LzrprfPage.alloc.initWithFrame($.NSMakeRect(0, 0, 520, 260)));
    secureText.editable = false;
    secureText.richText = false;
    secureText.drawsBackground = false;
    secureText.automaticLinkDetectionEnabled = false;
    secureText.automaticDataDetectionEnabled = false;
    secureText.textContainerInset = $.NSMakeSize(0, 0);
    secureScroll.documentView = secureText;
    secureBox.addSubview(secureScroll);
    secureTech = button('What this page is made of', 'techs:');    // the lock's panel's last row
    secureTech.autoresizingMask = 0;
    secureBox.addSubview(secureTech);
    root.addSubview(secureBox);
    suggestBox = $.LzrprfSuggest.alloc.initWithFrame($.NSMakeRect(0, 0, 600, 200));
    suggestBox.hidden = true;
    root.addSubview(suggestBox);
    tracked(suggestBox);
    cogCatch = $.LzrprfCatch.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 720));
    cogCatch.hidden = true;
    root.addSubview(cogCatch);
    cogBox = $.LzrprfCogMenu.alloc.initWithFrame($.NSMakeRect(0, 0, 260, 208));
    cogBox.hidden = true;
    root.addSubview(cogBox);
    tracked(cogBox);
    veil = $.LzrprfVeil.alloc.initWithFrame($.NSMakeRect(0, 0, 960, 720));    // last, so it is over everything
    veil.hidden = true;
    panel = $.LzrprfPanel.alloc.initWithFrame($.NSMakeRect(0, 0, 600, 300));
    veil.addSubview(panel);
    modalKeys = $.LzrprfKeys.alloc.initWithFrame($.NSMakeRect(0, 0, 0, 0));
    veil.addSubview(modalKeys);
    panelTitle = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 28));
    panelSub = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 100, 40));
    [panelTitle, panelSub].forEach(function (one) { one.editable = false; one.selectable = true; one.bordered = false; one.drawsBackground = false; one.cell.wraps = true; panel.addSubview(one); });
    panelTitle.font = sans(18, true);
    panelSub.font = sans(13);
    panelSub.textColor = WHITE;
    form = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 500, 150));
    form.hidden = true;
    panel.addSubview(form);
    function label(words) { var one = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 84, 20)); one.editable = false; one.selectable = false; one.bordered = false; one.drawsBackground = false; one.font = sans(12.5); one.textColor = GREY; one.stringValue = $(words); form.addSubview(one); return one; }
    function field() { var one = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 300, 26)); one.font = sans(13); one.cell.allowsUndo = true; one.cell.usesSingleLineMode = true; one.cell.scrollable = true; form.addSubview(one); return one; }
    nameLabel = label('Name'); nameField = field();
    addressLabel = label('Address'); addressField = field();
    folderLabelView = label('Folder');
    folderPop = $.NSPopUpButton.alloc.initWithFramePullsDown($.NSMakeRect(0, 0, 260, 26), false);
    folderPop.font = sans(12.5);
    folderPop.target = hand;
    folderPop.action = 'folderChosen:';
    form.addSubview(folderPop);
    newFolderField = field();
    newFolderField.placeholderString = $('New folder: a name, or names joined by /');
    newFolderField.hidden = true;
    engineField = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 26));
    engineField.font = sans(13);
    engineField.cell.usesSingleLineMode = true;
    engineField.cell.scrollable = true;
    engineField.placeholderString = $('https://search.example.com/search?q=%s');
    engineField.hidden = true;
    panel.addSubview(engineField);
    licenceField = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 26));    // Enter licence code: its one field
    licenceField.font = sans(13);
    licenceField.cell.usesSingleLineMode = true;
    licenceField.cell.scrollable = true;
    licenceField.placeholderString = $('XXXXX-XXXXX-XXXXX-...');
    licenceField.hidden = true;
    panel.addSubview(licenceField);
    profileField = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 26));    // New profile, Rename: its one field
    profileField.font = sans(13);
    profileField.cell.usesSingleLineMode = true;
    profileField.cell.scrollable = true;
    profileField.placeholderString = $('A name, at most 32 characters');
    profileField.hidden = true;
    panel.addSubview(profileField);
    supportScroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 580, 200));    // Support request: the box for your words
    supportScroll.hasVerticalScroller = true;
    supportScroll.borderType = 1;
    supportText = unchecked($.LzrprfPage.alloc.initWithFrame($.NSMakeRect(0, 0, 580, 200)));
    supportText.editable = true;
    supportText.richText = false;
    supportText.font = sans(13);
    supportText.textColor = WHITE;
    supportText.insertionPointColor = WHITE;
    supportText.backgroundColor = DARK;
    supportText.textContainerInset = $.NSMakeSize(6, 6);
    supportText.autoresizingMask = 2;
    supportScroll.documentView = supportText;
    supportScroll.hidden = true;
    panel.addSubview(supportScroll);
    supportTick = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 580, 22));    // the picture of the window, off until ticked
    supportTick.setButtonType(3);    // a box to tick
    supportTick.font = sans(12.5);
    supportTick.state = 0;
    supportTick.target = hand;
    supportTick.action = 'supportTicked:';
    supportTick.hidden = true;
    panel.addSubview(supportTick);
    supportPreview = $.NSImageView.alloc.initWithFrame($.NSMakeRect(0, 0, 200, 112));    // that picture, small, while it is ticked
    supportPreview.imageScaling = 3;    // made smaller or larger to fit, its shape kept
    supportPreview.imageFrameStyle = 0;
    supportPreview.hidden = true;
    panel.addSubview(supportPreview);
    wizardView = $.LzrprfWizard.alloc.initWithFrame($.NSMakeRect(0, 0, 600, 260));
    wizardView.hidden = true;
    panel.addSubview(wizardView);
    torView = $.LzrprfTorBeam.alloc.initWithFrame($.NSMakeRect(0, 0, 580, 190));
    torView.hidden = true;
    panel.addSubview(torView);
    toolScroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 700, 400));    // the list of the application's tool, in the modal
    toolScroll.hasVerticalScroller = true;
    toolScroll.borderType = 0;
    toolScroll.drawsBackground = false;
    toolView = $.LzrprfTool.alloc.initWithFrame($.NSMakeRect(0, 0, 700, 400));
    toolScroll.documentView = toolView;
    toolScroll.hidden = true;
    panel.addSubview(toolScroll);
    toolCopy = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 380, 32));    // the tool's copy button, above its list
    toolCopy.title = $(TOOL_COPY_WORDS);
    toolCopy.bezelStyle = 1;
    toolCopy.font = sans(13);
    toolCopy.target = hand;
    toolCopy.action = 'toolCopy:';
    toolCopy.enabled = false;
    toolCopy.hidden = true;
    panel.addSubview(toolCopy);
    procsMade();    // Show all processes and its Notes field (HC-0843), once toolView is made
    partsMade();    // the boxes of Add or remove LZR modules and of LZRTNNL
    toolTabs = ['On Your Computer', 'Scripts, Redirects and Sends', 'Other'].map(function (words, k) {    // the panel's three tabs, under its title
        var one = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 170, 28));
        one.title = $(words); one.bezelStyle = 1; one.font = sans(13, true); one.tag = k; one.target = hand; one.action = 'toolTab:'; one.hidden = true;
        panel.addSubview(one);
        return one;
    });
    permitCopy = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 150, 32));    // the copy button of the question about scripts
    permitCopy.title = $(PERMIT_COPY_WORDS); permitCopy.bezelStyle = 1; permitCopy.font = sans(13); permitCopy.target = hand; permitCopy.action = 'permitCopy:'; permitCopy.hidden = true;
    panel.addSubview(permitCopy);
    tracked(wizardView);
    pathField = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 26));
    pathField.font = sans(13);
    pathField.cell.usesSingleLineMode = true;
    pathField.cell.scrollable = true;
    pathField.placeholderString = $('Or type its path: ~/Downloads/bookmarks.html');
    pathField.hidden = true;
    panel.addSubview(pathField);
    panelScroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 600, 300));
    panelScroll.hasVerticalScroller = true;
    panelScroll.borderType = 0;
    panelText = unchecked($.LzrprfPage.alloc.initWithFrame($.NSMakeRect(0, 0, 600, 300)));
    panelText.editable = false;
    panelText.richText = false;
    panelText.automaticLinkDetectionEnabled = false;
    panelText.automaticDataDetectionEnabled = false;
    panelText.backgroundColor = DARK;
    panelText.textContainerInset = $.NSMakeSize(10, 8);
    panelText.autoresizingMask = 2;
    panelScroll.documentView = panelText;
    panel.addSubview(panelScroll);
    under.hidden = true;
    panel.addSubview(under);    // the list of what the page is made of, shown in the modal (techToggled)
    root.addSubview(veil);
    listed([]);
    menus();
    place();
    $.NSNotificationCenter.defaultCenter.addObserverSelectorNameObject(hand, 'heard:', $.NSFileHandleDataAvailableNotification, from);
    from.waitForDataInBackgroundAndNotify;
    shown();
    say('ready');
    view();    // after "ready", which lzrprf hears first: the size the first page is laid out at
    app.run;
}

// Only the signed release offer uses this modal. Its first button is also Escape.
function updateOfferTold(rest) {
    if (!rest) { if (modalOpen && modalKind == 'updateoffer') closeModal(); return; }
    var parts = rest.split('\t'), versions = parts[0].split(' '), number = ++asked;
    var answer = function (choice) { return function () { closeModal(); say('button ' + number + ' ' + choice); }; };
    modal('LZRBRWSR update available', 'Release ' + versions[0] + ' is ready to install. You are using release ' + versions[1] + '. The installer runs in this window and shows its progress here.', [[parts[1], answer(1)], [parts[2], answer(2)]], 'updateoffer');
}
END
}
