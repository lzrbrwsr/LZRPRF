# The application's tool, opened by its icon at the right end of the strip.
# lzrprf looks at this computer with the system's own programs: its processes
# (ps), the launchd jobs of your account and of the system (launchctl, and
# the property lists of the three LaunchAgents and LaunchDaemons folders,
# read with plutil), and who signed their programs (codesign). What it saw
# goes to the application in its container, as an answer does for a page: no
# network and no file, so nothing of the look leaves this computer. The
# application answers with a list, and lzrprf holds every line of it to its
# own rules before the window is given it (sub tool_checked, sub tool_may).
# A look changes nothing. A change is made only for a row you ticked and then
# confirmed in the window, where each change is said in lzrprf's own words,
# and each is written in the log first: a launchd job of your account is
# switched off (launchctl disable, then bootout), a process of yours is asked
# to end (TERM). Never a job or a process of the system or of Apple, never
# lzrprf's own, never with a password. A job you switched off is kept in
# ~/.lzrprf/quieted, looked at again at each start and every $TOOL_WATCH
# seconds while a window is open, switched off again when it came back, and
# switched on again when you say so (launchctl enable, then bootstrap). An
# incognito window has no tool: it would write.                     # [C20]
my $TOOL_ROWS = 200;                      # DECLARED([C20] the most rows the application may name: more than a list a person ticks through)
my $TOOL_ACTS = 12;                       # DECLARED([C20] the most changes of one row: a product with a dozen jobs and helpers)
my $TOOL_PROCS = 4000;                    # DECLARED([C20] the most processes of one look that are handed on: several times what a busy Mac runs)
my $TOOL_FILES = 400;                     # DECLARED([C20] the most property lists read in one folder of launchd jobs)
my $TOOL_SIGNED = 80;                     # DECLARED([C20] the most programs whose signature is read anew in one look, each about a twentieth of a second of codesign; what one look left out the next reads)
my $TOOL_ASKED = 40;                      # DECLARED([C20] the most loaded jobs with no property list in the three folders that launchd is asked about one by one)
my $TOOL_WATCH = 300;                     # DECLARED([C20] seconds between two looks at the jobs you switched off, while a window is open)
my $TOOL_LABEL = qr/[A-Za-z0-9][A-Za-z0-9._-]{0,199}/;    # a launchd label lzrprf acts on: one written any other way is listed nowhere and never acted on
my (%TOOL, %TOOL_SIGN, %TOOL_FILE);       # the last look (its processes, jobs and rows); the signatures and the property lists read already, each by its file's time and size
my $TOOL_LOOKED;                          # when the jobs you switched off were last looked at; nothing before the first look of a window
my $TOOL_MANS = 800;                      # DECLARED([C20] the most names of programs whose manual page is read in one look for Show all processes: more than the programs a busy Mac runs at once)
my $TOOL_NOTE = 500;                      # DECLARED([C20] the most characters of one note you write to a process: a few sentences, as a cell of the list holds)
my $TOOL_NOTES = 2000;                    # DECLARED([C20] the most notes kept in procnotes: more programs than a Mac holds)
my (%TOOL_MAN, $TOOL_ALL);               # the manual pages read already, each by the name of its program; whether the window shows every process (its last look was "tool all")

sub tool_stand { my $stand = "$ROOT/toolstand"; return $TRY && -d $stand ? $stand : undef }    # "lzrprf try" only: a folder whose files stand for what the system's programs say, so a test acts on no real job and no real process
sub tool_asked {                          # what one of the system's programs says, and whether it ended well
    my ($name, $seconds, @command) = @_;
    my $stand = tool_stand() // return said($seconds, @command);
    open my $in, '<', "$stand/$name" or return ('', 0);
    local $/;
    return (scalar(<$in>) // '', 1);
}
sub tool_ran {                            # [C20] a change, made by one of the system's programs; a test's stand-in notes it and changes nothing
    my ($note, @command) = @_;
    my $stand = tool_stand() // return (said(10, @command))[1];
    return put("$stand/done", O_APPEND, $note);
}
sub tool_plain {                          # text of the system as one line of at most $most bytes: no control character, and UTF-8 or plain ASCII
    my ($text, $most) = @_;
    utf8::encode($text) if utf8::is_utf8($text);
    $text =~ s/[\x00-\x1f\x7f]/ /g;
    if (length $text > $most) { $text = substr($text, 0, $most); $text =~ s/[\xc0-\xff][\x80-\xbf]*\z// }    # not cut inside a character
    my $copy = $text;
    $text =~ s/[^\x20-\x7e]/?/g unless utf8::decode($copy);
    return $text;
}
sub tool_text {                           # [C20] text of the application, shown as text and nowhere acted on: 1 to $most characters, none a control or format character
    my ($text, $most) = @_;
    no warnings 'utf8';
    my $copy = $text;
    return unless utf8::decode($copy) && length $copy >= 1 && length $copy <= $most && $copy !~ /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]/;
    return $text;
}
sub tool_places {                         # where launchd jobs are written down: [whose, folder]; the first two are your account's
    if (defined(my $stand = tool_stand())) { return (['gui', "$stand/agents"], ['system', "$stand/daemons"]) }
    return (['gui', "$HOME/Library/LaunchAgents"], ['gui', '/Library/LaunchAgents'], ['system', '/Library/LaunchDaemons']);
}
sub tool_services {                       # of what launchctl prints of a domain: the jobs loaded there, each with its process (0: none runs), and the jobs switched off there
    my ($said) = @_;
    my (%loaded, %off);
    my ($block) = $said =~ /^\tservices = \{\n(.*?)^\t\}/ms;
    for (split /\n/, $block // '') { $loaded{$2} = $1 if /^\s+(\d+)\s+\S+\s+(\S+)\s*$/ }
    my ($set) = $said =~ /^\tdisabled services = \{\n(.*?)^\t\}/ms;
    for (split /\n/, $set // '') { $off{$1} = 1 if /^\s+"([^"]+)" => disabled\s*$/ }
    return (\%loaded, \%off);
}
sub tool_file {                           # a launchd property list: its label, the program it runs, that program's arguments, and when it runs (R at load, K kept alive, I on an interval, C by the calendar)
    my ($file) = @_;
    my @is = stat $file or return;
    return unless -f _ && $is[7] <= 1024 * 1024;
    my $key = "$is[9] $is[7]";
    return @{$TOOL_FILE{$file}[1]} if $TOOL_FILE{$file} && $TOOL_FILE{$file}[0] eq $key;
    my ($text, $ok) = said(5, '/usr/bin/plutil', '-convert', 'json', '-o', '-', '--', $file);
    my $list = $ok ? import_json($text) : undef;
    my @got;
    if (ref $list eq 'HASH') {
        my @args = ref $list->{ProgramArguments} eq 'ARRAY' ? grep { defined && !ref } @{$list->{ProgramArguments}} : ();
        my $flags = join '', map { $list->{$_->[0]} ? $_->[1] : () } [RunAtLoad => 'R'], [KeepAlive => 'K'], [StartInterval => 'I'], [StartCalendarInterval => 'C'];
        my $first = @args ? $args[0] : undef;    # read into a name of its own: $args[0] in a list given to grep would make that element when @args is empty, and the join would warn of it
        @got = ($list->{Label}, (grep { defined && !ref } $list->{Program}, $first, $list->{BundleProgram}, '')[0], join(' ', @args), $flags);
    }
    else {                                # a list with a date or data in it, which is no JSON: its label and its program are asked for one by one
        my @one = map { my ($said, $there) = said(5, '/usr/bin/plutil', '-extract', $_, 'raw', '-o', '-', '--', $file); chomp $said; $there ? $said : undef } 'Label', 'Program', 'ProgramArguments.0';
        @got = ($one[0], $one[1] // $one[2] // '', '', '');
    }
    @got = defined $got[0] && !ref $got[0] && $got[0] =~ /^$TOOL_LABEL\z/ ? ($got[0], tool_plain($got[1], 1000), tool_plain($got[2], 400), $got[3]) : ();
    $TOOL_FILE{$file} = [$key, \@got];
    return @got;
}
sub tool_signed {                         # who signed these programs, as codesign says: [path, the team (or "adhoc", "none", "-"), the identifier]
    my @paths = @_;
    my (%key, @ask);
    for my $path (@paths) {
        my @is = stat $path or next;
        $key{$path} = "$is[9] $is[7]";
        push @ask, $path if @ask < $TOOL_SIGNED && !($TOOL_SIGN{$path} && $TOOL_SIGN{$path}[0] eq $key{$path});
    }
    if (@ask) {
        my %asked = map { $_ => 1 } @ask;
        my ($said) = tool_asked('sign', 60, '/bin/sh', '-c', 'for p; do printf "=%s\n" "$p"; "$0" -dv --verbose=2 "$p" 2>&1; done', '/usr/bin/codesign', @ask);
        for my $part (split /^=/m, $said) {
            my ($path, $rest) = split /\n/, $part, 2;
            next unless defined $path && $asked{$path};
            $rest //= '';
            my ($team) = $rest =~ /^TeamIdentifier=([A-Za-z0-9]{1,20})$/m;
            my ($name) = $rest =~ /^Identifier=([\x21-\x7e]{1,200})$/m;
            $team //= $rest =~ /^Signature=adhoc$/m ? 'adhoc' : $rest =~ /not signed at all/ ? 'none' : '-';
            $TOOL_SIGN{$path} = [$key{$path}, $team, $name // '-'];
        }
    }
    return map { $TOOL_SIGN{$_} && $TOOL_SIGN{$_}[0] eq $key{$_} ? [$_, @{$TOOL_SIGN{$_}}[1, 2]] : () } grep { defined $key{$_} } @paths;
}
sub tool_kept {                           # [C20] the launchd jobs you switched off here: [label, its property list or nothing, when]
    open my $in, '<', "${\ shared()}/quieted" or return [];
    return [map { chomp; my @one = split /\t/, $_, -1; @one == 3 && $one[0] =~ /^$TOOL_LABEL\z/ && $one[1] =~ m{^(?:/[\x20-\x7e]{1,1000})?\z} && $one[2] =~ /^[0-9TZ:-]{1,30}\z/ ? [@one] : () } <$in>];
}
sub tool_keep {                           # [C20] that list, written beside the old one and through to the disk, then given its name in one step
    my ($kept) = @_;
    unlink "${\ shared()}/quieted.new";
    if (!@$kept) { return !-e "${\ shared()}/quieted" || unlink "${\ shared()}/quieted" }
    unless (put("${\ shared()}/quieted.new", O_EXCL, map { join "\t", @$_ } @$kept) && rename "${\ shared()}/quieted.new", "${\ shared()}/quieted") { unlink "${\ shared()}/quieted.new"; return 0 }
    synced(shared());
    return 1;
}

# One look. With $full, everything named above; without, only the jobs you
# switched off, which is all the tool needs to open. What is handed to the
# application is lines of text: "me", "proc", "open" (an app that is open
# now), "job", "sign" and "kept". What lzrprf itself saw is held in %TOOL,
# and a change is made against that, never against the application's word.
sub tool_look {
    my ($full) = @_;
    my (%procs, %jobs, %own, %open, @lines);
    my $kept = tool_kept();
    if ($full) {
        my ($list, $listed) = tool_asked('procs', 10, '/bin/ps', '-axww', '-o', 'pid=,ppid=,uid=,lstart=,comm=');
        return unless $listed;
        for (split /\n/, $list) {
            my ($pid, $ppid, $owner, $began, $path) = /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+\s+\S+\s+\d+\s+[\d:]+\s+\d+)\s+(.*?)\s*$/ or next;
            last if keys %procs >= $TOOL_PROCS;
            $procs{$pid} = { ppid => $ppid, uid => $owner, began => $began =~ s/\s+/ /gr, path => tool_plain($path, 1000), args => '' };
        }
        my ($args) = tool_asked('args', 10, '/bin/ps', '-axww', '-o', 'pid=,args=');
        for (split /\n/, $args) { my ($pid, $rest) = /^\s*(\d+)\s+(.*)$/ or next; $procs{$pid}{args} = tool_plain($rest, 400) if $procs{$pid} }
        for (my $up = $$; $up > 1 && $procs{$up} && !$own{$up}; $up = $procs{$up}{ppid}) { $own{$up} = 1 }    # lzrprf's own: this process and what started it, up to launchd
        my %mine = ($$ => 1);
        for (my $grew = 1; $grew;) { $grew = 0; for (keys %procs) { next if $mine{$_} || !$mine{$procs{$_}{ppid}}; $mine{$_} = $own{$_} = $grew = 1 } }    # and all it started: the window's pages, their keepers, the Tor client
        my ($gui, $gui_said) = tool_asked('jobs', 10, '/bin/launchctl', 'print', "gui/$<");
        return unless $gui_said;
        my ($system) = tool_asked('system', 10, '/bin/launchctl', 'print', 'system');
        my %in = (gui => [tool_services($gui)], system => [tool_services($system)]);
        for my $place (tool_places()) {
            my ($domain, $folder) = @$place;
            opendir(my $dir, $folder) or next;
            my @names = sort grep { /\.plist\z/ && !/[\x00-\x1f\x7f]/ } readdir $dir;
            closedir $dir;
            splice @names, $TOOL_FILES if @names > $TOOL_FILES;
            for my $name (@names) {
                my ($label, $program, $with, $flags) = tool_file("$folder/$name") or next;
                next if $jobs{$domain}{$label};
                my ($loaded, $off) = @{$in{$domain}};
                $jobs{$domain}{$label} = { pid => $loaded->{$label} // 0, state => exists $loaded->{$label} ? ($loaded->{$label} ? 'run' : 'load') : $off->{$label} ? 'off' : 'file',
                    program => $program, file => tool_plain("$folder/$name", 1000), flags => $flags . ($off->{$label} ? 'D' : ''), args => $with };
            }
        }
        my $asked = 0;
        for my $domain ('gui', 'system') {    # what is loaded and written down in none of the three folders: an open app, or a job an app registered from inside itself
            my ($loaded, $off) = @{$in{$domain}};
            for my $label (sort keys %$loaded) {
                next if $jobs{$domain}{$label} || $label =~ /^com\.apple\./ || $label !~ /^$TOOL_LABEL\z/;
                if ($label =~ /^application\.(.+?)\.\d+\.\d+\z/) { $open{$1} = 1; next }
                my ($one) = $asked++ < $TOOL_ASKED ? tool_asked("job.$label", 5, '/bin/launchctl', 'print', ($domain eq 'gui' ? "gui/$<" : 'system') . "/$label") : ('');
                my ($program) = $one =~ /^\tprogram = (.+)$/m;
                $jobs{$domain}{$label} = { pid => $loaded->{$label}, state => $loaded->{$label} ? 'run' : 'load', program => tool_plain($program // '', 1000), file => '', flags => $off->{$label} ? 'D' : '', args => '' };
            }
        }
        my $ours = qr{^/(?:System|bin|sbin|usr(?!/local/)|Library/Apple)/};    # the system's own programs: Apple signed them, and they are never changed here
        my (%want, @want);
        for my $path ((map { $_->{program} } map { values %$_ } values %jobs), map { $_->{path} =~ m{^(/.*?\.app)/} ? $1 : $_->{path} } @procs{sort { $a <=> $b } keys %procs}) {
            push @want, $path if $path =~ m{^/} && $path !~ $ours && !$want{$path}++;
        }
        push @lines, map { "proc $_ $procs{$_}{ppid} $procs{$_}{uid} " . ($procs{$_}{began} =~ tr/ /_/r) . "\t$procs{$_}{path}\t$procs{$_}{args}" } sort { $a <=> $b } keys %procs;
        push @lines, map { "open $_" } sort keys %open;
        for my $domain ('gui', 'system') { push @lines, map { my $job = $jobs{$domain}{$_}; "job $domain $_ $job->{pid} $job->{state}\t$job->{program}\t$job->{file}\t$job->{flags}\t$job->{args}" } sort keys %{$jobs{$domain} // {}} }
        push @lines, map { "sign $_->[0]\t$_->[1]\t$_->[2]" } tool_signed(@want);
    }
    push @lines, map { "kept $_->[0]\t$_->[1]\t$_->[2]" } @$kept;
    %TOOL = (procs => \%procs, jobs => \%jobs, own => \%own, kept => { map { $_->[0] => $_ } @$kept });
    return join '', map { "$_\n" } "me $<", @lines;
}

# lzrprf's own rules for a change the application names, whatever the
# application says of it: what the change is, in lzrprf's own words, or
# nothing when lzrprf does not make it. A process: one of yours that lzrprf
# itself saw in this look, not lzrprf, what it started or what started it,
# and not a program of the system. A launchd job: one of your account that
# lzrprf itself saw, written down in one of your account's two folders or in
# none, and not one of Apple's or an open app. A job switched on again: one
# you switched off here.                                             # [C20]
sub tool_may {
    my ($kind, $what) = @_;
    if ($kind eq 'stop') {
        my $proc = $what =~ /^[1-9][0-9]{0,6}\z/ ? $TOOL{procs}{$what} : undef;
        return unless $proc && $what > 1 && $proc->{uid} == $< && !$TOOL{own}{$what};
        return unless $proc->{path} =~ m{^/} && $proc->{path} !~ m{^/(?:System|bin|sbin|usr(?!/local/)|Library/Apple)/};
        return "the process $what, started $proc->{began}, $proc->{path}";
    }
    return unless $what =~ /^$TOOL_LABEL\z/ && $what !~ /^(?:com\.apple\.|application\.)/i;
    if ($kind eq 'quiet') {
        my $job = $TOOL{jobs}{gui}{$what} or return;
        return if $job->{state} eq 'off';
        my ($folder) = $job->{file} =~ m{^(.*)/[^/]+\z};
        return if $job->{file} ne '' && !grep { $_->[0] eq 'gui' && $_->[1] eq $folder } tool_places();
        return "the launchd job $what of your account" . ($job->{file} ne '' ? ", written down in $job->{file}" : '') . ($job->{program} ne '' ? ", which runs $job->{program}" : '');
    }
    my $kept = $kind eq 'wake' ? $TOOL{kept}{$what} : undef or return;
    return "the launchd job $what, switched off here on $kept->[2]" . ($kept->[1] ne '' ? ", written down in $kept->[1]" : '');
}

# The application's answer, checked: its title, its words, the heading of its
# list, the words of its three buttons (look, switch off, switch on again),
# and its rows, each a tag, a title and a sentence, with the changes it names
# for that row. Text is shown as text. A change is kept only when sub
# tool_may lets it be made, and a row with none left cannot be ticked. An
# answer with one line in no such form is not shown at all.           # [C20]
sub tool_checked {
    my ($wrote) = @_;
    return unless defined $wrote && $wrote =~ s/\n\z//;
    my @lines = split /\n/, $wrote, -1;
    return if @lines > ($TOOL_ACTS + 1) * $TOOL_ROWS + 8 + $TOOL_PROCS;
    my (%said, %rows, @order, %about);
    for (@lines) {
        if (/^(title|head) (.+)\z/s) { defined($said{$1} = tool_text($2, 60)) or return }
        elsif (/^words (.+)\z/s) { defined($said{words} = tool_text($1, 600)) or return }
        elsif (/^button (sense|act|undo) (.+)\z/s) { defined($said{$1} = tool_text($2, 40)) or return }
        elsif (/^row (0|[1-9][0-9]{0,2}) ([^\t]*)\t([^\t]*)\t([^\t]*)\z/s) {
            return if $1 >= $TOOL_ROWS || $rows{$1};
            my %row = (tag => tool_text($2, 24), title => tool_text($3, 100), detail => tool_text($4, 600), acts => []);
            return if grep { !defined } @row{qw(tag title detail)};
            $rows{$1} = \%row;
            push @order, $1;
        }
        elsif (/^(stop|quiet|wake) (0|[1-9][0-9]{0,2}) ([\x21-\x7e]{1,200})\z/) {
            my $row = $rows{$2} or return;
            return if @{$row->{acts}} >= $TOOL_ACTS;
            push @{$row->{acts}}, [$1, $3];
        }
        elsif (/^about ([1-9][0-9]{0,6}) (core|known)\t([^\t]*)\t([^\t]*)\t([^\t]*)\z/s) {    # Show all processes: what the application can say of one process; shown as text, and nothing is ever changed for it
            return if $about{$1} || keys %about >= $TOOL_PROCS;
            my %one = (group => $2, title => tool_text($3, 100), about => tool_text($4, 600), source => tool_text($5, 100));
            return if grep { !defined } values %one;
            $about{$1} = \%one;
        }
        else { return }
    }
    return unless defined $said{title};
    for my $row (values %rows) {
        my @acts = map { my $fact = tool_may(@$_); defined $fact ? [@$_, $fact] : () } @{$row->{acts}};
        my @wake = grep { $_->[0] eq 'wake' } @acts;
        @acts = @wake ? @wake : ((grep { $_->[0] eq 'quiet' } @acts), grep { $_->[0] eq 'stop' } @acts);    # a job is switched off before its process is asked to end, so launchd does not start it again
        @$row{qw(acts mode)} = (\@acts, @wake ? 'undo' : @acts ? 'act' : 'none');
        $row->{fact} = tool_plain(join('; ', map { ($_->[0] eq 'stop' ? 'Ends ' : $_->[0] eq 'quiet' ? 'Switches off ' : 'Switches on again ') . $_->[2] } @acts), 4000);
    }
    return { %said, rows => \%rows, order => \@order, about => \%about };
}

sub tool_none { window('tool none'); return idle($_[0]) }

# "tool open", "tool sense" and "tool all", from the window: the look, the
# application's answer to it, and the list the window shows; "tool all" (Show
# all processes) adds every process of the look (sub tool_procs). $said: what
# lzrprf did a moment ago, in its own words, shown over the list.
sub tool_shown {
    my ($how, $said) = @_;
    return tool_none('An incognito window has no tool of the application: it would write what you switch off.') if $INCOGNITO;
    return tool_none('LZRDFNDR is not installed. Add it in Add or remove LZR modules, in the cogwheel menu.') unless part_on('lzrdfndr');
    $TOOL_ALL = $how eq 'all' if $how ne 'open';
    window('tool busy ' . ($how eq 'all' ? 'Reading every process of this computer' : $how eq 'sense' ? 'Reading the processes and the launchd jobs of this computer' : 'Asking the application'));
    my $look = tool_look($how ne 'open');
    return tool_none('The system did not list its processes and launchd jobs, so the application was asked nothing.') unless defined $look;
    my ($wrote, $why) = contained('tool', "=tool $how\n$look", undef, 0, 1);    # [C1] [C3] in the page container, as a picture is: no network, no file
    my $list = defined $wrote ? tool_checked($wrote) : undef;
    return tool_none(defined $wrote ? 'This application has no tool, or its answer was not in the form lzrprf takes, so nothing of it is shown.' : "The application's tool was not run: " . ($why // 'it did not start') . '.') unless $list;
    $TOOL{rows} = $list->{rows};
    record("You looked at this computer's processes and launchd jobs with the application's tool: " . @{$list->{order}} . ' rows' . ($how eq 'all' ? ' and every process shown' : '') . ', nothing changed') if $how ne 'open' && !defined $said;
    window('tool begin', "tool title $list->{title}", (map { defined $list->{$_} ? "tool $_ $list->{$_}" : () } 'words', 'head'), (map { defined $list->{$_} ? "tool button $_ $list->{$_}" : () } 'sense', 'act', 'undo'),
        (map { my $row = $list->{rows}{$_}; "tool row $_ $row->{mode}\t$row->{tag}\t$row->{title}\t$row->{detail}\t$row->{fact}" } @{$list->{order}}), ($how eq 'all' ? tool_procs($list->{about}) : ()), defined $said ? "tool said $said" : (), 'tool end');
    return;
}

# "tool act I,I,.." and "tool undo I,I,..", from the window, after you ticked
# those rows and, for a switching off, confirmed lzrprf's own words for each.
# A list is acted on once: after it the computer is looked at again.  # [C20]
sub tool_done {
    my ($kind, $picked) = @_;
    my $rows = delete $TOOL{rows};
    return tool_none('That list is no longer the newest look at this computer, so nothing was changed. Look again.') if $INCOGNITO || !$rows;
    window('tool busy ' . ($kind eq 'act' ? 'Switching off what you ticked' : 'Switching on again what you ticked'));
    my (%seen, @did, @not);
    for my $i (split /,/, $picked) {
        my $row = $rows->{$i};
        next if $seen{"row $i"}++ || !$row || $row->{mode} ne $kind;
        for my $act (@{$row->{acts}}) {
            next if $seen{"$act->[0] $act->[1]"}++;
            my ($ok, $says) = $act->[0] eq 'stop' ? tool_stop($act->[1]) : $act->[0] eq 'quiet' ? tool_quiet($act->[1]) : tool_wake($act->[1]);
            push @{$ok ? \@did : \@not}, $says;
        }
    }
    my $said = join ' ', @did ? 'Done: ' . join('; ', @did) . '.' : (), @not ? 'Not done: ' . join('; ', @not) . '.' : ();
    return tool_shown($TOOL_ALL ? 'all' : 'sense', tool_plain($said, 3000) || 'Nothing you ticked is a change lzrprf makes.');
}

# Show all processes, the button at the bottom left of On Your Computer:
# every process of the look, each as one line "tool proc" of fifteen fields
# parted by tabs: its number, its share of a processor now (ps %cpu), its
# memory in KiB (ps rss), its group, its title, what it is, where that was
# read, the note you wrote to it, the number of its parent, its user, when it
# started, its program, its command line, who signed it and the launchd job
# that runs it. What it is comes from the application's word for it (a
# process of the core project by its name, or one its table names), else
# from the manual page of its program on this Mac (sub tool_man), else
# nothing: nothing of the look is sent anywhere to be described. The window
# copies a row's fields to the clipboard on its Copy info, and a row is shown
# and never changed from here: a process is ended only as a ticked row of the
# list above (sub tool_done).                                        # [C20]
sub tool_procs {
    my ($about) = @_;
    my (%use, %user, %job);
    my ($said, $ok) = tool_asked('usage', 10, '/bin/ps', '-axww', '-o', 'pid=,%cpu=,rss=');
    for (split /\n/, $ok ? $said : '') { $use{$1} = [$2, $3] if /^\s*(\d+)\s+([\d.]+)\s+(\d+)\s*$/ }
    for my $domain ('gui', 'system') { for my $label (sort keys %{$TOOL{jobs}{$domain} // {}}) { my $pid = $TOOL{jobs}{$domain}{$label}{pid}; $job{$pid} //= "$domain $label" if $pid } }
    my $notes = tool_notes();
    my $read = 0;
    my $system = qr{^/(?:System|bin|sbin|usr(?!/local/)|Library/Apple)/};
    return map {
        my ($pid, $proc) = ($_, $TOOL{procs}{$_});
        my $name = $proc->{path} =~ m{([^/]+)\z} ? $1 : $proc->{path};
        my $told = $about->{$pid};
        my ($text, $source) = $told ? @$told{qw(about source)} : tool_man($name, \$read);
        my $group = $told && $told->{group} eq 'core' ? 'core' : $TOOL{own}{$pid} ? 'lzrbrwsr' : $proc->{path} =~ $system ? 'macos' : $proc->{uid} == $< ? 'yours' : 'others';
        my $sign = $TOOL_SIGN{$proc->{path} =~ m{^(/.*?\.app)/} ? $1 : $proc->{path}};
        $user{$proc->{uid}} //= tool_plain((getpwuid $proc->{uid})[0] // $proc->{uid}, 64);
        'tool proc ' . join("\t", $pid, $use{$pid} ? @{$use{$pid}} : ('-', '-'), $group, $told ? $told->{title} : tool_plain($name, 100), map({ $_ // '' } $text, $source), $notes->{$proc->{path}} // '',
            $proc->{ppid}, $user{$proc->{uid}}, $proc->{began}, $proc->{path}, $proc->{args}, $sign ? "$sign->[1] $sign->[2]" : '', $job{$pid} // '');
    } sort { $a <=> $b } keys %{$TOOL{procs}};
}
sub tool_man {                            # [C20] what the manual page of a program on this Mac says it is, its NAME line, and which page; nothing when none is there or $TOOL_MANS were read in this look
    my ($name, $read) = @_;
    return @{$TOOL_MAN{$name}} if $TOOL_MAN{$name};
    return unless $name =~ /\A[A-Za-z0-9][A-Za-z0-9._+-]{0,100}\z/ && $$read++ < $TOOL_MANS;
    my $stand = tool_stand();
    for my $dir (defined $stand ? "$stand/man" : ('/usr/share/man', '/usr/local/share/man', '/opt/homebrew/share/man')) {
        for my $section (8, 1, 5) {
            my $file = "$dir/man$section/$name.$section";
            next unless -f $file && -s _ <= 1024 * 1024 && open my $in, '<', $file;
            read $in, my $text, 16384;
            my ($what) = $text =~ /^\.Nd\s+(.+)$/m;    # mdoc: .Nm NAME, then .Nd what it is
            ($what) = $text =~ /^\.SH\s+"?NAME"?\s*\n(?:\.[^\n]*\n)*([^\n]*?\\-\s*[^\n]+)$/m unless defined $what;    # man: NAME \- what it is, under .SH NAME
            next unless defined $what;
            $what =~ s/^.*?\\-\s*//;    # the name before "\-" goes: the title column has it
            $what =~ s/\\f[A-Z]|\\\(..|\\[&|^]//g;
            $what =~ s/\\(.)/$1/g;
            $what = tool_plain($what =~ s/^\s+|\s+$//gr, 300);
            next unless length $what;
            return @{$TOOL_MAN{$name} = [ucfirst($what) . ($what =~ /[.!?]\z/ ? '' : '.'), "the manual page $name($section) on this Mac"]};
        }
    }
    $TOOL_MAN{$name} = [];
    return;
}
sub tool_notes {                          # [C20] the notes you wrote to processes, each by the program of the process: { program => note }
    open my $in, '<', "${\ shared()}/procnotes" or return {};
    my %notes;
    while (my $line = <$in>) {
        last if keys %notes >= $TOOL_NOTES;
        chomp $line;
        my ($key, $note) = split /\t/, $line, 2;
        $notes{$key} = $note if defined $note && $key =~ /\A[^\x00-\x1f\x7f]{1,1000}\z/ && defined tool_text($note, $TOOL_NOTE);
    }
    return \%notes;
}
# "tool note PROGRAM<tab>TEXT", from the window: the note you wrote in the Notes
# column of a process, kept by its program (the same note for every process
# of it) in ~/.lzrprf/procnotes, written beside the old list and given its
# name in one step; an empty note takes it away. Never in an incognito
# window, which has no tool. The window is told "tool noted kept" or "tool
# noted failed".                                                    # [C20]
sub tool_note {
    my ($key, $note) = @_;
    $note =~ s/^\s+|\s+$//g;
    return window('tool noted failed') if $INCOGNITO || length($note) && !defined tool_text($note, $TOOL_NOTE);
    my $notes = tool_notes();
    if (length $note) { $notes->{$key} = $note } else { delete $notes->{$key} }
    return window('tool noted failed') if keys %$notes > $TOOL_NOTES;
    record("You wrote a note to the processes of $key in LZRDFNDR's Show all processes") or return window('tool noted failed');
    my $file = "${\ shared()}/procnotes";
    unlink "$file.new";
    my $kept = !%$notes ? (!-e $file || unlink $file) : put("$file.new", O_EXCL, map { "$_\t$notes->{$_}" } sort keys %$notes) && rename("$file.new", $file);
    unlink "$file.new";
    synced(shared()) if $kept;
    return window('tool noted ' . ($kept ? 'kept' : 'failed'));
}
sub tool_stop {                           # [C20] a process of yours is asked to end: looked at again first, and ended only when it is still the one that was listed; the log line says who ended it (lzr says its own command)
    my ($pid, $who) = @_;
    my $fact = tool_may('stop', $pid) or return (0, "process $pid is not one lzrprf ends");
    my $proc = $TOOL{procs}{$pid};
    my ($now) = tool_asked("proc.$pid", 5, '/bin/ps', '-o', 'uid=,lstart=,comm=', '-p', $pid);
    my ($owner, $began, $path) = $now =~ /^\s*(\d+)\s+(\S+\s+\S+\s+\d+\s+[\d:]+\s+\d+)\s+(.*?)\s*$/ or return (1, "process $pid had ended already");
    return (0, "process $pid is no longer the one that was listed") unless $owner == $proc->{uid} && ($began =~ s/\s+/ /gr) eq $proc->{began} && tool_plain($path, 1000) eq $proc->{path};
    record(($who // "You ended a process from the application's tool") . ": $fact") or return (0, "process $pid: the log could not be written, so it was left running");    # written down first
    return (tool_ran("TERM $pid"), "process $pid was asked to end") if defined tool_stand();
    kill('TERM', $pid) or return (0, "process $pid could not be asked to end");
    for (my $until = now() + 2; now() < $until && kill(0, $pid);) { Time::HiRes::sleep(0.05) }
    return (1, kill(0, $pid) ? "process $pid was asked to end and is still ending" : "process $pid ended");
}
sub tool_off {                            # [C20] a launchd job of your account, switched off and taken out of launchd; true when launchd no longer holds it
    my ($label) = @_;
    my $off = tool_ran("disable $label", '/bin/launchctl', 'disable', "gui/$</$label");
    tool_ran("bootout $label", '/bin/launchctl', 'bootout', "gui/$</$label");    # of a job that is not loaded there is nothing to take out, and launchctl says so: that is no failure
    for (my $until = now() + 3; now() < $until;) {
        return $off unless (tool_asked("job.$label.after", 5, '/bin/launchctl', 'print', "gui/$</$label"))[1];
        Time::HiRes::sleep(0.2);
    }
    return 0;
}
sub tool_quiet {                          # [C20]
    my ($label) = @_;
    my $fact = tool_may('quiet', $label) or return (0, "launchd job $label is not one lzrprf switches off");
    my $job = $TOOL{jobs}{gui}{$label};
    record("You switched a launchd job off from the application's tool: $fact") or return (0, "launchd job $label: the log could not be written, so it was left as it is");    # written down first
    my $kept = tool_kept();
    @$kept = ((grep { $_->[0] ne $label } @$kept), [$label, $job->{file} =~ m{^/[\x20-\x7e]{1,1000}\z} ? $job->{file} : '', strftime('%Y-%m-%dT%H:%M:%SZ', gmtime)]);
    tool_keep($kept) or return (0, "launchd job $label: the list of what you switched off could not be written, so it was left as it is");
    return tool_off($label) ? (1, "launchd job $label is switched off") : (0, "launchd job $label could not be switched off");
}
sub tool_wake {                           # [C20] a job you switched off here, switched on again: enabled, and loaded again when its property list is still there
    my ($label) = @_;
    my $fact = tool_may('wake', $label) or return (0, "launchd job $label is not one you switched off here");
    my $file = $TOOL{kept}{$label}[1];
    record("You switched a launchd job on again from the application's tool: $fact") or return (0, "launchd job $label: the log could not be written, so it was left switched off");
    my $on = tool_ran("enable $label", '/bin/launchctl', 'enable', "gui/$</$label");
    tool_ran("bootstrap $label", '/bin/launchctl', 'bootstrap', "gui/$<", $file) if $file ne '' && -f $file;
    tool_keep([grep { $_->[0] ne $label } @{tool_kept()}]);
    return $on ? (1, "launchd job $label is switched on again" . ($file ne '' && -f $file ? '' : ', and starts when its app or the next login starts it')) : (0, "launchd job $label could not be switched on again");
}

# The jobs you switched off, looked at again: at the start of a window and
# every $TOOL_WATCH seconds while it is open. One that is loaded again, or
# no longer switched off, was put back by its app or its installer: it is
# switched off again, as you chose, written in the log first, and the window
# lights the tool's icon. Nothing else of the computer is read for this, and
# with nothing switched off nothing is read at all. The programs you
# deactivated with lzr are looked for on a cadence of their own (sub
# lzr_watch), with nothing read while none is deactivated.            # [C20]
sub tool_due {                            # the seconds until the next such look, or the next look for deactivated programs; nothing when there is nothing to look at
    return if $INCOGNITO;
    my @due = sort { $a <=> $b } lzr_due(), -s "${\ shared()}/quieted" && part_on('lzrdfndr') ? ($TOOL_LOOKED // now()) + $TOOL_WATCH - now() : ();
    return unless @due;
    return $due[0] > 1 ? $due[0] : 1;
}
sub tool_watch {
    return if $INCOGNITO;
    lzr_watch();
    return if !part_on('lzrdfndr') || defender_is_off('computer') || defined $TOOL_LOOKED && now() < $TOOL_LOOKED + $TOOL_WATCH;    # what LZRDFNDR switched off is looked at only while it is installed; what lzr deactivated, always
    $TOOL_LOOKED = now();
    my $kept = tool_kept();
    return unless @$kept;
    my ($gui, $said) = tool_asked('jobs', 10, '/bin/launchctl', 'print', "gui/$<");
    return unless $said;
    my ($loaded, $off) = tool_services($gui);
    my @back = grep { exists $loaded->{$_} || !$off->{$_} } map { $_->[0] } @$kept;
    @back = grep { record("The launchd job $_, which you switched off, was switched on again by something else, and lzrprf switched it off again") && tool_off($_) } @back;
    window('tool back ' . @back) if @back;
    return;
}

