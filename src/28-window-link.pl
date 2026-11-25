# The live debug link in the window [C31]: the part of the window's text the
# link uses, joined after the rest of it by sub run (04-start.pl).
#   - a row in the cogwheel's menu, "Live debug link", on and off by the same
#     press ("menu debug-link"; sub link_menu says what it does);
#   - a badge in the window's lower right corner the whole time the link is
#     on: its id, so you can read it out, and when it ends; each command the
#     link runs is said in it for a few seconds ("link said WORDS");
#   - a picture of the window, or of the page shown, made from the window's
#     own drawing as Support request makes one (windowPicture), never a capture
#     of the screen, when lzrprf asks ("link shot NONCE page|window"); handed
#     back as "link shot NONCE PNG-IN-BASE64".
# lzrprf says "link on ID UNTIL" (UNTIL in seconds since 1970) and "link off".
# SYNC: src/21-link.pl ; src/28-window.pl (cogItems, told, windowPicture) ; managed-projects/lzrbrwsr/architecture/live-debug-link.md
sub window_link_text {
    return <<'END';

var linkId = null, linkUntil = 0, linkSaid = '', linkSaidAt = 0, linkBadge = null;
var cogItemsBeforeLink = cogItems;
cogItems = function () {    // the cogwheel's menu with the link's row before Check for updates
    var items = cogItemsBeforeLink();
    if (cogMode != 'cog') return items;
    var row = [linkId ? 'Turn off live debug link' : 'Live debug link', linkId ? linkId : 'off', !!linkId, INCOGNITO ? function () { wordsTold(LINK_TIP); } : function () { if (takes()) sent('menu debug-link'); }, INCOGNITO ? LINK_TIP : 'Sends load timings and errors (never cookies, typing or page text) to the LZRBRWSR project for 24 hours, and takes its signed commands', 'brace'];
    var at = 0;
    for (var i = 0; i < items.length; i++) if (items[i] && items[i][0] == 'Check for updates') at = i;
    items.splice(at || items.length, 0, row);
    return items;
};
var LINK_TIP = 'An incognito or Tor window is never on the live debug link: it would write and send.';
function told(word, rest) {    // the one seam each line of lzrprf reaches (heard, 28-window.pl)
    if (word != 'link') { if (linkSaid && Date.now() - linkSaidAt > 6000) { linkSaid = ''; linkPlaced(); } return; }
    var m;
    if ((m = /^on ([0-9a-f]{12}) ([0-9]{10})$/.exec(rest))) { linkId = m[1]; linkUntil = +m[2]; linkSaid = ''; }
    else if (rest == 'off') { linkId = null; linkSaid = ''; }
    else if ((m = /^said (.{1,300})$/.exec(rest))) { linkSaid = m[1]; linkSaidAt = Date.now(); }
    else if ((m = /^shot ([0-9a-f]{16,32}) (page|window)$/.exec(rest))) { linkShot(m[1], m[2]); }
    linkPlaced();
    if (cogOpen) cogPlaced();
}
function linkPlaced() {    // the badge: shown while the link is on, in the lower right corner, over everything else
    if (!root) return;
    if (!linkBadge) {
        linkBadge = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 360, 20));
        linkBadge.editable = false; linkBadge.selectable = false; linkBadge.bordered = false;
        linkBadge.drawsBackground = true; linkBadge.backgroundColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.55, 0.05, 0.12, 0.92);
        linkBadge.textColor = $.NSColor.whiteColor; linkBadge.font = $.NSFont.boldSystemFontOfSize(11); linkBadge.alignment = 1;    // 1: centred
        linkBadge.toolTip = $('The live debug link is on: load timings and errors go to the LZRBRWSR project. Turn it off in the cogwheel menu.');
        root.addSubview(linkBadge);
    }
    linkBadge.hidden = !linkId;
    if (!linkId) return;
    var at = new Date(linkUntil * 1000), two = function (n) { return (n < 10 ? '0' : '') + n; };
    var text = 'LIVE DEBUG LINK ' + linkId + ' on until ' + two(at.getHours()) + ':' + two(at.getMinutes()) + (linkSaid ? '  |  ' + linkSaid : '');
    linkBadge.stringValue = $(text);
    var b = root.bounds, w = Math.min(b.size.width - 20, Math.max(260, text.length * 6.6 + 20)), h = 20;
    linkBadge.frame = $.NSMakeRect(b.size.width - w - 10, root.isFlipped ? b.size.height - h - 6 : 6, w, h);
}
function linkShot(nonce, which) {    // the window's own drawing of itself, or of the page shown, as a PNG small enough to send; never the screen
    var png = null;
    if (which == 'page' && canvas && !canvas.hidden) {
        var r = canvas.visibleRect, rep = canvas.bitmapImageRepForCachingDisplayInRect(r);
        if (rep && !rep.isNil()) { canvas.cacheDisplayInRectToBitmapImageRep(r, rep); png = rep.representationUsingTypeProperties(4, $({})); }    // 4: PNG
        if (png && (png.isNil() || png.length > SUPPORT_PICTURE_MOST)) png = null;
    }
    if (!png) png = windowPicture();
    if (png) say('link shot ' + nonce + ' ' + png.base64EncodedStringWithOptions(0).js);
}
END
}
