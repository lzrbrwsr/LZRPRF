# Tabs, the home page, bookmarks, search, the lock, redirects

This text was the README section "Tabs, the home page, bookmarks, search, the lock, redirects" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- A reference to `markPlaced`, a function the window text no longer has, was removed.
- References to `homeNameFollowed` and `homePressAt`, and the check `name`, were removed: since
  release 78 the default home is the closed application's scene, and "The home screen" says what
  lzrprf keeps of it.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/window.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| All of this is drawn by lzrprf's window, ... | `outrun` | - | - |
| - Tabs. Each tab keeps its own page ... | `tabbed`, `tab_shown`, `relaid` | C9 | - |
| - Reopening a closed tab. Cmd-Shift-T, or "Reopen ... | `tab_reopened`, `closed_kept` | C4 C5 | - |
| - A tab pulled out. A tab dragged ... | `tab_out`, `pulled_command`, `opened_with`, `started` | C4 C5 | `incognito`, `taboutmost`, `tabslots` |
| - Dragging a tab moves the tab, never ... | - | - | `window`, `tabslots` |
| - Zoom. Cmd-plus (or Cmd-=), Cmd-minus and Cmd-0, ... | `viewing`, `relaid` | - | - |
| - Find in page. Cmd-F opens a small ... | - | - | - |
| - The home page. The cogwheel's "Make current ... | `menu`, `home` | C4 C5 | - |
| - Bookmarks. The star opens lzrprf's own modal: ... | `marks_read`, `mark_saved`, `pictures_elsewhere`, `marks_into_bar`, `order_set` | C4 | - |
| - Importing bookmarks. The cogwheel's "Import bookmarks..." opens ... | `import_profile_name`, `plain_name`, `import_reader`, `lz4_block`, `plist_binary`, `import_kept`, `import_allowed`, `import_kept_out`, `import_unshown`, `import_html`, `address`, `mark_written`, `import_plan`, `import_go` | C15 C10 C4 | `importnames`, `importunnamed` |
| - Address suggestions. While you type in the ... | - | C4 | - |
| - No footer. Nothing stands at the window's ... | `parts_told`, `parts_set`, `parts_fetched`, `contained` | - | - |
| - Clearing. "Clear browsing history" empties the addresses ... | - | C7 | - |
| - Redirects. An answer 301, 302, 303, 307 ... | `redirected`, `asked`, `unfit`, `redirect_noted`, `redirects_decide` | C7 | - |
| - The game page opens LZRDFNDR. The program's ... | `live_answered` | - | `liveopen`, `liveopenno` |
| - LZRDFNDR's satellite in the minigame. The Other ... | `game_helper_set` | - | `gamehelper`, `gamehelperincognito` |
| - LZRDFNDR's panel opens at once. A press ... | `tool_shown` | - | - |
| - Undo. The bar and the modal's fields ... | - | - | - |
| - Presses and keys of a modal and ... | - | - | `welcomeclick`, `welcomekey` |
| - Back, forward, reload. The arrows left of ... | `navigated` | C4 | - |
| - The home screen. An empty tab shows ... | `home_shown`, `paired`, `contained`, `live_answered` | C9 C18 | - |
| - Search. Words typed into the bar that ... | `typed`, `engine_fit` | C4 | - |
| - The cogwheel's menu. A panel of the ... | - | - | `cogfits`, `cogkeys` |
| - The support member licence. The cogwheel's "Enter ... | `licence_read`, `licence_checked`, `signed`, `licence_set`, `licence_removed` | - | - |
| - A support or feature request. The cogwheel's ... | `support_sent`, `fixed`, `support_read`, `support_forgot` | C4 C7 | - |
| - In an incognito window neither the licence ... | - | C16 | - |
| - Keys. Chrome's keys for what LZRBRWSR has: ... | - | - | - |
| - The bookmarks page. The cogwheel's "Bookmarks", the ... | - | - | - |
| - The lock. Pointing at the lock in ... | `secured` | - | - |
<!-- index end -->

All of this is drawn by lzrprf's window, in strips of its own above the page where no page
draws: the strip of tabs on top, then back, forward and reload, the bar with its lock and star,
and the cogwheel, then the bookmarks bar when you chose to show it. The look is lzrprf's too,
the neon laser: near black glass inside a thin glowing cyan edge, straight beams of light, light
grey line icons and the system's own face, the logo set wide. It is drawn on the processor by
the window alone, and nothing in it comes from a page. The glass and its glowing edge are
layers: the edge is drawn once, as nine stretchable pieces, so a resize moves them and draws
nothing. While the window is resized the page keeps the size it was drawn at, and the part the
window grew shows the page's own background colour at once (the colour of the page's first
rectangle, or what its right edge shows), never white; the page is fitted once, at the
release. A drag that pauses for 120 ms tells lzrprf its size already, so the page is laid out
at that width while the button is held, and a release there costs only the swap; a newer
width ends a layout still running for an older one, one run at a time (`sub outrun`). The
view the page's layers stand in is set to the laid page's size at every fit (`layersFitted`):
layers that arrive while the button is held, before the fit, would otherwise keep the size
before, and masked to it the home page showed nothing once the window was made larger again.

- **Tabs.** Each tab keeps its own page as lzrprf keeps the page shown: its address, the
  answer, the style sheets it was laid out with and its pictures, its title, the addresses it
  went to and lzrprf's last words in it (`sub tabbed`). A tab is chosen on the press, also
  while lzrprf is busy with a page: the window shows the drawing it kept of that tab at once
  (it keeps one for each of the 8 tabs shown last), and lzrprf is told when it is free
  (`sub tab_shown`). A tab with no kept drawing is sent the list lzrprf kept of its page, and
  only a page kept at another width is laid out again (`sub relaid`): nothing is fetched and
  nothing is written in the log. At most 32 tabs; closing the last leaves one empty tab. Cmd-T opens a tab, Cmd-W closes
  one. A tab's title is the page's `=title` line, checked `[C9]`.
- **Reopening a closed tab.** Cmd-Shift-T, or "Reopen Closed Tab" in the Tab menu, brings back
  the tab closed last in this window, at its old place (or last, when fewer tabs stand now),
  and chooses it. The window says only `tab reopen` (`sub tab_reopened`). lzrprf holds the last
  ten closed tabs, the newest first, in the memory of its process and nowhere else, so an
  incognito window writes nothing for them either (`sub closed_kept`). The two closed last keep
  their page and come back with nothing fetched; an older one keeps its address, its title and
  the addresses it went to, and its address is visited again, written in the log first `[C4]`
  `[C5]`. A tab with no address is not held, and "Clear browsing history" forgets them all.
- **A tab pulled out.** A tab dragged more than 54 points above or below where it was pressed,
  or out past any side of the window, leaves the strip and is drawn as the small window it
  becomes. Let go there, it opens as a window of its own, of this window's size, placed so the tab stays under the pointer: the
  window says `tab out N X Y W H`, and lzrprf starts a second lzrprf as it was started itself,
  `perl lzrprf run --open "X Y W H" /path/to/program` (`incognito` from an incognito window,
  and `--profile ID` before `--open` from a profile's window, so the tab stays in its profile),
  which goes through every start check of its own (`sub tab_out`, `sub pulled_command`). The
  tab's address goes to it as one line on its standard input, never as an argument: every user
  of this computer can read the arguments of a process in the list of processes for as long as
  it runs, which would break what an incognito window promises. The new lzrprf checks that line
  as a typed address (`sub opened_with`) and writes it, as `start ADDRESS`, into the pipe its
  process behind the window reads, before the window is made, so the window neither says it
  nor reads it (`sub started`). Its first page is that address, written in the log first as
  `you pulled a tab out into this window` `[C4]` `[C5]`; only the address goes, so the page is
  fetched again and the tab's history stays behind. The tab then closes in the first window,
  with the line `you pulled a tab out into a new window`, and is not one of the closed tabs to
  reopen. When no process could be started, the tab stays. One window opens at most 32
  windows from its tabs and profiles together in its life, as many as it holds tabs, so a window process that was
  taken over cannot have lzrprf start processes without end: the 33rd tab pulled out stays,
  and lzrprf says why (run `taboutmost`). The only tab of a window is drawn away so too while the
  window stays; let go away, that tab already is a window of its own, so the window itself is put
  there, once, at the release: its page goes with it, neither fetched nor laid out again, and no
  `tab out` is said (run `tabslots`).
- **Dragging a tab moves the tab, never the window** (HC-0856). The strip of tabs, the bar's row,
  the bookmarks bar and the frame each say no to macOS moving the window from a press on them
  (`mouseDownCanMoveWindow`): the strip stands in the window's title bar, where a view of AppKit's
  own lets macOS move the window from any press, so a tab dragged along the strip moved the whole
  window with it. The window is moved only where nothing else is pressed: beside the tabs, beside
  the bar's buttons and pill, beside the bookmarks, and on the frame; pressed twice there, it
  zooms (run `window`, its line `winmove`, and `tabslots`).
- **Zoom.** Cmd-plus (or Cmd-=), Cmd-minus and Cmd-0, in the View menu, zoom the page of the
  tab shown in steps of 50, 67, 80, 90, 100, 110, 125, 150, 175 and 200 percent, held at the
  ends; Cmd-0 goes back to 100. Each tab has its own zoom, held in the window's memory and not
  kept. The page is laid out again for the width the zoom means, the page's room divided by
  it, on the road every new size of the window takes (`view W H`, `sub viewing`,
  `sub relaid`): nothing is fetched and nothing is written in the log. lzrprf lays a page only
  at widths in steps of 160 points, between 320 and 1600, so a site cannot read the window's
  exact size, and the window draws the laid page scaled to fill its room. So a step can be laid
  out as its neighbour is: at some widths 110 percent is laid as 100 is, and only drawn larger.
  Nothing says the zoom in words: the page's size shows it.
- **Find in page.** Cmd-F opens a small bar over the top right corner of the page, with its
  field, which match of how many is shown (`3 of 17`), previous, next and close. It looks
  through the text of the page shown, capitals and small letters alike, marks every match (at
  most 1000) and the current one more strongly, and scrolls to it. Return or Cmd-G goes to the
  next, Shift-Return or Cmd-Shift-G to the one before, round from the last to the first; Escape
  closes it. A match inside one piece of text as the page laid it out is found; one that runs
  across two pieces is not. It is the window's alone: it says nothing to lzrprf, fetches
  nothing and writes nothing.
- **The home page.** The cogwheel's "Make current page the home page" keeps the address of the
  tab in one plain file of yours, `~/.lzrprf/home`, one line (`sub menu`, `sub home`). A new
  tab and each new window open it, as if it had been typed: its line is in the log first `[C4]`
  `[C5]`. A link at that name, a file that is not yours or a line that is no address lzrprf
  fetches opens nothing.
  An empty tab, with no home page set, shows the default home, which is not lzrprf's: see "The
  home screen" below.
- **Bookmarks.** The star opens lzrprf's own modal: Name, Address, Folder, New folder. A
  bookmark is one plain file in `~/.lzrprf/bookmarks`, a folder of yours, `NAME.mark` with
  two lines, its name and its address; a folder of bookmarks is a real folder, at most 4 deep,
  each name letters, digits, space, dot, underscore and hyphen, not beginning with a dot or a
  space; at most 1000 are read (`sub marks_read`, `sub mark_saved`). A link, a file that is not
  yours and an address lzrprf does not fetch are passed over; a bookmarks folder that is a link
  is not read and nothing is written through it. The star of a page you bookmarked opens the
  same modal to change it or Remove it. Opening a bookmark is a visit like a typed one `[C4]`.
  The cogwheel's "Show bookmarks bar" ("Hide bookmarks bar" while the bar is shown; each toggle
  says what pressing it does now) is kept in `~/.lzrprf/marksbar`. "Block pictures from other
  sites" ("Allow pictures from other sites" while they are blocked; allowed until you block
  them) is kept in `~/.lzrprf/pictures`, and read through `sub pictures_elsewhere` alone; an
  incognito window holds it in its memory. The bar shows one folder,
  `Bookmarks bar` (Chrome's name for it), which the star's modal offers first; the first time the
  folder is read without it, the bookmarks at its top, which the bar showed until then, move into it
  by a change of name each (`sub marks_into_bar`).
  A folder's order is
  kept in a file `.order` in it, its names one a line (`sub order_set`): the window shows every
  folder in that order, everywhere (the bar, the folder menus, the bookmarks page), and a new
  bookmark is added at the end. What is in a folder and not named in it comes after, by name.
- **Importing bookmarks.** The cogwheel's "Import bookmarks..." opens one modal. Choose a
  browser: the ones on this Mac, of Chrome, Edge, Brave, Firefox, Safari and Vivaldi, and last
  "HTML file". Then its profiles are shown, always as a list, by the names in Chromium's
  `Local State` or Firefox's `profiles.ini`. A Chromium browser's are shown as its own profile
  picker shows them, sorted by name: the name, or the account's given or full name while the
  name is the default one ("Person 1", "Your Chrome"), with the account's address in grey under
  it, and the folder only where two are alike (`sub import_profile_name`). A `Local State` is
  often megabytes on one line, so only its member `profile` is decoded (`sub
  import_json_member`), and one byte that is no UTF-8 or half an emoji in it becomes U+FFFD
  instead of losing every name; a zero-width joiner is kept only inside an emoji sequence, so
  a joiner inside a word cannot make two names look alike (`sub plain_name`). When macOS lets the reader see the profiles' files and not read
  `Local State`, the Open panel asks for the browser's folder before the list, so that after
  Allow the names are read with the rest; names that still cannot be read are never silent:
  the profiles are shown by their folders under one line that says so, and the log says why
  and that the folders were looked for as `Default` and `Profile 1` to `Profile 255`
  (runs `importnames`, `importunnamed`). Choosing one imports it at once, and the strip
  says in one line how many came in, and of the rest how many were there already, appeared
  twice in it, are not addresses lzrprf opens, or did not fit; at most 99 profiles are listed
  and the rest said. Another browser's files are read by the reader alone `[C15]`: a fresh system perl running
  the lines of `$IMPORT_READER`, started by `sub import_reader` in the container `$CONTAINER`
  with `$IMPORT_ALLOWED` on top. That container lets it read, under your home folder, each
  Chromium browser's `Local State` and `<profile>/Bookmarks`, Firefox's `profiles.ini` and a
  profile's `bookmarkbackups/*.jsonlz4` (and the names in that folder), Safari's
  `Bookmarks.plist`, and look whether each browser's folder, a profile's folder and the folders
  above them are there: one or two levels inside a browser's folder it may look at (stat) a
  folder or a link and nothing else, so a file there such as `places.sqlite` it cannot even see
  unless it is one of the files above; no other file of yours, no network, no writing, no
  program but itself.
  It reads a plain file of yours of one name: a link, a hard link (which may be any file of
  yours) and a file in a folder that is a link, even one that leads back inside the browser's
  own folder, are refused and said as such, whether or not the read went through; a file's own
  permissions (EACCES) are said apart from macOS keeping a folder out (EPERM). A home folder
  whose path holds a character the reader does not take, or a reader that cannot start, is
  said in one sentence and written in the log. So whatever macOS lets LZRBRWSR read, lzrprf
  reads of another browser these files and nothing else; `selftest` asks the reader for a
  profile's `History` and `Login Data` beside its bookmarks and is refused. lzrprf parses what
  the reader hands back: Chromium's JSON with the JSON code that comes with the system's perl,
  Firefox's newest backup with an LZ4 block decoder of its own (`sub lz4_block`, at most
  64 MiB unpacked), Safari's binary plist with a reader of its own (`sub plist_binary`, which
  reads no object that holds itself and stops at a fixed budget of work: what it read within
  the budget is imported, and the strip says the rest was not read).
  Firefox's `places.sqlite` would need `sqlite3` and is not read: its own backups hold the same
  bookmarks. macOS asks nobody about these folders: from macOS 27 it keeps Chrome's and
  Firefox's from every app (its Application Support protection, with no prompt an app can ask
  for), and Safari's since long before unless the app has Full Disk Access. What lzrprf
  tries, short of Full Disk Access, is your choice in the system's Open panel: when the reader
  is kept out of Chrome, Edge, Brave, Vivaldi or Firefox, the window opens that panel at the
  browser's own folder, its button "Allow" (`function allowPanel`), once a browser in an import
  (`sub import_kept`); Safari's are said kept out at once, as only Full Disk Access lets them
  through. Allow on exactly that folder has the reader try again at once (`sub import_allowed`);
  another folder (also one whose name has a character past ASCII) is refused in one sentence;
  Cancel ends in the sentence of `sub import_kept_out`, which says to switch LZRBRWSR on under
  Privacy & Security, Files & Folders if it is listed there. Closing the wizard drops a panel
  asked for, so a late answer opens nothing. Allow hands lzrprf a word and nothing more: the
  reader's container is the same, and what can change is what macOS lets through. **What is
  proven and what is not:** `selftest` proves the reader's container, its refusals and the
  wizard's lines, with the panel stood in for. Only a real Mac can show whether the panel opens
  from the window's container at all, whether Allow or the Files & Folders switch lets the
  reader through (the grant may go to the window's process and not to the reader), and whether
  a switch survives an update of an app signed ad hoc. So the panel and that switch are an
  attempt, worded as one, and a panel that could not be shown, or closed before anyone could
  choose, is one line of the window's log (`sub import_unshown`), so that a real run says
  which. The window's container may know of those folders that they are there, so that the
  panel can open at one, and nothing more. lzrprf never asks for Full Disk Access and never
  opens System Settings, and an
  HTML file the browser exported still works: the "HTML file" choice offers the bookmarks files
  lzrprf finds in Downloads, Desktop and Documents and takes a path you type in your home
  folder (`sub import_html`); lzrprf reads that file itself. The window cannot show a file
  picker: its container reads nothing under your home folder `[C10]`. The source's bookmarks
  bar goes into "Bookmarks bar", folders and all, after what it holds; each of its other top
  folders keeps its own name at the top ("Other bookmarks", "Mobile bookmarks", "Bookmarks
  menu", "Reading List"); each folder in the source's order, bookmarks and folders mixed, kept
  in its `.order`. A Firefox HTML export gives the layout its own backups give. A bookmark
  whose folder and address are there already is passed over, so importing a profile twice adds
  nothing twice; folder names are compared without case, as the disk compares them, and a
  folder there already keeps its name; addresses are compared as they are, since two that
  differ in case may be two pages. Each bookmark gets the checks one you add gets:
  its name through `sub plain_name`, its address through `sub address` (one lzrprf does not
  fetch is skipped and counted), at most 1000 in all, folders at most 4 deep and at most
  1000 folders, none made without a bookmark in it (what does not fit is left out and
  counted), each written by `sub mark_written` (`sub import_plan`,
  `sub import_go`). Nothing imported is fetched `[C4]`.
- **Address suggestions.** While you type in the bar, a list under it suggests pages shown in
  this window and your bookmarks: the start of a host first, then the start of a title or of a
  word in it, then anything that contains what you typed, at most 8 (`function suggested` in
  the window). The arrow keys move, Return or a click opens, Escape closes. The pages come from
  lzrprf as they are shown (`history add`), held in the window's memory only, at most 500, and
  cleared with "Clear browsing history": nothing of them is written to the disk. Opening one is
  a visit like a typed address `[C4]`.
- **No footer.** Nothing stands at the window's foot but a question of lzrprf's while it is
  asked; between questions the page reaches down to the edge. How the site answered the page
  shown, its status, the time all of it took and how much came (`200 · 412 ms · 89 kB`), is the
  first row of the panel the lock left of the bar opens (`secure brief`); everything lzrprf says
  is a line of the log, and a tip is the tooltip of its row. Nothing is written under the address
  bar (Henry, 2026-11-24: no note there, "we dont need that information"); while lzrprf works a thin
  line grows along the bar's lower edge (`function loadingSet`, window test `note`). LZRDFNDR's
  icon, then Tor's, stand just right of the bar, left of the
  Profiles icon and the cogwheel (window test `footer`); each only while its part is installed
  (`function partOn`, from lzrprf's `parts on ...`, `sub parts_told`). "Add or remove LZR modules..."
  in the cogwheel's menu opens a modal with a box for each part: LZRBRWSR, ticked and greyed (the
  window and these settings are its own), LZRDFNDR, LZRTRMNL, LZRTNNL and LZRGM. Once a box differs
  from what is installed, "Restart with these modules" says `parts set NAME ...`: lzrprf writes the
  record the installer writes (`sub parts_set`, `~/.lzrprf/parts`), takes away the program of a part
  left out, and LZRBRWSR starts again with the new set; a part whose program is not there is added
  only through the signed road of an update (`sub parts_fetched`). An incognito window changes no
  module. LZRTRMNL and LZRGM left out are not on the home page either (`sub contained`). "Show log" in the cogwheel's menu opens
  the log on a page of its own over the page shown, which stays as it is under it: this
  window's lines, the newest first, then the last of the log kept on this computer; its Close
  button, "Hide log" or the back arrow closes it again. The last row of the lock's panel, "What
  this page is made of", opens, in a panel of its own over the page, the list the application gave of what
  the page is made of, each thing with its version and whether the application says it
  supports it, under the sentence that lzrprf checked the form of that list and not whether it
  is true.
- **Clearing.** "Clear browsing history" empties the addresses the tabs went to; the log is
  cleared by its own button and by nothing else. Clearing the sessions also drops every page
  lzrprf keeps for a tab. lzrprf sends no cookie and keeps none `[C7]`, so no login was kept by
  it either way.
- **Redirects.** An answer 301, 302, 303, 307 or 308 is never laid out and never followed by
  `curl` `[C7]`. lzrprf reads its `Location` itself, in plain characters only, resolves it
  against the address, and asks in its own modal, with the status, both addresses and Cancel
  first (`sub redirected`, `sub asked`). Proceed is a new visit, with every check of a typed
  address and its line in the log first. An address lzrprf does not fetch (plain http, a host
  that is a bare number, another port) gets Cancel alone, and the modal says why in plain words
  (`sub unfit`). A page opened from a bookmark gets a third button, "Proceed and update
  bookmark". One redirect a visit is followed without asking: to the same https address with
  `www.` put in front of its host or taken off, the same path and query, written in the log as
  one line first (`example.com redirected to www.example.com (301); followed, the same site`).
  Every redirect put to you is listed in LZRDFNDR's third tab, Redirects, with your answer; a
  Proceed or Cancel kept there answers that same redirect without asking, in this window, and
  Forget asks again (`sub redirect_noted`, `sub redirects_decide`). It is kept in memory only.
- **The game page opens LZRDFNDR.** The program's own page https://lzrbrwsr.com/play has
  Activate LZRDFNDR beside its Start button, Setup LZRDFNDR once the satellite is active. A press
  sends the page to one address, https://lzrbrwsr.com/play/lzrdfndr, which lzrprf never fetches:
  asked by the game page alone, it tells the window `tool show`, and the window opens LZRDFNDR's
  panel on On Your Computer as a press on its icon does; the page stays (`sub live_answered`,
  runs `liveopen` and `liveopenno`). From any other page that address is followed as any other.
- **LZRDFNDR's satellite in the minigame.** The Other tab of LZRDFNDR's panel has a switch, On or
  Off, for the satellite that flies in the home page's minigame and shoots every saucer before it
  reaches the name. The window says `game helper on` or `off`; lzrprf keeps the choice in one plain
  file of yours, `gamehelper` (an incognito window in its memory alone), tells the window
  `game helper 1` or `0` at every start, and starts the home page with it (`LZRPRF_HOME` is
  `home satellite` while it is on). A home page kept running with the other choice is ended and shown
  again, so Off is off at once. Activate LZRDFNDR in the game switches it on too (`sub game_helper_set`,
  runs `gamehelper` and `gamehelperincognito`).
- **LZRDFNDR's panel opens at once.** A press on its icon opens the panel in the same frame, with the
  last list read (or none yet) held busy, "Reading this computer", until lzrprf's new list replaces it;
  nothing can be ticked against an old look, and the Other tab works meanwhile (`sub tool_shown`).
  Its flight out of the icon takes its first frame in the press itself, from a quarter picture of the
  panel while it is still small, then a whole one: about 26 ms from press to movement, where it was
  150 ms and more behind lzrprf's answer.
- **Undo.** The bar and the modal's fields undo and redo typing step by step: Cmd-Z and
  Cmd-Shift-Z, in an Edit menu that also cuts, copies, pastes and selects all.
- **Presses and keys of a modal and the home page.** Every press goes straight to the view under
  it. The home page's lasers see a press from the window's own views (the frame, the home page, the
  tabs, the belt round the bar, the cogwheel, Profiles, the star, the bookmarks bar), each before its
  own handling of it; a control of the system's own (the text of the bar, the Log icon) takes its
  press alone. The home page also takes the press that brings the window to the front, as the
  lasers saw it before. Nothing of the window depends on what a block hands back: release 75 saw each press
  through a monitor of the application's events, whose block the bridge answers with its own
  wrapper of the event, which AppKit cannot read, so every press of the window was lost and the
  welcome's Got it could not be pressed. Nor does any class of the window take `sendEvent:`
  (release 74's hang). A modal has a way out from the keyboard: Return presses its button where it
  has one alone (Got it, Close, Cancel), and Escape the one that closes it or steps back (Cancel,
  Close, Got it, Hide, Back), in lzrprf's own questions (Scripts, Redirect) their first, the answer
  when nobody answers. Return never presses one of several buttons, whose last may grant, clear or
  choose. The selftest presses the real window, kept unseen, by putting presses and keys on the
  application's queue as the system does (`welcomeclick`, `welcomekey`).
- **Back, forward, reload.** The arrows left of the bar, and Cmd-[, Cmd-] and Cmd-R, walk the
  addresses the tab went to (`sub navigated`). Each step is a new visit to that address, with
  every check of a typed one and its line in the log first (`you went back to`, `you reloaded`)
  `[C4]`: lzrprf keeps no copy of an earlier page to show instead. A redirect followed on the way
  takes the place of the address it came from, so back does not land on it again.
- **The home screen.** An empty tab shows the default home of the closed application, and
  lzrprf holds none of its drawing: its words, shapes, buttons and minigame are a scene of the
  application's own, compiled into its program, since release 78. lzrprf starts it only when the
  release file says `home local`, as a page kept running in the page container with no fetch
  (`sub home_shown`, the address `https://lzrbrwsr.invalid/_home`, which is never fetched), and only
  while the program is the file whose SHA-256 the release file names on its line `file`: checked
  at the start (`sub paired`) and read again before the run (`sub contained`). Its lines and layers
  are checked as every page's are `[C9]` `[C18]`, every request it makes is refused, and an
  address it asks to follow is not followed: four fixed local words alone (search, bookmarks, the
  open tabs, a new tab) reach the window, within a second of a press handed to it, and the window
  does what its own button does, and its minigame's LZRDFNDR button opens LZRDFNDR's panel
  (`sub live_answered`). The window keeps a picture of the first
  scene in its memory to show in a new tab until the scene is made again, and draws the beam from
  a pressed button to the bar or the new tab itself, since nothing of a page may draw over the
  bar. Nothing on it is fetched.
- **Search.** Words typed into the bar that are no address (no `://`, and a space or no dot)
  go to the search engine you chose: Brave, DuckDuckGo, Google, or one of your own (`sub typed`).
  Nothing is sent before you choose: the first search, and the home screen's search button,
  ask in lzrprf's modal. A search engine of your own is given as an address with `%s` once where
  your words go, for example `https://search.example.com/search?q=%s`; it must be https, a host
  by its name, port 443, plain characters without a space, and lzrprf percent-encodes your words
  into it (`sub engine_fit`). The choice is one line in one plain file of yours,
  `~/.lzrprf/search`; the cogwheel's "Search engine..." changes it. A search is a visit like a
  typed address, written in the log first as `you searched with` `[C4]`.
- **The cogwheel's menu.** A panel of the window's own glass, opened under the cogwheel inside the
  window, each item with the keys that do it too; a press outside it closes it and reaches nothing.
  In a window too low for it its rows grow lower for that opening, never under 22 points, and
  it rises over the bar, so every row stays inside the window and is pressed where it is drawn
  (`function cogPlaced`; run `cogfits` checks it at the window's least size). When its rows do
  not fit even at 22 points, as a long Profiles list in a low window, the box stays inside the
  window and scrolls: the wheel, the arrow keys, Page Up and Page Down, Home and End move it,
  a small chevron marks an edge with rows past it and a press on it shows one row more, and a
  press and the lit row are the row drawn there (`function cogScrolled`); `cogfits` checks 16
  profiles at the least size. The box takes those keys, pressed with no Control, Option or
  Command and not while an input method composes a word, when the window offers them to its
  views as key equivalents, and the keyboard never leaves the bar (`function cogKeyed`, run
  `cogkeys`, which shows the box's side under a plain view). Whether a window offers plain keys
  there while the bar is typed into only a real Mac shows; if it does not, the keys do nothing
  and the wheel and the chevrons still scroll. A key watch through NSEvent is not used: a
  JavaScript block cannot hand the event back to AppKit.
- **The support member licence.** The cogwheel's "Enter licence code..." opens one field for
  the code you got when you bought the browser: 120 letters and digits, in 24 groups of 5.
  lzrprf reads it with case, spaces and dashes left aside, O read as 0 and I and L as 1, as 75
  bytes in Crockford's base32: one byte its kind (17, a support member), two the month it was
  bought in, eight its own number, and 64 an Ed25519 signature over the words
  `LZRBRWSR-LICENCE-1` and the eleven bytes before it (`sub licence_read`). lzrprf checks that
  signature on this Mac in plain perl, with the system's `Math::BigInt` and `Digest::SHA`, and
  fetches nothing for it (`sub licence_checked`, `sub signed`). In this release lzrprf holds no
  public key yet (`$LICENCE_KEY` is `ed25519 none`), so a code is checked here by its form, and
  by its signature where a support request goes; the window says which. A code that checks is
  kept in one plain file of yours, `~/.lzrprf/licence`, readable by you alone, and the log says
  that a code was entered and holds none of it (`sub licence_set`). With a code kept, the item
  says since when the browser is a support member's, and its panel removes the code and its
  file (`sub licence_removed`). A support request you send then carries the code, so it is
  answered first.
- **A support or feature request.** The cogwheel's "Support request..." opens a box for your
  words: what went wrong, or what you would like the browser to do. Before Send the panel says
  where it goes and all that goes: your words; one line with the release number; your licence
  code, only when one is kept (the panel then says that the code ties the request to your
  purchase, and that removing the code first sends it without; with no code it says that the
  request is sent anonymously); and a picture of this window, only when you tick it, shown
  small while it is ticked. The picture is the window's own drawing of itself, made when the
  panel opens, never a capture of the screen, and it shows what the window shows: the page in
  it, and the address in its bar too. Nothing else goes: no address of a page besides what the
  picture shows, no history, no name of this Mac or of you; the host sees your internet
  address, as every site does. The request is one POST of JSON to the one
  address the application's release file names in a line `support https://...`, and to no
  other `[C4]` `[C7]`. It goes as every fixed request goes: its line in the log first, through
  the one place that connects, or through Tor while Tor is on (`sub support_sent`,
  `sub fixed`). The log says that a request was sent and what went with it, never its words.
  The answer names the request's reference and a key, which are kept in one plain file of
  yours, `~/.lzrprf/support`. "Read the answer" asks for the replies only when you press it: a
  GET of the reference under the support address, with the key in a line `Authorization` that
  `curl` reads on its input, so no list of processes shows it (`sub support_read`). The replies
  are shown as text and nothing in them is acted on. A request sent later replaces the one
  kept, and "Forget it" removes the file (`sub support_forgot`). The release file of this
  release names no support address yet, so the item is switched off and says why.
- **In an incognito window** neither the licence nor a support request is offered: both keep
  something `[C16]`. The two items only say why, and lzrprf refuses their lines from such a
  window. A tab pulled out of an incognito window opens an incognito window.
- **Keys.** Chrome's keys for what LZRBRWSR has: Cmd-L, Cmd-[, Cmd-], Cmd-R, Cmd-T, Cmd-W, Cmd-D
  (bookmark the page), Cmd-Shift-B (the bookmarks bar), Cmd-Option-B (the bookmarks page),
  Cmd-Shift-Delete (clear history), Cmd-Comma (the cogwheel's menu), Cmd-1 to Cmd-8 and Cmd-9
  (a tab, the last tab), Ctrl-Tab and Ctrl-Shift-Tab, Cmd-Option-Right and Left (the next and the
  previous tab), Cmd-Shift-A (the tabs page), Cmd-Shift-T (reopen a closed tab), Cmd-F, Cmd-G
  and Cmd-Shift-G (find in the page), Cmd-plus, Cmd-minus and Cmd-0 (zoom). Each does what its
  button does, and only then.
- **The bookmarks page.** The cogwheel's "Bookmarks", the home screen's button and Cmd-Option-B
  list every bookmark by folder; the back arrow returns to the page.
- **The lock.** Pointing at the lock in the bar, or pressing it to keep it open, shows what
  lzrprf knows of the page shown (`sub secured`): the address, the server's IP address it
  connected to, the encryption, the answer's status line, that no cookie was sent or kept, every
  redirect on the way here and who followed it, and each certificate the server presented (up to
  6): subject, issuer, valid from and until, serial number, signature, public key and the names
  it covers. The certificates are as `curl` read them in the same connection that fetched the
  page; nothing is fetched to show them.
