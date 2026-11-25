# The list of addresses lzrprf never opens

This text was the README section "The list of addresses lzrprf never opens" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/blocklist.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| lzrprf never opens an address that is on ... | - | C23 | - |
| What is blocked. Every address is held to ... | `find`, `tor_where`, `fetch`, `reach`, `tor_reach` | C1 C10 | - |
| Where the lists come from. The file blocklist ... | - | - | - |
| Why matching is local. The file holds digests ... | - | - | - |
| No setting, variable or button turns it off. ... | - | - | - |
| A list is only as good as its ... | `url_form` | - | - |
| - Host. Lower case, the A-label (punycode) form ... | - | - | - |
| - Path. Split on / (and \, as ... | - | - | - |
| - Query. Split on & and ;. + ... | - | - | - |
| - What is hashed. host-sha256 holds the SHA-256 ... | - | - | - |
| - Pre-hashed entries need both halves. A list ... | - | - | - |
| - How an address is looked up. As ... | - | - | - |
| - Onion. onion-md5 holds the MD5 of <label>.onion, ... | - | - | - |
| What the form cannot know. A server may ... | - | - | - |
| - a server that decodes %2F or %5C ... | - | - | - |
| - a server that decodes twice (%252F); ... | - | - | - |
| - a path that ignores case (IIS, or ... | - | - | - |
| - a path that carries + for a ... | - | - | - |
| - parameters a server reads from the path ... | - | - | - |
| - a server that answers the same page ... | - | - | - |
| The list's makers list such spellings as entries ... | - | - | - |
<!-- index end -->

lzrprf never opens an address that is on a list of child sexual abuse material or other
illegal content, and nothing it runs can get around that `[C23]`. The window and the log say
the same sentence: "This address is on a list of child sexual abuse material or other illegal
content, so LZRBRWSR does not open it." The window adds where help is found in confidence,
Stop It Now (https://www.stopitnow.org.uk), and where such material is reported, the Internet
Watch Foundation (https://report.iwf.org.uk).

**What is blocked.** Every address is held to the list before anything else is done with it:
what you type into the bar or search for (the search address would carry it), a bookmark, the
home page, every hop of a redirect, each picture, style sheet and video a page names, what a
page kept running asks for, and the fixed addresses of the release file; with Tor on as with
Tor off. Then it is held to the list once more at the three places every request passes: where
a name is looked up (`sub find`, or `sub tor_where` with Tor on), where `curl` is started
(`sub fetch`, the one caller of `sub reach`, the one `connect` to a site), and where Tor is
asked to connect (`sub tor_reach`). The application, the engine and the window have no network
of their own `[C1]` `[C10]`, so a request of theirs is a request lzrprf makes, and passes the
same places. An onion address is matched by its last two labels, so every name under a listed
one is listed too; any other host is matched by itself and by every name it stands under, so a
name under a listed host is listed too; an address is matched by its host, path and query, by
its host and path alone, and by every path above its own, so neither a query, more query parts
nor a deeper path added to a listed address gets it past. Before matching, the address is put in the one form the
list is made of ("The digests" below), so another spelling of the same address (`%70` for `p`,
`/./`, `//`, `/x/../`, a `/` or `;x` at the end, the query's parts in another order, capital
letters, a port, a name and password before the host) is the same address. `lzrprf lookup`
refuses a listed name too, before it is handed to the resolver, and prints nothing for it.

**Where the lists come from.** The file `blocklist` beside lzrprf holds four parts. The first
holds onion addresses, as the MD5 of the full address with `.onion`, the form in which Ahmia
publishes its list of onion services that carry child sexual abuse material
(https://ahmia.fi/blacklist/). The second, third and fourth hold the SHA-256 of a host, of
`host/path?query`, and of `host/path` of each address with a query, for the URL List of the
Internet Watch Foundation, which it gives to those it licenses. All are empty in the file that ships today: Ahmia's list is placed once its licence
for shipping inside an application is settled, and the IWF's once lzrprf may carry it. The
file is written by `scripts/blocklist.pl` in the application's source, which writes digests only:
it takes lists of digests, or plain addresses that it hashes and does not keep, so no address of
any list is ever written into this repository. `docs-blocklist-sources.md` in the application's
source compares the lists there are and what their terms allow. Ahmia's list goes in as it is
published, one MD5 a line: `perl scripts/blocklist.pl --ahmia-md5 banned.txt ... blocklist`, which
refuses any line that is not 32 hex letters.

**Why matching is local.** The file holds digests and no address, so it names nothing to whoever
reads it, and an address is matched by computing its digests here and looking them up in the
list held in memory: a search by halves of each sorted part, a few dozen steps at most, in a
list of at most 64 MiB read once when a window starts, which holds about a million SHA-256
digests or two million MD5 digests. Nothing of what
you visit, no address and no digest of one, is sent to anyone to be matched. A service that
matched addresses for lzrprf would learn every address you open, which is what lzrprf exists to
keep from everyone.

**No setting, variable or button turns it off.** There is no setting, no variable, no button and
no argument that turns the list off or names another one: lzrprf reads it from one place, beside itself, and the
installer puts it there read-only beside lzrprf. The application's release file names the list's
SHA-256 in a line `blocklist`, as it names lzrprf's. A list that is not there, is damaged, is out
of order, or is another file than the release file names opens no page at all, and the window
says why and that installing again mends it. A listed address is never written to the log, kept
in a tab, its history, a bookmark or anywhere else: the log says only that a listed address was
refused, and a line that would name one is written as that sentence instead.

## The digests

A list is only as good as its agreement with the matching, so the form an address is hashed in is
fixed here, and `scripts/blocklist.pl` of the application runs the very text of lzrprf's
`sub url_form` to put plain addresses in it (`--host-plain`, `--url-plain`). This is form 2. The
list's first line names it (`lzrprf blocklist 2 form 2`), and lzrprf takes a list made for another
form as no list, because its digests would match nothing.

- **Host.** Lower case, the A-label (punycode) form of a name with letters outside ASCII
  (`blocklist.pl` refuses a host that is not plain ASCII), no dot at either end, no port, no name
  or password. `www.` is not taken away: `www.example.test` and `example.test` are two hosts, and
  a list that means both names both. A host matches itself and every name it stands under
  (`a.b.example.test` matches a listed `b.example.test` and `example.test`). A whole host is listed
  in this part, never as `host/`.
- **Path.** Split on `/` (and `\`, as browsers read it). `%2F` and `%5C` are not split on: they
  stay escapes inside their segment. In each segment, what follows a `;` is dropped. A `%XX` of an
  unreserved character (`A-Z a-z 0-9 - . _ ~`) is decoded. Every other `%XX` is written with capital
  hex, and every other byte as its capital `%XX`, so a space is `%20`, `@` is `%40`, `+` is `%2B`
  and a byte of 0x80 or above is escaped. Empty segments and `.` are dropped, and `..` takes away
  the segment before it. The segments are joined with `/` after one leading `/`: no `/` at the end,
  and the root is `/`.
- **Query.** Split on `&` and `;`. `+` is read as a space (`%20`). Each part is written as a
  segment is, except that `=` stays as it is. Empty parts and repeated parts are dropped, and the
  rest are sorted (bytewise) and joined with `&`. There is no fragment: `#` and what follows are
  never sent.
- **What is hashed.** `host-sha256` holds the SHA-256 of the host. `url-sha256` holds the SHA-256
  of `host` + `path` + `?query`, or of `host` + `path` when there is no query (`example.test/a/b`,
  `example.test/a/b?k=1&z=2`). `query-sha256` holds the SHA-256 of `host` + `path` of each entry
  with a query (`example.test/a/b`).
- **Pre-hashed entries need both halves.** A list given to `blocklist.pl` as digests (`--url`) must
  come with its `--query` counterpart, the SHA-256 of `host/path` of every entry with a query. A
  supplier who sends digests sends both files, each complete: a `--query` file that misses the
  path of one entry with a query lets that entry's added or repeated parts get past.
  `--url-plain` writes both itself. Without that counterpart, an entry is still matched exactly
  as listed, but an address with parts added, repeated or more than 8 gets past.
- **How an address is looked up.** As it is, and, on a path that `query-sha256` names, with every
  choice of its query's parts, so a listed
  `?k=1&z=2` is still refused with parts added (`?k=1&m=5&z=2`) or repeated. With more than 8 parts
  the 255 choices are not tried: the address is refused when its `host/path` is in `query-sha256`,
  that is, when any query on that path is listed. Then it is looked up without its query, and at
  every path above its own down to its first segment, so a listed `example.test/a` also refuses
  `example.test/a/b?k=1`. `host/` is never a parent: a listed `example.test/` refuses that one page
  and not the whole host. An address longer than lzrprf reads (a host over 1000 bytes, or a path
  and query over 8192) is refused, never let past.
- **Onion.** `onion-md5` holds the MD5 of `<label>.onion`, the 56-letter label in lower case, as
  Ahmia publishes it. An address under it (`www.<label>.onion`) matches it.

**What the form cannot know.** A server may read one address in more ways than the form does, and
then the same page can be reached under a spelling the list does not hold:

- a server that decodes `%2F` or `%5C` into a path separator;
- a server that decodes twice (`%252F`);
- a path that ignores case (IIS, or a case-insensitive file system behind a server);
- a path that carries `+` for a space;
- parameters a server reads from the path (`/a,b`) or ignores (`?utm_source=`, only when they are
  not part of the listed query);
- a server that answers the same page under another path (rewrites, `index.html`).

The list's makers list such spellings as entries of their own. A whole host or onion service is
listed by its host or onion part, which no spelling of a path gets past.
