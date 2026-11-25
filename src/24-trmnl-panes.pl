
# LZRTRMNL's panes, its tabs and its bar [C29]: the window chrome of a
# terminal, drawn by lzrprf as lines of a laid page around what each pane's
# container draws (24-trmnl.pl).
#
# A browser tab that is a terminal holds a workspace ($tab->{trmnl}): one or
# more terminal tabs, shown in a strip under a bar of two menus, File and
# View. Each terminal tab is a tree of panes. A leaf is one pane, a shell and
# its drawing container (sub trmnl_started); a split holds two parts, side by
# side ("right") or one above the other ("down"), and the share of the first
# in ten-thousandths. Splits nest, and every pane stays in the browser tab it
# was made in: a terminal's tab does not move to another window.
#
# What you do, and how lzrprf hears it:
#   a press on File or View: lzrprf hands the window that menu ("trmnlmenu X
#     Y" and its items), which shows it and says the item you chose ("page
#     menu ID"). An item is taken only when it was offered, and offered as one
#     that can be done, in the menu shown last, and once (sub trmnl_pressed);
#   a right press in the terminal ("page context X Y"): the pane under it gets
#     the focus, and its menu is offered there: the splits, Close pane, Copy
#     and Paste;
#   a key of the window's TRMNL_SHORTCUTS ("page tkey ID"), one of %TRMNL_KEYED;
#   a press on a terminal tab chooses it, on its x closes it, on + adds one;
#   a press on a divider, then a drag, moves it; a press in a pane gives it the
#     focus and starts a selection there, which a drag carries on.
#
# The keys, the common terminals' wherever the browser does not use the key
# for itself already (its menus: Cmd-D, Cmd-T, Cmd-W, Shift-Cmd-T, Cmd-[ and
# Cmd-], Cmd-Option-Left and Right, Ctrl-Tab):
#   Split right             Cmd-\              VS Code's split terminal
#   Split down              Shift-Cmd-D        iTerm2's split horizontally
#   Close pane              Shift-Cmd-W        Windows Terminal's Ctrl-Shift-W, with Cmd as on a Mac
#   Focus a pane            Shift-Cmd-arrow    iTerm2 and VS Code use Cmd-Option-arrow, which the browser's tabs hold
#   Move a divider          Ctrl-Cmd-arrow     iTerm2 and VS Code
#   Equalise sizes          Ctrl-Cmd-=
#   Add terminal tab        Ctrl-Shift-T       Windows Terminal
#   Close terminal tab      Ctrl-Shift-W
#   Next, previous tab      Ctrl-Page Down, Ctrl-Page Up (VS Code, Chrome); with Shift the tab moves
#   Save tabs and views     Cmd-S
#
# Save writes the workspace into the plain file trmnl of this profile's own
# folder (sub trmnl_saved): the terminal tabs in their order, the one shown,
# each tab's number, its tree with every split's direction and share, the pane
# with the focus, and each pane's working folder, which the system says of
# its shell (sub trmnl_cwd). No title a program set, nothing typed and nothing
# shown is written. Opening LZRTRMNL again lays out exactly that (sub
# trmnl_workspace): each pane a new login shell, started in its folder, or in
# the home folder when that folder is gone. A shell that ended cannot be
# brought back, and a new one in the same place is what the common terminals
# restore too.
my $TRMNL_TABS = 9;                       # the most terminal tabs in one LZRTRMNL
my $TRMNL_PANES = 16;                     # the most panes in all its tabs together: each is a shell and a container of about 2 MB
my $TRMNL_BAR = 24;                       # the height of the bar of File and View, in points
my $TRMNL_STRIP = 26;                     # the height of the strip of terminal tabs under it
my $TRMNL_EDGE = 2;                       # the frame round each pane: two panes side by side have 4 points between them, and the focused one's frame is in the beam colour
my @TRMNL_LEAST = (96, 48);               # the smallest pane, in points: 12 columns and 3 rows. A split that would make a pane smaller is not made, and a divider stops there
my @TRMNL_STEP = (8, 16);                 # how far a key moves a divider: a column, a row
my $TRMNL_SAVED = 65_536;                 # the most bytes of the saved file
my $TRMNL_TAB_WIDE = 180;                 # the widest a terminal tab is drawn in the strip
my %TRMNL_INK = (page => '0c0f12ff', bar => '161b20ff', strip => '101418ff', line => '2a323aff', frame => '1d2329ff', focus => '48ddffff', shade => '0c0f1273', text => 'd6dde3', dim => '7f8b96');
my @TRMNL_MENUS = (['file', 'File', 4, 44], ['view', 'View', 48, 48]);    # each menu of the bar: its name, its word, where it starts and how wide its press is
my %TRMNL_SAID = ('tab-new' => 'Add terminal tab', 'tab-close' => 'Close current terminal tab', save => 'Save tabs and views', forget => 'Forget saved tabs and views',
    'tab-next' => 'Next terminal tab', 'tab-prev' => 'Previous terminal tab', 'tab-left' => 'Move terminal tab left', 'tab-right' => 'Move terminal tab right',
    'split-right' => 'Split right', 'split-down' => 'Split down', 'close-pane' => 'Close pane', equalise => 'Equalise sizes', copy => 'Copy', paste => 'Paste',
    'focus-left' => 'Focus pane to the left', 'focus-right' => 'Focus pane to the right', 'focus-up' => 'Focus pane above', 'focus-down' => 'Focus pane below',
    'size-left' => 'Move divider left', 'size-right' => 'Move divider right', 'size-up' => 'Move divider up', 'size-down' => 'Move divider down');
my %TRMNL_KEYED = map { $_ => 1 } qw(split-right split-down close-pane focus-left focus-right focus-up focus-down size-left size-right size-up size-down equalise tab-new tab-close tab-next tab-prev tab-left tab-right save);    # DECLARED(the window's TRMNL_SHORTCUTS)

sub trmnl_leaves { my ($node) = @_; return $node->{split} ? (trmnl_leaves($node->{a}), trmnl_leaves($node->{b})) : ($node) }    # the panes of a tree, left to right and top to bottom
sub trmnl_panes { my ($w) = @_; return map { trmnl_leaves($_->{tree}) } @{ $w->{tabs} } }    # every pane of a workspace, in all its terminal tabs
sub trmnl_shown_tab { my ($w) = @_; return $w->{tabs}[$w->{at}] }    # the terminal tab shown

sub trmnl_path {                          # the splits from the top of a tree down to one of its panes, each with the side the pane is on; nothing when it is not in the tree
    my ($node, $leaf) = @_;
    return [] if $node == $leaf;
    return unless $node->{split};
    for my $side (qw(a b)) { my $below = trmnl_path($node->{$side}, $leaf) or next; return [[$node, $side], @$below] }
    return;
}

sub trmnl_replaced {                      # one part of a terminal tab's tree put in another's place
    my ($tt, $old, $new) = @_;
    return $tt->{tree} = $new if $tt->{tree} == $old;
    my $path = trmnl_path($tt->{tree}, $old) or return;
    my ($parent, $side) = @{ $path->[-1] };
    $parent->{$side} = $new;
}

# Where everything stands. The page is the window's page as it is, as a
# terminal's always was (@TRMNL_VIEW); the bar and the strip take its top, and
# each terminal tab's tree is laid in the rest: a split gives its first part
# its share of the length across, held so both parts keep their least size
# where there is room for both. A pane's cell is its place with its frame; its
# rectangle, the cell less the frame, is what its container draws in.
sub trmnl_page {
    my ($wide, $high) = @TRMNL_VIEW ? @TRMNL_VIEW : @VIEW;
    $wide = $wide < 240 ? 240 : $wide > 8192 ? 8192 : $wide;
    $high = $high < 160 ? 160 : $high > 8192 ? 8192 : $high;
    return ($wide, $high);
}

sub trmnl_least {                         # the least width and height a tree is laid in
    my ($node) = @_;
    return ($TRMNL_LEAST[0] + 2 * $TRMNL_EDGE, $TRMNL_LEAST[1] + 2 * $TRMNL_EDGE) unless $node->{split};
    my ($aw, $ah) = trmnl_least($node->{a});
    my ($bw, $bh) = trmnl_least($node->{b});
    return $node->{split} eq 'right' ? ($aw + $bw, $ah > $bh ? $ah : $bh) : ($aw > $bw ? $aw : $bw, $ah + $bh);
}

sub trmnl_held {                          # where a split's divider may stand in a length $all, from where it would: both parts at least their least size when there is room for both
    my ($split, $first, $all) = @_;
    my $i = $split->{split} eq 'right' ? 0 : 1;
    my ($a, $b) = ((trmnl_least($split->{a}))[$i], (trmnl_least($split->{b}))[$i]);
    if ($a + $b <= $all) { $first = $a if $first < $a; $first = $all - $b if $first > $all - $b }
    else { $first = int($all / 2) }
    return $first < 1 ? 1 : $first;
}

sub trmnl_place {                         # a tree laid in the cell X Y WIDE HIGH
    my ($node, $x, $y, $wide, $high) = @_;
    $node->{cell} = [$x, $y, $wide, $high];
    if (!$node->{split}) {
        my @rect = ($x + $TRMNL_EDGE, $y + $TRMNL_EDGE, $wide - 2 * $TRMNL_EDGE, $high - 2 * $TRMNL_EDGE);
        $_ = $_ < 1 ? 1 : $_ for @rect[2, 3];
        $node->{rect} = \@rect;
        return;
    }
    my $right = $node->{split} eq 'right';
    my $all = $right ? $wide : $high;
    my $first = $node->{at} = trmnl_held($node, int($all * $node->{share} / 10_000 + 0.5), $all);
    trmnl_place($node->{a}, $x, $y, $right ? ($first, $high) : ($wide, $first));
    trmnl_place($node->{b}, $right ? ($x + $first, $y, $wide - $first, $high) : ($x, $y + $first, $wide, $high - $first));
}

sub trmnl_layout {                        # every terminal tab of a workspace laid in the page, and each pane's container told its size (sub trmnl_sized)
    my ($w) = @_;
    my ($wide, $high) = trmnl_page();
    trmnl_place($_->{tree}, 0, $TRMNL_BAR + $TRMNL_STRIP, $wide, $high - $TRMNL_BAR - $TRMNL_STRIP) for @{ $w->{tabs} };
    trmnl_sized($_) for trmnl_panes($w);
}

sub trmnl_relaid {                        # a workspace laid out again and drawn: after a split, a close, a divider moved, another tab or another size of the window
    my ($tab) = @_;
    my $w = $tab->{trmnl} or return;
    trmnl_layout($w);
    trmnl_retitled($tab);
    trmnl_drawn($tab);
}

sub trmnl_span {                          # how wide each terminal tab is drawn in the strip, with room for + after them
    my ($w, $wide) = @_;
    my $span = int(($wide - 32) / @{ $w->{tabs} });
    return $span > $TRMNL_TAB_WIDE ? $TRMNL_TAB_WIDE : $span < 48 ? 48 : $span;
}

sub trmnl_label {                         # what a terminal tab is called: the title its focused pane's program set, or its number
    my ($tt) = @_;
    return $tt->{focus}{title} // "Terminal $tt->{number}";
}

sub trmnl_fitted {                        # text cut to at most $most characters, an ellipsis at its end when it was cut; bytes of UTF-8 in and out
    my ($text, $most) = @_;
    my $chars = $text;
    utf8::decode($chars);
    $most = 1 if $most < 1;
    $chars = substr($chars, 0, $most - 1) . "\x{2026}" if length $chars > $most;
    utf8::encode($chars);
    return $chars;
}

sub trmnl_chrome {                        # the lines of the bar, with File and View, and of the strip of terminal tabs, the one shown marked, each with its x and + after them
    my ($w, $wide) = @_;
    my @lines = ("R0,0,$wide,$TRMNL_BAR,$TRMNL_INK{bar}", "R0," . ($TRMNL_BAR - 1) . ",$wide,1,$TRMNL_INK{line}");
    push @lines, 'X' . ($_->[2] + 10) . ",16,12,\@,$TRMNL_INK{text},$_->[1]" for @TRMNL_MENUS;
    my ($top, $base, $span) = ($TRMNL_BAR, $TRMNL_BAR + 17, trmnl_span($w, $wide));
    push @lines, "R0,$top,$wide,$TRMNL_STRIP,$TRMNL_INK{strip}";
    my $x = "\x{d7}";
    utf8::encode($x);
    for my $i (0 .. $#{ $w->{tabs} }) {
        my ($left, $shown) = ($i * $span, $i == $w->{at});
        push @lines, "R$left,$top,$span,$TRMNL_STRIP,$TRMNL_INK{page}", "R$left,$top,$span,2,$TRMNL_INK{focus}" if $shown;
        push @lines, 'R' . ($left + $span - 1) . ',' . ($top + 5) . ",1,16,$TRMNL_INK{line}";
        push @lines, 'X' . ($left + 10) . ",$base,12," . ($shown ? "A,$TRMNL_INK{text}" : "\@,$TRMNL_INK{dim}") . ',' . trmnl_fitted(trmnl_label($w->{tabs}[$i]), int(($span - 34) / 7));
        push @lines, 'X' . ($left + $span - 18) . ",$base,12,\@,$TRMNL_INK{dim},$x";
    }
    push @lines, 'X' . (@{ $w->{tabs} } * $span + 10) . ",$base,14,\@,$TRMNL_INK{dim},+";
    return @lines;
}

sub trmnl_moved {                         # the lines of a pane's row moved to where its rectangle stands, and cut to it
    my ($lines, $x0, $y0, $wide, $high) = @_;
    my @moved;
    for (@$lines) {
        if (/^R([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9a-f]{8})$/) {
            my ($x, $y, $w, $h) = ($1, $2, $3, $4);
            next if $x >= $wide || $y >= $high;
            $w = $wide - $x if $x + $w > $wide;
            $h = $high - $y if $y + $h > $high;
            push @moved, 'R' . ($x + $x0) . ',' . ($y + $y0) . ",$w,$h,$5";
        }
        elsif (/^X([0-9]+),([0-9]+),(.*)\z/s) { push @moved, 'X' . ($1 + $x0) . ',' . ($2 + $y0) . ",$3" unless $1 >= $wide || $2 > $high }
    }
    return \@moved;
}

# The page of a workspace: the bar, the strip, and the panes of the terminal
# tab shown, each in its frame, the focused one's in the beam colour, and the
# others shaded when there is more than one. Within a laid page's bounds: a
# row that would take the page past them is left out, and the window is told
# so once. Gives the list, and whether a row was left out.
sub trmnl_composed {
    my ($w) = @_;
    my ($wide, $high) = trmnl_page();
    my $tt = trmnl_shown_tab($w);
    my @leaves = trmnl_leaves($tt->{tree});
    my @list = ("L${wide}x$high", "R0,0,$wide,$high,$TRMNL_INK{page}", trmnl_chrome($w, $wide));
    my ($r, $x, $text, $cut) = (scalar(@list) + 3 * @leaves, scalar(@list), 0, 0);
    $text += length for @list;
    for my $t (@leaves) {
        my ($cell, $rect) = @$t{qw(cell rect)};
        next unless $cell && $rect;
        push @list, 'R' . join(',', @$cell) . ',' . (@leaves > 1 && $t == $tt->{focus} ? $TRMNL_INK{focus} : $TRMNL_INK{frame}), 'R' . join(',', @$rect) . ",$TRMNL_INK{page}";
        my $at = "@$rect";
        @$t{qw(moved moved_at)} = ([], $at) if ($t->{moved_at} // '') ne $at;
        for my $n (0 .. $#{ $t->{rows} // [] }) {
            my ($row, $tally) = ($t->{rows}[$n], $t->{tally}[$n]);
            next unless $row && $tally;
            if ($r + $tally->[0] > $LAID{R} || $x + $tally->[1] > $LAID{X} || $text + $tally->[2] > $ALL_TEXT) { $cut = 1; next }
            ($r, $x, $text) = ($r + $tally->[0], $x + $tally->[1], $text + $tally->[2]);
            push @list, @{ $t->{moved}[$n] //= trmnl_moved($row, @$rect) };
        }
    }
    push @list, map { 'R' . join(',', @{ $_->{rect} }) . ",$TRMNL_INK{shade}" } grep { $_ != $tt->{focus} && $_->{rect} } @leaves if @leaves > 1;
    return (\@list, $cut);
}

sub trmnl_retitled {                      # the browser tab's title: the title the focused pane's program set, or LZRTRMNL
    my ($tab) = @_;
    my $w = $tab->{trmnl} or return;
    my $title = trmnl_shown_tab($w)->{focus}{title} // 'LZRTRMNL';
    return if $title eq ($tab->{title} // '');
    $tab->{title} = $title;
    my ($n) = grep { $TABS[$_] == $tab } 0 .. $#TABS;
    window("title $n $title") if defined $n;
}

# A new workspace: the tabs and views saved for this profile, laid out as they
# were saved, or one terminal tab of one pane when none was saved or what was
# saved cannot be read. Gives the workspace, or nothing and why in full.
sub trmnl_workspace {
    my $w = { tabs => [], at => 0, started => [] };
    my $kept = trmnl_kept();
    if ($kept) {
        for my $one (@{ $kept->{tabs} }) {
            my $tree = trmnl_grown($w, $one->{tree});
            if (!$tree) { trmnl_pane_end($_) for @{ $w->{started} }; return (undef, "LZRTRMNL could not be started: $w->{why}. No shell was started.") }
            my @leaves = trmnl_leaves($tree);
            push @{ $w->{tabs} }, { tree => $tree, focus => $leaves[$one->{focus}], number => $one->{number} };
        }
        $w->{at} = $kept->{at};
        delete $w->{started};
        noted('LZRTRMNL opened the tabs and views saved for this profile');
        return $w;
    }
    my ($t, $why) = trmnl_pane_new($w, undef);
    return (undef, "LZRTRMNL could not be started: $why. No shell was started.") unless $t;
    push @{ $w->{tabs} }, { tree => $t, focus => $t, number => 1 };
    delete $w->{started};
    return $w;
}

sub trmnl_grown {                         # a saved tree with each of its panes started; nothing when one could not be, and why in $w->{why}
    my ($w, $node) = @_;
    if ($node->{split}) {
        my $a = trmnl_grown($w, $node->{a}) or return;
        my $b = trmnl_grown($w, $node->{b}) or return;
        return { split => $node->{split}, share => $node->{share}, a => $a, b => $b };
    }
    my ($t, $why) = trmnl_pane_new($w, $node->{cwd});
    $w->{why} = $why unless $t;
    return $t;
}

sub trmnl_pane_new {                      # a pane: its container started now, its shell once the container says its size, in the folder $cwd (the home folder when that is none or gone)
    my ($w, $cwd) = @_;
    my @panes = $w->{started} ? @{ $w->{started} } : trmnl_panes($w);    # while a saved workspace is laid out, the panes started so far
    return (undef, "LZRTRMNL holds $TRMNL_PANES panes at most") if @panes >= $TRMNL_PANES;
    my ($program, $why) = trmnl_program();
    return (undef, $why) unless $program;
    my ($t, $fault) = trmnl_started($program, defined $cwd && -d $cwd ? $cwd : undef);
    return (undef, $fault) unless $t;
    push @{ $w->{started} }, $t if $w->{started};
    return $t;
}

# What the window says of a press, a drag, a right press, an item of a menu
# and a key of the list, in a terminal's tab [C29].
sub trmnl_pressed {
    my ($tab, $what) = @_;
    my $w = $tab->{trmnl} or return;
    if ($what =~ /^click ([0-9]+) ([0-9]+)$/) { return trmnl_clicked($tab, 0 + $1, 0 + $2) }
    if ($what =~ /^drag ([0-9]+) ([0-9]+)$/) { return trmnl_dragged($tab, 0 + $1, 0 + $2) }
    if ($what =~ /^context ([0-9]+) ([0-9]+)$/) {
        my ($x, $y) = (0 + $1, 0 + $2);
        my $t = trmnl_pane_at($w, $x, $y) or return;
        trmnl_focused($tab, $t);
        return trmnl_menu_offered($w, "pane", $x, $y);
    }
    if ($what =~ /^menu ([a-z-]+)$/) { my ($id, $offered) = ($1, delete $w->{offered}); return $offered && $offered->{$id} ? trmnl_act($tab, $id) : undef }    # only what the menu shown last offered as one that can be done, and once
    if ($what =~ /^tkey ([a-z-]+)$/ && $TRMNL_KEYED{$1}) { return trmnl_act($tab, $1) }
}

sub trmnl_pane_at { my ($w, $x, $y) = @_; my ($t) = grep { my $c = $_->{cell}; $c && $x >= $c->[0] && $y >= $c->[1] && $x < $c->[0] + $c->[2] && $y < $c->[1] + $c->[3] } trmnl_leaves(trmnl_shown_tab($w)->{tree}); return $t }    # the pane of the tab shown whose cell holds a point

sub trmnl_divider_at {                    # the split whose divider is within 3 points of a point, the deepest first
    my ($node, $x, $y) = @_;
    return unless $node->{split};
    for my $side (qw(a b)) { my $below = trmnl_divider_at($node->{$side}, $x, $y); return $below if $below }
    my ($cx, $cy, $cw, $ch) = @{ $node->{cell} // return };
    return $node if $node->{split} eq 'right' ? abs($x - $cx - $node->{at}) <= 3 && $y >= $cy && $y < $cy + $ch : abs($y - $cy - $node->{at}) <= 3 && $x >= $cx && $x < $cx + $cw;
    return;
}

sub trmnl_clicked {
    my ($tab, $x, $y) = @_;
    my $w = $tab->{trmnl};
    delete $w->{press};
    my ($wide) = trmnl_page();
    if ($y < $TRMNL_BAR) {
        for (@TRMNL_MENUS) { my ($menu, undef, $left, $span) = @$_; return trmnl_menu_offered($w, $menu, $left, $TRMNL_BAR) if $x >= $left && $x < $left + $span }
        return;
    }
    if ($y < $TRMNL_BAR + $TRMNL_STRIP) {
        my $span = trmnl_span($w, $wide);
        my $i = int($x / $span);
        return trmnl_act($tab, 'tab-new') if $i == @{ $w->{tabs} } && $x - $i * $span < 30;
        return unless $i < @{ $w->{tabs} };
        return trmnl_tab_closed($tab, $i) if $x >= ($i + 1) * $span - 24;
        return trmnl_tab_chosen($tab, $i);
    }
    my $tt = trmnl_shown_tab($w);
    if (my $split = trmnl_divider_at($tt->{tree}, $x, $y)) { $w->{press} = { split => $split }; return }
    my $t = trmnl_pane_at($w, $x, $y) or return;
    trmnl_focused($tab, $t) if $t != $tt->{focus};
    $w->{press} = { pane => $t };
    $t->{pressed}++ if $t->{mouse} && $t->{pressed} < 8;    # a press of yours while the shell asked for presses: its container may answer it with =mouse once (sub trmnl_reported)
    trmnl_inside($t, 'p', $x, $y);
}

sub trmnl_inside { my ($t, $what, $x, $y) = @_; my ($px, $py, $pw, $ph) = @{ $t->{rect} }; ($x, $y) = ($x - $px, $y - $py); $x = $x < 0 ? 0 : $x >= $pw ? $pw - 1 : $x; $y = $y < 0 ? 0 : $y >= $ph ? $ph - 1 : $y; trmnl_send($t, "$what $x $y\n") if $t->{to} }    # a press or a drag to a pane's container, in its own points, held inside it

sub trmnl_dragged {                       # a drag after a press: a divider moved with it, or the pane's selection carried on
    my ($tab, $x, $y) = @_;
    my $w = $tab->{trmnl};
    my $press = $w->{press} or return;
    return trmnl_inside($press->{pane}, 'g', $x, $y) if $press->{pane} && !$press->{pane}{ended};
    my $split = $press->{split} or return;
    my ($cx, $cy, $cw, $ch) = @{ $split->{cell} };
    trmnl_shared($split, $split->{split} eq 'right' ? $x - $cx : $y - $cy);
    trmnl_relaid($tab);
}

sub trmnl_shared {                        # a split's share, from where its divider is to stand
    my ($split, $first) = @_;
    my $all = $split->{cell}[$split->{split} eq 'right' ? 2 : 3];
    return if $all < 2;
    my $share = int(trmnl_held($split, $first, $all) * 10_000 / $all + 0.5);
    $split->{share} = $share < 1 ? 1 : $share > 9999 ? 9999 : $share;
}

sub trmnl_focused {                       # a pane given the focus: its frame drawn in the beam colour, the keys go to its shell
    my ($tab, $t) = @_;
    my $tt = trmnl_shown_tab($tab->{trmnl});
    $tt->{focus} = $t;
    trmnl_retitled($tab);
    trmnl_drawn($tab);
}

sub trmnl_neighbour {                     # the pane beside the focused one in a direction: of those wholly that way that overlap it across, the nearest, then the one that overlaps most
    my ($tt, $way) = @_;
    my ($fx, $fy, $fw, $fh) = @{ $tt->{focus}{cell} // return };
    my ($best, $gap_best, $over_best);
    for my $t (trmnl_leaves($tt->{tree})) {
        next if $t == $tt->{focus} || !$t->{cell};
        my ($x, $y, $w, $h) = @{ $t->{cell} };
        my ($gap, $low, $high) = $way eq 'left' ? ($fx - $x - $w, $y, $y + $h) : $way eq 'right' ? ($x - $fx - $fw, $y, $y + $h) : $way eq 'up' ? ($fy - $y - $h, $x, $x + $w) : ($y - $fy - $fh, $x, $x + $w);
        my ($flow, $fhigh) = $way =~ /left|right/ ? ($fy, $fy + $fh) : ($fx, $fx + $fw);
        my $over = ($high < $fhigh ? $high : $fhigh) - ($low > $flow ? $low : $flow);
        next if $gap < 0 || $over <= 0;
        ($best, $gap_best, $over_best) = ($t, $gap, $over) if !$best || $gap < $gap_best || $gap == $gap_best && $over > $over_best;
    }
    return $best;
}

sub trmnl_divider_for {                   # the divider a key in a direction moves: the nearest above the focused pane that runs across that way
    my ($tt, $way) = @_;
    my $path = trmnl_path($tt->{tree}, $tt->{focus}) or return;
    my $dir = $way =~ /left|right/ ? 'right' : 'down';
    my ($split) = grep { $_->{split} eq $dir } map { $_->[0] } reverse @$path;
    return $split;
}

sub trmnl_across { my ($node, $dir) = @_; return 1 unless $node->{split}; my ($a, $b) = (trmnl_across($node->{a}, $dir), trmnl_across($node->{b}, $dir)); return $node->{split} eq $dir ? $a + $b : $a > $b ? $a : $b }    # how many panes stand side by side in a tree, across a direction

sub trmnl_even {                          # Equalise sizes: every split's share set so the panes side by side across it share its length alike
    my ($node) = @_;
    return unless $node->{split};
    my ($a, $b) = (trmnl_across($node->{a}, $node->{split}), trmnl_across($node->{b}, $node->{split}));
    $node->{share} = int(10_000 * $a / ($a + $b) + 0.5);
    trmnl_even($_) for @$node{qw(a b)};
}

sub trmnl_splits {                        # whether the focused pane can be split that way: a pane left to be had, and room for two
    my ($w, $way) = @_;
    my @panes = trmnl_panes($w);
    return 0 if @panes >= $TRMNL_PANES;
    my $cell = trmnl_shown_tab($w)->{focus}{cell} or return 1;
    my $i = $way eq 'right' ? 0 : 1;
    return $cell->[2 + $i] >= 2 * ($TRMNL_LEAST[$i] + 2 * $TRMNL_EDGE) ? 1 : 0;
}

# The menus: File, View, and a pane's own (its right press). Each item is
# offered as one that can be done (1) or not (0), with a line ("-") between
# groups; the window shows each item's key beside it from its own list.
sub trmnl_items {
    my ($w, $menu) = @_;
    my $tt = trmnl_shown_tab($w);
    my @panes = trmnl_panes($w);
    my @here = trmnl_leaves($tt->{tree});
    my $tabs = @{ $w->{tabs} };
    my %can = ('tab-new' => $tabs < $TRMNL_TABS && @panes < $TRMNL_PANES, 'tab-close' => $tabs > 1, 'tab-next' => $tabs > 1, 'tab-prev' => $tabs > 1, 'tab-left' => $w->{at} > 0, 'tab-right' => $w->{at} < $tabs - 1,
        save => 1, forget => -e trmnl_file() ? 1 : 0, 'split-right' => trmnl_splits($w, 'right'), 'split-down' => trmnl_splits($w, 'down'), "close-pane" => @here > 1 || $tabs > 1, equalise => @here > 1, copy => 1, paste => 1,
        map { ("focus-$_" => trmnl_neighbour($tt, $_) ? 1 : 0, "size-$_" => trmnl_divider_for($tt, $_) ? 1 : 0) } qw(left right up down));
    my @ids = $menu eq 'file' ? qw(tab-new tab-close - tab-next tab-prev tab-left tab-right - save forget)
        : $menu eq 'view' ? qw(split-right split-down - close-pane - focus-left focus-right focus-up focus-down - size-left size-right size-up size-down - equalise)
        : qw(split-right split-down - close-pane - copy paste);
    return map { $_ eq '-' ? '-' : [$_, $can{$_} ? 1 : 0] } @ids;
}

sub trmnl_menu_offered {                  # a menu handed to the window to show at a point of the page; the items it may say back, kept until the next menu or the item chosen
    my ($w, $menu, $x, $y) = @_;
    my @items = trmnl_items($w, $menu);
    $w->{offered} = { map { ref && $_->[1] ? ($_->[0] => 1) : () } @items };
    window("trmnlmenu $x $y\t" . join("\t", map { ref ? "$_->[0]|$TRMNL_SAID{$_->[0]}|$_->[1]" : '-' } @items));
}

sub trmnl_act {                           # [C29] what an item of a menu, or its key, does
    my ($tab, $id) = @_;
    my $w = $tab->{trmnl} or return;
    my $tt = trmnl_shown_tab($w);
    my @here = trmnl_leaves($tt->{tree});
    if ($id =~ /^split-(right|down)$/) { return trmnl_split($tab, $1) }
    if ($id eq 'close-pane') { return trmnl_pane_closed($tab, $tt->{focus}) }    # the last pane of a terminal tab closes the tab, and the last tab stays
    if ($id =~ /^focus-(left|right|up|down)$/) { my $t = trmnl_neighbour($tt, $1) or return; return trmnl_focused($tab, $t) }
    if ($id =~ /^size-(left|right|up|down)$/) {
        my $way = $1;
        my $split = trmnl_divider_for($tt, $way) or return;
        my $i = $split->{split} eq "right" ? 0 : 1;
        trmnl_shared($split, $split->{at} + ($way =~ /left|up/ ? -1 : 1) * $TRMNL_STEP[$i]);
        return trmnl_relaid($tab);
    }
    if ($id eq 'equalise') { trmnl_even($tt->{tree}); return trmnl_relaid($tab) }
    if ($id eq 'tab-new') { return trmnl_tab_added($tab) }
    if ($id eq 'tab-close') { return trmnl_tab_closed($tab, $w->{at}) }
    if ($id =~ /^tab-(next|prev)$/) { return trmnl_tab_chosen($tab, ($w->{at} + ($1 eq 'next' ? 1 : -1)) % @{ $w->{tabs} }) }
    if ($id =~ /^tab-(left|right)$/) {
        my $to = $w->{at} + ($1 eq 'left' ? -1 : 1);
        return unless $to >= 0 && $to < @{ $w->{tabs} };
        @{ $w->{tabs} }[$w->{at}, $to] = @{ $w->{tabs} }[$to, $w->{at}];
        $w->{at} = $to;
        return trmnl_drawn($tab);
    }
    if ($id eq 'save') { return trmnl_saved($tab) }
    if ($id eq 'forget') { unlink trmnl_file(); return aside('The saved tabs and views were forgotten: LZRTRMNL opens one shell from now on.') }
}

sub trmnl_split {                         # [C29] the focused pane split in two: a new shell beside it or under it, in the folder its shell is in, with the focus
    my ($tab, $way) = @_;
    my $w = $tab->{trmnl};
    my $tt = trmnl_shown_tab($w);
    my $old = $tt->{focus};
    return aside("No pane was added: LZRTRMNL holds $TRMNL_PANES panes at most, or this pane has no room for two.") unless trmnl_splits($w, $way);
    my ($t, $why) = trmnl_pane_new($w, trmnl_cwd($old));
    return aside("No pane was added: $why.") unless $t;
    trmnl_replaced($tt, $old, { split => $way, share => 5000, a => $old, b => $t });
    $tt->{focus} = $t;
    trmnl_relaid($tab);
}

sub trmnl_pane_closed {                   # [C29] a pane closed: its shell hung up and its container ended, and the part beside it takes its place and the focus. The last pane of a terminal tab closes the tab
    my ($tab, $t) = @_;
    my $w = $tab->{trmnl};
    my ($i) = grep { my $tt = $w->{tabs}[$_]; grep { $_ == $t } trmnl_leaves($tt->{tree}) } 0 .. $#{ $w->{tabs} };
    return unless defined $i;
    my $tt = $w->{tabs}[$i];
    return trmnl_tab_closed($tab, $i) if $tt->{tree} == $t;
    my $path = trmnl_path($tt->{tree}, $t);
    my ($parent, $side) = @{ $path->[-1] };
    my $other = $parent->{$side eq 'a' ? 'b' : 'a'};
    trmnl_replaced($tt, $parent, $other);
    trmnl_pane_end($t);
    my @near = trmnl_leaves($other);
    $tt->{focus} = $side eq 'a' ? $near[0] : $near[-1] if $tt->{focus} == $t;
    trmnl_relaid($tab);
}

sub trmnl_tab_added {                     # [C29] Add terminal tab: one pane, a new shell in your home folder, after the others and shown
    my ($tab) = @_;
    my $w = $tab->{trmnl};
    return aside("LZRTRMNL holds $TRMNL_TABS terminal tabs at most: close one to add another.") if @{ $w->{tabs} } >= $TRMNL_TABS;
    my ($t, $why) = trmnl_pane_new($w, undef);
    return aside("No terminal tab was added: $why.") unless $t;
    my %used = map { $_->{number} => 1 } @{ $w->{tabs} };
    my $number = 1;
    $number++ while $used{$number};
    push @{ $w->{tabs} }, { tree => $t, focus => $t, number => $number };
    $w->{at} = $#{ $w->{tabs} };
    trmnl_relaid($tab);
}

sub trmnl_tab_closed {                    # [C29] Close current terminal tab, or the x of one: the shells of all its panes hung up. The last one stays: the browser tab is closed instead
    my ($tab, $i) = @_;
    my $w = $tab->{trmnl};
    return aside('This is the last terminal tab of LZRTRMNL: close the browser tab to end it.') if @{ $w->{tabs} } <= 1;
    my ($tt) = splice @{ $w->{tabs} }, $i, 1;
    trmnl_pane_end($_) for trmnl_leaves($tt->{tree});
    $w->{at}-- if $w->{at} > $i || $w->{at} >= @{ $w->{tabs} };
    trmnl_relaid($tab);
}

sub trmnl_tab_chosen { my ($tab, $i) = @_; my $w = $tab->{trmnl}; return if $i == $w->{at}; $w->{at} = $i; delete $w->{press}; trmnl_relaid($tab) }    # a terminal tab shown; the shells of the others run on, drawn when shown again

# Saving and reading the tabs and views. The file is lines of one form each:
#   lzrtrmnl 1
#   at N                      the terminal tab shown, from 0
#   tab NUMBER FOCUS          a terminal tab, in its order: its number, and its focused pane among its panes, from 0
#   split right|down SHARE    a split, its first part's share in ten-thousandths (1 to 9999), then its two parts
#   pane FOLDER               a pane: its shell's working folder, its bytes outside A-Z a-z 0-9 / . _ ~ + - as %XX, or - for none
#   end
sub trmnl_file { return "$DIR/trmnl" }    # in this profile's own folder: never in an incognito or Tor window, where no terminal opens

sub trmnl_cwd {                           # the folder a pane's shell works in now, as the system says it (proc_pidinfo, PROC_PIDVNODEPATHINFO, for a process of yours: no question is asked); the folder it was started in when it cannot say
    my ($t) = @_;
    return $t->{cwd} unless $t->{shell};
    my $info = "\0" x 2352;               # struct proc_vnodepathinfo: the working folder's vnode_info (152 bytes) and its path (1024), then the root's
    return $t->{cwd} unless syscall(336, 2, $t->{shell}, 9, 0, $info, 2352) == 2352;    # proc_info, PROC_INFO_CALL_PIDINFO, PROC_PIDVNODEPATHINFO
    my $cwd = unpack 'Z*', substr($info, 152, 1024);
    return $cwd =~ m{\A/[^\x00-\x1f\x7f]{0,1023}\z} && -d $cwd ? $cwd : $t->{cwd};
}

sub trmnl_tree_lines {                     # the lines of a tree, its splits before their parts
    my ($node) = @_;
    return ("split $node->{split} $node->{share}", map { trmnl_tree_lines($_) } @$node{qw(a b)}) if $node->{split};
    my $cwd = trmnl_cwd($node);
    return "pane " . (defined $cwd ? $cwd =~ s/([^A-Za-z0-9\/._~+-])/sprintf '%%%02X', ord $1/ger : "-");
}

sub trmnl_written {                       # the lines a workspace is saved as
    my ($w) = @_;
    my @lines = ('lzrtrmnl 1', "at $w->{at}");
    for my $tt (@{ $w->{tabs} }) {
        my @leaves = trmnl_leaves($tt->{tree});
        my ($focus) = grep { $leaves[$_] == $tt->{focus} } 0 .. $#leaves;
        push @lines, "tab $tt->{number} " . ($focus // 0), trmnl_tree_lines($tt->{tree});
    }
    return (@lines, 'end');
}

sub trmnl_saved {                         # [C29] Save tabs and views: the workspace written into the plain file trmnl of this profile's folder, in place of what was there
    my ($tab) = @_;
    my $w = $tab->{trmnl};
    my $file = trmnl_file();
    unlink "$file.new";
    return aside('The tabs and views could not be saved: their file could not be written. Nothing was changed.') unless put("$file.new", O_EXCL, trmnl_written($w)) && rename("$file.new", $file);
    synced();
    my @panes = trmnl_panes($w);
    my $tabs = @{ $w->{tabs} };
    noted("LZRTRMNL saved $tabs terminal tabs and " . @panes . ' panes for this profile');
    aside('Saved ' . ($tabs == 1 ? '1 terminal tab' : "$tabs terminal tabs") . ' and ' . (@panes == 1 ? '1 pane' : @panes . ' panes') . ', with their folders: LZRTRMNL opens them so the next time.');
}

sub trmnl_kept {                          # the tabs and views saved for this profile, read and checked; nothing when there are none or they are not of their one form
    sysopen(my $in, trmnl_file(), O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return;
    my @is = stat $in;
    return unless -f _ && $is[4] == $< && $is[7] <= $TRMNL_SAVED;
    my $text = '';
    while (length $text <= $TRMNL_SAVED) { my $got = sysread($in, $text, 16_384, length $text); last unless $got }
    my $kept = length $text <= $TRMNL_SAVED && $text =~ /\n\z/ ? trmnl_read_saved(split /\n/, $text) : undef;
    aside('The saved tabs and views could not be read, so LZRTRMNL opened one shell.') unless $kept;
    return $kept;
}

sub trmnl_read_saved {                    # the saved lines, checked: { at, tabs => [{ number, focus, tree }] } with each pane's folder, or nothing
    my @lines = @_;
    return unless @lines >= 5 && shift(@lines) eq 'lzrtrmnl 1' && pop(@lines) eq 'end';
    my ($at) = shift(@lines) =~ /^at ([0-8])$/ or return;
    my ($panes, @tabs, %numbers) = (0);
    while (@lines) {
        my ($number, $focus) = shift(@lines) =~ /^tab ([1-9]) (0|[1-9][0-9]?)$/ or return;
        return if $numbers{$number}++ || @tabs >= $TRMNL_TABS;
        my $tree = trmnl_tree_read(\@lines, \$panes, 0) or return;
        my @leaves = trmnl_leaves($tree);
        return unless $focus < @leaves;
        push @tabs, { number => 0 + $number, focus => 0 + $focus, tree => $tree };
    }
    return unless $at < @tabs;
    return { at => 0 + $at, tabs => \@tabs };
}

sub trmnl_tree_read {                     # one tree of the saved lines, taken from their front: a split and its two parts, or a pane; nothing past $TRMNL_PANES panes
    my ($lines, $panes, $depth) = @_;
    return if $depth >= $TRMNL_PANES || !@$lines;
    my $line = shift @$lines;
    if ($line =~ /^split (right|down) ([1-9][0-9]{0,3})$/) {
        my ($way, $share) = ($1, 0 + $2);
        my $a = trmnl_tree_read($lines, $panes, $depth + 1) or return;
        my $b = trmnl_tree_read($lines, $panes, $depth + 1) or return;
        return { split => $way, share => $share, a => $a, b => $b };
    }
    my ($said) = $line =~ m{^pane (-|/[A-Za-z0-9/._~+%-]{0,3071})$} or return;
    return if ++$$panes > $TRMNL_PANES;
    return { cwd => undef } if $said eq '-';
    (my $cwd = $said) =~ s/%([0-9A-F]{2})/chr hex $1/ge;
    return unless $cwd =~ m{\A/[^\x00-\x1f\x7f]{0,1023}\z};
    return { cwd => $cwd };
}
