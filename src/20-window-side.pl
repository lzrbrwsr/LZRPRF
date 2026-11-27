# The window's side. The window is lzrprf's: the text at the end of this file,
# run by the system's own osascript in the window container. It is told what
# to show in lines, and says what you did in lines. Ten kinds of line can come
# from it, each in a shape lzrprf checks, and nothing the application wrote is
# among them: that it is ready, what you typed into the bar when you pressed
# Return, which of two buttons you pressed, that you asked for the log, that
# it could not draw a list, the size of its page, a tab opened, chosen or
# closed or moved ("tab new", "tab select N", "tab close N", "tab move FROM TO"), and an item of the
# cogwheel's menu ("menu clear-history", "menu clear-sessions", "menu home", "menu bookmarks-bar"), a bookmark opened, saved or removed ("mark open N", "mark save ...", "mark remove N", sub mark_saved), its size and place once you have moved or resized it ("frame X Y W H" or "frame full", sub frame_said), and buttons up to three for a question in a modal ("redirect"). More come only while the page shown is kept running ("live on"): a click in it ("page click X Y", in the laid page's points after scrolling; on a site's page "page down X Y" and "page up X Y" in its place), the pointer moved over it ("page move X Y", at most once a frame) or out of it ("page out"), its shape asked back as "cursor T NAME" (28-window-pointer.pl), a key ("page key NAME" or "page key NAME shift", a printable character or one of the named keys), text typed while a field of it has the focus ("page text ...", at most $LIVE_TEXT bytes) and where it shows the page from ("page scroll T X Y", T the tab shown, whole CSS pixels of the laid page, at most once a frame); lzrprf hands each to that page and to nothing else (sub live_input), and tells the window "live on|off 0|1" and "live end WHY" (sub live_told), and "scroll T X Y" where the page's script scrolled it, just before its drawing (sub live_scroll_told). In a terminal's tab five more: "page drag X Y", "page wheel N", "page copy", and your paste as "page paste TEXT" or "page pastelong" (sub trmnl_viewed), a right press "page context X Y", an item of its menus "page menu ID" and one of its own keys "page tkey ID" (sub trmnl_pressed) [C29]. The words lzrprf says are in a
# strip of their own between the bar and the page, where no page can write:
# the one thing of the application's that lzrprf says there is up to four of
# the other hosts its page names, each in the shape of a host name, and how
# many there are (the last line of "sub visit").
sub window {                              # all the lines in one write: a list of thousands of lines printed one by one (autoflush) woke the window once a line, and a page took 100 ms to arrive (measured 2026-11-23)
    $WINDOW_LISTS++ if @_ && $_[0] =~ /^(?:page|relaid|patch|runs|tabs?)\b/;
    print join('', map { "$_\n" } (@_ && $_[0] =~ /^(?:page|relaid|patch|runs)\b/ ? named_owed(@_) : ()), @_) or leave() if @_;    # without a window ("lzrprf try" only) this is printed for the test to read
    sound_hushed() if $SOUND && @_ && $_[0] =~ /^(?:tabs |page(?: [0-9]+)?\z|live (?!on ))/;    # [C12] another tab, a new page shown, or no page kept running: every sound stops and goes
    timed('sent ' . ($_[0] =~ /^(\S+)/ ? $1 : '')) if $TIMED && @_;    # "lzrprf try" with "times": the moment the window was handed each write, by its first word
}

# The strip as it is now, to put back. The window takes a press only after lzrprf said "idle": a line
# "busy", and a question once it is answered, leave it closed to every press. So whatever speaks in the
# strip beside a page (the look for a newer release) ends by putting the strip back, on every way out.
sub strip_back {                          # what the strip said, said again: with a sentence of the page's own given, that sentence in the strip and after the words in full (a video that is locked, sub videoed)
    my ($was, $short) = @{ $TABS[$TAB] }{qw(says brief)};
    return sub { defined $_[0] ? idle(index($was // '', $_[0]) >= 0 ? $was : join(' ', grep { length } $was // '', $_[0]), $_[0]) : idle($was // '', $short); return };    # a sentence the words already end with, a locked video clicked again, is not said twice
}
sub busy { window('busy ' . $_[0] =~ s/\s+/ /gr) }
sub idle {                                # what lzrprf says, in full; with $short the strip shows that instead ("brief"), and the full words stand where they belong: with what the page is made of, or on the log page
    my ($says, $short) = map { defined ? s/\s+/ /gr : undef } @_[0, 1];
    @{ $TABS[$TAB] }{qw(says brief)} = ($says, $short);
    window("brief $short") if length($short // '');
    window("idle $says");
    return;
}
sub aside {                               # said in full, with the strip left as it was: an answer that belongs elsewhere than the strip
    my ($says, $shut) = @_;
    my ($was, $short) = @{ $TABS[$TAB] }{qw(says brief)};
    window('log shut') if $shut;
    idle($says, length($short // '') ? $short : $was // '');
    @{ $TABS[$TAB] }{qw(says brief)} = ($was, $short);
    return;
}
sub noted { push @SESSION, line(unlisted($_[0])); return }    # [C23] a line of this window's log alone, in its memory, that names no listed address
sub said_noted { my $says = $TABS[$TAB]{says}; noted($says) if length($says // ''); return }    # what the strip just said of something you did that fetched nothing: a bookmark, a setting, a window    # a line of this window's log alone, in its memory: what happened here and fetched nothing

# The =statement line of a page, which comes right after its =pictures and
# =sheets lines (or its first line): the application's own words, in one sentence, for why it
# shows the page in compatibility-statement mode. At most one such line, of
# 1 to $STATEMENT bytes that are each a plain printable character (0x20 to
# 0x7e), so nothing in it acts on the window; a second one is a line of no kind
# and makes the page unfit, as does one too long or with any other byte. The
# words are shown as they are, as plain text, at the end of the bottom bar
# (sub visit); they are never read for anything. Takes the checked page's
# lines and takes the line off them. Returns its words, '' when there is none,
# or nothing for a line that is not one.
sub stated {
    my ($lines) = @_;
    my $STATEMENT = 200;                  # the most bytes of the words: one sentence the bottom bar holds beside its own
    return '' unless @$lines && $lines->[0] =~ /^=statement/;
    my ($words) = shift(@$lines) =~ /^=statement ([\x20-\x7e]{1,$STATEMENT})\z/ or return;
    return $words;
}

sub hear {                                # the next thing the window says; nothing (undef) when the window is gone, an empty line when it said nothing in time
    my ($seconds, $main) = @_;            # $main: the loop of sub behind, the one place that takes "live", the word that a page kept running answered or is to end (sub live_turn); elsewhere what such a page writes is read and held, and taken there later
    push @HELD, splice @LATER if $main && @LATER;
    return shift @HELD if @HELD;
    my $until = defined $seconds ? now() + $seconds : undef;
    while (1) {
        return 'live' if $main && grep { live_due($_) || (live_scroll_left($_) // 1) <= 0 || (live_home_left($_) // 1) <= 0 } @LIVE;    # or a place of its own scroll waited for the frame to be over (sub live_scroll_told)
        if ($main && !$FROM && @EVENTS && $EVENTS[0] eq 'idle') { shift @EVENTS; my $work = idle_taken(); $work->(), timed('idle-work') if $work; next }    # "lzrprf try": the test's line "=idle" stands for a window that waits for you, as a real one does before you type (scripts/snappy.pl)
        if (!$FROM && @EVENTS && $EVENTS[0] =~ /\Apause ([1-9][0-9]{0,3})\z/) { shift @EVENTS; select undef, undef, undef, $1 / 1000; next }    # "lzrprf try": the test's line "=pause MS" stands for a person who looks at the page that long before the next line (scripts/snappy.pl)
        return substr(shift @EVENTS, 1) if !$FROM && @EVENTS && substr($EVENTS[0], 0, 1) eq '~';    # "lzrprf try": a test's line marked "~" is said at once, while a page kept running has not answered yet, as a window says it whenever it likes
        return shift @EVENTS unless $FROM || $main && (grep { $_->{waiting} } @LIVE) || $main && !@EVENTS && grep { now() < $_->{heard} + $TRY_QUIET } @LIVE;    # "lzrprf try": the test's next line, once every page kept running answered the one before; after the last, the end once every such page was quiet for $TRY_QUIET
        if ($FROM && (my $end = index($FROM_HELD, "\n")) >= 0) {
            my $line = substr($FROM_HELD, 0, $end + 1, '');
            chomp $line;
            print STDERR "$line\n" if $TRY && $line =~ /^(?:test|fault) /;    # "lzrprf try" only: what a test's own text in the window reports
            if ($line =~ /^undrawn ([a-z]{1,20}) ([\x20-\x7e]{0,200})$/) { record("the window could not finish drawing its $1 view this once, and goes on: $2"); next }    # said by function viewDrawn in the window, the first fault of each view once: kept in the log wherever lzrprf listens, in the loop of sub behind, in a question or after an install
            return $line;
        }
        my ($ready, $writable, $wait) = ('', '', defined $until ? $until - now() : undef);
        for my $live (grep { $_->{kept_app} && keys %{ $_->{kept_app}{sockets} } } @LIVE) {
            ws_pump($live);
            $wait = 0.2 if !defined $wait || $wait > 0.2;
        }
        for my $live (@LIVE) { vec($writable, fileno $live->{relay}, 1) = 1 if length($live->{input_held} // '') }
        return '' if defined $wait && $wait <= 0;    # the time is over, and the window is still there
        vec($ready, fileno $FROM, 1) = 1 if $FROM;
        if ($SOUND) { vec($ready, fileno $SOUND->{from}, 1) = 1; vec($writable, fileno $SOUND->{to}, 1) = 1 if length $SOUND->{out} }    # [C12] the sound process: what it says, and what waits for it
        for my $live (grep { !live_due($_) } @LIVE) {    # a page kept running is heard while the window is waited for, up to its own end of time
            vec($ready, fileno $live->{from}, 1) = 1;
            my ($left, $quiet) = ($live->{until} - now(), $live->{heard} + $TRY_QUIET - now());
            $left = $quiet if !$FROM && $quiet > 0 && $quiet < $left;    # "lzrprf try": up to the end of its quiet, when the test is looked at again
            $wait = $left < 0 ? 0 : $left if !defined $wait || $left < $wait;
            my $frame = $main ? live_scroll_left($live) : undef;    # up to the end of the frame a place of its own scroll waits for
            $wait = $frame if defined $frame && $frame < $wait;
            my $home = $main ? live_home_left($live) : undef;    # T3: up to when a settling home is said ready
            $wait = $home if defined $home && $home < $wait;
        }
        trmnl_select(\$ready, \$writable);    # [C29] each terminal's shell and container, heard as the window is
        cht_select(\$ready, \$writable);    # [C32] each LZRCHT's roles and connections
        if ($main && $FROM && ($IDLE_WORK || defined $SPARE_WANTED || $CURL_WANTED) && !length($FROM_HELD) && $writable !~ /[^\0]/ && !grep({ $_->{starting} } @LIVE) && select(my $now = $ready, undef, undef, 0) == 0) { my $work = idle_taken(); $work->() if $work; timed('idle-work'); next }    # once: nothing said, nothing to write and no page being made, so nothing waits for it
        prefetch_select(\$ready);         # [C19] the scripts begun ahead are read as they come (17-prefetch.pl)
        select($ready, $writable, undef, $wait) > 0 or next;
        prefetch_heard($ready);
        trmnl_heard($ready, $writable);
        cht_heard($ready, $writable);
        live_flushed($_) for grep { length($_->{input_held} // '') && vec($writable, fileno $_->{relay}, 1) } @LIVE;
        live_read($_) for grep { !live_due($_) && vec($ready, fileno $_->{from}, 1) } @LIVE;
        sound_flushed() if $SOUND && length $SOUND->{out} && vec($writable, fileno $SOUND->{to}, 1);
        sound_heard() if $SOUND && vec($ready, fileno $SOUND->{from}, 1);
        next unless $FROM && vec($ready, fileno $FROM, 1);
        my $got = sysread($FROM, $FROM_HELD, 65536, length $FROM_HELD);
        return if defined $got ? !$got : !$!{EINTR};    # the window is gone
    }
}

sub window_changed {                      # the window holds the list $old of the tab shown, and $new is to stand there: only what changed is sent. One stretch as "patch TAB FIRST DROP" and its lines; several as "runs TAB K", K lines "FIRST DROP COUNT" in the order of the list (places in $old), then the lines of them all; the whole list ("relaid") when little would be saved or there is no list to go from. yle.fi's list is 7100 lines and 1.5 MB, and it was sent whole twice more while the page loaded (measured in the staging browser, 2026-11-25)
    my ($old, $new) = @_;
    my ($first, $last, @runs) = (0, 0);
    return window("relaid $TAB", @$new, '.') unless $old;
    $first++ while $first < @$old && $first < @$new && $old->[$first] eq $new->[$first];
    $last++ while $last < @$old - $first && $last < @$new - $first && $old->[$#$old - $last] eq $new->[$#$new - $last];
    my $saved = 0; $saved += length($new->[$_]) + 1 for 0 .. $first - 1, @$new - $last .. $#$new;
    my ($end_old, $end_new) = (@$old - $last, @$new - $last);    # the middle that differs: $first up to these
    my $middle = 0; $middle += length($new->[$_]) + 1 for $first .. $end_new - 1;
    if ($middle > 4096 && $end_old > $first) {    # a long middle: the lines of it that stand in both are found, each stretch between them a run
        my %at; push @{ $at{$new->[$_]} }, $_ for $first .. $end_new - 1;
        my ($i, $j, $same) = ($first, $first, 0);
        while (($i < $end_old || $j < $end_new) && @runs <= 64) {
            if ($i < $end_old && $j < $end_new && $old->[$i] eq $new->[$j]) { $same += length($new->[$j]) + 1; $i++; $j++; next }
            my ($to_old, $to_new) = ($end_old, $end_new);
            FIND: for my $k ($i .. ($i + 64 < $end_old ? $i + 64 : $end_old) - 1) {    # the next line of the old list that stands in the new one with the line after it: there the two go on alike
                my $places = $at{$old->[$k]} or next;
                shift @$places while @$places && $places->[0] < $j;
                for my $p (@$places[0 .. ($#$places < 7 ? $#$places : 7)]) {
                    next unless $k + 1 < $end_old && $p + 1 < $end_new ? $old->[$k + 1] eq $new->[$p + 1] : $k + 1 == $end_old && $p + 1 == $end_new;
                    ($to_old, $to_new) = ($k, $p);
                    last FIND;
                }
            }
            push @runs, [$i, $to_old - $i, $j, $to_new - $j];
            ($i, $j) = ($to_old, $to_new);
        }
        if (@runs > 1 && @runs <= 64 && $saved + $same > 512) {
            return window("runs $TAB " . @runs, (map { "$_->[0] $_->[1] $_->[3]" } @runs), (map { @$new[$_->[2] .. $_->[2] + $_->[3] - 1] } @runs), '.');
        }
    }
    return window("patch $TAB $first " . (@$old - $first - $last), @$new[$first .. $#$new - $last], '.') if $saved > 512;
    window("relaid $TAB", @$new, '.');
}
