# LZRDFNDR's switches (Ticket #1546): each protection on or off from the top of its tab in LZRDFNDR's panel.
# SYNC: managed-projects/lzrbrwsr/architecture/lzrdfndr.md
# One plain file of yours, defender, holds a line for each protection switched off ("scripts off"); no file,
# and every protection is on. A file that does not read leaves every protection on, so a damaged file never
# lets anything through unasked. Off, a protection asks nothing and shows no message: a page's scripts run as
# after Allow Once, a redirect is followed as after Proceed, a send to another host goes as after Allow Once,
# and On Your Computer no longer switches a job you switched off back off. What it lets through is still
# written in the log. An incognito window holds its choice in its memory alone [C16].
my @DEFENDER_KINDS = qw(computer scripts redirects sends);
my $DEFENDER_BYTES = 128;    # DECLARED(four lines of at most "redirects off\n": the file is never longer)
my $HELD_DEFENDER;

sub defender_off {                        # {kind => 1} for each protection switched off
    return { %$HELD_DEFENDER } if $INCOGNITO && $HELD_DEFENDER;
    sysopen(my $in, kept_in() . '/defender', O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or return {};
    my @is = stat $in;
    my $text = '';
    return {} unless @is && -f _ && $is[3] == 1 && $is[4] == $< && $is[7] <= $DEFENDER_BYTES && defined sysread($in, $text, $DEFENDER_BYTES + 1) && ($text eq '' || $text =~ /\n\z/);
    my %off;
    for (split /\n/, $text) { my ($kind) = /\A(computer|scripts|redirects|sends) off\z/ or return {}; $off{$kind} = 1 }
    return \%off;
}

sub defender_is_off { return defender_off()->{ $_[0] } ? 1 : 0 }

sub defender_told { my $off = defender_off(); window('defender ' . join(' ', map { "$_ " . ($off->{$_} ? 'off' : 'on') } @DEFENDER_KINDS)) }

sub defender_set {                        # "defender KIND on" or "off", from the switch at the top of its tab
    my ($kind, $on) = @_;
    my %off = %{ defender_off() };
    if ($on) { delete $off{$kind} } else { $off{$kind} = 1 }
    my $kept = 1;
    if ($INCOGNITO) { $HELD_DEFENDER = {%off} }
    else {
        my @lines = map { "$_ off" } grep { $off{$_} } @DEFENDER_KINDS;
        my $file = "$DIR/defender";
        if (!@lines) { $kept = !(-e $file || -l $file) || unlink $file }
        else { unlink "$file.new"; $kept = put("$file.new", O_EXCL, @lines) && rename("$file.new", $file); unlink "$file.new" unless $kept }
        synced() if $kept;
    }
    defender_told();
    my %name = (computer => 'On Your Computer', scripts => 'Scripts', redirects => 'Redirects', sends => 'Sends');
    return idle("LZRDFNDR's $name{$kind} could not be switched " . ($on ? 'on' : 'off') . ': its setting could not be written.') if !$kept || defender_is_off($kind) == ($on ? 1 : 0);
    noted("you switched LZRDFNDR's $name{$kind} " . ($on ? 'on' : 'off'));
    return idle("LZRDFNDR's $name{$kind} is " . ($on ? 'on.' : 'off: it asks nothing and shows no message.'));
}
