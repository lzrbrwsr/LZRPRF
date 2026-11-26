# A line of the window for the page kept running with the selected tab, in a
# form sub behind checked: "click X Y" in CSS pixels of the laid page, where
# the window found the pointer after its own scrolling, at most 200000 each
# way; "key NAME" or "key NAME shift"; "text TEXT", only while a text field of
# the page has the focus, of 1 to $LIVE_TEXT bytes of UTF-8 with no control
# or format character; "scroll T X Y", where the window shows the page of tab
# T from, in whole CSS pixels of the laid page, at most 200000 each way. The
# window says it after every drawing of the page shown, when the page is kept
# running ("live on") and as you scroll, at most once a frame; one for a tab
# that is not the selected one is passed over. Each page kept running is
# handed the first one it hears and then each one that differs from the last
# it was handed or told of itself (sub live_answered), so a page is told where
# it is shown once at its start and never told back its own scroll. Once
# lzrprf has sent the window a scroll of the page's own (sub
# live_scroll_told), every place the window says is passed over until it says
# that very place back: what it said before it read lzrprf's line is where it
# was, not where the page is. The window's next place after that echo, said
# within $LIVE_STOP_SECONDS of it, says where its view stopped (sub
# live_stopped): within a pixel of the page's place each way, it is where the
# page is and is not handed back; short of it by more on an axis, it is the
# window's end there: the page is handed it, and a place of the page's script
# past it on that axis is told only up to it, and not at all when the window
# shows that already, until you scroll elsewhere or click or press a key, the
# page is drawn at another height or the window's page changes size; so a
# page that scrolls past its end on every scroll is not answered once a frame,
# and a page that keeps to its bottom as it grows is still told its new bottom.
# The window is told a place of the page's own scroll at most once a frame
# ($LIVE_FRAME_SECONDS); one sooner waits, and only the newest.
# The pointer: "move X Y" where it is over the page, at most once a frame;
# "down X Y" and "up X Y" for the primary button pressed and let go there
# (a down is a press of yours for [C12]); "out" when it left the page.
# While the page has not answered a line yet, a scroll waits, and a move
# waits, only the newest of each: a page that is slow to answer is not sent a
# line for every frame, and a click, press or key after them sends them
# first, in their order.
# Each is written to the page as "=click", "=move", "=down", "=up", "=out",
# "=key", "=text" or "=scroll", at most $LIVE_INPUT bytes, and nothing else
# ever is; a tab with no page kept running takes none.
sub live_input {                          # [C18]
    my ($what) = @_;
    link_line('INFO', 'input', "the window handed lzrprf $what", what => $what, tab => $TAB, live => (live_of($TABS[$TAB]) ? 1 : 0), waiting => (live_of($TABS[$TAB]) && live_of($TABS[$TAB])->{waiting} ? 1 : 0)) if $what =~ /\A(?:click|down|up|context) /;    # [1237] the sniffer (keys and text never, they can be a password): each press that reached lzrprf, while the live debug link is on (staging-control tail shows it); a press the window dropped never appears here
    return trmnl_input($what) if $TABS[$TAB]{trmnl};    # [C29] a terminal's tab: its keys go to its shell, in their fixed forms
    my $live = live_of($TABS[$TAB]) or return;
    return if $what =~ /^(?:click|move|down|up|context|scroll [0-9]+) ([0-9]+) ([0-9]+)$/ && ($1 > 200_000 || $2 > 200_000);
    if ($what =~ /^move /) {
        if ($live->{waiting}) { $live->{move_held} = $what; return }    # the newest place of the pointer waits for the page's answer (sub live_answered), as a scroll does
        return live_wrote($live, $what);
    }
    if ($what =~ /^text (.*)\z/s) {
        my $text = $1;
        return unless $live->{focus} && utf8::decode($text) && $text !~ /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]/;
    }
    if ($what =~ /^scroll ([0-9]+) (.*)$/) {
        my ($tab, $at) = ($1, $2);
        return if $tab != $TAB;    # said of a tab the window showed before it heard lzrprf choose another
        if (defined $live->{scroll_sent}) { @$live{qw(scroll_echo scroll_echoed)} = (delete $live->{scroll_sent}, now()) if $at eq $live->{scroll_sent}; return }    # said before the window read the page's own scroll, or that scroll said back
        my ($echo, $echoed) = (delete $live->{scroll_echo}, delete $live->{scroll_echoed});
        my $stop = defined $echo && now() - $echoed <= $LIVE_STOP_SECONDS ? live_stopped($at, $echo) : undef;    # only the window's next place after its echo, and soon after it, says where its view stopped
        if ($stop && !grep { defined } @$stop) { $live->{scrolled} = $at; return }    # within a pixel of the page's own place each way: where the page is, not handed back to it
        if ($stop) { $live->{scroll_clamp} = $stop }    # the window could not show the page's place: it stopped short of it, at its own end, on these axes
        elsif ($live->{scroll_clamp} && $at ne ($live->{scrolled} // '')) { delete $live->{scroll_clamp} }    # you scrolled elsewhere: the page's places past the window's end may be told again
        return if ($live->{scrolled} // '') eq $at;    # what it was handed or told last: nothing new
        $live->{scrolled} = $at;
        if ($live->{waiting}) { $live->{scroll_held} = "scroll $at"; return }    # the newest scroll waits for the page's answer (sub live_answered)
        return live_wrote($live, "scroll $at");
    }
    delete @$live{qw(scroll_echo scroll_echoed scroll_clamp)};    # only the window's next place after its echo can say where it stopped short, and after a click or a key the page's places are told again
    live_wrote($live, delete $live->{scroll_held}) if defined $live->{scroll_held};    # a scroll that waits goes first: the lines keep their order
    live_wrote($live, delete $live->{move_held}) if defined $live->{move_held} && !$live->{ended};    # and the pointer's place that waits, so a press is where the pointer is
    return if $live->{ended};
    $live->{pressed} = now() if $what =~ /^(?:click |down |key (?!Escape(?: |\z)))/;    # [C12] a press of yours: the page may sound for $SOUND_PRESS_SECONDS after it (sub live_sound); Escape is none, as in the engine
    live_wrote($live, $what);
}

sub live_wrote {                          # [C18] preserve the order and any unwritten tail on a nonblocking relay
    my ($live, $what) = @_;
    my $line = "=$what\n";
    return unless length $line <= $LIVE_INPUT + 1;
    $live->{input_held} //= '';
    return live_end($live, 'it does not read what it is given') if length($live->{input_held}) + length($line) > 1_048_576;    # DECLARED(1 MiB of bounded pending input; an unresponsive page cannot grow the parent)
    $live->{input_held} .= $line;
    $live->{waiting}++;
    live_flushed($live);
    return;
}

sub live_flushed {                        # [C18] a short write is progress, EAGAIN waits for readiness, a closed reader ends the page
    my ($live) = @_;
    return unless length($live->{input_held} // '');
    my $took = syswrite($live->{relay}, $live->{input_held});
    if (defined $took && $took > 0) { substr($live->{input_held}, 0, $took, '') }
    elsif (defined $took || (!$!{EAGAIN} && !$!{EINTR})) { live_end($live, 'it does not read what it is given') }
}

sub live_stopped {                        # [C18] where the window's place $at stands to the page's place $wanted it said back, axis by axis: undef when it is past it either way by more than a pixel (you scrolled), else for x and y the window's place where it stopped short of the page's by more than a pixel, as a view at its end does, and undef where it is at it within a pixel
    my ($at, $wanted) = @_;
    my @at = split / /, $at;
    my @wanted = split / /, $wanted;
    my @short;
    for my $i (0, 1) {
        return undef if $at[$i] > $wanted[$i] + 1;
        push @short, $at[$i] < $wanted[$i] - 1 ? $at[$i] : undef;
    }
    return \@short;
}

sub live_scroll_told {                    # [C18] where the page's script scrolled it, to the window: just before its drawing, so the window shows the drawing from there and says nothing older; once a frame at most
    my ($live) = @_;
    return unless $live && defined $live->{scroll_unsent};
    return if now() < ($live->{scroll_told} // 0) + $LIVE_FRAME_SECONDS;    # told one a moment ago: this waits, newer ones take its place, and the loop of sub behind tells the newest once the frame is over (sub live_scroll_left)
    $live->{scroll_told} = now();
    $live->{scroll_sent} = delete $live->{scroll_unsent};
    window("scroll $TAB $live->{scroll_sent}");
}

sub live_scroll_back {                    # [C18] the line the window says when it says back the page's own scroll it was told last, of the tab shown, or '' when none is owed: kept while a question is open (sub asked)
    my $live = live_of($TABS[$TAB]);
    return $live && defined $live->{scroll_sent} ? "page scroll $TAB $live->{scroll_sent}" : '';
}

sub live_home_settling {                  # T3: a home whose answer made layers is said ready only once a frame passes with no new layer, at most $HOME_SETTLE_MOST after its first: the window showed the background grid of a scene laid over several answers
    my ($live, @layers) = @_;
    my $grew = grep { /(?:\A|;)n / } @layers;
    $live->{home_first} //= now();
    $live->{home_owed} = now() + 2 * $LIVE_FRAME_SECONDS if $grew || !$live->{home_owed};
    $live->{home_owed} = $live->{home_first} + $HOME_SETTLE_MOST if $live->{home_owed} > $live->{home_first} + $HOME_SETTLE_MOST;
}
sub live_home_left {                      # T3: seconds until a settling home is said ready, 0 when now, nothing when none waits
    my ($live) = @_;
    return undef unless $live->{home_owed} && !$live->{ended};
    my $left = $live->{home_owed} - now();
    return $left > 0 ? $left : 0;
}
sub live_home_told {                      # T3: the home's scene stopped growing; the window, if it shows it, shows it whole
    my ($live) = @_;
    delete @$live{qw(home_owed home_first)};
    return if $live->{home_ready} || $live->{tab} != $TABS[$TAB];
    $live->{home_ready} = 1;
    window('home ready');
}
sub live_scroll_left {                    # [C18] the seconds until a place of the page's own scroll that waits may be told to the window, 0 when it may be now; nothing when none waits for the window
    my ($live) = @_;
    return undef unless defined $live->{scroll_unsent} && !$live->{ended} && $DRAWN && $live->{tab} == $TABS[$TAB];
    my $left = ($live->{scroll_told} // 0) + $LIVE_FRAME_SECONDS - now();
    return $left > 0 ? $left : 0;
}

# An answer of a page kept running, up to its line "=ready", each part only
# when there is one and in this order:
#
#   =focus 1|0          a text field of the page took the focus, or none has it now: whether text typed goes to it
#   =go ADDRESS         an address the page asks to go to: a link followed, or a form sent with GET; it is
#                       checked and fetched exactly as an address typed into the bar (sub go), in the tab shown
#   =statement WORDS    1 to 200 plain printable characters, shown in lzrprf's strip as plain text
#   =scroll X Y         its script scrolled the page: the window is told "scroll T X Y" and shows the page of tab T
#                       from X, Y CSS pixels (whole, 0 to 200000), and says nothing of it back as a scroll of yours;
#                       the page writes it only once the window has said where it shows it ("=scroll" above). It goes
#                       just before the drawing of the same answer; of answers with no drawing, only the newest of
#                       one turn goes, once the page is drawn in the window. A place of the window's that waited
#                       for this answer is then dropped, as older than it; with no =scroll it is handed now
#   =layers ITEMS       what of the page the window draws as layers of its own, moved by the page frame by frame
#                       without a drawing (src/page/layers.rs): one or more lines of at most $LAYERS_LINE bytes,
#                       each item checked in its form and against the layers the page made before (sub live_layer);
#                       their bytes are not counted in $LIVE_BYTES but against a budget of their own, $LAYERS_RATE
#                       a second with $LAYERS_BURST at once (sub live_layers_paid). The window is told
#                       "layers T ITEMS" for the tab shown; a tab not shown is told nothing, and once it is shown
#                       again its page is written "=layers" and tells every layer gone and makes it again
#   =sound ID RATE FRAMES FROM TO, =samples ID BASE64, =play ID AT, =hush ID
#                       the page's sound (src/page/sound.rs), after =layers and before =again, each line checked
#                       against the sounds the page made before (sub live_sound): a sound of FRAMES samples of 16
#                       bits at RATE a second, looping from FROM to TO or played once when both are 0, its samples
#                       in base64 on the =samples lines that follow; =play sounds it from frame AT, =hush silences
#                       it. Their bytes are not counted in $LIVE_BYTES but against $SOUND_BYTES of samples in the
#                       page's life. A =play goes to the sound process (sub sound_told) only within
#                       $SOUND_PRESS_SECONDS of a click or a key lzrprf handed the page, and only for the tab shown
#                       (sub live_sounded)
#   =cursor NAME        the shape of the pointer over the page (CSS cursor), one of %CURSORS, in any place before
#                       =again: the window is told "cursor T NAME" for the tab shown; a name not among them is
#                       passed over as a line lzrprf does not know
#   =again              then the page's lines, as a first list has them after its head: checked by sub checked
#                       with the first list's =pictures paths, =videos and U lines in front, at the width it was laid at,
#                       and drawn in place of the drawing before, its decoded pictures placed again
#
# A line before =again of the form "=NAME" or "=NAME WORDS" (NAME small letters,
# digits and "-", 1 to 32; WORDS printable, at most 8192 bytes) whose NAME is
# none that lzrprf knows is passed over: so an application may add a line a
# later lzrprf reads without its pages ending under this one. Only such a part
# of one line is passed over; a part of more lines ends the page, as any line
# of no form does. The first $LIVE_UNKNOWN_NAMES such NAMEs of one page kept
# running are written in the log once each, and then one line says there were
# more; what a page counted goes with it when it ends. Anything else, a line of no
# form, a known part out of its form or its order, a line that begins with "="
# among the lines after =again, or lines that sub checked does not let
# through, ends the page; its last good drawing stays. Nothing of an answer
# reaches the window before the whole of it was checked.
sub live_unknown {                        # a line of an answer lzrprf does not know, by its name: written in the log once for each page, for the first $LIVE_UNKNOWN_NAMES names
    my ($live, $name) = @_;
    my $seen = $live->{unknown} //= {};
    return if $seen->{$name};
    if (keys %$seen < $LIVE_UNKNOWN_NAMES) {
        $seen->{$name} = 1;
        return record("the page $live->{url} wrote a line lzrprf does not know, =$name; it is passed over, here and in every later answer of this page");
    }
    return if $live->{unknown_more}++;
    record("the page $live->{url} wrote lines of more names lzrprf does not know than the $LIVE_UNKNOWN_NAMES named; they are passed over and not named");
}

sub live_answered {                       # [C18]
    my ($live) = @_;
    while (!$live->{ended} && live_due($live)) {
        if (!defined $live->{whole} && !$live->{gone} && now() < $live->{until} && $live->{bytes} <= $LIVE_BYTES && ref(my $asked = live_asked($live))) {    # [C19] a request of the page, answered before anything it writes after it
            live_fetched($live, $asked);
            next;
        }
        return live_end($live, $live->{gone} ? 'it ended' : now() >= $live->{until} ? 'its time was over' : 'it wrote more than lzrprf takes') unless defined $live->{whole};
        my $at = delete $live->{whole};
        my $answer = $at < 0 ? '' : substr($live->{held}, 0, $at + 1);
        substr($live->{held}, 0, $at < 0 ? 7 : $at + 8, '');
        $live->{looked} = 0;
        $live->{waiting}-- if $live->{waiting};
        my @lines = split /\n/, $answer;
        my ($stage, $focus, $go, $words, $scroll, $shown, $cursor, @layers, @sounds) = (0);
        my $before_shown = $live->{shown};
        while (@lines && $lines[0] ne '=again' && $lines[0] !~ /^=patch /) {
            my $line = shift @lines;
            if ($stage < 1 && $line =~ /^=focus ([01])$/) { ($stage, $focus) = (1, $1) }
            elsif ($stage < 2 && $line =~ /^=go ([\x21-\x7e]{1,8192})$/) { ($stage, $go) = (2, $1) }    # the longest the application writes (LONGEST_GO); sub address takes 2000 at most, and says so
            elsif ($stage < 3 && $line =~ /^=statement ([\x20-\x7e]{1,200})$/) { ($stage, $words) = (3, $1) }
            elsif ($stage < 4 && $line =~ /^=scroll (0|[1-9][0-9]{0,5}) (0|[1-9][0-9]{0,5})$/ && $1 <= 200_000 && $2 <= 200_000) { ($stage, $scroll) = (4, "$1 $2") }
            elsif ($stage <= 5 && $line =~ /^=layers ([\x20-\x7e]+)\z/ && length $line <= $LAYERS_LINE) {    # [C18] after =scroll and before =again, one line or more
                my $items = $1;
                $stage = 5;
                my $wrong = live_layers_paid($live, length($line) + 1);
                for my $item (split /;/, $items, -1) { last if $wrong; $wrong = live_layer($live, $item) }
                return live_end($live, "it wrote layers lzrprf does not take: $wrong") if $wrong;
                push @layers, $items;
            }
            elsif ($stage <= 6 && $line =~ /^=(?:sound|samples|play|hush) /) {    # [C12] after =layers and before =again
                $stage = 6;
                $live->{bytes} -= length($line) + 1;    # counted when read (sub live_read): a page's sound has its own budget
                my $wrong = live_sound($live, $line, \@sounds);
                return live_end($live, "it wrote a sound lzrprf does not take: $wrong") if $wrong;
            }
            elsif ($line =~ /^=pressed (a|a-nohref|button|input|none) (click|noclick) (acts|canceled|stopped|throw|nopress|-)$/) { link_line('INFO', 'pressed', "the page met the press: $1, $2, $3", met => $1, click => $2, outcome => $3) }    # [1238] what a released press met, for the live debug link's log alone, before =again in any place
            elsif ($line =~ /^=inspect ([1-9][0-9]{0,8}) (-|(?:[0-9a-f]{2}){1,1000}) (-|(?:[0-9a-f]{2}){1,2400})$/) { inspect_answer($live, $1, $2, $3) }    # [C18] bounded, numbered reply to the current native pane
            elsif ($line =~ /^=cursor ([a-z-]{1,16})$/ && $CURSORS{$1}) { $cursor = $1 }    # the cursor over the page, before =again, in any place among the lines above
            elsif ($line =~ /^=keep ([^\x00-\x20\x7f]{1,16000})$/) { jar_kept_write($live, $1) }    # [C7] a cookie the page's script set, before =again in any place: judged by the jar against the page's own address (sub jar_kept_write)
            elsif ($line =~ /^=([a-z0-9-]{1,32})(?: [\x20-\x7e]{0,8192})?$/ && !$LIVE_KNOWN{$1}) { live_unknown($live, $1) }    # a line of a later application: passed over
            else { return live_end($live, 'it wrote a line of no form') }
        }
        my $quick;                        # a splice checked by itself, and sent to the window as it came (sub live_patched)
        if (my $drawing = shift @lines) {    # a full snapshot or a splice into the previous checked snapshot
            my ($start, $drop) = $drawing =~ /^=patch (0|[1-9][0-9]{0,5}) (0|[1-9][0-9]{0,5})$/;
            if (defined $start && ($quick = live_patched($live, $start, $drop, \@lines))) { $shown = $live->{shown} }
            else {
                if ($drawing ne '=again') {
                    my $old = $live->{raw};
                    return live_end($live, 'it wrote an invalid drawing splice') unless defined($start) && $old && $start <= @$old && $drop <= @$old - $start;
                    @lines = (@$old[0 .. $start-1], @lines, @$old[$start+$drop .. $#$old]);
                    my $bytes = 0; $bytes += length($_) + 1 for @lines;
                    return live_end($live, 'its expanded drawing is too large') if @lines > $PIECES || $bytes > $PAGE_BYTES;
                }
                return live_end($live, 'it wrote a line of no form') if grep { /^=/ } @lines;
                my $list = join '', map { "$_\n" } '=page', @{ $live->{paths} } ? '=pictures ' . join(' ', @{ $live->{paths} }) : (), @{ $live->{videos} } ? '=videos ' . join(' ', @{ $live->{videos} }) : (), @{ $live->{made} }, @lines;
                my ($wide, $title) = ($LAID_WIDE, $TITLED);
                $LAID_WIDE = $live->{wide};
                my ($checked) = checked($list);    # [C9] the same checks as a first list
                ($LAID_WIDE, $TITLED) = ($wide, $title);
                return live_end($live, 'it drew a list that is not fit') unless $checked;
                $live->{tally} = $LAID_TALLY;    # what it holds, for the next splice checked by itself (sub live_patched)
                my $laid = ($lines[0] // '') =~ /^(L[0-9]+x[0-9]+)$/ ? $1 : '';
                delete $live->{scroll_clamp} if $laid ne ($live->{laid} // '');    # laid at another height: the page's end moved, so where the window stopped short says nothing now, and a page that keeps to its bottom is told its new bottom
                $live->{laid} = $laid;
                $live->{raw} = [@lines];
                delete $live->{raw_bytes};     # counted again for the next splice checked by itself
                ($shown) = pictured($checked, $live->{paths}, $live->{host}, undef, undef, $live->{pictures});    # its decoded pictures only: nothing is fetched
                $live->{plain} = $shown == $checked;    # no picture in it: what is shown is what was checked, line for line
                $live->{shown} = $shown;
                $live->{unsent} = 1;       # not yet in the window: a tab not shown keeps its old drawing there until it is chosen again (sub tab_shown)
            }
        }
        if (defined $scroll) { delete $live->{scroll_held} }    # the page's own scroll is newer than any place of the window's that waited for this answer: the window is told it and shows it, and the page is not handed the older place
        elsif (!$live->{waiting} && defined $live->{scroll_held}) { live_wrote($live, delete $live->{scroll_held}); return if $live->{ended} }    # the newest place that waited for this answer, once it was read
        if (!$live->{waiting} && defined $live->{move_held}) { live_wrote($live, delete $live->{move_held}); return if $live->{ended} }    # the pointer's newest place that waited for this answer
        $live->{focus} = $focus if defined $focus;
        if (defined $scroll && (my $end = $live->{scroll_clamp})) {    # past where the window stopped short, on an axis it stopped on: told, the window would stop short again and the page be handed that, once a frame
            my @to = split / /, $scroll;
            my @past = grep { defined $end->[$_] && $to[$_] > $end->[$_] } 0, 1;
            if (@past) {
                $to[$_] = $end->[$_] for @past;    # the window is told only what it can show
                $scroll = "$to[0] $to[1]";
                $scroll = undef if $scroll eq ($live->{scrolled} // '');    # nothing it does not show already
                record("the page $live->{url} scrolled past where the window can show it; the window is told no place past that until you scroll elsewhere") unless $live->{scroll_past_said}++;
            }
        }
        if (defined $scroll) { ($live->{scrolled}, $live->{scroll_unsent}) = ($scroll, $scroll) }    # what the window will show: not handed back to the page when the window says it
        if (@layers && $live->{tab} == $TABS[$TAB]) { window(map { "layers $TAB $_" } @layers) }    # [C18] onto the drawing shown, before a drawing of the same answer
        elsif (@layers) { $live->{layers_lost} = 1 }    # the window is shown another tab: this page's layers are made again once it is shown (sub live_layers_again)
        live_sounded($live, @sounds) if @sounds;    # [C12] a tab not shown sounds nothing
        next unless $live->{tab} == $TABS[$TAB];    # a tab not selected draws when it is chosen again (sub relaid), and follows no address
        window("cursor $TAB $cursor") if defined $cursor;    # the shape of the pointer over the page shown (CSS cursor)
        if ($shown) { live_scroll_told($live); $quick ? window("patch $TAB @$quick[0, 1]", @{ $quick->[2] }, '.') : live_window_patch($before_shown, $shown); $live->{unsent} = 0; $DRAWN = 1 }    # where it was read in the page is kept, and where its script scrolled it goes just before
        live_told();
        live_home_settling($live, @layers) if @layers && $live->{home} && !$live->{home_ready};    # T3 (Henry, 2026-11-26): no flash of a half-made home; it is said ready once its scene stops growing (sub live_home_left)
        idle($words) if defined $words;
        if (defined $go && (($go eq $LZRDFNDR_OPEN && $live->{url} =~ $LZRDFNDR_PAGE) || ($live->{home} && $go =~ m{\Ahttps://lzrbrwsr\.invalid/_home/lzrdfndr(?:-other)?\z}))) { noted("the game page asked for LZRDFNDR's panel; it was opened, and nothing was fetched"); game_helper_set(1, 1) if $live->{home}; window('tool show' . ($go =~ /-other\z/ ? ' other' : '')); undef $go }    # [C26] its Activate LZRDFNDR button, or Setup LZRDFNDR (".../lzrdfndr-other": on the panel's Other tab): the page stays, and the window opens the panel as a press on its icon does
        if ($live->{home} && defined $go) {
            if ($go =~ m{^https://lzrbrwsr\.invalid/_home/(search|marks|tabs|new|trmnl)$} && now() - ($live->{pressed} // 0) <= 1) { $1 eq 'trmnl' ? ($TRMNL_OPEN = 1) : window("homeaction $1") }    # [C29] the terminal icon: lzrprf opens it itself, within a second of your press
            undef $go;    # a local home never follows an address, even if its program asks
        }
        link_line('INFO', 'go', 'the page asked to go to another address', home => ($live->{home} ? 1 : 0)) if defined $go;    # [1238] the address itself is not logged
        return go($go, 'you followed the page to') if defined $go;    # [C4] a visit like a typed address; it ends this page first (sub visit)
    }
    live_scroll_told($live) if !$live->{ended} && $DRAWN && $live->{tab} == $TABS[$TAB];    # of the answers of this turn with no drawing, the newest scroll only, and only onto a drawing the window shows
}


# The layers of a page kept running (src/page/layers.rs; how-it-works.md,
# "Layers of a page kept running"). Each item of a "=layers" line is one of
#
#   n ID P g | n ID P k X Y W H | n ID P s FILL STROKE WIDTH CAP RULE GLOWC GLOWR PATH
#   n ID P t SIZE WEIGHT STRETCH ANCHOR COLOR SPACING GLOWC GLOWR TEXT
#   n ID P e COLOR RATE LIFE SPEED SPREAD ANGLE AX AY SIZE
#   m ID A B C D E F | o ID ALPHA | d ID PATH | f ID FILL STROKE WIDTH GLOWC GLOWR
#   c ID TEXT | r ID RATE | x ID
#
# An id is 1 to 9999. "n" makes a layer of an id not in use, under a group
# (g or k) that is, or under the page (0); every other item names a layer
# that is, and only of the kind it changes (d of a shape; f of a shape or a
# text, whose STROKE is then -; c of a text; r of a particle source). "x"
# takes the layer and all it holds. At most $LAYERS_MOST layers at once and
# $LAYERS_EMITTERS particle sources; a source's RATE is 0 to 1000 a second,
# LIFE 0 to 10 seconds, SPEED 0 to 2000, SPREAD 0 to 6.2832, SIZE 0 to 64;
# an opacity is 0 to 1; a PATH at most $LAYERS_PATH bytes. Anything else ends
# the page.
sub live_layer {                          # [C18] one item of a "=layers" line, against the layers the page made: '' when it is fit, else what is wrong with it
    my ($live, $item) = @_;
    my ($n, $c, $kind) = ($LAYER_NUM, $LAYER_COLOUR, $live->{layer_kind} //= {});
    if ($item =~ /^n ([1-9][0-9]{0,3}) (0|[1-9][0-9]{0,3}) (.*)\z/s) {
        my ($id, $parent, $rest, $is) = ($1, $2, $3);
        return "layer $id is made twice" if $kind->{$id};
        return "layer $id is made under no group" unless $parent == 0 || ($kind->{$parent} // '') =~ /^[gk]\z/;
        return 'more layers than lzrprf takes' if keys %$kind >= $LAYERS_MOST;
        if ($rest eq 'g') { $is = 'g' }
        elsif ($rest =~ /^k $n $n $n $n\z/) { $is = 'k' }
        elsif ($rest =~ /^s $c $c $n [brs] [ne] $c $n ($LAYER_PATH)\z/ && length $1 <= $LAYERS_PATH) { $is = 's' }
        elsif ($rest =~ /^t $n [1-9] [nw] [sme] [0-9a-f]{8} $n $c $n $LAYER_TEXT\z/) { $is = 't' }
        elsif ($rest =~ /^e [0-9a-f]{8} ($n) ($n) ($n) ($n) $n $n $n ($n)(?: ($n) ($n) ($n))?\z/ && (!defined $6 || abs($6) <= 10 && abs($7) <= 10 && abs($8) <= 10) && $1 >= 0 && $1 <= 1000 && $2 >= 0 && $2 <= 10 && $3 >= 0 && $3 <= 2000 && $4 >= 0 && $4 <= 6.2832 && $5 >= 0 && $5 <= 64) {
            return 'more particle sources than lzrprf takes' if ($live->{layer_emitters} // 0) >= $LAYERS_EMITTERS;
            $live->{layer_emitters}++;
            $is = 'e';
        }
        else { return "layer $id is made in no form" }
        $kind->{$id} = $is;
        $live->{layer_parent}{$id} = $parent;
        $live->{layer_kids}{$parent}{$id} = 1;
        return '';
    }
    return 'an item of no form' unless $item =~ /^([modfcrx]) ([1-9][0-9]{0,3})(?: (.*))?\z/s;
    my ($op, $id, $rest) = ($1, $2, $3);
    my $is = $kind->{$id} or return "layer $id is not there";
    return '' if $op eq 'x' && !defined $rest && live_layer_gone($live, $id);
    return "layer $id is changed in no form" unless defined $rest;
    return '' if $op eq 'm' && $rest =~ /^$n $n $n $n $n $n\z/;
    return '' if $op eq 'o' && $rest =~ /^$n\z/ && $rest >= 0 && $rest <= 1;
    return '' if $op eq 'd' && $is eq 's' && length $rest <= $LAYERS_PATH && $rest =~ /^$LAYER_PATH\z/;
    return '' if $op eq 'f' && ($is eq 's' ? $rest =~ /^$c $c $n $c $n\z/ : $is eq 't' && $rest =~ /^[0-9a-f]{8} - $n $c $n\z/);
    return '' if $op eq 'c' && $is eq 't' && $rest =~ /^$LAYER_TEXT\z/;
    return '' if $op eq 'r' && $is eq 'e' && $rest =~ /^$n\z/ && $rest >= 0 && $rest <= 1000;
    return "layer $id is changed in no form";
}

sub live_layer_gone {                     # [C18] a layer and all it holds taken out of what lzrprf knows of the page's layers; true
    my ($live, $id) = @_;
    my @gone = ($id);
    while (defined(my $one = shift @gone)) {
        push @gone, keys %{ delete $live->{layer_kids}{$one} // {} };
        $live->{layer_emitters}-- if (delete $live->{layer_kind}{$one} // '') eq 'e';
        my $parent = delete $live->{layer_parent}{$one};
        delete $live->{layer_kids}{$parent}{$one} if defined $parent && $live->{layer_kids}{$parent};
    }
    return 1;
}

sub live_layers_paid {                    # [C18] the bytes of one "=layers" line taken out of its page's budget, which fills at $LAYERS_RATE a second up to $LAYERS_BURST; they are not counted in $LIVE_BYTES. '' while the budget holds, else why not
    my ($live, $bytes) = @_;
    $live->{bytes} -= $bytes;              # counted when read (sub live_read): a page's layers have their own budget
    my $now = now();
    my $had = $live->{layers_budget} // $LAYERS_BURST;
    $had += ($now - ($live->{layers_paid} // $now)) * $LAYERS_RATE;
    $had = $LAYERS_BURST if $had > $LAYERS_BURST;
    $live->{layers_paid} = $now;
    $live->{layers_budget} = $had - $bytes;
    return $live->{layers_budget} < 0 ? "more than $LAYERS_RATE bytes of layers a second" : '';
}

# The sound of a page kept running (src/page/sound.rs; how-it-works.md,
# "Sound of a page kept running"). "=sound ID RATE FRAMES FROM TO" makes
# sound ID, an id of 1 to 4294967295 not made before: RATE of 8000 to 96000
# frames a second, FRAMES of 1 to $SOUND_FRAMES, looping from FROM to TO with
# FROM below TO and TO at most FRAMES, or played once with both 0; at most
# $SOUNDS_MOST sounds and $SOUND_BYTES of samples in the page's life.
# "=samples ID BASE64" adds to its samples: RFC 4648 base64 in groups of
# four, padded only on the line that ends them, never more than FRAMES
# samples of two bytes. "=play ID AT" sounds a sound whose samples are all
# there from frame AT, below FRAMES; "=hush ID" silences a sound made.
# Anything else ends the page. A =play more than $SOUND_PRESS_SECONDS after
# the last click or key lzrprf handed the page is not passed on, and the log
# says so once for the page: a page never starts sound by itself.
sub live_sound {                          # [C12] one sound line of an answer, against the sounds the page made: '' when it is fit, else what is wrong with it; what the sound process is to be told is put on @$out
    my ($live, $line, $out) = @_;
    my $made = $live->{sounds} //= {};
    my $id = qr/([1-9][0-9]{0,9})/;
    if ($line =~ /^=sound $id (0|[1-9][0-9]{0,8}) (0|[1-9][0-9]{0,8}) (0|[1-9][0-9]{0,8}) (0|[1-9][0-9]{0,8})\z/) {
        my ($n, $rate, $frames, $from, $to) = ($1, $2, $3, $4, $5);
        return 'an id past 4294967295' if $n > 4294967295;
        return 'a sound made twice' if $made->{$n};
        return 'a rate lzrprf does not take' if $rate < 8000 || $rate > 96000;
        return 'a sound of no frames or too many' if $frames < 1 || $frames > $SOUND_FRAMES;
        return 'a loop outside the sound' unless ($from == 0 && $to == 0) || ($from < $to && $to <= $frames);
        return "more than $SOUNDS_MOST sounds" if ++$live->{sounds_made} > $SOUNDS_MOST;
        return "more than $SOUND_BYTES bytes of samples" if ($live->{sound_bytes} += 2 * $frames) > $SOUND_BYTES;
        $made->{$n} = { rate => $rate, frames => $frames, from => $from, to => $to, parts => [], got => 0 };
        return '';
    }
    if ($line =~ /^=samples $id ([A-Za-z0-9+\/]*={0,2})\z/) {
        my ($n, $code) = ($1, $2);
        my $sound = $made->{$n} or return 'samples of a sound not made';
        return 'samples of a line too long' if length($code) > $SOUND_LINE;
        return 'samples not in groups of four' if !length($code) || length($code) % 4;
        my $pad = $code =~ /(=+)\z/ ? length $1 : 0;
        $sound->{got} += length($code) / 4 * 3 - $pad;
        return 'more samples than the sound has' if $sound->{got} > 2 * $sound->{frames};
        return 'padding before the samples end' if $pad && $sound->{got} < 2 * $sound->{frames};
        push @{ $sound->{parts} }, $code;
        return '';
    }
    if ($line =~ /^=play $id (0|[1-9][0-9]{0,8})\z/) {
        my ($n, $at) = ($1, $2);
        my $sound = $made->{$n} or return 'a sound not made';
        return 'a sound whose samples are not all there' if $sound->{got} != 2 * $sound->{frames};
        return 'a frame past its end' if $at >= $sound->{frames};
        if (now() - ($live->{pressed} // -1e9) > $SOUND_PRESS_SECONDS) {
            record("the page $live->{url} started a sound with no click or key of yours just before it; no sound of it is played") unless $live->{sound_unpressed}++;
            return '';
        }
        push @$out, "play $n $at";
        return '';
    }
    if ($line =~ /^=hush $id\z/) {
        return 'a sound not made' unless $made->{$1};
        push @$out, "stop $1";
        return '';
    }
    return 'a line of no form';
}

sub live_sounded {                        # [C12] what a page's answer sounds, for the tab shown, to the sound process: a sound's samples once ("sound begin", "sound part"), then "sound play" and "sound stop"; every sound goes with another tab, a new page and no page kept running (sub sound_hushed), and lzrprf forgets what it sent then
    my ($live, @told) = @_;
    return unless $live->{tab} == $TABS[$TAB];
    my $held = $live->{sound_held} //= {};
    my @lines;
    for (@told) {
        my ($what, $n, $at) = split / /;
        if ($what eq 'stop') { push @lines, "sound stop $TAB $n" if $held->{$n}; next }
        my $sound = $live->{sounds}{$n};
        push @lines, "sound begin $TAB $n $sound->{rate} $sound->{frames} $sound->{from} $sound->{to}", map { "sound part $TAB $n $_" } @{ $sound->{parts} } unless $held->{$n}++;
        push @lines, "sound play $TAB $n $at";
    }
    sound_told($live, @lines) if @lines;
}

sub live_layers_again {                   # [C18] the page of the tab shown now, whose layers the window does not hold, is written "=layers": it tells every layer gone and makes it again
    my $live = live_of($TABS[$TAB]) or return;
    return unless delete $live->{layers_lost} or %{ $live->{layer_kind} // {} };
    delete @$live{qw(home_ready home_owed home_first)} if $live->{home};
    live_wrote($live, 'layers') unless $live->{ended};
}

# Only checked complete drawings arrive here. The window receives a compact replacement range
# when it saves at least 512 bytes; it retains the same drawing objects for unchanged lines.
# [C9] A splice of a laid list checked by itself: its own lines, from where the list stands where it
# begins (found item by item, the rows of a tile or a picture passed over by their count), against what
# the rest of the list holds (sub laid_run), and ending where the list it replaces ended. Only a splice
# with no tile, placed tile, picture or picture to fetch (K, J, M, I) on either side, of a page with no
# picture to fetch whose last list was checked whole; else nothing, and the whole list is checked as a
# first list is. Typing in a field of a long page checked its 8 MB list again on every key, 15 to 20 ms
# with putting it together (measured 2026-11-23). Gives where the shown list changed, and its new lines.
sub live_patched {
    my ($live, $start, $drop, $new) = @_;
    my ($old, $tally) = ($live->{raw}, $live->{tally});
    return unless $tally && $live->{plain} && $old && $start >= 1 && $drop <= @$old - $start && ($old->[0] // '') =~ /^L([0-9]+)x/ && $1 == $live->{wide};
    return if grep { /^[KJMNI=]/ } @$new, @$old[$start .. $start + $drop - 1];
    my $at = sub {                        # where the list stands at the start of its line $p: the rows still to come of the item it is in, a tile row's length, a picture row's bytes, whether a row of its tile stands above
        my ($p) = @_;
        for (my $i = 1; $i < $p;) {
            my ($w, $h) = $old->[$i] =~ /^K[0-9]+,[0-9]+,[0-9]+,([0-9]+),([0-9]+)$/;
            my ($pw, $ph) = defined $w ? () : $old->[$i] =~ /^M[0-9]+,[0-9]+,[0-9]+,[0-9]+,([0-9]+),([0-9]+)(?:,[0-9]+,[0-9]+,[0-9]+,[0-9]+)?$/;
            my $rows = $h // $ph // 0;
            return ($i + $rows - $p + 1, defined $w ? 1 + 4 * $w : 0, defined $pw ? 4 * $pw : 0, defined $w && $p > $i + 1 ? 1 : 0) if $i + $rows >= $p;
            $i += 1 + $rows;
        }
        return (0, 0, 0, 0);
    };
    my @begin = $at->($start);
    my $rows = $begin[0];
    my @end = $at->($start + $drop);
    my ($text, $bytes, %less) = (0, 0);   # what the lines taken out held
    for my $line (@$old[$start .. $start + $drop - 1]) {
        $bytes += length($line) + 1;
        if ($rows) { $rows--; next }
        $less{substr $line, 0, 1}++;
        next unless substr($line, 0, 1) eq 'X';
        my $chars = $line;
        utf8::decode($chars) or return;
        $text += length($chars) - length(($chars =~ /^(X[0-9]+,[0-9]+,[0-9]+,[\@-O],[0-9a-f]{6},)/)[0] // return);
    }
    my @lines = @$new;
    utf8::decode($_) or return for @lines;
    my %count = %{ $tally->{count} };
    $count{$_} -= $less{$_} for keys %less;
    my $state = { %$tally, text => $tally->{text} - $text, count => \%count, rows => $begin[0], row_chars => $begin[1], row_bytes => $begin[2], above => $begin[3] };
    laid_run(\@lines, 0, $#lines, $state, $live->{paths}, $live->{videos}) or return;
    return unless $state->{rows} == $end[0] && (!$end[0] || $state->{row_chars} == $end[1] && $state->{row_bytes} == $end[2]);    # it ends where the list it replaces ended: the rest stands as it was checked
    utf8::encode($_) for @lines;
    my @raw = (@$old[0 .. $start - 1], @lines, @$old[$start + $drop .. $#$old]);
    $live->{raw_bytes} //= do { my $all = 0; $all += length($_) + 1 for @$old; $all };
    $bytes = $live->{raw_bytes} - $bytes;
    $bytes += length($_) + 1 for @lines;
    return if @raw > $PIECES || $bytes > $PAGE_BYTES;
    @$live{qw(raw raw_bytes tally unsent)} = (\@raw, $bytes, { %$state, rows => 0, row_chars => 0, row_bytes => 0, above => 0 }, 1);
    $live->{shown} = [@{ $live->{made} }, @raw];
    print STDERR "test splice alone $start $drop\n" if $TRY;    # "lzrprf try" only: the whole list was not checked again, for the test to see
    return [@{ $live->{made} } + $start, $drop, \@lines];
}

sub live_window_patch { window_changed(@_) }    # the list the window holds and the one to stand there (20-window-side.pl)
