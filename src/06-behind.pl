# The first line behind hears is lzrprf's own, written before the window was made (sub run):
# "start ADDRESS" in the window of a pulled tab, else "start -". Then the window's first words,
# "ready". Returns that address, '' for none, or nothing when the run did not begin so.
sub started {
    my ($pulled) = (hear(60) // '') =~ /^start (-|[\x20-\x7f]{1,2100})$/ or return;
    return (hear(60) // '') eq 'ready' ? ($pulled eq '-' ? '' : $pulled) : undef;
}

sub named {                               # the program of this run, and the name it is called by in the window
    ($PROGRAM, @ARGUMENTS) = @_;
    ($APP) = $PROGRAM =~ m{([^/]+?)(?:\.app/Contents/MacOS/[^/]+)?$};
    $APP = 'the application' unless defined $APP && $APP =~ /^[A-Za-z0-9 ._-]{1,40}$/;
}

# Behind the window: everything lzrprf does for one run, one thing at a time.
my $HELD;                                  # in an incognito window, the lock on its folder's file "held" that the sweeper waits for
sub behind {
    if ($INCOGNITO) {                     # [C16] every way out removes the folder
        open $HELD, '>>', "$DIR/held" and flock $HELD, LOCK_EX;
        put("$DIR/behind", O_EXCL, $$);    # its number, for a test that kills it outright, as a crash would
        $SIG{$_} = sub { leave() } for qw(INT TERM HUP QUIT);
    }
    $TOR_SESSION = { phase => 'made' } if $TOR_WINDOW;    # [C17] a fresh session of its own: made, and nothing reaches the network until Tor is connected and sealed
    print STDERR "test torfolder $DIR\n" if $TRY && $TOR_WINDOW;    # "lzrprf try" only: where its folder is, for the test to see it gone
    timed('behind');
    witnessed();                          # the one that answers whether a process is contained is started now, while the window is still being made, so it is ready when the window is asked about [C10]
    my $summing = sum_started($PROGRAM);    # the program's sum is read beside the tries below (sub sum_started)
    my $marking = $TRY && !-e "$ROOT/prove" ? undef : mark_started();    # and the mark of now, when the proof is looked at below (sub mark_started)
    my $held = holds();                   # [C2] tried now too, beside the window being made: it starts nothing but its own small program, and its answer is waited on below before anything else is done
    timed('holds');
    ($BEGAN, $PROGRAM_SEEN) = sum_read($summing);    # read before it is compared below, so the program that is compared is the one every page is held to; and the file it was read from (sub program_same)
    my $pulled = started() // leave();
    timed('ready');
    return closed('That profile is no longer there: it was removed as this window started. Open another from the Profiles icon of a window.') unless profile_held();    # held from here until the window ends
    paired();                             # before anything else: an application and an lzrprf that were not installed together are noticed
    return closed('LZRTNNL is not installed, so no Tor window opens. Add it in Add or remove LZR modules, in the cogwheel menu of a window.') if $TOR_SESSION && !part_on('lzrtnnl');
    return closed("lzrprf holds no list of the addresses it never opens: $LIST_WHY. That list keeps child sexual abuse material and other illegal content out, and without it $APP shows no page. Installing again mends it.") unless list_read();    # [C23] read once, here, before any address is taken
    timed('listed');
    return closed($INCOGNITO ? "lzrprf was not tested on this Mac as it is now, or did not hold, so $APP shows no page. An incognito window does not run the self-test, because the test writes its result: open a normal window once to test this Mac." : "lzrprf was not tested on this Mac as it is now, or did not hold, so $APP shows no page. What the test found: $ROOT/selftest.txt") unless ($TRY && !-e "$ROOT/prove") || proven($marking);    # [C11]
    timed('proven');
    return closed("The container did not hold on this Mac a moment ago, so $APP was not started. Run selftest, which is beside lzrprf, to see what was not refused.") unless $held;    # [C2] the tries made at the start of this sub
    return closed("The system did not say that this window is in its container, so $APP shows no page. Run selftest, which is beside lzrprf, to see what was not refused.") unless !$RUN || inside($RUN, 1);    # [C10] the window is a process too, and the system is asked about it by its number
    timed('window-inside');
    $UNEXPIRED = !expire_log();           # [C12] the days you chose, at the start of a window; when a request of another window is open just then, it is tried again before each request of this window and each press of Log, until it is done
    decoders_removed();                   # [C21] the folders of the system's decoder that runs ended before they could remove them left, when their process is gone
    welcome() unless $INCOGNITO;          # once after each install or update: what is new, and what $APP does and does not do for you; an incognito window writes nothing, so it shows none
    window('incognito') if $INCOGNITO;
    idle(($INCOGNITO ? "$APP is contained, in an incognito window: its log, history and tabs are held in its memory and one folder of its own, removed when it closes. Nothing is written to ~/.lzrprf." : "$APP is contained: no network, no file of yours, no other program. lzrprf fetches what you type above, and writes it in the log first. " . kept_words(keeping()) . ((keeping())[0] eq 'nothing' && -s "$DIR/log" ? ' A log written earlier is still on this computer: the Log button offers to clear it.' : '')), $INCOGNITO ? 'Contained, incognito' : 'Contained');
    timed('idle-sent');
    said_noted();                         # the first line of this window's log: that it is contained, and what is kept
    marks_told();
    profiles_told();                      # the Profiles icon's list: told none in an incognito window
    my $local_home = grep { /^home local$/ } map { chomp; $_ } release_lines();
    window('home available') if $local_home;
    window('startup ready') unless $local_home && !length($pulled) && !home() && !$TOR_SESSION;
    sso_told();                           # the sign-ins of this profile, for the Profiles list's "Connect seamless SSO accounts"; in an incognito window, why there are none
    window('game helper ' . game_helper(), 'marksbar ' . (marks_bar() ? 'on' : 'off'), 'search ' . (engine() ? 'set' : 'none'), $PICTURES_SHOWN ? 'pictures ' . (pictures_elsewhere() ? 'allow' : 'block') : ());
    parts_told();                         # the parts installed: the window shows the icons and menus of those alone
    nav_told();
    if ($TOR_SESSION) { window('torsession made') }    # [C17] a Tor window opens no home page and no pulled tab, and connects only on your Connect to Tor in its LZRTNNL modal: Tor first, and only then an address
    elsif (length $pulled) { go($pulled, 'you pulled a tab out into this window') }    # [C4] checked as a typed address is, and [C5] written before its name is looked up: the address of a tab pulled out of another window, handed on a pipe
    elsif (my $home = home()) { go($home, 'you opened your home page') }    # [C4] an address that came from the bar, kept when you made it the home page
    newer() unless $INCOGNITO || $local_home;           # [C16] it would write its answer and an installer's lines. Only now, once the window is idle and its first page is drawn: a look for a newer release never stands before the first drawing
    window('release ' . ((beside())[0] // '-'));    # the release number, shown in Help > About
    window('checked ' . ($INCOGNITO ? 'none' : checked_kept()));    # when lzrprf last looked for a newer release, shown under Check for updates
    licence_told();                       # whether a licence code is kept, shown under Enter licence code
    support_told();                       # where a support request would go, and whether one is kept to read its answer
    link_told();                          # [C31] the badge of the live debug link, while it is on
    tool_watch();                        # [C20] the jobs you switched off, looked at once as the window starts
    my $home_update_due = $local_home && !$INCOGNITO;
    $IDLE_WORK = \&identity_asked unless $local_home;    # [C7] D18 asked while you have not typed yet, not after: it was 17 to 28 ms of the first visit (measured 2026-11-24); a window with a local home asks once that home is drawn, so it never waits for it
    my ($behind, $faults) = ($$, 0);    # this process, and the errors of its own it went on after (sub unheard)
    while (1) {
        my $event = eval { hear(scalar(link_due(scalar tnnl_due(scalar tool_due()))), 1) };    # what a page kept running wrote is read here too: an error of lzrprf's own in it ends that page, never the window
        if (!defined $event) { last unless $@; unheard('', $@, $behind, ++$faults); next }
        timed('heard ' . ($event =~ /^(\S+)/ ? $1 : '')) if $TIMED;    # "lzrprf try" with "times": the moment each line of the window was taken up, so a test reads how long lzrprf took to answer it (scripts/snappy.pl)
        eval { link_watch() } if length $event;    # [C31] a window that is never quiet still sends the link's lines when they are due (a cheap look, read once in two seconds)
        eval {    # each line taken up below; an error of lzrprf's own in it is caught after the last elsif (sub unheard)
        if ($event =~ /^go ([\x20-\x7f]{1,2100})$/) { typed($1) }    # [C4] the one place an address comes from: the bar of lzrprf's own window; a size said while it was fetched and laid out is the size it is laid out again at
        elsif ($event =~ /^home ([1-9][0-9]{2,3}) ([1-9][0-9]{1,3})(?: (game))?$/ && $1 <= 8192 && $2 <= 8192) { home_shown(0+$1, 0+$2, $3) }
        elsif ($event =~ /^page refresh (0|[1-9][0-9]?)$/ && $1 == $TAB) { my $live = live_of($TABS[$TAB]); named_again(); my $list = $live && $live->{shown} ? $live->{shown} : $SHOWN && $SHOWN->{list}; window("relaid $TAB", @$list, '.') if $list; live_layers_again() }
        elsif ($event eq 'live') { live_turn(); trmnl_opened() if $TRMNL_OPEN; permits_later(); my $home = live_of($TABS[$TAB]); if ($home_update_due && $home && $home->{home_ready}) { $home_update_due = 0; newer() } $IDLE_WORK //= \&identity_asked if $local_home && $home && $home->{home_ready} }    # a page kept running with its tab answered, or is to end (sub live_answered); [C26] what it asked meanwhile is put to you after
        elsif ($event =~ /^scripts (list|reset|revoke|set)(?: (0|[1-9][0-9]{0,3}))?(?: (always|deny))?$/ && ($1 eq 'revoke' ? defined $2 && !defined $3 : $1 eq 'set' ? defined $2 && defined $3 : !defined $2 && !defined $3)) { scripts_set($1, $2, $3); said_noted() }    # [C26] [C4] LZRDFNDR scripts, from the cogwheel's menu
        elsif ($event =~ /^scripts (e1|curated)(?: (0|[1-9][0-9]{0,3}))? (on|off)$/ && ($1 eq 'curated') == defined $2) { scripts_set($1, $2, $3); said_noted() }    # [C26] the switch of the sandbox (E1), or of one curated rule (E2)
        elsif ($event =~ /^button ([1-9][0-9]{0,8}) ([1-5])$/) { my $again = permit_button($1, $2); go($again, 'you reloaded') if $again; said_noted() }    # [C26] the answer to the question about scripts, which never held the page
        elsif ($event eq 'scripts sites') { sites_told() }    # [C26] LZRDFNDR's On Websites: the scripts of each site and your decision on each
        elsif ($event =~ /^scripts decide (0|[1-9][0-9]{0,3}) (always|deny|allow-once|deny-once|forget)$/) { sites_decide($1, $2); said_noted() }    # [C26] [C4] a decision changed there
        elsif ($event eq 'sends list') { sends_told() }
        elsif ($event =~ /\Asends decide (0|[1-9][0-9]{0,3}) (always|deny|allow-once|deny-once|forget)\z/) { sends_decide($1, $2) }
        elsif ($event eq 'essential list') { essential_web_told() }
        elsif ($event =~ /\Aessential save ([01])((?: [0-9]=[a-z-]+){0,8})\z/) {
            my ($on, $changes) = ($1, $2);
            my $ok = essential_web_save($on, grep length, split / /, $changes);
            my ($again, $resolved) = $ok ? permit_essentials_saved() : ();
            window('essential saved ' . ($ok ? $resolved ? 'resolved' : 'ok' : 'failed'));
            essential_web_told();
            if ($again) { $PERMIT_RELOAD = $again; go($again, 'you reloaded') }
            elsif ($resolved) { permits_later() }
        }
        elsif ($event eq 'redirects list') { redirects_told() }    # [C4] LZRDFNDR's Redirects: every redirect put to you and your decision on each
        elsif ($event =~ /^redirects decide (0|[1-9][0-9]{0,3}) (proceed|cancel|allow-once|deny-once|forget)$/) { redirects_decide($1, $2); said_noted() }    # [C4] a decision changed there
        elsif ($event =~ /^filters (list|switch|allow|revoke)(?: (0|[1-9][0-9]{0,3}))?(?: (on|off))?$/ && ($1 eq 'list' ? !defined $2 && !defined $3 : $1 eq 'switch' ? defined $2 && defined $3 : defined $2 && !defined $3)) { filters_set($1, $2, $3); said_noted() }    # [C27] [C4] Filters, from the cogwheel's menu: the lists, a list switched, a blocked request's host let through on its site, or that revoked
        elsif ($event =~ /^video (0|[1-9][0-9]?)$/ && $1 < $VIDEOS) { videoed($1) }    # [C22] you clicked the place of a video: the one moment a video is fetched
        elsif ($event =~ /^video at (0|[1-9][0-9]?) ((?:playing|paused|ended|off|gone) [0-9]{1,6}\.[0-9]{3} [0-9]{1,2}(?:\.[0-9]{1,3})? [0-9]{13})$/ && $1 < $VIDEOS) { video_sound_at($1, $2) }    # [C22] the picture's clock of a video whose sound you turned on: its sound plays in the sound process, in step
        elsif ($event eq 'video stop') { window("video $TAB $VIDEO_CLICKED stopped") if defined $VIDEO_CLICKED }    # [C22] a Stop that met no fetch: the video had come, failed or was stopped already, and a box still saying Stopping gets its mark back
        elsif ($event =~ /^page ((?:click|move|down|up|scroll (?:0|[1-9][0-9]?)) (?:0|[1-9][0-9]{0,5}) (?:0|[1-9][0-9]{0,5})|out|key (?:[\x21-\x7e]|Space|Escape|Enter|Tab|Backspace|Delete|ArrowUp|ArrowDown|ArrowLeft|ArrowRight|Home|End|PageUp|PageDown)(?: shift)?|text [^\x00-\x1f\x7f]{1,$LIVE_TEXT})$/) { live_input($1) }    # a click in the page, the pointer moved over it, its button down or up, the pointer out of it, a key while it has the keyboard, text typed into its field, where the window shows it from: handed to the page kept running, and to nothing else
        elsif ($event =~ /^page ctrl ([a-z@\[\]\\^_])$/) { trmnl_input("ctrl $1") }    # [C29] a key held with Control, in a terminal's tab alone
        elsif ($event =~ /^page ((?:drag|context) (?:0|[1-9][0-9]{0,5}) (?:0|[1-9][0-9]{0,5})|(?:menu|tkey) [a-z]{1,8}(?:-[a-z]{1,8})?|wheel -?[1-9][0-9]{0,2}|copy|pastelong|paste [\x21-\x7e]+)$/) { trmnl_input($1) }    # [C29] in a terminal's tab alone: a drag that selects or moves a divider, a right press, an item of its menus, a key of its own (24-trmnl-panes.pl), the wheel, your copy, and your paste as the window read it from the clipboard
        elsif ($event =~ /^inspect (0|[1-9][0-9]?) ([1-9][0-9]{0,8}) ([1-9][0-9]{0,8}) (open|-|(?:[0-9a-f]{2}){1,500})$/) { inspect_input($1, $2, $3, $4) }    # [C18] the user opened or typed into the Inspect pane of this tab
        elsif (viewing($event)) { relaid() }    # the window's page has a new size: the page shown is laid out again at its width, from what was kept, and nothing is fetched
        elsif ($event =~ /^tab move (0|[1-9][0-9]?) (0|[1-9][0-9]?)$/) { tab_moved($1, $2) }    # a tab dragged along the strip to another place among the tabs: the page shown stays as it is
        elsif ($event =~ /^tab (new|select|close)(?: (0|[1-9][0-9]?))?( kept)?$/) { tabbed($1, $2, $3); relaid() }    # a tab chosen in the strip: the window shows the drawing it kept of it ("kept"), or lzrprf sends the one it kept, and only a page kept at another width is laid out again; nothing is fetched, unless a new tab opens the home page
        elsif ($event eq 'tab reopen') { tab_reopened(); relaid() }    # Cmd-Shift-T: the tab closed last, at its place, from lzrprf's memory alone
        elsif ($event =~ /^tab out (0|[1-9][0-9]?) (-?[0-9]{1,5} -?[0-9]{1,5} [1-9][0-9]{1,4} [1-9][0-9]{1,4})$/) { tab_out($1, $2); relaid() }    # a tab pulled out of the strip: a window of its own
        elsif ($event =~ /^menu (clear-history|clear-sessions|forget-cookies|home|bookmarks-bar|pictures)$/) { menu($1); said_noted() }
        elsif ($event eq 'menu debug-link') { link_menu(); said_noted() }    # [C31] the live debug link, switched on or off in the cogwheel's menu
        elsif ($event =~ /^link drew ([0-9]{1,6})$/) { link_drew($1) }    # [C31] how long the window took to draw a list, said only while the link is on
        elsif ($event =~ /^link shot ([0-9a-f]{16,32}) ([A-Za-z0-9+\/]+={0,2})$/) { link_shot($1, $2) }    # [C31] the window's picture of itself, for a signed command that asked for it
        elsif ($event =~ /^game helper (on|off)$/) { game_helper_set($1 eq 'on'); said_noted() }    # H-0071: LZRDFNDR's satellite in the minigame, from the switch in the Other tab of its panel
        elsif ($event =~ /^mark open (0|[1-9][0-9]{0,2})$/) { $MARKS[$1] ? go($MARKS[$1][2], 'you opened a bookmark', $1) : idle('That bookmark is no longer there.') }    # [C4] an address kept from the bar or typed into the window's own modal
        elsif ($event =~ /^mark remove (0|[1-9][0-9]{0,2})$/) { mark_removed($1); said_noted() }
        elsif ($event =~ /^mark save\t(-|0|[1-9][0-9]{0,2})\t([A-Za-z0-9 ._\/-]{0,300})\t([^\t\x00-\x1f\x7f]{1,800})\t([\x20-\x7f]{1,2100})$/) { mark_saved($1, $2, $3, $4); said_noted() }
        elsif ($event =~ /^nav (back|forward|reload)$/) { navigated($1) }    # [C4] an address this tab went to already, from its own list
        elsif ($event =~ /^search (brave|duckduckgo|google)$/) { search_set($ENGINES{$1}); said_noted() }
        elsif ($event =~ /^search custom\t([\x21-\x7e]{1,2000})$/) { search_set($1); said_noted() }
        elsif ($event eq 'log') { log_shown() }
        elsif ($event =~ /^tor (on|off)$/) { $TOR_SESSION ? ($1 eq 'on' ? tor_session_on() : tor_session_asked()) : $1 eq 'on' ? tor_window_opened() : window('tor off') }    # [C17] Tor, from the onion icon of the bottom bar: a window that is not a Tor window opens one apart from itself; in a Tor window, on connects it and off asks to close the whole window first
        elsif ($event =~ /^tool (open|sense|all)$/) { tool_shown($1) }    # [C20] the application's tool, from its icon in the bottom bar: a look, which changes nothing; "all" from its Show all processes, with every process
        elsif ($event =~ /^tool note ([^\x00-\x1f\x7f]{1,1000})\t([^\x00-\x1f\x7f]{0,2000})\z/) { tool_note($1, $2) }    # [C20] a note you wrote to the processes of a program in Show all processes
        elsif ($event =~ /^tool (act|undo) ((?:0|[1-9][0-9]{0,2})(?:,(?:0|[1-9][0-9]{0,2})){0,199})$/) { tool_done($1, $2) }    # [C20] the rows you ticked, and for a switching off confirmed
        elsif ($event eq '') { tool_watch(); tnnl_watch(); link_watch() }    # [C20] nothing was said for a while: the jobs you switched off are looked at again, and the VPN under Tor
        elsif ($event =~ /^parts set((?: (?:lzrbrwsr|lzrdfndr|lzrtrmnl|lzrtnnl|lzrgm)){0,5})$/) { parts_set(split ' ', $1) }    # Add or remove LZR modules: the set ticked, after Restart with these modules
        elsif ($event eq 'parts list') { parts_told() }
        elsif ($event =~ m{^tnnl vpn file (/[\x20-\x7e]{0,1000})$}) { tnnl_file($1) }    # LZRTNNL: the WireGuard file chosen in the Tor window's Open panel
        elsif ($event eq 'tnnl vpn look') { tnnl_look() }    # LZRTNNL: whether the VPN is active now
        elsif ($event eq 'tnnl vpn off') { tnnl_forget() }    # LZRTNNL: Use also VPN unticked
        elsif ($event eq 'update-check') { $INCOGNITO ? idle('An incognito window looks for no newer release; a window that is not incognito does, in its cogwheel menu.') : newer(1) }
        elsif ($event =~ /^frame (full|-?[0-9]{1,5} -?[0-9]{1,5} [1-9][0-9]{1,4} [1-9][0-9]{1,4})$/) { frame_said($1) }    # the window was moved, resized or made full screen: kept for the next window
        elsif ($event eq 'incognito') { incognito_opened(); said_noted() }
        elsif ($event eq 'window new') { window_opened(); said_noted() }    # File > New Window (sub window_opened)
        elsif ($event eq 'window tor') { tor_window_opened(); said_noted() }    # File > New Tor Window: as the onion icon
        elsif ($event =~ /^help (privacy|terms)$/) { help_opened($1); relaid() }    # Help > Privacy Policy and Terms and Conditions: the site's own page in a new tab
        elsif ($INCOGNITO && $event =~ /^profiles? /) { profiles_refused('An incognito window has no profile, and opens, makes or changes none.') }
        elsif ($event eq 'sso list') { sso_told() }    # "Connect seamless SSO accounts" was opened: each provider as connected now
        elsif ($event =~ /^sso connect ([a-z]{1,16})$/) { sso_connect($1); relaid() }    # Connect: the provider's own sign-in page in a new tab
        elsif ($event =~ /^sso remove ([a-z]{1,16})$/) { sso_remove($1); said_noted() }    # Remove: asked once, then its cookies deleted
        elsif ($event =~ /^sso /) { idle('That is not a provider lzrprf knows, or not a word it takes. Nothing was changed.') }
        elsif ($event eq 'profile list') { profiles_told() }    # the Profiles icon was pressed: which profile has a window open is looked at now
        elsif ($event =~ /^profile open (first|[0-9a-f]{12})$/) { profile_window($1); said_noted() }    # a profile chosen in the list: a new window of it, by its id
        elsif ($event =~ /^profile new\t([^\t]{0,400})$/) { profile_new($1); said_noted() }    # "New profile": the name typed into the window's own field, checked here
        elsif ($event =~ /^profile rename\t(first|[0-9a-f]{12})\t([^\t]{0,400})$/) { profile_renamed($1, $2); said_noted() }
        elsif ($event =~ /^profile remove (first|[0-9a-f]{12})$/) { profile_removed($1); said_noted() }
        elsif ($event =~ /^profiles? /) { profiles_refused('That is not a profile lzrprf knows, or not a word it takes. Nothing was changed.') }    # a path, a dot, a slash, an id of another length or form: no folder is named
        elsif ($event =~ /^licence set ([0-9A-Za-z \-]{1,200})$/) { licence_set($1) }    # "Enter licence code": the code typed into the window's own field, checked here before anything is kept
        elsif ($event eq 'licence remove') { licence_removed() }
        elsif ($event =~ /^support send ([A-Za-z0-9+\/]+={0,2}) (-|[A-Za-z0-9+\/]+={0,2})$/) { support_sent($1, $2) }    # [C4] "Support request": your words and, when you ticked it, the window's picture of itself; the address is the release file's, never the window's
        elsif ($event eq 'support read') { support_read() }    # [C4] the answer to the request kept, read from the release file's support address
        elsif ($event eq 'support forget') { support_forgot() }
        elsif ($event eq 'import sources') { import_sources() }    # [C15] "Import bookmarks..." in the window's wizard: the browsers on this Mac, then a browser's profiles, then a profile imported at once
        elsif ($event =~ /^import profiles (chrome|edge|brave|vivaldi|firefox|safari|file)$/) { import_profiles($1) }
        elsif ($event =~ /^import go (chrome|edge|brave|vivaldi|firefox|safari|file) (0|[1-9][0-9]?)$/) { import_go($1, $2); said_noted() }
        elsif ($event =~ /^import path ([\x20-\x7e]{1,1000})$/) { import_path($1); said_noted() }
        elsif ($event =~ m{^import allowed (chrome|edge|brave|vivaldi|firefox|safari) (/[\x20-\x7f]{0,1000})$}) { import_allowed($1, $2); said_noted() }    # [C15] Allow in the Open panel, and the folder chosen in it; a character past ASCII comes as \x7f, and the comparison refuses it
        elsif ($event =~ /^import denied (chrome|edge|brave|vivaldi|firefox|safari)(?: (failed|at-once))?$/) { import_unshown($1, $2) if $2; import_allowed($1, undef); said_noted() }    # Cancel in the Open panel, or a panel the window could not show
        elsif ($event eq 'import cancel') { import_cancelled() }    # the wizard closed: an Open panel asked for and not answered is dropped, so an answer that comes late is not taken
        elsif ($event =~ /^fault / && $DRAWN) { $DRAWN = 0; fault('undrawn') }    # the window could not draw a list that "checked" let through: it shows nothing of it. Taken once for a page that was handed over, and never without one: the window's process cannot open the question about a report whenever it likes
        1 } or unheard($event, $@, $behind, ++$faults);    # Henry 2026-11-24: a page took the whole browser down. An error of lzrprf's own stays in the tab it met
    }
    leave();
}

sub unheard {                             # an error of lzrprf's own while it took up a line of the window or of a page (sub behind): the page of the tab shown is ended and the tab says so, and the window and its other tabs go on
    my ($event, $error, $behind, $faults) = @_;
    POSIX::_exit(1) unless $$ == $behind;    # a copy made by fork that met it ends, and never goes on as the one behind the window
    ($error = "$error") =~ s/\s+\z//;
    $error =~ s/[^\x20-\x7e]/?/g;
    $error = substr($error, 0, 300);
    my ($word) = $event =~ /\A([a-z-]{1,20})/;
    eval { record("lzrprf met an error of its own while it took up " . (defined $word ? "\"$word\" from the window" : 'what a page wrote') . ", ended the page of the tab shown and went on: $error") };
    my $live = live_of($TABS[$TAB]);
    eval { live_end($live, 'lzrprf met an error of its own', 1) } if $live;
    $DRAWN = 0;
    leave() if $faults > $BEHIND_FAULTS;    # one that comes back at every line is not gone on after for ever
    eval { idle("$APP met an error of its own with this page, so the page was ended; the window and its other tabs go on. Type the address again to load it. What it was: $error") };
}

# The pair. The installer puts the application and lzrprf in place together,
# and the application's "release" file names the SHA-256 of that lzrprf.
# When this file is another one, the application does not start: the window
# says why and what mends it, with one button, Quit, and there is no way on
# from there. An application whose file names no lzrprf, or that has no such
# file, does not start either: applications before release 12 named none.
# Only a program that stands in no application folder and has no "release"
# file beside it is not asked: the installer puts no such program in place,
# and the launcher starts none.
#
# The same file names, in lines "file NAME SHA-256", the files in the folder
# of the program: the program lzrprf starts in the page container, and the
# launcher. From release 16 on each named file must be the file that is
# there, and the program itself must be named, or the application does not
# start. From release 17 on nothing stands beside the program in an
# application folder that the file does not name: so the launcher must be
# named too, and a file that was put there later stops the start. A name that
# begins with a dot is passed over: the Finder writes such a file into a
# folder it showed, and nothing starts one. The named files are looked at
# once, at the start; the program is read again before every page (sub
# laid_out). All of it is measured by a file of the application's own: it
# finds a program that was changed and a file that was not, as a damaged disk
# or a copy that did not finish leaves them. Whoever can change both is not
# found by it. A name is one plain word of
# letters, digits, dot, hyphen and underscore, so a program of another name
# cannot be named and does not start from an application folder. Only a plain
# file is read: a folder, a pipe or a device of that name counts as another
# file. A line that begins with "file" and is not in this shape counts as a
# file that differs, so a damaged line does not pass for no line.
sub paired {
    my @lines = release_lines();
    my ($pair) = map { /^lzrprf\s+(\S+)/ ? $1 : () } @lines;    # read for itself: a file whose other lines are damaged still names its lzrprf
    return if !defined $pair && $PROGRAM !~ m{\.app/Contents/MacOS/} && !-e release_file() && !-l release_file();
    my @files = map { /^file ([A-Za-z0-9_][A-Za-z0-9._-]*) ([0-9a-f]{64})$/ ? [$1, $2] : () } @lines;    # a name is one plain word, so it is a file in the program's own folder and nowhere else
    my ($other) = map { $_->[0] } grep { my $file = dirname($PROGRAM) . "/$_->[0]"; -f $file ? $_->[1] ne (($file eq $PROGRAM && program_same() ? $BEGAN : sum_of($file)) // '') : !part_left_out($_->[0]) } @files;    # the program, read whole at the start, is not read again while it is the same file; the program of a part left out is not there, as it was installed (sub parts_read)
    $other //= basename($PROGRAM) =~ s/[^A-Za-z0-9._-]/?/gr unless grep { $_->[0] eq basename($PROGRAM) } @files;
    $other //= unnamed(map { $_->[0] } @files) if $PROGRAM =~ m{\.app/Contents/MacOS/[^/]+$};
    my $what = @files < grep({ /^file\b/ } @lines) ? 'a line "file" there is not as the installer writes it' : defined $other ? "the file \"$other\" is another one than that file names, or is not named there" : undef;
    return if defined $pair && $pair eq (sum_of($SELF) // '') && !defined $what;
    ask(defined $pair && $pair eq (sum_of($SELF) // '') ? "$APP is not as it was installed, so it does not start. The installer writes the SHA-256 of the program and of the launcher into the application's release file: here $what. Installing again mends it." : defined $pair ? "$APP was installed together with another lzrprf than the one running now, so it does not start. The installer puts the two in place as a pair: a pair that differs was left by an install that did not finish, or lzrprf was replaced by hand. Installing again mends it." : "$APP does not say which lzrprf it was installed with, so it does not start. The installer puts the two in place as a pair and writes lzrprf's SHA-256 into the application's release file: here that line is missing, as in an application older than release 12 or one that was changed by hand. Installing again mends it.", 'Quit');    # whatever comes back, the run ends here
    window('quit');
    leave();
}

sub unnamed {                             # the first thing in the program's folder that is none of these names and does not begin with a dot; a folder that cannot be listed is itself the answer
    my %named = map { $_ => 1 } @_;
    opendir my $folder, dirname($PROGRAM) or return 'Contents/MacOS';
    my ($first) = sort grep { !/^\./ && !$named{$_} } readdir $folder;
    return defined $first ? $first =~ s/[^A-Za-z0-9._-]/?/gr : undef;
}

sub leave {
    tor_session_end('its window closed') if $TOR_SESSION;    # [C17] a Tor window ends in its order: requests refused, pages ended, its data removed and checked, then Tor
    my @live = @LIVE;
    live_end($_, 'the window closed', 1) for @live;    # no page kept running outlives its window
    jar_end();                            # [C7] nor the cookie jar: its lasting cookies written first, in a window of a profile
    trmnl_end($_, 'its window closed') for grep { $_->{trmnl} } @TABS;    # [C29] nor a terminal: its shell is hung up
    kill 'KILL', $witness if $witness;
    spare_dropped();                      # a page run's process started before its run, never handed anything
    curl_ended($CURL_SPARE);              # and curl started before its request
    sound_ended();                       # [C12] the sound process ends with its window
    removed($DIR) if $TOR_SESSION;        # [C17] a Tor window whose end was held: its folder goes before Tor does
    tor_off();                            # the Tor client ends with the window that started it
    unlink "$DIR/way.$$";
    removed($DIR) if $INCOGNITO;          # [C16]
    exit 0;
}

sub closed {                              # nothing more is done in this run: the window says why, and its bar takes nothing
    window('startup ready');    # a startup refusal must remain visible even when the home never became ready
    busy($_[0]);
    1 while defined hear();
    leave();
}

