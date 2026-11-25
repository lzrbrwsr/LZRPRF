my $command = shift // '';
if ($command =~ /^(?:run|incognito|tor|keep|log)\z/ && ($ARGV[0] // '') eq '--profile') { (undef, $PROFILE) = splice @ARGV, 0, 2; die "lzrprf: --profile takes the id of a profile, 12 hex digits as lzrprf made it. Nothing was started or changed. \"lzrprf profiles\" lists each id with its name.\n" unless ($PROFILE // '') =~ /\A[0-9a-f]{12}\z/ }    # a profile's window: its id alone is an argument, never its name (sub profile_command)
if ($command =~ /^(?:run|incognito)\z/ && ($ARGV[0] // '') eq '--open') { ($OPEN, $OPEN_FRAME, @ARGV) = opened_with(\*STDIN, @ARGV); open STDIN, '<', '/dev/null' }
if (defined $PROFILE && $command =~ /^(?:keep|log)\z/) { $DIR = profile_folder($PROFILE) // die "lzrprf: there is no profile with the id $PROFILE. Nothing was changed. \"lzrprf profiles\" lists each id with its name.\n" }    # the terminal's word for one profile: its folder, only when lzrprf finds it under the folder of the profiles
die "lzrprf: this macOS has no /usr/bin/sandbox-exec. lzrprf contains with that command and with nothing else, so nothing was started.\n" if $command =~ /^(?:run|try|incognito|tor)\z/ && !-x '/usr/bin/sandbox-exec';
if ($command eq 'run') { run(@ARGV) }
elsif ($command eq 'tor') { ($INCOGNITO, $TOR_WINDOW) = (1, 1); run(@ARGV ? @ARGV : '/Applications/LZRBRWSR.app/Contents/MacOS/lzrbrwsr-bin') }    # [C17] a Tor window: an incognito window of its own, carried by Tor alone
elsif ($command eq 'torsteps' && @ARGV) { $TOR_SESSION = { phase => 'made' }; print tor_phase($_) ? "ok $_\n" : "refused $_ after $TOR_SESSION->{phase}\n" for @ARGV }    # [C17] the order of a Tor window's steps, as sub tor_phase holds it: for selftest
elsif ($command eq 'tnnlconf' && @ARGV == 1) { open(my $in, '<', $ARGV[0]) or die "lzrprf: $ARGV[0] could not be read\n"; my ($vpn, $why) = tnnl_read(do { local $/; <$in> }); print $vpn ? "kept $vpn->{address} $vpn->{endpoint} v6 $vpn->{v6} dns $vpn->{dns}\n" : "refused $why\n" }    # LZRTNNL: what lzrprf keeps of a WireGuard file, for the tests
elsif ($command eq 'tnnlrelay' && @ARGV == 2 && $ARGV[0] =~ /^[0-9]{1,5}\z/) { print tnnl_tried(@ARGV) }    # LZRTNNL: the relay bound to one interface, for the tests
elsif ($command eq 'tnnldrop' && @ARGV == 1 && $ARGV[0] =~ m{\A/[\x21-\x7e]*/\.lzrprf\z} && -d $ARGV[0]) { ($ROOT, $DIR) = ($ARGV[0]) x 2; print tnnl_tried(0, 'drop') }    # LZRTNNL: the VPN dropping under the relay, for the tests (its log lines go to that folder)
elsif ($command eq 'parts' && @ARGV <= 1 && (!@ARGV || $ARGV[0] =~ m{\A/[\x21-\x7e]*/\.lzrprf\z})) { $ROOT = $ARGV[0] if @ARGV; print 'on ', join(' ', grep { part_on($_) } @PARTS_ALL), "\nabsent as installed:", map({ part_left_out($_) ? " $_" : '' } qw(arti core-lzrbrwsr-trmnl)), "\n" }    # the parts installed, as the record of that folder says (sub parts_read), and the programs whose absence sub paired takes for what was installed: for the tests
elsif ($command eq 'partsset' && @ARGV >= 2 && $ARGV[0] =~ m{\A/[\x21-\x7e]*/\.lzrprf\z} && $ARGV[1] =~ m{\A/[\x21-\x7e]*\.app/Contents/MacOS/lzrbrwsr-bin\z}) { ($TRY, $ROOT, $PROGRAM) = (1, shift @ARGV, shift @ARGV); $DIR = $ROOT; parts_set(@ARGV) }    # Restart with these modules, as the modal sends it, for the tests: "lzrprf try" starts nothing again
elsif ($command eq 'incognito') { $INCOGNITO = 1; run(@ARGV ? @ARGV : '/Applications/LZRBRWSR.app/Contents/MacOS/lzrbrwsr-bin') }    # [C16] with no program named: the installed application's
elsif ($command eq 'try' && @ARGV > 4 && $ARGV[0] =~ m{^\Q$DIR\E/[A-Za-z0-9][A-Za-z0-9.]*\z} && $ARGV[1] =~ /^(?:-|127\.0\.0\.1:\d+)$/ && $ARGV[3] =~ /^(?:allow|deny|ask|[1234]{1,9})$/) {
    ($TRY, $DIR, $PEER, $TYPED, $ANSWER) = (1, splice @ARGV, 0, 4);    # for tests: lzrprf try FOLDER PEER|- TYPED|- allow|deny|ask|DIGITS /path/to/program
    if (open my $in, '<', "$DIR/live-seconds") { (<$in> // '') =~ /^([0-9]{1,2}(?:\.[0-9]{1,3})?) ([0-9]{1,2}(?:\.[0-9]{1,3})?)$/ and ($LIVE_STOP_SECONDS, $LIVE_FRAME_SECONDS) = ($1, $2) }    # [C18] "lzrprf try" only: a test's own $LIVE_STOP_SECONDS and $LIVE_FRAME_SECONDS, so what it tries does not hang on how busy the computer is
    if (open my $in, '<', "$DIR/view-scale") { $VIEW_SCALE = 2 if (<$in> // '') eq "2\n" }    # "lzrprf try" only: a test's own retina screen, its tiles drawn at scale 2 (the load test's --scale2)
    run(@ARGV);
}
elsif ($command eq 'profiles' && !@ARGV) { print "$_\t", profile_name($_), "\n" for profile_ids() }    # each profile's id and its name; "--profile" takes each id but "first", which is the profile used without it
elsif ($command eq 'log' && !@ARGV) { show() }
elsif ($command eq 'keep' && @ARGV <= 2) { keep_command(@ARGV) }
elsif ($command eq 'address' && @ARGV) { print !list_read() ? "$_\tnot fetched: lzrprf holds no list of the addresses it never opens: $LIST_WHY\n" : listed($_) ? "-\tnot fetched: $REFUSED\n" : "$_\t" . ((address($_))[0] // 'not fetched: not an address lzrprf fetches') . "\n" for @ARGV }    # [C23] a listed address is not written back either
elsif ($command eq 'request' && @ARGV) { my $other = $ARGV[0] eq '--other' && shift @ARGV; print request((address($_))[0] // '', !$other) for @ARGV }
elsif ($command eq 'public' && @ARGV) {
    for my $number (@ARGV) {
        my $one = numbered($number);
        my $route = !$one ? '' : route($one->{family}, $number) // 'none';
        print "$number\t", public($number) ? 'on the public internet' : 'not public: this computer or a network of your own',
            "\t", { internet => 'sent the way the internet at large is', own => 'sent by a route of its own', none => 'no way there from this computer', '' => 'not a numeric address' }->{$route}, "\n";
    }
}
elsif ($command eq 'mark' && !@ARGV) { print mark(), "\n" }
elsif ($command eq 'filters' && @ARGV >= 4) { filters_dir(@ARGV) }    # [C27] what the lists of a folder would do with addresses: for a survey and for selftest, never for a window
elsif ($command eq 'behind' && @ARGV > 7 && $ARGV[0] =~ /^[01]$/ && $ARGV[2] =~ /^(?:-|127\.0\.0\.1:\d+)$/ && $ARGV[3] =~ /^(?:allow|deny|ask)$/ && $ARGV[4] =~ /^\d+$/ && ($ARGV[5] eq '-' || $ARGV[1] =~ m{/lzrprf-i\.\d+\.[0-9a-f]{12}\z}) && ($ARGV[6] eq '-' || $ARGV[6] =~ /\A[0-9a-f]{12}\z/)) {    # started by run, not by hand: the same five things "try" sets, handed on, for an incognito window the folder its settings are read from, and for a profile's window its id
    ($TRY, $DIR, $PEER, $ANSWER, $RUN, $BASE, $PROFILE) = splice @ARGV, 0, 7;
    ($INCOGNITO, $BASE) = $BASE eq '-' ? (0, undef) : (1, $BASE);
    $TOR_WINDOW = $INCOGNITO && -f "$DIR/torwindow" && !-l "$DIR/torwindow";    # [C17] the incognito folder its window made says it is a Tor window
    $ROOT = $INCOGNITO ? $BASE : $DIR;
    if ($PROFILE eq '-') { undef $PROFILE } elsif ($INCOGNITO) { $BASE = profile_folder($PROFILE) // exit 1 } else { $DIR = profile_folder($PROFILE) // exit 1 }    # the folder of a profile lzrprf knows, or no start: what an incognito window reads, else this window's own
    named(@ARGV);
    $TIMED = $TRY && -e "$ROOT/times";
    open $FROM, '<&=', 0 or exit 1;
    $SIG{PIPE} = 'IGNORE';
    $| = 1;
    behind();
}
elsif ($command eq 'lzr') { $| = 1; exit lzr_main(@ARGV) }    # [C20] LZRTRMNL's own command, lzr, which the terminal's shell finds on its PATH (sub lzr_bin): "lzrprf lzr" with no words lists its commands
elsif ($command eq 'lookup' && @ARGV == 1 && $ARGV[0] =~ /^$NAME$/) { lookup(@ARGV) }    # started for one address that was typed, not by hand
else { die "usage: lzrprf run /path/to/program [arguments]\n       lzrprf lzr [command] [--help] (LZRTRMNL's command: \"lzrprf lzr\" lists them)\n       lzrprf incognito [/path/to/program [arguments]]\n       lzrprf run --profile ID /path/to/program [arguments] (ID: a profile lzrprf made)\n       lzrprf run|incognito --open \"X Y W H\" /path/to/program [arguments] (one line on standard input: the address, or none)\n       lzrprf incognito --profile ID [/path/to/program [arguments]]\n       lzrprf log [--profile ID]\n       lzrprf keep [--profile ID] [nothing|hosts|all [DAYS]]\n       lzrprf profiles\n       lzrprf address TEXT...\n       lzrprf request [--other] TEXT...\n       lzrprf public NUMBER...\n       lzrprf mark\n" }
