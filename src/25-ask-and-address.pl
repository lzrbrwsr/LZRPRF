# A question, in lzrprf's strip of the window, with two buttons, or with one
# where there is nothing to choose. The first
# button is always the one that fetches, sends, replaces and keeps nothing, or
# keeps less, and it is the answer when the time is over; when the window is
# gone, lzrprf ends instead, and nothing is fetched or sent. Returns 1 or 2.
# Both sides count the questions, and a button says which question it
# answers: a press that comes late, after its question ran out of time, is
# not taken as the answer to the next one.
my $ASKED = 0;
sub ask { my ($words, @buttons) = @_; return asked('ask ' . $words =~ s/\s+/ /gr, @buttons) }

sub asked {                               # a question in a line of its own kind: "ask" in the strip, "redirect" in a modal; up to four buttons
    my ($line, @buttons) = @_;
    $ASKED++;
    window(join "\t", $line, @buttons);
    if (!$FROM) {                         # "lzrprf try" only: the test's answer
        my $press = $ANSWER eq 'allow' ? 2 : $ANSWER =~ s/^([1-4])// ? $1 : 1;    # a digit for each question in turn; a third button is answered by 3, a fourth by 4
        window("answered $press");
        return $press;
    }
    my $until = now() + $ANSWER_SECONDS;
    while ((my $left = $until - now()) > 0) {
        my $event = hear($left) // leave();
        return $1 if $event =~ /^button $ASKED ([1-4])$/ && $1 <= @buttons;
        viewing($event); if ($event =~ /^page scroll [0-9]{1,2} [0-9]{1,6} [0-9]{1,6}$/) { my $back = live_scroll_back(); @LATER = ((grep { !/^page scroll / || $_ eq $back && $_ ne $event } @LATER), $event) } elsif ($event =~ /^tor (?:on|off)$/) { push @LATER, $event }    # a new size of the window's page said meanwhile is still its size; the page is laid out at it after the question (sub relaid); Tor turned on or off is heard after it too, and where the window shows the page from, the newest place only: one said each frame of a long question is not kept by the hundred, but the page's own scroll said back is kept too, so the window's places are heard again after it (sub live_input)
    }
    return 1;
}

# What is fetched for a text that was typed. An address is https, a host by its
# name, port 443, and plain characters without a space. lzrprf adds https://
# when no scheme was typed, writes the host in small letters, and leaves out
# what follows a #, which is never sent to a site. Everything else is sent
# exactly as typed, or, when it is not such an address, not at all.
sub address {
    my ($text) = @_;
    $text =~ s/^[ \t]+|[ \t\r\n]+$//g;
    $text =~ s/#.*//s;
    $text = "https://$text" unless $text =~ m{^[A-Za-z][A-Za-z0-9+.-]*://};
    return unless $text =~ m{^https://($NAME)(?::443)?([/?][\x21-\x7e]*)?$}i && length $1 <= 253 && length $text <= 2000;
    my ($host, $rest) = (lc $1, $2 // '/');
    $rest = "/$rest" if $rest =~ /^\?/;
    return if listed("https://$host$rest");    # [C23] a listed address is no address lzrprf fetches, wherever it came from
    return ("https://$host$rest", $host);
}

# A host that leads to this computer, into a network of your own, or to a
# place this computer reaches by a route of its own is not the public
# internet. It is fetched only after you said yes to exactly that, in
# lzrprf's strip of the window, and the yes holds for that one request.
# Returns nothing after a yes, and the reason after a no.                # [C8]
sub own_network {
    my ($host, $where, $kept) = @_;
    my $there = join ', ', map { $_->{text} } @$where;
    my $yes = ask("$host is not on the public internet. It leads to $there: this computer, a network of your own, or a place this computer reaches by a route of its own, such as a VPN. What answers there can be a device of yours, such as a router. Fetch it this once?", 'No', 'Yes, this once') == 2;
    record('you ' . ($yes ? 'allowed' : 'refused') . " $host, which is inside your own network ($there)" . ($yes ? ', this once' : ''), $kept) or return 'the log could not be written';
    return $yes ? undef : 'you said no to a host inside your own network';
}

