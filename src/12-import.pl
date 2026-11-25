# Importing bookmarks from another browser. "Import bookmarks..." in the cogwheel's menu opens the
# window's wizard: you choose a browser, then one of its profiles, and that profile is imported at
# once. Another browser's files are read by the reader alone: a fresh system perl running the few
# lines of $IMPORT_READER, started by lzrprf in a container of its own ($CONTAINER, and on top of it
# $IMPORT_ALLOWED), with no network, no writing and no program but itself. It may read these files
# under your home folder and nothing else of it:                                          [C15]
#   Chrome, Edge, Brave, Vivaldi   "Local State" (the names of the profiles) and each profile's "Bookmarks"
#   Firefox                        profiles.ini, a profile's bookmarkbackups folder and the *.jsonlz4 in it
#   Safari                         Library/Safari/Bookmarks.plist
# and it may look whether each browser's own folder, a profile's folder and the folders above them
# are there. It hands back each file whole on its standard output, a plain file of yours of one
# name (a hard link is refused: it may be any file of yours), no link and in no folder that is a
# link, of at most $IMPORT_BYTES. So whatever macOS
# lets LZRBRWSR read, lzrprf reads of another browser these files and nothing else: a profile's
# History or Login Data is refused to the reader by its container (selftest tries that).
# macOS asks nobody about these folders: from macOS 27 it keeps Chrome's and Firefox's (its
# Application Support protection) and, since long before, Safari's from every app that has no Full
# Disk Access, with no prompt an app can ask for. What lzrprf tries, short of Full Disk Access, is
# your choice in the system's Open panel: when the reader is kept out of a browser you chose other
# than Safari (whose files only Full Disk Access lets through), the window opens that panel at the
# browser's own folder with its button "Allow", once a browser in an import (sub import_kept).
# Allow on exactly that folder has the reader try again at once (sub import_allowed); another
# folder, or Cancel, ends in one sentence. Whether the panel opens from the window's container and
# whether Allow lets the reader through is for a real Mac to show: a panel that could not be shown
# is a line of the log (sub import_unshown), and the words say "try". What Allow sends lzrprf is only
# a word: the reader's container is the same before and after, and what changes is what macOS
# itself lets through. lzrprf never asks for Full Disk Access and never opens System Settings; an
# HTML file exported by the browser still works. An HTML file of
# yours (in Downloads, Desktop or Documents, or a path typed) is read by lzrprf itself.
# Firefox's places.sqlite would need a program (sqlite3) and is not read: its own backups hold the
# same bookmarks. Each bookmark goes through the checks a bookmark you add gets: its name through
# sub plain_name, its address through sub address (one lzrprf does not fetch is skipped and
# counted), at most $MARKS_MOST in all and folders at most $MARKS_DEEP deep, at most
# $IMPORT_FOLDERS folders and none without a bookmark in it (what does not fit is left out and
# counted), and it is written by sub mark_written and named last in its folder's
# order (sub order_set). The source's bookmarks bar goes into "Bookmarks bar", folders and all;
# each of its other top folders keeps its name at the top ("Other bookmarks", "Mobile bookmarks",
# "Bookmarks menu", "Reading List"). A bookmark whose folder and address are there already is
# passed over, so importing a profile twice adds nothing twice; folder names are compared as the
# disk compares them, without case, and a folder there already keeps the name it has. Nothing imported is fetched [C4]:
# a bookmark is fetched when you open it, as one you made.
my $IMPORT_BYTES = 32 * 1024 * 1024;      # DECLARED(the most of one file that is read: Chrome's own file for ten thousand bookmarks is about 3 MB)
my $IMPORT_OUT = 64 * 1024 * 1024;        # DECLARED(the most a Firefox backup may unpack to: twice the most of a file that is read)
my $IMPORT_NODES = 100_000;               # DECLARED(the most bookmarks and folders taken from one file: a hundred times $MARKS_MOST; the rest is left out)
my $IMPORT_DEPTH = 64;                    # DECLARED(the most folders inside folders read from one file: what is deeper is left out; four are kept)
my $IMPORT_FOUND = 20;                    # DECLARED(the most bookmarks files the HTML step offers: the newest)
my $IMPORT_SECONDS = 30;                  # DECLARED(the most one step of the reader is given: 32 MiB from a disk takes well under a second)
my %BROWSERS = (chrome => ['Chrome', 'Library/Application Support/Google/Chrome'], edge => ['Edge', 'Library/Application Support/Microsoft Edge'],
    brave => ['Brave', 'Library/Application Support/BraveSoftware/Brave-Browser'], vivaldi => ['Vivaldi', 'Library/Application Support/Vivaldi'],
    firefox => ['Firefox', 'Library/Application Support/Firefox'], safari => ['Safari', 'Library/Safari'], file => ['HTML file', '']);
my @BROWSERS = qw(chrome edge brave firefox safari vivaldi);    # in the wizard's order; Vivaldi is the owner's pick of a sixth
my ($IMPORT_KEY, @IMPORT_FROM);           # the browser chosen; its profiles or files: [what the window shows, the file]
my $IMPORT_CUT = 0;                       # whether the property list being read asked for more work than its budget: what lies past it was not read
my $IMPORT_SEEN = 0;                      # how many bookmarks and folders the file being read has given so far
my $IMPORT_PROBE = 255;                   # DECLARED(Chrome names its profiles Default and Profile 1, 2, ... and never uses a number twice: when its Local State cannot be read, Profile 1 to this one are looked for, in one request of the reader, and the log names the bound)
my $IMPORT_PROFILES = 99;                 # DECLARED(the most profiles of one browser that are looked at and listed: the window takes a profile's number below 100; the rest are left out and said)
my $IMPORT_MORE = 0;                      # how many profiles of the browser chosen were left out
my $IMPORT_UNNAMED = '';                  # why the browser chosen had its profiles' names unread, said in the log; "" when they were read
my $IMPORT_FOLDERS = 1000;                # DECLARED(the most folders one import makes, as many as bookmarks fit: a folder past it is left out with what is in it, counted)
my %IMPORT_LIFTED;                        # "lzrprf try" alone: each browser whose own folder an Allow chose in this import, for the test's refusals that an Allow lifts
my ($IMPORT_ASKING, $IMPORT_AGAIN, %IMPORT_ASKED) = ('', '');    # the browser whose folder the Open panel asks for now, what is read again after Allow ("profiles" or a profile's number), and each browser asked for in this import
my %IMPORT_WHY = (refused => 'macOS kept it out', denied => 'its permissions do not let you read it', home => 'the path of your home folder holds a character the reader does not take', start => 'the reader could not start', missing => 'it is not there', link => 'it is a link, or a folder above it is, and lzrprf follows no link', other => 'it is not a plain file of yours', large => 'it is larger than 32 MiB', unreadable => 'it could not be read');

# The reader's container, on top of $CONTAINER (sub contain): HOME is your home folder, HOME_RE the
# same as a pattern. The patterns are the files above and no other; a name in them is any name
# without a slash, so they reach no folder deeper than the one named. One or two levels inside a
# browser's folder it may look at what is there (stat) only of a folder or a link, the profiles and
# the links the reader looks for; a file there, as Last Version or places.sqlite, it may not even
# see unless it is one of the files it reads.
my $IMPORT_ALLOWED = <<'END';
(allow file-read-metadata
  (literal (string-append (param "HOME") "/Library/Application Support"))
  (literal (string-append (param "HOME") "/Library/Application Support/Google"))
  (literal (string-append (param "HOME") "/Library/Application Support/BraveSoftware"))
  (literal (string-append (param "HOME") "/Library/Application Support/Google/Chrome"))
  (literal (string-append (param "HOME") "/Library/Application Support/Microsoft Edge"))
  (literal (string-append (param "HOME") "/Library/Application Support/BraveSoftware/Brave-Browser"))
  (literal (string-append (param "HOME") "/Library/Application Support/Vivaldi"))
  (literal (string-append (param "HOME") "/Library/Application Support/Firefox"))
  (literal (string-append (param "HOME") "/Library/Safari"))
  (require-all (require-any (vnode-type DIRECTORY) (vnode-type SYMLINK))
    (require-any
      (regex (string-append "^" (param "HOME_RE") "/Library/Application Support/(Google/Chrome|Microsoft Edge|BraveSoftware/Brave-Browser|Vivaldi)/[^/]+$"))
      (regex (string-append "^" (param "HOME_RE") "/Library/Application Support/Firefox/[^/]+(/[^/]+)?$")))))
(allow file-read*
  (regex (string-append "^" (param "HOME_RE") "/Library/Application Support/(Google/Chrome|Microsoft Edge|BraveSoftware/Brave-Browser|Vivaldi)/(Local State|[^/]+/Bookmarks)$"))
  (regex (string-append "^" (param "HOME_RE") "/Library/Application Support/Firefox/(profiles[.]ini|([^/]+/)?[^/]+/bookmarkbackups(/[^/]+[.]jsonlz4)?)$"))
  (literal (string-append (param "HOME") "/Library/Safari/Bookmarks.plist")))
END

# The reader: the most bytes of one file, the home folder, then requests, each "r:" (a file's
# bytes), "l:" (the names of the *.jsonlz4 in a folder) or "s:" (what is there: a folder, a file, a
# link or other) and a path. It says "reader" first, then for each "ok LENGTH", a line end and that
# many bytes, or "no WHY" and a line end. WHY "refused" is EPERM, which is how macOS keeps a folder
# out; "denied" is EACCES, a file's own permissions; "link" is a link, a file of more than one name
# (a hard link) or a folder on the way that is a link, as a browser's data folder moved elsewhere.
my $IMPORT_READER = <<'END';
use Fcntl qw(O_RDONLY O_NOFOLLOW O_NONBLOCK);
my ($most, $home) = (shift, shift);
binmode STDOUT;
my $why = sub { $!{EPERM} ? 'refused' : $!{EACCES} ? 'denied' : $!{ELOOP} ? 'link' : $!{ENOENT} || $!{ENOTDIR} ? 'missing' : 'unreadable' };
my $linked = sub { my $up = $_[0]; while ($up =~ s{/[^/]+\z}{} && length $up > length "$home/Library") { return 1 if lstat($up) && -l _ } return 0 };
print "reader\n";
for my $asked (@ARGV) {
    my ($do, $path) = $asked =~ m{\A([rls]):(/.*)\z}s or (print("no unreadable\n"), next);
    my ($out, $no);
    if ($do eq 's') { $out = lstat($path) ? (-l _ ? 'link' : -d _ ? 'folder' : -f _ ? 'file' : 'other') : undef; $no = $why->() unless defined $out }
    elsif ($do eq 'l') {
        if (!lstat $path) { $no = $why->() } elsif (!-d _) { $no = -l _ ? 'link' : 'other' }
        elsif (opendir my $in, $path) { $out = join "\n", sort grep { /\A[^.\/][^\/\n]{0,200}\.jsonlz4\z/ } readdir $in } else { $no = $why->() }
    } elsif (!sysopen my $in, $path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) { $no = $why->() }
    else {
        my @is = stat $in;
        if (!-f _ || $is[4] != $<) { $no = 'other' } elsif ($is[3] != 1) { $no = 'link' } elsif ($is[7] > $most) { $no = 'large' }
        else {
            my $got;
            $out = '';
            while (($got = sysread $in, $out, 1 << 20, length $out) && length $out <= $most) { }
            ($no, $out) = ('unreadable', undef) unless defined $got && length $out <= $most;
        }
    }
    ($out, $no) = (undef, 'link') if ($no // '') ne 'link' && $linked->($path);    # read or not: a folder on the way that is a link, even one that leads back inside the browser's folder, is a link, and nothing of it is taken
    print defined $out ? 'ok ' . length($out) . "\n$out" : "no $no\n";
}
END

sub import_home { $TRY ? "$ROOT/home" : $HOME }    # "lzrprf try": the test's own folder stands for the home folder

sub import_base { (abs_path(import_home()) // import_home()) . '/' . $BROWSERS{$_[0]}[1] }    # by the resolved path of your home folder, as the reader's container names it

sub import_reader {                       # what the reader said of each request: [the bytes, or undef and why]
    my @asked = @_;
    my $home = abs_path(import_home()) // '';
    my $none = sub { my ($why) = @_; return map { [undef, $why] } @asked };
    return $none->('home') unless $home =~ m{\A/[A-Za-z0-9 ._/+@,-]*\z};    # a home folder whose path a pattern could misread: nothing is read
    (my $pattern = $home) =~ s/([^A-Za-z0-9 \/_-])/[$1]/g;
    my $kept = '';                        # "lzrprf try" alone: the files its folder's "kept" names are refused to the reader as macOS refuses them (EPERM: looked at, not read), so that a test can stand for macOS
    if ($TRY && open my $list, '<', "$ROOT/kept") { $kept .= qq{(deny file-read-data (literal (string-append (param "HOME") "/$_")))\n} for grep { m{\A[A-Za-z0-9 ._/-]{1,300}\z} && !m{(?:^|/)\.\.?(?:/|$)} } map { my $line = s/\n\z//r; $line =~ s/^allowed:// && grep({ index($line, "$BROWSERS{$_}[1]/") == 0 } keys %IMPORT_LIFTED) ? () : $line } <$list> }    # a line "allowed:FILE" is refused only until an Allow on its browser's folder in this import, as macOS lifts its refusal for the folder chosen in the Open panel
    pipe(my $from, my $to) or return $none->('start');
    my $child = fork // return $none->('start');
    if (!$child) {
        close $from;
        become(undef, $to, undef, $FETCH_LIMITS, contain($IMPORT_ALLOWED . $kept, '/usr/bin/perl', '-D', "HOME=$home", '-D', "HOME_RE=$pattern"), '-e', $IMPORT_READER, $IMPORT_BYTES, $home, @asked);
    }
    close $to;
    my ($text, $until, $most) = ('', now() + $IMPORT_SECONDS, (grep { /^r:/ } @asked) * ($IMPORT_BYTES + 64) + 65536 * @asked);
    while ((my $left = $until - now()) > 0 && length $text <= $most) {
        my $ready = '';
        vec($ready, fileno $from, 1) = 1;
        select($ready, undef, undef, $left > 1 ? 1 : $left) > 0 or next;
        my $got = sysread($from, $text, 1 << 20, length $text);
        next if !defined $got && $!{EINTR};
        last unless $got;
    }
    close $from;
    ended($child, 2);
    return $none->('start') unless $text =~ /\Greader\n/gc;    # the reader did not start: no answer of it stands
    my @said;
    for (@asked) {
        if ($text =~ /\Gok (\d{1,9})\n/gc && pos($text) + $1 <= length $text) { push @said, [substr($text, pos($text), $1)]; pos($text) += $1 }
        elsif ($text =~ /\Gno (refused|denied|missing|link|other|large|unreadable)\n/gc) { push @said, [undef, $1] }
        else { last }
    }
    push @said, [undef, 'unreadable'] while @said < @asked;    # the reader ended before it said them all
    return @said;
}

sub import_read {                         # an HTML file's bytes, read by lzrprf itself, or nothing and why (a key of %IMPORT_WHY)
    my ($file) = @_;
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return (undef, $!{EPERM} ? 'refused' : $!{EACCES} ? 'denied' : $!{ELOOP} ? 'link' : 'missing');
    my @is = stat $in;
    return (undef, 'other') unless -f _ && $is[4] == $<;
    return (undef, 'link') if $is[3] != 1;    # a hard link: the same file by another name, which may be any file of yours
    return (undef, 'large') if $is[7] > $IMPORT_BYTES;
    my ($text, $got) = ('', 0);
    while (($got = sysread($in, $text, 1 << 20, length $text)) && length $text <= $IMPORT_BYTES) { }
    return (undef, 'unreadable') unless defined $got && length $text <= $IMPORT_BYTES;
    return $text;
}

sub import_node {                         # one bookmark or folder of a file, or nothing once $IMPORT_NODES were taken
    my ($name, $url, $kids) = @_;
    return if ++$IMPORT_SEEN > $IMPORT_NODES;
    $name //= '';
    utf8::encode($name) if utf8::is_utf8($name);
    return $kids ? { name => $name, kids => $kids } : { name => $name, url => $url // '' };
}

sub import_json {                         # a JSON text, decoded by the JSON code that comes with the system's perl, or nothing and why in $@
    my ($text) = @_;
    require JSON::PP;
    my $all = eval { JSON::PP->new->utf8->max_depth(2 * $IMPORT_DEPTH + 8)->decode($text) };
    return $all if defined $all || $@ !~ /malformed UTF-8|surrogate/;
    my $first = $@;
    require Encode;                       # one bad character anywhere would lose the whole file: a byte that is no UTF-8, or half of a pair written as \uD800 to \uDFFF, becomes U+FFFD, as a browser shows it, and the file is read again
    my $chars = Encode::decode('UTF-8', $text);
    $chars =~ s/(?<!\\)((?:\\\\)*)\\u(d[89ab][0-9a-f]{2})(?!\\ud[c-f][0-9a-f]{2})/$1\\ufffd/gi;
    $chars =~ s/(?<!\\)((?:\\\\)*)(\\ud[89ab][0-9a-f]{2})?\\u(d[c-f][0-9a-f]{2})/defined $2 ? "$1$2\\u$3" : "$1\\ufffd"/gie;
    $all = eval { JSON::PP->new->max_depth(2 * $IMPORT_DEPTH + 8)->decode($chars) };
    $@ = $first unless defined $all;
    return $all;
}

sub import_json_member {                  # the text of one member of a JSON object's top level, found without decoding the rest, or nothing: strings, brackets and words are stepped over and counted
    my ($text, $name) = @_;
    my ($depth, $wanted, $from) = (0, 0);
    pos($text) = 0;
    while ($text =~ /\G\s*(?:(")|([{\[])|([}\]])|([:,])|(-?[0-9][0-9.eE+-]*+|true|false|null))/gc) {
        if (defined $1) {                 # a string, stepped over here and not by one pattern, which gives up past some thousands of escapes
            my $at = pos($text) - 1;
            while (1) { $text =~ /\G[^"\\]*+/gc; last if $text =~ /\G"/gc; $text =~ /\G\\./gcs or return }    # no end: not JSON
            if (defined $from) { return substr($text, $from, pos($text) - $from) if $depth == 1; next }    # the member is a string
            $wanted = $depth == 1 && substr($text, $at, pos($text) - $at) eq qq("$name");
            next;
        }
        if (defined $2) { $depth++; next }
        if (defined $3) { $depth--; return substr($text, $from, pos($text) - $from) if defined $from && $depth == 1; return if $depth < 1; next }
        if (defined $from) { return substr($text, $from, pos($text) - $from) if $depth == 1 && !defined $4; next }    # a value that is no object or array
        if (defined $4 && $4 eq ':' && $wanted && $depth == 1) { $text =~ /\G\s*/gc; $from = pos($text) }
    }
    return;
}

sub lz4_block {                           # an LZ4 block (the block format of lz4) unpacked, at most $most bytes; nothing for one that is not well formed
    my ($in, $most) = @_;
    my ($at, $end, $out) = (0, length $in, '');
    my $more = sub { my $n = 0; while (1) { return -1 if $at >= $end; my $byte = ord substr($in, $at++, 1); $n += $byte; return $n if $byte != 255 } };
    while ($at < $end) {
        my $token = ord substr($in, $at++, 1);
        my $literals = $token >> 4;
        if ($literals == 15) { my $n = $more->(); return if $n < 0; $literals += $n }
        return if $at + $literals > $end || length($out) + $literals > $most;
        $out .= substr($in, $at, $literals);
        $at += $literals;
        last if $at == $end;              # the last sequence holds literals alone
        return if $at + 2 > $end;
        my $back = unpack 'v', substr($in, $at, 2);
        $at += 2;
        return if !$back || $back > length $out;
        my $length = $token & 15;
        if ($length == 15) { my $n = $more->(); return if $n < 0; $length += $n }
        $length += 4;
        return if length($out) + $length > $most;
        my $from = substr($out, length($out) - $back, $back < $length ? $back : $length);
        $out .= $back >= $length ? $from : substr($from x (int($length / $back) + 1), 0, $length);    # a copy that overlaps itself repeats what it copies
    }
    return $out;
}

sub plist_binary {                        # a binary property list (bplist00) as Perl data, or nothing: strings, numbers, arrays and dictionaries; what else it holds is undef
    my ($text) = @_;
    return unless length $text >= 40 && substr($text, 0, 8) eq 'bplist00';
    my ($size, $refs, $count, $top, $table) = unpack 'x6 C C Q> Q> Q>', substr($text, -32);
    return unless $size >= 1 && $size <= 8 && $refs >= 1 && $refs <= 8 && $count <= length($text) && $top < $count && $table + $count * $size <= length($text) - 32;
    my $int = sub { my ($at, $n) = @_; my $v = 0; $v = $v * 256 + ord substr($text, $at + $_, 1) for 0 .. $n - 1; return $v };
    my ($steps, %path) = (0);              # %path: the objects being read, from the top to here; one that holds itself is not read again
    my $object; $object = sub {
        my ($ref, $deep) = @_;
        return if ++$steps > 4 * $IMPORT_NODES || $ref >= $count || $deep > $IMPORT_DEPTH * 2 + 8 || $path{$ref};
        local $path{$ref} = 1;
        my $at = $int->($table + $ref * $size, $size);
        return if $at >= length($text) - 32;
        my $marker = ord substr($text, $at, 1);
        my ($kind, $n) = ($marker >> 4, $marker & 15);
        my $body = $at + 1;
        if ($kind != 0 && $kind != 1 && $kind != 2 && $kind != 3 && $kind != 8 && $n == 15) {    # a length of 15 or more follows as a number of its own
            my $head = ord substr($text, $body, 1);
            return unless $head >> 4 == 1;
            my $bytes = 1 << ($head & 15);
            return if $bytes > 8;
            $n = $int->($body + 1, $bytes);
            $body += 1 + $bytes;
        }
        if ($kind == 1) { return $int->($body, 1 << $n) if (1 << $n) <= 8; return }
        if ($kind == 5) { return if $body + $n > length $text; return substr($text, $body, $n) }
        if ($kind == 6) {
            return if $body + 2 * $n > length $text;
            require Encode;
            my $chars = eval { Encode::decode('UTF-16BE', substr($text, $body, 2 * $n)) } // return;
            utf8::encode($chars);
            return $chars;
        }
        if ($kind == 10) {
            return if $body + $n * $refs > length $text;
            my @list;
            for my $k (0 .. $n - 1) { last if $steps > 4 * $IMPORT_NODES; push @list, $object->($int->($body + $k * $refs, $refs), $deep + 1) }    # past the budget nothing more is read
            return \@list;
        }
        if ($kind == 13) {
            return if $body + 2 * $n * $refs > length $text;
            my %dict;
            for my $k (0 .. $n - 1) {
                last if $steps > 4 * $IMPORT_NODES;
                my $key = $object->($int->($body + $k * $refs, $refs), $deep + 1);
                $dict{$key} = $object->($int->($body + ($n + $k) * $refs, $refs), $deep + 1) if defined $key && !ref $key;
            }
            return \%dict;
        }
        return;
    };
    my $all = $object->($top, 0);
    $IMPORT_CUT = 1 if $steps > 4 * $IMPORT_NODES;    # past the budget: what was read within it stands, and the rest is said not read
    return $all;
}

sub html_text {                           # the text of HTML with its entities as characters, in UTF-8
    my ($text) = @_;
    my $char = sub { my $n = $_[0]; return '?' if $n > 0x10ffff || $n >= 0xd800 && $n <= 0xdfff; my $c = chr $n; utf8::encode($c); return $c };
    $text =~ s/&(?:#(\d{1,7})|#[xX]([0-9A-Fa-f]{1,6})|(amp|lt|gt|quot|apos|nbsp));/defined $1 ? $char->($1) : defined $2 ? $char->(hex $2) : { amp => '&', lt => '<', gt => '>', quot => '"', apos => "'", nbsp => ' ' }->{$3}/ge;
    return $text;
}

sub import_html {                         # the Netscape bookmarks file every browser exports: (its bar, the rest)
    my ($text) = @_;
    return unless $text =~ /NETSCAPE-Bookmark-file-1/i;
    my (@stack, $waiting) = ([]);
    my $root = $stack[0];
    while ($text =~ m{<(/?)(DL|H3|A)\b([^>]*)>(?:([^<]*)</(?:H3|A)\s*>)?}gi) {
        my ($close, $tag, $attributes, $inner) = ($1, uc $2, $3, $4 // '');
        if ($tag eq 'DL') {
            if ($close) { pop @stack if @stack > 1 }
            else { push @stack, $waiting ? $waiting->{kids} : $stack[-1]; undef $waiting }
            next;
        }
        next if $close;
        my $name = html_text($inner =~ s/\s+/ /gr);
        if ($tag eq 'H3') {
            my $folder = @stack <= $IMPORT_DEPTH ? import_node($name, undef, []) : undef;
            $waiting = $folder // { kids => [] };    # a folder too deep, or one too many, takes what is in it with it
            $folder->{bar} = 1 if $folder && $attributes =~ /PERSONAL_TOOLBAR_FOLDER\s*=\s*"true"/i;
            $folder->{unfiled} = 1 if $folder && $attributes =~ /UNFILED_BOOKMARKS_FOLDER\s*=\s*"true"/i;    # Firefox's Other Bookmarks
            push @{ $stack[-1] }, $folder if $folder;
        } else {
            my ($href) = $attributes =~ /\bHREF\s*=\s*"([^"]*)"/i;
            my $mark = import_node($name, html_text($href // '')) or next;
            push @{ $stack[-1] }, $mark;
        }
    }
    my ($bar) = grep { $_->{kids} && $_->{bar} } @$root;
    ($bar) = grep { $_->{kids} && $_->{name} =~ /^(?:Bookmarks ?bar|Bookmarks Toolbar|Favou?rites|BookmarksBar)$/i } @$root unless $bar;    # Safari's export names its bar Favorites and marks it no other way
    my @rest = grep { !$bar || $_ != $bar } @$root;
    my ($unfiled) = grep { $_->{kids} && $_->{unfiled} } @rest;
    return ($bar ? $bar->{kids} : [], import_tops('Bookmarks menu' => [grep { $_ != $unfiled } @rest], 'Other bookmarks' => $unfiled->{kids})) if $unfiled;    # Firefox's export: what is at its top is its Bookmarks Menu, as in its own backups
    my @loose = grep { !$_->{kids} } @rest;
    my ($other) = grep { $_->{kids} && $_->{name} =~ /^Other bookmarks$/i } @rest;
    push @{ $other->{kids} }, @loose if $other;    # bookmarks at the top of the file go into Other bookmarks, as Chrome keeps them
    return ($bar ? $bar->{kids} : [], [(grep { $_->{kids} } @rest), $other ? () : @{ import_tops('Other bookmarks' => \@loose) }]);
}

sub import_chromium {                     # Chrome's Bookmarks file, and that of each browser made from Chromium: (its bar, the rest)
    my ($text) = @_;
    my $all = import_json($text);
    return unless ref $all eq 'HASH' && ref $all->{roots} eq 'HASH';
    my $nodes; $nodes = sub {
        my ($list, $deep) = @_;
        return [] unless ref $list eq 'ARRAY' && $deep <= $IMPORT_DEPTH;
        return [map { ref $_ ne 'HASH' ? () : ($_->{type} // '') eq 'folder' ? (import_node($_->{name}, undef, $nodes->($_->{children}, $deep + 1)) // ()) : ($_->{type} // '') eq 'url' ? (import_node($_->{name}, $_->{url}) // ()) : () } @$list];
    };
    my $roots = $all->{roots};
    my $top = sub { ref $roots->{$_[0]} eq 'HASH' ? $nodes->($roots->{$_[0]}{children}, 1) : [] };
    return ($top->('bookmark_bar'), import_tops('Other bookmarks' => $top->('other'), 'Mobile bookmarks' => $top->('synced')));
}

sub import_tops { my @tops = @_; return [map { my ($name, $kids) = @tops[2 * $_, 2 * $_ + 1]; @$kids ? import_node($name, undef, $kids) // () : () } 0 .. $#tops / 2] }    # a source's top folders but its bar, each under its own name, the empty ones left out


sub import_firefox {                      # a Firefox backup, bookmarkbackups/*.jsonlz4: "mozLz40", a zero byte, the size unpacked in 4 bytes, then one LZ4 block
    my ($text) = @_;
    return unless length $text > 12 && substr($text, 0, 8) eq "mozLz40\0";
    my $size = unpack 'V', substr($text, 8, 4);
    return if $size > $IMPORT_OUT;
    my $json = lz4_block(substr($text, 12), $size) // return;
    return unless length $json == $size;
    my $all = import_json($json);
    return unless ref $all eq 'HASH' && ref $all->{children} eq 'ARRAY';
    my $nodes; $nodes = sub {
        my ($list, $deep) = @_;
        return [] unless ref $list eq 'ARRAY' && $deep <= $IMPORT_DEPTH;
        return [map { ref $_ ne 'HASH' ? () : ($_->{type} // '') eq 'text/x-moz-place-container' ? (import_node($_->{title}, undef, $nodes->($_->{children}, $deep + 1)) // ()) : ($_->{type} // '') eq 'text/x-moz-place' ? (import_node($_->{title}, $_->{uri}) // ()) : () } @$list];
    };
    my %root = map { ref $_ eq 'HASH' && defined $_->{guid} ? ($_->{guid} => $_->{children}) : () } @{ $all->{children} };
    return ($nodes->($root{toolbar_____}, 1), import_tops('Bookmarks menu' => $nodes->($root{menu________}, 1), 'Other bookmarks' => $nodes->($root{unfiled_____}, 1), 'Mobile bookmarks' => $nodes->($root{mobile______}, 1)));
}

sub import_safari {                       # Safari's Bookmarks.plist: (its bar, the rest)
    my ($text) = @_;
    my $all = plist_binary($text);
    return unless ref $all eq 'HASH' && ref $all->{Children} eq 'ARRAY';
    my $nodes; $nodes = sub {
        my ($list, $deep) = @_;
        return [] unless ref $list eq 'ARRAY' && $deep <= $IMPORT_DEPTH;
        return [map {
            my $one = $_;
            my $type = ref $one eq 'HASH' ? $one->{WebBookmarkType} // '' : '';
            $type eq 'WebBookmarkTypeList' ? (import_node($one->{Title}, undef, $nodes->($one->{Children}, $deep + 1)) // ())
                : $type eq 'WebBookmarkTypeLeaf' ? (import_node(ref $one->{URIDictionary} eq 'HASH' ? $one->{URIDictionary}{title} : '', $one->{URLString}) // ()) : ()
        } @$list];
    };
    my %root = map { ref $_ eq 'HASH' ? (($_->{Title} // '') => $_) : () } @{ $all->{Children} };
    my $top = sub { $root{$_[0]} ? $nodes->($root{$_[0]}{Children}, 1) : [] };
    return ($top->('BookmarksBar'), import_tops('Bookmarks menu' => $top->('BookmarksMenu'), 'Reading List' => $top->('com.apple.ReadingList')));
}

sub import_profiles_of {                  # a browser's profiles that hold bookmarks: why none was found, or undef; then each [the name shown, the file]
    my ($key) = @_;
    my $base = import_base($key);
    if ($key eq 'safari') {
        my ($there) = import_reader("s:$base/Bookmarks.plist");
        return (undef, ['Safari', "$base/Bookmarks.plist"]) if defined $there->[0] || $there->[1] =~ /^(?:refused|denied|link)$/;    # kept out, or not a plain file: why is said when it is chosen
        return import_why($there);
    }
    if ($key eq 'firefox') {
        my ($ini) = import_reader("r:$base/profiles.ini");
        return $ini->[1] unless defined $ini->[0];
        my (@dirs, %one);
        for my $line (split /\r?\n/, "$ini->[0]\n[end]") {
            if ($line =~ /^\[/) {
                my $path = $one{Path} // '';
                $path = index($path, "$base/") == 0 ? substr($path, length "$base/") : '' if ($one{IsRelative} // '1') ne '1';    # an absolute path is read only in Firefox's own folder
                push @dirs, [plain_name($one{Name} // $path), "$base/$path"] if $path =~ m{\A[^/.][^/]*(?:/[^/.][^/]*)?\z};
                %one = ();
            } elsif ($line =~ /^(Name|Path|IsRelative)=(.{1,500})$/) { $one{$1} = $2 }
        }
        ($IMPORT_MORE, $#dirs) = (@dirs - $IMPORT_PROFILES, $IMPORT_PROFILES - 1) if @dirs > $IMPORT_PROFILES;
        my @lists = import_reader(map { "l:$_->[1]/bookmarkbackups" } @dirs);
        my @found = map { my ($newest) = reverse split /\n/, $lists[$_][0] // ''; $newest ? [$dirs[$_][0], "$dirs[$_][1]/bookmarkbackups/$newest"] : () } 0 .. $#dirs;    # the names come sorted, and begin with the day: the last is the newest
        return (@found ? undef : import_why(@lists), @found);
    }
    my ($state) = import_reader("r:$base/Local State");    # the names of the profiles, as the browser's own profile picker shows them
    my $part = defined $state->[0] ? import_json_member($state->[0], 'profile') : undef;    # a Local State is often megabytes: the one member read alone takes a thousandth of the time
    my $all = defined $part ? import_json(qq({"profile":$part})) : undef;
    $all = import_json($state->[0]) if defined $state->[0] && ref $all ne 'HASH';    # not found so: the whole is read, and why it fails is said
    my $cache = ref $all eq 'HASH' && ref $all->{profile} eq 'HASH' && ref $all->{profile}{info_cache} eq 'HASH' ? $all->{profile}{info_cache} : undef;
    if (!$cache && ($state->[1] // '') eq 'refused' && !$IMPORT_ASKED{$key}) {    # macOS lets the reader see the profiles' files and not read the names: the Open panel asks first, so that after Allow the names are read with the rest
        noted("macOS kept lzrprf's reader out of $BROWSERS{$key}[0]'s Local State (EPERM), where the names of its profiles are, so the Open panel asks for $BROWSERS{$key}[0]'s folder before they are listed.");    # the line a real Mac's log shows of it
        return 'refused';
    }
    $IMPORT_UNNAMED = $cache ? '' : defined $state->[0] ? (defined $all ? 'it holds no list of profiles' : 'it is not JSON lzrprf reads (' . ($@ =~ s/\s+at \S+ line \d+.*//sr =~ s/[^\x20-\x7e]/?/gr) . ')') : $IMPORT_WHY{ $state->[1] };    # why the folders' names are shown, for the log
    $IMPORT_UNNAMED .= "; the profiles were looked for as Default and Profile 1 to Profile $IMPORT_PROBE" if !$cache;
    my $probed = !$cache;
    $cache //= { map { $_ => {} } 'Default', map { "Profile $_" } 1 .. $IMPORT_PROBE };    # no names to read: the profiles are looked for by their usual folders
    my @dirs = grep { /^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}\z/ } sort keys %$cache;
    ($IMPORT_MORE, $#dirs) = (@dirs - $IMPORT_PROFILES, $IMPORT_PROFILES - 1) if !$probed && @dirs > $IMPORT_PROFILES;    # folders looked for are counted once found
    my @there = import_reader(map { "s:$base/$_/Bookmarks" } @dirs);
    my $bytes = sub { my ($text) = @_; utf8::encode($text) if utf8::is_utf8($text); return $text };
    my $chars = sub { my ($text) = @_; utf8::decode($text); return $text };
    my @found = map {    # each as shown: the name and the address made plain first, so that two alike on the screen are alike here; a Bookmarks that is a link or no plain file is shown, and why it is not read is said when it is chosen
        my ($name, $address, $dir) = ($there[$_][0] // '') =~ /^(?:file|link|other)$/ ? @{ import_profile_name($dirs[$_], $cache->{ $dirs[$_] }) } : ();
        defined $dir ? [plain_name($bytes->($name), $dir), "$base/$dir/Bookmarks", length $address ? plain_name($bytes->($address), '') : '', $dir] : ();
    } 0 .. $#dirs;
    ($IMPORT_MORE, $#found) = (@found - $IMPORT_PROFILES, $IMPORT_PROFILES - 1) if @found > $IMPORT_PROFILES;
    require Unicode::Normalize; my $alike = sub { lc Unicode::Normalize::NFC($chars->($_[0])) };    # composed and lower case: an a with a ring as one character or as two is the same name
    my %named; $named{ $alike->("$_->[0]\t$_->[2]") }++ for @found;
    require Unicode::Collate;
    my $order = Unicode::Collate->new(level => 2);    # by name as the browser's picker lists them, Å with A and ö with o
    @found = map { [$_->[1][0], $_->[1][1], $named{ $alike->("$_->[1][0]\t$_->[1][2]") } > 1 ? $_->[1][3] : $_->[1][2]] }    # the account's address beside a name, and the folder only where two are alike in both
        sort { $order->cmp($a->[0][0], $b->[0][0]) || $order->cmp($a->[0][1], $b->[0][1]) || $a->[1][3] cmp $b->[1][3] }
        map { [[$chars->($_->[0]), $chars->($_->[2])], $_] } @found;
    return (@found ? undef : import_why($state, @there), @found);
}

sub import_profile_name {                 # one profile of a browser made from Chromium as its picker shows it: (the name, the account's address or "", the folder), in characters
    my ($dir, $one) = @_;
    $one = {} unless ref $one eq 'HASH';
    my $text = sub { my $v = $one->{ $_[0] }; return defined $v && !ref $v ? $v =~ s/\s+/ /gr =~ s/^ | $//gr : '' };
    my ($name, $gaia) = ($text->('name'), length $text->('gaia_given_name') ? $text->('gaia_given_name') : $text->('gaia_name'));
    $name = $gaia if length $gaia && ($one->{is_using_default_name} || !length $name);    # "Person 1" or "Your Chrome" while the name is the default: the picker shows the account's given name
    $name = $dir unless length $name;    # the folder, as a last resort
    my $address = $text->('user_name');
    $address = '' unless $address =~ /\A[^\s\@]{1,200}\@[^\s\@]{1,200}\z/;
    return [$name, $address, $dir];
}

sub import_why { my %is = map { ($_->[1] // '') => 1 } @_; return (grep { $is{$_} } qw(home start refused denied link other large unreadable))[0] // 'missing' }    # why nothing was found, of the reader's answers: the weightiest

sub import_files {                        # the bookmarks files in Downloads, Desktop and Documents, the newest first: [the name shown, the file]
    my @found;
    for my $where (qw(Downloads Desktop Documents)) {
        opendir(my $in, import_home() . "/$where") or next;    # macOS may not let lzrprf look there: then nothing is found there
        for my $entry (grep { /^[^.].{0,200}\.html?\z/is } readdir $in) {
            my $file = import_home() . "/$where/$entry";
            my @is = lstat $file or next;
            next unless -f _ && $is[4] == $< && $is[7] <= $IMPORT_BYTES;
            sysopen(my $one, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or next;
            defined sysread($one, my $head, 512) or next;
            push @found, [plain_name("$where/$entry"), $file, $is[9]] if $head =~ /NETSCAPE-Bookmark-file-1/i;
        }
    }
    @found = sort { $b->[2] <=> $a->[2] || $a->[0] cmp $b->[0] } @found;
    return @found[0 .. ($#found < $IMPORT_FOUND - 1 ? $#found : $IMPORT_FOUND - 1)];
}

sub import_sources {                      # the browsers on this Mac, by whether the reader finds each one's own folder (or macOS keeps it out, which means it is there), then an HTML file
    return import_refused("$UNKEPT, so it imports no bookmarks.") if $INCOGNITO;    # [C16]
    ($IMPORT_ASKING, %IMPORT_ASKED, %IMPORT_LIFTED) = ('');    # a new import: each browser may be asked for once again
    my @there = import_reader(map { 's:' . import_base($_) } @BROWSERS);
    my $why = import_why($there[0]);
    if ($why eq 'home' || $why eq 'start') {    # no browser can be looked at: said and logged, and an HTML file still works
        my $words = "No browser's bookmarks can be read: $IMPORT_WHY{$why}.";
        noted($words);
        window('import begin', "import source file $BROWSERS{file}[0]", 'import step source', "import refused $words");
        return idle($words);
    }
    window('import begin', (map { "import source $BROWSERS[$_] $BROWSERS{ $BROWSERS[$_] }[0]" } grep { defined $there[$_][0] || $there[$_][1] =~ /^(?:refused|denied|link)$/ } 0 .. $#BROWSERS), "import source file $BROWSERS{file}[0]", 'import step source');
    return idle('Choose a browser.');
}

sub import_profiles {
    return import_refused("$UNKEPT, so it imports no bookmarks.") if $INCOGNITO;    # [C16]
    my ($key) = @_;
    my $why;
    ($IMPORT_MORE, $IMPORT_UNNAMED) = (0, '');
    ($IMPORT_KEY, $why, @IMPORT_FROM) = ($key, $key eq 'file' ? (undef, import_files()) : import_profiles_of($key));
    return import_kept($key, 'profiles') if ($why // '') eq 'refused';
    return import_refused($why eq 'missing' ? "No profile of $BROWSERS{$key}[0] holds bookmarks." : "$BROWSERS{$key}[0] could not be read: $IMPORT_WHY{$why}.") if $key ne 'file' && !@IMPORT_FROM;
    my $unnamed = length $IMPORT_UNNAMED ? "$BROWSERS{$key}[0]'s profile names could not be read: folders are shown." : '';
    noted("$BROWSERS{$key}[0]'s profile names could not be read from its Local State: $IMPORT_UNNAMED. The profiles are shown by their folders' names.") if $unnamed;    # never silent: the log says why
    window('import begin', (map { "import profile $_ $IMPORT_FROM[$_][0]" . ($key ne 'file' && length $IMPORT_FROM[$_][2] ? "\t$IMPORT_FROM[$_][2]" : '') } 0 .. $#IMPORT_FROM), $unnamed ? "import note $unnamed" : (), 'import step profile');    # always shown, also when there is one; after a tab what tells two alike apart, the account's address or the folder
    return idle(join ' ', $key eq 'file' ? 'Choose a file, or type its path.' : $IMPORT_MORE ? "Choose a profile; $IMPORT_MORE more " . ($IMPORT_MORE == 1 ? 'was' : 'were') . ' left out.' : 'Choose a profile.', $unnamed || ());
}

sub import_refused { window("import refused $_[0]"); return idle($_[0]) }    # one sentence, in the wizard and in the strip

sub import_kept_out {                     # macOS keeps them out: what works, in one sentence; Safari's are let through by Full Disk Access alone, which lzrprf never asks for
    return "macOS keeps Safari's bookmarks out and offers no prompt for them; export them as an HTML file instead." if $_[0] eq 'safari';
    return "macOS keeps $BROWSERS{$_[0]}[0]'s bookmarks out with no prompt; if Privacy & Security, Files & Folders lists LZRBRWSR, switch it on there, or export an HTML file instead.";    # whether that switch reaches the reader is for a real Mac to show
}

sub import_kept {                         # macOS kept the reader out of a browser you chose: the window's Open panel asks for its folder, once a browser in an import
    my ($key, $again) = @_;
    my $folder = import_base($key);
    return import_refused(import_kept_out($key)) if $key eq 'safari' || $IMPORT_ASKED{$key}++ || $folder !~ m{\A/[\x20-\x7e]{1,1000}\z};
    ($IMPORT_ASKING, $IMPORT_AGAIN) = ($key, $again);
    window("import ask $key $folder");
    return idle("Choose Allow to let LZRBRWSR try to read $BROWSERS{$key}[0]'s bookmarks.");
}

sub import_cancelled { $IMPORT_ASKING = ''; return }    # the wizard closed with an Open panel asked for: its answer, if one comes, is "Choose the browser again."

sub import_unshown {                      # the window could not show the Open panel, or it closed before anyone could choose: one line of this window's log, so that a run on a real Mac says which
    my ($key, $how) = @_;
    noted("The Open panel for $BROWSERS{$key}[0]'s folder " . ($how eq 'failed' ? 'could not be shown' : 'closed at once, before anyone could choose') . ', so nothing was read.');
}

sub import_allowed {                      # the Open panel's answer: Allow on the folder asked for reads again at once; another folder, or Cancel (no path), ends in one sentence
    my ($key, $path) = @_;
    my $asked = $IMPORT_ASKING;
    $IMPORT_ASKING = '';
    return import_refused('Choose the browser again.') unless $key eq $asked;
    return import_profiles($key) if !defined $path && $IMPORT_AGAIN eq 'profiles';    # Cancel on the names: the profiles found are listed by their folders, said so, or why none can be read is said
    return import_refused(import_kept_out($key)) unless defined $path;
    $path =~ s{(?<=.)/+\z}{};
    my $folder = import_base($key);
    return import_refused("That is not $BROWSERS{$key}[0]'s own folder, so nothing was read.") unless $path eq $folder || $path eq (abs_path($folder) // $folder);
    $IMPORT_LIFTED{$key} = 1 if $TRY;      # only the try-mode stand-in of a refusal reads it
    return $IMPORT_AGAIN eq 'profiles' ? import_profiles($key) : import_go($key, $IMPORT_AGAIN);    # asked once: kept out again, it is said at once
}

sub import_path {                         # a bookmarks file typed as a path: in your home folder, by a path that does not climb out of it
    return import_refused("$UNKEPT, so it imports no bookmarks.") if $INCOGNITO;    # [C16]
    my ($path) = @_;
    $path =~ s/^\s+|\s+$//g;
    $path =~ s{^~/}{import_home() . '/'}e;
    return import_refused('That is not a path in your home folder.') unless index($path, import_home() . '/') == 0 && $path !~ m{(?:^|/)\.\.?(?:/|$)};
    ($IMPORT_KEY, @IMPORT_FROM) = ('file', [plain_name(substr($path, length(import_home()) + 1)), $path]);
    return import_go('file', 0);
}

sub import_plan {                         # what an import writes, in order: ['F', folder] and ['B', folder, name, address]; with what it counts and leaves out
    my ($bar, $rest, $over) = @_;
    my ($found) = marks_read();
    my $root = marks_root();
    my %had = map { (lc($_->[3]) . "\t$_->[2]" => 1) } @$found;    # each bookmark there already, by its folder, the case folded as the disk folds names, and its address as it is: two addresses that differ in case may be two pages
    my %plan = (steps => [], marks => 0, there => 0, twice => 0, skipped => 0, left => 0, over => $over);
    my ($room, $folders, %used, %planned, %disk) = ($MARKS_MOST - @$found, 0);
    my $named = sub {                     # a folder's name in a folder: the name a folder there has already, when the two differ in case alone
        my ($folder, $name) = @_;
        my $in = length $folder ? "$root/$folder" : $root;
        $disk{$in} //= do { my %on; if (opendir my $dir, $in) { for (sort readdir $dir) { $on{ lc $_ } //= $_ if !/^\./ && !-l "$in/$_" && -d _ } } \%on };
        return $disk{$in}{ lc $name } // $name;
    };
    my $walk; $walk = sub {               # the steps for these nodes in this folder; when $counting, what is in them is only counted
        my ($nodes, $folder, $level, $counting) = @_;
        my @steps;
        for my $node (@$nodes) {
            if ($node->{kids}) {
                if ($counting || $level >= $MARKS_DEEP || $folders >= $IMPORT_FOLDERS) { $walk->($node->{kids}, '', $level + 1, 1); next }    # too deep, or one folder too many: left out with what is in it
                my $base = substr($node->{name} =~ s/[^A-Za-z0-9 ._-]/_/gr =~ s/^[ .]+//r, 0, 60) =~ s/ +\z//r;
                $base = 'Folder' unless length $base;
                my $name = $named->($folder, $base);
                for (my $k = 2; $used{ lc "$folder/$name" }; $k++) { $name = $named->($folder, "$base $k") }    # two folders of one name in one place stay two
                $used{ lc "$folder/$name" } = 1;
                my $inner = length $folder ? "$folder/$name" : $name;
                $folders++;
                my @inside = $walk->($node->{kids}, $inner, $level + 1, 0);
                if (grep { $_->[0] eq 'B' } @inside) { push @steps, ['F', $inner], @inside } else { $folders-- }    # a folder is made only for a bookmark in it
            } else {
                my ($url) = address($node->{url});
                if (!$url) { $plan{skipped}++; next }
                my $key = lc($folder) . "\t$url";
                if ($counting) { $plan{left}++; next }
                if ($had{$key}) { $plan{there}++; next }
                if ($planned{$key}) { $plan{twice}++; next }
                if ($room <= 0) { $plan{left}++; next }
                ($room--, $planned{$key} = 1);
                push @steps, ['B', $folder, plain_name($node->{name}), $url];
                $plan{marks}++;
            }
        }
        return @steps;
    };
    $plan{steps} = [$walk->($bar, $BAR, 1, 0), $walk->($rest, '', 0, 0)];    # the other top folders, each under its own name at the top
    return \%plan;
}

sub import_go {                           # a profile or a file chosen: read, and imported at once
    return import_refused("$UNKEPT, so it imports no bookmarks.") if $INCOGNITO;    # [C16]
    my ($key, $n) = @_;
    my $from = $key eq ($IMPORT_KEY // '') ? $IMPORT_FROM[$n] : undef;
    return import_refused('Choose the browser again.') unless $from;
    my $source = $key eq 'file' || $key eq 'safari' ? $from->[0] : "$BROWSERS{$key}[0] ($from->[0])";    # Safari has one list of bookmarks
    busy("Importing from $source.");
    my ($text, $why) = $key eq 'file' ? import_read($from->[1]) : @{ (import_reader("r:$from->[1]"))[0] };
    return $key ne 'file' && $why eq 'refused' ? import_kept($key, $n) : import_refused("$source could not be read: $IMPORT_WHY{$why}.") unless defined $text;
    ($IMPORT_SEEN, $IMPORT_CUT) = (0, 0);
    my ($bar, $rest) = { chrome => \&import_chromium, edge => \&import_chromium, brave => \&import_chromium, vivaldi => \&import_chromium, firefox => \&import_firefox, safari => \&import_safari, file => \&import_html }->{$key}->($text);
    return import_refused("$source holds no bookmarks lzrprf can read.") unless $bar;
    my $plan = import_plan($bar, $rest, $IMPORT_SEEN > $IMPORT_NODES ? $IMPORT_SEEN - $IMPORT_NODES : $IMPORT_CUT ? -1 : 0);
    my ($root, %order, @order_of) = (marks_root());
    mkdir $root, 0700 unless -e $root || -l $root;
    return import_refused("Nothing was imported: $root is not a folder of yours.") unless owned_folder($root);
    marks_into_bar();
    my ($written, $stopped) = (0, '');
    for my $step (@{ $plan->{steps} }) {
        my $dir = "$root/$step->[1]";
        my ($parent, $name);
        if ($step->[0] eq 'F') {
            my $made = !(-e $dir || -l $dir) && mkdir($dir, 0700);
            ($stopped = "$dir is not a folder of yours"), last unless owned_folder($dir);
            next unless $made;            # a folder there already keeps its place
            ($parent, $name) = $dir =~ m{\A(.*)/([^/]+)\z};
        } else {
            my $file = mark_file($dir, $step->[2]) or next;
            ($stopped = "a bookmark could not be written in $dir"), last unless mark_written($dir, $file, $step->[2], $step->[3]);
            $written++;
            ($parent, $name) = ($dir, basename($file));
        }
        push @order_of, $parent unless $order{$parent};
        push @{ $order{$parent} }, $name;
    }
    order_set($_, undef, @{ $order{$_} }) for @order_of;    # each folder's new names last in its order, in the source's order
    marks_told();
    window('import done');
    my @also = ($plan->{there} ? "$plan->{there} " . ($plan->{there} == 1 ? 'was' : 'were') . ' there already' : (), $plan->{twice} ? "$plan->{twice} appeared twice in it" : (),
        $plan->{skipped} ? ($plan->{skipped} == 1 ? '1 is not an address' : "$plan->{skipped} are not addresses") . ' lzrprf opens' : (), $plan->{left} ? "$plan->{left} did not fit" : (), $plan->{over} > 0 ? "the rest of it, past $IMPORT_NODES entries, was not read" : $plan->{over} ? 'the rest of it, past the work lzrprf gives one file, was not read' : ());    # each number counts bookmarks, and what its words say
    my $also = @also > 1 ? join(', ', @also[0 .. $#also - 1]) . " and $also[-1]" : $also[0];
    return idle("Imported $written " . ($written == 1 ? 'bookmark' : 'bookmarks') . " from $source" . (defined $also ? "; $also" : '') . (length $stopped ? ", then stopped: $stopped" : '') . '.');
}

