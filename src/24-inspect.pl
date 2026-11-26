# The page's native Inspect pane: what only the window may ask from the live page [C18].
# SYNC: managed-projects/lzrbrwsr/ARCHITECTURE.md §7.4 ; src/28-window-inspect.pl
# TRIAD(tests: managed-projects/lzrbrwsr/src/page/scripted_inspect.rs, docs: managed-projects/lzrbrwsr/ARCHITECTURE.md)

sub inspect_input {
    my ($tab, $panel, $request, $source) = @_;
    return if $tab != $TAB || $TABS[$TAB]{trmnl};
    my $live = live_of($TABS[$TAB]) or return;
    if ($source eq 'open') {
        $live->{inspect_panel} = $panel;
        $source = '-';
    } else {
        return unless ($live->{inspect_panel} // '') eq $panel && !defined $live->{inspect_reply};
    }
    $live->{inspect_reply} = $request;
    live_wrote($live, "inspect $request $source");
}

sub inspect_answer {
    my ($live, $request, $result, $log) = @_;
    return unless defined $live->{inspect_reply} && $live->{inspect_reply} eq $request;
    delete $live->{inspect_reply};
    return unless $live->{tab} == $TABS[$TAB] && defined $live->{inspect_panel};
    for my $encoded ($result, $log) {
        next if $encoded eq '-';
        my $text = pack 'H*', $encoded;
        $encoded = '-' unless utf8::decode($text) && $text !~ /(?:(?![\n\t])[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Cs}\p{NChar}])/;
    }
    window("inspect $TAB $live->{inspect_panel} $request $result $log");
}
