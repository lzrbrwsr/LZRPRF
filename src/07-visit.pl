# One visit: what happens after Return was pressed in the bar, as a chain of
# conditions. Each "return" below is a place where the chain ends and nothing
# is fetched. There is no other way to the fetch.
sub visit {
    my ($typed, $how, $mark, $auto) = @_;   # whether a redirect to the same site was followed already in this visit; what was typed, how its line in the log begins ("you typed", "you opened your home page", "you opened a bookmark", "you chose to follow a redirect to"), and the bookmark it came from
    return kept_app_visit($TABS[$TAB], $typed, $how) if $TABS[$TAB]{kept_app};
    $DRAWN = 0;
    prefetch_end();                       # [C19] nothing fetched ahead or kept for the page before is handed to this one
    trmnl_end($TABS[$TAB], 'an address was opened in its tab') if $TABS[$TAB]{trmnl};    # [C29]
    cht_end($TABS[$TAB], 'an address was opened in its tab') if $TABS[$TAB]{cht};    # [C32]
    return idle('This Tor window is closing: nothing more is fetched.') if $TOR_SESSION && $TOR_SESSION->{phase} !~ /^(?:made|connecting|sealed|browsing)$/;    # [C17] from the first step of its end, no new navigation
    pictures_before($SHOWN, $TABS[$TAB]) unless !$SHOWN && ($how // '') =~ /redirect to$/;    # a redirect followed is the same visit: what was kept for it stays
    undef $SHOWN;                         # a page asked for anew is laid out again only once it is shown
    return barred() if listed($typed);    # [C23] before the address is shown, kept in the tab or written anywhere
    my ($url, $host) = address($typed);
    return idle('lzrprf does not fetch that. An address must be https, a host by its name, port 443, in plain characters without a space.') unless $url;
    window("address $url");                 # the bar shows what will be sent, exactly
    permit_visited($url, $host);            # [C26]
    my $tab = $TABS[$TAB];
    my @left = grep { $_->{tab} && $_->{tab} == $tab } @LIVE;
    live_end($_, 'its tab went elsewhere') for @left;    # the page this tab kept running is told "=end" and ended before anything else is asked
    @$tab{qw(url title)} = ($url, '');
    window("title $TAB ");                  # the tab's title is the page's, once it is shown
    if (($how // '') =~ /redirect to$/ && $tab->{at} >= 0) { $tab->{visited}[$tab->{at}] = $url }    # a redirect followed takes the place of the address that redirected, so back does not land on it again
    elsif (($how // '') !~ /^you (?:went (?:back|forward) to|reloaded)$/) {    # back, forward and reload stand where sub navigated put them
        splice @{ $tab->{visited} }, $tab->{at} + 1;
        push @{ $tab->{visited} }, $url;
        shift @{ $tab->{visited} } while @{ $tab->{visited} } > $VISITED;
        $tab->{at} = $#{ $tab->{visited} };
    }
    $tab->{secure} = undef;
    window('secure none');
    nav_told();
    return fault('changed') unless program_same();    # before a site is asked: a program that is no longer the file this window began with is given no page, so none is fetched for it
    curl_for();                           # and curl for its request (sub curl_for)
    spare_for($url);                      # the process of its first run, started now: it waits in its container, handed nothing, while the address is judged, looked up and fetched
    $UNEXPIRED = !expire_log() if $UNEXPIRED;
    open my $request, '>>', "$DIR/busy" or return idle($UNWRITTEN);
    flock $request, LOCK_SH or return idle($UNWRITTEN);    # from "you typed" until its last line is written, a request keeps the log from being cleared under it
    my ($kept) = keeping();                 # read once: no line of one request is kept at more than this, whatever is chosen while it runs; when less is chosen meanwhile, its later lines are kept at that (sub record)
    record(($how // 'you typed') . " $url", $kept) or return idle($UNWRITTEN);  # [C5] before the name is even looked up
    timed('logged');
    my $shield = shield_said($url);       # [C28] judged before its name is looked up: a block sends nothing to that site
    return flag_shown($url) if $shield eq 'flagged';
    if ($shield ne 'allow') { record("$url not fetched: " . shield_why($shield), $kept) or return idle($UNWRITTEN); return idle('Nothing is shown: ' . shield_why($shield) . '.') }
    busy($TOR_WANTED ? "Asking Tor for $host." : "Looking up $host.");
    my ($where, $why) = $TOR_WANTED ? tor_where($host) : find($host);    # with Tor on, nothing is looked up on this computer: Tor's exit looks up the name
    timed('found');
    $why = own_network($host, $where, $kept) if $where && grep { $_->{own} } @$where;    # [C8]
    my ($got, $from, $tried, $certs);
    if (!$why) {
        record("$url -> lzrprf connects " . ($TOR_WANTED ? "through Tor, one circuit for $host" : 'to the first that answers of: ' . join(', ', map { $_->{text} } @$where)), $kept) or return idle($UNWRITTEN);    # [C5] written down first, connected second
        busy("Fetching $url");
        $tried = 1;
        identity_asked(); fetchers_for($where, undef, ['style', $host]) unless $TOR_WANTED;    # (17-prefetch.pl) [C7] D18: once a window, before its first visit, which hosts the application shows another browser identity
        ($got, $why, $from, $certs) = fetch($url, $where, undef, 1);    # the request of a page: the one that carries Accept
    }
    timed('fetched');
    record("$url " . ($why ? "failed: $why" : 'answered: ' . length($got) . " bytes from $from"), $kept) or return idle($tried ? $UNENDED : $UNWRITTEN);    # an answer whose line could not be recorded is not shown, and the window says the fetch was tried
    close $request;
    return idle("Nothing is shown: $why.") if $why;
    sso_heard($url, $got);                  # [C7] an answer of a provider you connected or are connecting, at top level: its cookies kept, the provider connected once its session cookie appears (sub sso_heard)
    if (my ($status, $to) = redirected($got, $url)) {    # never shown as an answer, never followed blindly: you choose, in lzrprf's own modal (sub redirected)
        return barred() if defined $to && listed($to);    # [C23] every hop: a redirect to a listed address is neither followed nor shown in the modal
        my ($fit) = defined $to ? address($to) : ();
        my ($there) = defined $fit ? $fit =~ m{^https://([^/]+)} : ();
        my $rest = sub { $_[0] =~ s{^https://[^/]+}{}r };
        if (defined $fit && !$auto && $rest->($fit) eq $rest->($url) && ($there eq "www.$host" || $host eq "www.$there")) {    # the same address with www. put in front of its host or taken off: followed once a visit, written down first
            record("$host redirected to $there ($status); followed, the same site", $kept) or return idle($UNWRITTEN);
            push @WAY, "$url answered $status, to $fit (followed by lzrprf: the same site)";
            $NEXT = [$fit, 'lzrprf follows that redirect to', $mark, 1];
            return idle("$host redirected to $there ($status): the same site, so lzrprf follows it.");
        }
        my $essential = essential_web_redirect($url, $fit);
        my $rule = essential_web_answer($essential, 0);
        my $family = sso_of($host);
        if ($rule eq 'forget' && defined $fit && defined $family && sso_on() && sso_state($family) ne 'none' && (sso_of($there) // '') eq $family && ($auto // 0) < $SSO_HOPS) {    # within the family of a provider you connected or are connecting: its own sign-in redirects, followed without a question and written down first, at most $SSO_HOPS a visit (sub sso_cookie)
            record("$host redirected to $there ($status); followed, the same sign-in family", $kept) or return idle($UNWRITTEN);
            push @WAY, "$url answered $status, to $fit (followed by lzrprf: the same sign-in family)";
            $NEXT = [$fit, 'lzrprf follows that sign-in redirect to', $mark, ($auto // 0) + 1];
            return idle("$host redirected to $there ($status), the same sign-in family, so lzrprf follows it.");
        }
        my $why = !defined $to ? 'The answer names no address to go to.' : defined $fit ? '' : unfit($to);
        my $decided = redirect_noted($url, $to, $status, defined $fit);    # [C4] 2 to follow, 1 to stop, 0 to ask
        my $by_rule = $decided ? 0 : $rule eq 'deny' || $rule eq 'deny-once' ? 1 : defined $fit && ($rule eq 'always' || $rule eq 'allow-once') ? 2 : 0;
        essential_web_answer($essential, 1) if $by_rule;
        my $words = "$url redirects to " . ($to // '(no address)') . " ($status)." . (length $why ? " $why" : '');
        my $press = $decided || $by_rule || web_question('redirect', $words, $essential, defined $fit, defined $fit && defined $mark);
        my $go = defined $fit && ($press == 2 || $press == 3 || $press == 6);
        redirect_answered($url, $to, $press, $go) unless $decided || $by_rule;
        noted("your kept decision answered the redirect of $url: " . ($go ? 'proceed' : 'cancel')) if $decided || $by_rule;
        if ($go) {
            push @WAY, "$url answered $status, to $fit (you chose to follow it)";
            my $moved = $press == 6 ? (mark_moved($mark, $fit) ? ' The bookmark now holds that address.' : ' The bookmark could not be changed.') : '';
            $NEXT = [$fit, 'you chose to follow a redirect to', undef];
            return idle("$url redirects to $fit ($status). lzrprf goes there as a new request.$moved");
        }
        window("page $TAB", '.');
        return idle("Nothing is shown: $url redirects " . (defined $to ? "to $to " : '') . "($status), and lzrprf did not go there." . (length $why ? " $why" : ''));
    }
    beside_wanted($url, $host, $got, $kept, $where);    # [C19] the scripts the page names, fetched side by side while it is laid out, for when it asks for them: begun the moment its first run is started (sub beside_begun)
    busy("$APP lays the page out, in its container.");
    timed('lay');
    my ($lines, $hosts, $paths, $said, $named, $live, $videos) = laid_out($url, $got, "=sheets\n", 1);    # [C14] a first run is told that no style sheet came with the answer; $live: the run, when the application keeps its page running (sub contained)
    beside_dropped() unless $lines && @$named; return flag_shown($url) if !$lines && $hosts eq 'flagged';    # [C28] nothing of the page is drawn: LZRDFNDR's red page instead
    return fault($hosts) unless $lines;
    prefetch_later() unless @$named; my $titled_first = $TITLED;             # the first run's title: what the tab says when that run is the one shown after later runs were laid
    my $styled = '';                        # what the bar says of the page's style sheets
    my ($with_sheets, $two) = ("=sheets\n", 0);    # the frame of style sheets the page shown was laid with, and whether that was a second run: what a new width lays it with again
    if (@$named) {                          # [C14] the page names style sheets on its own host: they are fetched, and the page is laid out once more with them
        $live = live_dropped($live);        # the first run is not the one kept running: a page shown as it was laid out first, because its second run is not shown, runs no more
        curl_for();                         # curl for the first style sheet, and
        spare_for($url); pictures_judged($lines, $paths, $host);    # the second run's process, started while its style sheets are fetched, and its pictures judged beside it (sub pictures_judged)
        my ($frame, $with) = sheeted($named, $host, $where, $kept) or return idle($UNWRITTEN);
        busy("$APP lays the page out again with its style sheets, in its container.");
        my @again = laid_out($url, $got, $frame, 1);
        my $asked = $READ_ASKED;            # what the second run asked for while it was read, fetched or refused: a third run would ask it again
        my ($n, $one) = (scalar @$named, @$named == 1);
        my $sheet_words = "the $n " . ($one ? 'style sheet' : 'style sheets') . " the page names on $host itself";
        if ($again[0] && !@{ $again[4] }) {    # a second run that names style sheets again is not shown, and nothing starts a third
            ($lines, $hosts, $paths, $said, $videos) = (@again[0 .. 3], $again[6]);
            ($with_sheets, $two) = ($frame, 1);
            $live = $again[5];              # the run shown is the one kept running
            $styled = "$APP laid the page out again with $with of the $n " . ($one ? 'style sheet' : 'style sheets') . " it names on $host itself. ";
            if (@FONTS_NAMED) {             # [C30] that run names web fonts its sheets name on the page's own host: they are fetched, and the page is laid out a third time with its sheets and them, shown when it is a page that names neither again
                my @fonts = @FONTS_NAMED;
                $live = live_dropped($live);    # the second run is not the one kept running: shown when the third is not, it runs no more
                my ($faces, $drawn) = fonted(\@fonts, $host, $where, $kept) or return idle($UNWRITTEN);
                busy("$APP lays the page out a third time with its style sheets and web fonts, in its container.");
                my $titled_second = $TITLED;
                my @third = laid_out($url, $got, $frame . $faces, 1);
                if ($third[0] && !@{ $third[4] } && !@FONTS_NAMED) {
                    ($lines, $hosts, $paths, $said, $videos) = (@third[0 .. 3], $third[6]);
                    ($with_sheets, $live) = ($frame . $faces, $third[5]);    # a new width lays it with both again
                    $styled .= "It laid it out a third time with $drawn of the " . @fonts . ' web ' . (@fonts == 1 ? 'font' : 'fonts') . ' they name. ';
                } else {
                    live_end($third[5], 'it is not shown', 1) if $third[5];
                    $TITLED = $titled_second;
                    $styled .= "The run with the web fonts they name is not shown: the page is drawn in $APP" . "'s own faces. ";
                }
            }
        } elsif ($again[0]) {               # a second run that names style sheets again broke the frame it was given: the first run is shown, and nothing starts a third
            live_end($again[5], 'it is not shown', 1) if $again[5];
            $TITLED = $titled_first;
            $styled = "$APP did not use $sheet_words: the page is shown as it was laid out first. ";
        } elsif ($again[1] =~ /^(?:changed|unstarted|uncontained)$/) {    # the program or its container failed, not the page: a new run cannot help, and that fault is said as for any page
            return fault($again[1]);
        } else {                            # [C14] the second run is no page: it failed, ended or was late, or wrote too much. The first run was read without the network, so none of the page's external or module scripts ran in it
            my $noted = sub { open my $request, '>>', "$DIR/busy" or return 0; flock $request, LOCK_SH or return 0; return record($_[0], $kept) };    # as in visit: no line of this request falls into a clearing of the log
            my $first_shown = 'The page is shown as it was laid out first, and none of its external or module scripts ran in the page shown.';
            if ($asked || $again[1] !~ /^(?:unfit|ended|late)$/) {    # a third run would ask the site again for what the second run asked (no run of a visit asks again for what an earlier run of it asked), or would write too much again
                $TITLED = $titled_first;
                $noted->("$url was laid out again with its style sheets, and that run is not shown: " . fault_said($again[1]) . '. While it was read it ' . asked_words($asked) . '. ' . ($asked ? 'A third run would ask for ' . ($asked == 1 ? 'it' : 'them') . ' again, so none is laid. ' : 'A third run would write as much, so none is laid. ') . $first_shown) or return idle($UNWRITTEN);
                $styled = "$APP did not use $sheet_words: the run with them " . ($asked ? asked_words($asked) . ', and was not shown.' : 'was not shown: ' . fault_said($again[1]) . '.') . " $first_shown ";
            } else {                        # the second run asked for no address: the page is laid out once more, given no style sheet and with the network, and that run is shown when it is a page
                my $unsheeted = join(' ', '=sheets', ('0') x $n) . "\n";    # each named sheet with length 0: no style sheet to use, and to the application not a first run, so it reads the page with the network and fetches its scripts, by the run that is shown
                $noted->("$url was laid out again with its style sheets, and that run is not shown: " . fault_said($again[1]) . ". While it was read it asked for no address, and the first run fetched and ran no external or module script, so lzrprf lays the page out once more without style sheets, with the network") or return idle($UNWRITTEN);
                busy("$APP lays the page out once more without its style sheets, in its container.");
                my @third = laid_out($url, $got, $unsheeted, 1);
                if ($third[0] && !@{ $third[4] }) {    # a run handed sheets that names sheets again is not shown, as a second run is not
                    ($lines, $hosts, $paths, $said, $videos) = (@third[0 .. 3], $third[6]);
                    ($with_sheets, $two) = ($unsheeted, 1);
                    $live = $third[5];      # the run shown is the one kept running
                    $noted->("$url laid out without its style sheets: it is a page, and it is shown. While it was read, with the network, it " . asked_words($READ_ASKED) . ($READ_ASKED ? ', its external and module scripts among them' : '')) or return live_dropped($live, $UNWRITTEN);
                    $styled = "$APP did not use $sheet_words: the run with them is not a page, so the page is shown as it was laid out once more without them, with the network for its scripts. ";
                } else {
                    live_end($third[5], 'it is not shown', 1) if $third[5];
                    $TITLED = $titled_first;
                    $noted->("$url laid out without its style sheets: that run is not shown either: " . ($third[0] ? 'it names style sheets again' : fault_said($third[1])) . ". $first_shown") or return idle($UNWRITTEN);
                    $styled = "$APP did not use $sheet_words: neither the run with them nor a run without them is a page. $first_shown ";
                }
            }
        }
    } elsif (@FONTS_NAMED) {                # [C30] the page names no style sheet, but its own <style> names web fonts on its own host: the first run was read without the network; they are fetched, and the page is laid out again with them
        my @fonts = @FONTS_NAMED;
        $live = live_dropped($live);        # the first run is not the one kept running
        my ($faces, $drawn) = fonted(\@fonts, $host, $where, $kept) or return idle($UNWRITTEN);
        my $font_words = 'the ' . @fonts . ' web ' . (@fonts == 1 ? 'font' : 'fonts') . ' its own style names';
        busy("$APP lays the page out again with its web fonts, in its container.");
        my @again = laid_out($url, $got, "=sheets\n" . $faces, 1);
        my $asked = $READ_ASKED;
        if ($again[0] && !@{ $again[4] } && !@FONTS_NAMED) {    # a run that names sheets or fonts again is not shown, and nothing starts another
            ($lines, $hosts, $paths, $said, $videos) = (@again[0 .. 3], $again[6]);
            ($with_sheets, $two, $live) = ("=sheets\n" . $faces, 1, $again[5]);
            $styled = "$APP laid the page out again with $drawn of $font_words. ";
        } elsif (!$again[0] && $again[1] =~ /^(?:changed|unstarted|uncontained)$/) {
            return fault($again[1]);
        } else {
            live_end($again[5], 'it is not shown', 1) if $again[5];
            my $unfonted = "=sheets\n" . join(' ', '=webfonts', ('0') x @fonts) . "\n";    # each named font with length 0: none to use, and to the application no first run, so it reads the page with the network and names no font again
            my @third = !$asked && !$again[0] && $again[1] =~ /^(?:unfit|ended|late)$/ ? laid_out($url, $got, $unfonted, 1) : ();    # as for sheets: only when that run asked for no address and was no page
            if (@third && $third[0] && !@{ $third[4] } && !@FONTS_NAMED) {
                ($lines, $hosts, $paths, $said, $videos) = (@third[0 .. 3], $third[6]);
                ($with_sheets, $two, $live) = ($unfonted, 1, $third[5]);
                $styled = "$APP did not use $font_words: the run with them is not a page, so the page is shown as it was laid out once more without them, with the network for its scripts. ";
            } else {
                live_end($third[5], 'it is not shown', 1) if @third && $third[5];
                $TITLED = $titled_first;
                $styled = "$APP did not use $font_words: the page is shown as it was laid out first, in $APP" . "'s own faces, and none of its external or module scripts ran in it. ";
            }
        }
    }
    timed('laid');
    my $title = $TITLED;                    # the title the run that is shown wrote
    my $first = grep { /^I\d/ } @$lines;    # the page draws pictures: it is shown at once with a grey box in the place of each, and drawn again with them once they came
    my $sent = $first ? (pictured($lines, $paths, $host, $where, $kept, pictures_so_far($host)))[0] : undef;
    my $first_mark;                               # the count of lists sent once the first went: the second is a patch of it only while the window still holds it (no list sent in between)
    if ($first) {
        window("page $TAB", @$sent, '.'); $first_mark = $WINDOW_LISTS;    # nothing is fetched for this one: a picture begun ahead and here, or decoded for the page this tab showed before, stands in its place; every other place is grey
        $DRAWN = 1;
        timed('list');
    }
    my ($shown, $fetched, $wanted, $decoded) = pictured($lines, $paths, $host, $where, $kept, undef, $got);
    undef $PICTURES_BEFORE;                # the page's own pictures are here: what was kept of the page before is dropped
    window("page $TAB", '.') if !$shown && $first;    # a line of a picture could not be written: the page drawn at once is taken away again, as nothing of this answer would have been shown before
    return live_dropped($live, $UNWRITTEN) unless $shown;
    timed($first ? 'pictured' : 'list');
    $first ? window_changed(defined $first_mark && $first_mark == $WINDOW_LISTS ? $sent : undef, $shown) : window("page $TAB", @$shown, '.');    # the tab a list is for is named, so a list that arrives once another tab was chosen in the window goes to that tab's kept drawing; the second drawing keeps the place the page is read at
    $DRAWN = 1;
    $SHOWN = { url => $url, got => $got, frame => $with_sheets, two => $two, host => $host, where => $where, pictures => $decoded, videos => $videos, sites => [grep { elsewhere($_, $host) } @PICTURED], wide => $LAID_WIDE, scale => $VIEW_SCALE, list => $shown, used => ++$LIST_USED };    # list: what was sent, sent again from here when the tab is chosen again (sub tab_shown)
    lists_bounded();
    live_kept($live, $tab, $lines, $paths, $host, $decoded, $shown, $videos) if $live;    # the page goes on with this tab: clicks and keys in it reach it, and what it draws again is checked as this list was
    live_told();
    $tab->{secure} = secured($url, $from, $got, $certs);
    $tab->{brief} = sprintf("%s \xc2\xb7 %d ms \xc2\xb7 %s", $got =~ m{\AHTTP/1\.[01] (\d{3})} ? $1 : '?', (now() - $WENT) * 1000, length($got) < 1000 ? length($got) . ' B' : sprintf('%d kB', length($got) / 1000));    # how the site answered: status, time, size; the first row of the lock's panel
    window('secure begin', "secure brief $tab->{brief}", (map { "secure line $_" } @{ $tab->{secure} }), 'secure end');
    $tab->{title} = $title;
    window("title $TAB $title");            # checked: plain characters, no control or format character, at most $TITLE (sub checked)
    window("history add $url\t$title");     # what the bar suggests while you type: the pages shown in this window, in its memory only, emptied by "Clear history" (function suggested)
    my $whole = "$host answered " . length($got) . ' bytes. ' . $styled . ($wanted ? "$fetched of the $wanted " . ($wanted == 1 ? 'picture' : 'pictures') . ' the page draws ' . (@PICTURED ? '' : "from $host itself ") . ($fetched == 1 ? 'was' : 'were') . ' fetched and shown' . (@PICTURED ? '; besides ' . $host . ', lzrprf asked ' . join(', ', @PICTURED > 4 ? (@PICTURED[0 .. 3], '...') : @PICTURED) . ' for them' : '') . '. ' : '') . (@$hosts ? 'The page names ' . @$hosts . (@$hosts == 1 ? ' other host' : ' other hosts') . ' (' . join(', ', @$hosts > 4 ? (@$hosts[0 .. 3], '...') : @$hosts) . '). lzrprf asked none of them' . (@PICTURED ? ' for anything but a picture.' : '.') : 'The page names no other host.') . (length $said ? " $said" : '');    # the application's own words why the page is in compatibility-statement mode, last and as plain text (sub stated)
    noted($whole);
    idle($whole, $tab->{brief});    # the strip: how the site answered, how long all of it took, how much came
    $NEXT = [$url, 'you reloaded', undef] if permits_asked();    # [C26] once the page is drawn, never before: no question holds a page; on an Allow it is loaded again with it
}

# The request is over and the connection to the site is closed. Only now does
# the application see the answer, in a page container, and only after the
# system said that this very process is contained, with the frame of style
# sheets it is given ("=sheets" and a line end on a first run). Returns the
# checked lines, the other hosts the page names, the paths of the pictures it
# names on its own host, its statement ('' for none) and the paths of the style
# sheets it names; or nothing, and one word for what went wrong. With $keep,
# the run is asked to keep its page running with the tab (sub contained), and
# the run that does so comes last; a first list that is unfit ends it.
sub laid_out {
    my ($url, $got, $sheets, $keep, $app) = @_;
    $LAID_WIDE = $VIEW[0];                # the width contained asks for in its =view frame, and the one width sub laid takes
    my ($wrote, $why, $live) = contained($url, $got, $sheets, $keep, undef, undef, undef, $app);
    timed('page-read');                   # what the application wrote is all here: the time to "laid" is lzrprf's check of it (sub checked)
    return (undef, $why) unless defined $wrote;
    return (live_dropped($live), flagged_by($wrote)) if substr($wrote, 0, 9) eq '=flagged ';    # [C28] LZRDFNDR blocked the page: its one line, and nothing of the page
    my ($lines, $hosts, $paths, $said, $named, $videos) = checked($wrote) or return (live_dropped($live), 'unfit');    # [C9]
    $live->{tally} = $LAID_TALLY if $live;    # what the first list holds, so a first key in a field is a splice checked by itself too (sub live_patched)
    return ($lines, $hosts, $paths, $said, $named, $live, $videos);
}

# A relayout outrun (sub relaid): what the window said while the page was laid out again is read as sub relaid
# reads it before a run, every size taken and the rest held in its order for later. Returns whether the width to
# lay at moved on from the one this run lays at, or the window is gone: either way the run is ended at once, so
# a drag that pauses at one width and then at another never waits for the first width's run.
sub outrun {
    my $got = sysread($FROM, $FROM_HELD, 65536, length $FROM_HELD);
    return 1 if defined $got ? !$got : !$!{EINTR};
    my @later;
    while (defined(my $more = hear(0))) { last if $more eq ''; push @later, $more unless viewing($more) }
    push @HELD, @later;
    return $VIEW[0] != $LAID_WIDE;
}

# The fonts a page is drawn with, as one frame in front of its answer:
# "=fonts", the length of each of the eight, a line end, then their bytes.
# The application opens no file of its own, so lzrprf reads them here, once
# in a window. A face that is a link, a pipe or anything but a plain file,
# is larger than $FACE_BYTES or does not begin as a font goes as length 0.
my $FRAME;
sub faces {                               # [C13]
    return $FRAME //= do {
        my @got = map {
            my ($in, $font) = (undef, '');
            sysopen($in, $_, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) && -f $in && binmode($in)
                && read($in, $font, $FACE_BYTES + 1) && length($font) <= $FACE_BYTES
                && $font =~ /\A\x00\x01\x00\x00/ ? $font : '';
        } @FACES;
        join(' ', '=fonts', map { length } @got) . "\n" . join('', @got);
    };
}

# One run of the application in a page container, for a page or for one
# picture: it is given what was fetched on descriptor 0, under the same
# limits, the same keeper and the same clock. Returns what it wrote, not yet
# checked; or nothing, and one word for what went wrong. A picture run is
# told one thing more, LZRPRF_PICTURE=1; a page run gets the size of the
# window's page first, "=view", its width and its height in points and a line
# end, then the fonts, then the frame of its style sheets, $sheets, none of
# which a picture run has.
#
# A page kept running with its tab. With $keep (a page run, never a picture
# run) the answer goes in the frame "=live", its length in bytes and a line
# end, then the answer; the application's half is src/page/scripted.rs.
# An application that keeps the page (an HTML page its engines read) writes
# its first list and then a line "=ready", and stays: its keeper keeps its
# input open and hands it the lines lzrprf writes into a third pipe, the
# relay, which only lzrprf and that keeper hold. lzrprf reads the first list
# up to "=ready", within the same $PAGE_SECONDS and $PAGE_BYTES, checks it as
# every first list, and returns the run with it: the page, its keeper, the
# relay, the pipe the page writes to and lzrprf's end of the keeper's pipe,
# which still ends the page when lzrprf ends by whatever way. An application
# that does not keep the page writes its list and ends, and is read to its end
# as before. Every line that reaches a page kept running is written by lzrprf
# from a line of the window it checked (sub live_input); every answer of the
# page is checked before anything of it is drawn (sub live_answered).
sub contained {
    my ($url, $got, $sheets, $keep, $tool, $local_home, $soon, $app) = @_;    # $soon: a page kept running is handed back once it is contained, and its first list read in the loop of sub behind (sub home_arrived)    # $tool 'judge': LZRDFNDR's verdicts on addresses before they are fetched ([C28], sub shield_asked); else the run is the application's tool ([C20], sub tool_shown): handed lzrprf's look at this computer as a picture run is handed a picture, and read to its end
    if ($app && (!kept_app_valid($app, $url) || !$keep || !defined $sheets || $tool || $local_home || $soon)) { return (undef, 'unstarted') }
    $READ_ASKED = 0;                      # this run has asked for nothing yet, whatever way it ends
    return (undef, 'changed') unless program_same();    # read again before every run: the program on the disk is the file this window began with, or nothing is laid out
    $keep = 0 unless defined $sheets;     # a picture run is never kept
    my $frame = defined $sheets ? "=view $VIEW[0] $VIEW[1]" . ($VIEW_SCALE == 2 ? " 2" : "") . "\n" . faces() . $sheets : '';    # the size first, numbers lzrprf holds to its bounds (sub viewing); [C13] [C14] the fonts read here, before the keeper is a copy of this process, so once in a window; handed over by the keeper alone, after the same word as the answer
    $frame .= permit_page($url, \$got, $app) if defined $sheets && !$tool;    # [C26] the decisions lzrprf holds for the site, after the style sheets; a site whose scripts are not allowed is handed its page with them taken out
    $frame .= ($app ? kept_app_jar($app, sub { jar_frame($url) }) : jar_frame($url)) if defined $sheets && !$tool && !$local_home;    # [C7] the cookies of the page's own site its script may see, after the permissions (sub jar_frame)
    my ($stored, $epoch) = $app ? kept_storage_frame($app, $url) : ('', undef);
    $frame .= $stored;
    $frame .= '=live ' . length($got) . "\n" if $keep;
    if (!$app && (my $ran = beside_taken($frame . $got, defined $sheets && !$tool, $url, !$local_home && !$soon))) { return run_read($ran, $keep, $sheets, $tool) }    # the very run, started beside the first (sub beside_begun)
    my ($input, $relay);                  # the keeper's end of the relay and lzrprf's, for a page kept running
    if ($keep) { pipe($input, $relay) or return (undef, 'unstarted') }
    my $run = (!$app ? spare_taken($url, $sheets, $tool, $local_home) : undef) // page_started($url, $sheets, $tool, $local_home, $app) // return (undef, 'unstarted');    # its process, started for this one run, here or a moment before (sub spare_for)
    my ($page, $answer_in, $from_page, $seal) = @$run{qw(page in from seal)};
    pipe(my $held, my $hold) or do { kill 'KILL', $page; waitpid $page, 0; return (undef, 'unstarted') };
    my $feeder = fork;
    if (!defined $feeder) {               # no second process to be had: the application is running by now, so it is ended here and not left to end by itself
        kill 'KILL', $page;
        waitpid $page, 0;
        return (undef, 'unstarted');
    }
    if (!$feeder) {                       # the keeper of this page
        close $_ for $from_page, $hold, grep { defined } $relay, map({ @$_{qw(relay from hold)} } @LIVE), trmnl_fds(), cht_fds(), beside_fds(), $SPARE ? @$SPARE{qw(in from)} : (), $CURL_SPARE ? @$CURL_SPARE{qw(to from)} : ();    # and lzrprf's ends of every page kept running: the end of lzrprf is the end of each of their pipes, held by nobody else
        keeper($held, $answer_in, "=seal $seal\n" . $frame . $got, $page, $input);
        POSIX::_exit(0);                  # the keeper never returns; were it ever to, it ends here and does not go on as a second lzrprf
    }
    close $_ for $answer_in, $held, grep { defined } $input;
    timed('page-forked');
    timed("run-forked $$") if $TIMED;    # "lzrprf try" with "times": each run of the application by the process that started it, a page's or a picture's (scripts/load-timeline.pl)
    fcntl($relay, POSIX::F_SETFL(), O_NONBLOCK) if $relay;    # lzrprf never waits in a write to a page: a line it cannot write at once ends the page (sub live_input)
    if (!inside($page)) {                 # [C3] the system did not say so: the answer stays here; the application was told the address and nothing else
        kill 'STOP', $page;               # held still before anything else: the keeper's end closes the application's input, and an application the system does not call contained is not to go on at that while it waits to be ended
        kill 'KILL', $feeder;             # the keeper first, here and below: it acts on the application's number, and is gone before the system may give that number to another process
        waitpid $feeder, 0;
        my $gone = waitpid($page, POSIX::WNOHANG()) == $page;    # it ended by itself: of a process that is gone the system has nothing to say
        kill 'KILL', $page unless $gone;
        waitpid $page, 0 unless $gone;
        return (undef, $gone ? 'ended' : 'uncontained');    # only a process still running, of which the system does not say that it is contained, is the container's fault
    }
    timed('page-inside');
    if ((syswrite($hold, 'g') // 0) != 1) {    # the keeper cannot be told that the system said so: nothing is handed over
        kill 'KILL', $feeder, $page;
        waitpid $_, 0 for $feeder, $page;
        return (undef, 'unstarted');
    }
    my $started = { page => $page, keeper => $feeder, relay => $relay, from => $from_page, hold => $hold, held => '', looked => 0, wide => $VIEW[0], scale => $VIEW_SCALE, until => now() + $PAGE_SECONDS, bytes => 0, waiting => 0, focus => 0, home => $local_home, url => $url, fetches => 0, heard => now() };
    @$started{qw(kept_app storage_epoch)} = ($app, $epoch) if $app;
    if ($soon && $keep) { $started->{fed} = $frame . $got if $soon eq 'beside'; return (undef, undef, $started) }
    beside_begun($started, $sheets, $keep, $tool) unless $app;    # what the page names is begun, and its second run when its style sheets are here first (07-visit-beside.pl)
    return run_read($started, $keep, $sheets, $tool);
}

# The application's process for one run, started and left waiting on its input for its seal, which
# its keeper hands over only after the system said it is contained (sub contained). Its variables
# are those of the run, the address among them: nothing of the answer is in it yet.
sub page_started {
    my ($url, $sheets, $tool, $local_home, $app) = @_;
    pipe(my $answer_out, my $answer_in) && pipe(my $from_page, my $to_lzrprf) or return;
    my $seal = run_seal() // return;      # [C1] the run's seal: in its variables, and again as the first line its keeper hands over, only after the system said it is contained
    my $page = fork // return;
    if (!$page) {
        %ENV = (LZRPRF_CONTAINED => $url, LZRPRF_SEAL => $seal, $TOR_WANTED ? (LZRPRF_TOR => '1') : (), $local_home ? (LZRPRF_HOME => ($INCOGNITO ? 'private' : 'home') . (game_helper() ? ' satellite' : '') . (part_on('lzrgm') ? '' : ' nogame') . (part_on('lzrtrmnl') ? '' : ' notrmnl')) : (), $tool ? ($tool eq 'judge' ? (LZRPRF_JUDGE => '1') : (LZRPRF_TOOL => '1')) : defined $sheets ? () : (LZRPRF_PICTURE => '1'), !$tool && !$local_home && defined $sheets && !$OUTRUN ? (LZRPRF_EARLY => '1') : (), !$app && !$tool && !$local_home && !$TOR_WANTED ? (LZRPRF_SOON => '1') : (), $TIMED && !$tool ? (LZRPRF_TIMES => '1') : ());    # the application is told the address it lays out, and for a picture that it is one, and sees no other variable: these it is given before the system is asked [C3]
        chdir '/';
        the_program($answer_out, $to_lzrprf);    # [C1]
    }
    close $_ for $answer_out, $to_lzrprf;
    return { page => $page, in => $answer_in, from => $from_page, seal => $seal, key => "$url\t" . ($TOR_WANTED ? 1 : 0), of => $$ };
}

# A page run's process started before its run: the 10 to 25 ms the system takes to put a process in
# its container (and the program's own start) are then spent while the address is judged and
# fetched, or while the window is quiet, and not on the way to the drawing (measured 2026-11-24). At
# most one, for one address, a plain page run's (no picture, tool, verdict or local home); made by
# this process alone and taken by it alone, so a copy of lzrprf never hands it anything. Each is
# one run's process as sub contained starts it, with the same variables, limits, container and seal
# of its own, and it is used once: sub contained hands it its answer as it would a process started
# there (its keeper, the system asked first, then the seal). One that is not used is ended, never
# kept for another address; one for an older Tor setting is not taken.
sub spare_for {
    my ($url) = @_;
    return if $SPARE && $SPARE->{of} == $$ && $SPARE->{key} eq "$url\t" . ($TOR_WANTED ? 1 : 0) or $BESIDE && $BESIDE->{run};    # or the run it would be for is started already (07-visit-beside.pl)
    spare_dropped();
    return unless $$ == $FRESH && program_same();    # a program changed on the disk is not started, as sub contained starts none
    $SPARE = page_started($url, "=sheets\n");
}

sub spare_taken {                         # the process started for this run, when it is the one for its address and is still waiting; else nothing, and one for another run is ended
    my ($url, $sheets, $tool, $local_home) = @_;
    return unless $SPARE && defined $sheets && !$tool && !$local_home;
    my $one = $SPARE;
    return spare_dropped() if $one->{of} != $$ || $one->{key} ne "$url\t" . ($TOR_WANTED ? 1 : 0);
    undef $SPARE;
    return $one if waitpid($one->{page}, POSIX::WNOHANG()) == 0;
    close $_ for @$one{qw(in from)};      # it ended while it waited, having been handed nothing: a new one is started in its place
    return;
}

sub spare_dropped {                       # the process started before its run, ended unused; a copy of lzrprf only forgets it
    my $one = $SPARE or return;
    undef $SPARE;
    if ($one->{of} == $$) { kill 'KILL', $one->{page}; waitpid $one->{page}, 0 }
    close $_ for @$one{qw(in from)};
    return;
}

sub spare_work {                          # what the next quiet moment does (sub hear): the process for the next run of the page shown, for a new width, and curl for the next request
    my ($url, $curl) = ($SPARE_WANTED, $CURL_WANTED);
    return unless defined $url || $curl;
    ($SPARE_WANTED, $CURL_WANTED) = ();
    return sub { spare_for($url) if defined $url; curl_for() if $curl };
}

sub idle_taken {                          # the work of a quiet moment, once: sub behind's first ($IDLE_WORK), then a spare's
    my $work = $IDLE_WORK // return spare_work();
    undef $IDLE_WORK;
    return $work;
}

# The seal of one run of the application [C1]: 16 random bytes as 32 hex digits, named to the
# application in LZRPRF_SEAL and written again by its keeper as the first line it hands over,
# "=seal" and the digits. The keeper writes nothing before lzrprf's word that the system called
# the application contained, so the line is lzrprf's handshake: the application refuses to start
# without it (src/page/sealed.rs), and then tries a write and a read its container refuses, and
# refuses to start when either is not refused. A variable alone is not enough: anyone can set one.
sub run_seal {
    open my $random, '<:raw', '/dev/urandom' or return;
    read($random, my $bytes, 16) == 16 or return;
    return unpack('H*', $bytes);
}

# The keeper: the second process of a page, a copy of lzrprf itself. It
# waits for one byte, lzrprf's word that the system called the application
# contained, and only then hands the answer over. After that, and while it
# hands over, it waits for one thing more: the end of lzrprf. The pipe it
# reads has its other end in lzrprf alone, so it runs dry when lzrprf ends,
# by whatever way, also when lzrprf is killed and can end nothing itself.
# Then the keeper ends the application and itself. Without it an application
# that sleeps would stay, in its container, after lzrprf was killed. While
# lzrprf lives, lzrprf ends the keeper before it lets go of the application's
# number, so the keeper never acts on a number the system gave to another
# process; after lzrprf's end it acts at once, on a number the system gives
# away only once the application has ended and been cleared away, which is
# the one moment this cannot rule out. An application that does not read
# changes nothing: the keeper never waits in a write.
# The keeper of a page kept running has one pipe more, the relay ($input),
# whose other end only lzrprf holds: what lzrprf writes there it hands on
# after the answer, in the same way, and it keeps the application's input
# open until the relay ends. It holds at most $LIVE_HELD bytes that are not
# handed on yet and reads no more until they are, so lzrprf, which writes
# without waiting, finds the relay full and ends the page.
sub keeper {
    my ($held, $to, $data, $page, $input) = @_;
    $SIG{PIPE} = 'IGNORE';                # an application that closes what it reads does not end its keeper
    my $over = sub { kill 'KILL', $page; POSIX::_exit(0) };
    my ($word, $go, $sent) = ('', undef, 0);
    do { $go = sysread($held, $word, 1) } until defined $go || !$!{EINTR};
    $over->() unless $go;                 # lzrprf ended, or ended this page, before the system said that the application is contained
    fcntl($to, POSIX::F_SETFL(), O_NONBLOCK) or $over->();
    while (1) {
        if ($to && $sent >= length $data && !$input) { close $to; undef $to }    # all of the answer is handed over, and of a page kept running the relay has ended: what the application reads ends here
        my ($read, $write) = ('', '');
        vec($read, fileno $held, 1) = 1;
        vec($read, fileno $input, 1) = 1 if $input && length($data) - $sent < $LIVE_HELD;
        vec($write, fileno $to, 1) = 1 if $to && $sent < length $data;
        select($read, $write, undef, undef) > 0 or next;
        if (vec($read, fileno $held, 1)) {
            my $more = sysread($held, $word, 1);
            $over->() if defined $more ? !$more : !$!{EINTR};    # nothing more to read: lzrprf is gone
        }
        if ($input && vec($read, fileno $input, 1)) {
            my $more = sysread($input, my $lines, 4096);
            if ($more) { substr($data, 0, $sent, ''); $sent = 0; $data .= $lines }    # what was handed on already is let go
            elsif (defined $more || !$!{EINTR}) { undef $input }    # lzrprf closed the relay ("=end" is in it): what is held is handed on, then the input ends
        }
        next unless $to && vec($write, fileno $to, 1);
        my $left = length($data) - $sent;
        my $took = syswrite($to, $data, $left > 65536 ? 65536 : $left, $sent);
        if (defined $took) { $sent += $took } elsif (!$!{EINTR} && !$!{EAGAIN}) { $sent = length $data }    # the application reads no more: the rest is not handed over
    }
}

# What the application may write, and nothing else: a first line that names
# the other hosts the page asks for, its =pictures, =sheets and =statement lines (sub stated), and then lines of five kinds, or a laid page.
#
#   U<kind><s><name>   a thing the application says the page is made of; <s> is + when it says its own code supports the thing and - when not; a tab and a version may follow
#   P<style><depth>    a paragraph begins: plain, heading 1 2 3, list item, quote, code, rule; how far it is set in, 0 to 9
#   T<looks><text>     text in that paragraph; one letter says bold, italic, fixed width, and coloured as a link
#   B                  a line ends
#   I<wide>x<high>     a grey box where a picture would stand, 8 to 640 wide and 8 to 480 high
#
# None of the five can carry an address to fetch, a program, a picture or a
# command: a link is a colour, a picture is a size. A list with any other
# line in it is not drawn at all. The lines of the first kind stand before
# every other, at most 120 of them: one of eight letters for the kind
# (document, CSS, JavaScript, libraries, media and formats, web APIs,
# security and transport, metadata), a + or a - for whether the application
# says its own code supports the thing, a name of 1 to 60 plain characters,
# and after a tab a version of 1 to 30, neither with a space at either end.
# They come in the order of the kinds and by name within a kind, and no name
# twice in a kind, so a list has one form only. They are what the
# application says, of the page and of itself: lzrprf checks their form, not
# whether they are true, and the window shows them as text in a pane of
# their own under the page.
# Or, after the first kind, a laid page: one line L and then rectangles, runs
# of text, grey boxes and pictures where the application laid them out (see
# "sub laid"). A picture or a tile there is pixels, checked to be exactly as
# many bytes as it says; it carries no address and no command either.
# In the text, every character that would
# act on the display instead of being displayed (a control code, an invisible
# mark, a mark that turns the reading direction) is replaced by the
# replacement mark before the window is given it.                        # [C9]
# What the window is spared. The window lays text out with the system's own
# code, and that code is not linear: measured on the real window, unseen, one
# block of 100,000 characters outside the first font (an emoji, Devanagari,
# Arabic) kept it busy for more than a minute, and so did one letter under
# 20,000 marks, one chain of 10,000 letters joined by a joining sign, and
# words of 20,000 Devanagari letters. A list of 200,000 lines took 17
# seconds. So a page may hold $PIECES lines and $PAGE_BYTES bytes and a block
# $BLOCK characters as the application wrote them: more is not a page. And
# two things are changed in a text, as a control character in it is changed.
# No more than $HUNG characters in a row hang on the one before them: the next
# one becomes U+FFFD, which nothing joins, and the row begins again. What
# hangs is what Unicode joins to the character before it (a mark, a character
# that extends a cluster or is spaced like a mark, a Hangul vowel or final, a
# Hangul initial after another), what follows a character that comes before
# its letter, and what follows a sign that joins two letters into one (and a
# mark after that sign), which Unicode 13, the version this Perl knows, does
# not join and the system does. And no more than $WORD characters stand in a
# row with no place where a line may end: there lzrprf puts in a space of no
# width (U+200B), which shows nothing and lets a line end. A no-break space
# is no such place. The application cannot write U+200B itself, it is one of
# those replaced above. It is put after all the characters that hang on the
# last one; a word that ends in them keeps them, so no mark is parted from
# its letter and no joined letter from its sign. Both are counted over the end
# of a line of text, because the window sets one line after the other. A text
# you copy out of the window holds those spaces. selftest draws the heaviest
# pages of each kind that was measured slow in the real window and takes the
# time; that is a measurement, and a text of a kind nobody tried may be slow.
sub unhung {                              # (the row the text before ended with, and the character before it; a line of text): the line with no row longer than $HUNG, and the row it ends with
    my ($row, $line) = @_;
    my $both = $row . substr($line, 2);
    $both =~ s/((?:$HANGS){$HUNG})$HANGS/$1\x{fffd}/g;
    my ($ends) = (length($both) > $HUNG + 3 ? substr($both, -$HUNG - 3) : $both) =~ /(.(?:$HANGS)*|(?:$HANGS)*)\z/s;    # with the character before the row: whether the next one hangs can depend on it
    return (substr($line, 0, 2) . substr($both, length $row), $ends);
}

sub parted {                              # (how many characters the word before the line has, and its last two; a line of text): the line with no word longer than $WORD, and the same of its last word
    my ($had, $tail, $line) = @_;
    my $both = 'x' x ($had - length $tail) . $tail . substr($line, 2);    # the last two as they are: whether a character hangs can depend on them
    $both =~ s/(?:\G|(?<!$SOLID))((?:$SOLID){$WORD}(?:$HANGS){0,$HUNG})(?!$HANGS)(?=$SOLID)/$1\x{200b}/g if length($both) > $WORD;    # only from the beginning of a word or the last space put in, so every word is read once
    my ($ends) = reverse(length($both) > $WORD + $HUNG ? substr($both, -$WORD - $HUNG) : $both) =~ /^($SOLID*)/;    # read from the end: a search for the last word from the front would try every place
    my $word = length($ends) < $WORD ? length $ends : $WORD;    # a word that ended in what hangs may be longer: counted as $WORD, so a space put in later is never put into the stand-in above
    return (substr($line, 0, 2) . substr($both, $had), $word, $word < 2 ? substr($both, -$word, $word) : substr($both, -2));
}

sub checked {
    my ($wrote) = @_;
    no warnings 'utf8';
    undef $LAID_TALLY;                    # said again by sub laid, for a laid list alone
    @FONTS_NAMED = ();                    # [C30] said again below, by a run that names web fonts
    return unless utf8::decode($wrote) && $wrote =~ s/\n\z//;
    my ($first, @lines) = split /\n/, $wrote, -1;
    return unless defined $first && $first =~ /^=page((?: $NAME){0,200})$/ && @lines <= $PIECES;
    my @hosts = split ' ', $1;
    $TITLED = '';
    if (@lines && $lines[0] =~ /^=title/) {    # the page's title, shown in its tab and nowhere else: one line of 1 to $TITLE characters; what would act on the display instead of being shown is taken out
        my ($title) = shift(@lines) =~ /^=title (.{1,$TITLE})\z/s or return;
        $title =~ s/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]//g;
        $title =~ s/^[ \p{M}]+| +$//g;    # and a mark with no letter before it, which would hang on the tab's own drawing
        utf8::encode($title);
        $TITLED = $title;
    }
    my @paths;
    if (@lines && $lines[0] =~ /^=pictures/) {    # the pictures the page names: on its own host by path alone, on another host as https://, a host by name and a path [C9]; how many other sites are asked, and what each address may be, is held where it is fetched (sub pictured)
        return unless shift(@lines) =~ m{^=pictures((?: (?:https://$NAME)?/[A-Za-z0-9._~/%?=&,-]{0,511}){1,$PICTURES})$};
        @paths = split ' ', $1;
    }
    my @videos;
    if (@lines && $lines[0] =~ /^=videos/) {    # [C22] the MP4 files the page names, written as its pictures are and held to the same checks where one is fetched, only when you click it (sub videoed)
        return unless shift(@lines) =~ m{^=videos((?: (?:https://$NAME)?/[A-Za-z0-9._~/%?=&,-]{0,511}){1,$VIDEOS})$};
        @videos = split ' ', $1;
    }
    my @sheets;
    if (@lines && $lines[0] =~ /^=sheets/) {    # [C14] the style sheets the page names on its own host, by path alone, as its pictures are
        return unless shift(@lines) =~ m{^=sheets((?: /[A-Za-z0-9._~/%?=&-]{0,511}){1,$SHEETS})$};
        @sheets = split ' ', $1;
    }
    if (@lines && $lines[0] =~ /^=webfonts/) {    # [C30] the web font files the page's style names on its own host, by path alone, as its sheets are: a run handed its sheets writes it, or a first run of a page that names no sheet, from its own <style>
        my $path = qr{/[A-Za-z0-9._~/%?=&-]{0,511}};
        return unless shift(@lines) =~ m{^=webfonts((?: $path(?:\|$path){0,@{[$FONT_TRIES - 1]}}){1,$FONTS})$};    # each font its paths in order, joined by |
        @FONTS_NAMED = split ' ', $1;
    }
    my ($said, $boxes, $made, $block, $row, $word, $tail, $before, $begun) = ((stated(\@lines) // return), 0, 0, 0, '', 0, '');    # the words of the one =statement line, '' for none; a malformed one makes the page unfit
    for (@lines) {
        if (!$begun && /^U([dcjlmasx])[+-]([\x21-\x7e](?:[\x20-\x7e]{0,58}[\x21-\x7e])?)(?:\t[\x21-\x7e](?:[\x20-\x7e]{0,28}[\x21-\x7e])?)?$/) {    # only plain characters, so nothing in such a line acts on the display
            my $key = index('dcjlmasx', $1) . $2;
            return unless ++$made <= $MADE && (!defined $before || $before lt $key);    # in the one order there is, and none twice
            $before = $key;
            next;
        }
        return laid(\@lines, \@hosts, $made, \@paths, $said, \@sheets, \@videos) if !$begun++ && /^L/;    # from the first line of another kind on, a line that begins with U is no line at all; and that first line says whether the page is laid
        if (/^T[\@-O]./s) {
            s/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]/\x{fffd}/g;    # the last: a number above every character there is, which Perl would pass on and the window could not read
            return unless ($block += length($_) - 2) <= $BLOCK;    # counted as the application wrote it, before anything is put in below
            ($_, $row) = unhung($row, $_) if $row ne '' || /$HANGS/;
            ($_, $word, $tail) = parted($word, $tail, $_);
            next;
        }
        ($row, $word, $tail) = ('', 0, '');   # a row of hanging characters and a word end with the text they are in: at a break, a box, a new block
        if (/^I([0-9]{1,3})x([0-9]{1,3})$/) { return unless $1 >= 8 && $1 <= 640 && $2 >= 8 && $2 <= 480 && ++$boxes <= $BOXES && ($block += $BOX) <= $BLOCK }
        elsif ($_ eq 'B') { return unless ++$block <= $BLOCK }
        else { return unless /^P[p123lqcr][0-9]$/; $block = 0 }
    }
    utf8::encode($_) for @lines;
    return (\@lines, \@hosts, \@paths, $said, \@sheets, \@videos);
}

# A laid page. The application has laid the page out itself and says where
# everything stands, in CSS pixels, on a page of a width and a height it
# names in one line L<width>x<height> right after what the page is made of.
# Then, in the order they are painted:
#
#   R<x>,<y>,<w>,<h>,<rrggbbaa>             a filled rectangle in that colour
#   X<x>,<y>,<size>,<looks>,<rrggbb>,<text> a run of text whose baseline begins at x,y; <looks> as in T
#   G<x>,<y>,<w>,<h>                        a grey box where a picture would stand
#   M<x>,<y>,<w>,<h>,<pw>,<ph>              a picture of pw by ph pixels shown in that box, given by
#   m<base64>                               exactly ph lines after it, one row each: pw times four
#                                           bytes, red, green, blue and how opaque, as pixels already
#   I<x>,<y>,<w>,<h>,<n>                    the picture of the nth path in =pictures (from 0), scaled
#                                           into that box; lzrprf fetches it and gives the window an M
#                                           in its place, or a G when there is no picture (sub pictured)
#   K<n>,<x>,<y>,<w>,<h>                    tile n, 0 to 31, each once, at a corner of the grid of 256: w and h are
#                                           256, or what is left of the page there; exactly h lines follow, one row
#   n<base64>                               each: w times three bytes, red, green and blue, with no "=" at the end;
#                                           a tile is opaque, the application paints white under everything
#   n                                       a bare n: the row above it in the same tile again, never a tile's first
#                                           row; on a page measured 58% of the rows were one (release 83)
#   J<n>,<x>,<y>                            tile n of a K above, placed again at a corner where it is cut the same
#   V<x>,<y>,<w>,<h>,<k>                    the place of the kth video in =videos (from 0), at most 8: the window
#                                           draws a play mark of its own over what was drawn there before (its
#                                           poster, an I, or grey); nothing of the video is fetched until you
#                                           click it there, and then lzrprf fetches it (sub videoed)
#
# Numbers are written in one way only, without a sign or a 0 in front, and
# everything stands inside the page. A page is laid or flowing, never both.
# A run of text gets the changes a text gets: a control or format character
# becomes U+FFFD, and so does the 31st character in a row that hangs on the
# one before it, counted in that run alone, since each run is set by itself.
# No space of no width is put in: a run is drawn on one line, where no line
# ends, and it is 2000 characters at most, a tenth of the word that was
# measured slow. A picture is bytes and no file: the window has no decoder
# to give it a picture to, it puts the bytes into the pixels as they are. A row of a
# tile is not decoded here: w times three bytes are exactly 4w characters of
# base64 with no "=", and every text of that alphabet and that length is the
# one form of its bytes, so its length and its alphabet are its whole check.
# A bare n is checked by where it stands: below a row of its own tile that was
# checked, which it repeats, so the window never reads a row nobody checked.
my $N = qr/(0|[1-9][0-9]{0,5})/;          # a number in its one form
sub laid {
    my ($lines, $hosts, $from, $paths, $said, $sheets, $videos) = @_;
    no warnings 'utf8';
    my ($wide, $high) = $lines->[$from] =~ /^L${N}x$N$/ or return;
    return unless defined $LAID_WIDE && $wide == $LAID_WIDE && $high >= 1 && $high <= 200_000;    # laid at the width its =view frame asked for, and at no other
    my $state = { wide => $wide, high => $high, text => 0, pixels => 0, rows => 0, row_bytes => 0, row_chars => 0, above => 0, rounded => 0, count => {}, tile => {} };
    laid_run($lines, $from + 1, $#$lines, $state, $paths, $videos) or return;
    return if $state->{rows} || $state->{rounded};    # a picture with rows missing, or a rounded edge with no picture after it
    $LAID_TALLY = $state;                 # what the list holds, for a splice of it checked by itself (sub live_patched)
    utf8::encode($_) for @$lines;
    return ($lines, $hosts, $paths, $said, $sheets, $videos);
}

sub laid_run {                            # the lines $first to $last of a laid list, checked in order from where $state says the list stands, and $state brought to after them; X lines are put in their shown form in place
    my ($lines, $first, $last, $state, $paths, $videos) = @_;
    no warnings 'utf8';
    my ($wide, $high, $text, $pixels, $rows, $row_bytes, $row_chars, $above, $count, $tile, $rounded) = @$state{qw(wide high text pixels rows row_bytes row_chars above count tile rounded)};    # $row_chars: how long a row of the tile above is, 0 under a picture; $above: whether a row of that tile was checked above the next
    my %count = %$count;
    my %tile = %$tile;
    my $inside = sub { my ($x, $y, $w, $h) = @_; return $w >= 1 && $h >= 1 && $x + $w <= $wide && $y + $h <= $high };
    my $cut = sub { my ($x, $y) = @_; return $x % 256 || $y % 256 || $x >= $wide || $y >= $high ? '' : ($wide - $x < 256 ? $wide - $x : 256) . ',' . ($high - $y < 256 ? $high - $y : 256) };    # the one size a tile has at a corner of the grid, or '' for no corner
    for (@$lines[$first .. $last]) {
        if ($rows) {                      # a row of the picture or the tile above: in base64, exactly as long as it is wide
            if ($row_chars) { return unless $_ eq 'n' ? $above : length($_) == $row_chars && /\An[A-Za-z0-9+\/]+\z/; $above = 1 }    # a tile's row n, never m; a bare n only below a row it repeats
            else {                        # a picture's row m, never n
                my ($code) = /^m([A-Za-z0-9+\/]+={0,2})$/ or return;
                my $bytes = decode_base64($code);
                return unless length($bytes) == $row_bytes && encode_base64($bytes, '') eq $code;    # written back the same: one form only, no byte more or less
            }
            $rows--;
            next;
        }
        my ($kind) = /^([RXGMIKJVQ])/ or return;
        return if $rounded && $kind ne 'I'; $rounded = 0;    # a rounded edge Q is said of the fetched picture on the next line, and of nothing else
        return unless ++$count{$kind} <= $LAID{$kind};
        if ($kind eq 'R') { return unless /^R$N,$N,$N,$N,[0-9a-f]{8}$/ && $inside->($1, $2, $3, $4) }
        elsif ($kind eq 'Q') { return unless /^Q$N,$N,$N,$N((?:,[0-9]{1,5}){8})$/ && $3 >= 1 && $4 >= 1 && $1 + $3 <= 200000 && $2 + $4 <= 200000 && !grep { $_ > 20000 } split /,/, substr($5, 1); $rounded = 1 }    # its rounded edge: a box and the eight radii of its corners, px
        elsif ($kind eq 'G') { return unless /^G$N,$N,$N,$N$/ && $inside->($1, $2, $3, $4) }
        elsif ($kind eq 'V') { return unless /^V$N,$N,$N,$N,$N$/ && $inside->($1, $2, $3, $4) && $5 < @$videos }
        elsif ($kind eq 'I') { return unless /^I$N,$N,$N,$N,$N(?:,([1-4]),$N,$N,$N,$N)?$/ && $inside->($1, $2, $3, $4) && $5 < @$paths && (!defined $6 || 4 == grep { $_ >= 1 && $_ <= 199999 } $7, $8, $9, $10) }    # a fit and a position (sub fit_crop)
        elsif ($kind eq 'M') {
            return unless /^M$N,$N,$N,$N,$N,$N(?:,$N,$N,$N,$N)?$/ && $inside->($1, $2, $3, $4) && $5 >= 1 && $5 <= 1024 && $6 >= 1 && $6 <= 1024 && ($pixels += $5 * $6) <= $PIXELS;
            return if defined $7 && ($9 < 1 || $10 < 1 || $7 + $9 > 100 * $5 || $8 + $10 > 100 * $6);    # the part of the picture a fit draws lies in it
            ($rows, $row_bytes, $row_chars) = ($6, $5 * 4, 0);
        } elsif ($kind eq 'K') { return unless /^K$N,$N,$N,$N,$N(,2)?$/ && $1 < $LAID{K} && !exists $tile{$1} && ($tile{$1} = $cut->($2, $3)) eq "$4,$5"; my $s = $6 ? 2 : 1; ($rows, $row_chars, $above) = ($5 * $s, 1 + 4 * $4 * $s, 0) }    # a tile is not counted in $PIXELS: 32 at most is its bound
        elsif ($kind eq 'J') { return unless /^J$N,$N,$N$/ && defined $tile{$1} && $tile{$1} eq $cut->($2, $3) }
        else {
            my ($head, $x, $y, $size, $chars) = /^(X$N,$N,$N,[\@-O],[0-9a-f]{6},)(.{1,$RUN_TEXT})\z/s or return;
            return unless $x < $wide && $y <= $high && $size >= 6 && $size <= 96 && ($text += length $chars) <= $ALL_TEXT;
            $chars =~ s/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]/\x{fffd}/g if $chars =~ /[^\x20-\x7e]/;    # as in T; printable ASCII is never replaced, so it is not searched
            $chars = substr((unhung('', "  $chars"))[0], 2) if $chars =~ /[^\x20-\x7e]/ && $chars =~ /$HANGS/;    # no printable ASCII character hangs
            $_ = $head . $chars;
        }
    }
    @$state{qw(text pixels rows row_bytes row_chars above count tile rounded)} = ($text, $pixels, $rows, $row_bytes, $row_chars, $above, \%count, \%tile, $rounded);
    return 1;
}


# LZRDFNDR's Redirects [C4]: every redirect lzrprf put to you in this window, with what you answered,
# grouped under the site that redirected. A decision changed there, "proceed always" or "cancel always",
# answers that same redirect (the same address to the same address) for you from then on, in this window;
# Forget takes it away, and the redirect is asked about again. Nothing of it is written.
sub redirect_noted {                      # [C4] a redirect about to be put to you, kept as "pending"; returns 2 when your kept decision proceeds (and it can be followed), 1 when it cancels, 0 when you are asked
    my ($url, $to, $status, $fit) = @_;
    my $key = "$url\t" . ($to // '');
    my $one = $REDIRECTS{$key};
    return $one->{decision} eq 'proceed always' && $fit ? 2 : 1 if $one && $one->{decision} =~ /always\z/;
    if ($one && delete $one->{once}) { return $one->{decision} eq 'proceeded' && $fit ? 2 : 1 }
    if (!$one && keys %REDIRECTS >= $REDIRECTS_MOST) { my ($oldest) = sort { $REDIRECTS{$a}{n} <=> $REDIRECTS{$b}{n} } keys %REDIRECTS; delete $REDIRECTS{$oldest} }
    my ($host) = $url =~ m{\Ahttps://([^/?#:]+)};
    $REDIRECTS{$key} = { site => 'https://' . lc($host // ''), status => $status, from => $url, to => $to // '', fit => $fit ? 1 : 0, decision => 'pending', n => ++$REDIRECTS_SEEN };
    return 0;
}

sub redirect_answered {
    my ($url, $to, $press, $went) = @_;
    my $one = $REDIRECTS{"$url\t" . ($to // '')} or return;
    if ($press == 5) { $one->{decision} = 'pending'; return }
    $one->{decision} = $press == 3 && $went ? 'proceed always' : $press == 4 ? 'cancel always' : $went ? 'proceeded' : 'cancelled';
}

sub redirects_listed {                    # [C4] the redirects of LZRDFNDR's Redirects, each site's together, in the order of their site and address: their keys, and the lines that tell them
    my @keys = sort { $REDIRECTS{$a}{site} cmp $REDIRECTS{$b}{site} || $a cmp $b } keys %REDIRECTS;
    my ($n, $was, @lines) = (0, '');
    for my $key (@keys) {
        my $one = $REDIRECTS{$key};
        push @lines, "redirects site $one->{site}" if $one->{site} ne $was;
        $was = $one->{site};
        push @lines, 'redirects one ' . join("\t", $n++, $one->{site}, $one->{status}, $one->{from}, $one->{to}, $one->{decision}, $one->{fit});
    }
    return \@keys, \@lines;
}

my @REDIRECT_WEB_KEYS;
sub redirects_told { my ($keys, $lines) = redirects_listed(); @REDIRECT_WEB_KEYS = @$keys; window('redirects begin', map({ unlisted($_) } @$lines), 'redirects end') }    # [C4] [C23] "redirects begin", "redirects site SITE", "redirects one N<tab>SITE<tab>STATUS<tab>FROM<tab>TO<tab>DECISION<tab>FIT" for each, "redirects end"

sub redirects_decide {                    # [C4] a decision changed in LZRDFNDR's Redirects, for the redirect numbered $n as redirects_told last numbered it: "proceed" or "cancel" keeps it as always, "forget" takes it away
    my ($n, $to) = @_;
    my $key = $REDIRECT_WEB_KEYS[$n];
    my $words = 'Nothing was changed: that redirect is no longer in the list.';
    if (defined $key && exists $REDIRECTS{$key}) {
        my $one = $REDIRECTS{$key};
        if ($to eq 'forget') { delete $REDIRECTS{$key}; $words = "No decision is kept for the redirect of $one->{from}: it is asked about again." }
        elsif (($to eq 'proceed' || $to eq 'allow-once') && !$one->{fit}) { $words = "The redirect of $one->{from} cannot be followed, so its decision stays unchanged." }
        else {
            delete $one->{once};
            $one->{once} = 1 if $to =~ /-once\z/;
            $one->{decision} = $to eq 'allow-once' ? 'proceeded' : $to eq 'deny-once' ? 'cancelled' : "$to always";
            $words = "The redirect of $one->{from} is now answered $to in this window.";
        }
        noted('LZRDFNDR Redirects: ' . unlisted($words));
    }
    redirects_told();
    return idle(unlisted($words));
}
