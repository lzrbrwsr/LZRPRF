# The log in the window: this window's lines where a page stands, and under
# them the log on this computer when there is one; one sentence on what is
# kept; the button that clears the log whenever there is one; and, while a
# log is kept, the questions that keep less. The log is cleared by that
# button, and that it was cleared is the first line of the new log.     # [C12]
# No button of the window makes lzrprf keep more: a log is chosen, and full
# addresses are chosen, with "lzrprf keep" in a terminal and in no other
# way. The window's process is the one that tells lzrprf which button was
# pressed, so what it could do by itself, if text it draws took it over, is
# what the buttons can do: keep less, and clear.
# Every question here has the button that keeps less, or changes nothing,
# first, and a question nobody answers counts as that one.
sub log_shown {
    $DRAWN = 0;                           # what the window shows from here on is lzrprf's own, over the page: a fault it says now is not of a page the application drew
    $UNEXPIRED = !expire_log() if $UNEXPIRED;
    my ($mode, $days, $unread) = keeping();
    my ($holds, $count, @lines) = holds_log();
    my $rows = sub { map { my ($when, undef, $what) = split /\t/, s/[^\x20-\x7e\t]/?/gr, 3; "log line $when\t" . (length($what // '') > 600 ? substr($what, 0, 600) . ' ...' : $what // '') =~ s/\t/   /gr } @_ };    # the time, what happened; the number of the run stays in the file
    my @mine = @SESSION > 200 ? @SESSION[-200 .. -1] : @SESSION;
    my $says = "Every address lzrprf fetched for $APP in this window is below" . (@SESSION > @mine ? ', its last ' . @mine . ' lines' : '') . '. ' . kept_words($mode, $days, $unread)
        . ($count ? " The log on this computer holds $holds." . ($count > @lines ? ' Below are its last ' . @lines . ' lines.' : '') . " The whole of it: $DIR/log" . ($mode eq 'nothing' ? ' It was written earlier, and nothing more is added to it.' : '') : '')
        . ($UNMARKED ? ' The log could not be marked for Time Machine to leave it out of backups.' : '');
    undef $UNMARKED;                      # said once
    my $more = $INCOGNITO ? ' No button of this window makes lzrprf keep more.' : $mode eq 'nothing' ? " To keep a log, type in Terminal: perl $SELF keep " . (defined $PROFILE ? "--profile $PROFILE " : '') . "hosts. No button of this window makes lzrprf keep more." : '';    # an incognito window keeps nothing whatever is chosen, and is told nothing of profiles [C16]: the words to type would not be of it
    # The log page of the window, over the page shown, which stays as it is under it: these words, then this
    # window's lines, then the last of the log on this computer. "log shut" closes it again.
    window('log begin', "log note $says$more", 'log part This window', $rows->(@mine), $count ? ('log part On this computer', $rows->(@lines)) : (), 'log end');
    if ($count) {                         # the clear, one click away whenever there is a log on this computer
        window("brief $count " . ($count == 1 ? 'line is' : 'lines are') . ' kept on this computer.');
        if (ask($says, 'Keep the log', 'Clear the log') == 2) {
            window('brief Clear the log? This cannot be undone.');
            return aside('The log was kept.') unless ask("Clear the log? It holds $holds. This cannot be undone.", 'Keep', 'Clear') == 2;
            my $cleared = clear_log();
            window('log shut');
            return idle(!$cleared ? 'The log was not cleared: an address is being fetched right now, or the log could not be written. Nothing was removed.' : $mode eq 'nothing' ? 'The log was cleared: there is no log on this computer now.' : 'The log was cleared. Its first line now says so.');
        }
        $says = 'The log is as it was. ' . kept_words($mode, $days, $unread);
    }
    return aside("$says$more") if $mode eq 'nothing';
    window('brief Kept on this computer: ' . ($mode eq 'all' ? 'full addresses.' : 'hosts only.'));
    return aside($says, 1) unless ask($says, 'Close', 'Keep less') == 2;
    choose_keeping($mode, $days);
    window('log shut');
}

# Keeping less, in the window: full addresses can become hosts only, and
# either can become nothing. Each first button keeps less. What is chosen
# holds from the next request on, and deletes and shortens nothing that is
# on the disk already: that is the button "Clear the log".
sub choose_keeping {
    my ($was, $days) = @_;
    my $log = ask('What is kept after this window closes? A log on this computer lets you look back at what was fetched, and so can anyone who reads your files.', 'Keep nothing', $was eq 'all' ? 'Keep a log' : 'Hosts only, as now') == 2;
    my $full = $log && $was eq 'all' && ask('A log of hosts only holds, for each request, the time, the host, the numeric address and how it ended: no path and no query. Full addresses can hold search words, tokens and invitation links.', 'Hosts only', 'Full addresses, as now') == 2;
    my $mode = !$log ? 'nothing' : $full ? 'all' : 'hosts';    # never more than $was: "all" only from "all", "hosts" only from "all" or "hosts"
    my $lock = keep_lock() or return idle("What is kept was not changed: $DIR/keep.lock could not be taken.");
    my ($now, $left) = keeping();         # read again, under the lock: a question can stand open for minutes, and "lzrprf keep" may have run in that time
    if ($MORE{$mode} >= $MORE{$now}) {    # nothing is written that is not less than what is kept at this moment
        return idle('What is kept is as it was. ' . kept_words($now, $left)) if $now eq $was && $left == $days;
        return idle('What is kept was changed elsewhere while this question was open. Nothing was written here. ' . kept_words($now, $left));
    }
    my (undef, $count) = holds_log();
    my $writing = log_lock() or return idle("What is kept was not changed: $DIR/lock could not be taken.");
    return idle("What is kept was not changed: $DIR/keep could not be written.") unless keep_as($mode, $left);    # the days as they are now: never more of them
    my $told = changed('in the window', $now, $left, $writing);
    idle('From the next request on: ' . kept_words(keeping()) . ($count ? " The log on this computer still holds $count lines written before this choice. They are not deleted or shortened: the Log button offers to clear it." : '')
        . ($told ? '' : ' The log on this computer could not be given the line that says so.'));
}

# A change of what is kept is written down itself: among this window's
# lines, and as a line of the log on this computer when there is one or one
# is kept from now on. So a log says where it stops, or where its lines
# became shorter or longer, and whether a button or the command did it.
sub changed {
    my ($how, $was, $before, $lock) = @_;
    my ($mode, $days) = keeping();
    my $named = sub { $_[0] eq 'nothing' ? 'nothing' : ($_[0] eq 'hosts' ? 'hosts only' : 'full addresses') . ($_[1] ? ", $_[1] days" : ', until cleared') };
    my $line = line("what is kept was changed $how: " . $named->($was, $before) . ' -> ' . $named->($mode, $days));
    push @SESSION, $line;
    return 1 if $mode eq 'nothing' && !-e "$DIR/log";
    $lock //= log_lock() or return 0;
    my $new = !-e "$DIR/log";
    my $size = (-s "$DIR/log") // 0;
    if (!put("$DIR/log", O_APPEND, $line)) { $HALF = ((-s "$DIR/log") // 0) > $size; return 0 }
    excluded("$DIR/log") if $new || !$MARKED++;
    return 1;
}

sub log_lock {                            # one writer of the log at a time. A change of what is kept holds it from the setting to its line, so no line of a request falls between the two
    open my $lock, '>>', "$DIR/lock" or return;
    flock $lock, LOCK_EX or return;
    return $lock;
}

sub keep_lock {                           # one writer of the setting at a time: a window's answers, or "lzrprf keep". Held from reading the setting to the line that says it changed
    open my $lock, '>>', "$DIR/keep.lock" or return;
    flock $lock, LOCK_EX or return;
    return $lock;
}

sub holds_log {                           # what the log on the disk holds, in words; the number of its lines; the last 200 of them
    my ($count, $first, $last, @tail) = (0, '', '');
    my $in;
    if (sysopen($in, "$DIR/log", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) && -f $in) {    # a plain file and no link; a pipe put in its place is not waited for
        while (my $line = <$in>) {
            chomp $line;
            $first = $line unless $count++;
            $last = $line;
            push @tail, $line;
            shift @tail if @tail > 200;
        }
    }
    return ('nothing yet', 0) unless $count;
    return (sprintf('%d lines, %.1f MB, from %s to %s', $count, (-s "$DIR/log") / 1048576, map { /^(\S+)/ ? $1 : '?' } $first, $last), $count, @tail);
}

# What is kept, in a plain settings file of yours, "$DIR/keep": "nothing";
# "hosts" or "all" with a number of days, 0 for until you clear it. Only
# lzrprf writes it, outside every container: "lzrprf keep" for you, and the
# process behind the window after an answer there that keeps less (sub
# choose_keeping, sub keep_as). No container can write a file, and no button
# of the window keeps more. Anything else in that place counts as
# "nothing": no file, a link, a file of another owner or with a second name,
# a file that is not plain, more than one short line, a word or a number
# lzrprf does not take. Returns the mode, the days, and whether the file was
# there and not read.                                                   # [C12]
sub keeping {
    return ('nothing', 0, 0) if $INCOGNITO;    # [C16] its log is in its memory only
    sysopen(my $in, "$DIR/keep", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return ('nothing', 0, -l "$DIR/keep" || -e _);
    my @is = stat $in;
    return ('nothing', 0, 1) unless @is && -f _ && $is[3] == 1 && $is[4] == $< && $is[7] <= 64;
    my $text = '';
    sysread($in, $text, 65) // return ('nothing', 0, 1);
    my ($mode, $days) = $text =~ /^(nothing|hosts|all)(?: ([0-9]{1,4}))?\n?\z/ or return ('nothing', 0, 1);
    return ('nothing', 0, defined $days) if $mode eq 'nothing';
    $days //= $KEPT_DAYS;
    return $days <= $KEPT_MOST ? ($mode, $days + 0, 0) : ('nothing', 0, 1);
}

sub kept_words {                          # what is kept, in one sentence
    my ($mode, $days, $unread) = @_;
    return ($unread ? "$DIR/keep is not a setting lzrprf takes, so: " : '') . 'Nothing is kept after this window closes.' if $mode eq 'nothing';
    return 'Kept on this computer ' . ($days ? "for $days days" : 'until you clear it') . ': ' . ($mode eq 'hosts' ? 'hosts only.' : 'full addresses.');
}

sub keep_as {                             # the settings file, written beside the old one and through to the disk, then given its name in one step
    my ($mode, $days) = @_;
    unlink "$DIR/keep.new";
    sysopen(my $out, "$DIR/keep.new", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) or return 0;
    print($out $mode eq 'nothing' ? "nothing\n" : "$mode $days\n") && $out->flush or return 0;
    return 0 unless ($^O eq 'darwin' ? defined fcntl($out, 51, 0) : $out->sync) && close $out;
    rename "$DIR/keep.new", "$DIR/keep" or return 0;
    synced();
    return 1;
}

sub keep_command {                        # "lzrprf keep": what is kept, in words; or a new setting. The one place where more is chosen
    my ($mode, $days) = @_;
    mkdir $DIR, 0700;
    my @folder = lstat $DIR;
    die "lzrprf: $DIR is not a folder of yours\n" unless @folder && -d _ && $folder[4] == $<;
    my $one = defined $PROFILE ? "--profile $PROFILE " : '';    # the profile it was said of, so the words to type again name it too
    my $choices = "lzrprf keep ${one}nothing\n       lzrprf keep ${one}hosts|all [DAYS]     DAYS from 0 (until you clear it) to $KEPT_MOST, $KEPT_DAYS when it is left out\n";
    my $lock = keep_lock() or die "lzrprf: $DIR/keep.lock could not be taken. Nothing was changed.\n";
    my ($was, $before) = keeping();
    my (undef, $count) = holds_log();
    my $untold;
    if (defined $mode) {
        die "usage: $choices" unless $mode =~ /^(?:nothing|hosts|all)\z/ && (!defined $days || $mode ne 'nothing' && $days =~ /^[0-9]{1,4}\z/ && $days <= $KEPT_MOST);
        my $writing = log_lock() or die "lzrprf: $DIR/lock could not be taken. Nothing was changed.\n";
        keep_as($mode, $days // $KEPT_DAYS) or die "lzrprf: $DIR/keep could not be written. Nothing was changed.\n";
        my ($now, $after) = keeping();
        if (($now ne $was || $after != $before) && !changed('by "lzrprf keep"', $was, $before, $writing)) {    # the line that says so could not be written
            if ($now eq 'nothing') { $untold = 1 }    # keeping nothing is never refused
            else {
                my $half = $HALF;
                my $back = keep_as($was, $before);
                my $noted = $back && $half && changed('back by "lzrprf keep", as the line before this one could not be confirmed on the disk', $now, $after, $writing);
                die "lzrprf: the line that says what was changed could not be " . ($half ? 'confirmed on the disk' : 'written') . " in $DIR/log, so "
                    . (!$back ? "the old setting was to be put back, and that failed too: the change stands unsaid. Look at $DIR/keep"
                        : !$half ? 'nothing was changed'
                        : 'the old setting was put back. The log holds the line of the change' . ($noted ? ', and after it the line that it was put back' : ', and not that it was put back')) . ".\n";
            }
        }
        print 'From the next request on: ';
    }
    my ($now) = keeping();
    print kept_words(keeping()) =~ s/this window closes/a window closes/r, "\n";
    print "Full addresses can hold search words, tokens and invitation links.\n" if $now eq 'all';
    print "The log on this computer still holds $count lines written before this choice. They are not deleted or shortened: the Log button of the window offers to clear it.\n" if defined $mode && $count && $now ne 'all' && $now ne $was;
    print "A log written earlier is still on this computer, $count lines. Nothing more is added to it: the Log button of the window offers to clear it.\n" if !defined $mode && $count && $now eq 'nothing';
    print "The log on this computer could not be given the line that says so.\n" if $untold;
    print "To choose: $choices" unless defined $mode;
}

# The log. Every line is kept in the memory of the process behind the window,
# and there only, unless you chose a kept log: then it is added at the end of
# the log on the disk too, cut to its hosts unless you chose full addresses,
# and this returns true only when the system says the line is on the disk.
# Nothing is looked up or fetched whose line could not be recorded, and no
# answer is shown whose line could not.                                  # [C5]
# Nothing in this file changes or removes a line of the log on the disk but
# your button and the days you chose, and the log has no size at which
# anything is dropped. Each line: the time, the number of the run it belongs
# to, what happened. The log stays on this computer. Nothing in this file
# sends it, or any part of it, anywhere.                                 # [C12]
sub record {
    my ($what, $mode) = @_;
    my $line = line(unlisted($what));    # [C23]
    ($mode) = keeping() unless defined $mode;    # a request reads it once and hands it in: none of its lines is kept at more than that
    my $lock;
    if ($mode ne 'nothing') {
        $lock = log_lock() or return 0;
        my ($now) = keeping();            # read again, under the lock a change of what is kept holds: when less was chosen while this request is open, no line follows the line of that change at more
        $mode = $now if $MORE{$now} < $MORE{$mode};
    }
    if ($mode ne 'nothing') {
        my $new = !-e "$DIR/log";
        put("$DIR/log", O_APPEND, $mode eq 'hosts' ? shortened($line) : $line) or return 0;
        excluded("$DIR/log") if $new || !$MARKED++;    # a new log, and once in each window a log that was there already, such as one an earlier release wrote
    }
    push @SESSION, $line;
    return 1;
}

sub line { strftime('%Y-%m-%dT%H:%M:%SZ', gmtime) . "\t$$\t$_[0]" }    # the time, the run, what happened

# A line of a log of hosts only: every address in it cut to https://host. So
# the disk holds the time, the run, the host, the numeric addresses lzrprf
# connected to and how it ended; no path, no query, no name before an @.
sub shortened { $_[0] =~ s{https://(?:[^/?#\s\@]*\@)?([A-Za-z0-9.-]+)\S*}{https://$1}gr }

# Time Machine leaves out of its backups a file with this mark. That it does
# is Apple's doing and is not tested here. A mark that could not be set
# stops nothing, and the Log button says so once.
sub excluded {
    my ($file) = @_;
    my (undef, $done) = said(5, '/usr/bin/xattr', '-w', '-s', 'com.apple.metadata:com_apple_backup_excludeItem', 'com.apple.backupd', $file);
    $UNMARKED = 1 unless $done;
    return $done;
}

sub put {                                 # lines into a plain file of yours that no link leads elsewhere, and through to the disk
    my ($file, $how, @lines) = @_;
    sysopen(my $out, $file, O_WRONLY | O_CREAT | O_NOFOLLOW | $how, 0600) or return 0;
    my @is = stat $out;
    return 0 unless -f _ && $is[3] == 1 && $is[4] == $<;
    print($out map { /\n\z/ ? $_ : "$_\n" } @lines) && $out->flush or return 0;
    return 0 unless $^O eq 'darwin' ? defined fcntl($out, 51, 0) : $out->sync;    # 51 is F_FULLFSYNC: through the disk's own cache
    return close $out;
}

sub synced { if (open my $folder, '<', $_[0] // $DIR) { $^O eq 'darwin' ? fcntl($folder, 51, 0) : $folder->sync } }    # a change of name, through to the disk too

# Replacing the log: the new log, whose first line says why, is written
# beside the old one and through to the disk, marked for Time Machine, and
# then takes its name in one step. So at no moment is there a log that was
# emptied or shortened without saying so.                                # [C12]
sub replace_log {
    unlink "$DIR/log.new";
    unless (put("$DIR/log.new", O_EXCL, @_)) { unlink "$DIR/log.new"; return 0 }    # what could not be written whole is not left beside the log
    excluded("$DIR/log.new");
    unless (rename "$DIR/log.new", "$DIR/log") { unlink "$DIR/log.new"; return 0 }
    synced();
    return 1;
}

# Clearing: by your button only, and not while a request is between its
# first line and its last. With a kept log the new log's first line says what
# the old one held. When nothing is kept, the log an earlier window or an
# earlier release left is taken away whole.
sub clear_log {
    open my $requests, '>>', "$DIR/busy" or return 0;
    flock $requests, LOCK_EX | LOCK_NB or return 0;
    open my $lock, '>>', "$DIR/lock" or return 0;
    flock $lock, LOCK_EX or return 0;
    my ($holds) = holds_log();
    if ((keeping())[0] eq 'nothing') {
        unlink "$DIR/log.new";            # and what a replacing that failed may have left beside it
        unlink "$DIR/log" or return 0;
        synced();
        push @SESSION, line("you cleared the log: it held $holds");    # no log is left to say so: this window's lines do
        return 1;
    }
    return replace_log(line("you cleared the log: it held $holds"));
}

# The days you chose. At the start of a window, the lines of a kept log that
# are older than that are taken out, the way clearing replaces the log, and
# the new first line says how many and why. With 0 days, or when nothing is
# kept, no line is taken out: a log an earlier release left stays as it is
# until you clear it.                                                    # [C12]
sub expire_log {
    my ($mode, $days) = keeping();
    return 1 if $mode eq 'nothing' || !$days || !-e "$DIR/log";
    open my $requests, '>>', "$DIR/busy" or return 0;
    flock $requests, LOCK_EX | LOCK_NB or return 0;
    open my $lock, '>>', "$DIR/lock" or return 0;
    flock $lock, LOCK_EX or return 0;
    my $before = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime(time - $days * 86400));
    my ($old, @kept) = (0);
    sysopen(my $in, "$DIR/log", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 0;
    return 0 unless -f $in;                # a plain file and no link; a pipe put in its place is not waited for
    while (my $one = <$in>) {
        if ($one =~ /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)\t/ && $1 lt $before) { $old++ } else { push @kept, $one }    # a line without a time is kept
    }
    close $in;
    return 1 unless $old;
    return replace_log(line("lzrprf took out $old lines older than $days days, as you chose"), @kept);
}

sub show {
    my ($mode, $days, $unread) = keeping();
    print 'What is kept: ', kept_words($mode, $days, $unread) =~ s/this window closes/a window closes/r, $mode eq 'all' ? '' : ' The full lines of a window that is open now are in that window only: press its Log button.', "\n";
    print "when (UTC)\trun\twhat you typed, where lzrprf connected for it, and how it ended\n";
    if (open my $in, '<', "$DIR/log") { print <$in> } else { print "(nothing on this computer)\n" }
}

