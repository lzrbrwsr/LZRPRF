# Profiles

This text was the README section "Profiles" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/profiles.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| A profile is a browser of its own ... | - | - | - |
| Where each lives. The first profile is the ... | `profile_new`, `profile_renamed` | - | `profilenone` |
| What is per profile, each in that profile's ... | - | - | `home`, `tor`, `profiletwo`, `profilefirst` |
| What belongs to the installation, and stays in ... | - | - | `support` |
| A profile's window is its own lzrprf, started ... | `profile_window`, `profile_command`, `profile_held`, `first_held` | - | `profiletwo`, `profilefirst`, `profilelate`, `profilewindows` |
| Bounds, each a declared constant in lzrprf. There ... | `profile_fit` | - | `profilemost`, `profilenew` |
| Removing a profile asks once, in the strip, ... | `profile_removed` | - | `profileremove` |
| The window's words, each checked by lzrprf as ... | `profile_folder`, `profiles_told` | - | `profilehostile`, `profilenew` |
| Making, renaming and removing a profile each take ... | `profiles_locked`, `profiles_swept` | - | `profileremove` |
| "Close and restart" after an update opens the ... | `restarted` | - | - |
| An incognito window belongs to no profile. It ... | `incognito_opened` | - | `profileincog`, `profileincogtwo`, `profileincogbehind`, `untestedincog`, `profilegone` |
| In a terminal, perl lzrprf profiles prints each ... | - | - | - |
| Connected sign-ins (release 77, the owner's order of ... | `sso_told`, `sso_connect`, `sso_heard`, `sso_written`, `sso_cookie`, `sso_remove` | C7 C4 C16 C17 | `ssoconnect`, `livesso`, `ssokept`, `ssoremove`, `ssoincog`, `ssotor` |
| What is left for a later part, and ... | - | - | - |
<!-- index end -->

A profile is a browser of its own on the same Mac: its own bookmarks, history, log, home page
and search, kept apart from every other profile. The Profiles icon, a head and shoulders left of
the cogwheel, opens the list. The window's own profile is drawn in green and marked "this
window"; a profile with a window open says "open". Pressing another profile opens it in a new
window. "New profile..." asks for a name, makes the profile and opens it. "Rename or remove..."
turns each row into a press that opens the same field for that profile, with Rename and, for a
profile that may go, Remove. The cogwheel's "Profiles..." opens the same list.

Where each lives. The first profile is the state folder itself, `~/.lzrprf`, exactly as it was
before there were profiles: nothing is moved, and an installed browser sees no change and gets no
new file until a second profile is made or the first is renamed (run `profilenone`). Every other
profile is a folder `~/.lzrprf/profiles/ID`, mode 700, readable by you alone. ID is 12 hex
digits lzrprf draws from `/dev/urandom` when it makes the profile, and never anything typed
(`sub profile_new`). Its name is the one plain file `name` in that folder; the first profile's
name, once you give it one, is the file `profiles/first` (`sub profile_renamed`).

What is per profile, each in that profile's folder: `keep`, the log and its locks, `home`,
`search`, the folder `bookmarks`, `marksbar`, `pictures`, LZRTRMNL's saved tabs and views `trmnl`, the window's frame, Tor's folder `tor`, and the
folders `tries.NUMBER` and `way.NUMBER` while its window runs. History, the closed tabs to reopen
and each tab's zoom are held in the memory of the window's own process, and every profile's
window is a process of its own, so they are per profile too. A profile's window reads and writes
no file of another profile: run `profiletwo` hashes every file of the first profile before and
after a second profile's window opens its home page, a page and a bookmark, and run
`profilefirst` does the same the other way round. The one thing a window reads of another
profile is its name, for the list.

What belongs to the installation, and stays in `~/.lzrprf` for every profile alike: the release
file and the look for a newer release with your answer (`look`), an installer and its lines
(`install.txt`), the welcome (`welcomed`), the licence code (`licence`), the support request's
reference (`support`), the self-test's result (`proven`, `untested`, `selftest.txt`,
`selftest.lock`), and the jobs the application's tool switched off (`quieted`). These are facts
about this Mac or this copy of LZRBRWSR, not about where you went.

A profile's window is its own lzrprf, started as a pulled tab's window is
(`sub profile_window`, `sub profile_command`):
`perl lzrprf run --profile ID /path/to/program`. The id is the only word of a profile on a
command line, because every user of this computer can read the list of processes; the name never
goes on one. The window holds a shared lock on the file `inuse` in its folder for as long as it
lives (`sub profile_held`). The first profile's windows hold the same lock on `~/.lzrprf/inuse`,
but only once the folder of profiles is there, so an installed browser with one profile still
gets no new file; from then on the first profile shows as "open" in another window's list too
(runs `profiletwo`, `profilefirst`). A first profile's window that started before the folder
was made takes the lock the first time its own list is told or a profile word reaches it, once
(`sub first_held`, run `profilelate`); until then the other windows list the first profile as
shut. A tab pulled out of a profile's window opens in the same profile. One
window opens at most 32 windows from its tabs and profiles together in its life, the bound of a
pulled tab (run `profilewindows`).

Bounds, each a declared constant in `lzrprf`. There are at most 16 profiles, the first among
them, so a window process that was taken over cannot fill the disk with folders; the 17th is
refused with "There are 16 profiles, the most there may be. Remove one to make another." (run
`profilemost`). A name is at most 32 characters long, of plain text with no control or format
character, its spaces made single; it is refused otherwise, and two names that differ only in
capitals are refused as the same name (`sub profile_fit`, run `profilenew`).

Removing a profile asks once, in the strip, by lzrprf itself and not by the window: "Remove the
profile NAME? Its bookmarks, history, log, home page, search address and all that is kept for it
are deleted from this Mac. This cannot be undone." Remove then deletes exactly that profile's
folder and nothing else; a link inside it is removed and never followed. The first profile is
never removed, since its folder also holds what belongs to the installation, and neither is a
profile with a window open, this window's own among them (`sub profile_removed`, run
`profileremove`).

The window's words, each checked by lzrprf as the words of a hostile window are: `profile list`;
`profile open ID`; `profile new<TAB>NAME`; `profile rename<TAB>ID<TAB>NAME`; `profile remove ID`.
ID is `first` or 12 hex digits, and only the id of a folder lzrprf finds under `profiles`, a
folder of yours and no link, names a folder (`sub profile_folder`); dots, slashes, a longer id,
capitals or an id lzrprf never made are refused and said (run `profilehostile`). lzrprf answers
with `profiles begin`, a line `profiles one ID this|open|shut NAME` for each profile, and
`profiles end` (`sub profiles_told`); and with `profiles refused WORDS` when it did nothing.
The window shows a name as plain text, never as markup. A name is written to one file only,
that profile's own `name` (or `profiles/first`); the list and the strip's words, such as "You made
the profile NAME", are held in the window's memory and its strip, never on the disk (run
`profilenew` looks for the name in every file of the state folder and finds it in that file alone).

Making, renaming and removing a profile each take an exclusive lock on the folder of profiles,
opened with no link followed, so two windows cannot pass the bound of 16 together or take one
name twice; the count and the name are looked at again under the lock (`sub profiles_locked`).
Under that lock a removal also clears what an earlier removal left half done: an entry named
exactly `.removed.ID.PROCESS` whose process is gone. A link of that name is removed and never
followed, and any other name is left as it is (`sub profiles_swept`, run `profileremove`).

"Close and restart" after an update opens the new release in the same profile, with only its id
on the command line, as the Profiles icon does (`sub restarted`). The installer has replaced
`lzrprf` and the application in place, and a fresh perl reads `lzrprf` from the disk, so the
window that comes back is the new release and passes every check of a start.

An incognito window belongs to no profile. It is told none, shows no Profiles icon, and the
cogwheel's item only says why; lzrprf refuses every word of a profile from it and makes no folder
of profiles (run `profileincog`). An incognito window opened from a profile's window reads that
profile and no other: its id is the one word of the profile on its command line
(`perl lzrprf incognito --profile ID`), and the home page, the search address, the bar and the
bookmarks it reads, never writes, are that profile's (`sub incognito_opened`, run
`profileincogtwo`, and run `profileincogbehind` through the parser of the process behind the
window). It writes nothing to the state folder either: a self-test mark it does not match is
noted in its own folder only (run `untestedincog`). It holds no lock on the profile, so it does
not keep the profile from being removed. It reads the profile's bookmarks, home page and search
address each time it uses them, so once the profile is removed they are gone from that window
too. It then starts no new window and pulls out no tab, since such a window would end at its
first check; it says in the strip that the profile was removed (run `profilegone`). It is told
nothing of profiles, and its Log panel names no command to type, since none would be of it.

In a terminal, `perl lzrprf profiles` prints each profile's id and name, and `perl lzrprf log`
and `perl lzrprf keep` take `--profile ID` to speak of that profile; without it they speak of the
first. The id is 12 hex digits lzrprf made; any other word, or the id of no profile, is refused
and nothing changes (`perl selftest`, the checks after run `keepcli`).

Connected sign-ins (release 77, the owner's order of 2026-11-22). The Profiles list ends with
"Connect seamless SSO accounts...", which lists Google, Apple and Meta, each Connected or Not
connected, with Connect or Remove (`sub sso_told`). lzrprf has no sign-in client of its own:
Connect opens the provider's own fixed sign-in page in a new tab of this window, and you sign in
there (`sub sso_connect`). From that press until the window ends, the cookies the provider's own
family of hosts sets (`%SSO_PROVIDERS`: google.com, youtube.com and gmail.com; apple.com and
icloud.com; facebook.com, messenger.com and instagram.com) are held in the window's memory; when
one of the provider's session cookies appears, looked for by its name and never by its value, the
profile is connected and they are written to the one file `sso/PROVIDER` of that profile, readable
by you alone (`sub sso_heard`, `sub sso_written`, run `ssoconnect`). A cookie whose Domain is
another site or a whole top-level domain is not kept. From then on a request to a host of that
family carries the cookies that match it by host and path, when it is the request of a page you
visit or of a page kept running whose own host is of the same family; no other site's page
makes them go (`sub sso_cookie`, run `livesso`). They go to curl on its input, never on a command
line, and no value is written in the log, told to the window or handed to the application `[C7]`.
A redirect between hosts of the family is followed without a question, written in the log first,
at most `$SSO_HOPS` a visit; a redirect out of it is asked about as any other `[C4]`. Clearing
history and sessions, or the log, leaves the file as it is (run `ssokept`); Remove asks once and
deletes it, which signs you out of the provider's sites in this profile (`sub sso_remove`, run
`ssoremove`). An incognito window and Tor read, keep and send none (runs `ssoincog`, `ssotor`)
`[C16]` `[C17]`. Removing a profile removes its sign-ins with its folder.

What is left for a later part, and not built: sharing a connected sign-in with a site outside the
provider's family (a "Sign in with Google" on another site) only after you were asked, with three
answers (from now on, only this time, or never), each host trusted on its own, and the hosts
managed under a settings entry "Manage shared authentication". Until then such a site gets no
cookie of the provider, and the provider's sign-in page reached from it is a page of its own.
