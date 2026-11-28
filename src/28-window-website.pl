# Website decisions in the LZRDFNDR window.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrdfndr.md
sub window_website_text {
    return <<'END';
var WEB_PILLS = [['Always allow', 'always'], ['Allow once', 'allow-once'], ['Always Deny', 'deny'], ['Deny once', 'deny-once'], ['Forget', 'forget']];
// The questions (scripts, redirect, send) offer the four answers: Forget is only in the site's settings.
var ASK_PILLS = WEB_PILLS.filter(function (pill) { return pill[1] != 'forget'; });
var WEB_EFFECT = { 'allowed always': 'always', 'allowed once': 'allow-once', 'denied always': 'deny', 'denied once': 'deny-once',
    'proceed always': 'always', 'cancel always': 'deny', proceeded: 'allow-once', cancelled: 'deny-once', pending: 'forget', 'no decision': 'forget' };
var ESSENTIAL_TITLE = 'Essential Allow and deny list';
var essentialScriptPrompt = false, essentialList = null, essentialIn = null, essentialOpen = false, essentialOn = false, essentialChanges = {}, essentialError = '';
var sendsList = null, sendsIn = null, webReturn = null, webReviewButton = null, webReviewLabel = null;
function webEffect(decision) { return WEB_EFFECT[decision] || decision; }
function webPillsFit(one, w) {
    var width = Math.min(115, (w - 44) / WEB_PILLS.length - 6), active = webEffect(one.web.decision);
    return WEB_PILLS.map(function (pill, k) {
        return { word: pill[0], to: pill[1], x: 16 + k * (width + 6), y: one.y + 38 + one.detail, w: width, h: 24, active: active == pill[1] };
    });
}
function webRow(one, words, sayWhat, y, w, tall) {
    var detail = tall(words, sans(11.5), w - 32);
    return { web: one, words: words, says: sayWhat, y: y, h: 91 + detail, detail: detail };
}
function webLaid(items, w, tall, y0) {
    var y = y0 || 2, headline = ESSENTIAL_TITLE + (essentialOpen ? '  \u25be' : '  \u25b8');
    items.push({ essentialHead: true, y: y, h: 48, text: headline });
    y += 59;
    if (essentialOpen) {
        if (essentialList) essentialList.forEach(function (one) {
            var row = webRow({ n: one.n, name: one.name, decision: essentialChanges[one.n] || one.decision },
                (one.kind == 'redirect' ? 'Redirect to ' + one.to : 'Script on ' + one.site), 'essential', y, w, tall);
            items.push(row); y += row.h + 8;
        });
    }
    if (essentialError) {
        var error = { text: essentialError, font: sans(12, true), colour: YELLOW, y: y, h: tall(essentialError, sans(12, true), w - 8) };
        items.push(error); y += error.h + 12;
    }
    if (webReturn) return y;
    var groups = Object.create(null);
    function add(list, kind) {
        (list || []).forEach(function (one) {
            if (one.n === undefined) return;
            var domain = one.site.replace(/^https:\/\//, ''), group = groups[domain] || (groups[domain] = []);
            group.push({ one: one, kind: kind });
        });
    }
    add(sitesList, 'script'); add(redirectsList, 'redirect'); add(sendsList, 'send');
    Object.keys(groups).sort().forEach(function (site) {
        var h = tall(site, sans(14, true), w - 8);
        items.push({ text: site, font: sans(14, true), colour: WHITE, y: y, h: h }); y += h + 8;
        groups[site].forEach(function (entry) {
            var one = entry.one, kind = entry.kind;
            var words = kind == 'redirect' ? 'Redirect ' + one.status + (one.to ? ' to ' + one.to : '') + (one.fit ? '' : ' (unavailable)') :
                kind == 'send' ? 'Send to ' + one.name : ['Script', one.where, one.bytes ? one.bytes + ' bytes' : '', one.who,
                    one.cls == 'strings' ? 'turns text into code (eval)' : ''].filter(Boolean).join(', ');
            var row = webRow(one, words, { script: 'scripts decide', redirect: 'redirects decide', send: 'sends decide' }[kind], y, w, tall);
            row.fit = kind != 'redirect' || one.fit;
            items.push(row); y += row.h + 8;
        });
    });
    return y;
}
function webPaintHead(one, w) {
    var card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1.5, one.y + 0.5, w - 3, one.h - 1), 10, 10);
    FILL.setFill; card.fill; stroked(card, LINE, 1);
    var tick = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(14, one.y + 9, 30, 30), 6, 6);
    if (essentialOn) {
        GREEN.setFill; tick.fill;
        var check = $.NSBezierPath.bezierPath;
        check.moveToPoint($.NSMakePoint(21, one.y + 24)); check.lineToPoint($.NSMakePoint(27, one.y + 31)); check.lineToPoint($.NSMakePoint(38, one.y + 17));
        stroked(check, DARK, 2.5);
    } else stroked(tick, ICON, 1.5);
    styled(one.text, inked(sans(14, true), WHITE)).drawAtPoint($.NSMakePoint(54, one.y + 15));
}
function webPaintRow(one, w) {
    var card = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(1.5, one.y + 0.5, w - 3, one.h - 1), 10, 10);
    FILL.setFill; card.fill; stroked(card, LINE, 1);
    $(one.web.name).drawInRectWithAttributes($.NSMakeRect(16, one.y + 10, w - 32, 19), inked(sans(13.5, true), WHITE, true));
    styled(one.words, inked(sans(11.5), GREY)).drawInRect($.NSMakeRect(16, one.y + 30, w - 32, one.detail + 2));
    var active = 'Forget';
    webPillsFit(one, w).forEach(function (pill) {
        var box = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(pill.x, pill.y, pill.w, pill.h), 8, 8);
        if (pill.active) { glass(box, true); active = pill.word; }
        stroked(box, pill.active ? GREEN : ICON, 1);
        var inactive = one.fit === false && /^(always|allow-once)$/.test(pill.to), label = styled(pill.word, inked(sans(11, pill.active), inactive ? GREY : WHITE));
        label.drawAtPoint($.NSMakePoint(pill.x + Math.max(2, (pill.w - label.size.width) / 2), pill.y + 4));
    });
    styled(active, inked(sans(11.5, true), GREEN)).drawAtPoint($.NSMakePoint(16, one.y + 67 + one.detail));
}
function webClick(at, items, w) {
    for (var i = 0; i < items.length; i++) {
        var row = items[i];
        if (at.y < row.y || at.y >= row.y + row.h) continue;
        if (row.essentialHead) {
            if (at.x < 50 && essentialList) { essentialOn = !essentialOn; essentialOpen = true; }
            else essentialOpen = !essentialOpen;
            toolChanged(); return;
        }
        if (!row.web) continue;
        var hit = webPillsFit(row, w).filter(function (pill) { return at.x >= pill.x && at.x <= pill.x + pill.w && at.y >= pill.y && at.y <= pill.y + pill.h; })[0];
        if (!hit || (row.fit === false && /^(always|allow-once)$/.test(hit.to))) return;
        if (row.says == 'essential') { essentialChanges[row.web.n] = hit.to; toolChanged(); return; }
        var decision = row.says == 'redirects decide' ? { always: 'proceed', deny: 'cancel' }[hit.to] || hit.to : hit.to;
        say(row.says + ' ' + row.web.n + ' ' + decision);
        return;
    }
}
function webSettingsShown() { return modalOpen && modalKind == 'tool' && toolTab == 'websites'; }
function webRead() {
    sitesList = redirectsList = sendsList = essentialList = null;
    essentialOpen = false; essentialChanges = {}; essentialError = '';
    say('scripts sites'); say('redirects list'); say('sends list'); say('essential list');
}
function sendsTold(rest) {
    var fields = rest.split('\t');
    if (rest == 'begin') sendsIn = [];
    else if (rest == 'end' && sendsIn) { sendsList = sendsIn; sendsIn = null; if (webSettingsShown()) toolChanged(); }
    else if (sendsIn && /^one [0-9]{1,4}$/.test(fields[0]) && fields.length == 4)
        sendsIn.push({ n: +fields[0].slice(4), site: fields[1], name: fields[2], decision: fields[3] });
}
function essentialTold(rest) {
    var f = rest.split('\t');
    if (rest == 'script') essentialScriptPrompt = true;
    else if (/^begin [01]$/.test(rest)) { essentialIn = []; essentialOn = rest == 'begin 1'; }
    else if (rest == 'end' && essentialIn) { essentialList = essentialIn; essentialIn = null; if (webSettingsShown()) toolChanged(); }
    else if (essentialIn && /^row [0-9]$/.test(f[0]) && f.length == 6)
        essentialIn.push({ n: +f[0].slice(4), kind: f[1], site: f[2], name: f[3], to: f[4], decision: f[5] });
    else if (rest == 'saved failed') { essentialError = 'The list could not be saved.'; toolChanged(); }
    else if (rest == 'saved ok' || rest == 'saved resolved') {
        essentialChanges = {}; essentialError = '';
        if (webReturn) webReviewEnded(rest == 'saved resolved');
    }
}
function essentialSave() {
    var changes = Object.keys(essentialChanges).map(function (id) { return ' ' + id + '=' + essentialChanges[id]; }).join('');
    say('essential save ' + (essentialOn ? '1' : '0') + changes);
}
function webQuestionTold(rest) {
    var f = rest.split('\t'), number = ++asked;
    webQuestionShown({ kind: f[0], words: f[1], essential: f[2] != '-', fit: f[3] == '1', titles: f.slice(4), number: number });
}
function webQuestionShown(one) {
    var answerByPosition = [3, 2, 4, 1, 5, 6], choices = [];
    one.titles.forEach(function (title, i) {
        if (answerByPosition[i] == 5) return;   // Forget: only in the site's settings, never in the question
        choices.push([title, function () { closeModal(); say('button ' + one.number + ' ' + answerByPosition[i]); }]);
    });
    modal('LZRDFNDR ' + (one.kind == 'redirect' ? 'redirect' : 'send'), one.words || '', choices, 'tall');
    if (!one.fit) { panelButtons[0].enabled = false; panelButtons[1].enabled = false; }
    if (one.essential) webWarning('redirect', function () { webQuestionShown(one); });
}
function webWarning(kind, again) {
    webReturn = null;
    if (!webReviewButton) {
        webReviewButton = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 0, 0));
        webReviewButton.title = $('Review and enable Essential Allow and deny list');
        webReviewButton.font = sans(12, true); webReviewButton.bezelStyle = 1; webReviewButton.target = hand; webReviewButton.action = 'essentialReview:';
        panel.addSubview(webReviewButton);
        webReviewLabel = $.NSTextField.wrappingLabelWithString($(''));
        webReviewLabel.font = sans(12, true); webReviewLabel.textColor = GREEN;
        panel.addSubview(webReviewLabel);
    }
    webReviewLabel.stringValue = $('This ' + kind + ' belongs to our LZRDFNDR "Essential Allow and deny list" - Do you want to enable "Essential Allow and deny list"');
    webReviewLabel.hidden = webReviewButton.hidden = false;
    webReviewButton.toolTip = $('Edit the entries before turning the list on');
    webReviewAction = again;
    placeModal();
}
var webReviewAction = null;
function webWarningHidden() {
    if (webReviewButton) webReviewButton.hidden = webReviewLabel.hidden = true;
    webReviewAction = null;
}
function isWebQuestion() { return /^LZRDFNDR (scripts|redirect|send)$/.test(String(panelTitle.stringValue.js)); }
function webQuestionPlaced(m, w, h) {
    if (!panelButtons.length || !isWebQuestion()) return;
    var permit = modalKind == 'permit', extra = panelButtons.length > ASK_PILLS.length, count = Math.min(panelButtons.length, ASK_PILLS.length);
    var wButton = Math.floor((w - 52 - (count - 1) * 5) / count), line = m + (permit ? 53 : 18);
    for (var i = 0; i < count; i++) {
        var button = panelButtons[i];
        button.font = sans(11, i == 3);
        button.frame = $.NSMakeRect(m + 26 + i * (wButton + 5), line, wButton, 32);
    }
    if (extra) {
        var last = panelButtons[count], lastW = permit ? 105 : 221;
        last.frame = $.NSMakeRect(m + w - 26 - lastW, m + (permit ? 18 : 53), lastW, 32);
    }
    var warning = webReviewButton && !webReviewButton.hidden;
    var under = !permit && extra ? 97 : 65;
    if (permit) {
        var top = h - (warning ? 261 : 204);
        panelScroll.frame = $.NSMakeRect(m + 26, m + 93, w - 52, Math.max(28, top - 93));
    } else {
        var bodyFloor = under + (warning ? 65 : 0);
        panelSub.frame = $.NSMakeRect(m + 26, m + bodyFloor, w - 52, Math.max(28, h - bodyFloor - 60));
    }
    if (!warning) return;
    var right = Math.min(312, Math.floor((w - 62) * 0.48)), y = m + (permit ? h - 253 : under + 5);
    webReviewLabel.frame = $.NSMakeRect(m + 26, y, Math.max(100, w - 62 - right), 55);
    webReviewButton.frame = $.NSMakeRect(m + w - 26 - right, y + 8, right, 34);
}
function webReviewOpened() {
    if (!webReviewAction) return;
    webReturn = webReviewAction;
    tool = tool || { title: TOOL_TITLE, words: '', head: '', said: '', buttons: {}, rows: [] };
    tool.busy = ''; tool.confirm = false; toolTab = 'websites';
    essentialList = null; essentialOpen = true; essentialChanges = {}; essentialError = '';
    say('essential list');
    modal(TOOL_TITLE, '', toolChoices(), 'tool'); toolChanged();
}
function webReviewEnded(resolved) {
    var again = webReturn;
    webReturn = null;
    if (resolved) { permitLaterSet(null); closeModal(); }
    else if (again) again();
}
END
}
