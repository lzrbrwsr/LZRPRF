# Cross-host sends are keyed by the originating site and the exact destination.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrdfndr.md
my (%SEND_NOTED, @SEND_WEB_KEYS);
my $SEND_SEEN = 0;
my $SEND_MOST = 256;    # DECLARED(the latest 256 cross-host sends in one window)

sub send_keys {
    return sort { $SEND_NOTED{$a}->{site} cmp $SEND_NOTED{$b}->{site} || $a cmp $b } keys %SEND_NOTED;
}

sub sends_told {
    my $n = 0;
    @SEND_WEB_KEYS = send_keys();
    window('sends begin', (map {
        my $one = $SEND_NOTED{$_};
        'sends one ' . join("\t", $n++, @$one{qw(site to decision)})
    } @SEND_WEB_KEYS), 'sends end');
}

sub sends_decide {
    my ($n, $decision) = @_;
    my $key = $SEND_WEB_KEYS[$n];
    my $one = defined $key ? $SEND_NOTED{$key} : undef;
    if ($one) {
        if ($decision eq 'forget') { delete $SEND_NOTED{$key} }
        else {
            $one->{decision} = $decision;
            $one->{once} = $decision =~ /-once\z/ ? 1 : 0;
        }
    }
    sends_told();
}

sub send_question {
    my ($site, $to) = @_;
    my $key = "$site\t$to";
    return 2 if defender_is_off('sends') && record("$site sent to $to unasked: LZRDFNDR's Sends is off");    # Ticket #1546
    if (my $one = $SEND_NOTED{$key}) {
        my $decision = $one->{decision};
        return 2 if $decision eq 'always';
        return 1 if $decision eq 'deny';
        return $decision eq 'allow-once' ? 2 : 1 if delete $one->{once};
    } elsif (keys %SEND_NOTED >= $SEND_MOST) {
        my ($old) = sort { $SEND_NOTED{$a}->{n} <=> $SEND_NOTED{$b}->{n} } keys %SEND_NOTED;
        delete $SEND_NOTED{$old};
    }
    my $words = "The page $site wants to send something to $to, on another host. No script permission covers that.";
    my $answer = web_question('send', $words, undef, 1, 0);
    $SEND_NOTED{$key} = { site => $site, to => $to, n => ++$SEND_SEEN, decision => $WEB_ANSWER_BY_ID[$answer - 1] };
    return $answer == 2 || $answer == 3 ? 2 : 1;
}

sub sends_count { scalar keys %SEND_NOTED }
sub sends_clear { %SEND_NOTED = (); @SEND_WEB_KEYS = (); $SEND_SEEN = 0 }
