# [C32] Kept apps have a broker-issued record. An address typed in an ordinary tab never gets one.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrcht-discord-web.md
my @KEPT_APPS = ({
    name => 'discord',
    start => 'https://discord.com/app',
    hosts => { map { $_ => 1 } qw(discord.com gateway.discord.gg cdn.discordapp.com media.discordapp.net discord.gg) },
    socket_host => 'gateway.discord.gg',
    seconds => 86_400, requests => 120, bytes => 8 * 1024 * 1024, sockets => 2,
});

sub kept_app_discord {
    return if $INCOGNITO || $TOR_WANTED || $TOR_WINDOW || $TOR_SESSION;
    my ($spec) = @KEPT_APPS;
    my $folder = kept_app_folder($spec->{name}) or return;
    my $at = now();
    return { spec => $spec, folder => $folder, until => $at + $spec->{seconds}, minute => int($at / 60), requests => 0, bytes => 0, sockets => {} };
}

sub kept_app_valid {
    my ($app, $url) = @_;
    return if $INCOGNITO || $TOR_WANTED || $TOR_WINDOW || $TOR_SESSION;
    return unless $app->{spec} == $KEPT_APPS[0] && now() < $app->{until};
    my ($fit, $host) = address($url);
    return $fit && $app->{spec}{hosts}{$host};
}

sub kept_app_budget {
    my ($app, $requests, $bytes) = @_;
    my $at = now();
    return if $at >= $app->{until};
    my $minute = int($at / 60);
    if ($app->{minute} != $minute) { @$app{qw(minute requests bytes)} = ($minute, 0, 0) }
    return if $app->{requests} + $requests > $app->{spec}{requests} || $app->{bytes} + $bytes > $app->{spec}{bytes};
    $app->{requests} += $requests;
    $app->{bytes} += $bytes;
    return 1;
}


sub kept_app_folder {
    my ($name) = @_;
    return unless $name =~ /\A[a-z]{1,16}\z/;
    my $path = $ROOT;
    for my $part ('cht', 'web', $name) {
        $path .= "/$part";
        mkdir $path, 0700;
        my @info = lstat $path;
        return unless @info && -d _ && $info[4] == $< && !($info[2] & 077);
    }
    return $path;
}

# Switch only the jar's state and files. The app never borrows the profile jar,
# its SSO provider store or the default directory.
sub kept_app_jar {
    my ($app, $work) = @_;
    local $JAR_FOLDER = $app->{folder};
    local ($JAR, $JAR_STARTS, $JAR_SAVED) = @{ $app->{jar} // [undef, 0, 0] };
    my $result = $work->();
    $app->{jar} = [$JAR, $JAR_STARTS, $JAR_SAVED];
    return $result;
}

# The kept application has a separate network route. Every request still passes
# the blocklist, content shield, checked address broker and TLS verification.
sub kept_app_fetched {
    my ($live, $line, $body) = @_;
    my $app = $live->{kept_app};
    my ($method, $size, $type, $dest, $to) = $line =~ m{\A=fetch (GET|HEAD|POST|PUT|PATCH|DELETE) (0|[1-9][0-9]{0,5}) (-|text/plain|application/x-www-form-urlencoded|application/json) (?:(data|script|module|worker|frame|image) )?([\x21-\x7e]{1,8192})\z};
    return live_replied($live, 403, '', '') unless $method && $size == length($body)
        && ($method !~ /\A(?:GET|HEAD)\z/ || !$size && $type eq '-')
        && !$INCOGNITO && !$TOR_WANTED && !$TOR_WINDOW && !$TOR_SESSION;
    my (undef, $status, undef, undef, $parts) = kept_app_response($app, $to, $method, $type, $body, $dest, 0, $FETCH_BYTES);
    return live_replied($live, $parts ? @$parts : ($status, '', ''));
}

sub kept_app_response {
    my ($app, $to, $method, $type, $body, $dest, $nav, $maximum) = @_;
    my ($url, $host) = address($to);
    return (undef, 403) unless $url && $app->{spec}{hosts}{$host};
    return (undef, 403) if listed($url) ||
        defined filter_said($url, $FILTER_DEST{$dest // 'data'} // $dest, 'discord.com') || shield_said($url) ne 'allow';
    return (undef, 403) unless kept_app_budget($app, 1, 0);
    my $remaining = $app->{spec}{bytes} - $app->{bytes};
    return (undef, 403) unless $remaining > 0;
    return (undef, 403) unless record("the kept app asked for $host ($method)");
    my ($where) = find($host);
    return (undef, 403) unless $where && !grep { $_->{own} } @$where;
    return (undef, 403) unless record("the kept app connects to $host at the first public address that answers: " . join(', ', map { $_->{text} } @$where));
    my $ask = { method => $method, type => $type, body => $body, origin => 'https://discord.com', top => $app->{spec}{start}, kept_app => 1 };
    my ($got, $why, $peer, $certs) = @{ kept_app_jar($app, sub {
        return [fetch($url, $where, $ask, $nav, [$remaining < $maximum ? $remaining : $maximum, $FETCH_SECONDS])];
    }) };
    return (undef, 0) if $why || !defined $got || !kept_app_budget($app, 0, length($got));
    my $parts = live_parts($got, $method);
    return (undef, 0) unless $parts && record("$host answered the kept app with $parts->[0]: " . length($got) . ' bytes');
    return ($got, $parts->[0], $peer, $certs, $parts);
}

sub kept_app_open_tab {
    my ($source) = @_;
    return unless $TABS[$TAB] == $source && $source->{cht};
    for my $i (0 .. $#TABS) {
        next unless $TABS[$i]{kept_app};
        tabbed('select', $i);
        return;
    }
    return idle("A window holds $TABS_MOST tabs at most: close one to open Discord.") if @TABS >= $TABS_MOST;
    my $app = kept_app_discord() or return idle('Discord could not open its private kept-app store.');
    $source->{shown} = $SHOWN;
    my $tab = fresh_tab();
    $tab->{kept_app} = $app;
    push @TABS, $tab;
    $TAB = $#TABS;
    undef $SHOWN;
    tab_shown('Opening Discord in its kept-app tab.');
    return go($app->{spec}{start}, 'you opened Discord from LZRCHT');
}

sub kept_app_visit {
    my ($tab, $typed, $how) = @_;
    my $app = $tab->{kept_app};
    my ($url, $host) = address($typed);
    return idle('This Discord tab opens Discord addresses only.') unless $url && kept_app_valid($app, $url) && $host =~ /\A(?:discord\.com|discord\.gg)\z/;
    my ($got, $status);
    for (0 .. 3) {
        ($got, $status) = kept_app_response($app, $url, 'GET', '-', '', 'document', 1, $FETCH_BYTES);
        return idle("Discord could not be opened (request status $status).") unless defined $got;
        last unless $status >= 300 && $status < 400;
        my (undef, $to) = redirected($got, $url);
        ($url, $host) = defined $to ? address($to) : ();
        return idle('The Discord redirect was refused.') unless $url && kept_app_valid($app, $url) && $host =~ /\A(?:discord\.com|discord\.gg)\z/;
    }
    return idle("Discord could not be opened (HTTP $status).") unless $status == 200;
    my $prior = live_of($tab);
    live_end($prior, 'its kept app went elsewhere', 1) if $prior;
    my $frame = "=sheets\n";
    my ($lines, undef, $paths, $title, $named, $live) = laid_out($url, $got, $frame, 1, $app);
    return idle('Discord could not draw its page.') unless $lines && $live;
    if (@$named) {
        my @sheets = map {
            my ($sheet, $status) = kept_app_response($app, "https://$host$_", 'GET', '-', '', 'stylesheet', 0, $SHEET_BYTES);
            $status == 200 ? $sheet : '';
        } @$named;
        if (grep { length } @sheets) {
            my $with = join(' ', '=sheets', map { length } @sheets) . "\n" . join('', @sheets);
            my @next = laid_out($url, $got, $with, 1, $app);
            if ($next[0] && $next[5]) {
                live_dropped($live);
                ($lines, $paths, $title, $live) = @next[0, 2, 3, 5];
                $frame = $with;
            } else { live_dropped($next[5]) }
        }
    }
    @$tab{qw(url title says)} = ($url, $title || 'Discord', 'Discord in its kept-app tab.');
    if (($how // '') !~ /\Ayou (?:went (?:back|forward) to|reloaded)\z/) {
        splice @{ $tab->{visited} }, $tab->{at} + 1;
        push @{ $tab->{visited} }, $url;
        shift @{ $tab->{visited} } while @{ $tab->{visited} } > $VISITED;
        $tab->{at} = $#{ $tab->{visited} };
    }
    $SHOWN = { url => $url, host => $host, got => $got, frame => $frame, list => $lines, pictures => {},
        videos => [], sites => [], wide => $VIEW[0], scale => $VIEW_SCALE };
    live_kept($live, $tab, $lines, $paths, $host, {}, $lines, []);
    tab_shown();
    live_told();
    return;
}
