# Which choices cost you, and where they are made

This text was the README section "Which choices cost you, and where they are made" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/choices.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| Each choice has one direction that costs you ... | - | - | - |
| choice the direction that costs you where it ... | - | - | - |
| what is kept more kept: a log, full ... | `keep_command`, `choose_keeping`, `clear_log` | - | - |
| an address fetching it: the site sees your ... | `visit` | C5 | - |
| a host inside your own network yes: this ... | `own_network` | - | - |
| looking for a newer release yes: GitHub sees ... | `newer` | - | - |
| installing a newer release "Install it": it runs ... | `newer`, `installed` | - | - |
| the home page and bookmarks an address kept ... | `menu`, `mark_saved` | C5 | - |
| following a redirect Proceed: a new request to ... | `visit`, `asked` | - | - |
| a report after a failure "Send": the maker's ... | `fault`, `behind` | - | - |
| a support request "Send": the support address the ... | `support_sent`, `support_read` | C5 | - |
| Only the first row can be closed entirely, ... | - | C10 C5 | - |
<!-- index end -->

Each choice has one direction that costs you something. The window's process draws text the
application chose, so it is the part to trust least (see "What it does not prove"): if such
text ever took it over, it could say that a button was pressed. This is what that is worth,
choice by choice.

| choice | the direction that costs you | where it is made | what a taken-over window process could do |
| --- | --- | --- | --- |
| what is kept | more kept: a log, full addresses, more days | a terminal only (`sub keep_command`) | keep less, and clear the log (`sub choose_keeping`, `sub clear_log`) |
| an address | fetching it: the site sees your internet address and the address you typed | the bar of the window (`sub visit`) | say "go ADDRESS" as if you had typed it, as often as it likes. Each one is a line before it is fetched `[C5]` |
| a host inside your own network | yes: this computer, your router or another device of yours is asked, this once | the window, each time such an address is typed (`sub own_network`) | say such an address and answer "Yes, this once" itself. The address and the yes are lines before anything is fetched |
| looking for a newer release | yes: GitHub sees your internet address at each start | the window, when lzrprf asks: at a first start, and again when a release names another address or `~/.lzrprf/look` was deleted (`sub newer`) | answer yes while that question is open. It cannot open the question. The yes is a line of the log before it is kept, and each look is a line before it is made |
| installing a newer release | "Install it": it runs at once, in lzrprf's window, by itself | the window (`sub newer`, `sub installed`) | press "Install it" when a newer release is published. lzrprf then fetches the installer from the addresses the release names, from both places, and runs it only when the two copies are the same: the most a press can do is install the release the maker published |
| the home page and bookmarks | an address kept on the disk, opened at each start, in each new tab, or with a click | the cogwheel's menu and the star's modal (`sub menu`, `sub mark_saved`) | keep an address it said, as if from the bar or the modal, and open it. Each opening is a line before it is fetched `[C5]` |
| following a redirect | Proceed: a new request to the address the site named | lzrprf's modal over the window (`sub visit`, `sub asked`) | press Proceed while the question is open. The new address gets every check of a typed one, and a line before it is fetched |
| a report after a failure | "Send": the maker's server sees your internet address and three values | the window, when a page was not shown (`sub fault`) | say that a page it was handed could not be drawn, once for each page (`sub behind`), and press "Send" to the question that follows: the three values, written in the log first |
| a support request | "Send": the support address the release file names sees your internet address, your words, the release number, your licence code when one is kept, and the picture of the window when you ticked it | the cogwheel's "Support request..." (`sub support_sent`, `sub support_read`) | say "support send" with words of its own and a picture it drew, and ask for the answer kept. Each goes only to the address of the release file, as a line of the log first `[C5]`; besides what the window's process holds itself, it carries nothing of yours but the licence code when one is kept |

Only the first row can be closed entirely, and it is: nothing in the window keeps more. In the
other rows the window is where you answer, so a taken-over window process could answer too.
Installing takes nothing from the window but the press: what is fetched and run comes from the
fixed addresses of the release file and nothing the window says, and the window's process
commands no other program `[C10]`. What holds in the other rows is `[C5]`: nothing leaves this computer before its line exists, and with
nothing kept that line is in the memory of lzrprf's process, which the window's process
cannot write.
