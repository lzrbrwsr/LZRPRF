# An incognito window

This text was the README section "An incognito window" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/incognito.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| lzrprf incognito, or "New Incognito Window" (Shift-Command-N) in ... | - | C16 | - |
| Where its state lives. sub incognito_begun makes a ... | `incognito_begun`, `temp_folder` | - | - |
| What it reads from ~/.lzrprf, read only, and ... | `licence_set`, `support_sent`, `support_read` | C11 | `home`, `support`, `profileincog` |
| Every way out removes the folder. The process ... | `leave`, `swept`, `removed` | - | - |
| What macOS could keep, and what was checked: ... | - | - | - |
| - Saved application state (the windows macOS reopens ... | - | - | - |
| - Recent documents. The window opens no document ... | - | - | - |
| - Temporary files. The page container writes no ... | - | C10 | `incognito` |
| - What it does not cover: what sites ... | - | - | - |
| A Tor window is an incognito window that ... | `tor_window_opened` | C17 | - |
| 1. The Tor window opens first. lzrprf says ... | `tor_session_on` | - | `tor` |
| 2. Then its modal opens in it, flown ... | `tor_on` | - | - |
| 3. When Tor is ready (tor on), the ... | - | - | - |
| 4. Stop Tor says tor off; lzrprf asks ... | `tor_session_asked`, `tor_on` | - | `torkeep`, `torstopkeep` |
| 5. Stop Tor answers it: the modal shows ... | `tor_session_end` | - | `tor`, `torstop`, `torflow` |
<!-- index end -->

`lzrprf incognito`, or "New Incognito Window" (Shift-Command-N) in the app menu or the cog
menu, opens a second window of its own whose whole state lives in one folder that is removed
when it ends `[C16]`. It is told apart at a glance: it glows violet instead of cyan, the word
"Incognito" and a mask stand left of the address, and its new tab page says what it keeps and
what it does not.

Where its state lives. `sub incognito_begun` makes a folder `lzrprf-i.<pid>.<12 hex>` with mode
0700 in your own temporary folder: `TMPDIR` when it is a folder of yours that nobody else can
read, else yours under `/private/var/folders/.../T` (`sub temp_folder`). The log of the window,
its tabs, its history and every answer are in the memory of the process behind the window or in
that folder; a search engine chosen there and the bookmarks bar shown or hidden there are held in
memory for that window only.

What it reads from `~/.lzrprf`, read only, and why each: `proven`, `untested` and `selftest.lock`
(no page is shown before the self-test held `[C11]`; an incognito window never runs the test,
because the test writes its result, and says to open a normal window once instead); `home` (the
home page opens); `search` (searches go where you chose); `marksbar` (the bar as you keep it);
`pictures` (pictures from other sites as you keep them); `bookmarks` (your bookmarks open). Everything else of a normal window is not read, and nothing
is written there: the star, the bookmark modal, the import wizard and "make this the home page"
are refused with "An incognito window writes nothing", shown greyed out with that tooltip. The
cogwheel's "Enter licence code..." and "Support request..." only say that an incognito window
keeps no licence code and sends no support request; lzrprf refuses their lines from it too
(`sub licence_set`, `sub support_sent`, `sub support_read`), and `licence` and `support` are
not read. Its closed tabs to reopen are held in memory, as in every window. A tab pulled out of
it opens an incognito window, whose address goes on a pipe and never in the list of processes.
It has no profile: it shows no Profiles icon, is told no profile, and lzrprf refuses every word
of one from it (run `profileincog`).

Every way out removes the folder. The process behind the window removes it in `sub leave`
whether the window was quit, its last window closed, Command-Q pressed or the window's process
ended; it does the same on SIGINT, SIGTERM, SIGHUP and SIGQUIT. A third process, the sweeper,
started in its own session and deaf to those signals, waits until the window's process is gone
and the process behind it has let go of the lock on `held`, then removes the folder too. Only
`kill -9` of all three at once (a crash, a power cut) leaves it; `sub swept`, at every start of
any lzrprf window, removes every `lzrprf-i.*` folder of yours whose window process is gone.
`sub removed` removes nothing whose name is not exactly that form.

What macOS could keep, and what was checked:

- Saved application state (the windows macOS reopens at login, under
  `~/Library/Saved Application State`). The window's container refuses every file write, so
  `osascript` cannot write it; on top of that an incognito window registers, in memory only,
  `NSQuitAlwaysKeepsWindows` false and `ApplePersistenceIgnoreState` true, and sets its window's
  `restorable` to false. Checked on the development Mac on 2026-11-20 after incognito windows were
  run off the screen: that folder holds nothing for `osascript`, `perl` or lzrprf, and
  `~/Library/Caches` and `~/Library/Preferences` hold no `com.apple.osascript` entry.
- Recent documents. The window opens no document and has no `NSDocumentController`, so it adds
  nothing to the recent items list. The list's own folder
  (`~/Library/Application Support/com.apple.sharedfilelist`) is closed to a terminal by macOS
  privacy settings, so that it is unchanged was not read directly.
- Temporary files. The page container writes no file at all `[C10]`, the window's container none,
  and the process behind the window writes into the incognito folder only. `selftest` run
  `incognito` checks that afterwards no `lzrprf-i.<its pid>.*` is left in the temporary folder
  and that every file of the run's lzrprf folder is byte for byte what it was.
- What it does not cover: what sites see (your internet address and what you send them), and the
  macOS unified log, which records process starts and sandbox refusals as for any program.

## The Tor window

A Tor window is an incognito window that Tor alone carries `[C17]`. The onion of a window that is not
one asks lzrprf for a Tor window apart from it (`sub tor_window_opened`); Tor never carries the first.
The order, fixed since H-0073 (Henry, 2026-11-23: turning Tor on used to jump straight to the incognito
window with no animation, because the modal was opened only by a press of the onion in the Tor window
itself, which nobody made there):

1. The Tor window opens first. lzrprf says `startup ready`, the window is put on the screen, and only
   then does `sub tor_session_on` say `torsession connecting` (run `tor` checks that order).
2. Then its modal opens in it, flown out of the onion (`function torShown`; while the window is not on
   the screen yet, it looks again a moment later). Its five stations light from the client's own log
   lines, `tor step N PERCENT WORDS`, read by `sub tor_on`: the real progress of Arti, not a timer.
3. When Tor is ready (`tor on`), the last station flares and the modal stays, with two buttons: OK
   closes it and Tor stays on; Stop Tor. While it connects the buttons are Stop Tor and Hide.
4. Stop Tor says `tor off`; lzrprf asks first (`sub tor_session_asked`), also while Tor is still
   connecting (`sub tor_on`), and the window shows the question in the same modal (`function torAsked`):
   all tabs of this window will be closed, Tor will be disconnected and the incognito window closed.
   Cancel returns to the modal of Tor (runs `torkeep`, `torstopkeep`).
5. Stop Tor answers it: the modal shows the stop on a beam of its own, Tabs, Data, Tor, Window. Each
   station is lit when lzrprf says that step of `sub tor_session_end` is done (`torsession ended`,
   `checked 0 0`, `released`, then its end of the pipe), never before; the window lights at most one each
   0.35 s so a stop done in milliseconds is still seen step by step (`function torPaced`), and closes only
   after the last (runs `tor`, `torstop`, and `torflow`, the modal's own functions run with no window).
