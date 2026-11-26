# Website decisions and their opt-in essentials.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrdfndr.md
my @WEB_CHOICES = ('Always allow', 'Allow once', 'Always Deny', 'Deny once', 'Forget');
my @WEB_ANSWER_BY_ID = qw(deny-once allow-once always deny forget);    # The numbered answer keeps its action when the order on screen changes.
my @ESSENTIAL_WEB = (
    ['redirect', 'gmail.com', '/', 'mail.google.com', '/mail/u/0/', 'always'],
    ['redirect', 'mail.google.com', '/mail/u/0/', 'accounts.google.com', '/ServiceLogin', 'always'],
    ['redirect', 'accounts.google.com', '/ServiceLogin', 'accounts.google.com', '/v3/signin/identifier', 'always'],
    ['script', 'yle.fi', 'player-v2.yle.fi', '/embed.js', qr{\A/embed\.js\z}, 'always'],
    ['script', 'yle.fi', 'player-v2.yle.fi', '/33.<hash>.js', qr{\A/33\.[0-9a-f]{20}\.js\z}, 'always'],
    ['script', 'yle.fi', 'player-v2.yle.fi', '/761.<hash>.js', qr{\A/761\.[0-9a-f]{20}\.js\z}, 'always'],
    ['script', 'yle.fi', 'tag-manager.yle.fi', '/ylefi-production.js', qr{\A/ylefi-production\.js\z}, 'deny'],
    ['script', 'www.google.com', 'www.gstatic.com', '/og/_/js/', qr{\A/og/_/js/}, 'deny'],
);
my $HELD_ESSENTIAL_WEB;
my %ESSENTIAL_WEB_ONCE;
sub essential_web_count { scalar(keys %ESSENTIAL_WEB_ONCE) + !!$HELD_ESSENTIAL_WEB }
sub essential_web_clear { %ESSENTIAL_WEB_ONCE = (); undef $HELD_ESSENTIAL_WEB }

sub website_path {
    my ($url) = @_;
    return unless defined $url;
    my ($host, $path) = $url =~ m{\Ahttps://([^/?#:]+)(/[^?#]*)?(?:[?#].*)?\z} or return;
    return (lc $host, $path // '/');
}

sub essential_web_redirect {
    my ($from, $to) = @_;
    my ($home, $start) = website_path($from);
    my ($away, $finish) = website_path($to);
    return unless defined $home && defined $away;
    for my $index (0 .. $#ESSENTIAL_WEB) {
        my ($kind, $site, $path, $other, $target) = @{ $ESSENTIAL_WEB[$index] };
        return $index if $kind eq 'redirect' && $home eq $site && $start eq $path && $away eq $other && $finish eq $target;
    }
    return;
}

sub essential_web_script {
    my ($site, $class, $origin, $path) = @_;
    return unless $class eq 'code' && length $path;
    my ($home) = website_path($site);
    my ($host) = website_path($origin);
    return unless defined $home && defined $host;
    $home =~ s/\Awww\.yle\.fi\z/yle.fi/;
    for my $index (0 .. $#ESSENTIAL_WEB) {
        my ($kind, $owner, $source, undef, $pattern) = @{ $ESSENTIAL_WEB[$index] };
        return $index if $kind eq 'script' && $home eq $owner && $host eq $source && $path =~ $pattern;
    }
    return;
}

sub essential_web_settings {
    return $HELD_ESSENTIAL_WEB if $INCOGNITO && $HELD_ESSENTIAL_WEB;
    my $file = kept_in() . '/essential-web';
    my $off = { on => 0, choices => {}, unread => 1 };
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return -l $file || -e _ ? $off : { on => 0, choices => {} };
    my @is = stat $in;
    my $text = '';
    return $off unless @is && -f _ && $is[3] == 1 && $is[4] == $< &&
        $is[7] <= 512 && defined sysread($in, $text, 513) && $text =~ /\A([01])\n((?:[0-7] (?:always|deny|forget)\n)*)\z/;
    my ($on, $lines, %choices) = ($1, $2);
    for (split /\n/, $lines) {
        my ($id, $choice) = split / /;
        return $off if exists $choices{$id};
        $choices{$id} = $choice;
    }
    return { on => $on, choices => \%choices };
}

sub essential_web_choice {
    my ($settings, $id) = @_;
    return 'forget' unless defined $id && defined $ESSENTIAL_WEB[$id];
    return $ESSENTIAL_WEB_ONCE{$id} // $settings->{choices}{$id} // $ESSENTIAL_WEB[$id][-1];
}

sub essential_web_told {
    my $settings = essential_web_settings();
    my @rows;
    for my $id (0 .. $#ESSENTIAL_WEB) {
        my ($kind, $site, $a, $b, $c) = @{ $ESSENTIAL_WEB[$id] };
        my ($from, $to) = $kind eq 'script' ? ("$a$b", '') : ("$site$a", "$b$c");
        push @rows, 'essential row ' . join("\t", $id, $kind, $site, $from, $to, essential_web_choice($settings, $id));
    }
    window("essential begin " . $settings->{on}, @rows, 'essential end');
}

sub essential_web_save {
    my ($on, @change) = @_;
    my $lock = $INCOGNITO ? 1 : keep_lock();
    return unless $lock;
    my $settings = essential_web_settings();
    return if $settings->{unread};
    my %keep = %{ $settings->{choices} };
    my %once = %ESSENTIAL_WEB_ONCE;
    my %seen;
    for my $change (@change) {
        my ($id, $choice) = $change =~ /\A([0-9])=(always|deny|allow-once|deny-once|forget)\z/ or return;
        return if !defined $ESSENTIAL_WEB[$id] || $seen{$id}++;
        delete $once{$id};
        if ($choice eq 'allow-once' || $choice eq 'deny-once') {
            $once{$id} = $choice;
            $keep{$id} = 'forget';
        } else {
            $keep{$id} = $choice;
        }
    }
    if ($INCOGNITO) {
        $HELD_ESSENTIAL_WEB = { on => $on, choices => \%keep };
    } else {
        my $file = "$DIR/essential-web";
        unlink "$file.new";
        unless (put("$file.new", O_EXCL, $on, map { "$_ $keep{$_}" } sort keys %keep) && rename("$file.new", $file)) {
            unlink "$file.new";
            return;
        }
        synced();
    }
    %ESSENTIAL_WEB_ONCE = %once;
    return 1;
}

sub essential_web_site {
    my ($site) = @_;
    return 0 unless $site eq 'https://yle.fi' || $site eq 'https://www.yle.fi' || $site eq 'https://www.google.com';
    return essential_web_settings()->{on};
}

sub essential_web_answer {
    my ($id, $take) = @_;
    return 'forget' unless defined $id;
    my $settings = essential_web_settings();
    return 'forget' unless $settings->{on};
    my $choice = essential_web_choice($settings, $id);
    delete $ESSENTIAL_WEB_ONCE{$id} if $take;
    return $choice;
}

# A redirect or send that holds one request. The same numbered answer path is used by the window.
sub web_question {
    my ($kind, $words, $id, $can_allow, $bookmark) = @_;
    my $saved = sub {
        my $choice = essential_web_answer($id, 0);
        if ($choice eq 'deny' || $choice eq 'deny-once') { essential_web_answer($id, 1); return 1 }
        if ($can_allow && ($choice eq 'always' || $choice eq 'allow-once')) { essential_web_answer($id, 1); return 2 }
        return;
    };
    return asked(join("\t", "webquestion $kind", unlisted($words), defined $id ? $id : '-', $can_allow ? 1 : 0),
        $saved, @WEB_CHOICES, ($bookmark ? 'Proceed and update bookmark' : ()));
}

# Selftest appends this to the actual matcher source in its own contained copy.
sub essential_test_text {
    return <<'END';
my @redirects = (
    ['https://gmail.com/', 'https://mail.google.com/mail/u/0/'],
    ['https://mail.google.com/mail/u/0/', 'https://accounts.google.com/ServiceLogin?new=1'],
    ['https://accounts.google.com/ServiceLogin?osid=1', 'https://accounts.google.com/v3/signin/identifier?dsh=rotated'],
    ['https://gmail.com/inbox', 'https://mail.google.com/mail/u/0/'],
    ['https://gmail.com/', 'https://mail.google.com.evil.test/mail/u/0/'],
);
my $hash = 'a' x 20;
my @scripts = (
    ['yle.fi', 'code', 'player-v2.yle.fi', '/embed.js'],
    ['www.yle.fi', 'code', 'player-v2.yle.fi', "/33.$hash.js"],
    ['yle.fi', 'code', 'player-v2.yle.fi', "/761.$hash.js"],
    ['yle.fi', 'code', 'tag-manager.yle.fi', '/ylefi-production.js'],
    ['www.google.com', 'code', 'www.gstatic.com', '/og/_/js/k=og.asy.x'],
    ['yle.fi', 'code', 'player-v2.yle.fi', "/762.$hash.js"],
    ['evil.test', 'code', 'player-v2.yle.fi', '/embed.js'],
    ['yle.fi', 'strings', 'player-v2.yle.fi', '/embed.js'],
);
print join(',', map { essential_web_redirect(@$_) // '-' } @redirects), "\n";
print join(',', map {
    my ($site, $class, $host, $path) = @$_;
    essential_web_script("https://$site", $class, "https://$host", $path) // '-'
} @scripts), "\n";
END
}
