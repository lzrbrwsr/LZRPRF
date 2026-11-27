# Kept Discord localStorage. The renderer is handed only its own origin's
# snapshot and tells lzrprf bounded mutations. Nothing here is sent to the log.
# SYNC: managed-projects/lzrbrwsr/src/page/web_storage.rs
my $STORAGE_BYTES = 2 * 1024 * 1024;       # DECLARED(matches the renderer's kept-app snapshot bound)
my $STORAGE_ITEMS = 100_000;             # DECLARED(matches engine storage::MAX_ITEMS)

sub kept_storage_file {
    my ($app, $url) = @_;
    return unless kept_app_valid($app, $url);
    my ($host) = $url =~ m{\Ahttps://(discord\.com|discord\.gg)(?:[/?]|\z)} or return;
    return "$app->{folder}/$host.storage";
}

sub kept_storage_locked {
    my ($file, $step) = @_;
    sysopen(my $lock, "$file.lock", O_WRONLY | O_CREAT | O_NOFOLLOW | O_NONBLOCK, 0600) or return;
    my @info = stat $lock;
    return unless @info && -f _ && $info[4] == $< && !($info[2] & 077);
    return unless flock($lock, LOCK_EX);
    return $step->();
}

sub kept_storage_read {
    my ($file) = @_;
    sysopen(my $in, $file, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return $!{ENOENT} ? '' : undef;
    my @info = stat $in;
    return unless @info && -f _ && $info[3] == 1 && $info[4] == $< && !($info[2] & 077) && $info[7] <= $STORAGE_BYTES + 32;
    binmode $in;
    local $/;
    my $raw = <$in>;
    return unless defined $raw && length($raw) == $info[7] && $raw =~ /\A[0-9a-f]{32}/;
    return $raw;
}

sub kept_storage_replace {
    my ($file, $raw) = @_;
    my $next = "$file.new.$$";
    unlink $next;
    sysopen(my $out, $next, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) or return;
    binmode $out;
    my $fit = print {$out} $raw;
    $fit = close($out) && $fit;
    return 1 if $fit && rename($next, $file);
    unlink $next;
    return;
}

sub kept_storage_items {
    my ($snapshot) = @_;
    my (%entries, $at);
    $at = 0;
    while ($at < length $snapshot) {
        return if length($snapshot) - $at < 8 || keys(%entries) >= $STORAGE_ITEMS;
        my ($k, $v) = unpack 'NN', substr($snapshot, $at, 8);
        $at += 8;
        return if ($k | $v) & 1 || $k + $v > length($snapshot) - $at;
        my $key = substr($snapshot, $at, $k);
        return if exists $entries{$key};
        $entries{$key} = substr($snapshot, $at + $k, $v);
        $at += $k + $v;
    }
    return \%entries;
}

sub kept_storage_frame {
    my ($app, $url) = @_;
    my $file = kept_storage_file($app, $url) or return ('', undef);
    my $epoch;
    my $snapshot = kept_storage_locked($file, sub {
        my $raw = kept_storage_read($file) // return;
        if (!length $raw) {
            $raw = link_random(16) // return;
            return unless kept_storage_replace($file, $raw);
        }
        my $snapshot = substr($raw, 32);
        return unless kept_storage_items($snapshot);
        $epoch = substr($raw, 0, 32);
        return $snapshot;
    });
    return defined $snapshot ? ('=webstore ' . length($snapshot) . "\n$snapshot", $epoch) : ('', undef);
}

sub kept_storage_asked {
    my ($held) = @_;
    my $end = index $held, "\n";
    return length($held) <= 24 ? 0 : [''] if $end < 0;
    my $line = substr($held, 0, $end);
    my ($size) = $line =~ /\A=store ([1-9][0-9]{0,6})\z/ or return [''];
    return [''] if $size < 9 || $size > $STORAGE_BYTES;
    return 0 if length($held) < $end + 1 + $size;
    return [$line, substr($held, $end + 1, $size), $end + 1 + $size];
}

sub kept_storage_change {
    my ($live, $body) = @_;
    my $app = $live->{kept_app} or return;
    my $file = kept_storage_file($app, $live->{url}) or return;
    my $epoch = $live->{storage_epoch} or return;
    my ($op, $k, $v) = unpack 'CNN', $body;
    return unless ($op == 2 || $op == 1 && !$v || !$op && !$k && !$v)
        && !(($k | $v) & 1) && $k + $v + 9 == length($body);
    my $key = substr($body, 9, $k);
    return kept_storage_locked($file, sub {
        my $raw = kept_storage_read($file) // return;
        return unless substr($raw, 0, 32) eq $epoch;
        my $entries = $op ? kept_storage_items(substr($raw, 32)) : {};
        return unless $entries;
        if ($op == 2) { $entries->{$key} = substr($body, 9 + $k, $v) }
        elsif ($op == 1) { delete $entries->{$key} }
        return if keys(%$entries) > $STORAGE_ITEMS;
        my $snapshot = join '', map { pack('NN', length($_), length($entries->{$_})) . $_ . $entries->{$_} } sort keys %$entries;
        return if length($snapshot) > $STORAGE_BYTES;
        return kept_storage_replace($file, $epoch . $snapshot);
    });
}

# Rotate the on-disk generation while clearing. A renderer loaded before the
# clear cannot later write its old snapshot or credentials back.
sub kept_storage_forget {
    my ($app, $url) = @_;
    my $file = kept_storage_file($app, $url) or return;
    my $epoch = link_random(16) // return;
    return kept_storage_locked($file, sub { kept_storage_replace($file, $epoch) });
}

sub kept_storage_forget_app {
    my ($app) = @_;
    my $first = kept_storage_forget($app, 'https://discord.com/');
    my $second = kept_storage_forget($app, 'https://discord.gg/');
    return $first && $second;
}

sub kept_storage_forget_site {
    my ($url) = @_;
    return 0 unless $url =~ m{\Ahttps://(?:discord\.com|discord\.gg)(?:[/?]|\z)} &&
        -d "$ROOT/cht/web/discord";
    my $app = kept_app_discord() or return;
    return unless kept_storage_forget_app($app);
    for my $live (grep { $_->{kept_app} } @LIVE) { live_end($live, 'its Discord storage was cleared', 1) }
    return 1;
}
