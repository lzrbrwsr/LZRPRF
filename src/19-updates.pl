# What the application's maker put beside the program, in a file "release":
# the number of this release, and up to four addresses. Where the newest
# release number is published, where the installer is, where reports go, and
# a second place that holds the same installer ("same"), so that the copy
# from one place can be compared with the copy from the other. A newer
# application also names the SHA-256 of the lzrprf it was installed with
# ("lzrprf"). A program without that file is never checked for a newer one,
# and is never asked about in a report.
sub release_file { $PROGRAM =~ m{^(.*\.app)/Contents/MacOS/} ? "$1/Contents/Resources/release" : dirname($PROGRAM) . '/release' }
sub release_lines { open my $in, '<', release_file() or return; return <$in> }

sub beside {
    my %is = map { /^(release|newest|installer|report|same|lzrprf) (\S+)$/ ? ($1 => $2) : () } release_lines();
    return unless ($is{release} // '') =~ /^\d{1,6}$/;
    my ($same) = address($is{same} // '');
    return ($is{release}, (map { my ($url) = address($is{$_} // ''); $url } 'newest', 'report', 'installer'), exists $is{same} ? $same // '' : undef, $is{lzrprf});    # the last: the SHA-256 of the lzrprf the application was installed with, when the file names it. A second place that is named and is no address counts as one that does not agree: nothing is written
}

# A newer release. The first time, you are asked whether lzrprf may look at
# each start, and your answer is kept in a file. A yes is kept with the
# address it was given for: when a later release names another address, the
# yes does not count for it and you are asked again. With a yes, lzrprf fetches
# one fixed address at each start, where the newest release number is
# published and nothing else. The request holds what "request" above holds:
# the same request from every computer, so it says nothing about you or about
# which release you run, and it is written in the log like any other. When
# the number there is larger than the one beside the program, the window says
# so and offers the installer. "Install it" is the yes: the installer then
# runs at once, in a modal of lzrprf's own in this window, in auto: it shows
# no question, since nobody is there choosing, and every line it prints is
# shown there and kept in install.txt (sub installed).
# THE RELEASE KEY AND THE APPROVAL KEYS. An update is offered, and its installer is run, only when
# its release is signed and approved [C25]. A release is signed as a manifest: its number, when it
# was signed, until when the signature holds, and the SHA-256 of each file a person downloads or
# runs. Two SSH signatures (ssh-keygen -Y) are made over the same manifest, and both must hold:
#   the approval, namespace lzrbrwsr-approval, by an approval key. The first is made in the Secure
#   Enclave of the owner's phone, opens only to his Face ID at each use and never leaves the phone.
#   He reads the release on his phone and approves it there. By his decision of 2026-11-22 a
#   second key may approve too: the agent approval key, held by the project's signing service,
#   so releases go out as work lands. Its line ends "valid-until YYYY-MM-DD": it holds through
#   that day (UTC) and never after (sub approval_key_current), and a release that drops the line
#   revokes it.
#   the signature, namespace lzrbrwsr-release, by the release key. Its private half is on the
#   project's server, readable by the signing service alone, which signs only a manifest that
#   carries a valid approval, and each release number once.
# So without the agent approval key no program, server or person at a computer can authorize a release
# without the owner's approval on his phone, and the phone alone cannot publish one either; while that
# key is listed and in date, the project's server can, and nothing else. The public halves are written here
# and beside this file (release-key.pub, approval-keys.pub). The manifest and both signatures stand
# beside the installer, in each place the release file names it, and both places must hold the same
# three files. lzrprf reads the manifest in one form only (sub manifest_read) and has macOS's own
# ssh-keygen check each signature in the verifier container: no network, nothing to write, and of
# the disk the system's files and the folder with the manifest, the signature and the keys (sub
# signature_holds). A release is refused when the manifest cannot be fetched or read, either
# signature does not hold for its keys, its number is not the published one or not newer than yours, it says it was signed
# later than now, it expired or says it holds longer than a year and a month, or it names no
# installer; and the installer runs only when its SHA-256 is the one the manifest names. A refusal
# has no way around it: nothing is installed, and the window says why.
my $RELEASE_KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINHg3YnFC/5ryVmSXSX4jSb/+x8HsD8B52O07Ug75X+C lzrbrwsr-release';    # [C25] the public half of the release key
my $RELEASE_NAMESPACE = 'lzrbrwsr-release';    # [C25] what an SSH signature says it was made for: a signature made for anything else does not hold
my @APPROVAL_KEYS = (                     # [C25] the public halves of the approval keys, one OpenSSH line each: one of them approves each release; a line ending "valid-until YYYY-MM-DD" holds through that day only (sub approval_key_current)
    'ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBIWKMATpVOLaAKtBC4cBWQYxOMaESOFLQrgngQ8BuBU7xm5z4JEA+a9JMkTi0dSj7FVpQZ2HhViKWh+FOcp0DVU= henry-phone',
    'ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBC8gYmKCyxfiGXwWmeZZDRY2wyW1MbVBRkaDEKff8qS13flShTkVHiRkKkCCPIwmayFMNVQ9JeMqnOx5nIb1yJM= lzrbrwsr-agent valid-until 2027-02-28',
);
my $APPROVAL_NAMESPACE = 'lzrbrwsr-approval';    # [C25] what the approval says it was made for
my $MANIFEST_MOST = 4096;                 # [C25] bytes a manifest may hold
my $SIGNATURE_MOST = 2048;                # [C25] bytes its signature may hold
my %SIGNATURE_HELD;                       # [C25] what the verifier said of each manifest, signature and keys asked in this window (sub signature_holds)
my $SIGNED_DAYS = 400;                    # [C25] the longest a signature may say it holds, counted from when it was signed
my $VERIFIER = <<'END';
(allow file-read* (subpath (param "WORK")))
(allow file-write-data (literal "/dev/null"))
(allow sysctl-read (sysctl-name "kern.hostname"))
(allow mach-lookup (global-name "com.apple.system.opendirectoryd.libinfo"))
END

sub release_key {                         # the key a signature must hold for; "lzrprf try" alone may be given a test's key, in its own folder, and installs nothing
    return $RELEASE_KEY unless $TRY;
    open my $in, '<', "$ROOT/release-key.pub" or return $RELEASE_KEY;
    my $key = <$in> // '';
    chomp $key;
    return $key =~ m{\Assh-ed25519 [A-Za-z0-9+/]{60,80}={0,2}(?: [!-~]{1,64})?\z} ? $key : $RELEASE_KEY;
}

sub approval_keys {                       # the keys an approval must hold for, those past their valid-until day left out; "lzrprf try" alone may be given a test's keys, in its own folder, and installs nothing
    my @keys = @APPROVAL_KEYS;
    if ($TRY && open my $in, '<', "$ROOT/approval-keys.pub") {
        my @read = grep { m{\Aecdsa-sha2-nistp256 [A-Za-z0-9+/]{100,200}={0,2}(?: [!-~]{1,64})?(?: valid-until [0-9]{4}-[0-9]{2}-[0-9]{2})?\z} } map { s/\n\z//r } <$in>;
        @keys = @read if @read;
    }
    return grep { approval_key_current($_) } @keys;
}

sub approval_key_current {                # [C25] an approval key whose line ends "valid-until YYYY-MM-DD" holds through the end of that day (UTC) and never after; a line without one holds until a release takes it out
    my ($key) = @_;
    return 1 unless $key =~ / valid-until /;
    my ($y, $m, $d) = $key =~ / valid-until ([0-9]{4})-([0-9]{2})-([0-9]{2})\z/ or return 0;
    require Time::Local; my $until = eval { Time::Local::timegm(0, 0, 0, $d, $m - 1, $y) } // return 0;
    return time < $until + 86400 ? 1 : 0;
}

sub manifest_read {                       # [C25] a manifest in its one form, as numbers and sums; or nothing and why
    my ($text) = @_;
    my $bad = 'the manifest is not in its form';
    return (undef, $bad) unless length $text <= $MANIFEST_MOST && $text =~ /\A[\x20-\x7e\n]*\n\z/;
    my @lines = split /\n/, $text;
    return (undef, $bad) unless @lines >= 5 && @lines <= 36 && $lines[0] eq 'lzrbrwsr release manifest 1';
    my ($release) = $lines[1] =~ /\Arelease ([1-9][0-9]{0,5})\z/;
    my @when;
    for my $at (2, 3) {
        my ($word) = $at == 2 ? 'signed' : 'expires';
        my @t = $lines[$at] =~ /\A$word ([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z\z/ or return (undef, $bad);
        return (undef, $bad) unless $t[1] >= 1 && $t[1] <= 12 && $t[2] >= 1 && $t[2] <= 31 && $t[3] < 24 && $t[4] < 60 && $t[5] < 60;
        require Time::Local; push @when, eval { Time::Local::timegm($t[5], $t[4], $t[3], $t[2], $t[1] - 1, $t[0]) } // return (undef, $bad);
    }
    my %files;
    for my $line (@lines[4 .. $#lines]) {
        my ($name, $sum) = $line =~ /\Afile ([A-Za-z0-9][A-Za-z0-9._-]{0,63}) ([0-9a-f]{64})\z/ or return (undef, $bad);
        return (undef, $bad) if exists $files{$name};
        $files{$name} = $sum;
    }
    return (undef, $bad) unless defined $release;
    return ({ release => $release, signed => $when[0], expires => $when[1], files => \%files });
}

sub signature_holds {                     # [C25] macOS's own ssh-keygen, in the verifier container, says the signature holds for one of these keys, made for this namespace
    my ($manifest, $signature, $namespace, $type, @keys) = @_;
    my $asked = Digest::SHA::sha256_hex(join "\0", $manifest, $signature, $namespace, $type, @keys);    # the same bytes asked again in this window, as the curated rules and the filter lists each ask: the answer the verifier gave
    return $SIGNATURE_HELD{$asked} if exists $SIGNATURE_HELD{$asked};
    return $SIGNATURE_HELD{$asked} = signature_checked($manifest, $signature, $namespace, $type, @keys);
}

sub signature_checked {                   # [C25] signature_holds asked of the verifier: macOS's own ssh-keygen, in the verifier container
    my ($manifest, $signature, $namespace, $type, @keys) = @_;
    return 0 unless @keys && $signature =~ m{\A-----BEGIN SSH SIGNATURE-----\n(?:[A-Za-z0-9+/=]{1,76}\n){1,30}-----END SSH SIGNATURE-----\n\z} && length $signature <= $SIGNATURE_MOST;
    my $allowed = join "\n", map { my @key = split / /; qq{$namespace namespaces="$namespace" $key[0] $key[1]} } @keys;
    my $work = "${\ shared()}/verify.$$";
    remove_tree($work);
    mkdir($work, 0700) or return 0;
    my @is = lstat $work;
    my $real = abs_path($work) // '';
    my $held = 0;
    if (@is && -d _ && $is[4] == $< && $real !~ /["\\\n]/ && length $real
        && put("$real/manifest", O_EXCL, $manifest =~ s/\n\z//r) && put("$real/manifest.sig", O_EXCL, $signature =~ s/\n\z//r)
        && put("$real/allowed", O_EXCL, $allowed)) {
        my ($said, $well) = said(10, '/bin/sh', '-c', 'exec "$@" <"$0"', "$real/manifest",
            contain($VERIFIER, '/usr/bin/ssh-keygen', '-D', "WORK=$real"),
            '-Y', 'verify', '-f', "$real/allowed", '-I', $namespace, '-n', $namespace, '-s', "$real/manifest.sig");
        $held = $well && $said =~ /\AGood "\Q$namespace\E" signature for \Q$namespace\E with \Q$type\E key /;
    }
    remove_tree($work);
    return $held;
}

sub release_signed {                      # [C25] the signed manifest of release $there, fetched from beside each installer; or nothing and why it is refused
    my ($there, $release, $installer, $same) = @_;
    my @places = map { m{\A(https://[^?#\s]*/)[^/?#\s]+\z} ? $1 : () } $installer, defined $same ? $same : ();
    return (undef, 'the release file names no place beside the installer for a signed manifest') unless @places == (defined $same ? 2 : 1);
    my (@manifests, @signatures, @approvals);
    for my $place (@places) {
        my ($host) = $place =~ m{^https://([^/:]+)};
        for my $kind (['release.manifest', \@manifests, $MANIFEST_MOST], ['release.manifest.sig', \@signatures, $SIGNATURE_MOST], ['release.manifest.approval', \@approvals, $SIGNATURE_MOST]) {
            my ($name, $into, $most) = @$kind;
            my $got = fixed("lzrprf fetches the signed manifest of release $there: $place$name", "$place$name", $host);
            my $body = defined $got ? body_of($got) : undef;
            return (undef, "$place$name could not be fetched") unless defined $body && length $body && length $body <= $most;
            push @$into, $body;
        }
    }
    return (undef, 'the two places hold different manifests, signatures or approvals') if @places == 2 && ($manifests[0] ne $manifests[1] || $signatures[0] ne $signatures[1] || $approvals[0] ne $approvals[1]);
    my ($manifest, $why) = manifest_read($manifests[0]);
    return (undef, $why) unless $manifest;
    return (undef, 'it is not approved with an approval key lzrprf carries: a key past its valid-until day is not carried') unless signature_holds($manifests[0], $approvals[0], $APPROVAL_NAMESPACE, 'ECDSA', approval_keys());
    return (undef, 'its signature does not hold for the release key lzrprf carries') unless signature_holds($manifests[0], $signatures[0], $RELEASE_NAMESPACE, 'ED25519', release_key());
    return (undef, "the signed manifest is of release $manifest->{release}, not of the published $there") unless $manifest->{release} == $there;
    return (undef, "release $there is not newer than release $release") unless $there > $release;
    my $now = time;
    return (undef, 'it says it was signed later than this Mac says it is now') if $manifest->{signed} > $now + 86400;
    return (undef, 'its signature expired') if $now >= $manifest->{expires};
    return (undef, "its signature says it holds longer than $SIGNED_DAYS days") unless $manifest->{expires} > $manifest->{signed} && $manifest->{expires} - $manifest->{signed} <= $SIGNED_DAYS * 86400;
    return (undef, 'the signed manifest names no installer') unless $manifest->{files}{'install.sh'};
    return ($manifest);
}

sub newer {
    my ($asked) = @_;                     # "update-check": Check for updates in the cogwheel's menu was chosen, and that choice is the yes for this one look
    my ($release, $newest, undef, $installer, $same) = beside();
    return $asked && checked_said('none') unless $newest && $installer;
    return newer_looked($release, $newest, $installer, $same, 1) if $asked;
    my ($may, $back) = ('', strip_back());
    if (open my $in, '<', "${\ shared()}/look") { $may = <$in> // '' }
    $may = $may eq "yes $newest" ? 'yes' : $may =~ /^no\b/ ? 'no' : '';    # a yes for another address is no yes for this one; a no stays a no
    if (!$may) {
        $may = ask("May lzrprf look for a newer release of $APP at each start? It fetches one fixed address, $newest, with the same request from every computer, and writes it in the log like every other. The request does not say who you are or what you read; the host of that address sees your internet address, as every site does.", 'No', 'Yes, look') == 2 ? 'yes' : 'no';
        unlink "${\ shared()}/look";
        my $kept = record($may eq 'yes' ? "you allowed lzrprf to look for a newer release at each start: $newest" : 'no newer release is looked for: the question was answered no, or not at all');    # an answer that lasts is a line first, like a change of what is kept: without its line it is not kept
        my $out;
        $kept &&= sysopen($out, "${\ shared()}/look", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) && print({$out} ($may eq 'yes' ? "yes $newest" : 'no')) && close($out);
        if (!$kept) {                         # no line, or no place to keep it: the answer counts for nothing, now or later, and the question comes again at the next start
            unlink "${\ shared()}/look";
            record('that answer could not be kept: no newer release is looked for now, and you are asked again at the next start');
            $may = 'no';
        }
        $back->();                        # the question was in the strip: answered, it leaves the window closed to every press until this
    }
    return unless $may eq 'yes';
    return newer_looked($release, $newest, $installer, $same, 0);
}

# One look at the published release number, at a start allowed to look or for Check for updates;
# when it was done and what it found is kept in a plain file of yours, checked ("EPOCH RESULT":
# "same N", "newer N" or "failed"), and told to the window as "checked EPOCH RESULT", which shows
# it under Check for updates. An incognito window looks for nothing and keeps nothing.    # [C16]
sub newer_looked {
    my ($release, $newest, $installer, $same, $asked) = @_;
    my $back = strip_back();
    busy('Looking for a newer release.');
    my ($host) = $newest =~ m{^https://([^/]+)};
    my $got = fixed(($asked ? 'you chose Check for updates: ' : '') . "lzrprf looks for a newer release: $newest", $newest, $host);
    my ($there) = defined $got ? $got =~ m{\AHTTP/1\.1 200 .*?\r\n\r\n(?:[0-9a-f]{1,4}\r\n)?(\d{1,6})\s*(?:0\r\n\r\n)?\z}s : ();    # one number and nothing else, or the answer counts for nothing
    checked_said(!defined $there ? 'failed' : $there > $release ? "newer $there" : "same $release", $asked);
    if ($asked) {                         # that it is the newest stands in the menu, beside Check for updates, and in this window's log: the strip stays as it was
        my $says = !defined $there ? 'lzrprf could not read the newest release number just now. The log says what was fetched.' : $there > $release ? "A newer release of $APP is published: $there." : "You run the newest release of $APP, $release.";
        noted($says);
        defined $there && $there <= $release ? aside($says) : idle($says);
        $back = strip_back();             # what the strip says now is what a "Later" below puts back
    }
    else { $back->() }                    # the start's own look: it said busy, so it says idle, with the strip's words as they were
    return unless defined $there && $there > $release;
    my ($signed, $refused) = release_signed($there, $release, $installer, $same);    # [C25]
    if (!$signed) {
        my $says = "A newer release of $APP is published ($there), and it is not offered: $refused. Only a release signed with the release key lzrprf carries is installed, and nothing else is.";
        record("release $there is not offered: $refused");
        noted($says);
        aside($says);
        return;
    }
    return $back->() unless ask("A newer release of $APP is published: $there. You run $release. Install it fetches the installer and runs it here, in this window, with no further question: every line it prints is shown and kept in ${\ shared()}/install.txt.", 'Later', 'Install it') == 2;
    installed($there, $installer, $same, $signed);
    return $back->();                     # the installer did not run to its end (an install that is done never comes back here): its modal says why, and the window takes a press again
}

# A welcome, once after each install or update. At the first start of a
# release this folder was not welcomed to yet, the window shows a modal: what
# is new in it (the release file's lines "new", at most six) and, every time,
# two short groups, what $APP keeps you from and what it cannot, which stays
# yours to watch, so that every release is begun with the right picture of
# what it does. A site can still do things to you with what you give it: the
# second group says so before anything is opened. "Got it" closes it, and only
# then is the release number written to $DIR/welcomed, a number and nothing
# else; when it cannot be written the welcome comes again at the next start.
# Nothing is fetched for it. An application without a release file shows none,
# and "lzrprf try" only when its folder holds a file "welcome".
my @PROTECTS = (
    'Page scripts: the scripts of a page run sealed in its container, with no network, no file of yours and no other program, so no tracking code, fingerprinting or hidden miner runs either.',
    'Being followed: every site gets the same request from every computer, with nothing kept from an earlier visit but its own cookies, kept apart under each site you visit it from so no site follows you across others, and the sign-in of a provider you connected, which goes to the sites of that provider alone.',
    'Pages reaching your Mac: each page is drawn in a sealed container with no network, no file of yours and no other program.',
    'Hidden requests: nothing is fetched that you did not ask for, and every address is in your log before it is fetched.',
);
my @CANNOT = (
    'What you send: whatever you type into a site, a password, a card number, your name, goes to that site, to keep or to misuse.',
    'What a site does on its side: a site you sign in to knows it is you, and keeps and shares what you do there on its own servers.',
    'Fake sites and scams: a page can look exactly like your bank. Read the address in the bar before you trust it or type anything.',
    'What you take elsewhere: a file you save and open, or a link you follow in another program, is outside $APP.',
    'Your internet address: every site you open sees it, as with every browser.',
);
sub welcome {
    my ($release) = beside();
    return unless defined $release;
    return if $TRY && !-e "${\ shared()}/welcome";
    my $was = '';
    if (open my $in, '<', "${\ shared()}/welcomed") { $was = <$in> // '' }
    return if $was eq $release;
    my @new = grep { length } map { /^new (.+)$/ ? substr($1 =~ s/[\x00-\x1f\x7f]//gr, 0, 200) : () } release_lines();
    splice @new, 6;
    window("welcome begin $release");
    window(@new ? ("welcome line n What is new in release $release", map { "welcome line b $_" } @new) : ());
    window("welcome line g What $APP keeps you from", (map { "welcome line b $_" } @PROTECTS), "welcome line y What $APP cannot keep you from: yours to watch", map { "welcome line b " . s/\$APP/$APP/gr } @CANNOT);
    window('welcome end');
    $WELCOMING = $release;                # nothing waits for "Got it": behind's own loop takes it (sub welcomed). A wait here held every
    return;                               # other line, the page's answers among them, so a welcome card another modal replaced left the page grey and deaf (2026-11-26)
}

sub welcomed {                            # "Got it" on the welcome card, taken in behind's own loop: the release is marked welcomed once
    my $release = $WELCOMING // return;
    undef $WELCOMING;
    unlink "${\ shared()}/welcomed";
    my $out;
    sysopen($out, "${\ shared()}/welcomed", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) && print({$out} $release) && close($out);
    window("welcome kept $release");    # said back once the release is marked, so the window (and its self-test) knows Got it was taken
    return;
}

# What "Install it" does, with no key to press after it: the press is the yes.
# What it can reach is only this: the installer at the address the
# application's release file names. lzrprf fetches it the way it fetches a
# typed address, with its line in the log first [C5], through the one place
# that connects [C6], by a curl held to https that follows no redirect and is
# contained [C3], and from the public internet only. When the release file
# names a second place for the same installer, it is fetched from there too,
# and it runs only when the two copies are the same byte for byte: somebody
# who changed the installer in one place would have had to change it in the
# other too. A second place that is named and is no address counts as one
# that does not agree. The installer is written into a folder of its own
# under $DIR, as a plain file, its SHA-256 is shown in the window and written
# in the log, and it is started there, with nothing of lzrprf's own
# environment: env -i, the system's PATH, your home folder, and TERM=dumb,
# in auto, so it asks nothing and needs no terminal. Every line it prints is
# given to the window, which shows it in a modal of its own over everything
# (no page draws there), and appended to $DIR/install.txt. A colour the
# installer asks for in a line becomes one letter the window draws in, and
# every escape and control character is taken out, so nothing it prints acts
# on the window. The window cannot close the modal while it runs; at the end
# it says done or failed. After done, lzrprf takes nothing more in this
# window: the application was replaced, and is started again. lzrprf itself
# replaces nothing: whatever is replaced is replaced by that installer.
# The installer runs in a session of its own, so a signal meant for lzrprf's
# group does not reach it, nor one of its own reach lzrprf. From "install
# begin" to the end, a signal that would end lzrprf without a word
# (@INSTALL_STOPS) is said in install.txt, the modal and the log, and lzrprf
# stops there. An installer that runs then goes on, and a process of its own
# reads its lines on into install.txt (sub install_drained); each line
# reaches install.txt as it comes. The window is told when the installer
# starts and when lzrprf stops while it runs, and when lzrprf is gone before
# the install ended it keeps the modal open and says what is true of the
# installer. A file grown past the size the system allows fails its write
# and ends nothing (signal XFSZ).
my %INK = (31 => 'r', 32 => 'g', 33 => 'y', 34 => 'b', 35 => 'm', 36 => 'c', 37 => 'w', 91 => 'r', 92 => 'g', 93 => 'y', 94 => 'b', 95 => 'm', 96 => 'c', 97 => 'w');    # the colours of a terminal, as one letter each
my $INSTALL_LOG;                          # install.txt in the state folder (sub shared) while an installer runs
my $INSTALL_PARTS;                        # the parts an install was asked for in Add or remove LZR modules (sub parts_fetched): its installer's word parts=, or none and it keeps the record
sub installed {
    my ($there, $installer, $same, $signed) = @_;    # $signed: the manifest release_signed read for $there [C25]
    my %run = (phase => 'fetch', held => '');    # phase: fetch until the installer is started, run while it runs, after once it ended
    local $SIG{XFSZ} = 'IGNORE';          # install.txt grown past the size the system allows: that write fails, and nothing ends lzrprf
    local @SIG{@INSTALL_STOPS} = (sub { POSIX::_exit(1) unless $$ == $FRESH; die "lzrprf told $_[0]\n" }) x @INSTALL_STOPS;    # from "install begin" to the end, the restart included; a copy made by fork that has not yet become its program ends at once, never going on as lzrprf
    my $fault;                            # an error of lzrprf's own while it installs: said as a stop signal is, in install.txt, the modal and the log, and never an end without a word (an empty line of the installer ended lzrprf so, silently, up to release 68)
    my $told = eval { install_run(\%run, $there, $installer, $same, $signed); '' } // ($@ =~ /\Alzrprf told ([A-Z0-9]+)\n\z/ ? $1 : do { POSIX::_exit(1) unless $$ == $FRESH; ($fault = "$@") =~ s/\s+\z//; $fault =~ s/[^\x20-\x7e]/?/g; 'FAULT' });
    return unless length $told;
    my $why = defined $fault ? "met an error of its own ($fault)" : "was told to stop by the signal $told";
    if ($run{phase} eq 'fetch') {         # no installer was started: nothing was changed
        record("lzrprf behind this window $why before the installer of release $there ran: nothing was changed");
        install_end(0, "lzrprf behind this window $why before the installer ran, and stops here. Nothing was changed.") if $INSTALL_LOG;
    } elsif ($run{phase} eq 'run') {      # the installer runs, in its own session: its lines go on into install.txt by a process of its own, and it goes on by itself
        my $held = $run{held};            # what was read and not yet shown, whole lines and a part, which a signal or an error can leave: never glued into one line
        $run{held} = '';
        my $drained = install_drained($run{from}, $run{until}, $held);    # the reader that takes over starts with it
        if (!$drained) { install_guarded($1) while $held =~ s/\A([^\n]*)\n//; install_guarded($held) if length $held }
        close $run{from};
        record("lzrprf behind this window $why while the installer of release $there ran: it stops, and the installer goes on by itself" . ($drained ? ', its lines into install.txt' : ', and no process could be started to read its lines'));
        install_end(0, "lzrprf behind this window $why, and stops here. The installer goes on by itself" . ($drained ? ', and each line it prints goes on into install.txt.' : '. No process could be started to read what it prints, so it may stop at its next line.'));
        print STDOUT "install told $told" . ($drained ? '' : ' undrained') . "\n";    # the window keeps its modal open when lzrprf is gone: undrained, with the words of an installer nothing reads
    } else {                              # the installer had ended, and how was said: only that lzrprf stops
        record("lzrprf behind this window $why after the installer of release $there had ended");
    }
    leave();
}

sub install_run {
    my ($run, $there, $installer, $same, $signed) = @_;
    window('install begin');
    require IO::Handle;                  # for autoflush and flush, loaded for an install alone
    sysopen($INSTALL_LOG, "${\ shared()}/install.txt", O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0600) or undef $INSTALL_LOG;
    $INSTALL_LOG->autoflush(1) if $INSTALL_LOG;    # each line reaches install.txt as it comes: a run that ends without its own end still leaves every line it was given
    my @is = $INSTALL_LOG ? stat $INSTALL_LOG : ();
    undef $INSTALL_LOG unless @is && -f _ && $is[3] == 1 && $is[4] == $<;
    return install_end(0, "${\ shared()}/install.txt could not be written, so nothing was fetched.") unless $INSTALL_LOG;
    print {$INSTALL_LOG} line("you chose to install release $there"), "\n";    # the time, the run, what happened: as a line of the log
    return install_end(0, 'The second place the release file names is not an address lzrprf fetches. Nothing was fetched.') if defined $same && !length $same;
    my @from = ($installer, defined $same ? $same : ());
    my @copies;
    for my $try (1 .. $INSTALL_TRIES) {       # the copies are compared each time anew: one that differs is never run, it is only fetched again later
        @copies = ();
        for my $url (@from) {
            install_line("Fetching the installer from $url");
            my ($host) = $url =~ m{^https://([^/:]+)};
            my $got = fixed("you chose to install release $there: lzrprf fetches the installer: $url", $url, $host);
            my $body = defined $got ? body_of($got) : undef;
            return install_end(0, "The installer could not be fetched from $url. Nothing was changed.") unless defined $body && length $body;
            push @copies, $body;
        }
        last if @copies < 2 || $copies[0] eq $copies[1] || $try == $INSTALL_TRIES;
        install_line("The two places hold different installers for now. Nothing runs while they differ: a new release is usually being published, and one place can keep its old copy for up to five minutes. Both are fetched again in $INSTALL_WAIT seconds (try $try of $INSTALL_TRIES).");
        Time::HiRes::sleep($TRY ? 0.05 : $INSTALL_WAIT);    # "lzrprf try" waits a moment only: the tries are what is tested, not the clock
    }
    return install_end(0, "The two places hold different installers. Nothing was changed: $from[0] and $from[1].") if @copies == 2 && $copies[0] ne $copies[1];
    my $wanted = ref $signed eq 'HASH' && $signed->{release} == $there ? $signed->{files}{'install.sh'} // '' : '';    # [C25]
    my $fetched = Digest::SHA->new(256)->add($copies[0])->hexdigest;
    return install_end(0, "The installer is not the one the signed manifest of release $there names: it has SHA-256 $fetched" . (length $wanted ? ", the manifest names $wanted" : ', and no signed manifest was read') . '. Nothing was changed.') unless length $wanted && $fetched eq $wanted;
    my ($folder, $out) = ("${\ shared()}/install.$$");
    mkdir $folder, 0700;
    my @folder = lstat $folder;
    my $file = "$folder/install.sh";
    unlink $file;
    return install_end(0, "The installer could not be written to $file. Nothing was changed.") unless @folder && -d _ && $folder[4] == $< && sysopen($out, $file, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) && print({$out} $copies[0]) && close($out);
    my $sum = Digest::SHA->new(256)->add($copies[0])->hexdigest;
    install_line(@copies == 2 ? 'The installer was fetched from two places, and both hold the same file.' : 'The installer comes from one place.');
    install_line("It is in this file, to read: $file");
    install_line("Its SHA-256: $sum");
    window("install sum $sum");
    record("the installer of release $there has SHA-256 $sum, and runs now in auto: $file") or return install_end(0, $UNWRITTEN);    # [C5]
    return install_end(0, 'lzrprf try: the installer was written and is not run.') if $TRY;
    install_line('It runs now by itself: no question is shown, and each line it prints is shown here.');
    pipe(my $from, my $to) or return install_end(0, 'The installer could not be started. Nothing was changed.');
    my $stops = POSIX::SigSet->new(map { POSIX->can("SIG$_")->() } @INSTALL_STOPS);
    POSIX::sigprocmask(POSIX::SIG_BLOCK(), $stops);    # held from the fork until the phase says it: a signal in between is taken once it does
    my $child = fork;
    if (defined $child && !$child) {
        POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $stops);    # the installer starts with no signal held
        $SIG{XFSZ} = 'DEFAULT';           # ignored above for install.txt; an ignored signal outlives the start of a program, and the installer's self-test expects this one as the system gives it (SIGPIPE stays ignored: the installer goes on writing when this window stops reading)
        close $from;
        POSIX::setsid();                  # a session of its own: a signal to the group of lzrprf behind this window does not reach the installer, and the installer's own group signals do not reach lzrprf
        chdir $folder or POSIX::_exit(127);
        become(undef, $to, $to, '/usr/bin/env', '-i', 'PATH=/usr/bin:/bin:/usr/sbin:/sbin', "HOME=$HOME", 'TERM=dumb', '/bin/sh', 'install.sh', 'auto', $INSTALL_PARTS ? "parts=$INSTALL_PARTS" : ());
    }
    @$run{qw(phase from until)} = ('run', $from, now() + $INSTALL_SECONDS) if defined $child;
    print STDOUT "install runs\n" if defined $child;    # the installer was started: from here on the window knows it may go on without lzrprf
    POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $stops);
    defined $child or return install_end(0, 'The installer could not be started. Nothing was changed.');
    close $to;
    my ($how, $piped, $late);
    {
        local $SIG{PIPE} = sub {          # the window stopped reading: the installer's lines still go on into install.txt, said once
            return if $piped++;
            print {$INSTALL_LOG} "lzrprf behind this window could no longer write to the window (signal PIPE): the installer's lines go on into this file.\n" if $INSTALL_LOG;
            record('the window stopped reading while the installer ran (signal PIPE): its lines go on into install.txt');
        };
        while ((my $left = $run->{until} - now()) > 0) {
            my $ready = '';
            vec($ready, fileno $from, 1) = 1;
            select($ready, undef, undef, $left > 1 ? 1 : $left) > 0 or next;
            my $got = sysread($from, $run->{held}, 65536, length $run->{held});
            next if !defined $got && $!{EINTR};
            last unless $got;
            install_line($1) while $run->{held} =~ s/\A([^\n]*)\n//;
            install_line(substr($run->{held}, 0, $INSTALL_LINE, '')) while length $run->{held} > 4 * $INSTALL_LINE;    # a line with no end yet is given in parts once it is this long
        }
        POSIX::sigprocmask(POSIX::SIG_BLOCK(), $stops);    # the end of the installer is taken whole: a signal now is taken as one after it
        install_line($run->{held}) if length $run->{held};
        $run->{held} = '';
        $late = now() >= $run->{until};
        $how = ended($child, 5);
        close $from;
        $run->{phase} = 'after';
    }
    if ($late) { install_end(0, "The installer was ended after $INSTALL_SECONDS seconds. What it printed is above.") }
    elsif ($how != 0) { install_end(0, 'The installer ended with an error (' . ($how >> 8) . '). What it printed is above.') }
    else { install_end(1, "The installer says it is done. Close $APP, or close it and start the new release at once.") }
    POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $stops);    # held until the end is in the window and in install.txt: a signal in the end's wait is taken here, after it
    restarted() if !$late && $how == 0;
}

# The installer's lines once lzrprf behind the window stops while it runs: a
# process of its own, in a session of its own and deaf to the signals that
# stop lzrprf, reads them on into install.txt until the installer ends or its
# time is over. So the installer, which takes no signal PIPE, is never left
# writing into a pipe nobody reads, where its next line would fail and end it.
# It holds nothing of the window's and nothing else of lzrprf's: the window
# sees lzrprf gone, and the lock lzrprf holds while it lives is let go.
sub install_drained {
    my ($from, $until, $held) = @_;
    my $stops = POSIX::SigSet->new(map { POSIX->can("SIG$_")->() } @INSTALL_STOPS);
    POSIX::sigprocmask(POSIX::SIG_BLOCK(), $stops);    # held from here: lzrprf behind the window only ends after this, and the reader takes none until it is deaf to them
    my $drainer = fork // return 0;
    return 1 if $drainer;
    $SIG{$_} = 'IGNORE' for @INSTALL_STOPS, 'PIPE', 'XFSZ';
    POSIX::setsid();
    POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $stops);
    my $nowhere = POSIX::open('/dev/null', O_RDWR) // POSIX::_exit(1);
    POSIX::dup2($nowhere, $_) // POSIX::_exit(1) for 0 .. 2;
    my %kept = map { $_ => 1 } fileno($from), $INSTALL_LOG ? fileno($INSTALL_LOG) : ();
    opendir(my $open, '/dev/fd') or POSIX::_exit(1);
    my @numbers = grep { /^\d+$/ && $_ > 2 && !$kept{$_} } readdir $open;
    closedir $open;
    POSIX::close($_) for @numbers;
    $held //= '';                         # what lzrprf behind the window had read and not yet shown: its whole lines first, each as one
    while (1) {
        install_guarded($1) while $held =~ s/\A([^\n]*)\n//;
        install_guarded(substr($held, 0, $INSTALL_LINE, '')) while length $held > 4 * $INSTALL_LINE;
        my $left = $until - now();
        last if $left <= 0;
        my $ready = '';
        vec($ready, fileno $from, 1) = 1;
        select($ready, undef, undef, $left > 1 ? 1 : $left) > 0 or next;
        my $got = sysread($from, $held, 65536, length $held);
        next if !defined $got && $!{EINTR};
        last unless $got;
    }
    install_guarded($held) if length $held;
    POSIX::_exit(0);
}

sub install_guarded {                     # one line into install.txt once lzrprf behind the window stops while the installer runs: a line that cannot be shown is said as such there, and the reading goes on, so the installer is never left writing into a pipe nobody reads
    my ($line) = @_;
    return if eval { install_line($line); 1 };
    (my $fault = "$@") =~ s/\s+\z//;
    print {$INSTALL_LOG} 'lzrprf could not show one line of the installer (' . ($fault =~ s/[^\x20-\x7e]/?/gr) . "): it is left out, and the lines after it go on.\n" if $INSTALL_LOG;
    return;
}

# After an install that is done lzrprf takes nothing more in this window, which
# offers two buttons: Close, and Close and restart. "restart" starts the
# application again once this run has ended: a process of its own, outside
# this run's session, waits until lzrprf and the launcher that started it are
# gone (at most 20 seconds), then asks macOS to open the application at the
# place it ran from, which the installer has replaced by then. Nothing else
# is started, and "lzrprf try" starts nothing.
sub restarted {
    busy($_[0] // 'The install is done.');
    while (defined(my $line = hear())) {
        next unless $line eq 'restart';
        my ($app) = $PROGRAM =~ m{^(.*\.app)/Contents/MacOS/};
        last unless $app && !$TRY;
        record("you chose to start $APP again after the install: $app") or last;    # [C5]
        my @waits = ($$, getppid());
        my $first = fork;
        if (defined $first && !$first) {
            POSIX::setsid();
            my $second = fork;
            POSIX::_exit(0) if !defined $second || $second;
            # The waiter lets go of the window's pipes, and of every other descriptor, before it waits: while it held
            # lzrprf's output the window never saw it end, so the window stayed open until these 20 seconds were over.
            my $nowhere = POSIX::open('/dev/null', O_RDWR) // POSIX::_exit(127);
            POSIX::dup2($nowhere, $_) // POSIX::_exit(127) for 0 .. 2;
            seal();
            for (1 .. 80) { last unless grep { kill 0, $_ } @waits; Time::HiRes::sleep(0.25) }
            # The first profile comes back as the icon starts it: macOS opens the application, whose launcher starts the new lzrprf.
            # Another profile cannot go that road, since the launcher passes nothing on, so this process starts it as the Profiles
            # icon does (sub profile_command): perl, the file $SELF and the program $PROGRAM, with the profile's id alone. The
            # installer has replaced both in place by now, and a fresh perl reads $SELF from the disk, so the new release runs,
            # and it goes through every start check itself, the self-test's mark of the new release among them.
            become(undef, undef, undef, defined $PROFILE ? profile_command($PROFILE) : ('/usr/bin/open', '-n', $app));
        }
        waitpid($first, 0) if $first;
        last;
    }
    leave();
}

sub install_line {                        # one line the installer printed: in the window's modal, with its colour as one letter, and in install.txt
    my ($text) = @_;
    my ($ink) = map { $INK{$_} // () } map { split /;/ } $text =~ /\e\[([0-9;]*)m/g;
    $text =~ s/\e\][^\a\e]*(?:\a|\e\\)?//g;    # a title or a link a terminal would take: nothing of it is shown
    $text =~ s/\e\[[0-9;?]*[ -\/]*[\@-~]//g;
    $text =~ s/\e.?//gs;
    $text =~ s/\A.*\r(?=.)//s;            # a line written over itself: what stands last
    no warnings 'utf8';
    utf8::decode($text) or $text =~ s/[^\x00-\x7f]/?/g;
    $text =~ s/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]//g;
    for my $piece ($text =~ /(.{1,$INSTALL_LINE})/gs, length $text ? () : '') {
        my $part = $piece;                # a copy: an empty line is the constant '' here, which encoding it in place would change, and perl ends lzrprf for that ("Modification of a read-only value attempted": every install of releases 36 to 68 from the window ended so at the installer's first line, which is empty)
        utf8::encode($part);
        print STDOUT 'install line ' . ($ink // '-') . " $part\n";    # not "window": when the window is gone the installer is not left without its reader
        print {$INSTALL_LOG} "$part\n" if $INSTALL_LOG;
    }
}

sub install_end {                         # how the install ended, said in the modal, in install.txt and in the log; returns nothing
    my ($done, $words) = @_;
    eval { install_line($words); 1 } or do {    # the end is said even when a line cannot be cleaned: in plain characters
        my $plain = $words =~ s/[^\x20-\x7e]/?/gr;
        print STDOUT "install line - $plain\n";
        print {$INSTALL_LOG} "$plain\n" if $INSTALL_LOG;
    };
    print STDOUT 'install end ' . ($done ? 'done' : 'failed') . " $words\n";
    if ($INSTALL_LOG) { require IO::Handle; $INSTALL_LOG->flush; $^O eq 'darwin' ? fcntl($INSTALL_LOG, 51, 0) : $INSTALL_LOG->sync; close $INSTALL_LOG; undef $INSTALL_LOG }
    record('the install ' . ($done ? 'is done' : "failed: $words"));
    return;
}

sub body_of {                             # the body of an answer 200, as curl gave it raw: whole, or in chunks that are all there; nothing for anything else
    my ($got) = @_;
    my ($head, $body) = $got =~ m{\AHTTP/1\.1 200 [^\r\n]*\r\n(.*?)\r\n\r\n(.*)\z}s or return;
    return $body unless $head =~ /^transfer-encoding:[ \t]*chunked[ \t]*\r?$/mi;
    my ($whole, $end) = ('', length $body);
    pos($body) = 0;                       # read where the last chunk ended, never a copy of the rest
    while ($body =~ /\G([0-9a-fA-F]{1,8})([^\r\n]*)\r\n/gc) {
        my ($size, $more, $n, $at) = ($1, $2, hex $1, pos $body);
        return $whole unless $n;
        return unless $end >= $at + $n + 2 && substr($body, $at + $n, 2) eq "\r\n";
        $whole .= substr($body, $at, $n);
        pos($body) = $at + $n + 2;
        next if $n > 64 || length $more || utf8::is_utf8($body);    # a run is read as octets, so only a body of octets, as curl gives it
        my $from = pos $body;             # small chunks with the same size line in a row (a site's thousands of one-byte chunks): the regex engine checks all their frames at once and unpack takes their bytes, not one turn of this loop each
        next unless $body =~ /\G(?:\Q$size\E\r\n.{$n}\r\n)+/gcs;
        my $count = (pos($body) - $from) / (length($size) + $n + 4);
        $whole .= pack "C*", unpack("x$from (x" . (length($size) + 2) . "C${n}x2)$count", $body);
    }
    return;
}

