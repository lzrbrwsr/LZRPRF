# LZRDFNDR's switches in its panel (Ticket #1546): at the top of each tab, a switch for each protection of the tab.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrdfndr.md ; src/22-defender.pl
sub window_defender_text {
    return <<'END';
var DEFEND_TAB = { computer: [['computer', 'On Your Computer']], websites: [['scripts', 'Scripts'], ['redirects', 'Redirects'], ['sends', 'Sends']] };
var DEFEND_SAID = { computer: 'lzrprf keeps every job you switched off here off, and says so when something switches one back on.', scripts: "a page's scripts that no rule allows are put to you before they run.", redirects: 'a redirect to another address is put to you before it is followed.', sends: 'a page that sends to another host is put to you first.' };
var defendOff = {};    // from lzrprf's "defender KIND on|off ..." (sub defender_told): each protection switched off
function defenderTold(rest) { var f = rest.split(' '); defendOff = {}; for (var k = 0; k + 1 < f.length; k += 2) if (f[k + 1] == 'off') defendOff[f[k]] = true; toolItems = null; if (modalOpen && modalKind == 'tool') toolChanged(); }
// The rows of the shown tab's switches, from y: each a box ticked while its protection is on; returns the y below them.
function defendLaid(items, w, tall, y) {
    (DEFEND_TAB[toolTab] || []).forEach(function (one) {
        var on = !defendOff[one[0]], said = on ? 'On: ' + DEFEND_SAID[one[0]] + ' Untick to switch it off.' : 'Off: nothing is asked and no message is shown; what it lets through is still in the log. Tick to switch it on.';
        var detail = tall(said, sans(11.5), w - 52), high = 11 + 19 + detail + 11;
        items.push({ row: { on: on, mode: 'act', tag: on ? 'on' : 'off', title: one[1] + ' protection', detail: said, fact: '' }, defend: one[0], y: y, h: high, detail: detail, fact: 0 });
        y += high + 8;
    });
    return y;
}
function defendClicked(at, items) {    // a press on a switch's row: lzrprf is told, and its answer redraws the row
    for (var k = 0; k < items.length; k++) { var one = items[k]; if (one.defend && at.y >= one.y && at.y < one.y + one.h) { say('defender ' + one.defend + (defendOff[one.defend] ? ' on' : ' off')); return true; } }
    return false;
}
END
}
