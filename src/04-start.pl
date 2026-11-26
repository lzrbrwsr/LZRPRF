# The start. The process that was started becomes the window, so that the
# system shows it under the application's name. Its child is a fresh copy of
# this file, outside every container, and the two talk over two pipes.
sub run {
    my ($program, @arguments) = @_;
    seal();
    $ROOT = $DIR;
    $TIMED = $TRY && -e "$ROOT/times";
    timed('perl');
    $program = abs_path($program // '') // '';
    die "lzrprf: no such program\n" unless -f $program && -x _;
    named($program, @arguments);
    mkdir $DIR;
    my @folder = lstat $DIR;
    die "lzrprf: $DIR is not a folder of yours\n" unless @folder && -d _ && $folder[4] == $<;
    chmod 0700, $DIR;
    runs_swept($DIR);
    swept();                              # [C16] the folder of an incognito run that ended without removing it, at every start
    $TOR_WINDOW ||= $TRY && -e "$ROOT/tor";    # "lzrprf try" only: a file "tor" in the test's folder makes the run a Tor window [C17]
    $INCOGNITO ||= $TOR_WINDOW || $TRY && -e "$ROOT/incognito";    # a Tor window is an incognito window, and more    # "lzrprf try" only: a file "incognito" in the test's folder makes the run an incognito one, the test's folder standing for ~/.lzrprf
    if ($TRY && open my $named, '<', "$ROOT/profile") { $PROFILE = <$named> // ''; chomp $PROFILE }    # "lzrprf try" only: a file "profile" in the test's folder holds the id the run opens, as --profile does
    profile_entered() if defined $PROFILE;    # a profile's window: its own folder from here on, and the state folder for what belongs to the installation
    incognito_begun() if $INCOGNITO;      # opened from a profile's window, its settings are read from that profile's folder alone
    put("$DIR/torwindow", O_EXCL, "1\n") || die "lzrprf: the Tor window could not mark its folder, so nothing was started\n" if $TOR_WINDOW;    # [C17] what the process behind the window reads to know it is one
    $SIG{PIPE} = 'IGNORE';
    if ($TRY && open my $pull, '<', "$ROOT/open") { ($OPEN) = opened_with($pull, '--open', '0 0 400 300', $program) }    # "lzrprf try" only: a file "open" in the test's folder holds the line a pulled tab's window reads on standard input
    if ($TRY && $ANSWER ne 'ask') {       # "lzrprf try" only: no window
        @EVENTS = ('start ' . ($OPEN // '-'), 'ready', $TYPED eq '-' ? () : map { /^=(.+)/ ? $1 : "go $_" } split /,,/, $TYPED);
        return behind();
    }
    pipe(my $window_in, my $to) && pipe(my $from, my $window_out) or die "lzrprf: cannot make a pipe: $!\n";
    my $window = $$;
    my $behind = fork // die "lzrprf: cannot fork: $!\n";
    become($from, $to, $TRY ? \*STDOUT : undef, '/usr/bin/perl', $SELF, 'behind', $TRY, defined $PROFILE && !$INCOGNITO ? $ROOT : $DIR, $PEER, $ANSWER, $window, $INCOGNITO ? $ROOT : '-', $PROFILE // '-', $program, @arguments) unless $behind;    # descriptor 0 is what the window says, descriptor 1 what it is told; a profile by its id alone, never by its name, and behind finds its folder from the state folder
    close $_ for $to, $from;
    my $more = window_pointer_text() . window_trmnl_text() . window_link_text() . window_menu_text() . window_inspect_text() . window_website_text();    # the pointer over a page kept running (28-window-pointer.pl), and [C29] the part of the window a terminal's tab alone uses (24-trmnl-window.pl), after the rest of it
    if ($TRY && open my $test, '<', "$ROOT/window") { local $/; $more .= <$test> }    # "lzrprf try" only: the test's own text after the window's, so a test can keep the window off the screen and read what it holds
    die "lzrprf: the home folder's path holds a character lzrprf does not pass on\n" if $HOME =~ /["\\\n]/;
    syswrite $window_out, 'start ' . ($OPEN // '-') . "\n";    # the first line behind hears, written here before the window is made, so the window can neither say it nor read it: the address a pulled tab's window opens (sub started)
    become($window_in, $window_out, $TRY ? \*STDERR : undef, '/usr/bin/sandbox-exec', '-D', "HOME=$HOME", '-p', $WINDOW_CONTAINER, $SCRIPT, '-l', 'JavaScript', '-e', window_text() . window_sound_text() . $more, $APP, ($TOR_WINDOW ? 'tor' : $INCOGNITO ? 'incognito' : 'window') . (defined $OPEN_FRAME ? '+' : ''), $OPEN_FRAME // frame_kept());    # T5: a window a tab was pulled out into is told so by a "+" after its kind, and runs without a Dock icon of its own    # the size and place the last window was left at (sub frame_kept), so it opens there and does not jump; a pulled tab's window opens where the tab was let go
}

sub runs_swept {                          # what runs that have ended left in a folder: a request's socket, the folder of the tries at the start
    my ($folder) = @_;
    for my $old (bsd_glob("$folder/way.*"), bsd_glob("$folder/tries.*")) {
        next if $old =~ /\.(\d+)$/ && kill 0, $1;
        unlink bsd_glob("$old/*"), $old;
        rmdir $old;
    }
}

# An incognito window [C16]. Its folder is made the way mkdtemp makes one: a
# name with 12 random hex digits, made by one mkdir that fails when the name is
# taken, readable by you alone, in your own temporary folder. Its name holds the
# number of the window's process, so a later start can tell a folder whose run
# has ended. A third process, the sweeper, outlives the window and the process
# behind it: it ignores the signals a terminal sends, waits for both to be gone
# and removes the folder. The process behind the window removes it too when it
# leaves, on a signal among them. A run killed whole, the sweeper with it,
# leaves the folder to the next start (sub swept).
sub temp_folder {                         # your own temporary folder: TMPDIR when it is a folder of yours that nobody else may read, else the one of yours under /private/var/folders
    my @found = grep { defined && m{^/[\x21-\x7e]+\z} } map { abs_path($_) } grep { defined && length } $ENV{TMPDIR}, bsd_glob('/private/var/folders/*/*/T');
    for my $temp (@found) {
        my @is = lstat $temp;
        return $temp if @is && -d _ && $is[4] == $< && !($is[2] & 0077);
    }
    return;
}

sub swept {                               # [C16] incognito folders of runs whose window process is gone
    my $temp = temp_folder() // return;
    for my $old (bsd_glob("$temp/lzrprf-i.*")) {
        my ($pid) = $old =~ m{/lzrprf-i\.(\d+)\.[0-9a-f]{12}\z} or next;
        my @is = lstat $old;
        next unless @is && -d _ && $is[4] == $<;
        next if kill(0, $pid) || $!{EPERM};    # its window, or a process of that number, is still there
        removed($old);
    }
}

sub removed {                             # an incognito folder, whole; nothing else is ever removed by this
    my ($folder) = @_;
    return unless $folder =~ m{/lzrprf-i\.\d+\.[0-9a-f]{12}\z} && -d $folder && !-l $folder;
    remove_tree($folder, { safe => 0, keep_root => 0 });
}

sub incognito_begun {
    my $temp = temp_folder() // die "lzrprf: no temporary folder of yours was found that nobody else may read, so no incognito window was started\n";
    my $folder;
    for (1 .. 8) {
        open my $random, '<:raw', '/dev/urandom' or last;
        read($random, my $bytes, 6) == 6 or last;
        my $try = "$temp/lzrprf-i.$$." . unpack('H*', $bytes);
        if (mkdir $try, 0700) { $folder = $try; last }
    }
    die "lzrprf: the incognito window's folder could not be made in $temp, so nothing was started\n" unless $folder;
    ($BASE, $DIR, $INCOGNITO) = ($DIR, $folder, 1);
    my $window = $$;
    my $sweeper = fork // do { removed($folder); die "lzrprf: cannot fork: $!\n" };
    return if $sweeper;
    $SIG{$_} = 'IGNORE' for qw(INT TERM HUP QUIT PIPE);    # a terminal's Ctrl-C or its closing ends the window, not the one that cleans after it
    POSIX::setsid();
    my $nowhere = POSIX::open('/dev/null', O_RDWR);
    POSIX::dup2($nowhere, $_) for 0 .. 2;
    seal();
    put("$folder/sweeper", O_EXCL, $$);    # its number, for a test that ends it too
    select undef, undef, undef, 0.25 while getppid() == $window;    # the window is this process's parent until it is gone
    if (open my $held, '<', "$folder/held") { flock $held, LOCK_EX }    # the process behind the window holds this while it lives
    removed($folder);
    POSIX::_exit(0);
}

sub incognito_opened {                    # "New Incognito Window": a second lzrprf, of its own, in incognito
    return idle($GONE) if defined $PROFILE && !profile_folder($PROFILE);    # the profile it reads was removed while this window was open: a window started now would end at its first check, so none is started and that is said
    return idle('A new incognito window was asked for: "lzrprf try" starts none.') if $TRY;
    return idle('No incognito window was started: lzrprf could not start a process.') unless apart(undef, '/usr/bin/perl', $SELF, 'incognito', defined $PROFILE ? ('--profile', $PROFILE) : (), $PROGRAM, @ARGUMENTS);    # it reads the settings of this window's profile, named by its id alone
    return idle('An incognito window is opening. It writes nothing: when it closes, it leaves nothing behind.');
}

sub window_opened {                       # File > New Window: a second lzrprf, of its own, started as "New Incognito Window" starts one, not incognito
    return idle('A new window was asked for: "lzrprf try" starts none.') if $TRY;
    return idle("No window was opened: this window has opened $PULLED_MOST windows from its tabs, profiles and File menu, the most one window may. Open it from another window.") if $PULLED >= $PULLED_MOST;
    return idle('No window was opened: lzrprf could not start a process.') unless apart(undef, '/usr/bin/perl', $SELF, 'run', defined $PROFILE ? ('--profile', $PROFILE) : (), $PROGRAM, @ARGUMENTS);    # this window's profile, by its id alone
    $PULLED++;
    return idle('A new window is opening.');
}

sub help_opened {                         # Help > Privacy Policy or Terms and Conditions: the page of the site the installer comes from, in a new tab, so the text is the web's own
    my ($which) = @_;
    my (undef, undef, undef, $installer) = beside();
    my ($site) = ($installer // '') =~ m{^(https://[A-Za-z0-9.-]{1,253})/};
    return idle('This application names no site, so it has no privacy policy or terms to open.') unless $site;
    tabbed('new');
    go("$site/$which.html", $which eq 'privacy' ? 'you opened the privacy policy from the Help menu' : 'you opened the terms and conditions from the Help menu');
}

sub apart {                               # a second lzrprf, of its own, that goes through every start check itself; true when it was started. A line given is its standard input, then closed
    my ($line, @command) = @_;
    my ($from, $to);
    pipe($from, $to) or return 0 if defined $line;
    my $child = fork // return 0;
    if (!$child) {
        POSIX::setsid();
        my $grandchild = fork // POSIX::_exit(1);
        POSIX::_exit(0) if $grandchild;   # so the window started is nobody's child here, and leaves nothing to wait for
        become($from, undef, undef, @command);
    }
    if ($to) {                            # one line, at most 2101 bytes, fits in the pipe at once: nothing waits on the reader
        close $from;
        local $SIG{PIPE} = 'IGNORE';
        syswrite $to, "$line\n";
        close $to;
    }
    waitpid $child, 0;
    return $? == 0;
}

# A tab pulled out of the strip and let go away from it: "tab out N X Y W H", N a tab that is
# there and the rest the frame of its new window, in the form of a kept frame. A second lzrprf
# is started for it as "New Incognito Window" starts one, and goes through every start check of
# its own: it is handed the frame as an argument and the tab's address as one line on its
# standard input, nothing else; the address is never an argument, which every user of the
# computer can read in the list of processes for as long as the window lives. A tab of an incognito window opens an incognito
# window, and a tab of a profile's window a window of the same profile. The tab then closes here;
# it is not one of the closed tabs to reopen, since it still shows. The last tab is never pulled
# out: let go away, its own window is put there by the window, and no "tab out" is said. One window opens at most $PULLED_MOST windows this way and from
# the Profiles list together in its life.
sub tab_out {
    my ($n, $frame) = @_;
    return if $n >= @TABS || @TABS < 2;
    my ($url) = address($TABS[$n]{url} // '');
    my $stays = $TABS[$n]{trmnl} ? 'The tab stays here: a terminal does not move to another window, as its shell is a process of this one.'    # [C29]
        : $PULLED >= $PULLED_MOST ? "The tab stays here: this window has opened $PULLED_MOST windows from its tabs and profiles, the most one window may. Open a new window for more."
        : defined $PROFILE && !profile_folder($PROFILE) ? "The tab stays here. $GONE"
        : !$TRY && !apart($url // '', pulled_command($frame)) ? 'The tab stays here: lzrprf could not start a process for its new window.' : '';
    if (length $stays) {
        window('tabs ' . @TABS . " $TAB", map { "title $_ $TABS[$_]{title}" } 0 .. $#TABS);    # the strip shows the tab again
        return idle($stays);
    }
    $PULLED++;
    tabbed('close', $n, undef, 1);
    idle('A tab pulled out opens a new window: "lzrprf try" starts none.') if $TRY;
}

sub pulled_command { my ($frame) = @_; return ('/usr/bin/perl', $SELF, $TOR_WINDOW ? 'tor' : $INCOGNITO ? 'incognito' : 'run', defined $PROFILE ? ('--profile', $PROFILE) : (), '--open', $frame, $PROGRAM, @ARGUMENTS) }    # the new window's lzrprf, started as this one was, in this window's profile by its id, and no address in it

# "--open FRAME" before the program (sub pulled_command), the frame in the form of a kept frame,
# and one line read from $in (standard input): an address checked as a typed one, or an empty
# line for none, at most 2100 characters. Returns the address (undef for none), the frame and the
# program with its arguments; anything else ends the start here.
sub opened_with {
    my ($in, undef, $frame, @rest) = @_;
    my $url = '';
    my $one;
    while (length $url <= 2100) { (read($in, $one, 1) // 0) == 1 && $one ne "\n" or last; $url .= $one }
    die "lzrprf: --open takes a frame \"X Y W H\", then the program, and an address lzrprf fetches or an empty line on standard input\n"
        unless defined $frame && @rest && length $url <= 2100 && (!length $url || (address($url))[0]) && $frame =~ /\A-?[0-9]{1,5} -?[0-9]{1,5} [1-9][0-9]{1,4} [1-9][0-9]{1,4}\z/;
    return (length $url ? (address($url))[0] : undef, $frame, @rest);
}

