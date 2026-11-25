# Use

This text was the README section "Use" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/use.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| perl lzrprf run /path/to/program open the window, with ... | - | C16 C27 | - |
| Three lines of the log, for one request ... | - | - | - |
| The Log button of the window shows the ... | `noted`, `log_shown` | - | - |
| selftest prints six kinds of line under eleven ... | - | - | - |
<!-- index end -->

    perl lzrprf run /path/to/program     open the window, with the program contained behind it
    perl lzrprf incognito [/path/to/program]  the same in an incognito window, which leaves nothing behind when it closes [C16]
    perl lzrprf run|incognito --open "X Y W H" /path/to/program   the window of a tab pulled out of another, at that frame: lzrprf starts it itself, with the tab's address as one line on standard input, never as an argument
    perl lzrprf run --profile ID [--open "X Y W H"] /path/to/program   a window of the profile whose id is ID, 12 hex digits lzrprf made: lzrprf starts it itself from the Profiles icon, and the name never goes on the command line
    perl lzrprf incognito --profile ID [/path/to/program]   an incognito window that reads the profile whose id is ID; lzrprf starts it itself from that profile's window
    perl lzrprf profiles                 each profile's id and its name; the first profile is "first", the one used without --profile
    perl lzrprf log [--profile ID]       what the log on this computer holds, and what is kept
    perl lzrprf keep [--profile ID]      what is kept after a window closes, in words
    perl lzrprf keep [--profile ID] MODE [DAYS]   choose it: nothing, hosts or all; DAYS 0 keeps until you clear it. The one place where more is chosen
    perl lzrprf address TEXT             what would be fetched if TEXT were typed into the bar
    perl lzrprf request [--other] TEXT   the exact bytes a site is sent for TEXT: a page you visit, or with --other a picture, a style sheet or the release file
    perl lzrprf public NUMBER            whether a numeric address is public, and how this computer sends to it
    perl lzrprf mark                     this build of macOS, this lzrprf and the selftest beside it, as one line
    perl lzrprf filters DIR PAGE TYPE ADDRESS...   what the filter lists in DIR would do with each address, as a request of TYPE from a page of the host PAGE; decides nothing for a window (docs/filters.md) [C27]
    perl selftest                        probe it on this computer; about half a minute, no window

Three lines of the log, for one request (time, number of the run, what happened), as a log of
full addresses holds them; a log of hosts only holds `https://example.com` in each:

    2026-11-18T09:14:03Z  4711  you typed https://example.com/
    2026-11-18T09:14:03Z  4711  https://example.com/ -> lzrprf connects to the first that answers of: 93.184.215.14
    2026-11-18T09:14:04Z  4711  https://example.com/ answered: 931 bytes from 93.184.215.14

The Log button of the window shows the lines of that window, from memory: every address
fetched, and what you did in it that fetched nothing, such as a tab opened or closed, a
bookmark or a setting (`sub noted`). Under them it shows the log on this
computer when there is one, with the button that clears it and, while a log is kept, the
questions that keep less (`sub log_shown`).

`selftest` prints six kinds of line under eleven numbered headings, then a count and a
verdict. `now`: what the test is doing at this moment, printed while it runs; the installer
shows these as its steps. `ran`: one of the runs of lzrprf, as it ends: its number of all of
them, its seconds and what it tries (`%about`); a run is judged after all have ended, and the
installer shows each under its step. `works`: a probe tried outside every container, where it must
succeed. `held`: a probe that failed inside, or a promise checked against what the test site
itself received. `UNTESTED`: something this Mac gave no way to try, with the reason; the mark
the run writes names each. `FAILED`:
a probe that succeeded, or a promise that did not hold. A line that begins `selftest:` says
why the test could not run at all. The hostile application is the text `$hostile` in
`selftest`: read it, add a probe of your own, run it again. The test uses no host outside
this computer. Its tries at an address outside go to 192.0.2.1, which is kept for
documentation and which no host answers: made outside every container, where they must not
be refused, they can put the opening packet of a connection on your network, with nothing of
yours in it. `selftest-output.txt` is the
record of the run of this release's `lzrprf` on the maker's Mac, written when the release was
made; its last line names the build of macOS and the SHA-256 of the `lzrprf` and `selftest`
that were run, and a record that names another sum than `release.txt` is not of this release.
It shows what a run looks like; the proof for your computer is your own run.
