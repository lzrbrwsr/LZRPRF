# Profiles. A profile is a browser of its own inside this one, for one person or one part of a
# life: its own bookmarks and their bar, home page, search address, log and what is kept of it,
# and Tor's folder, on the disk; its own history, closed tabs and zoom, in the memory of its
# window's process. The first profile is the state folder itself, ~/.lzrprf, as it always was:
# nothing is moved, and an installed browser sees no change, and gets no new file, until a second
# profile is made or the first is renamed. Every other profile is a folder of its own,
# ~/.lzrprf/profiles/ID, readable by you alone (mode 700), ID being 12 hex digits lzrprf drew from
# /dev/urandom and never anything typed. A profile's name is the one plain file "name" in its
# folder; the first profile's, once you gave it one, is the file profiles/first. What belongs to
# the installation and to no profile stays in the state folder and is the same for every profile:
# the self-test's result, the look for a newer release and its answer, an installer and its lines,
# the welcome, the licence code, the support request kept, and the jobs the application's tool
# switched off. A profile's window is a process of its own, started as a pulled tab's window is
# (sub profile_window): the id is its one word of a profile on a command line, since every user
# of the computer can read the list of processes, and the name never is. It holds a shared lock on
# the file "inuse" in its folder for as long as it lives (sub profile_held), and a profile is
# removed only while nobody holds it; a window of the first profile does the same in the state
# folder, once there are profiles. One window at a time counts, makes, renames or removes
# profiles, under a lock on the folder of the profiles (sub profiles_locked). An incognito window
# opened from a profile's window reads that profile's settings, by its id on its command line,
# and writes nothing there; it is told no profile, and lzrprf refuses every word of a profile from
# it. A profile's name is shown in the strip and kept in the memory of the window that said it,
# and written in no file but its own "name": no file on the disk names another profile.
#
# The window's words, each checked here as the words of a hostile window are: "profile list";
# "profile open ID", a window of that profile; "profile new<TAB>NAME", a profile made and opened;
# "profile rename<TAB>ID<TAB>NAME"; "profile remove ID", asked once and then removed. ID is
# "first" or 12 hex digits, and only the id of a profile lzrprf finds in its folder names a folder;
# a name is at most $PROFILE_NAME characters of plain text. lzrprf answers with "profiles begin",
# a line "profiles one ID this|open|shut NAME" for each profile, the first one first and the others
# by name, and "profiles end"; and with "profiles refused WORDS" when it did not do what was asked.
my $FIRST_NAME = 'First profile';         # the first profile's name until you give it one
my $INUSE;                                # in a profile's window, the shared lock on its file "inuse": held while the window lives

sub profiles_root { "$ROOT/profiles" }
sub profiles_folder {                     # the folder of the profiles when it is a folder of yours and no link; nothing when it is not there or is something else
    my @is = lstat profiles_root();
    return @is && -d _ && $is[4] == $< ? profiles_root() : undef;
}

sub profile_folder {                      # the folder of a profile lzrprf knows, by its id; nothing for any other word, so no word of the window names a folder outside
    my ($id) = @_;
    $id //= '';
    return $ROOT if $id eq 'first';
    return unless $id =~ /\A[0-9a-f]{12}\z/;
    my $all = profiles_folder() // return;
    my @is = lstat "$all/$id";
    return @is && -d _ && $is[4] == $< ? "$all/$id" : undef;
}

sub profile_ids {                         # the ids of the profiles there are, the first one first
    my $all = profiles_folder();
    my @ids;
    if ($all && opendir my $in, $all) { @ids = sort grep { /\A[0-9a-f]{12}\z/ && profile_folder($_) } readdir $in }
    return ('first', @ids);
}

sub profile_fit {                         # a name as it was typed: its bytes as they are kept, or nothing and why in plain words
    my ($typed) = @_;
    my $name = $typed // '';
    return (undef, 'A profile name is plain text, and that was not.') unless utf8::decode($name);
    return (undef, 'A profile name holds no control or format character.') if $name =~ /[\p{C}\p{Zl}\p{Zp}]/;
    $name =~ s/\s+/ /g;
    $name =~ s/\A | \z//g;
    return (undef, 'Type a name for the profile first.') unless length $name;
    return (undef, "A profile name is at most $PROFILE_NAME characters. That one has " . length($name) . '.') if length $name > $PROFILE_NAME;
    utf8::encode($name);
    return ($name);
}

sub profile_name {                        # a profile's name, as kept; one that is not there, or not a name lzrprf takes, reads as a name made from its id
    my ($id) = @_;
    my ($all, $bytes) = (profiles_folder(), '');
    if ($all && sysopen my $in, $id eq 'first' ? "$all/first" : "$all/$id/name", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) { sysread $in, $bytes, 400 if -f $in }    # a plain file and no link; a pipe put in its place is not waited for
    my ($name) = profile_fit($bytes =~ s/\n.*//sr);
    return $name // ($id eq 'first' ? $FIRST_NAME : "Profile $id");
}

sub profile_open {                        # true while a window of the profile in this folder is open: that window holds the lock on its file "inuse"
    my ($folder) = @_;
    sysopen(my $lock, "$folder/inuse", O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return 0;
    return !flock $lock, LOCK_EX | LOCK_NB;    # the lock, taken now, ends with the handle
}

sub profiles_told {                       # the list, for the Profiles icon: nothing in an incognito window
    return if $INCOGNITO;
    first_held();                         # the list names the profiles, so from here on this window is listed as open in the others too
    my ($first, @others) = profile_ids();
    my %name = map { $_ => profile_name($_) } $first, @others;
    @others = sort { lc $name{$a} cmp lc $name{$b} || $a cmp $b } @others;
    window('profiles begin', (map { "profiles one $_ " . (($PROFILE // 'first') eq $_ ? 'this' : profile_open(profile_folder($_)) ? 'open' : 'shut') . " $name{$_}" } $first, @others), 'profiles end');
}

sub profiles_refused { my ($says) = @_; window("profiles refused $says"); return alert($says) }

sub profiles_locked {                     # one window at a time counts, makes, renames or removes profiles: an exclusive lock on the folder of the profiles, held while the handle lives
    my $all = profiles_folder() // return;
    sysopen(my $lock, $all, O_RDONLY | O_NOFOLLOW) or return;
    flock($lock, LOCK_EX) or return;      # each holder only reads names and makes, renames or removes one folder, so the wait is short
    return $lock;
}

sub profiles_swept {                      # what a removal that failed part way left: only names of exactly the form ".removed.ID.PID", of a process that is gone; a link is removed itself, never followed. Under profiles_locked
    my $all = profiles_folder() // return;
    opendir(my $in, $all) or return;
    for my $left (grep { /\A\.removed\.[0-9a-f]{12}\.(\d+)\z/ && ($1 == $$ || !kill 0, $1) } readdir $in) {
        my @is = lstat "$all/$left";
        if (-l _) { unlink "$all/$left" }
        elsif (@is && -d _ && $is[4] == $<) { remove_tree("$all/$left", { safe => 0 }) }
    }
}

sub profile_taken {                       # a profile name another profile has already, capitals aside; nothing when none has
    my ($name, $but) = @_;
    return scalar grep { $_ ne ($but // '') && lc profile_name($_) eq lc $name } profile_ids();
}

sub profile_entered {                     # a profile's window, at its start: the profile named is one lzrprf knows, and its folder is this window's folder from here on; anything else ends the start here
    my $folder = ($PROFILE // '') =~ /\A[0-9a-f]{12}\z/ ? profile_folder($PROFILE) : undef;
    die "lzrprf: there is no such profile: it may have been removed. Open another from the Profiles icon of a window.\n" unless $folder;
    $DIR = $folder;
    return if $INCOGNITO;                 # an incognito window reads that folder and changes nothing in it [C16]
    chmod 0700, $folder;
    runs_swept($DIR);
}

sub profile_held {                        # behind a profile's window: the shared lock on its file "inuse", taken for as long as this process lives; false when the profile was removed meanwhile
    return 1 if $INCOGNITO;               # it writes nothing there, so it holds no lock there either: it does not count as an open window of the profile
    return 1 if !defined $PROFILE && !profiles_folder();    # the first profile takes the lock only once there are profiles, so an installation with one gets no new file
    sysopen($INUSE, "$DIR/inuse", O_RDWR | O_CREAT | O_NOFOLLOW, 0600) or return 0;
    flock $INUSE, LOCK_SH or return 0;    # waits while a removal holds it
    return (stat $INUSE)[3] && -f _;      # its name is still there: the profile was not removed while the lock was waited for
}

sub first_held { profile_held() unless defined $PROFILE || $INUSE || $INCOGNITO }    # the first profile's window, once it knows there are profiles: its lock, taken once. A window opened before the folder of the profiles was made takes it here, when its list is told or a profile word reaches it

sub profile_command { my ($id) = @_; return ('/usr/bin/perl', $SELF, 'run', $id eq 'first' ? () : ('--profile', $id), $PROGRAM, @ARGUMENTS) }    # a profile's window: its id, and nothing typed

sub profile_window {                      # a new window of a profile lzrprf knows, by its id alone, started as a pulled tab's window is, with no address
    my ($id) = @_;
    return profiles_refused('An incognito window has no profile, and opens none.') if $INCOGNITO;
    first_held();
    profile_folder($id) or return profiles_refused('That is not a profile lzrprf knows. No window was opened.');
    return profiles_refused("No window was opened: this window has opened $PULLED_MOST windows from its tabs and profiles, the most one window may. Open it from another window.") if $PULLED >= $PULLED_MOST;
    return profiles_refused('No window was opened: lzrprf could not start a process for it.') unless $TRY || apart(undef, profile_command($id));
    $PULLED++;
    return idle($TRY ? 'A profile\'s window was asked for: "lzrprf try" starts none.' : 'The profile ' . profile_name($id) . ' opens in a new window.');
}

sub profile_new {                         # "profile new<TAB>NAME": a profile made, with a folder of its own, and opened in a new window
    my ($typed) = @_;
    return profiles_refused("$UNKEPT, so it makes no profile.") if $INCOGNITO;
    my ($name, $why) = profile_fit($typed);
    return profiles_refused($why) unless defined $name;
    my $most = "There are $PROFILES_MOST profiles, the most there may be. Remove one to make another.";
    my $taken = "There is a profile called $name already. Choose another name.";
    return profiles_refused($most) if (() = profile_ids()) >= $PROFILES_MOST;    # said before anything is made: a refused name makes no folder of profiles
    return profiles_refused($taken) if profile_taken($name);
    mkdir profiles_root(), 0700 unless -e profiles_root() || -l profiles_root();
    my $all = profiles_folder() // return profiles_refused('No profile was made: ' . profiles_root() . ' is not a folder of yours.');
    chmod 0700, $all;
    my $lock = profiles_locked() // return profiles_refused('No profile was made: the folder of the profiles could not be locked.');
    profiles_swept();
    return profiles_refused($most) if (() = profile_ids()) >= $PROFILES_MOST;    # counted again under the lock: another window may have made one meanwhile
    return profiles_refused($taken) if profile_taken($name);
    first_held();    # the first profile's window takes its lock now that there are profiles, so it is listed as open
    my $id;
    for (1 .. 8) {
        open my $random, '<:raw', '/dev/urandom' or last;
        read($random, my $bytes, 6) == 6 or last;
        my $try = unpack 'H*', $bytes;
        if (mkdir "$all/$try", 0700) { $id = $try; last }
    }
    return profiles_refused('No profile was made: its folder could not be made.') unless defined $id;
    unless (put("$all/$id/name", O_EXCL, $name)) { remove_tree("$all/$id", { safe => 0 }); return profiles_refused('No profile was made: its name could not be written.') }
    synced($all);
    undef $lock;
    noted('you made a profile');          # in this window's memory alone. A profile's name is shown in this window's strip and kept in its memory (the lines its Log button shows), never written to any file but its own "name" and never shown to a page: no file on the disk names another profile
    profiles_told();
    return profile_window($id);
}

sub profile_renamed {                     # "profile rename<TAB>ID<TAB>NAME"
    my ($id, $typed) = @_;
    return profiles_refused("$UNKEPT, so it renames no profile.") if $INCOGNITO;
    profile_folder($id) or return profiles_refused('That is not a profile lzrprf knows. Nothing was renamed.');
    my ($name, $why) = profile_fit($typed);
    return profiles_refused($why) unless defined $name;
    my $taken = "There is a profile called $name already. Choose another name.";
    return profiles_refused($taken) if profile_taken($name, $id);
    mkdir profiles_root(), 0700 unless -e profiles_root() || -l profiles_root();    # the first profile's name is the one thing of it kept there
    my $all = profiles_folder() // return profiles_refused('Nothing was renamed: ' . profiles_root() . ' is not a folder of yours.');
    my $lock = profiles_locked() // return profiles_refused('Nothing was renamed: the folder of the profiles could not be locked.');
    return profiles_refused($taken) if profile_taken($name, $id);    # again under the lock
    profile_folder($id) or return profiles_refused('That is not a profile lzrprf knows. Nothing was renamed.');
    my $was = profile_name($id);
    first_held();
    my $file = $id eq 'first' ? "$all/first" : "$all/$id/name";
    unlink "$file.new";
    return profiles_refused('Nothing was renamed: the name could not be written.') unless put("$file.new", O_EXCL, $name) && rename("$file.new", $file);
    synced($id eq 'first' ? $all : "$all/$id");
    undef $lock;
    noted('you renamed a profile');       # the names, old and new, in this window's strip and memory alone (sub profile_new)
    profiles_told();
    return idle("The profile $was is now called $name.");
}

sub profile_removed {                     # "profile remove ID": asked once, then the profile's folder and nothing else is deleted
    my ($id) = @_;
    return profiles_refused("$UNKEPT, so it removes no profile.") if $INCOGNITO;
    first_held();
    return profiles_refused('The first profile is never removed: its folder is the state folder itself, which also holds what belongs to the whole installation.') if $id eq 'first';
    my $folder = profile_folder($id) // return profiles_refused('That is not a profile lzrprf knows. Nothing was removed.');
    my $name = profile_name($id);
    return profiles_refused("The profile $name is this window's own. Remove it from a window of another profile, once this one is closed.") if ($PROFILE // '') eq $id;
    my $open = "The profile $name has a window open. Close its windows first, then remove it.";
    return profiles_refused($open) if profile_open($folder);
    return idle("The profile $name was not removed.") unless ask("Remove the profile $name? Its bookmarks, history, log, home page, search address and all that is kept for it are deleted from this Mac. This cannot be undone.", 'Cancel', 'Remove') == 2;
    my $all = profiles_locked() // return profiles_refused("The profile $name was not removed: the folder of the profiles could not be locked. Nothing was deleted.");
    $folder = profile_folder($id) // return profiles_refused('That is not a profile lzrprf knows. Nothing was removed.');    # looked at again under the lock: the question can stand open for minutes
    my $lock;                             # held while it is removed: no window of it starts meanwhile
    sysopen($lock, "$folder/inuse", O_RDWR | O_CREAT | O_NOFOLLOW, 0600) && flock($lock, LOCK_EX | LOCK_NB) or return profiles_refused($open);
    my $gone = profiles_root() . "/.removed.$id.$$";    # out of the list in one step; a name no profile can have
    return profiles_refused("The profile $name was not removed: its folder could not be moved aside. Nothing was deleted.") unless rename $folder, $gone;
    remove_tree($gone, { safe => 0 });    # a link inside is removed, never followed
    profiles_swept();                     # and what an earlier removal could not finish
    synced(profiles_root());
    undef $all;
    noted('you removed a profile');
    profiles_told();
    return idle(-e $gone ? "The profile $name was taken off the list, but part of its folder could not be deleted: $gone" : "The profile $name was removed, and its folder with it.");
}


# Connected sign-ins ("Connect seamless SSO accounts" in the Profiles list), the owner's order of
# 2026-11-22. A profile may keep a lasting sign-in with Google, Apple and Meta, as other browsers
# do, so that once you signed in to one site of a provider its other sites know you too. lzrprf has
# no sign-in of its own and is no client of any provider: Connect opens the provider's own sign-in
# page in a new tab of this window, and you sign in there as on any page. From that press until
# the window ends, the answers of that provider's own family of hosts (google.com, youtube.com and
# gmail.com for Google, and so on: %SSO_PROVIDERS) may set cookies, held in this window's memory
# only; the moment one of the provider's session cookies is among them, looked at by its name and
# never by its value, the profile is connected and they are written to one file of that profile,
# sso/PROVIDER, mode 600, readable by you alone. From then on each request to a host of that
# family carries that family's cookies, as the cookie rules of RFC 6265 match them by host and
# path, when it is the request of a page you visit, or a request of a page kept running whose own
# host is of the same family; a page of any other site never makes them go, and its requests to
# those hosts carry none. A redirect from a host of the family to another host of the same family
# is followed without a question, written in the log first, at most $SSO_HOPS a visit; a redirect
# out of the family is asked about as every other is. A cookie whose Domain names a host outside
# the family is not kept. What is kept is cleared by Remove and by nothing else: no clearing of
# history, sessions or the log touches it; Remove deletes the file, which is all lzrprf keeps of
# that provider (it keeps no other storage of any site). An incognito window and Tor neither read
# nor write it, and send no cookie at all. The cookie line goes to curl on its input, never on a
# command line every user can read, and no value is written in the log, told to the window or
# handed to the application.
my %SSO_PROVIDERS = (                    # DECLARED: key => [the name shown, the provider's own sign-in page, its family of hosts, the names of its session cookies]
    google => ['Google', 'https://accounts.google.com/ServiceLogin', [qw(google.com youtube.com gmail.com)], [qw(SID __Secure-1PSID __Secure-3PSID)]],
    apple => ['Apple', 'https://appleid.apple.com/sign-in', [qw(apple.com icloud.com)], [qw(myacinfo)]],
    meta => ['Meta', 'https://www.facebook.com/login/', [qw(facebook.com messenger.com instagram.com)], [qw(c_user xs)]],
);
my $SSO_HOPS = 8;                         # DECLARED: redirects within one provider's family followed without a question in one visit
my $SSO_COOKIES = 200;                    # DECLARED: cookies kept for one provider at most
my $SSO_VALUE = 4096;                     # DECLARED: the longest cookie (name and value) kept
my (%SSO_PENDING, %SSO_HELD);             # the providers you pressed Connect for in this window, and the cookies held for each in its memory until it is connected
sub sso_providers {                       # "lzrprf try" only: a file "ssoproviders" in the test's folder names stand-in providers in place of these, one a line: key, name, sign-in page, hosts and session cookies (each list split by commas)
    return \%SSO_PROVIDERS unless $TRY && open my $in, '<', "$ROOT/ssoproviders";
    my %stand_in;
    while (my $line = <$in>) { chomp $line; my ($key, $name, $page, $hosts, $names) = split /\t/, $line; $stand_in{$key} = [$name, $page, [split /,/, $hosts], [split /,/, $names]] if defined $names && $key =~ /\A[a-z]{1,16}\z/ }
    return \%stand_in;
}
sub sso_on { !$INCOGNITO && !$TOR_WANTED && !$TOR }    # [C16] [C17] no cookie is read, kept or sent in an incognito window or through Tor
sub sso_of {                              # the provider whose family holds this host, or nothing
    my ($host) = @_;
    return unless defined $host;
    my $all = sso_providers();
    for my $key (sort keys %$all) { return $key if grep { $host eq $_ || substr($host, -length(".$_")) eq ".$_" } @{ $all->{$key}[2] } }
    return;
}
sub sso_file { "$DIR/sso/$_[0]" }
sub sso_kept {                            # the cookies kept for a connected provider, or nothing when it is not connected
    my ($key) = @_;
    sysopen(my $in, sso_file($key), O_RDONLY | O_NOFOLLOW) or return;
    my $first = <$in> // '';
    return unless $first eq "connected\n";
    my @cookies;
    while (my $line = <$in>) {
        chomp $line;
        my %one;
        @one{qw(name value domain host path expires)} = split /\t/, $line;
        push @cookies, \%one if defined $one{expires} && @cookies < $SSO_COOKIES;
    }
    return \@cookies;
}
sub sso_state { my ($key) = @_; return sso_kept($key) ? 'connected' : $SSO_PENDING{$key} ? 'connecting' : 'none' }
sub sso_cookies {                         # the cookies this request may carry, by provider: kept, or held while connecting
    my ($key) = @_;
    return sso_kept($key) // ($SSO_PENDING{$key} ? $SSO_HELD{$key} //= [] : undef);
}
sub sso_cookie {                          # the line Cookie a request to this address carries: only to a host of a provider you connected or are connecting, and only for the request of a page you visit ($from undef) or of a page of the same family
    my ($url, $from) = @_;
    return unless sso_on();
    my ($host, $path) = $url =~ m{\Ahttps://([^/:]+)(/[^?#]*)?} or return;
    my $key = sso_of($host) // return;
    return if defined $from && (sso_of($from) // '') ne $key;    # a page of another site never makes them go
    my $cookies = sso_cookies($key) // return;
    my $now = time;
    $path //= '/';
    my @sent = grep { ($_->{host} ? $host eq $_->{domain} : $host eq $_->{domain} || substr($host, -length(".$_->{domain}")) eq ".$_->{domain}") && ($path eq $_->{path} || index($path, $_->{path} =~ m{/\z} ? $_->{path} : "$_->{path}/") == 0) && (!$_->{expires} || $_->{expires} > $now) } @$cookies;
    return @sent ? 'Cookie: ' . join('; ', map { "$_->{name}=$_->{value}" } @sent) : undef;
}
sub sso_heard {                           # an answer of a host of a provider you connected or are connecting: its Set-Cookie lines kept, its session cookie looked for by name; returns the provider's name when this answer connected it
    my ($url, $got, $from) = @_;
    return unless sso_on() && defined $got;
    my ($host) = $url =~ m{\Ahttps://([^/:]+)} or return;
    my $key = sso_of($host) // return;
    return if defined $from && (sso_of($from) // '') ne $key;
    my $was = sso_state($key);
    return if $was eq 'none';
    my ($head) = $got =~ /\A(.*?)\r\n\r\n/s or return;
    my @set = $head =~ /^set-cookie:[ \t]*([^\r\n]*)/mgi or return;
    my $all = sso_providers();
    my $cookies = [@{ sso_cookies($key) }];
    my $now = time;
    for my $line (@set) {
        my ($pair, @attributes) = split /;[ \t]*/, $line;
        my ($name, $value) = ($pair // '') =~ /\A[ \t]*([!#\$%&'*+.^_|~0-9A-Za-z\x60-]{1,256})=([\x21-\x2b\x2d-\x3a\x3c-\x7e]*)[ \t]*\z/ or next;    # a token and a value of plain characters with no comma or semicolon; a cookie of any other form is not kept
        next if length($name) + length($value) > $SSO_VALUE;
        my %one = (name => $name, value => $value, domain => $host, host => 1, path => '/', expires => 0);
        my $gone = 0;
        for (@attributes) {
            my ($a, $v) = /\A([A-Za-z-]+)(?:=(.*))?\z/ or next;
            $a = lc $a;
            $v //= '';
            if ($a eq 'domain') { ($one{domain} = lc $v) =~ s/\A\.//; $one{host} = 0 }
            elsif ($a eq 'path' && $v =~ m{\A/[\x21-\x3a\x3c-\x7e]*\z}) { $one{path} = $v }
            elsif ($a eq 'max-age' && $v =~ /\A-?[0-9]{1,10}\z/) { $one{expires} = $now + $v; $gone = 1 if $v <= 0 }
            elsif ($a eq 'expires' && !grep { $_ eq 'max-age' } map { lc((split /=/)[0]) } @attributes) { my $at = sso_date($v); if (defined $at) { $one{expires} = $at; $gone = 1 if $at <= $now } }
        }
        next unless $host eq $one{domain} || substr($host, -length(".$one{domain}")) eq ".$one{domain}";    # a cookie for another host than the one that set it, or a host above it, is not kept
        next unless (sso_of($one{domain}) // '') eq $key && $one{domain} =~ /\./;    # nor one whose Domain is outside the family, or a whole top-level domain
        @$cookies = grep { !($_->{name} eq $name && $_->{domain} eq $one{domain} && $_->{path} eq $one{path}) } @$cookies;
        push @$cookies, \%one unless $gone;
    }
    @$cookies = grep { !$_->{expires} || $_->{expires} > $now } @$cookies;
    splice @$cookies, 0, @$cookies - $SSO_COOKIES if @$cookies > $SSO_COOKIES;
    my %session = map { $_ => 1 } @{ $all->{$key}[3] };
    if ($was eq 'connecting') {
        $SSO_HELD{$key} = $cookies;
        return unless grep { $session{ $_->{name} } } @$cookies;    # not yet signed in: held in memory, written nowhere
    }
    return unless sso_written($key, $cookies);
    return if $was eq 'connected';
    delete $SSO_PENDING{$key}; delete $SSO_HELD{$key};
    noted("you connected $all->{$key}[0] in this profile");
    sso_told();
    return $all->{$key}[0];
}
sub sso_date {                            # the time an Expires names (RFC 6265 5.1.1, the common forms), or nothing
    my ($text) = @_;
    my %month = (jan => 0, feb => 1, mar => 2, apr => 3, may => 4, jun => 5, jul => 6, aug => 7, sep => 8, oct => 9, nov => 10, dec => 11);
    my ($d, $m, $y, $hh, $mm, $ss) = $text =~ /([0-9]{1,2})[ -]([A-Za-z]{3})[a-z]*[ -]([0-9]{2,4}) ([0-9]{1,2}):([0-9]{2}):([0-9]{2})/ or return;
    $m = $month{ lc $m } // return;
    $y += $y < 70 ? 2000 : 1900 if $y < 100;
    require Time::Local; return eval { Time::Local::timegm($ss, $mm, $hh, $d, $m, $y) };
}
sub sso_written {                         # a provider's cookies into its one file, through to the disk, under a lock against another window of the profile
    my ($key, $cookies) = @_;
    mkdir "$DIR/sso", 0700;
    return 0 if -l "$DIR/sso" || !-d _;
    my $new = sso_file($key) . ".new.$$";
    unlink $new;
    put($new, O_EXCL, 'connected', map { join "\t", @$_{qw(name value domain host path expires)} } @$cookies) or (unlink($new), return 0);
    rename($new, sso_file($key)) or (unlink($new), return 0);
    synced("$DIR/sso");
    return 1;
}
sub sso_told {                            # "sso begin", a line "sso one KEY connected|connecting|none NAME" for each provider, "sso end"; in an incognito window or with Tor on, "sso off WHY"
    return window('sso off ' . ($INCOGNITO ? 'An incognito window keeps no sign-in, and connects none.' : 'With Tor on, no sign-in is sent or kept. Turn Tor off to connect or use one.')) unless sso_on();
    my $all = sso_providers();
    return window('sso begin', (map { "sso one $_ " . sso_state($_) . " $all->{$_}[0]" } sort { $all->{$a}[0] cmp $all->{$b}[0] } keys %$all), 'sso end');
}
sub sso_connect {                         # "sso connect KEY": the provider's own sign-in page in a new tab of this window; connected once its session cookie appears
    my ($key) = @_;
    my $all = sso_providers();
    return idle('That is not a provider lzrprf knows. Nothing was changed.') unless $all->{$key};
    do { sso_told(); return idle($INCOGNITO ? "$UNKEPT, so it connects no sign-in." : 'With Tor on, no sign-in is kept: turn Tor off to connect one.') } unless sso_on();
    return idle("$all->{$key}[0] is already connected in this profile.") if sso_kept($key);
    return idle("A window holds $TABS_MOST tabs at most: close one to connect $all->{$key}[0].") if @TABS >= $TABS_MOST;
    $SSO_PENDING{$key} = 1;
    sso_told();
    $TABS[$TAB]{shown} = $SHOWN;
    push @TABS, fresh_tab();
    $TAB = $#TABS;
    undef $SHOWN;
    noted("you pressed Connect for $all->{$key}[0]: its own sign-in page opens in a new tab");
    tab_shown("Sign in to $all->{$key}[0] on its own page. This profile is connected the moment $all->{$key}[0] says you are signed in.");
    go($all->{$key}[1], "you pressed Connect for $all->{$key}[0], which opens");    # [C4] the provider's own fixed sign-in page
}
sub sso_remove {                          # "sso remove KEY": asked once, then that provider's cookies are deleted from this profile, which signs you out of its sites here
    my ($key) = @_;
    my $all = sso_providers();
    return idle('That is not a provider lzrprf knows. Nothing was changed.') unless $all->{$key};
    my $name = $all->{$key}[0];
    if (!-e sso_file($key) && !-l sso_file($key)) { delete $SSO_PENDING{$key}; delete $SSO_HELD{$key}; sso_told(); return idle("$name is not connected in this profile.") }
    return idle("$name was not removed.") unless ask("Remove $name from this profile? Its sign-in is deleted from this Mac, and the sites of $name see you signed out in this profile.", 'Cancel', 'Remove') == 2;
    unlink sso_file($key);
    delete $SSO_PENDING{$key}; delete $SSO_HELD{$key};
    synced("$DIR/sso");
    noted("you removed $name from this profile");
    sso_told();
    return idle(-e sso_file($key) || -l sso_file($key) ? "$name could not be removed: its file could not be deleted." : "$name was removed from this profile: its sign-in is deleted, and you are signed out of its sites here.");
}
