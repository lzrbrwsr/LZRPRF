# When a page cannot be shown

This text was the README section "When a page cannot be shown" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/faults.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| When the application did not give a page, ... | `fault` | C7 C5 | - |
| Seven phrases that can lead to a report, ... | `laid_out` | - | `page` |
| The release of LZRBRWSR on record here names ... | - | - | `report` |
| WORD is page or container, NUMBER is the ... | - | - | `page` |
| What the maker's server keeps of it cannot ... | - | - | - |
| Everyone on the same update of macOS has ... | - | - | - |
| An error of lzrprf's own while it takes ... | `unheard`, `behind` | - | `behindfault` |
<!-- index end -->

When the application did not give a page, the window says one of eight fixed phrases (`%FAULT`
in `lzrprf`; the eighth, from release 17 on, says that the program on the disk changed under
an open window, and it offers no report: nothing of the application ran). For the other seven,
if the release names an address for reports, you are asked whether to send one,
with two buttons, and shown the whole address first (`sub fault`). A report holds three values:
one of two words, the number of the release, the build of macOS. Not the address you typed, and
nothing of the page. It is not anonymous to the network: like any request, it shows the
receiving server your internet address and the time. It is sent only after "Send", the way a typed address is `[C7]`, and
written in the log first `[C5]`. The first button is "Don't send", and a question nobody
answers counts as that one. When the line that says how the report ended cannot be written to
the log, the window says that the report was tried, not that it could not be sent.

Seven phrases that can lead to a report, and only two words. Five of the seven are the
application's own doing: it ended
before it was given the page, it was late, it wrote too much, it wrote something that is no
page, or it wrote what the window could not draw. An application that could choose among five
words could tell its maker a little of what it had just read. So the report says `page` for
all five, and `container` for the two that lzrprf and macOS decide: the container could not be
started, or macOS did not say of a process still running that it was contained
(`sub laid_out`). An application that ends by itself before macOS was asked about it counts as
`page`, so it cannot pick `container` by ending early. One thing stays the application's choice and cannot be taken from it:
whether it fails at all, and so when. A report you send therefore tells the maker that some
page failed on your Mac at that moment, and not which. The report holds no address, but the
question appearing, and a report you then send, carry a little information from the
program: that a page failed, at a moment it chose. It cannot choose the word. Never pressing
"Send" closes this way.

The release of LZRBRWSR on record here names such an address: the `report` line shown in the
section above. So this is the whole of what can be sent, and to whom:

    GET /report?fault=WORD&release=NUMBER&macos=BUILD      to origin.lzrbrwsr.com

`WORD` is `page` or `container`, `NUMBER` is the release, `BUILD` is the build of macOS, such
as 26B123. The question shows that address in full before anything is sent.

What the maker's server keeps of it cannot be checked from here, and this repository does not
claim it as proven. The maker's word, the same as on the site's privacy page
(https://lzrbrwsr.com/privacy.html): the server sees your internet address and the moment, as
any server does, and keeps neither; it keeps one line with the day and those three values. What
you can check is everything on your side: the bytes (`perl lzrprf request ADDRESS`), the
question, and the line behind the Log button.

Everyone on the same update of macOS has the same build. A rare build, such as a test build,
narrows down who could have sent a report. The question shows the build before you choose.

An error of lzrprf's own while it takes up a line of the window or of a page kept running (`sub unheard`, called from
`sub behind`) never ends the window. The page of the tab shown is ended, the log keeps a line naming what was being
taken up and the error, and the tab says that the page was ended and that the window and its other tabs go on. A copy
of lzrprf made by fork that meets such an error ends at once and never goes on as the one behind the window. Only
after `$BEHIND_FAULTS` such errors in one window does lzrprf end after all. Until 2026-11-24 any such error ended
lzrprf, and the window followed it (Henry's report of yle.fi: the whole browser went). Run `behindfault`.
