# Filter lists

How lzrprf holds the requests of a page to the filter lists of uBlock Origin's uAssets, from release
76 on `[C27]`. Subs are named, never line numbers: `perl tools/sub-map` prints the line of each.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/filters.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| A filter list blocks requests. It never lets ... | `filter_said`, `live_fetched`, `pictured`, `sheeted`, `videoed` | C23 C26 | `filterlive`, `lostfilter` |
| - An exception (@@) only means "not blocked". ... | `permit_site`, `curated` | - | `filterallow` |
| - A line of a list that reads ... | `filter_line` | - | - |
| - What lzrprf filters: the pictures, style sheets ... | - | - | - |
| - A blocked request is not fetched and ... | - | - | - |
| The lists are kept in filters/ubo/, byte for ... | - | - | - |
| perl tools/ubo-update fetches a newer commit into a ... | - | - | - |
| The maker's repository holds no third party list ... | - | - | - |
| A release names each list in its signed ... | `filters`, `beside_read` | - | `filterchanged` |
| filters/ubo/LEGAL-REVIEW holds the outcome of a legal review ... | - | - | - |
| lzrprf holds no code of uBlock Origin and ... | `filter_line` | - | - |
| kind what it is what lzrprf does ... | - | - | - |
| network \\host^, a path, \ anchors, and ^, ... | - | - | - |
| exception the same after @@ the request is ... | - | - | - |
| options $script, $image, $stylesheet, $font, $media, $subdocument, $xmlhttprequest, ... | - | - | - |
| document $document, $popup counted: the page you open ... | - | - | - |
| regex a pattern between slashes counted, not matched ... | - | - | - |
| cosmetic, procedural, html ##, #?#, ##^ counted: lzrprf ... | - | - | - |
| scriptlet ##+js(...), #%# counted, never run ... | - | - | - |
| redirect, removeparam, csp those options counted: lzrprf neither ... | - | - | - |
| conditional a line between !#if and !#endif counted: ... | - | - | - |
| unsupported every other option, a domain given by ... | - | - | - |
| permission see above refused and counted ... | - | - | - |
| Rules are indexed when the lists are read: ... | `filter_rule`, `filtered` | - | `filterrules` |
| Filters, in the cogwheel's menu, shows the requests ... | `filters_told`, `filter_layers`, `filters_set` | - | `filterset` |
| The real lists at the pinned commit are ... | - | - | `filterreal` |
| What the lists would block on a few ... | - | - | - |
| says what the lists in DIR (every NAME.txt ... | `filters_dir` | - | - |
<!-- index end -->

## What a filter does, and what it never does

A filter list blocks requests. It never lets a script run. lzrprf holds every request of a page to
the lists after the list of addresses it never opens `[C23]` and before the script permissions
`[C26]`, in that order, so a filter can only take away: what `[C23]` refuses no exception brings back,
and what a filter lets through is still decided by the script permissions (`sub filter_said`, asked in
`sub live_fetched`, `sub pictured`, `sub sheeted` and `sub videoed`). Runs `filterlive` and `lostfilter`.

- An exception (`@@`) only means "not blocked". It never answers a script's question, never stands for
  an Allow, and is never read by `sub permit_site` or `sub curated`. Run `filterallow`.
- A line of a list that reads as a permission (a line in the form of the scripts file, of
  scriptlayers or of a curated rule, or a rule with an option such as `$allow`, `$permit`, `$run` or
  `$trusted`) is refused when the list is read and counted as `permission` (`sub filter_line`). uAssets
  has one such line at the pinned commit, a `$permissions=` rule of privacy.txt, which sets a header
  in uBlock Origin and is refused here like any other.
- What lzrprf filters: the pictures, style sheets and video it fetches for a page, and every request
  of a page kept running (its scripts, modules, workers, frames and data). An address you typed, a
  bookmark and the home page are not filtered: lzrprf does not refuse to open what you asked for.
- A blocked request is not fetched and nothing of it is looked up. The log says which rule of which
  list blocked it, and the page is told the request failed.

## Where the lists come from, and when they are used

The lists are kept in `filters/ubo/`, byte for byte as uAssets holds them at one commit, which
`filters/ubo/SOURCE` names with each file's path there and its SHA-256: uBlock Origin's own filters
(filters.txt and the yearly filters-2020.txt to filters-2026.txt), badware.txt, privacy.txt,
resource-abuse.txt, unbreak.txt, quick-fixes.txt, and the copy of EasyList in uAssets. Beside them
lzrprf keeps its own reviewed exceptions, `filters/local-exceptions.txt`, MIT, for pages the lists
break; each exception there carries its reason and its reviewer.

`perl tools/ubo-update` fetches a newer commit into a new empty folder and writes the difference of
each file and the counts lzrprf reads in both, for review; with `--write` the fetched files replace
those of `filters/ubo/` and SOURCE is written anew. `perl tools/ubo-update --check` says whether
every file is the one SOURCE names. What is fetched is data: compared and counted, never run.

The maker's repository holds no third party list data: of `filters/ubo/` it keeps only SOURCE, LICENSE
and the legal review, and its `.gitignore` keeps the lists out. `perl tools/ubo-update --fetch`
brings them back by the commit and the SHA-256 SOURCE names, into a new empty folder first, and
places nothing unless every sum matches; with the lists already there it fetches nothing. After the
legal review, the maker's release runs it first and stops if it fails, and lzrprf's public
repository carries the lists as fetched.

A release names each list in its signed manifest: `ubo-NAME.txt` for `filters/ubo/NAME.txt`,
`ubo-SOURCE` for SOURCE, `filters-local.txt` for the exceptions. lzrprf reads them from beside
itself once a window, the first time a request is held to them, and only when the manifest's
approval and signature hold for the keys lzrprf carries, the manifest is of this release, and each
list is the file the manifest names by its SHA-256 (`sub filters`, `sub beside_read`). When any of
that fails nothing is filtered, and Filters in the cogwheel's menu says why. Run `filterchanged`.

`filters/ubo/LEGAL-REVIEW` holds the outcome of a legal review of shipping the lists, as a line
`legal review: YYYY-MM-DD <outcome>`; it is absent until that review is made. Until its outcome begins
with `approved`, no release publishes `filters/` in lzrprf's public repository, serves a list on the
site or names one in its manifest: `scripts/release.sh` and `scripts/site.sh` of LZRBRWSR refuse.
Until then an installed lzrprf filters nothing and says that the manifest names no filter list.

## The syntax lzrprf reads

lzrprf holds no code of uBlock Origin and was written from the published filter syntax alone. Every
line is read once, as one of these kinds (`sub filter_line`); the counts are in Filters and in the
output of `lzrprf filters`.

| kind | what it is | what lzrprf does |
| --- | --- | --- |
| network | `\|\|host^`, a path, `\|` anchors, `*` and `^`, a host alone or a hosts-file line | blocks a matching request |
| exception | the same after `@@` | the request is not blocked; nothing else |
| options | `$script`, `$image`, `$stylesheet`, `$font`, `$media`, `$subdocument`, `$xmlhttprequest`, `$websocket`, `$other` and their `~` and short names, `$third-party`, `$1p`, `$3p`, `$domain=` and `$from=` with hosts, `$important`, `$match-case`, `$all` | as the syntax says |
| document | `$document`, `$popup` | counted: the page you open is not filtered |
| regex | a pattern between slashes | counted, not matched |
| cosmetic, procedural, html | `##`, `#?#`, `##^` | counted: lzrprf gives a page no style of its own, so it has no place to hide an element |
| scriptlet | `##+js(...)`, `#%#` | counted, never run |
| redirect, removeparam, csp | those options | counted: lzrprf neither rewrites a request nor its answer |
| conditional | a line between `!#if` and `!#endif` | counted: the condition is not weighed, so neither side is used |
| unsupported | every other option, a domain given by a pattern, a pattern with spaces | counted |
| permission | see above | refused and counted |

Rules are indexed when the lists are read: a rule anchored at a whole host by that host, any other
by its longest token that a matching address must hold whole; the few with no such token are read for
every request (`sub filter_rule`, `sub filtered`). The party of a request is its host's last two
labels, or three under a second level such as `co.uk`. `$important` beats an exception that is not
itself important. Run `filterrules`.

## What you can change

Filters, in the cogwheel's menu, shows the requests blocked on the page shown and before it in this
window, each with its rule and list; the lists in use with their commit and the counts of each kind;
and what you changed (`sub filters_told`). You may switch a list off, or let one host through on
one site, and revoke either there. Each is kept in the file filterlayers of your profile, or in
memory in an incognito window (`sub filter_layers`, `sub filters_set`). Run `filterset`.

## Measured

The real lists at the pinned commit are read in about half a second, once a window, and a request is
held to them in about a tenth of a millisecond; `selftest` reads and times them in run `filterreal`.

What the lists would block on a few public pages is measured by the maker outside this repository,
with `lzrprf filters` (below).

## Use

    perl lzrprf filters DIR PAGE TYPE ADDRESS...

says what the lists in DIR (every NAME.txt there, read unsigned) would do with each address, as a
request of TYPE from a page of the host PAGE, and prints the counts and the time taken. It decides
nothing for a window (`sub filters_dir`).
