# A size of the window's page: "view", its width and its height in points,
# each a number in its one form. The page is never laid at the window's own
# size, which differs from one computer to the next and would tell a site who
# you are: the width is taken to the nearest step of 160 points and the height
# to the nearest step of 128, so every window of about that size lays every
# page at one of a few sizes, the same on every computer, and the window fits
# the laid page to itself (function fit). A size outside the bounds a page is
# laid in is taken as the nearer bound. Anything else is no size. Returns
# whether the line was one.
my @VIEW_STEP = (160, 128);
sub viewing {
    my ($event) = @_;
    my ($wide, $high, $scale) = $event =~ /^view ([1-9][0-9]{0,4}) ([1-9][0-9]{0,4})(?: (2))?$/ or return; $VIEW_SCALE = $scale ? 2 : 1;
    @TRMNL_VIEW = ($wide, $high);
    cht_sized($TABS[$TAB]) if $TABS[$TAB]{cht};    # [C32] LZRCHT is drawn at that size too
    trmnl_relaid($TABS[$TAB]) if $TABS[$TAB]{trmnl};    # [C29] a terminal fills the page as it is, not as a page is laid: its panes laid out again in it
    ($wide, $high) = map { my $step = $VIEW_STEP[$_]; $step * int(($_ ? $high : $wide) / $step + 0.5) } 0, 1;
    @VIEW = ($wide < $VIEW_WIDE[0] ? $VIEW_WIDE[0] : $wide > $VIEW_WIDE[1] ? $VIEW_WIDE[1] : $wide, $high < $VIEW_HIGH[0] ? $VIEW_HIGH[0] : $high > $VIEW_HIGH[1] ? $VIEW_HIGH[1] : $high);
    delete $_->{scroll_clamp} for @LIVE;    # [C18] the window's page has another size, so its end is somewhere else: where it stopped short of a page's place says nothing now
    return 1;
}

# The page shown, laid out again at the width the window's page has now: the
# same answer and the same frame of style sheets that were kept when it was
# shown, in a page container as every run. lzrprf fetches no picture and no
# style sheet for it; but the run is a page run in a =live frame, so a page
# that is read with the network asks again, while it is read, for the
# external and module scripts it names, and each such request is written in
# the log and fetched as any request of a page kept running [C19]. Its pictures are the ones
# decoded then, placed where the new layout puts them; a place no picture was
# decoded for stays a grey box. One run at a time: before each run every size
# said so far is read, the latest kept, and the rest of what was said is heard
# after, in its order; and while it runs the window is heard the same way, so a
# newer width ends the run at once (sub outrun). The window says a size when a
# drag pauses for 120 ms too, so the page is laid at the drag's width while the
# button is held, and a release at that width costs the window only the swap. A run that is unfit, late or too large, or a second run that names
# style sheets again, leaves the page as it is shown, scaled by the window;
# that width is not tried again until another is said. The window keeps the
# place it was read at, as a share of the page's height ("relaid").
sub relaid {
    while ($SHOWN && ($SHOWN->{wide} != $VIEW[0] || ($SHOWN->{scale} // 1) != $VIEW_SCALE) && alive()) {    # another width, or the same on a screen of another scale
        if ($FROM) {
            my @later;
            while (defined(my $more = hear(0))) { last if $more eq ''; push @later, $more unless viewing($more) }
            push @HELD, @later;
            last if $SHOWN->{wide} == $VIEW[0] && ($SHOWN->{scale} // 1) == $VIEW_SCALE;    # the latest size is the width and scale shown already
        }
        $SHOWN->{wide} = $VIEW[0]; $SHOWN->{scale} = $VIEW_SCALE;
        my $kept = live_of($TABS[$TAB]);
        if ($kept && $kept->{wide} == $VIEW[0] && ($kept->{scale} // 1) == $VIEW_SCALE && $kept->{shown}) { window("relaid $TAB", @{ $kept->{shown} }, '.'); $kept->{unsent} = 0; $DRAWN = 1; next }    # the page kept running was laid at this width: its last drawing, as its scripts left it, and nothing is laid out
        $OUTRUN = 1; my @again = laid_out($SHOWN->{url}, $SHOWN->{got}, $SHOWN->{frame}, 1, $TABS[$TAB]{kept_app}); $OUTRUN = 0;    # a newer size said while it runs ends it ('outrun'), and the newest is laid next
        if (!$again[0] || $SHOWN->{two} && @{ $again[4] }) { live_dropped($again[5]); next }    # not shown: the page as it is shown stays, and so does the run kept running with it
        my ($shown) = pictured($again[0], $again[2], $SHOWN->{host}, undef, undef, $SHOWN->{pictures});
        window("relaid $TAB", @$shown, '.');
        $SHOWN->{list} = $shown;
        $SHOWN->{videos} = $again[6];     # [C22] the videos of the page as it is laid now, which a click names by number
        $DRAWN = 1;
        live_end($kept, 'it was laid out anew at another width', 1) if $kept;    # the new run is the page kept running now, laid at the width shown
        live_kept($again[5], $TABS[$TAB], $again[0], $again[2], $SHOWN->{host}, $SHOWN->{pictures}, $shown, $again[6]) if $again[5];
    }
    $CURL_WANTED = 1;
    if ($SHOWN && !$TABS[$TAB]{kept_app}) { $SPARE_WANTED = $SHOWN->{url} } else { spare_dropped() }    # a process for the page shown's next run, at the next quiet moment (sub spare_work); none waits for a page that is not shown
    live_told();
}

# The tabs. The window shows them in a strip of lzrprf's own above the bar,
# where no page draws, and says which you chose in one of three lines: "tab
# new", "tab select N" and "tab close N", N a tab that is there, in its one
# form; a fourth, "tab move FROM TO", moves a tab among the others (sub tab_moved). Each tab keeps its own page as $SHOWN keeps it (its address, its
# answer, the frame of style sheets it was laid with, its decoded pictures),
# its title, the addresses it went to, and lzrprf's last words in it. Only the
# selected tab's page is shown: choosing another clears the page and lays the
# chosen tab's page out again from what it kept, at the window's width (sub
# relaid), so nothing is fetched and nothing is written to the log. At most
# $TABS_MOST tabs; closing the last one leaves one empty tab. A new tab opens
# the home page when one is set, and is empty otherwise. After every such
# line lzrprf tells the window all the tabs again: "tabs COUNT SELECTED" and a
# line "title N TEXT" for each, the text checked by sub checked.
sub tabbed {
    my ($how, $n, $kept, $pulled) = @_;
    $TABS[$TAB]{shown} = $SHOWN;
    my $opened;
    if ($how eq 'new' && !defined $n && @TABS < $TABS_MOST) { push @TABS, fresh_tab(); $TAB = $#TABS; $opened = 1; noted('you opened a new tab') }
    elsif ($how eq 'select' && defined $n && $n < @TABS) { $TAB = $n }
    elsif ($how eq 'close' && defined $n && $n < @TABS) {
        my $live = live_of($TABS[$n]);
        live_end($live, 'its tab was closed', 1) if $live;
        cht_end($TABS[$n], 'its tab was closed') if $TABS[$n]{cht};    # [C32]
        trmnl_end($TABS[$n], 'its tab was closed') if $TABS[$n]{trmnl};    # [C29]    # at once: a closed tab's page is not waited for, and the window is not kept waiting the moment it took to end by itself (17 to 40 ms a close, measured 2026-11-23)
        noted(($pulled ? 'you pulled a tab out into a new window' : 'you closed a tab') . (length($TABS[$n]{url} // '') ? ": $TABS[$n]{url}" : ''));
        my ($gone) = splice @TABS, $n, 1;
        undef $PICTURES_BEFORE if $PICTURES_BEFORE && $PICTURES_BEFORE->{tab} == $gone;    # a closed tab keeps nothing for a first list
        closed_kept($gone, $n) unless $pulled;
        @TABS = (fresh_tab()) unless @TABS;
        $TAB-- if $TAB > $n || $TAB > $#TABS;
    }
    $SHOWN = $TABS[$TAB]{shown};
    tab_shown($how eq 'new' && !$opened ? "A window holds $TABS_MOST tabs at most: close one to open another." : undef, $how ne 'new' && $kept);    # a close the window showed at once, with the drawing it kept of the tab now shown, is "kept" as a select is
    my $home = $opened && home();
    go($home, 'you opened your home page') if $home;    # [C4] the address kept from the bar when you made it the home page
}

# A closed tab, kept for "Reopen Closed Tab" (Cmd-Shift-T) with its place: at most $CLOSED_MOST, the
# newest first, in the memory of this process and nowhere else, so an incognito window writes
# nothing for them either. Only the $CLOSED_DRAWN newest keep their page; an older one keeps its
# address, title and history, and is visited again when reopened. A tab with no address is not kept.
sub closed_kept {
    my ($tab, $at) = @_;
    return unless length($tab->{url} // '');
    unshift @CLOSED, [$at, $tab];
    splice @CLOSED, $CLOSED_MOST if @CLOSED > $CLOSED_MOST;
    $_->[1]{shown} = undef for @CLOSED[$CLOSED_DRAWN .. $#CLOSED];
}

# "tab reopen": the tab closed last, put in again at its old place (or last, when fewer tabs stand
# now) and chosen, with its page when lzrprf still has it, laid out again at the window's width
# when it was kept at another (sub relaid); else its address is visited, written in the log first.
sub tab_reopened {
    my $one = shift @CLOSED or return idle('No closed tab to reopen in this window.');
    if (@TABS >= $TABS_MOST) { unshift @CLOSED, $one; return idle("A window holds $TABS_MOST tabs at most: close one to reopen another.") }
    my ($at, $tab) = @$one;
    $TABS[$TAB]{shown} = $SHOWN;
    $at = @TABS if $at > @TABS;
    splice @TABS, $at, 0, $tab;
    $TAB = $at;
    $SHOWN = $tab->{shown};
    noted("you reopened a closed tab $tab->{url}") if $SHOWN;    # the same line "sub go" writes for one that is visited again
    tab_shown();
    go($tab->{url}, 'you reopened a closed tab') unless $SHOWN;    # [C4] an address this tab went to already
}

# The lists sent for the tabs' pages are kept for the $LISTS_KEPT tabs shown last, so a tab chosen
# again is sent its drawing and the application is not run; the others are laid out again when chosen.
# A list holds its pictures as text, so this bounds what lzrprf holds for tabs nobody looks at.
sub lists_bounded {
    my @kept = sort { $b->{used} <=> $a->{used} } grep { $_ && $_->{list} } map { $_ == $TAB ? $SHOWN : $TABS[$_]{shown} } 0 .. $#TABS;
    delete $_->{list} for @kept[$LISTS_KEPT .. $#kept];
}

# A tab dragged along the strip: "tab move FROM TO" takes the tab at FROM out and puts it in at TO,
# both tabs that are there. The selected tab stays the selected one, wherever it now stands, and its
# page stays shown: nothing is laid out again, nothing fetched, nothing written. The window is told
# the tabs again, as after every line of the strip.
sub tab_moved {
    my ($from, $to) = @_;
    return if $from >= @TABS || $to >= @TABS || $from == $to;
    my $chosen = $TABS[$TAB];
    my ($one) = splice @TABS, $from, 1;
    splice @TABS, $to, 0, $one;
    ($TAB) = grep { $TABS[$_] == $chosen } 0 .. $#TABS;
    window('tabs ' . @TABS . " $TAB", map { "title $_ $TABS[$_]{title}" } 0 .. $#TABS);
}

# A tab is shown at once, and the application is not run for it when its drawing was kept: the
# window shows the drawing it kept itself when it says "kept", and nothing of the page is sent; else
# lzrprf sends the list it kept, when it was laid at the width the window has now. Only a page kept
# at another width, or one whose list was let go (sub lists_bounded), is laid out again (sub relaid),
# with the page of the tab before cleared first. A page kept running that drew again while its tab
# was not shown is sent its new drawing.
sub tab_shown {
    my ($says, $kept) = @_;
    my $tab = $TABS[$TAB];
    window('tabs ' . @TABS . " $TAB", map { "title $_ $TABS[$_]{title}" } 0 .. $#TABS);
    return trmnl_shown($tab) if $tab->{trmnl};    # [C29]
    return cht_shown($tab) if $tab->{cht};    # [C32]
    window("address $tab->{url}");
    my $live = live_of($tab);
    my $list = $live && $live->{shown} && ($live->{home} || $live->{wide} == $VIEW[0] && ($live->{scale} // 1) == $VIEW_SCALE) ? $live->{shown} : $SHOWN && $SHOWN->{list} && $SHOWN->{wide} == $VIEW[0] && ($SHOWN->{scale} // 1) == $VIEW_SCALE ? $SHOWN->{list} : undef;
    $DRAWN = 0;
    delete @$live{qw(scroll_sent scroll_echo scroll_echoed scroll_clamp)} if $live;    # the window shows another drawing now: no scroll it was sent for the one before is still owed back, and where it stopped short of one says nothing of this (sub live_input)
    if ($kept && ($SHOWN || $live && $live->{shown})) { live_scroll_told($live); if ($live && $live->{unsent} && $list && $list == $live->{shown}) { window("relaid $TAB", @$list, '.'); $DRAWN = 1 } }    # the window's own drawing stands; a page kept running that drew meanwhile is sent, read where it was, and where its script scrolled it while another tab was shown goes just before
    elsif ($list) { live_scroll_told($live); window("page $TAB", @$list, '.'); $DRAWN = 1 }
    else { window("page $TAB", '.'); $SHOWN->{wide} = 0 if $SHOWN }    # the page of the tab before is gone; no width: sub relaid lays this one out again at the window's, and a scroll waits for a drawing to be shown on
    $live->{unsent} = 0 if $live && $DRAWN;
    if ($SHOWN) { $SHOWN->{used} = ++$LIST_USED; lists_bounded() }
    window($tab->{secure} ? ('secure begin', ($tab->{brief} ? "secure brief $tab->{brief}" : ()), (map { "secure line $_" } @{ $tab->{secure} }), 'secure end') : 'secure none');
    nav_told();
    live_layers_again();                  # [C18] the window let go of every layer with the line "tabs": the page shown makes its own again
    delete $_->{sound_held} for @LIVE;    # [C12] and the sound process of every sound (sub sound_hushed): a sound played again is sent whole again (sub live_sounded)
    idle($says // $tab->{says} // 'A new tab. Type an address above and press Return.', defined $says ? undef : $tab->{brief});
}

# The cogwheel's menu, each item one line of the window. "menu clear-history"
# empties the addresses every tab went to; the pages shown stay, and the log
# is cleared by its own button and by nothing else (sub log_shown).
# "menu clear-sessions" does that and also drops every page lzrprf keeps for a
# tab, its answer and its pictures: all that lzrprf holds of what a site sent.
# It empties the cookie jar too [C7], its file with it: no site knows you
# again through lzrprf, but for a provider you connected; the window warns, as asked, that pages would need a
# new login. "menu forget-cookies" clears the cookies of the shown tab's site alone. "menu home" makes the selected tab's address the home page, when
# it is one lzrprf fetches (sub address), in one plain file of yours, home,
# one line, written beside it and then given its name. The window asks before
# a clearing; what it could do by itself is clear, and keep one address that
# came from the bar.
sub menu {
    my ($what) = @_;
    if ($what eq 'forget-cookies') {      # [C7] the cookies of the shown tab's site, under every site they were set under
        my ($url, $host) = address($TABS[$TAB]{url} // '');
        return idle('No cookie was cleared: this tab shows no site.') unless $url && length $TABS[$TAB]{url};
        my $app = $TABS[$TAB]{kept_app};
        my $gone = $app ? kept_app_jar($app, sub { jar_clear() }) : jar_forget($url);
        my $stored = kept_storage_forget_site($url);
        return idle('The cookies were cleared, but Discord storage could not be cleared.') unless defined $stored;
        return idle('Discord storage and site cookies were cleared. Reload Discord to sign in again.') if $stored && $app;
        noted("you cleared the cookies of $host: $gone");
        return idle("The cookies of $host were cleared: $gone. Reload the page to see it without them.");
    }
    if ($what eq 'bookmarks-bar') {        # shown or hidden, kept in one plain file of yours, marksbar
        my $on = !marks_bar();
        if ($INCOGNITO) { $HELD_BAR = $on ? 1 : 0; window('marksbar ' . ($on ? 'on' : 'off')); return idle(($on ? 'The bookmarks bar is shown' : 'The bookmarks bar is hidden') . ' in this incognito window only: it writes nothing.') }    # [C16]
        unlink "$DIR/marksbar.new";
        return idle('The bookmarks bar could not be changed: its setting could not be written.') unless put("$DIR/marksbar.new", O_EXCL, $on ? 'on' : 'off') && rename("$DIR/marksbar.new", "$DIR/marksbar");
        synced();
        window('marksbar ' . ($on ? 'on' : 'off'));
        return idle($on ? 'The bookmarks bar is shown.' : 'The bookmarks bar is hidden.');
    }
    if ($what eq 'pictures') {            # pictures from other sites allowed or blocked, kept in one plain file of yours, pictures
        return idle('Pictures from other sites are not a choice in this release: nothing was changed.') unless $PICTURES_SHOWN;    # until lzrprf fetches by it, the choice is neither shown nor written
        my $allow = !pictures_elsewhere();
        my $said = $allow ? 'Pictures from other sites are allowed' : 'Pictures from other sites are blocked';
        if ($INCOGNITO) { $HELD_PICTURES = $allow ? 1 : 0; window('pictures ' . ($allow ? 'allow' : 'block')) if $PICTURES_SHOWN; return idle("$said in this incognito window only: it writes nothing.") }    # [C16]
        unlink "$DIR/pictures.new";
        return idle('Pictures from other sites could not be changed: their setting could not be written.') unless put("$DIR/pictures.new", O_EXCL, $allow ? 'allow' : 'block') && rename("$DIR/pictures.new", "$DIR/pictures");
        synced();
        window('pictures ' . ($allow ? 'allow' : 'block')) if $PICTURES_SHOWN;
        return idle("$said.");
    }
    if ($what eq 'home') {
        return idle("$UNKEPT, so the home page was not changed.") if $INCOGNITO;    # [C16]
        my ($url) = address($TABS[$TAB]{url});
        return idle('No home page was set: this tab shows no address lzrprf fetches.') unless $url && length $TABS[$TAB]{url};
        unlink "$DIR/home.new";
        return idle('The home page could not be kept: its file could not be written. Nothing was changed.') unless put("$DIR/home.new", O_EXCL, $url) && rename("$DIR/home.new", "$DIR/home");
        synced();
        return idle("The home page is set: $url. A new tab and the next window open it.");
    }
    my $count = 0;
    $count += @{ $_->{visited} } for @TABS;
    @CLOSED = ();                          # the closed tabs hold the addresses they went to, and their pages
    @$_{qw(visited at)} = ([], -1) for @TABS;
    nav_told();
    window('history clear');               # the pages the bar suggests go with the history
    return idle("The history was cleared: $count " . ($count == 1 ? 'address' : 'addresses') . ' that the tabs went to. The pages shown stay. The log is cleared by its own button.') if $what eq 'clear-history';
    @$_{qw(url title shown says secure)} = ('', '', undef, undef, undef) for @TABS;
    my @live = @LIVE;
    live_end($_, 'the sessions were cleared') for @live;    # a page kept running holds what its site sent, too
    undef $SHOWN;
    my $cookies = jar_clear();            # [C7] every cookie of this window's kind, and its file
    tab_shown("The history and the sessions were cleared: $count " . ($count == 1 ? 'address' : 'addresses') . ", every page lzrprf kept for a tab, and every cookie of this window's sites ($cookies). A provider you connected in the Profiles list keeps its sign-in, which is not cleared here: Remove it there to sign out. The log is cleared by its own button.");
}

# Back, forward and reload: the addresses this tab went to, as sub visit keeps
# them, and where in them the tab stands. Back and forward visit the address
# before or after, reload the address in the bar, each with the checks every
# typed address gets [C4] and written in the log first, as "you went back to",
# "you went forward to" or "you reloaded". The window is told what each would
# do now: "nav BACK FORWARD RELOAD", each 1 or 0.
sub nav_told {
    my $tab = $TABS[$TAB];
    window(join ' ', 'nav', $tab->{at} > 0 ? 1 : 0, $tab->{at} >= 0 && $tab->{at} < $#{ $tab->{visited} } ? 1 : 0, length $tab->{url} ? 1 : 0);
}

sub navigated {
    my ($way) = @_;
    my $tab = $TABS[$TAB];
    return length $tab->{url} ? go($tab->{url}, 'you reloaded') : idle('This tab shows no address to load again.') if $way eq 'reload';
    my $to = $tab->{at} + ($way eq 'back' ? -1 : 1);
    return idle("There is no page to go $way to in this tab.") unless $tab->{at} >= 0 && $to >= 0 && $to <= $#{ $tab->{visited} };
    $tab->{at} = $to;
    go($tab->{visited}[$to], "you went $way to");
}

# Search. Words typed into the bar that are no address (no "://", and a space
# or no dot) go to the search address you chose, kept in one plain file of
# yours, search, one line: an https address lzrprf fetches with %s once where
# the words go, percent-encoded. Three are offered by name; any other is typed
# into the window's own modal. Nothing is sent before one is chosen: the
# window is told "search ask" and asks. The address made is a visit like a
# typed one [C4], written in the log first as "you searched with".

sub engine_fit {                          # a search address lzrprf takes: https, a host by its name, port 443, plain characters, %s exactly once
    my ($text) = @_;
    return unless $text =~ /\A[\x21-\x7e]{1,2000}\z/ && $text =~ m{\Ahttps://}i && (() = $text =~ /%s/g) == 1;
    return (address($text =~ s/%s/x/r))[0] ? $text : undef;
}

sub engine {
    return $HELD_ENGINE if $INCOGNITO && $HELD_ENGINE;
    sysopen(my $in, kept_in() . '/search', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return;
    my @is = stat $in;
    return unless -f _ && $is[4] == $<;
    defined sysread($in, my $text, 2002) or return;
    my ($line) = $text =~ /\A([\x21-\x7e]{1,2000})\n?\z/ or return;
    return engine_fit($line);
}

sub search_set {
    my ($text) = @_;
    my $fit = engine_fit($text) or return idle('That search address was not kept: it must be https, a host by its name, port 443, in plain characters, with %s exactly once where the words go.');
    if ($INCOGNITO) { $HELD_ENGINE = $fit; window('search set'); return idle('Searches go to ' . ($fit =~ m{^https://([^/?#]+)}i)[0] . " in this incognito window only: $UNKEPT.") }    # [C16]
    unlink "$DIR/search.new";
    return idle('The search address could not be kept: its file could not be written. Nothing was changed.') unless put("$DIR/search.new", O_EXCL, $fit) && rename("$DIR/search.new", "$DIR/search");
    synced();
    window('search set');
    idle('Searches go to ' . ($fit =~ m{^https://([^/?#]+)}i)[0] . ' now: words typed into the bar that are no address are sent there.');
}

sub typed {
    my ($text) = @_;
    my $words = $text =~ s/^[ \t]+|[ \t]+$//gr;
    return barred() if grep { listed($_) } $words, split /[ \t]+/, $words;    # [C23] a listed address is not searched for either: the search address would carry it to the search site
    return go($text) if (address($text))[0] || $words =~ m{://} || $words !~ /[ \t]/ && $words =~ /\./ || !length $words;
    my $engine = engine() or do { window('search ask'); return idle('Choose a search engine first, and the words are sent there. Nothing was sent.') };
    my $query = $words =~ s/([^A-Za-z0-9._~-])/sprintf('%%%02X', ord $1)/ger;
    return go($engine =~ s/%s/$query/r, 'you searched with');
}

# What the lock beside the bar tells of the page shown: the address, the
# server lzrprf connected to, the answer's first line, the redirects on the
# way, and the certificates curl checked, as curl wrote them after the answer
# ("--write-out", sub fetch), each field plain characters and cut, so nothing
# in them acts on the window. Lines "# HEADING" or "NAME: VALUE".
sub secured {
    my ($url, $from, $got, $certs) = @_;
    my $plain = sub { my $one = $_[0] // ''; $one =~ s/[^\x20-\x7e]/?/g; return substr($one, 0, $_[1] // 300) };
    my ($status) = ($got // '') =~ /\A(HTTP\/[0-9.]+ [0-9]{3}[^\r\n]{0,80})/;
    my @lines = ('# Connection', 'Address: ' . $plain->($url, 2100), 'Server: ' . $plain->($from // 'unknown'),
        'Encryption: TLS 1.2 or newer, HTTP/1.1; the certificate checked against the roots lzrprf holds', 'Answer: ' . $plain->($status // 'unknown'),
        'Cookies: ' . (do { my ($host) = ($url // '') =~ m{\Ahttps://([^/:]+)}; my $key = sso_on() ? sso_of($host) : undef; defined $key && sso_state($key) ne 'none' ? 'only those of ' . sso_providers()->{$key}[0] . ', which you connected in this profile, sent to its own sites and kept until you remove it' : jar_kept() ? 'the site\'s own, kept apart under each site you visit, sealed in this profile until they expire or you clear them' : 'the site\'s own, kept apart under each site you visit, in this window\'s memory until it closes' }), '# Redirects on the way here');
    push @lines, @WAY ? map { ($_ + 1) . '. ' . $plain->($WAY[$_], 600) } 0 .. $#WAY : 'None: the address answered with the page itself.';
    my @chain = grep { /\S/ } split /-----END CERTIFICATE-----/, $certs // '';
    my %named = ('Subject' => 'Subject', 'Issuer' => 'Issuer', 'Start date' => 'Valid from', 'Expire date' => 'Valid until', 'Serial Number' => 'Serial number',
        'Signature Algorithm' => 'Signature', 'Public Key Algorithm' => 'Public key', 'X509v3 Subject Alternative Name' => 'Names it covers');
    for my $at (0 .. ($#chain < 5 ? $#chain : 5)) {
        push @lines, '# Certificate ' . ($at + 1) . ' of ' . @chain . ($at == 0 ? ': the site' : $at == $#chain ? ': the root side' : ': an issuer');
        for my $field ('Subject', 'Issuer', 'Start date', 'Expire date', 'Serial Number', 'Signature Algorithm', 'Public Key Algorithm', 'X509v3 Subject Alternative Name') {
            my ($value) = $chain[$at] =~ /^\Q$field\E:[ \t]*([^\r\n]*)/m or next;
            push @lines, "$named{$field}: " . $plain->($value, $field =~ /Alternative/ ? 500 : 300);
        }
    }
    push @lines, '# Certificate', 'curl wrote no certificate for this answer.' unless @chain;
    return \@lines;
}

sub home {                                # the home page you set, when it is still an address lzrprf fetches; a plain file of yours and no link
    sysopen(my $in, kept_in() . '/home', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return;
    my @is = stat $in;
    return unless -f _ && $is[4] == $<;
    defined sysread($in, my $text, 2102) or return;
    my ($line) = $text =~ /\A([\x21-\x7e]{1,2100})\n?\z/ or return;
    return (address($line))[0];
}

# A visit and what follows from it: a redirect you chose to follow is a new
# visit, made here after the one before has ended, as if its address had been
# typed (sub visit checks it the same way). Every one of them needs your yes.
sub go {
    my @next = @_;
    @WAY = ();
    $WENT = now();                        # the strip says how long the whole of it took, redirects followed and pictures fetched
    while (@next) {
        undef $NEXT;
        visit(@next);
        @next = $NEXT ? @$NEXT : ();
        relaid();
    }
}

# A redirect. curl follows none [C7]: an answer 301, 302, 303, 307 or 308
# is never laid out as a page. lzrprf shows it in its own modal: the address
# you went to, and the address the answer names, resolved against the first,
# and nothing is fetched for it unless you say so. Proceed is a new visit to
# it, with the checks every typed address gets; an address lzrprf does not
# fetch gets Cancel alone, and the modal says why in plain words (sub
# unfit). One redirect a visit is followed without asking: to the same
# address with "www." put in front of its host or taken off, https, the same
# path and query, written in the log first. The Location is read here by
# lzrprf, before the application sees the answer, and only when it is plain
# characters (0x21 to 0x7e), so nothing in it acts on the window. Returns the
# status and the whole address (undef when the answer names none, or one too
# long), or nothing when the answer is no redirect.
sub redirected {
    my ($got, $url) = @_;
    my ($status, $head) = $got =~ m{\AHTTP/1\.[01] (30[12378])[^\r\n]*\r\n(.*?)(?:\r\n\r\n|\z)}s or return;
    my ($to) = $head =~ /^location:[ \t]*([\x21-\x7e]{1,2000})[ \t]*\r?$/mi or return ($status, undef);
    my $whole = resolved($url, $to);
    return ($status, length $whole <= 2100 ? $whole : undef);
}

sub unfit {                               # why lzrprf does not fetch an address a page redirects to, in plain words
    my ($to) = @_;
    my $rule = 'lzrprf does not open this address: an address must be https, a host by its name, port 443, in plain characters without a space.';
    my ($scheme, $host, $port) = $to =~ m{^([A-Za-z][A-Za-z0-9+.-]*)://(?:[^/?#\@]*\@)?(\[[^\]/]*\]|[^/?#:]*)(?::([0-9]*))?} or return $rule;
    my @why;
    push @why, lc $scheme eq 'http' ? 'This address is not encrypted (http), and lzrprf opens https addresses only, so it cannot be opened.' : "This address is $scheme, not https, and lzrprf opens https addresses only." if lc $scheme ne 'https';
    push @why, 'Its host is a bare number, not a site name: lzrprf opens a site by its name only.' if $host =~ /^\[|^[0-9.]+\z/;
    push @why, "It names port $port, and lzrprf opens port 443 only." if defined $port && length $port && $port ne '443';
    return @why ? join(' ', @why) : $rule;
}

sub resolved {                            # a Location against the address it came from (RFC 3986 section 5.2, without a base that has a fragment)
    my ($base, $to) = @_;
    return $to if $to =~ m{^[A-Za-z][A-Za-z0-9+.-]*:};
    my ($origin, $path, $query) = $base =~ m{^(https://[^/?#]+)([^?#]*)(\?[^#]*)?};
    return "https:$to" if $to =~ m{^//};
    return "$origin$path" . ($query // '') . $to if $to =~ /^#/;
    return "$origin$path$to" if $to =~ /^\?/;
    my $joined = $to =~ m{^/} ? $to : ($path =~ s{[^/]*\z}{}r || '/') . $to;
    my ($rest) = $joined =~ /([?#].*)\z/s;
    $joined =~ s/[?#].*\z//s;
    my @out;
    my @parts = split m{/}, $joined, -1;
    for my $at (0 .. $#parts) {
        my $part = $parts[$at];
        if ($part eq '..') { pop @out if @out > 1; push @out, '' if $at == $#parts }
        elsif ($part eq '.') { push @out, '' if $at == $#parts }
        else { push @out, $part }
    }
    return $origin . join('/', @out) . ($rest // '');
}


# The application's local home scene uses the ordinary sealed page/layers/sound protocol.
# It receives no fetched answer and has no network, history entry or address in the bar.
# Only the window can ask for it; its dimensions stay local and are not a site fingerprint.
sub home_shown {
    my ($wide, $high, $game) = @_;
    my $fit = $wide > $VIEW_WIDE[1] ? $VIEW_WIDE[1] / $wide : 1;    # a window wider than a page is ever laid: the home is laid at the widest and as much lower, and the window scales it to its room as it does a page (function fit). The application refuses a =view outside the bounds and ends, which left the home black in a window 1611 wide (release 98)
    ($wide, $high) = map { my ($least, $most) = $_ ? @VIEW_HIGH : @VIEW_WIDE; my $is = int(($_ ? $high : $wide) * $fit + 0.5); $is < $least ? $least : $is > $most ? $most : $is } 0, 1;
    return if $TABS[$TAB]{trmnl} || $TABS[$TAB]{cht};    # [C29] [C32] a terminal's tab is no home, nor LZRCHT's
    if (length($TABS[$TAB]{url} // '')) {
        return unless $game && @TABS < $TABS_MOST;
        $TABS[$TAB]{shown} = $SHOWN; push @TABS, fresh_tab(); $TAB = $#TABS; undef $SHOWN; tab_shown();
    }
    my $old = live_of($TABS[$TAB]);
    return if $old && $old->{home} && $old->{wide} == $wide && $old->{home_high} == $high && !$game;
    if ($old && $old->{home}) {
        $old->{wide} = $wide; $old->{home_high} = $high; delete @$old{qw(home_ready home_owed home_first)};
        live_wrote($old, "resize $wide $high");
        live_wrote($old, 'key Enter') if $game;
        return;
    }
    live_end($old, 'the local home is shown', 1) if $old;
    my ($soon) = grep { $_->{starting} && $_->{starting}{tab} == $TABS[$TAB] } @LIVE;    # a home of this tab already being made
    return if $soon && $soon->{wide} == $wide && $soon->{starting}{high} == $high && !$game;
    live_end($soon, 'the local home is made at another size', 1) if $soon;
    my @before = @VIEW;
    @VIEW = ($wide, $high);
    $LAID_WIDE = $wide;
    my (undef, undef, $live) = contained('https://lzrbrwsr.invalid/_home', '', "=sheets\n", 1, undef, 1, 1);    # not waited for: the window's presses are taken while it makes its first list (a new tab held lzrprf 350 to 550 ms, measured 2026-11-23)
    @VIEW = @before;
    return window('startup ready'), idle('The local home could not be drawn.') unless $live;
    $live->{starting} = { tab => $TABS[$TAB], high => $high, game => $game };
    push @LIVE, $live;
}

sub home_arrived {                        # the first list of a home being made (sub home_shown), read in the loop of sub behind: drawn when its tab is still at home
    my ($live) = @_;
    while (!$live->{ended} && live_due($live)) {
        if (!defined $live->{whole} && !$live->{gone} && now() < $live->{until} && length $live->{held} <= $PAGE_BYTES && ref(my $asked = live_asked($live))) { live_fetched($live, $asked); next }    # [C19] as sub contained answers one before the first list
        my ($start, $at) = (delete $live->{starting}, delete $live->{whole});
        my ($tab, $wide) = ($start->{tab}, $live->{wide});
        my ($index) = grep { $TABS[$_] == $tab } 0 .. $#TABS;
        my $wrote = defined $at && $at >= 0 ? substr(substr($live->{held}, 0, $at + 8, ''), 0, $at + 1) : undef;
        @LIVE = grep { $_ != $live } @LIVE;
        my @before = @VIEW;
        @VIEW = ($wide, $start->{high});
        my ($lines, $hosts, $paths, $said, $named, $videos) = defined($wrote) && defined($index) && !length($tab->{url} // '') && !live_of($tab) ? checked($wrote) : ();
        @VIEW = @before;
        unless ($lines && !@$hosts && !@$paths && !@$named && !@$videos) { live_end($live, 'it is not shown', 1); return defined $index && $index == $TAB ? (window('startup ready'), idle('The local home could not be drawn.')) : undef }
        @$live{qw(looked until bytes tally)} = (0, now() + $LIVE_SECONDS, length $live->{held}, $LAID_TALLY);
        my ($shown) = pictured($lines, [], '', undef, undef, {});
        live_kept($live, $tab, $lines, [], '', {}, $shown, []);
        $live->{home_high} = $start->{high};
        if ($index == $TAB) { window("page $TAB", @$shown, '.'); $DRAWN = 1; live_told() } else { $live->{unsent} = 1 }    # a tab shown meanwhile: its own drawing stays, and this one is sent when the tab is chosen (sub tab_shown)
        live_wrote($live, 'key Enter') if $start->{game};    # Other > LZRDFNDR: show Start here; no address or new page
        return;
    }
}
