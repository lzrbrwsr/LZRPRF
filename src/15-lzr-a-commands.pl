
# lzr, the terminal's own command [C20]. LZRTRMNL puts its folder first on
# the shell's PATH (sub lzr_bin), and "lzr ..." is "lzrprf lzr ...": the same
# file, the same rules. Its words follow one grammar, written down in
# managed-projects/lzrbrwsr/architecture/lzr.md:
#
#   lzr <group> <command> [ID] [flags]      lzr processes kill k3f9a
#   lzr <group> [ID] <command> [flags]      lzr processes k3f9a kill (the same)
#
# "lzr" alone lists the commands. Every command has a help: "lzr help
# <command>", "lzr <command> --help" or "-h". A word that is no command is
# answered with the nearest ones. A flag means one thing wherever it is
# taken. Output goes to standard output, every complaint to standard error;
# lzr ends 0 when it did what was asked, 1 when it did not (refused, failed,
# or you said no), and 2 when the words were not in its form. Colours only on
# a terminal, and never with --no-color or NO_COLOR.
my $LZR_VERSION = '1.0';
my $LZR_COLOR = 0;
my %LZR_FLAG = (                          # every flag: its short form, what it takes, and its help; one meaning everywhere
    help => ['h', '', 'show this help'],
    'no-color' => ['', '', 'write no colour (none is written either when NO_COLOR is set or the output is no terminal)'],
    version => ['', '', 'the same as lzr version'],
    json => ['', '', 'write JSON, for a program to read'],
    mine => ['', '', 'only your own processes'],
    sort => ['', 'cpu|memory|pid|name', 'the order: most processor first (cpu, the default), most memory first, by number, by name'],
    yes => ['y', '', 'do it without asking first; outside a terminal lzr cannot ask, and does nothing without it'],
    'dry-run' => ['n', '', 'say what would be done, and do nothing'],
    interval => ['', 'SECONDS', 'seconds between two samples, 0.2 to 60 (1 when left out)'],
    frames => ['', 'N', 'draw N frames and stop, also outside a terminal: for scripts and tests'],
);
my $LZR_ID_HELP = 'ID is the short name lzr shows for a process (five letters and digits, as in k3f9a), or its process number.';
my %LZR_COMMAND = (                       # every command, by its words: what it does in one line and in full, its usage, its commands, flags and examples
    '' => {
        brief => 'the command line of LZRBRWSR',
        usage => ['lzr <command> [<subcommand>] [ID] [flags]'],
        about => 'lzr is the command of LZRTRMNL, the terminal of LZRBRWSR. It runs as you, with no password, and changes nothing before you asked for that change by its name.',
        commands => [qw(processes help version)],
        flags => [qw(version)],
        examples => ['lzr processes', 'lzr processes all', 'lzr processes k3f9a analyze', 'lzr help processes kill'],
    },
    processes => {
        brief => 'what LZRDFNDR deactivated and contains, and every process: analyze, kill, deactivate, contain',
        aliases => ['ps'],
        usage => ['lzr processes [flags]', 'lzr processes <command> [ID] [flags]', 'lzr processes ID <command> [flags]'],
        about => "With no command, two lists: the programs LZRDFNDR deactivated (they are closed whenever LZRDFNDR sees them run, and their launchd jobs are switched off), and the processes it contains (each runs in lzrprf's container, with no network, no file of yours and no right to write). $LZR_ID_HELP Only your own processes are changed, never one of the system, of Apple or of LZRBRWSR itself.",
        commands => [qw(list all analyze kill deactivate reactivate contain release)],
        flags => [qw(json)],
        examples => ['lzr processes', 'lzr processes all --sort memory', 'lzr processes k3f9a analyze', 'lzr processes kill 4242'],
    },
    'processes list' => {
        brief => 'the processes LZRDFNDR deactivated, and those it contains (the default)',
        aliases => ['ls'],
        usage => ['lzr processes list [--json]'],
        about => 'Two lists, each entry with its ID. A deactivated program that is seen running again is closed first, and lzr says so above the lists.',
        flags => [qw(json)],
        examples => ['lzr processes', 'lzr processes list --json'],
    },
    'processes all' => {
        brief => 'every process of this computer, each with its ID',
        usage => ['lzr processes all [--mine] [--sort cpu|memory|pid|name] [--json]'],
        about => "Every process the system lists to you: its ID, number, user, share of a processor, memory, name, what LZRDFNDR does with it and its program. Of another user's process the system tells you less; what it does not tell is shown as a dash. $LZR_ID_HELP",
        flags => [qw(mine sort json)],
        examples => ['lzr processes all', 'lzr processes all --mine --sort memory', 'lzr processes all --json'],
    },
    'processes analyze' => {
        brief => 'a live view of one process: its processor and memory against time, and everything known of it',
        args => 'ID',
        usage => ['lzr processes analyze ID [--interval SECONDS]', 'lzr processes ID analyze'],
        about => "A view that keeps tracking until you close it: a graph of its share of a processor and one of its memory, each against time, and a box with its program, where it lives, its owner, its parent, when it started, who signed it and what LZRDFNDR does with it. Close it with the Close button at its top right, with q or with Esc. It reads with the system's own unprivileged answers (ps and libproc) and never the process's memory. Of another user's process it shows what the system tells you and says what it does not. $LZR_ID_HELP",
        flags => [qw(interval frames)],
        examples => ['lzr processes k3f9a analyze', 'lzr processes analyze 4242 --interval 0.5'],
    },
    'processes kill' => {
        brief => 'end a process once; it may come back when something starts it again',
        args => 'ID',
        usage => ['lzr processes kill ID [--yes] [--dry-run]', 'lzr processes ID kill'],
        about => "Shows the process's share of a processor and its memory at that moment and asks before it acts. Then it is asked to end (TERM), and ended (KILL) when it has not after three seconds. Nothing keeps it from starting again: to keep it off, deactivate it. Your own processes only. $LZR_ID_HELP",
        flags => [qw(yes dry-run)],
        examples => ['lzr processes kill k3f9a', 'lzr processes 4242 kill --yes'],
    },
    'processes deactivate' => {
        brief => 'keep a program off: closed now, and closed whenever LZRDFNDR sees it run',
        args => 'ID',
        usage => ['lzr processes deactivate ID [--yes] [--dry-run]', 'lzr processes ID deactivate'],
        about => "The program of the process is kept in LZRDFNDR's list of deactivated programs. Every process of it is closed now, its launchd jobs of your account are switched off, and LZRDFNDR closes it whenever it sees it run again: every 10 seconds while a LZRBRWSR window is open, and at every lzr processes. macOS lets no program without an administrator stop another from starting, so a deactivated program may run until it is seen. lzr processes reactivate undoes it. $LZR_ID_HELP",
        flags => [qw(yes dry-run)],
        examples => ['lzr processes deactivate k3f9a', 'lzr processes k3f9a deactivate --dry-run'],
    },
    'processes reactivate' => {
        brief => 'undo deactivate: the program may run again, and its launchd jobs are switched on again',
        args => 'ID',
        usage => ['lzr processes reactivate ID [--yes] [--dry-run]', 'lzr processes ID reactivate'],
        about => 'The ID is the one lzr processes shows in its list of deactivated programs. A launchd job switched off in LZRDFNDR is switched on again too. Nothing is started.',
        flags => [qw(yes dry-run)],
        examples => ['lzr processes reactivate a1b2c'],
    },
    'processes contain' => {
        brief => "run a process in lzrprf's container, where it has no rights",
        args => 'ID',
        usage => ['lzr processes contain ID [--yes] [--dry-run]', 'lzr processes ID contain'],
        about => "macOS cannot put a process that runs into a container, so the process is ended and its program started again, with the same arguments, in lzrprf's container: the one a page of LZRBRWSR runs in. There it has no network, reads no file of yours (only the system's own and its own folder), writes no file and starts no other program. Many programs cannot work like that and end; lzr processes shows how. Its launchd jobs of your account are switched off, so launchd does not start it again outside. lzr processes release ends it. $LZR_ID_HELP",
        flags => [qw(yes dry-run)],
        examples => ['lzr processes contain k3f9a', 'lzr processes k3f9a contain --dry-run'],
    },
    'processes release' => {
        brief => 'end a contained process and take it off the list',
        args => 'ID',
        usage => ['lzr processes release ID [--yes] [--dry-run]', 'lzr processes ID release'],
        about => 'The ID is the one lzr processes shows in its list of contained processes. The process is ended through the keeper that started it, and nothing is started in its place.',
        flags => [qw(yes dry-run)],
        examples => ['lzr processes release q7w8e'],
    },
    help => {
        brief => 'help on lzr, or on any command',
        usage => ['lzr help [<command> [<subcommand>]]'],
        about => 'The same help as <command> --help or -h.',
        examples => ['lzr help', 'lzr help processes', 'lzr help processes analyze'],
    },
    version => {
        brief => 'which lzr this is, and the SHA-256 of the lzrprf it runs in',
        usage => ['lzr version'],
        examples => ['lzr version'],
    },
);

sub lzr_main {                            # "lzrprf lzr WORDS": what lzr does with the words, and the number it ends with
    my ($flags, $words, $bad) = lzr_parsed(@_);
    $LZR_COLOR = !$flags->{'no-color'} && !length($SHOWN{NO_COLOR} // '') && -t STDOUT;
    return lzr_wrong($bad, '') if defined $bad;
    my ($path, $args, $why) = lzr_found(@$words);
    return lzr_wrong($why, $path // '') if defined $why;
    return lzr_help($path) if $flags->{help};
    return lzr_version() if $path eq '' && $flags->{version} || $path eq 'version';
    my @extra = grep { my $f = $_; !grep { $_ eq $f } 'help', 'no-color', @{ $LZR_COMMAND{$path}{flags} // [] } } sort keys %$flags;
    return lzr_wrong("--$extra[0] is not a flag of lzr" . ($path eq '' ? '' : " $path") . (lzr_near($extra[0], @{ $LZR_COMMAND{$path}{flags} // [] }) ? '. Did you mean --' . join(' or --', lzr_near($extra[0], @{ $LZR_COMMAND{$path}{flags} // [] })) . '?' : ''), $path) if @extra;
    return lzr_help('') if $path eq '';
    if ($path eq 'help') {
        my ($at, undef, $wrong) = lzr_found(@$args);
        return lzr_wrong($wrong, $at // '') if defined $wrong;
        return lzr_help($at);
    }
    my $want = $LZR_COMMAND{$path}{args} ? 1 : 0;
    return lzr_wrong("lzr $path needs an ID: the process to act on", $path) if @$args < $want;
    return lzr_wrong("lzr $path takes " . ($want ? 'one ID' : 'no word') . ", and \"$args->[$want]\" is one more", $path) if @$args > $want;
    return lzr_processes($path =~ s/^processes ?//r || 'list', $args->[0], $flags);
}

sub lzr_parsed {                          # the words and the flags, apart: the flags anywhere after lzr, "--" ends them; an error of form, in words
    my (%flags, @words, $rest);
    my %short = map { $LZR_FLAG{$_}[0] ? ($LZR_FLAG{$_}[0] => $_) : () } keys %LZR_FLAG;
    while (@_) {
        my $word = shift;
        if ($rest || $word !~ /^-./) { push @words, $word; next }
        if ($word eq '--') { $rest = 1; next }
        my @names;
        my $value;
        if ($word =~ /^--([a-z][a-z-]*)(?:=(.*))?\z/s) {
            return (\%flags, \@words, "--$1 is not a flag of lzr" . (lzr_near($1, keys %LZR_FLAG) ? '. Did you mean --' . join(' or --', lzr_near($1, keys %LZR_FLAG)) . '?' : '')) unless $LZR_FLAG{$1};
            @names = ($1);
            $value = $2;
        }
        elsif ($word =~ /^-([a-zA-Z]+)\z/) {
            for my $letter (split //, $1) { return (\%flags, \@words, "-$letter is not a flag of lzr") unless $short{$letter}; push @names, $short{$letter} }
        }
        else { return (\%flags, \@words, "\"$word\" is not a flag lzr reads") }
        for my $name (@names) {
            my $takes = $LZR_FLAG{$name}[1];
            if (!length $takes) { return (\%flags, \@words, "--$name takes no value") if defined $value; $flags{$name} = 1; next }
            $value //= shift;
            return (\%flags, \@words, "--$name needs a value: $takes") unless defined $value && length $value;
            $flags{$name} = $value;
            undef $value;
        }
    }
    return (\%flags, \@words, undef);
}

sub lzr_named {                           # the command a word names among the commands of a group (its own name or an alias), or nothing
    my ($group, $word) = @_;
    for my $name (@{ $LZR_COMMAND{$group}{commands} // [] }) {
        my $path = length $group ? "$group $name" : $name;
        return $name if $word eq $name || grep { $_ eq $word } @{ $LZR_COMMAND{$path}{aliases} // [] };
    }
    return;
}

sub lzr_id_like { $_[0] =~ /\A(?:[1-9][0-9]{0,6}|(?=[a-z]*[0-9])[0-9a-hjkmnp-tv-z]{3,5})\z/ }    # a process number, or the start of an ID of lzr's (at least three of its letters and digits, one a digit)

sub lzr_found {                           # the command the words name, the words after it, or what is wrong
    my @words = @_;
    return ('', []) unless @words;
    my $first = shift @words;
    my $group = lzr_named('', $first);
    return (undef, undef, "\"$first\" is not a command of lzr" . lzr_hint($first, '')) unless defined $group;
    return ($group, \@words) unless $LZR_COMMAND{$group}{commands} && @words;
    my $verb = lzr_named($group, $words[0]);
    return ("$group $verb", [@words[1 .. $#words]]) if defined $verb;
    if (lzr_id_like($words[0])) {
        my $after = @words > 1 ? lzr_named($group, $words[1]) : undef;
        return ("$group $after", [$words[0], @words[2 .. $#words]]) if defined $after;
        return ($group, undef, "say what to do with $words[0]: lzr $group $words[0] " . join('|', grep { $LZR_COMMAND{"$group $_"}{args} } @{ $LZR_COMMAND{$group}{commands} })) if @words == 1;
        return ($group, undef, "\"$words[1]\" is not a command of lzr $group" . lzr_hint($words[1], $group));
    }
    return ($group, undef, "\"$words[0]\" is not a command of lzr $group" . lzr_hint($words[0], $group));
}

sub lzr_hint {                            # ". Did you mean ...?" with the nearest commands of a group, or nothing
    my ($word, $group) = @_;
    my @names = map { my $path = length $group ? "$group $_" : $_; ($_, @{ $LZR_COMMAND{$path}{aliases} // [] }) } @{ $LZR_COMMAND{$group}{commands} };
    my @near = lzr_near($word, @names);
    return @near ? '. Did you mean ' . join(' or ', map { "\"lzr " . (length $group ? "$group " : '') . "$_\"" } @near) . '?' : '';
}

sub lzr_near {                            # the names nearest a word that was typed: a name it begins, or within a few changes of a letter (one for a short word, two, three for a long one)
    my ($typed, @names) = @_;
    $typed = lc $typed;
    my @starts = grep { length $typed >= 2 && index($_, $typed) == 0 } @names;
    return @starts if @starts == 1;
    my $most = length $typed <= 4 ? 1 : length $typed <= 8 ? 2 : 3;
    my %far = map { $_ => lzr_distance($typed, $_) } @names;
    my @near = sort { $far{$a} <=> $far{$b} || $a cmp $b } grep { $far{$_} <= $most } @names;
    return grep { $far{$_} == $far{$near[0]} } @near if @near;
    return @starts;
}

sub lzr_distance {                        # the changes of one letter that make one word the other: put in, taken out, changed, or two side by side swapped (the optimal string alignment distance)
    my ($s, $t) = @_;
    my @d = map { [$_] } 0 .. length $s;
    $d[0][$_] = $_ for 0 .. length $t;
    for my $i (1 .. length $s) {
        for my $j (1 .. length $t) {
            my $cost = substr($s, $i - 1, 1) eq substr($t, $j - 1, 1) ? 0 : 1;
            my $best = (sort { $a <=> $b } $d[$i - 1][$j] + 1, $d[$i][$j - 1] + 1, $d[$i - 1][$j - 1] + $cost)[0];
            $best = $d[$i - 2][$j - 2] + 1 if $i > 1 && $j > 1 && substr($s, $i - 1, 1) eq substr($t, $j - 2, 1) && substr($s, $i - 2, 1) eq substr($t, $j - 1, 1) && $d[$i - 2][$j - 2] + 1 < $best;
            $d[$i][$j] = $best;
        }
    }
    return $d[length $s][length $t];
}

sub lzr_wrong {                           # words not in lzr's form: what is wrong, where to read more, and 2
    my ($why, $path) = @_;
    print STDERR "lzr: $why" . ($why =~ /[.?]\z/ ? '' : '.') . "\n", 'Run "lzr help' . (length $path ? " $path" : '') . "\" to see how it is used.\n";
    return 2;
}

sub lzr_said {                            # something lzr did not do: why, on standard error, and 1
    my ($why) = @_;
    print STDERR "lzr: $why\n";
    return 1;
}

sub lzr_paint { my ($code, $text) = @_; return $LZR_COLOR ? "\e[${code}m$text\e[m" : $text }    # colour, only on a terminal and when not asked for none

sub lzr_wrapped {                         # a paragraph in lines of at most $wide characters, each begun with $indent
    my ($text, $indent, $wide) = @_;
    my (@lines, $line);
    for my $word (split ' ', $text) {
        if (defined $line && length($line) + 1 + length($word) > $wide - length $indent) { push @lines, $line; undef $line }
        $line = defined $line ? "$line $word" : $word;
    }
    push @lines, $line if defined $line;
    return map { "$indent$_\n" } @lines;
}

sub lzr_help {                            # the help of a command: what it does, how it is used, its commands, flags and examples
    my ($path) = @_;
    my $c = $LZR_COMMAND{$path};
    my $name = length $path ? "lzr $path" : 'lzr';
    my @out = (lzr_paint(1, $name) . ": $c->{brief}\n\n", lzr_paint(1, 'USAGE') . "\n", map({ "  $_\n" } @{ $c->{usage} }));
    push @out, "\n", lzr_wrapped($c->{about}, '  ', 80) if $c->{about};
    if (my @names = @{ $c->{commands} // [] }) {
        my %line = map { my $sub = length $path ? "$path $_" : $_; my @also = @{ $LZR_COMMAND{$sub}{aliases} // [] }; ($_ => (@also ? "$LZR_COMMAND{$sub}{brief} (also: @also)" : $LZR_COMMAND{$sub}{brief})) } @names;
        push @out, "\n", lzr_paint(1, 'COMMANDS') . "\n", map { sprintf "  %s%s\n", lzr_paint(96, sprintf '%-12s', $_), $line{$_} } @names;
    }
    my @flags = (@{ $c->{flags} // [] }, 'help', ($path eq '' ? 'no-color' : ()));
    my %form = map { my ($short, $takes) = @{ $LZR_FLAG{$_} }; ($_ => ($short ? "-$short, " : '    ') . "--$_" . (length $takes ? " $takes" : '')) } @flags;
    my $wide = (sort { $b <=> $a } map { length } values %form)[0] + 2;
    push @out, "\n", lzr_paint(1, 'FLAGS') . "\n", map { sprintf "  %-${wide}s%s\n", $form{$_}, $LZR_FLAG{$_}[2] } @flags;
    push @out, "\n", lzr_paint(1, 'EXAMPLES') . "\n", map { "  $_\n" } @{ $c->{examples} } if $c->{examples};
    push @out, "\n", lzr_paint(1, 'LEARN MORE') . "\n", $c->{commands} ? "  Run \"lzr help $path <command>\" for more on a command." =~ s/help  /help /r . ($path eq '' ? ' Every command also takes --help.' : '') . "\n" : '', $path ne '' ? "  Run \"lzr\" for every command.\n" : ();
    print @out;
    return 0;
}

sub lzr_version { print "lzr $LZR_VERSION, the command of lzrprf ", substr(sum_of($SELF) // 'unknown', 0, 12), "\n"; return 0 }

# The folder lzr is started from in LZRTRMNL: ~/.lzrprf/bin, holding one file,
# lzr, written again at each terminal so it always names this lzrprf: three
# lines that start the system's perl with this file and "lzr". Nothing when
# that cannot be written, and the terminal opens without it.        # [C20]
sub lzr_bin {
    return if $INCOGNITO || $SELF =~ /['\n\\]/;
    my $bin = "${\ shared()}/bin";
    mkdir $bin, 0700;
    my @is = lstat $bin;
    return unless @is && -d _ && $is[4] == $<;
    unlink "$bin/lzr.new";
    put("$bin/lzr.new", O_EXCL, '#!/bin/sh', '# lzr, the command of LZRTRMNL: written by lzrprf when a terminal opens (lzrprf help: lzr help)', "exec /usr/bin/perl '$SELF' lzr \"\$\@\"") && chmod(0700, "$bin/lzr.new") && rename("$bin/lzr.new", "$bin/lzr") or return;
    return $bin;
}
