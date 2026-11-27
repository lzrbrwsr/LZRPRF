#!/bin/sh
# LZRBRWSR installer.
#
# It runs from a file and never from a pipe, so that what runs is something
# you can read and check first. In Terminal:
#
#     curl -q -fsSO https://lzrbrwsr.com/install.sh &&
#     curl -q -fsS https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/install.sh | cmp - install.sh &&
#     sh install.sh
#
# The first line saves this file. The second compares it, byte for byte, with
# the copy in a second place: lzrprf's public repository on GitHub, where
# every change to it is on record. It prints nothing when the two are the
# same, and the third line runs only then. Your own shell makes that
# comparison, before a byte of this file has run; this file cannot make it for
# you, because a changed file would simply say yes. curl is given -q first, so
# it reads no settings file of yours that could switch off its checking of the
# two sites. Then this file asks you, on your terminal, whether to print the
# whole script here first, and, whatever you answered, whether to run it.
# Each question takes y (yes, and the next question is asked too), n (no), or
# a (auto: yes to this question and to every one after it, each printed with
# its answer). "sh install.sh auto" starts in auto: that is how "Install it" in
# lzrprf's window runs it, so a newer release installs with no key pressed and
# every step stays in the Terminal window to read. Started in auto, it shows no
# question and no answer at all, because nobody is there making the choices:
# each step is said as what it does, and on an update the Dock is left as it is.
#
# What it does, in order:
#   1. asks you the two questions (none when started in auto);
#   2. stops if an LZRBRWSR that is installed, in Applications or in your own
#      Applications folder, is a newer release than this one;
#   3. downloads lzrprf, the open container, from its public repository at one
#      fixed commit, and checks its two files against the checksums below;
#   4. downloads LZRBRWSR from two places, this site and lzrprf's public
#      repository, checks it against the checksum below, and stops unless the
#      two copies are the same file;
#   5. checks what the icon will run: the download must hold exactly the seven
#      files named below, and its launcher, its property list and its release
#      file must be, byte for byte, the three texts written out in this script;
#   6. when this release would replace the lzrprf that is installed with
#      another one, says so and asks: the container is never changed silently;
#   7. runs lzrprf's own self-test on this computer: hostile tries we made
#      ourselves, just to be sure. It stops if one was not deflected (a line FAILED). A line UNTESTED, something this Mac gave
#      no way to try, does not stop it: each is printed again with its reason.
#      When all held, the test writes its mark, those checks named in it;
#   8. only then puts lzrprf into ~/.lzrprf and LZRBRWSR.app into Applications,
#      or into your own Applications folder when that one is not yours to write.
#      Both new parts are first written whole beside the ones they replace and
#      checked there; then they take their names by renames, back to back, and
#      if one fails or Ctrl-C comes, the older app and the older lzrprf are put
#      back as a pair. An older part that cannot be put back is never removed:
#      it is kept, and the installer says where it is and that the pair is not
#      whole. A power failure or a kill in that second can also leave a mixed
#      pair. Installing again mends it. Two files an earlier lzrprf kept and
#      this one does not (rules, refused) are removed;
#   9. asks whether to put LZRBRWSR in the Dock, and only on a yes adds it and
#      starts the Dock again so that it shows.
# Only one installer places files at a time: right after its two questions it takes a
# lock, the link ~/.lzrprf/.installing, and takes it away once the new parts stand at their names.
# If a step before step 8 fails, what changed is in ~/.lzrprf alone: step 7
# (the mark, the self-test's lock file) and that folder's rights. It never runs the closed program, asks for no password, reports
# nothing back, installs no updater and leaves nothing running. LZRBRWSR never
# updates itself: when you allowed it, lzrprf looks whether a newer release is
# published, and offers to fetch that release's installer into a file and run
# it in Terminal, with the same steps and the same questions.
#
# It hands no variable of your shell on: it goes on only when what it would give to a program it
# starts is nothing but your home folder (as this Mac's list of accounts gives it), the system's
# PATH, the kind of terminal and a few names a shell sets for itself, and otherwise starts itself
# once more through env -i with those three, so nothing
# set in your shell reaches curl, perl or lzrprf's self-test. It follows no redirect: each file
# comes from the address written in this file, or not at all.
#
# For tests, six variables change what it does: LZRBRWSR_BASE, LZRBRWSR_SECOND
# and LZRPRF_BASE (where the files come from; the checksums below must still match),
# LZRBRWSR_DEST (the folder the app is put in), LZRBRWSR_DOCK (a file that
# stands for the Dock's settings) and LZRBRWSR_UNATTENDED (ask nothing, and
# leave the Dock alone). They are taken only when every file comes from this
# computer itself (file:///...), which is what a test does. With one of them
# set and a file that would come from the internet, nothing runs: so a
# variable left in your shell cannot quietly change an install from the site.
#
# lzrprf is open source: https://github.com/lzrbrwsr/lzrprf
# LZRBRWSR is proprietary software: free to use, never to resell or pass on.
# All rights reserved. The licence: https://lzrbrwsr.com/terms.html
set -eu
unset IFS ARGV0	# two names a shell may have read for itself at its start; see the lines before the first case below
AUTO=; GIVEN=; SHOWN=; PARTS_GIVEN=; for word in "$@"; do case "$word" in auto) AUTO=auto GIVEN=auto ;; shown) SHOWN=shown ;; parts=*) PARTS_GIVEN="${word#parts=}" ;; esac; done	# "auto": every question answered yes; kept through the start again below. parts=NAME,...: the parts chosen without asking (packaging/parts.sh.in), kept through it too. GIVEN: started in auto, so no question is shown. SHOWN: started again through the reader of "Started in auto" below
PATH=/usr/bin:/bin:/usr/sbin:/sbin	# the system's own tools, whatever your shell was set to find first
export PATH

# Is one of the tests' six variables set? This is asked before any of them is given its usual value.
TESTING="${LZRBRWSR_BASE:-}${LZRBRWSR_SECOND:-}${LZRPRF_BASE:-}${LZRBRWSR_DEST:-}${LZRBRWSR_DOCK:-}${LZRBRWSR_UNATTENDED:-}"

# This script, curl and lzrprf's self-test take no variable of your shell: a variable can change
# what perl loads (PERL5OPT, PERL5LIB), which certificates curl trusts (SSL_CERT_FILE), or even
# what a command name means to the shell. So before anything else the script looks at what it
# would hand on to a program it starts (what /usr/bin/env prints), and goes on only when that
# is these and nothing else: your home folder as this Mac's list of accounts gives it for you
# (not as the shell says), the system's own PATH, the kind of terminal as one plain word, and
# names a shell sets for itself, each in its plain shape only (PWD, SHLVL, _; zsh also OLDPWD,
# the same folder, and LOGNAME, your account's name). With anything else there, the script
# starts itself once more through env -i with the first three (a kind of terminal that is not
# one plain word is left out; a test keeps its six settings and its home folder). No mark says
# "already clean" that a starter could set: what counts is what is there. It is read line by
# line by a perl that is itself started through env -i, and a line break or another control
# character in the value of one of these names counts as something else before that (the first
# case below), so one value cannot pass for several lines. The lines up to there name their
# tools by full path and use words of the shell that no function can give another meaning
# (case, set, unset, exec, exit, eval, for, export).
# What this cannot see or undo is what /bin/sh took in for itself at its own start and does
# not hand on. On macOS /bin/sh is bash: it reads SHELLOPTS and PS4, and with those a command
# written into PS4 runs before each of these lines, as the starter's own program; the second
# start has neither. Where an administrator made zsh the /bin/sh, it reads more for itself:
# the one found to act here (ARGV0, the name it gives the programs it starts) is unset at the
# top, and IFS with it. (With System Integrity Protection switched off, a DYLD_ variable would
# reach that first env and perl too.) What stays from the starter to the end and is no
# variable: the current folder, open files, limits, and signals set to be ignored.
case "${PATH-}${TERM-}${SHLVL-}${LOGNAME-}${HOME-}${OLDPWD-}${PWD-}${_-}" in *[[:cntrl:]]*) plain= ;; *) plain=one ;; esac
case "$plain$(/usr/bin/env | /usr/bin/env -i /usr/bin/perl -e '
	my ($testing) = @ARGV; my ($user, $home) = (getpwuid $<)[0, 7]; my $login = getlogin; my ($seen, %at) = (0);
	while (defined(my $line = <STDIN>)) {
		chomp $line;
		next if $line eq "PATH=/usr/bin:/bin:/usr/sbin:/sbin" || $line =~ m{^(?:TERM=[A-Za-z0-9._+-]+|SHLVL=[0-9]+|_=/[A-Za-z0-9._/+-]*)\z};
		if ($line =~ m{^(PWD|OLDPWD)=(/.*)\z}) { $at{$1} = $2; next }
		next if grep { defined($_) && $line eq "LOGNAME=$_" } $user, $login;
		if ($testing ne "") { next if $line =~ /^(?:HOME|LZRBRWSR_BASE|LZRBRWSR_SECOND|LZRPRF_BASE|LZRBRWSR_DEST|LZRBRWSR_DOCK|LZRBRWSR_UNATTENDED|LZRPRF_SELFTEST_HOME)=/ }
		elsif (defined $home && length $home && $line eq "HOME=$home") { $seen = 1; next }
		print "other"; exit;
	}
	print exists $at{OLDPWD} && $at{OLDPWD} ne ($at{PWD} // "") ? "other" : $testing ne "" || $seen ? "only" : "other";
' "$TESTING")" in
oneonly) ;;
*)
	case "$(/usr/bin/sed -n 2p "$0" 2>/dev/null)" in
	"# LZRBRWSR installer.")	# from a pipe there is no file to start again: nothing runs, as the lines further down say
		case "${1:-}" in
		again)
			if /bin/test -t 1; then gap=; else gap=' '; fi	# read by a window, not a terminal: no line of nothing (see "Started in auto" below)
			/usr/bin/printf '%s\n  LZRBRWSR: this installer could not be started with only your home folder, the PATH of the system\n  and the kind of terminal. Nothing was installed. Start it from a folder with a plain name.\n%s\n' "$gap" "$gap" >&2
			exit 1 ;;
		esac
		case "$TESTING" in
		'') home="$(/usr/bin/env -i /usr/bin/perl -e 'print((getpwuid $<)[7])')" ;;
		*) home="${HOME:-}" ;;
		esac
		/bin/test -n "$home" && /bin/test -d "$home" || {
			if /bin/test -t 1; then gap=; else gap=' '; fi
			/usr/bin/printf '%s\n  LZRBRWSR: this Mac gives no home folder for your account, and lzrprf keeps its files there. Nothing was installed.\n%s\n' "$gap" "$gap" >&2
			exit 1
		}
		set -- HOME="$home" PATH="$PATH"
		case "${TERM:-}" in '' | *[!A-Za-z0-9._+-]*) ;; *) set -- "$@" TERM="$TERM" ;; esac
		for name in LZRBRWSR_BASE LZRBRWSR_SECOND LZRPRF_BASE LZRBRWSR_DEST LZRBRWSR_DOCK LZRBRWSR_UNATTENDED ${TESTING:+LZRPRF_SELFTEST_HOME}; do	# in a test only: the home of a runner slot, which the self-test takes for the account's (scripts/test-run.sh)
			eval "value=\${$name:-}"
			case "$value" in '') ;; *) set -- "$@" "$name=$value" ;; esac
		done
		exec /usr/bin/env -i "$@" /bin/sh "$0" again ${AUTO:+auto} ${PARTS_GIVEN:+"parts=$PARTS_GIVEN"} ;;
	esac ;;
esac
set --
umask 022
BASE="${LZRBRWSR_BASE:-https://lzrbrwsr.com}"
# The second place of every download is the site's copy at Vercel: the production server publishes both in seconds, where
# GitHub's raw files can lag five minutes behind a release (its cache), and an install in that time would find two places
# that differ. lzrprf itself still comes from its public repository at one fixed commit (LZRPRF_BASE), which no cache delays.
SECOND="${LZRBRWSR_SECOND:-${LZRBRWSR_BASE:-https://lzrbrwsr.vercel.app}}"
FILE="lzrbrwsr-macos-arm64.tar.gz"
SHA256="3170cebc9bf1634a836b40c491ff945b07164d2aaaadb0d148392fa8ab67f087"
RELEASE="178"
LZRPRF_COMMIT="80cb67e8d724ae1fb85bfe410836044fbc95eef3"
LZRPRF_BASE="${LZRPRF_BASE:-https://raw.githubusercontent.com/lzrbrwsr/lzrprf/$LZRPRF_COMMIT}"
LZRPRF_SHA256="8c6584abd5203310e606b425b53825577667fc5da63f3c7351521c5d08e1ba65"
SELFTEST_SHA256="6a14b8cbecc7148a28f12e394cdf99f925db85ce31b55e86889df6cbf50f4291"
# BLOCKLIST_SHA256: the list of addresses lzrprf never opens, digests only, read by lzrprf from beside itself
BLOCKLIST_SHA256="9a2c542c7b59fd9ba88d84a21f363f18599561e7010e319e45bc9a383fc8a092"
# RELEASE_KEY: the public half of the release key; a release is installed only when its manifest is signed with it
RELEASE_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINHg3YnFC/5ryVmSXSX4jSb/+x8HsD8B52O07Ug75X+C lzrbrwsr-release"
# APPROVAL_KEYS: the public halves of the approval keys, comma between them; one of them approves each release
# beside the release key. The first is made in the Secure Enclave of the owner's phone and opens only to his Face ID.
# A key followed by "valid-until YYYY-MM-DD" holds through that day (UTC) and never after: the agent approval key,
# held by the project's signing service, by the owner's decision of 2026-11-22.
APPROVAL_KEYS="ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBIWKMATpVOLaAKtBC4cBWQYxOMaESOFLQrgngQ8BuBU7xm5z4JEA+a9JMkTi0dSj7FVpQZ2HhViKWh+FOcp0DVU=,ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBC8gYmKCyxfiGXwWmeZZDRY2wyW1MbVBRkaDEKff8qS13flShTkVHiRkKkCCPIwmayFMNVQ9JeMqnOx5nIb1yJM= valid-until 2027-02-28"

# Outside the tests, files come over https and nothing else, and an address
# that sends on to another is not followed. In a test they come from files on
# this computer and nothing else. curl reads no settings file of yours (-q).
if [ -z "$TESTING" ]; then
	fetch() { /usr/bin/curl -q -fsS --proto '=https' --tlsv1.2 --connect-timeout 30 --max-time 900 --max-filesize 209715200 "$1" -o "$2"; }
else
	fetch() { /usr/bin/curl -q -fsS --proto '=file' --max-time 900 "$1" -o "$2"; }
fi

# From a pipe there is no file that could be shown to you or checked. So
# nothing runs, and it says how to get the file.
if [ ! -f "$0" ] || [ "$(/usr/bin/sed -n 2p "$0" 2>/dev/null)" != "# LZRBRWSR installer." ]; then
	/bin/cat >/dev/null 2>&1 || true	# what is left of the pipe is not read as a script
	printf '\n  LZRBRWSR: this installer runs from a file, not from a pipe, so that you can\n  read and check what runs. Nothing was installed. In Terminal:\n\n      curl -q -fsSO https://lzrbrwsr.com/install.sh &&\n      curl -q -fsS https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/install.sh | cmp - install.sh &&\n      sh install.sh\n\n  What the middle line checks: https://github.com/lzrbrwsr/lzrprf#the-installer\n\n' >&2
	exit 1
fi

# Started in auto with no terminal, as the window of lzrprf starts it ("Install it"), this script is read by that
# window line by line, and so is every program it starts. lzrprf of releases 36 to 68 ends at a line that shows
# nothing (an empty one, or one of control characters only), and the first line here is empty; it reads 65536
# bytes at a time and cuts a line longer than 8000 bytes into parts of 2000, each of which must show something
# too. So in that run every line passes through the system's perl, read in bounded chunks: a line longer than
# 2000 bytes is given as lines of at most 2000 (cut between characters), and a line that would show nothing, as
# lzrprf's sub install_line cleans it, as one space; every other line is given as it is, as it comes.
# The road is a FIFO in a folder of its own that only you can open, taken away at once. Both of its ends are
# opened here before the reader starts, which is handed its end, so neither side can wait on the other or find
# the name gone; the reader holds no writer of it, so it ends with the last line this script and its programs
# print. It takes no stop signal, as this script takes none while it puts things in place: what this script exits
# with, its traps and its signals stay as they were, and a reader that is gone ends both at their next line, as
# before. Where no FIFO can be made, the same perl starts this script once more as its own child, words "auto
# shown", reads what it prints through a pipe, hands it the stop signals it is sent (those not ignored at its
# start), and ends as the script ended: with its status, or by its signal.
# On a terminal nothing of this runs.
if [ -n "$GIVEN" ] && [ -z "$SHOWN" ] && [ ! -t 1 ] && [ -x /usr/bin/perl ]; then
	shown_perl='
		use POSIX ();
		use Config;
		$| = 1;
		sub said {	# one line as the window of lzrprf would show it: one space when that is nothing
			my ($line, $end) = @_;
			my $seen = $line;
			$seen =~ s/\e\][^\a\e]*(?:\a|\e\\)?//g;
			$seen =~ s/\e\[[0-9;?]*[ -\/]*[\@-~]//g;
			$seen =~ s/\e.?//gs;
			$seen =~ s/\A.*\r(?=.)//s;
			utf8::decode($seen) or $seen =~ s/[^\x00-\x7f]/?/g;
			$seen =~ s/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Co}\p{Cs}\p{NChar}]|[^\x{0}-\x{10ffff}]//g;
			print length $seen ? $line : " ", $end;
		}
		sub shown {	# every line from one reader, in chunks of at most 65536 bytes, as lines of at most 2000
			my ($in) = @_;
			my $held = "";
			while (1) {
				my $got = sysread($in, $held, 65536, length $held);
				next if !defined $got && $!{EINTR};
				last unless $got;
				while (1) {
					if ($held =~ s/\A([^\n]{0,2000})\n//) { said($1, "\n"); next }
					last if length $held <= 2000;
					my $cut = 2000;
					$cut-- while $cut > 1996 && substr($held, $cut, 1) =~ /[\x80-\xbf]/;
					said(substr($held, 0, $cut, ""), "\n");
				}
			}
			said($held, "") if length $held;
		}
		if (!@ARGV) { $SIG{$_} = "IGNORE" for qw(INT TERM HUP QUIT); shown(\*STDIN); exit 0 }
		pipe(my $from, my $to) or do { { exec @ARGV } exit 127 };
		my $child;
		for my $stop (qw(INT TERM HUP QUIT)) {	# set before the fork: the script started again has them back as they were once it runs (exec); one ignored at the start stays ignored, in both
			$SIG{$stop} = sub { kill $_[0], $child if $child } unless ($SIG{$stop} // "") eq "IGNORE";
		}
		$child = fork;
		defined $child or do { { exec @ARGV } exit 127 };
		if (!$child) { close $from; open STDOUT, ">&", $to; open STDERR, ">&", $to; close $to; { exec @ARGV } POSIX::_exit(127) }
		close $to;
		shown($from);
		1 while waitpid($child, 0) < 0 && $!{EINTR};
		my $how = $?;
		if (my $signal = $how & 127) { my $name = (split " ", $Config{sig_name})[$signal]; $SIG{$name} = "DEFAULT" if defined $name; kill $signal, $$; exit 128 + $signal }
		exit $how >> 8;'
	shown=""
	if shown="$(/usr/bin/mktemp -d /tmp/lzrbrwsr-lines.XXXXXX 2>/dev/null)" && /usr/bin/mkfifo -m 600 "$shown/lines" 2>/dev/null && (exec 9<>"$shown/lines") 2>/dev/null; then
		exec 9<>"$shown/lines" 8<"$shown/lines"	# both ends opened here, before the reader starts: its end is handed to it, never looked up by a name that is gone
		/usr/bin/perl -e "$shown_perl" <&8 8<&- 9>&- &
		exec >"$shown/lines" 2>&1 8<&- 9>&-
		/bin/rm -rf "$shown"
	else
		[ -z "$shown" ] || /bin/rm -rf "$shown"
		exec /usr/bin/perl -e "$shown_perl" /bin/sh "$0" auto shown
	fi
fi

# Colour only when a person is looking at a terminal.
if [ -t 1 ]; then
	G="$(printf '\033[38;5;46m')" B="$(printf '\033[1;97m')" Y="$(printf '\033[1;93m')" N="$(printf '\033[0m')"
else
	G="" B="" Y="" N=""
fi

cat <<ART

 ${G}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃     ██╗     ███████╗██████╗ ██████╗ ██████╗ ██╗    ██╗███████╗██████╗      ┃${N}
 ${G}┃     ██║     ╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██║    ██║██╔════╝██╔══██╗     ┃${N}
 ${G}┃ ▒▓█ ██║       ███╔╝ ██████╔╝██████╔╝██████╔╝██║ █╗ ██║███████╗██████╔╝ ▒▓█ ┃${N}
 ${G}┃     ██║      ███╔╝  ██╔══██╗██╔══██╗██╔══██╗██║███╗██║╚════██║██╔══██╗     ┃${N}
 ${G}┃     ███████╗███████╗██║  ██║██████╔╝██║  ██║╚███╔███╔╝███████║██║  ██║     ┃${N}
 ${G}┃     ╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝     ┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃${B}  BROWSE WITH ZERO TRUST.                                                   ${N}${G}┃${N}
 ${G}┃${B}  PROOF OVER PROMISES.                                                      ${N}${G}┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃${N}  Your browser sees everything: what you read, what you type, where         ${G}┃${N}
 ${G}┃${N}  you go. Until now you could only believe what it does with that.          ${G}┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃${N}  LZRBRWSR runs inside lzrprf, an open-source security container you or     ${G}┃${N}
 ${G}┃${N}  an AI can audit. Built for clean, minimal and transparent browsing.       ${G}┃${N}
 ${G}┃${N}  No bloatware. No spyware. No telemetry. No hidden background processes.   ${G}┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃${N}   ▸ The browser has no network and no window. lzrprf owns the one          ${G}┃${N}
 ${G}┃${N}     window, and fetches the address you type into its bar.                 ${G}┃${N}
 ${G}┃${N}   ▸ Every address is written down before it is fetched, in a log           ${G}┃${N}
 ${G}┃${N}     the browser cannot touch and only you can clear.                       ${G}┃${N}
 ${G}┃${N}   ▸ It cannot read your files or your clipboard, cannot write a            ${G}┃${N}
 ${G}┃${N}     file, cannot start a program.                                          ${G}┃${N}
 ${G}┃${N}   ▸ Every page is treated as hostile: each is read in a sealed             ${G}┃${N}
 ${G}┃${N}     box of its own, and the box is thrown away.                            ${G}┃${N}
 ${G}┃${N}   ▸ The browser keeps nothing: no cookies, no account. Nothing is          ${G}┃${N}
 ${G}┃${N}     reported unless you press Send. The one record is that log.            ${G}┃${N}
 ${G}┃${N}   ▸ Our own engines lay each page out with its own styles, with            ${G}┃${N}
 ${G}┃${N}     a grey box where a picture stands. Nothing a page sends is run.        ${G}┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃${N}  You do not have to take our word for any of it.                           ${G}┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┃${N}  Read the container   https://github.com/lzrbrwsr/lzrprf                   ${G}┃${N}
 ${G}┃${N}  Get the browser      https://lzrbrwsr.com                                 ${G}┃${N}
 ${G}┃${N}                                                                            ${G}┃${N}
 ${G}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${N}

ART

step() { printf '  %s▸%s %s\n' "$G" "$N" "$1"; }
stop() {
	printf '\n  LZRBRWSR: %s Nothing was installed.\n\n' "$1" >&2
	exit 1
}

[ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ] || stop "so far only macOS on Apple silicon is built."
for part in perl sandbox-exec curl osascript openssl; do [ -x "/usr/bin/$part" ] || stop "this Mac lacks /usr/bin/$part, which lzrprf or its self-test is made of."; done

# The six variables of the tests count only when every file comes from this computer.
if [ -n "$TESTING" ]; then
	for place in "$BASE" "$SECOND" "$LZRPRF_BASE"; do
		case "$place" in
		file:///*) ;;
		*) stop "a test setting is set in this shell (a variable whose name begins LZRBRWSR_ or LZRPRF_), and test settings are taken only when every file comes from this computer. Take the variable away (unset) and run the installer again." ;;
		esac
	done
fi
[ -z "$TESTING" ] || step "test settings are in use: files from $BASE, $SECOND and $LZRPRF_BASE, the app into ${LZRBRWSR_DEST:-Applications}${LZRBRWSR_UNATTENDED:+, and no question is asked}"
[ ! -L "$HOME/.lzrprf" ] || stop ".lzrprf in your home folder is a link to somewhere else, and lzrprf keeps its files in a folder of its own."

sum() { shasum -a 256 "$1" | cut -d' ' -f1; }

# The questions. They are asked on your terminal and answered from it, so
# nothing that was piped into this script can answer for you. y is yes and the
# next question is asked too; a is auto: yes to this one and to every one after
# it, each printed with its answer, and nothing waits again.
ask() {
	if [ -n "$GIVEN" ]; then
		# Started in auto (lzrprf's update, or "sh install.sh auto"): nobody is there to choose, so no choice is shown;
		# what the yes does is said as a plain step instead, when the caller gave one.
		[ -z "${2:-}" ] || step "$2"
		return 0
	fi
	if [ -n "$AUTO" ]; then
		printf '  %s [a/y/n] a (auto)\n' "$1" >/dev/tty
		return 0
	fi
	while :; do
		printf '  %s [a/y/n] ' "$1" >/dev/tty
		read -r answer </dev/tty || stop "no answer came from the terminal."
		case "$answer" in
		a | A | auto | Auto | AUTO)
			AUTO=auto
			printf '  auto: this question and every one after it are answered yes\n' >/dev/tty
			return 0 ;;
		y | Y | yes | Yes | YES) return 0 ;;
		n | N | no | No | NO) return 1 ;;
		esac
	done
}
if [ -z "${LZRBRWSR_UNATTENDED:-}" ]; then
	# Started in auto it asks nothing, so it needs no terminal: lzrprf's window runs it after "Install it" was pressed
	# there, and shows every line it prints. By hand, the questions are asked on your terminal or not at all.
	[ -n "$GIVEN" ] || (: >/dev/tty) 2>/dev/null || stop "there is no terminal to ask you on, and this script runs only after you said so."
	if [ -n "$GIVEN" ]; then
		step "started in auto: no question is asked, and each step is printed here as it runs"
	else
	printf '  This installer is the file %s\n  Its SHA-256 is %s\n  Compare the install.sh entry in the signed release %s manifest: %s\n  Only your own comparison counts: a changed installer could print anything here.\n\n' "$0" "$(sum "$0")" "$RELEASE" "${BASE%/}/release.manifest" >/dev/tty
	if ask "Print the whole script here, before anything runs?"; then
		# Every byte of the file, except control characters, which could hide a line from you. It holds none.
		LC_ALL=C tr -d '\000-\010\013-\037\177' <"$0" >/dev/tty
		printf '\n' >/dev/tty
		ask "That was all of it. Run it now?" || stop "you said no."
	else
		ask "Run it now?" || stop "you said no."
	fi
	fi
fi
# The parts of LZRBRWSR (Henry, 2026-11-24). Each part but the browser itself is asked for, one by
# one, and only the parts you include are installed and shown. scripts/package.sh writes these lines
# into the installer at its line of the parts (the word PARTS between two at signs), so they are part of the one file whose SHA-256 is published.
#   LZRBRWSR  the browser with its profiles and its settings: always installed. The window, and the
#             settings where the other parts are switched on and off later ("Add or remove LZR
#             modules" in the cogwheel's menu), are its own, so it cannot be left out.
#   LZRDFNDR  the tool that shows and stops what runs on this Mac
#   LZRTRMNL  the terminal tab (its program core-lzrbrwsr-trmnl)
#   LZRTNNL   Tor, and an optional VPN of your own under it, set up from the Tor window (the program arti)
#   LZRGM     the minigame of the home page
# What you chose is written to ~/.lzrprf/parts once everything else stands: its first line
# "lzrbrwsr parts 1", then one name a line. lzrprf reads it (and "Add or remove LZR modules" writes
# it), so the installer and the browser share one record. An install over an earlier one offers what
# that record holds; the first install offers every part. Started in auto (lzrprf's update, or
# "sh install.sh auto"), with no question, or after you answered a, the offer is taken as it stands.
# The word parts=NAME,NAME,... chooses without asking: lzrbrwsr alone is the browser with no other
# part, and a name that is not a part stops the installer before anything changes. The program of a
# part left out is taken out of the checked app before it is put in place; LZRDFNDR and LZRGM are
# inside the program and lzrprf, so they stay on the disk, switched off and shown nowhere.
# SYNC: ../../lzrprf/src/24-parts.pl (the same record, read by lzrprf), ../../lzrprf/docs/installer.md, ../scripts/test-package-parts.sh, identity/staging (lzr_name)
parts_all="lzrdfndr lzrtrmnl lzrtnnl lzrgm"
parts_about() {
	case "$1" in
	lzrdfndr) echo "LZRDFNDR, the tool that shows and stops what runs on this Mac" ;;
	lzrtrmnl) echo "LZRTRMNL, the terminal tab" ;;
	lzrtnnl) echo "LZRTNNL, Tor with an optional VPN of your own, set up from the Tor window" ;;
	lzrgm) echo "LZRGM, the minigame of the home page" ;;
	esac
}
parts=""	# the parts chosen besides LZRBRWSR, in the order above
if [ -n "$PARTS_GIVEN" ]; then
	for name in $(printf '%s' "$PARTS_GIVEN" | tr ',' ' '); do
		case " lzrbrwsr $parts_all " in *" $name "*) ;; *) stop "parts= names \"$(printf '%s' "$name" | LC_ALL=C tr -c 'a-z0-9' '?' | cut -c1-40)\", which is no part. The parts: lzrbrwsr $parts_all." ;; esac
	done
	for name in $parts_all; do case ",$PARTS_GIVEN," in *",$name,"*) parts="$parts $name" ;; esac; done
	step "the parts were given as a word (parts=): LZRBRWSR$(for name in $parts; do printf ' %s' "$name" | tr 'a-z' 'A-Z'; done)"
else
	offer="$parts_all"	# the first install offers every part; a later one, what the record holds
	if [ -f "$HOME/.lzrprf/parts" ] && [ ! -L "$HOME/.lzrprf/parts" ] && [ "$(sed -n 1p "$HOME/.lzrprf/parts")" = "lzrbrwsr parts 1" ]; then
		offer=""
		for name in $parts_all; do ! grep -qx "$name" "$HOME/.lzrprf/parts" || offer="$offer $name"; done
	fi
	if [ -n "$GIVEN$AUTO${LZRBRWSR_UNATTENDED:-}" ]; then
		parts="$offer"
		step "the parts installed: LZRBRWSR$(for name in $parts; do printf ' %s' "$name" | tr 'a-z' 'A-Z'; done) (as the last install chose, or all of them the first time)"
	else
		printf '\n  LZRBRWSR, the browser with its profiles and settings, is always installed:\n  the window, and the settings where you switch the other parts on and off later, are its own.\n  Each other part is asked for in turn. Enter takes the answer in capitals.\n' >/dev/tty
		for name in $parts_all; do
			case " $offer " in *" $name "*) hint="Y/n" ;; *) hint="y/N" ;; esac
			while :; do
				printf '  Include %s? [%s] ' "$(parts_about "$name")" "$hint" >/dev/tty
				read -r answer </dev/tty || stop "no answer came from the terminal."
				case "$answer:$hint" in
				y:* | Y:* | yes:* | Yes:* | YES:* | :Y/n) parts="$parts $name"; break ;;
				n:* | N:* | no:* | No:* | NO:* | :y/N) break ;;
				esac
			done
		done
	fi
fi
parts_unpacked() {	# parts_unpacked <checked app>: the program of a part left out is taken out of it before it is summed and put in place
	case " $parts " in *" lzrtnnl "*) ;; *) rm -f "$1/Contents/MacOS/arti" ;; esac
	case " $parts " in *" lzrtrmnl "*) ;; *) rm -f "$1/Contents/MacOS/core-lzrbrwsr-trmnl" ;; esac
}
parts_written() {	# the record, under the lock, once everything else stands; a record that cannot be written is said: lzrprf then counts every part as installed, and a program left out makes it ask for an install
	rm -f "$HOME/.lzrprf/parts.new"
	if { echo "lzrbrwsr parts 1"; echo lzrbrwsr; for name in $parts; do echo "$name"; done; } >"$HOME/.lzrprf/parts.new" && chmod 600 "$HOME/.lzrprf/parts.new" && mv -f "$HOME/.lzrprf/parts.new" "$HOME/.lzrprf/parts"; then
		step "the parts are kept in:  $HOME/.lzrprf/parts (LZRBRWSR$(for name in $parts; do printf ' %s' "$name" | tr 'a-z' 'A-Z'; done))"
	else
		rm -f "$HOME/.lzrprf/parts.new"
		step "the record of the parts could not be written ($HOME/.lzrprf/parts): run the installer again"
	fi
	lzr_pathed
}
# lzr, LZRTRMNL's command (lzrprf lzr), on your PATH with no password asked, the way rustup and Homebrew do it: a
# launcher in a folder of the install's own (~/.lzrprf/path), and one marked line in ~/.zprofile and
# ~/.zshrc (and ~/.bash_profile when your login shell is bash) that puts that folder on the PATH of new
# terminals, never twice. lzr belongs to LZRTRMNL: an install without it takes the launcher and the lines
# away again, and so does switching LZRTRMNL off in Add or remove LZR modules (the launcher; the line,
# which then finds an empty folder, at the next install). Staging's identity names the launcher lzr-stg,
# in ~/.lzrprf-stg/path, so the two never shadow each other. The launcher says in one line when the
# installed lzrprf has no lzr yet, instead of a shell error.
lzr_name=lzr
lzr_line='case ":$PATH:" in *":$HOME/.lzrprf/path:"*) ;; *) export PATH="$HOME/.lzrprf/path:$PATH" ;; esac	# LZRBRWSR: lzr, the command of LZRTRMNL, on your PATH; its installer adds and removes this line'
lzr_ready=""	# the line of the closing words that says lzr is ready, when it is
lzr_pathed() {
	case " $parts " in
	*" lzrtrmnl "*) ;;
	*)	# LZRTRMNL left out: its launcher and its lines go
		rm -f "$HOME/.lzrprf/path/$lzr_name"; rmdir "$HOME/.lzrprf/path" 2>/dev/null || true
		for file in .zprofile .zshrc .bash_profile; do
			[ -f "$HOME/$file" ] && grep -qxF "$lzr_line" "$HOME/$file" || continue
			{ grep -vxF "$lzr_line" "$HOME/$file" >"$tmp/rc" || true; } && cat "$tmp/rc" >"$HOME/$file" && step "the line of lzr was taken out of ~/$file" || step "the line of lzr could not be taken out of ~/$file: remove the line that ends in \"its installer adds and removes this line\" by hand"
		done
		return 0 ;;
	esac
	mkdir -p "$HOME/.lzrprf/path" && rm -f "$HOME/.lzrprf/path/$lzr_name.new" && cat >"$HOME/.lzrprf/path/$lzr_name.new" <<'LZR' && chmod 755 "$HOME/.lzrprf/path/$lzr_name.new" && mv -f "$HOME/.lzrprf/path/$lzr_name.new" "$HOME/.lzrprf/path/$lzr_name" || { step "lzr could not be put in $HOME/.lzrprf/path: LZRTRMNL's own terminal still finds it"; return 0; }
#!/bin/sh
# lzr, the command of LZRTRMNL, written by the LZRBRWSR installer, which takes it away with LZRTRMNL: it starts the lzr of the installed lzrprf.
lzrprf="$HOME/.lzrprf/lzrprf"
[ -f "$lzrprf" ] && /usr/bin/grep -qF "\$command eq 'lzr'" "$lzrprf" && exec /usr/bin/perl "$lzrprf" lzr "$@"
echo "${0##*/}: the installed lzrprf ($lzrprf) has no lzr yet. It comes with a newer release of LZRBRWSR: take the update its window offers, or run the installer again." >&2
exit 127
LZR
	files=".zprofile .zshrc"
	case "$(/usr/bin/perl -e 'print((getpwuid $<)[8])')" in */bash) files="$files .bash_profile" ;; esac
	for file in $files; do
		[ -f "$HOME/$file" ] && grep -qxF "$lzr_line" "$HOME/$file" && continue	# never twice
		{ [ ! -s "$HOME/$file" ] || [ -z "$(tail -c1 "$HOME/$file")" ] || echo; printf '%s\n' "$lzr_line"; } >>"$HOME/$file" || step "~/$file could not be written: put $HOME/.lzrprf/path on your PATH yourself to type $lzr_name"
	done
	step "$lzr_name, LZRTRMNL's command, is in $HOME/.lzrprf/path, and ~/$(echo $files | sed 's/ / and ~\//g') put it on the PATH of new terminals"
	lzr_ready="
  $lzr_name, the command of LZRTRMNL, is ready in every new terminal: open one and type $lzr_name.
"
}

# One installer at a time, from here until the files are placed: two of them would each pass the checks below
# against what the other is about to replace, and each undo the other's renames. The lock is a
# link and not a file: making a link is one act, and what it points at is its text, so the lock and
# the name of its holder appear together. The text is this process's number and the moment it
# started, as the system says it (ps), so a later process that was given the same number is not
# taken for the holder.
# A lock whose holder is gone was left by an installer that was killed. It is taken away only by
# the installer that first makes a second link beside it (.installing.over), so two installers that
# find the same dead lock cannot take each other's new lock away.
lock="$HOME/.lzrprf/.installing" locked=""
started() { LC_ALL=C TZ=UTC /bin/ps -o lstart= -p "$1" 2>/dev/null || true; }	# in one zone and one language, so it reads the same when the Mac's are changed
lives() {	# lives <text of a lock>: is the process that wrote it still running, and still that process?
	case "${1%% *}" in '' | *[!0-9]*) return 1 ;; esac
	[ -n "$(started "${1%% *}")" ] && [ "${1%% *} $(started "${1%% *}")" = "$1" ]
}
take_lock() {
	[ -n "$(started "$$")" ] || stop "this Mac did not say when this process started (ps), so the installer cannot mark its lock as its own."
	me="$$ $(started "$$")"
	[ ! -e "$lock" ] || stop "$lock is not a lock of this installer. Look at it, move it away, and run this again."
	if ! ln -s "$me" "$lock" 2>/dev/null; then
		if [ ! -L "$lock" ]; then	# no lock stands: an installer that just ended took the folder it had made away
			[ -d "$HOME/.lzrprf" ] || made=1
			mkdir -p "$HOME/.lzrprf" && ln -s "$me" "$lock" 2>/dev/null || stop "the lock $lock could not be made. Run this again."
			locked=1
			return 0
		fi
		held="$(readlink "$lock" 2>/dev/null || true)"
		! lives "$held" || stop "another installer of LZRBRWSR is running on this Mac (process ${held%% *}). When it has ended, run this one again."
		ln -s "$me" "$lock.over" 2>/dev/null || stop "another installer is taking over the lock of one that was killed, or was killed itself while it did. If no installer is running, remove $lock.over and run this one again."
		[ "$(readlink "$lock" 2>/dev/null || true)" != "$held" ] || rm -f "$lock"
		if ln -s "$me" "$lock" 2>/dev/null; then
			rm -f "$lock.over"
		else
			rm -f "$lock.over"
			stop "another installer took the lock first. When it has ended, run this one again."
		fi
	fi
	locked=1
}
unlock() {	# takes the lock away when it is this process's own
	[ -z "$locked" ] || [ "$(readlink "$lock" 2>/dev/null || true)" != "$me" ] || rm -f "$lock"
	locked=""
}
# (the end of the lock's own lines)
# lzrprf's folder is made here when this Mac has none, for the lock to stand in. An installer that
# stops before it installs anything takes the folder away again, when it made it and it is empty.
made=""
[ -d "$HOME/.lzrprf" ] || made=1
mkdir -p "$HOME/.lzrprf"
tmp="" me="" testing=""
trap '[ -z "$testing" ] || { kill "$testing" 2>/dev/null; wait "$testing" 2>/dev/null; } || true; unlock; [ -z "$tmp" ] || rm -rf "$tmp"; [ -z "$made" ] || rmdir "$HOME/.lzrprf" 2>/dev/null || true' EXIT
trap 'exit 130' INT TERM HUP QUIT
take_lock
chmod 700 "$HOME/.lzrprf"

# Where the app goes: Applications, or your own Applications folder when that one is not yours to
# write. LZRBRWSR_DEST names another folder, for tests.
dest="${LZRBRWSR_DEST:-/Applications}"
[ -w "$dest" ] || dest="$HOME/Applications"

# An older release is never put over a newer one: not by a mistake, and not by somebody who serves
# you an old installer on purpose. The release that is installed says its number in a plain file.
# Both folders an install can be in are looked at, whichever of them this install goes to: Applications
# (in a test, the folder the test names in its place) and your own Applications folder. So a newer
# release in Applications is seen also when this install would go to your own folder because
# Applications is not yours to write. The refusal is this installer's: one from before release 5 does
# not hold it.
for folder in "${LZRBRWSR_DEST:-/Applications}" "$HOME/Applications"; do
	installed="$(sed -n 's/^release \([0-9]\{1,6\}\)$/\1/p' "$folder/LZRBRWSR.app/Contents/Resources/release" 2>/dev/null | sed -n 1p)"
	if [ -n "$installed" ] && [ "$installed" -gt "$RELEASE" ]; then
		stop "the LZRBRWSR that is installed in $folder is release $installed, and this installer holds the older release $RELEASE. To go back on purpose, move that LZRBRWSR.app to the Trash first."
	fi
done

tmp="$(mktemp -d)"

# The release is signed and approved, or nothing is installed. The owner read this release on his phone and approved
# it there: Face ID opened the approval key, which signed the manifest; only then did the signing service sign it with
# the release key. The manifest holds its number, when it was signed, until when the signatures hold, and the
# SHA-256 of this installer, of the download and of release.txt. The manifest and both signatures stand beside this
# installer in both places it is published, and both places must hold the same three files. macOS's own ssh-keygen
# checks each signature against the public keys written above (in a test, against the keys in the test's own folder).
# Then this installer must be the file the manifest names, of this release, signed no later than tomorrow on this
# Mac's clock, not expired, and the download is held below to the sum the manifest gives it too.
# There is no way past a refusal here: no setting, no question, no second try with another file.
key="$RELEASE_KEY"
[ -z "$TESTING" ] || key="$(sed -n 1p "${BASE#file://}/release-key.pub" 2>/dev/null || true)"
case "$key" in ssh-ed25519\ ?*) ;; *) stop "this installer carries no release key, so it cannot check that the release was signed." ;; esac
approvers="$APPROVAL_KEYS"
[ -z "$TESTING" ] || approvers="$(grep -E '^ecdsa-sha2-nistp256 ' "${BASE#file://}/approval-keys.pub" 2>/dev/null | awk '{ if ($(NF-1) == "valid-until") print $1, $2, "valid-until", $NF; else print $1, $2 }' | paste -sd, - || true)"
today="$(date -u +%Y%m%d)"
printf '%s\n' "$approvers" | tr ',' '\n' | grep -E '^ecdsa-sha2-nistp256 [A-Za-z0-9+/]+=*( valid-until [0-9]{4}-[0-9]{2}-[0-9]{2})?$' |
	while read -r kind blob _ until; do
		[ -z "$until" ] || [ "$(printf '%s' "$until" | tr -d -)" -ge "$today" ] || continue    # past its valid-until day: not carried
		printf 'lzrbrwsr-approval namespaces="lzrbrwsr-approval" %s %s\n' "$kind" "$blob"
	done >"$tmp/approvers"
[ -s "$tmp/approvers" ] || stop "this installer carries no approval key, so it cannot check that the owner approved the release."
copy=0
for place in "$BASE" "$SECOND"; do
	copy=$((copy + 1))
	fetch "$place/release.manifest" "$tmp/manifest.$copy" || stop "could not download the signed manifest of this release from $place."
	fetch "$place/release.manifest.sig" "$tmp/manifest.$copy.sig" || stop "could not download the signature of this release from $place."
	fetch "$place/release.manifest.approval" "$tmp/manifest.$copy.approval" || stop "could not download the approval of this release from $place."
done
cmp -s "$tmp/manifest.1" "$tmp/manifest.2" && cmp -s "$tmp/manifest.1.sig" "$tmp/manifest.2.sig" && cmp -s "$tmp/manifest.1.approval" "$tmp/manifest.2.approval" ||
	stop "the two places hold different signed manifests. Either a newer release was just published (get the installer again), or one of the two places was changed."
printf 'lzrbrwsr-release namespaces="lzrbrwsr-release" %s\n' "$(printf '%s' "$key" | cut -d' ' -f1-2)" >"$tmp/allowed"
/usr/bin/ssh-keygen -Y verify -f "$tmp/allowed" -I lzrbrwsr-release -n lzrbrwsr-release -s "$tmp/manifest.1.sig" <"$tmp/manifest.1" >/dev/null 2>&1 ||
	stop "the signature of this release does not hold for the release key this installer carries."
/usr/bin/ssh-keygen -Y verify -f "$tmp/approvers" -I lzrbrwsr-approval -n lzrbrwsr-approval -s "$tmp/manifest.1.approval" <"$tmp/manifest.1" >/dev/null 2>&1 ||
	stop "this release is not approved with an approval key this installer carries (a key past its valid-until day is not carried): nothing is installed."
awk 'NR == 1 && $0 != "lzrbrwsr release manifest 1" { bad = 1 }
     NR == 2 && $0 !~ /^release [1-9][0-9]*$/ { bad = 1 }
     NR == 3 && $0 !~ /^signed [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/ { bad = 1 }
     NR == 4 && $0 !~ /^expires [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/ { bad = 1 }
     NR > 4 && $0 !~ /^file [A-Za-z0-9][A-Za-z0-9._-]* [0-9a-f]+$/ { bad = 1 }
     END { exit bad || NR < 5 }' "$tmp/manifest.1" || stop "the signed manifest is not in its form."
[ "$(sed -n 2p "$tmp/manifest.1")" = "release $RELEASE" ] || stop "the signed manifest is of another release than this installer's ($RELEASE)."
epoch() { date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || echo x; }
signed="$(epoch "$(sed -n 3p "$tmp/manifest.1" | cut -d' ' -f2)")" expires="$(epoch "$(sed -n 4p "$tmp/manifest.1" | cut -d' ' -f2)")" now="$(date -u +%s)"
case "$signed$expires" in *[!0-9]*) stop "the signed manifest names a time that is no time." ;; esac
[ "$signed" -le "$((now + 86400))" ] || stop "the signed manifest says it was signed later than this Mac says it is now."
[ "$now" -lt "$expires" ] || stop "the signature of this release has expired."
[ "$expires" -gt "$signed" ] && [ "$((expires - signed))" -le $((400 * 86400)) ] || stop "the signature of this release says it holds longer than 400 days."
named() { sed -n "s/^file $1 \([0-9a-f]\{64\}\)\$/\1/p" "$tmp/manifest.1" | sed -n 1p; }
[ "$(named install.sh)" = "$(sum "$0")" ] || stop "this installer is not the one the signed manifest names."
[ "$(named "$FILE")" = "$SHA256" ] || stop "the signed manifest names another download than this installer."
step "release $RELEASE is signed with the release key ($(printf '%s\n' "$key" | /usr/bin/ssh-keygen -l -f - 2>/dev/null | cut -d' ' -f2)), and this installer is the one it names"
# The curated script rules (plan 0001029 E2), when the signed manifest names them: reviewed rules that let
# known scripts of a few sites run with no question. They are fetched from both places, must be the same file
# in both, and must be the file the manifest names by its SHA-256. They are kept beside lzrprf with the manifest
# and both its signatures, and lzrprf checks all four again before it uses one rule: a file changed afterwards is
# never used, and lzrprf then asks. A release whose manifest names none has the four taken away.
rulesum="$(named permit-rules)"
if [ -n "$rulesum" ]; then
	fetch "$BASE/permit-rules" "$tmp/permit-rules" || stop "could not download the curated script rules of this release."
	fetch "$SECOND/permit-rules" "$tmp/permit-rules.2" || stop "could not download the second copy of the curated script rules, from the site's second copy, at Vercel."
	cmp -s "$tmp/permit-rules" "$tmp/permit-rules.2" || stop "the two places hold different curated script rules. Either a newer release was just published (get the installer again), or one of the two places was changed."
	[ "$(sum "$tmp/permit-rules")" = "$rulesum" ] || stop "the curated script rules are not the file the signed manifest names."
	step "the curated script rules are the file the signed manifest names, the same in both places"
fi
# The filter lists (plan 0001029 F, lzrprf's docs/filters.md), each one the signed manifest names: uAssets'
# lists as ubo-NAME.txt with their record ubo-SOURCE, and lzrprf's reviewed exceptions as filters-local.txt.
# Each is fetched from both places, must be the same file in both and the file the manifest names by its
# SHA-256, and is kept beside lzrprf with the manifest and both its signatures, which lzrprf checks again
# before it uses one rule. They block requests only: no list decides whether a script runs.
filterfiles="$(awk '$1 == "file" && ($2 ~ /^ubo-[a-z0-9][a-z0-9.-]*\.txt$/ || $2 == "ubo-SOURCE" || $2 == "filters-local.txt") { print $2 }' "$tmp/manifest.1")"
for part in $filterfiles; do
	fetch "$BASE/$part" "$tmp/$part" || stop "could not download the filter list $part of this release."
	fetch "$SECOND/$part" "$tmp/$part.2" || stop "could not download the second copy of the filter list $part, from the site's second copy, at Vercel."
	cmp -s "$tmp/$part" "$tmp/$part.2" || stop "the two places hold different copies of the filter list $part. Either a newer release was just published (get the installer again), or one of the two places was changed."
	[ "$(sum "$tmp/$part")" = "$(named "$part")" ] || stop "the filter list $part is not the file the signed manifest names."
done
[ -z "$filterfiles" ] || step "the filter lists are the files the signed manifest names, the same in both places"

# get <address> <file> <checksum> <what it is>
get() {
	fetch "$1" "$tmp/$2" || stop "could not download $4."
	[ "$(sum "$tmp/$2")" = "$3" ] || stop "$4 does not match its checksum."
}

get "$LZRPRF_BASE/lzrprf" lzrprf "$LZRPRF_SHA256" "lzrprf"
get "$LZRPRF_BASE/selftest" selftest "$SELFTEST_SHA256" "lzrprf's self-test"
get "$LZRPRF_BASE/blocklist" blocklist "$BLOCKLIST_SHA256" "lzrprf's list of the addresses it never opens"
step "lzrprf downloaded, and it is the published one (commit $(printf %.12s "$LZRPRF_COMMIT"))"
get "$BASE/$FILE" "$FILE" "$SHA256" "the download"
# The same download once more, from a second place: the site's copy at Vercel, which the production server
# publishes beside the site; every release's download is also on record in lzrprf's public repository. Both must be the file this installer names.
# One changed place cannot pass: the site's copy is held to the checksum above, and so is this one.
fetch "$SECOND/$FILE" "$tmp/second" || stop "could not download the second copy of LZRBRWSR, from the site's second copy, at Vercel."
if ! cmp -s "$tmp/$FILE" "$tmp/second"; then
	stop "the site's second copy, at Vercel, holds another download than the site. Either a newer release was just published (get the installer again), or one of the two places was changed."
fi
rm -f "$tmp/second"
step "LZRBRWSR downloaded from two places: both are the same file, and it matches its checksum"

# What the icon will run is checked before anything is put in place. The
# download must name these ten files, the four folders they are in, and
# nothing else. It is unpacked into an empty folder of its own, so that nothing
# in it can take the place of a file that was checked above.
names="$(tar -tzf "$tmp/$FILE" | LC_ALL=C sort | tr '\n' ' ')"
[ "$names" = "LZRBRWSR.app/ LZRBRWSR.app/Contents/ LZRBRWSR.app/Contents/Info.plist LZRBRWSR.app/Contents/MacOS/ LZRBRWSR.app/Contents/MacOS/arti LZRBRWSR.app/Contents/MacOS/core-lzrbrwsr-cht LZRBRWSR.app/Contents/MacOS/core-lzrbrwsr-trmnl LZRBRWSR.app/Contents/MacOS/lzrbrwsr LZRBRWSR.app/Contents/MacOS/lzrbrwsr-bin LZRBRWSR.app/Contents/MacOS/lzrbrwsr-window LZRBRWSR.app/Contents/Resources/ LZRBRWSR.app/Contents/Resources/LICENSE.txt LZRBRWSR.app/Contents/Resources/lzrbrwsr.icns LZRBRWSR.app/Contents/Resources/release " ] || stop "the download holds files that do not belong in it."
[ -z "$(tar -tvzf "$tmp/$FILE" | grep -v '^[-d]')" ] || stop "the download holds a link."
mkdir "$tmp/unpacked"
tar -xzf "$tmp/$FILE" -C "$tmp/unpacked"
[ "$(cd "$tmp/unpacked" && find . ! -type d | LC_ALL=C sort | tr '\n' ' ')" = "./LZRBRWSR.app/Contents/Info.plist ./LZRBRWSR.app/Contents/MacOS/arti ./LZRBRWSR.app/Contents/MacOS/core-lzrbrwsr-cht ./LZRBRWSR.app/Contents/MacOS/core-lzrbrwsr-trmnl ./LZRBRWSR.app/Contents/MacOS/lzrbrwsr ./LZRBRWSR.app/Contents/MacOS/lzrbrwsr-bin ./LZRBRWSR.app/Contents/MacOS/lzrbrwsr-window ./LZRBRWSR.app/Contents/Resources/LICENSE.txt ./LZRBRWSR.app/Contents/Resources/lzrbrwsr.icns ./LZRBRWSR.app/Contents/Resources/release " ] || stop "the download holds files that do not belong in it."
[ -z "$(find "$tmp/unpacked" ! -type d ! -type f)" ] || stop "the download holds a link."
# The launcher is the file the icon runs. This is all of it: it starts lzrprf,
# and lzrprf starts the program. The one in the download must be the same.
cat >"$tmp/launcher" <<'LAUNCHER'
#!/bin/sh
# LZRBRWSR starts here, and only here. This file is plain text so that you
# can read what the icon runs: lzrprf, the open container
# (https://github.com/lzrbrwsr/lzrprf), and inside it the program,
# lzrbrwsr-bin, which stands beside this file.
#
# The window you see is lzrprf's, under the name LZRBRWSR. The program has
# no window and no network. The address you type into the bar of that window
# is fetched by lzrprf itself, and written down first:
#
#     perl ~/.lzrprf/lzrprf log
#
# Without lzrprf the program is not started at all.
#
# This file reads no variable of whoever started it. Its one command starts
# perl with no variable at all (env -i), and the few lines of perl below find
# your home folder in this Mac's list of accounts, as lzrprf does, and the
# folder this file is in. So nothing set around it chooses which lzrprf runs.
# What is left of the starter's is how /bin/sh itself starts, before this line.
exec /usr/bin/env -i /usr/bin/perl -e '
use Cwd qw(abs_path getcwd); use File::Basename "dirname";
my $lzrprf = ((getpwuid $<)[7] // "") . "/.lzrprf/lzrprf";
if (!-f $lzrprf) {
	system "/usr/bin/osascript", "-e", q{display alert "LZRBRWSR needs lzrprf" message "lzrprf, the open container LZRBRWSR runs in, is not on this computer, and LZRBRWSR does not start without it. Install it again: how is on https://lzrbrwsr.com"};
	exit 1;
}
my $self = abs_path(shift) // exit 1;
my $from = getcwd();
chdir dirname($self) or exit 1;
my $here = getcwd() // exit 1;
chdir $from if defined $from;
exec "/usr/bin/perl", $lzrprf, "run", "$here/lzrbrwsr-bin", @ARGV;
' -- "$0" "$@"
LAUNCHER
cmp -s "$tmp/launcher" "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/lzrbrwsr" || stop "the icon would not start LZRBRWSR through lzrprf."
# The property list tells macOS which file the icon runs, and it could also set
# variables for it. This is all of it: it names the launcher and sets none.
cat >"$tmp/plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>lzrbrwsr</string>
	<key>CFBundleIdentifier</key>
	<string>com.lzrbrwsr.browser</string>
	<key>CFBundleName</key>
	<string>LZRBRWSR</string>
	<key>CFBundleDisplayName</key>
	<string>LZRBRWSR</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleIconFile</key>
	<string>lzrbrwsr</string>
	<key>LSArchitecturePriority</key>
	<array>
		<string>arm64</string>
	</array>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHumanReadableCopyright</key>
	<string>Proprietary. Copyright 2026 create.repeat Oy. All rights reserved. Free to use; the terms: https://lzrbrwsr.com/terms.html</string>
</dict>
</plist>
PLIST
cmp -s "$tmp/plist" "$tmp/unpacked/LZRBRWSR.app/Contents/Info.plist" || stop "the app's property list is not the one written out in the installer."
# The release file is what lzrprf reads beside the program: the number of this release, four fixed
# addresses, the SHA-256 of the launcher, of the program, of the Tor client, of LZRTRMNL's drawing and of LZRCHT and of the window host (the six lines "file"), which lzrprf
# compares with those five files at every start, and the SHA-256 of the lzrprf this app is installed
# with, which lzrprf compares with itself at every start, and the SHA-256 of the list of addresses lzrprf never opens ("blocklist"),
# which lzrprf compares with the list beside it before it opens any page. This is all of it. "newest" is the one address lzrprf fetches by itself, and only
# after you said yes in its window. "installer" and "same" are the two places a newer release's
# installer is fetched from, by Terminal, after you chose to install it. "report" is where a report
# goes, and only when you pressed Send.
cat >"$tmp/release" <<'RELEASEFILE'
release 178
new Long pages draw to their end: every picture is fetched, not just the first 24, and pictures appear as they arrive.
new LZRBRWSR no longer gets stuck at full CPU or stops answering: macOS AutoFill kept retrying inside its window.
new Discord in LZRCHT now opens titled Discord in its own tab, instead of a "not supported yet" notice.
new Scrolling is smoother with a little more momentum, a page no longer jumps while it loads, and a minimized LZRDFNDR question waits in its icon with a count.
new The menu bar says LZRBRWSR, questions open in the same box as everything else and never hold your tabs, and Discord connects from LZRCHT in its own tab.
new Pages and files in 27 older encodings (Cyrillic, Greek, Central European, Hebrew and more) now read correctly.
home local
newest https://lzrbrwsr.com/latest
installer https://lzrbrwsr.com/install.sh
same https://lzrbrwsr.vercel.app/install.sh
report https://origin.lzrbrwsr.com/report
file lzrbrwsr 604a5cf1225c06b9beb01f80bd01d81645855dd3d63fc16a78b5e91198966eb1
file lzrbrwsr-bin d6443f3cbabf7caf3cf1b44d2022c428e4f5ec9c3ef1261035ce341e6658b50f
file arti b27695a75064d3a768485b17071e7c58c2281cb93694a554fd379b15a134e444
file core-lzrbrwsr-trmnl 6a60796b6a9510675c6b509d5fa6dd6b8543aa1afb8bc8411f240c93dc95bf03
file core-lzrbrwsr-cht 30c360815db8fc7fed396b12f64d96ec4b5d7539a283b0f5c5ad8d8aac9af8d2
file lzrbrwsr-window 6472a7855c52851bd8db375b86a7f3b400b77353bcab70a663c39574497867c9
lzrprf 8c6584abd5203310e606b425b53825577667fc5da63f3c7351521c5d08e1ba65
blocklist 9a2c542c7b59fd9ba88d84a21f363f18599561e7010e319e45bc9a383fc8a092
RELEASEFILE
cmp -s "$tmp/release" "$tmp/unpacked/LZRBRWSR.app/Contents/Resources/release" || stop "the app's release file is not the one written out in the installer."
grep -qx "lzrprf $LZRPRF_SHA256" "$tmp/release" || stop "the app's release file does not name the lzrprf this installer carries."
grep -qx "blocklist $BLOCKLIST_SHA256" "$tmp/release" || stop "the app's release file does not name the list of addresses this installer carries."
for name in lzrbrwsr-bin lzrbrwsr arti core-lzrbrwsr-trmnl core-lzrbrwsr-cht lzrbrwsr-window; do
	grep -qx "file $name $(sum "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/$name")" "$tmp/release" || stop "the app's release file does not name the file $name as it was unpacked."
done
step "the icon runs one thing: lzrprf, and inside it LZRBRWSR (release $RELEASE)"

# lzrprf is what holds LZRBRWSR in. A release of the browser never changes its own container
# silently: when the lzrprf this installer carries is not the one that is installed, that is
# said, with both checksums and where every change to it can be read, and it is your decision.
if [ -f "$HOME/.lzrprf/lzrprf" ] && [ "$(sum "$HOME/.lzrprf/lzrprf")" != "$LZRPRF_SHA256" ]; then
	step "this release replaces lzrprf, the container itself"
	step "  installed  $(sum "$HOME/.lzrprf/lzrprf")"
	step "  new        $LZRPRF_SHA256"
	step "  every change to it: https://github.com/lzrbrwsr/lzrprf/commits/main"
	if [ -z "${LZRBRWSR_UNATTENDED:-}" ]; then
		ask "Replace lzrprf with the new one? First it deflects, here on this Mac, hostile tries we made ourselves to be sure." "lzrprf is replaced by the new one once it deflects, here on this Mac, hostile tries we made ourselves to be sure" || stop "you said no to the new lzrprf."
	fi
fi

# The container proves itself on this computer before anything is put in place:
# we run hostile tries of our own inside it, made just to be sure, and it must
# deflect every one of them.
# It also leaves the mark of what it tested (this build of macOS, this lzrprf)
# in ~/.lzrprf/proven: lzrprf starts nothing without that mark, and asks to be
# tested again when macOS has changed.
#
# The test's steps are shown as they happen, each with its title and a beam
# while it runs that flies at lzrprf's wall and strikes it: the sparks fly back
# off the wall, in yellow and bright white, and nothing passes it. Every run of
# lzrprf is a line of its own, under the step it belongs to, as it ends: its
# number, the protection it verifies, and how long it took; a sentence longer than
# its column goes on in rows under it, never cut. Every word of it is read from the
# test's own output: its lines "now ..." and its numbered headings are the
# titles, its lines "ran ..." the runs, and the lines "held" under a heading are
# counted. Nothing here decides what held; a run that ran is judged afterwards.
# What was printed already is counted in $tmp/shown.
shown() {	# shown <frame> <seconds so far> <has the test ended: 0 or 1>
	awk -v frame="$1" -v seconds="$2" -v ended="$3" -v kept="$tmp/shown" -v G="$G" -v B="$B" -v Y="$Y" -v N="$N" '
		BEGIN { if ((getline printed < kept) <= 0) printed = 0; close(kept) }
		function line(text) { rows++; row[rows] = text }
		function closed_title() {
			if (n && !done[n]) line(sprintf("    %-54s %s━━━━━━%s✦%s▌%s  %s", title[n], G, Y, B, N, failed[n] ? "FAILED" : held[n] ? B held[n] " deflected" N : ran[n] ? B ran[n] " ran" N : "done"))
			done[n] = 1
		}
		/^now / { closed_title(); n++; title[n] = substr($0, 8); sub(/[.:;].*/, "", title[n]); next }
		/^[0-9]+\. / { closed_title(); n++; title[n] = $0; sub(/^[0-9]+\. /, "", title[n]); sub(/[.:;].*/, "", title[n]); next }
		function put(part) {	# one row of a run: the first carries its number and its time, the rows after it stand under the sentence
			if (count != "") line(sprintf("      %s%-8s%s %-56s %5s s", B, count, N, part, took))
			else line(sprintf("               %s", part))
			count = ""
		}
		/^ran / {	# the whole sentence is shown, wrapped at a space into rows of at most 56 characters, so every row fits 80 columns
			ran[n]++; what = $0; sub(/^ran +[^ ]+ +[^ ]+ +/, "", what); count = $2; took = $3
			while (length(what) > 56) {
				cut = 57; while (cut > 1 && substr(what, cut, 1) != " ") cut--
				if (cut == 1) cut = 57	# a word longer than the row is broken
				put(substr(what, 1, cut - 1)); what = substr(what, cut); sub(/^ +/, "", what)
			}
			put(what); next
		}
		/^(held|works) / { held[n]++ }
		/^FAILED/ { failed[n]++ }
		END {
			if (ended) closed_title()
			clear = G == "" ? "" : "\r\033[K"
			for (i = printed + 1; i <= rows; i++) printf "%s%s\n", clear, row[i]
			print rows > kept
			if (!ended && n > 0 && G != "") {
				at = frame % 10
				beam = ""
				if (at < 7) {	# the beam flies at the wall
					for (i = 0; i < at; i++) beam = beam "━"
					beam = beam "▶" N
					for (i = at; i < 6; i++) beam = beam " "
					beam = beam B "▌" N "   "
				} else {	# it strikes the wall: the sparks fly back off it, yellow and bright white, and nothing passes it
					spark[7] = "━━━━━━" Y "✸"; spark[8] = "━━━━" Y "✦" B "✧" Y "✸"; spark[9] = "━━" Y "·" B " ✧" Y " ✦"
					beam = spark[at] B "▌" N "   "
				}
				printf "%s    %-54s %s%s%s  %s s", clear, title[n], G, beam, N, seconds
			}
		}' "$tmp/selftest.out"
}
# A disk that is almost full stalls the self-test without a word: each file it writes waits. So the room
# is read first, and an installer on a full disk says so and changes nothing (2026-11-23: release 81's
# install ran out its 30 minutes on a disk with 193 MB free).
free_mb="$(df -m "$tmp" 2>/dev/null | awk 'NR==2 { print $4 }')"
case "$free_mb" in '' | *[!0-9]*) free_mb=0 ;; esac
[ "$free_mb" -ge 2048 ] || stop "this Mac has $free_mb MB free on its disk, and the self-test needs at least 2048 MB. Nothing was changed: free some room and run the installer again."
step "lzrprf now deflects hostile tries we made ourselves, just to be sure: about half a minute"
/usr/bin/perl "$tmp/selftest" >"$tmp/selftest.out" 2>&1 &
testing=$!
# Stopped with Ctrl-C: the test is told, and it ends every process it started and takes its files away.
trap 'kill "$testing" 2>/dev/null || true; wait "$testing" 2>/dev/null || true; exit 130' INT TERM HUP QUIT
: >"$tmp/shown"
frame=0 seconds=0 said=0 stuck="" began="$(date +%s)" grew="$(date +%s)" size=0
while kill -0 "$testing" 2>/dev/null; do
	seconds="$(($(date +%s) - began))"
	if [ "$seconds" -gt 1800 ]; then	# DECLARED(half a minute on a quiet Mac; a Mac busy with other work can take many times that) a test that does not end is ended, and counts as one that did not hold
		kill "$testing" 2>/dev/null || true
		break
	fi
	now_size="$(wc -c <"$tmp/selftest.out" 2>/dev/null | tr -d ' ')"
	if [ "${now_size:-0}" != "$size" ]; then size="${now_size:-0}" grew="$(date +%s)"
	elif [ "$(($(date +%s) - grew))" -gt 300 ]; then	# DECLARED(each run of the test is ended by the test itself after 90 s, so five minutes with no line at all is a test that stands still) it is ended as stuck, and counts as one that did not hold
		stuck=yes
		kill "$testing" 2>/dev/null || true
		break
	fi
	if [ -t 1 ]; then
		shown "$frame" "$seconds" 0 || true
		frame=$((frame + 1))
		sleep 0.1
	else	# no terminal (the window's update panel, a log): each step and each run is printed as it ends, as on a terminal but without the beam; when nothing new was printed for 5 seconds, a plain line says the test still runs, so the wait is never silent
		sleep 1
		before=0 after=0
		read -r before <"$tmp/shown" 2>/dev/null || before=0
		shown 0 "$seconds" 0 || true
		read -r after <"$tmp/shown" 2>/dev/null || after=0
		if [ "$after" != "$before" ]; then
			said="$seconds"
		elif [ "$((seconds - said))" -ge 5 ]; then
			said="$seconds"
			step "  Still waiting... $seconds s"
		fi
	fi
done
if wait "$testing"; then held=yes; else held=no; fi
testing=""	# it has ended: nothing is left for the line that ends it at an exit
trap 'exit 130' INT TERM HUP QUIT
shown 0 0 1 || true
if [ "$held" = yes ]; then
	untested="$(grep -c '^UNTESTED' "$tmp/selftest.out" || true)"
	step "self-test on this computer: lzrprf deflected all $(grep -c '^held' "$tmp/selftest.out") hostile tries we made ourselves, just to be sure"
	if [ "$untested" != 0 ]; then
		step "$untested of its checks could not be tried on this Mac. Each one, and why:"
		grep '^UNTESTED' "$tmp/selftest.out" | LC_ALL=C tr -c '\n\040-\176' '?' | cut -c1-300 | sed 's/^/      /'
		step "the mark of this test names them, and LZRBRWSR shows them and asks before it starts"
	fi
else
	if grep -q '^FAILED' "$tmp/selftest.out"; then	# each try that got through, cut at 300 characters as the checks that could not be tried are
		# each check cut at 200 characters, and the line "saw" the self-test prints after it with what it saw, cut at 600:
		# a long check filled the 300 characters that were shown, so 177's failure could not be told from its screen
		grep -E '^(FAILED|saw    )' "$tmp/selftest.out" | awk '/^saw / { print "    " substr($0, 1, 600); next } { print substr($0, 1, 200) }' >&2
		kept="${TMPDIR:-/tmp}/lzrbrwsr-selftest-failed.txt"    # outside ~/.lzrprf: a refused install leaves nothing there
		cp "$tmp/selftest.out" "$kept" 2>/dev/null && printf '  The whole self-test is kept in %s.\n' "$kept" >&2
	else	# no try got through: the test itself ended early; its last words say why
		printf '  The self-test ended before it was done. Its last lines:\n' >&2
		tail -n 5 "$tmp/selftest.out" | LC_ALL=C tr -c '\n\040-\176' '?' | cut -c1-300 | sed 's/^/      /' >&2
		[ "$seconds" -le 1800 ] || printf '  It did not end within 30 minutes: this Mac is very busy. Run the installer again when it is quieter.\n' >&2
		[ -z "$stuck" ] || printf '  It printed nothing for 5 minutes, so it was ended as stuck. Run the installer again; if it stops at the same place, that place is named above.\n' >&2
	fi
	stop "lzrprf's self-test did not hold on this computer."
fi

# What is put in place has exactly these rights. No attribute is taken off anything: the archive is
# packed without any (and is the file whose SHA-256 stands above), and a mark that macOS itself put on
# a file, the quarantine mark among them, stays where it is.
find "$tmp/unpacked" -type d -exec chmod 755 {} +
find "$tmp/unpacked" -type f -exec chmod 644 {} +
chmod 755 "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/lzrbrwsr-window" "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/lzrbrwsr-bin" "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/lzrbrwsr" "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/arti" "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/core-lzrbrwsr-trmnl" "$tmp/unpacked/LZRBRWSR.app/Contents/MacOS/core-lzrbrwsr-cht"; parts_unpacked "$tmp/unpacked/LZRBRWSR.app"

# Putting in place, as one change as far as files allow. First both new parts are written whole into
# folders of their own beside where they go (the same disk, so that a name can be taken by a rename),
# under names nobody can know beforehand, and checked there. Until then nothing that is installed
# has changed. Then the older ones are kept aside and the new ones take their names, renames back to
# back; if one fails, or Ctrl-C comes, every rename done is undone and the older app and the older
# lzrprf are back as a pair. Only when all stand are the older ones removed.
#
# What a script cannot do: make renames in two folders one act. If the power fails between them, or
# the installer is killed outright, the computer can be left with the new app and the older lzrprf,
# or the other way round, or with the app still aside in a hidden folder .LZRBRWSR.* in the same
# folder as the app. From this release on lzrprf notices a pair that does not belong together at
# its next start: the app's release file names the SHA-256 of the lzrprf it was installed with,
# lzrprf compares that with itself, says so and asks. That needs an app and an lzrprf that both
# know the line: an app of release 11 or earlier names no lzrprf, and an lzrprf of release 11 or
# earlier does not look. Running this installer again puts a matching pair in place.
[ "$(sum "$tmp/lzrprf")" = "$LZRPRF_SHA256" ] && [ "$(sum "$tmp/selftest")" = "$SELFTEST_SHA256" ] && [ "$(sum "$tmp/blocklist")" = "$BLOCKLIST_SHA256" ] || stop "lzrprf changed while it was being installed."
for part in lzrprf selftest blocklist; do
	if [ -L "$HOME/.lzrprf/$part" ] || { [ -e "$HOME/.lzrprf/$part" ] && [ ! -f "$HOME/.lzrprf/$part" ]; }; then
		stop "$HOME/.lzrprf/$part is not a plain file, and lzrprf, its self-test and its list are plain files. Look at what stands there, move it away, and run this again."
	fi
done
mkdir -p "$dest"
# What an earlier install left behind. This runs under the lock, so no folder of a running installer
# is among them. In lzrprf's folder: new files that never got their names, and second names of the
# installed ones, are removed. A folder that holds an older lzrprf, selftest or blocklist which is NOT the
# installed one is the only copy of it, and stays: it is named, every time, until you remove it.
# In the app's folder nothing with a file in it is removed: a hidden folder .LZRBRWSR.* there can
# hold the older app, whole. It is named; an empty one is removed.
for left in "$HOME/.lzrprf"/.new.????????; do
	[ -d "$left" ] || continue
	only=""
	for part in lzrprf selftest blocklist; do
		[ ! -e "$left/old.$part" ] || cmp -s "$left/old.$part" "$HOME/.lzrprf/$part" || only=1
	done
	if [ -n "$only" ]; then
		step "an older lzrprf is kept in: $left"
		step "an earlier install could not put it back, or was killed just after the new one was in place; remove that folder by hand when you do not need it"
	else
		rm -rf "$left" || step "what an earlier install left could not be removed: $left"
	fi
done
for left in "$dest"/.LZRBRWSR.????????; do
	[ -d "$left" ] && [ ! -L "$left" ] || continue
	if rmdir "$left" 2>/dev/null; then
		continue	# it was empty: an install was stopped as it began
	elif [ -e "$left/old.app" ]; then
		step "an older LZRBRWSR.app is kept in: $left"
		step "an earlier install could not put it back, or was killed; remove that folder by hand when you do not need it"
	else
		step "a LZRBRWSR.app that an earlier install never put in place is left in: $left (remove that folder by hand)"
	fi
done
# appsum <folder>: one checksum of every name and every file's contents in that folder
appsum() { (cd "$1" && find . | LC_ALL=C sort && find . -type f -exec shasum -a 256 {} + | LC_ALL=C sort) | shasum -a 256 | cut -d' ' -f1; }
checked="$(appsum "$tmp/unpacked/LZRBRWSR.app")"
stage="" prfstage="" placing="" back=0 kept="" had_lzrprf="" had_selftest="" had_blocklist=""
# undo: puts back what was there. It goes by what stands on the disk and not by a count of the steps
# done, so it is right at whichever rename a failure or Ctrl-C came. Before the renames began
# (placing is empty) nothing installed has changed and only the folders of the new parts are removed.
# Every putting back is checked. An older part that could not be put back is never removed: it stays
# where it is, "kept" names the place, and "back" is 1 so that what is printed afterwards is true.
# Whether there was an older lzrprf file is what was noted when its second name was made (had_...),
# not what the disk shows now: an installed file is removed only when none stood there before.
undo() {
	trap '' INT TERM HUP QUIT
	set +e	# every step below is checked by itself; none may end the script half way
	holds=""
	if [ -n "$placing" ]; then
		# A new lzrprf file that has left its folder holds the installed name: the older one, kept
		# under a second name, takes the name back; if there was none, the name is removed.
		for part in blocklist selftest lzrprf; do
			[ ! -e "$prfstage/$part" ] || continue
			if [ -e "$prfstage/old.$part" ]; then
				if ! mv -f "$prfstage/old.$part" "$HOME/.lzrprf/$part"; then
					back=1 holds=1
					kept="$kept
      the older $part: $prfstage/old.$part"
				fi
			elif eval "[ -n \"\$had_$part\" ]"; then
				back=1
				kept="$kept
      the older $part is not where this installer kept it ($prfstage/old.$part); what stands in its place was left as it is: $HOME/.lzrprf/$part"
			elif ! rm -f "$HOME/.lzrprf/$part"; then
				back=1
				kept="$kept
      the new $part could not be taken away again: $HOME/.lzrprf/$part"
			fi
		done
		# The same for the app: the new one goes back to its folder, the older one takes its name back.
		if [ ! -e "$stage/LZRBRWSR.app" ] && ! mv "$dest/LZRBRWSR.app" "$stage/LZRBRWSR.app"; then
			back=1
			kept="$kept
      the new LZRBRWSR.app could not be taken away again: $dest/LZRBRWSR.app"
		fi
		[ ! -e "$stage/old.app" ] || [ -e "$dest/LZRBRWSR.app" ] || mv "$stage/old.app" "$dest/LZRBRWSR.app" || true
	fi
	# A folder that still holds an older part that could not be put back is never removed.
	if [ -n "$stage" ] && [ -e "$stage/old.app" ]; then
		back=1
		kept="$kept
      the older LZRBRWSR.app, whole: $stage/old.app"
	elif [ -n "$stage" ]; then
		rm -rf "$stage"
	fi
	[ -z "$prfstage" ] || [ -n "$holds" ] || rm -rf "$prfstage"
	unlock
}
# gone <what failed>: undoes, then says what is true of the disk now, and stops.
gone() {
	undo
	if [ "$back" = 0 ]; then
		printf '\n  LZRBRWSR: %s Nothing was changed: what was installed before, the app and\n  lzrprf as a pair, is in place as it was.\n\n' "$1" >&2
	else
		printf '\n  LZRBRWSR: %s Not everything that was installed before could be put back.\n  Nothing older was removed. It is here:%s\n  Run this installer again: it puts an app and an lzrprf that belong together in place.\n\n' "$1" "$kept" >&2
	fi
	exit "${2:-1}"
}
# The three older lzrprf files are kept by a second name (a hard link), so their own names are never
# missing: the new file takes the name in one rename, and undoing it is one rename back.
trap 'gone "stopped while it was being put in place." 130' INT TERM HUP QUIT
{
	stage="$(mktemp -d "$dest/.LZRBRWSR.XXXXXXXX")" &&
		prfstage="$(mktemp -d "$HOME/.lzrprf/.new.XXXXXXXX")" &&
		cp "$tmp/lzrprf" "$tmp/selftest" "$tmp/blocklist" "$prfstage/" &&
		chmod 644 "$prfstage/lzrprf" "$prfstage/selftest" &&
		chmod 444 "$prfstage/blocklist" &&
		mv "$tmp/unpacked/LZRBRWSR.app" "$stage/LZRBRWSR.app" &&
		[ "$(sum "$prfstage/lzrprf")" = "$LZRPRF_SHA256" ] &&
		[ "$(sum "$prfstage/selftest")" = "$SELFTEST_SHA256" ] &&
		[ "$(sum "$prfstage/blocklist")" = "$BLOCKLIST_SHA256" ] &&
		[ "$(appsum "$stage/LZRBRWSR.app")" = "$checked" ] &&
		{ [ ! -f "$HOME/.lzrprf/lzrprf" ] || { ln "$HOME/.lzrprf/lzrprf" "$prfstage/old.lzrprf" && had_lzrprf=1; }; } &&
		{ [ ! -f "$HOME/.lzrprf/selftest" ] || { ln "$HOME/.lzrprf/selftest" "$prfstage/old.selftest" && had_selftest=1; }; } &&
		{ [ ! -f "$HOME/.lzrprf/blocklist" ] || { ln "$HOME/.lzrprf/blocklist" "$prfstage/old.blocklist" && had_blocklist=1; }; }
} || gone "the new files could not be written beside the installed ones, or were not the checked ones once written."
# The renames, back to back.
placing=1
before=
if [ -e "$dest/LZRBRWSR.app" ]; then
	before=yes
	mv "$dest/LZRBRWSR.app" "$stage/old.app" || gone "the LZRBRWSR.app that is installed could not be moved aside."
fi
mv "$stage/LZRBRWSR.app" "$dest/LZRBRWSR.app" || gone "the new LZRBRWSR.app could not be put in place."
mv -f "$prfstage/lzrprf" "$HOME/.lzrprf/lzrprf" || gone "lzrprf could not be put in place."
mv -f "$prfstage/selftest" "$HOME/.lzrprf/selftest" || gone "lzrprf's self-test could not be put in place."
mv -f "$prfstage/blocklist" "$HOME/.lzrprf/blocklist" || gone "lzrprf's list of the addresses it never opens could not be put in place."
trap '' INT TERM HUP QUIT	# all stand: what is left is removing the older ones
rm -rf "$stage" "$prfstage" || step "the older app or the older lzrprf, now replaced, could not be removed whole; what is left: $stage $prfstage"
# The curated script rules, the filter lists and what proves them (see above), each written whole under a
# new name and then renamed. lzrprf reads them with the manifest as one: if this stops between two renames,
# they no longer belong together, and lzrprf uses no curated rule and no filter list until the next install.
# The lists of the release before are taken away first, so one this release does not name is not left.
rulefiles="permit-rules release.manifest release.manifest.sig release.manifest.approval"
keep="release.manifest release.manifest.sig release.manifest.approval $filterfiles"
[ -z "$rulesum" ] || keep="permit-rules $keep"
for part in $rulefiles $filterfiles; do rm -f "$HOME/.lzrprf/$part.new"; done
for part in $(cd "$HOME/.lzrprf" && ls ubo-*.txt ubo-SOURCE filters-local.txt 2>/dev/null || true); do rm -f "$HOME/.lzrprf/$part"; done
whole=no
if [ -n "$rulesum$filterfiles" ]; then
	whole=yes
	cp "$tmp/manifest.1" "$HOME/.lzrprf/release.manifest.new" && cp "$tmp/manifest.1.sig" "$HOME/.lzrprf/release.manifest.sig.new" && cp "$tmp/manifest.1.approval" "$HOME/.lzrprf/release.manifest.approval.new" || whole=no
	[ -z "$rulesum" ] || cp "$tmp/permit-rules" "$HOME/.lzrprf/permit-rules.new" || whole=no
	for part in $filterfiles; do cp "$tmp/$part" "$HOME/.lzrprf/$part.new" || whole=no; done
	for part in $keep; do
		case "$part" in release.manifest*) ;; *) [ "$(sum "$HOME/.lzrprf/$part.new" 2>/dev/null)" = "$(named "$part")" ] || whole=no ;; esac
	done
fi
if [ "$whole" = yes ]; then
	[ -n "$rulesum" ] || rm -f "$HOME/.lzrprf/permit-rules"
	for part in $keep; do chmod 444 "$HOME/.lzrprf/$part.new" && mv -f "$HOME/.lzrprf/$part.new" "$HOME/.lzrprf/$part" || step "the curated script rules and the filter lists could not be kept whole, so lzrprf uses none of them: it asks, and filters nothing"; done
else
	[ -z "$rulesum$filterfiles" ] || step "the curated script rules and the filter lists could not be kept, so lzrprf uses none of them: it asks, and filters nothing"
	for part in $rulefiles $filterfiles; do rm -f "$HOME/.lzrprf/$part.new" "$HOME/.lzrprf/$part"; done
fi
parts_written
unlock
rm -f "$HOME/.lzrprf/rules" "$HOME/.lzrprf/refused"	# kept by an earlier lzrprf; this one keeps neither
trap - INT TERM HUP QUIT
# macOS keeps an app's icon by the time its folder last changed. Every file of the download carries
# one fixed date (the build is the same on every machine), so the Dock and the Finder went on showing
# the icon of an older release: the app is given the time of this install, and the system is told to
# read it again. Its contents stay as they were checked.
touch "$dest/LZRBRWSR.app" "$dest/LZRBRWSR.app/Contents" "$dest/LZRBRWSR.app/Contents/Info.plist" "$dest/LZRBRWSR.app/Contents/Resources" "$dest/LZRBRWSR.app/Contents/Resources/lzrbrwsr.icns" 2>/dev/null || step "the app's time could not be set, so the Dock may show the icon of the release before until you log in again"
lsr=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -n "${LZRBRWSR_DEST:-}" ] || [ ! -x "$lsr" ] || "$lsr" -f "$dest/LZRBRWSR.app" >/dev/null 2>&1 || true	# not for a folder you named (the package test installs into one): the system keeps no record of it
step "lzrprf is installed:    $HOME/.lzrprf/lzrprf"
step "LZRBRWSR is installed:  $dest/LZRBRWSR.app"
# An app in the other folder an install can be in was not touched, and can belong to another lzrprf.
for folder in "${LZRBRWSR_DEST:-/Applications}" "$HOME/Applications"; do
	[ "$folder" = "$dest" ] || [ ! -e "$folder/LZRBRWSR.app" ] || step "another LZRBRWSR.app stands in $folder and was not touched; it can belong to another lzrprf than the one installed now. Move it to the Trash and use the one above."
done
# A log an earlier release wrote. Nothing here removes it: that is for you, in the window.
if [ -s "$HOME/.lzrprf/log" ] && { [ ! -f "$HOME/.lzrprf/keep" ] || [ -L "$HOME/.lzrprf/keep" ] || ! grep -Eq '^(hosts|all) [0-9]+$' "$HOME/.lzrprf/keep"; }; then
	step "a log written earlier is still on this computer: $HOME/.lzrprf/log"
	step "this release adds nothing to it; the Log button of the window offers to clear it"
fi

# The Dock, if you say so. It is the one setting of yours this script can change,
# and only after a yes: one entry is added to the Dock's list of applications,
# and the Dock is started again so that it shows.
dock="${LZRBRWSR_DOCK:-com.apple.dock}"
case "$dest" in *[\&\<\>]*) dock="" ;; esac
if [ -n "$dock" ] && [ -z "${LZRBRWSR_UNATTENDED:-}" ]; then
	if defaults read "$dock" persistent-apps 2>/dev/null | grep -qF "$dest/LZRBRWSR.app"; then
		step "LZRBRWSR is in the Dock already"
	elif [ -n "$GIVEN" ] && [ -n "$before" ]; then
		step "the Dock is left as it is: this was an update, and whether LZRBRWSR is in the Dock is your own choice"
	elif ask "Put LZRBRWSR in the Dock?" "LZRBRWSR is put in the Dock"; then
		if defaults write "$dock" persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$dest/LZRBRWSR.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>" && { [ -n "${LZRBRWSR_DOCK:-}" ] || killall Dock; }; then
			step "LZRBRWSR is in the Dock"
		else
			step "the Dock could not be changed; drag LZRBRWSR there from Applications"
		fi
	fi
fi

cat <<DONE
$lzr_ready
  Open LZRBRWSR from Applications. It is one window. The window, its address
  bar and the words under the bar are lzrprf's: the browser has no window and
  no network. Type an address into the bar. lzrprf writes it down, fetches
  it, and only then hands the answer to the browser, in its container. What
  it wrote down is behind the Log button of the window. Unless you chose to
  keep a log, it is gone when the window closes: lzrprf keeps nothing on
  your disk unless you choose it, in Terminal and nowhere else. This says what
  is kept and how to choose:

      ${B}perl ~/.lzrprf/lzrprf keep${N}

  At its first start it asks once whether it may look for a newer release.
  It never updates itself: a newer release is offered, and then that
  release's installer runs, in front of you.

  LZRBRWSR is not signed by an Apple developer identity and not notarized,
  and that is on purpose. A signature says who made a program, not what it
  does, and the one who gives it can take it back. What vouches here is
  lzrprf: you can read it, and it just deflected, on this Mac, every hostile
  try we made ourselves to be sure. After an
  update of macOS it asks to be tested again before it starts anything.
  To have your own AI check that all of this is true, copy the prompt from
  https://github.com/lzrbrwsr/lzrprf

DONE
