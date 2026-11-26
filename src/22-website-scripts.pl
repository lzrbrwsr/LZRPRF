# LZRDFNDR website edits and the pending script question.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrdfndr.md
sub sites_decide {                        # [C26] [C4] a decision changed in LZRDFNDR's On Websites, for the script numbered $n as sites_told last numbered it: "always" or "deny" keeps a rule of yours for it, "forget" takes away every decision of yours for it; then the list is told again
    my ($n, $to) = @_;
    my (undef, $all) = sites_listed();
    my $key = $WEBSITE_SCRIPT_KEYS[$n];
    my $words = 'Nothing was changed: that script is no longer in the list.';
    if (defined $key && exists $all->{$key}) {
        my ($site, $kind, $origin, $sha, $caps) = @{ $all->{$key} };
        my $class = permit_class($kind);
        my $date = strftime('%Y-%m-%d', gmtime);
        delete $PERMIT_DENIED{$site}{"$class $origin $sha"} if $PERMIT_DENIED{$site};
        for my $once (grep { $_ } $PERMIT_ONCE{$site}, $PERMIT_NEXT{$site}) { delete $once->{keys}{$_} for grep { my ($k, $o, $s) = split / /; permit_class($k) eq $class && $o eq $origin && $s eq $sha } keys %{ $once->{keys} } }
        my $once = $to =~ /-once\z/;
        my $done = permit_stored(sub {
            my ($rules, $memory) = @_;
            my $had = @$rules;
            @$rules = grep { !($_->[1] eq $site && $_->[2] eq $class && $_->[3] eq $origin && $_->[4] eq $sha && !($memory && $_->[7] eq 'file')) } @$rules;
            push @$rules, [$to, $site, $class, $origin, $sha, $caps // '-', $date] if $to ne 'forget' && !$once;
            return $once || $to ne 'forget' || $had != @$rules;
        });
        if ($done && $once) {
            if ($to eq 'deny-once') { $PERMIT_DENIED{$site}{"$class $origin $sha"} = 1 }
            else {
                $PERMIT_NEXT{$site} //= { keys => {}, hosts => {} };
                $PERMIT_NEXT{$site}{keys}{join(' ', $kind, $origin, $sha, $caps // '-')} = 1;
            }
        }
        my ($name) = permit_named($site, $kind, $origin, $sha);
        $words = $to eq 'forget' ? "No decision of yours is kept for $name: it is asked about again." : $done && $once ? "$name now applies to one visit." : $done ? "$name is now " . ($to eq 'always' ? 'allowed' : 'denied') . ' always.' : 'Nothing was changed: the scripts file could not be written.';
        noted("LZRDFNDR On Websites: $words");
    }
    sites_told();
    return idle($words);
}

sub permit_essentials_saved {
    my $pending = $PERMIT_PENDING or return;
    return unless ($TABS[$TAB]{url} // '') eq $pending->{url};
    my ($allow, $changed, @remaining);
    for my $item (@{ $pending->{items} }) {
        my ($kind, $origin, $sha, $caps) = @$item;
        my $id = permit_essential_id($pending->{site}, @$item, $pending->{url});
        my $choice = essential_web_answer($id, 0);
        if ($choice eq 'forget') { push @remaining, $item; next }
        $changed = 1;
        if (($choice eq 'always' || $choice eq 'allow-once') && permit_covers(join(',', keys %PERMIT_E1), $caps)) {
            $allow = 1;
        } else {
            $PERMIT_DENIED{$pending->{site}}{permit_class($kind) . " $origin $sha"} = 1 if $choice eq 'deny-once';
        }
    }
    return unless $changed;
    undef $PERMIT_PENDING;
    unless ($allow) { permit_queued($pending->{site}, @$_) for @remaining }
    return ($allow ? $pending->{url} : '', 1);
}

