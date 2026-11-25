# The parts of LZRBRWSR (Henry, 2026-11-24, HC-0858). The installer asks for each part whether to
# include it, and "Add or remove LZR modules" in the cogwheel's menu changes the same choice later.
# Both write one record, $ROOT/parts (~/.lzrprf/parts): its first line "lzrbrwsr parts 1", then one
# name a line, each a part that is installed. LZRBRWSR itself, the browser with its profiles and its
# settings, is always one of them: the window, and the menu in which the others are switched, are its
# own. The four others:
#   lzrdfndr  LZRDFNDR, the tool of what runs on this Mac (sub tool_shown, the jobs it keeps off)
#   lzrtrmnl  LZRTRMNL, the terminal tab: its program core-lzrbrwsr-trmnl beside the application
#   lzrtnnl   LZRTNNL, Tor and the VPN it may go through: the program arti beside the application
#   lzrgm     LZRGM, the minigame of the local home
# A part that is not installed is shown nowhere in the window, and lzrprf refuses what would start it.
# The program of LZRTRMNL or LZRTNNL is not put beside the application when its part is left out, and
# sub paired takes that file's absence for what was installed. No record (an install before parts
# were asked for) is every part; a record that is not in its form is every part too, and is said once.
# Adding a part whose program is not beside the application fetches nothing by itself: it runs the
# installer of the published release through lzrprf's own signed road (sub parts_fetched, sub
# installed), with the parts as its one word, and that installer checks every file as an install does.
# Removing a part takes its program away and writes the record; the window then starts again with it.
# SYNC: ../lzrbrwsr/packaging/parts.sh.in (the installer's half of the record), 06-behind.pl (sub
#       paired), 28-window2.pl (partsTold, the modal), ../lzrbrwsr/architecture/lzrtnnl.md
my @PARTS_ALL = qw(lzrbrwsr lzrdfndr lzrtrmnl lzrtnnl lzrgm);
my %PART_FILE = (lzrtrmnl => 'core-lzrbrwsr-trmnl', lzrtnnl => 'arti');    # the program a part puts beside the application, for the two parts that have one
my ($PARTS, $PARTS_WHY);                  # the parts installed, read once a run, and why the record was not taken when it was not
sub parts_read {
    return $PARTS if $PARTS;
    my ($text, $why) = beside_read('parts', 4096);
    my %on = map { $_ => 1 } @PARTS_ALL;
    if (defined $text) {
        my @lines = split /\n/, $text;
        if ((shift(@lines) // '') eq 'lzrbrwsr parts 1' && !grep { my $one = $_; !grep { $_ eq $one } @PARTS_ALL } @lines) { %on = (lzrbrwsr => 1, map { $_ => 1 } @lines) }
        else { $PARTS_WHY = "$ROOT/parts is not in the form the installer writes, so every part counts as installed" }
    }
    return $PARTS = \%on;
}
sub part_on { return $_[0] eq 'lzrbrwsr' || parts_read()->{ $_[0] } ? 1 : 0 }
sub part_left_out {                       # true when the file named is the program of a part that was left out, so its absence is what was installed
    my ($file) = @_;
    my ($part) = grep { $PART_FILE{$_} eq $file } keys %PART_FILE;
    return defined $part && !part_on($part);
}
sub parts_told { window('parts on ' . join(' ', grep { part_on($_) } @PARTS_ALL)); noted($PARTS_WHY) if $PARTS_WHY; return }
sub parts_record { return ("lzrbrwsr parts 1", grep { $_ eq 'lzrbrwsr' || $_[0]{$_} } @PARTS_ALL) }    # the record's lines for this set

# "parts set NAME ..." from the modal: the set wanted, LZRBRWSR always in it. What only the record
# holds (LZRDFNDR, LZRGM, a program taken away) is written here and the window starts again; a part
# whose program is not beside the application goes the signed road.
sub parts_set {
    my (@wanted) = @_;
    return window('parts refused An incognito window changes no module: it writes nothing. Open Add or remove LZR modules from a window that is not incognito.') if $INCOGNITO;
    my %want = (lzrbrwsr => 1, map { $_ => 1 } grep { my $one = $_; grep { $_ eq $one } @PARTS_ALL } @wanted);
    my $folder = dirname($PROGRAM);
    my @fetch = grep { $want{$_} && !-f "$folder/$PART_FILE{$_}" } sort keys %PART_FILE;
    my @changed = grep { !$want{$_} != !part_on($_) } @PARTS_ALL;
    return window('parts refused Nothing changed: these are the modules installed now.') unless @changed;
    record('you chose the LZR modules: ' . join(' ', map { uc } grep { $want{$_} } @PARTS_ALL)) or return window("parts refused $UNWRITTEN");    # [C5]
    return parts_fetched(\%want, @fetch) if @fetch;
    unlink "$ROOT/parts.new";
    return window("parts refused The record $ROOT/parts could not be written. Nothing changed.") unless put("$ROOT/parts.new", O_EXCL, parts_record(\%want)) && rename("$ROOT/parts.new", "$ROOT/parts");
    synced($ROOT);
    $PARTS = undef;
    for my $part (grep { !$want{$_} } sort keys %PART_FILE) {    # the program of a part left out goes with it; one that cannot be taken away stays, unused, and is said
        my $file = "$folder/$PART_FILE{$part}";
        next unless -e $file && $PROGRAM =~ m{\.app/Contents/MacOS/};
        unlink($file) ? record("lzrprf took away the program of " . uc($part) . ": $file") : noted("the program of " . uc($part) . " could not be taken away ($file): it stays there unused until the next install");
    }
    if (!$want{lzrtrmnl} && grep { -e "$ROOT/path/$_" } qw(lzr lzr-stg)) {    # lzr, LZRTRMNL's command, goes with it from the PATH folder the installer made (packaging/parts.sh.in); its PATH line, then finding an empty folder, goes at the next install
        unlink map { "$ROOT/path/$_" } qw(lzr lzr-stg);
        rmdir "$ROOT/path";
        record("lzrprf took away lzr, the command of LZRTRMNL, from $ROOT/path");
    }
    window('parts applied');
    return idle('The LZR modules are set: lzrprf tried them as "lzrprf try", and starts nothing.') if $TRY;
    return restarted('The LZR modules are set. LZRBRWSR starts again with them.');
}

# A part whose program is not beside the application: the installer of the published release, the
# newest one, through the road of a newer release (sub release_signed, sub installed). Its manifest must
# be signed and approved as for an update; the release may be this one, never an older one.
sub parts_fetched {
    my ($want, @fetch) = @_;
    my ($release, $newest, undef, $installer, $same) = beside();
    return window('parts refused This application names no place its installer is published, so no program can be added. Run the installer again to add ' . join(', ', map { uc } @fetch) . '.') unless $newest && $installer;
    return window('parts install try ' . join(',', grep { $want->{$_} } @PARTS_ALL)) if $TRY;    # "lzrprf partsset" (a test) stops here: what follows is the road of every update, tested as one
    busy('Looking for the published release, to add ' . join(', ', map { uc } @fetch) . '.');
    my ($host) = $newest =~ m{^https://([^/]+)};
    my $got = fixed('you chose to add ' . join(', ', map { uc } @fetch) . ": lzrprf looks for the published release: $newest", $newest, $host);
    my ($there) = defined $got ? $got =~ m{\AHTTP/1\.1 200 .*?\r\n\r\n(?:[0-9a-f]{1,4}\r\n)?(\d{1,6})\s*(?:0\r\n\r\n)?\z}s : ();
    return window('parts refused The published release number could not be read just now. Nothing changed.') unless defined $there;
    return window("parts refused The published release, $there, is older than this one, $release. Nothing changed.") if $there < $release;
    my ($signed, $refused) = release_signed($there, $there - 1, $installer, $same);    # [C25] this release or a newer one: signed and approved, or nothing runs
    return window("parts refused Release $there is not installed: $refused. Nothing changed.") unless $signed;
    window('parts install');
    $INSTALL_PARTS = join(',', grep { $want->{$_} } @PARTS_ALL);
    installed($there, $installer, $same, $signed);
    $INSTALL_PARTS = undef;
    return;
}
