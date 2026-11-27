
# The menu bar of the window (Henry, 2026-11-26): the part of the window's text
# that names the application in the Mac's menu bar and adds its File and Help
# menus, joined after the rest of it by sub run (04-start.pl).
#   - the name: macOS names the application in the menu bar after the
#     process's entry in Launch Services, which for the system's osascript is
#     "osascript", so the bar never said LZRBRWSR. The entry is renamed to the
#     application's name, "LZRBRWSR", or "LZRBRWSR - Staging" for
#     LZRBRWSR-Staging.app (measured 2026-11-26 with osascript: "osascript"
#     before, the name after);
#   - File: New Tab, New Window, New Incognito Window, New Tor Window, Close
#     Tab, Close Window. New Window and New Tor Window are second lzrprfs of
#     their own ("window new", sub window_opened; "window tor", sub
#     tor_window_opened, as the onion icon);
#   - Help: About (a modal with the release number lzrprf says at start,
#     "release N"), Privacy Policy and Terms and Conditions, each the site's own
#     page in a new tab ("help privacy", "help terms"; sub help_opened), so the
#     text has one source, the one the web shows;
#   - full screen hides the menu bar and shows it when the pointer reaches the
#     top of the screen: the system's own presentation options, none of ours.
sub window_menu_text {
    return <<'END';
var releaseNumber = '';    // "release N", said by lzrprf at start (06-behind.pl): shown in About
function menuBarNamed(name) {
    try {
        ObjC.bindFunction('_LSGetCurrentApplicationASN', ['id', []]);
        ObjC.bindFunction('_LSSetApplicationInformationItem', ['int', ['int', 'id', 'id', 'id', 'id']]);
        $._LSSetApplicationInformationItem(-2, $._LSGetCurrentApplicationASN(), $('LSDisplayName'), $(name), $());    // -2: this login session
    } catch (e) { }    // a macOS without these calls keeps the name "osascript" in the bar; the window works the same
}
busyClass({ name: 'LzrprfMenu', methods: {
    'newWindow:': { types: ['void', ['id']], implementation: function (sender) { say('window new'); } },    // lzrprf starts a second lzrprf: this process starts nothing
    'torWindow:': { types: ['void', ['id']], implementation: function (sender) { say('window tor'); } },
    'closeWindow:': { types: ['void', ['id']], implementation: function (sender) { win.performClose($()); } },    // as the red dot
    'about:': { types: ['void', ['id']], implementation: function (sender) { aboutOpened(); } },
    'privacy:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) sent('help privacy'); } },
    'terms:': { types: ['void', ['id']], implementation: function (sender) { if (takes()) sent('help terms'); } }
} });
var menuHand = null;
function menusMore(main) {    // called by menus() before the bar is handed to the application
    menuHand = $.LzrprfMenu.alloc.init;
    var made = function (menu, words, action, key, mask, target) {
        var one = menu.addItemWithTitleActionKeyEquivalent($(words), action, $(key));
        one.target = target;
        if (mask) one.keyEquivalentModifierMask = mask;
        return one;
    };
    var appMenu = main.itemAtIndex(0).submenu, about = appMenu.insertItemWithTitleActionKeyEquivalentAtIndex($('About ' + NAME), 'about:', $(''), 0);
    about.target = menuHand;
    appMenu.insertItemAtIndex($.NSMenuItem.separatorItem, 1);
    var file = $.NSMenu.alloc.initWithTitle($('File')), fileItem = $.NSMenuItem.alloc.init;
    made(file, 'New Tab', 'newTab:', 't', 0, hand);
    made(file, 'New Window', 'newWindow:', 'n', 0, menuHand);
    made(file, 'New Incognito Window', 'incognito:', 'N', 0, hand);
    made(file, 'New Tor Window', 'torWindow:', 'n', CMD | OPTION, menuHand);
    file.addItem($.NSMenuItem.separatorItem);
    made(file, 'Close Tab', 'closeTab:', 'w', 0, hand);
    made(file, 'Close Window', 'closeWindow:', 'W', 0, menuHand);
    fileItem.submenu = file;
    main.insertItemAtIndex(fileItem, 1);
    var help = $.NSMenu.alloc.initWithTitle($('Help')), helpItem = $.NSMenuItem.alloc.init;
    made(help, 'About ' + NAME, 'about:', '', 0, menuHand);
    made(help, 'Privacy Policy', 'privacy:', '', 0, menuHand);
    made(help, 'Terms and Conditions', 'terms:', '', 0, menuHand);
    helpItem.submenu = help;
    main.addItem(helpItem);
    app.helpMenu = help;
}
function aboutOpened() {
    if (modalOpen || asking) return;
    modal('About ' + NAME, NAME + (releaseNumber ? ', release ' + releaseNumber : '') + '.\nIt runs in lzrprf, whose source is open: github.com/lzrbrwsr/lzrprf.', [['Close', closeModal]], 'about');
}
END
}
