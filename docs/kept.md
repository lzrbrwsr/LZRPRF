# What is kept

This text was the README section "What is kept" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/kept.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| The principle: every outgoing network request must be ... | - | - | - |
| So every line of the log is kept ... | `record`, `keeping` | C12 | - |
| mode what the Log button shows what stays ... | - | - | - |
| nothing, when nobody chose this window's lines nothing ... | - | - | - |
| hosts this window's full lines, and under them ... | `shortened` | - | `hosts` |
| all the same every line in full, as ... | - | - | - |
| More is chosen in one place only, a ... | `keep_command` | - | - |
| The window can keep less: Log, then "Keep ... | `choose_keeping` | - | - |
| Why the two are not the same door: ... | - | - | - |
| A change of what is kept is itself ... | `changed`, `kept_words` | - | - |
| Keeping less holds at once: a request that ... | `record` | - | - |
| - A kept log keeps a line 30 ... | `expire_log` | - | - |
| - In a kept mode [C5] holds as ... | - | C5 | - |
| - Keeping less deletes and shortens nothing. Switching ... | `clear_log` | - | `hosts` |
| - Only lzrprf writes the setting, outside every ... | `keep_as`, `keep_lock` | - | - |
| - When lzrprf creates or replaces the log, ... | `excluded` | - | - |
| The limits, said plainly: ... | - | - | - |
| - With nothing there is nothing to look ... | - | - | - |
| - With nothing, lzrprf writes nothing of what ... | - | - | - |
| - Besides the log, ~/.lzrprf holds what you ... | - | C11 | `home`, `gamehelper`, `support` |
| - Hosts and times alone still show habits: ... | - | - | `hosts` |
| - That Time Machine honours the mark is ... | - | - | - |
| - Old lines are taken out only while ... | `expire_log` | - | - |
| - Clearing and taking out old lines remove ... | - | - | - |
| - What macOS itself keeps is outside lzrprf: ... | - | - | - |
| - A window process that text took over ... | - | - | - |
<!-- index end -->

The principle: every outgoing network request must be observable by you, but no browsing
activity should be permanently retained without your explicit consent.

So every line of the log is kept in the memory of the process behind the window
(`sub record`), after it was written to the disk when a log is kept, and the Log button shows
it. What stays on this computer after the window
closes is your choice, held in the plain file `~/.lzrprf/keep` (`sub keeping`) `[C12]`, or in
the folder of a second profile its own `keep` (see "Profiles"):

| mode | what the Log button shows | what stays on this computer |
| --- | --- | --- |
| `nothing`, when nobody chose | this window's lines | nothing lzrprf writes: no file of lzrprf's holds an address you typed. A log kept earlier stays until you clear it, and what macOS keeps on its own is in the limits below |
| `hosts` | this window's full lines, and under them the log on this computer | each line with every address cut to `https://host`: the time, the run, the host, the numeric address lzrprf connected to, and how it ended; no path and no query (`sub shortened`) |
| `all` | the same | every line in full, as before there was a choice |

More is chosen in one place only, a terminal: `perl lzrprf keep hosts 30` keeps a log of hosts
for 30 days, `perl lzrprf keep all 30` keeps full addresses and says that they can hold search
words, tokens and invitation links (`sub keep_command`). No button of the window makes lzrprf
keep more.

The window can keep less: Log, then "Keep less", then "Keep nothing", or from full addresses
"Keep a log" and "Hosts only" (`sub choose_keeping`, where the new mode is never more than the
one that holds at that moment: the setting is read again after your last answer, and the days
stay as they are). The first button of each question keeps less or changes nothing, and a
question nobody answers counts as that one.

Why the two are not the same door: the window's process is the one that tells lzrprf which
button was pressed. If text it draws ever took that process over, it could do by itself what
the buttons can do. So the buttons can keep less and clear, and nothing else.

A change of what is kept is itself a line (`sub changed`), for example
`what is kept was changed in the window: full addresses, 30 days -> hosts only, 30 days`. A
change made in the window is among that window's lines. A change made either way is a line of
the log on this computer when there is one or one is kept from then on; where there is no log
and none is kept, `lzrprf keep` leaves no line. So a log says where it stops and where its lines became shorter or longer, and whether
a button or the command did it. The Log button and every start of a window say in one sentence
which mode is on (`sub kept_words`).

Keeping less holds at once: a request that is open while you choose writes no later line at
more than what is kept at that moment (`sub record` reads the setting again, under the lock the
change holds). Keeping more holds from the next request on.

- A kept log keeps a line 30 days unless you chose another number; 0 keeps it until you clear
  it. At the start of a window, older lines are taken out the same way clearing replaces the
  log, and the new first line says how many and why (`sub expire_log`). When a request of
  another window is open at that moment, it is tried again before each request of this window
  and each press of Log, until it is done.
- In a kept mode `[C5]` holds as before: the line is on the disk before the name is looked up.
  In `nothing` it is in memory before the name is looked up.
- Keeping less deletes and shortens nothing. Switching to `nothing` does not remove a log
  written earlier, and `hosts` does not shorten its older lines: they stay as they were, full
  ones among them, and lzrprf says how many there are. A log that is there, one an
  older release wrote among them, stays until you press "Clear the log", which is one click
  away under the Log button whenever there is a log, and asks once more (`sub clear_log`).
- Only lzrprf writes the setting, outside every container: `lzrprf keep` for you, and the
  process behind the window after your answers there, which only ever writes less
  (`sub keep_as`). One of them writes at a time (`sub keep_lock`). `lzrprf keep` changes
  nothing when the line that says so cannot be written to the log, unless the change is to
  keep nothing, which is never refused. Should putting the old setting back fail as well, the
  command says that the change stands. Anything else in that
  place counts as `nothing`: a link, a file with a second name or of another owner, something
  that is not a plain file, or words or a number of days (above 3650) it does not take.
  `selftest` tries each of these but the other owner, which only an administrator can make, and
  has the hostile application try to change the setting from inside each container.
- When lzrprf creates or replaces the log, or first adds a line to one that was there, it marks
  that file for Time Machine to leave out of its backups (`sub excluded`). A mark that cannot be set stops no request, and the Log button
  says so. The folder is not marked.

The limits, said plainly:

- With `nothing` there is nothing to look at after the window is closed, for you either.
- With `nothing`, lzrprf writes nothing of what was fetched to the disk on purpose. Memory can
  still reach the system's swap, a crash report of that process, the resolver's cache of
  names, a snapshot of the disk or a backup: those are macOS's, outside lzrprf, and lzrprf
  cannot prevent them.
- Besides the log, `~/.lzrprf` holds what you chose to keep there: `home` (the one address you
  made the home page), the folder `bookmarks` (one file a bookmark, a name and an address, and a file `.order` in each folder),
  `marksbar` (whether the bookmarks bar is shown), `pictures` (whether pictures from other sites are blocked), `gamehelper` (whether LZRDFNDR's satellite plays in the home page's minigame), and after "Install it" the folder
  `install.NUMBER` with the installer it fetched and `install.txt`, every line an installer
  printed, appended, `licence` (the support member licence code you entered, as it was given
  to you, until you remove it) and `support` (the reference and the key of the support request
  you sent last, so its answer can be read, and never its words, until "Forget it" or the next
  request), `procnotes` (the notes you wrote to programs in LZRDFNDR's Show all processes, one line a program, its path and your words, readable by you alone; an empty note removes its line, and an incognito window writes none), and the folder `profiles` once you made a second profile or named the first: a
  folder for each profile with its own `name`, `keep`, log, `home`, `search`, `bookmarks`,
  `marksbar` and `pictures`, and the file `first` with the first profile's name (see "Profiles"). An incognito
  window writes and reads neither licence nor support, and offers neither. The closed tabs
  to reopen and each tab's zoom are held in memory only. It also holds files lzrprf needs to
  work, none with an address you typed:
  `keep` (what is kept), `look` (your answer about newer releases), `welcomed` (the number of
  the last release whose welcome you closed, and nothing else), `proven` (the mark of
  `[C11]`), `untested` (your yes to starting without the checks a test could not try, as the
  line of the mark you said it to), `selftest.txt` (the last test's report), `selftest.lock`, from an installer's questions until its files are placed
  its lock (the link `.installing`), and while a window is
  open the lock files `lock`, `keep.lock` and `busy`, the folder `tries.NUMBER` of the tries at
  the start, and the socket `way.NUMBER` of a request.
- Hosts and times alone still show habits: which sites, when, and how often. That is why even
  `hosts` needs your yes.
- That Time Machine honours the mark is Apple's behaviour, and it is not tested here. The mark
  is a request to backup programs; another backup program may not read it.
- Old lines are taken out only while lzrprf runs (`sub expire_log`, at the start of a window;
  when another window's request kept it from that, again before each request and each press
  of Log until it is done). Nothing runs by itself to do it: while LZRBRWSR is not started, no line
  is taken out.
- Clearing and taking out old lines remove them from the file: a new file takes the log's name,
  or the log is removed. The places on the disk where the old lines stood are not overwritten,
  and a snapshot or a backup made before still holds them.
- What macOS itself keeps is outside lzrprf: its cache of names that were looked up, crash
  reports, and the memory it writes to swap.
- A window process that text took over could press the buttons that keep less and the two that
  clear the log, as it could press any button (see "What it does not prove"). It could remove
  the record on this computer. It could not make lzrprf keep more.
