# Bookmarks. They are files of yours in $DIR/bookmarks: one plain file a
# bookmark, NAME.mark, of two lines, the name it is shown by and its address;
# a folder of bookmarks is a real folder. A file or folder name is plain
# letters, digits, space, dot, underscore and hyphen, never begins with a dot
# or a space, and is at most 64 characters; anything else there is passed
# over, as is a link, something not yours, a file of more than 4 KiB, a line
# that is not in that shape, and an address lzrprf does not fetch (sub
# address). Folders go at most $MARKS_DEEP deep and at most $MARKS_MOST
# bookmarks are read. lzrprf reads them and tells the window the whole tree:
# "marks begin", "mark F FOLDER" for each folder, "mark B N FOLDER\tNAME\tADDRESS"
# for bookmark N, "marks end". The window says "mark open N", "mark remove N"
# or "mark save\tN-or-\tFOLDER\tNAME\tADDRESS", each checked here. A
# bookmark's address came from the window's bar, or was typed into the
# window's own modal [C4]; opening it is a visit like a typed one.
my $MARKS_MOST = 1000;                    # the most bookmarks read: the owner's order of 2026-11-20
my $MARKS_DEEP = 4;                       # how deep folders of bookmarks go: the owner's order of 2026-11-20
my $PART = qr/[A-Za-z0-9_-][A-Za-z0-9 ._-]{0,63}/;    # one name in the bookmarks folder

sub marks_root { kept_in() . '/bookmarks' }    # read, never written, by an incognito window [C16]

# The bookmarks bar shows one folder, "Bookmarks bar" (Chrome's own name for it), and nothing
# else; the star's modal offers it first. Before the bar had a folder of its own it showed the
# bookmarks at the top of the folder, so the first time the folder is read without it, those move
# into it, each by one change of name, and the bar shows what it showed. The folder is made then
# even when there is nothing to move, so a bookmark kept at the top later stays there.
my $BAR = 'Bookmarks bar';                # the owner's order of 2026-11-20

sub marks_into_bar {
    return if $INCOGNITO;                 # [C16]
    my $root = marks_root();
    return unless owned_folder($root);
    my $bar = "$root/$BAR";
    return if -e $bar || -l $bar;
    mkdir $bar, 0700 or return;
    opendir(my $in, $root) or return;
    for my $entry (grep { /^$PART\z/ && /\.mark\z/ } readdir $in) {
        my @is = lstat "$root/$entry" or next;
        rename "$root/$entry", "$bar/$entry" if -f _ && $is[3] == 1 && $is[4] == $<;
    }
    synced();
}

sub owned_folder { my @is = lstat $_[0]; return @is && -d _ && $is[4] == $< }    # a folder of yours, and no link to one

sub marks_read {
    my (@found, @folders);
    marks_walk('', 0, \@found, \@folders) if owned_folder(marks_root());
    return (\@found, \@folders);
}

sub marks_walk {
    my ($folder, $deep, $found, $folders) = @_;
    my $dir = length $folder ? marks_root() . "/$folder" : marks_root();
    for my $entry (order_shown($dir)) {    # in the folder's order (sub order_set)
        last if @$found >= $MARKS_MOST;
        my ($path, $inner) = ("$dir/$entry", length $folder ? "$folder/$entry" : $entry);
        my @is = lstat $path or next;
        if (-d _) {
            next unless $deep < $MARKS_DEEP && $is[4] == $<;
            push @$folders, $inner;
            marks_walk($inner, $deep + 1, $found, $folders);
        } elsif (-f _ && $entry =~ /\.mark\z/ && $is[3] == 1 && $is[4] == $< && $is[7] <= 4096) {
            sysopen(my $file, $path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or next;
            defined sysread($file, my $text, 4097) or next;
            my ($name, $where) = $text =~ /\A([^\n]{1,800})\n([\x21-\x7e]{1,2100})\n?\z/ or next;
            my ($url) = address($where) or next;
            push @$found, [$path, plain_name($name), $url, $folder];
        }
    }
}

sub plain_name {                          # a name to show: at most $TITLE characters, nothing that acts on the display, never empty: what stands for an empty one is given, or "Bookmark"
    my ($name, $instead) = @_;
    no warnings 'utf8';
    utf8::decode($name) or $name =~ s/[^\x00-\x7f]/?/g;
    $name =~ s/(?!\x{200D})[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]//g;
    $name =~ s/(?<!\p{Extended_Pictographic})(?<!\x{FE0F})(?<![\x{1F3FB}-\x{1F3FF}])\x{200D}|\x{200D}(?!\p{Extended_Pictographic})//g;    # the joiner only inside an emoji of several, so that no word holds one unseen (Pay, a joiner, Pal is not PayPal)
    $name =~ s/^[ \p{M}]+| +$//g;
    $name = substr($name, 0, $TITLE);
    $name = $instead // 'Bookmark' unless length $name;
    utf8::encode($name);
    return $name;
}

sub marks_told {
    marks_into_bar();
    my ($found, $folders) = marks_read();
    @MARKS = @$found;
    window('marks begin', (map { "mark F $_" } @$folders), (map { "mark B $_ $MARKS[$_][3]\t$MARKS[$_][1]\t$MARKS[$_][2]" } 0 .. $#MARKS), 'marks end');
}

sub mark_written {                        # a bookmark's two lines into a new file beside its place, then given its place's name in one step
    my ($dir, $file, $name, $url) = @_;
    my $new = "$dir/.new.$$";             # begins with a dot: never read as a bookmark
    unlink $new;
    put($new, O_EXCL, $name, $url) && rename($new, $file) or (unlink($new), return 0);
    synced();
    return 1;
}

sub mark_saved {
    my ($edit, $folder, $name, $where) = @_;
    return idle("$UNKEPT, so no bookmark was added or changed.") if $INCOGNITO;    # [C16]
    return idle("The bookmark was not saved. $REFUSED $REFUSED_HELP") if listed($where);    # [C23] nothing of it is written
    my ($url) = address($where);
    return idle('The bookmark was not saved: lzrprf does not fetch that address. An address must be https, a host by its name, port 443, in plain characters without a space.') unless $url;
    my @parts = length $folder ? split(m{/}, $folder, -1) : ();
    return idle("The bookmark was not saved: a folder is at most $MARKS_DEEP deep, and each name in it is letters, digits, space, dot, underscore or hyphen, not beginning with a dot or a space.") if @parts > $MARKS_DEEP || grep { !/^$PART\z/ } @parts;
    my $old = $edit eq '-' ? undef : $MARKS[$edit] // return idle('The bookmark was not saved: it is no longer there.');
    my ($found) = marks_read();
    return idle("The bookmark was not saved: there are $MARKS_MOST bookmarks already.") if !$old && @$found >= $MARKS_MOST;
    my $dir = marks_root();
    for my $part ('', @parts) {
        $dir .= "/$part" if length $part;
        mkdir $dir, 0700 unless -e $dir || -l $dir;
        return idle("The bookmark was not saved: $dir is not a folder of yours.") unless owned_folder($dir);
        marks_into_bar() unless length $part;    # the top folder may be new: the bar's folder is made before anything is kept at the top
    }
    $name = plain_name($name);
    my $file = mark_file($dir, $name, $old ? $old->[0] : undef) // return idle('The bookmark was not saved: too many of that name.');
    return idle('The bookmark could not be written. Nothing was changed.') unless mark_written($dir, $file, $name, $url);
    unlink $old->[0] if $old && $old->[0] ne $file && -f $old->[0] && !-l $old->[0];
    my ($was_in, $was) = $old ? $old->[0] =~ m{\A(.*)/([^/]+)\z} : ();
    order_set($dir, defined $was_in && $was_in eq $dir ? $was : undef, basename($file)) if !$old || $old->[0] ne $file;    # a new bookmark last in its folder; one renamed in its place; one moved last in its new folder
    marks_told();
    return idle(($old ? 'The bookmark was changed: ' : 'The bookmark was added: ') . "$name, $url.");
}

sub mark_removed {
    my ($n) = @_;
    return idle("$UNKEPT, so no bookmark was removed.") if $INCOGNITO;    # [C16]
    my $mark = $MARKS[$n] // return idle('That bookmark is no longer there.');
    my @is = lstat $mark->[0];
    unlink $mark->[0] if @is && -f _;
    my ($dir, $gone) = $mark->[0] =~ m{\A(.*)/([^/]+)\z};
    order_set($dir, $gone) if defined $dir && -f "$dir/.order";    # its name leaves its folder's order, so a later bookmark of that name is added last
    marks_told();
    return idle("The bookmark was removed: $mark->[1].");
}

sub mark_moved {                          # a bookmark's address made the one its page redirects to, after you said so
    my ($n, $url) = @_;
    my $mark = $MARKS[$n] or return 0;
    return 0 if $INCOGNITO;               # [C16]
    my ($dir) = $mark->[0] =~ m{\A(.*)/[^/]+\z} or return 0;
    mark_written($dir, $mark->[0], $mark->[1], $url) or return 0;
    marks_told();
    return 1;
}

# The window's size and place, kept so the next window opens as this one was left: one line in a
# plain file of yours, frame, "X Y W H" in points from the bottom left of the main screen, or "full"
# when it filled the screen (full screen, or as large as the screen lets it), which opens the next
# window as large as the desktop lets it. An incognito window reads it and writes nothing.    # [C16]
sub frame_kept {
    sysopen(my $in, kept_in() . '/frame', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 'none';
    my @is = stat $in;
    return 'none' unless -f _ && $is[4] == $<;
    defined sysread($in, my $text, 64) or return 'none';
    return $text =~ /\A(full|-?[0-9]{1,5} -?[0-9]{1,5} [1-9][0-9]{1,4} [1-9][0-9]{1,4})\n?\z/ ? $1 : 'none';
}

sub frame_said {
    my ($frame) = @_;
    return if $INCOGNITO || frame_kept() eq $frame;
    unlink "$DIR/frame.new";
    put("$DIR/frame.new", O_EXCL, $frame) && rename("$DIR/frame.new", "$DIR/frame");
    return;
}

sub checked_kept {                       # the last look for a newer release, as checked keeps it, or "never"
    sysopen(my $in, "$ROOT/checked", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 'never';
    my @is = stat $in;
    return 'never' unless -f _ && $is[4] == $<;
    defined sysread($in, my $text, 64) or return 'never';
    return $text =~ /\A([1-9][0-9]{8,10} (?:same|newer) [0-9]{1,6}|[1-9][0-9]{8,10} failed)\n?\z/ ? $1 : 'never';
}

sub checked_said {
    my ($result, $asked) = @_;
    if ($result ne 'none' && !$INCOGNITO) {
        unlink "${\ shared()}/checked.new";
        put("${\ shared()}/checked.new", O_EXCL, time . " $result") && rename("${\ shared()}/checked.new", "${\ shared()}/checked");
    }
    window('checked ' . ($result eq 'none' ? 'none' : $INCOGNITO ? time . " $result" : checked_kept()));
    return 1;
}

sub marks_bar {                           # whether the bookmarks bar is shown: one line "on" in a plain file of yours
    return $HELD_BAR if $INCOGNITO && defined $HELD_BAR;
    sysopen(my $in, kept_in() . '/marksbar', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 0;
    my @is = stat $in;
    return 0 unless -f _ && $is[4] == $<;
    defined sysread($in, my $text, 8) or return 0;
    return $text =~ /\Aon\n?\z/ ? 1 : 0;
}

sub pictures_elsewhere {                  # 1 when pictures from other sites are allowed, as they are until you block them; 0 when one line "block" in a plain file of yours, pictures, says so
    return $HELD_PICTURES if $INCOGNITO && defined $HELD_PICTURES;
    sysopen(my $in, kept_in() . '/pictures', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 1;
    my @is = stat $in;
    return 1 unless -f _ && $is[4] == $<;
    defined sysread($in, my $text, 8) or return 1;
    return $text =~ /\Ablock\n?\z/ ? 0 : 1;
}

# Whether LZRDFNDR's satellite fights in the home page's minigame (H-0071): its switch in the Other tab of
# LZRDFNDR's panel says "game helper on" or "off", and the game page's Activate LZRDFNDR says on. One plain
# file of yours, gamehelper, holds "on" while it is chosen and is removed when it is not; an incognito
# window holds the choice in its memory alone [C16]. The window is told "game helper 1" or "0". The home
# page is started with it (sub contained, LZRPRF_HOME "home satellite"), so a page kept running with the
# other choice is ended and the home shown again: off is off from that moment.
sub game_helper {                         # 1 while LZRDFNDR's satellite plays in the minigame
    return 0 unless part_on('lzrdfndr') && part_on('lzrgm');    # neither plays without both parts
    return $HELD_HELPER if $INCOGNITO && defined $HELD_HELPER;
    sysopen(my $in, kept_in() . '/gamehelper', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 0;
    my @is = stat $in;
    return 0 unless -f _ && $is[3] == 1 && $is[4] == $<;
    defined sysread($in, my $text, 8) or return 0;
    return $text =~ /\Aon\n?\z/ ? 1 : 0;
}

sub game_helper_set {                     # "game helper on" or "off"; $kept: the home page runs on (its Activate LZRDFNDR already let the satellite in)
    my ($on, $kept) = @_;
    my $was = game_helper();
    if ($INCOGNITO) { $HELD_HELPER = $on }
    elsif ($on) { unlink "$DIR/gamehelper.new"; synced() if put("$DIR/gamehelper.new", O_EXCL, 'on') && rename("$DIR/gamehelper.new", "$DIR/gamehelper") }
    elsif (unlink "$DIR/gamehelper") { synced() }
    my $is = game_helper();
    window("game helper $is");
    return if $kept;
    return idle("LZRDFNDR's satellite could not be switched " . ($on ? 'on' : 'off') . ': its setting could not be written.') if $is != $on;
    if ($is != $was) {
        my $home = live_of($TABS[$TAB]);
        my ($wide, $high) = $home && $home->{home} ? ($home->{wide}, $home->{home_high}) : ();
        live_end($_, "LZRDFNDR's satellite was switched " . ($on ? 'on' : 'off'), 1) for grep { $_->{home} } @LIVE;
        home_shown($wide, $high) if $wide;
    }
    return idle($on ? "LZRDFNDR's satellite fights in the home page's minigame." : "LZRDFNDR's satellite stays out of the home page's minigame.");
}

# The order of a bookmarks folder. Each folder may hold one plain file of yours, .order, that names
# what is in it, one name a line, in the order the bar, the folder menus and the bookmarks page show
# it: bookmarks and folders mixed, as Chrome mixes them. Its name begins with a dot, so it is never
# read as a bookmark. A name it holds that is not there is passed over; what is there and not named
# follows the named, by name, as every folder was shown before it had an order. A bookmark added is
# named last; one renamed keeps its place. It is written as every file of the bookmarks is: beside
# its place, then given its name in one step (sub order_set).
my $ORDER = '.order';
my $ORDER_BYTES = 128 * 1024;             # DECLARED(the most of an order that is read: $MARKS_MOST names of at most 64 characters and a line end each is 65,000 bytes; twice that for a folder of folders)

sub order_of {                            # the names an order holds, in order, each once; nothing when there is none
    my ($dir) = @_;
    sysopen(my $in, "$dir/$ORDER", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return;
    my @is = stat $in;
    return unless -f _ && $is[4] == $< && $is[7] <= $ORDER_BYTES;
    defined sysread($in, my $text, $ORDER_BYTES + 1) or return;
    my %seen;
    return grep { /^$PART\z/ && !$seen{$_}++ } split /\n/, $text;
}

sub order_shown {                         # what a folder shows, in its order: the named first, then the rest by name
    my ($dir) = @_;
    opendir(my $in, $dir) or return;
    my %there = map { $_ => 1 } grep { /^$PART\z/ } readdir $in;
    return ((grep { delete $there{$_} } order_of($dir)), sort keys %there);
}

sub order_set {                           # a folder's order written: what it named, with one old name replaced by the new ones, then the rest by name, then the new ones not placed yet
    my ($dir, $old, @new) = @_;
    opendir(my $in, $dir) or return 0;
    my %there = map { $_ => 1 } grep { /^$PART\z/ } readdir $in;
    my %new = map { $_ => 1 } @new;
    my @names = grep { delete $there{$_} } map { defined $old && $_ eq $old ? @new : $_ } order_of($dir);
    push @names, grep { !$new{$_} && delete $there{$_} } sort keys %there;
    push @names, grep { delete $there{$_} } @new;
    unlink "$dir/$ORDER.new";
    put("$dir/$ORDER.new", O_EXCL, @names) && rename("$dir/$ORDER.new", "$dir/$ORDER") or (unlink("$dir/$ORDER.new"), return 0);
    synced();
    return 1;
}

sub mark_file {                           # the file a bookmark of this name gets in that folder: its own name kept to plain characters, numbered when it is taken; nothing when 999 of it are
    my ($dir, $name, $old) = @_;
    my $base = substr($name =~ s/[^A-Za-z0-9 ._-]/_/gr =~ s/^[ .]+//r, 0, 50) =~ s/ +\z//r;
    $base = 'bookmark' unless length $base;
    my $file = "$dir/$base.mark";
    for (my $n = 2; (defined $old ? $file ne $old : 1) && (-e $file || -l $file); $n++) { return if $n > 999; $file = "$dir/$base $n.mark" }
    return $file;
}

