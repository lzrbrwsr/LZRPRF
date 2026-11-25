# LZRDFNDR scripts

This text was the README section "Script permissions" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- None in the move. Release 77 renamed the section "Script permissions" to "LZRDFNDR scripts" everywhere a
  person reads it, put Deny Once and Deny Always beside the two Allows, named each script, and showed
  the source of each in the question; the paragraphs below say so.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/script-permissions.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| LZRBRWSR runs no script you have not allowed ... | - | C26 | - |
| - What a script is. Its kind (inline, ... | - | - | - |
| - The order. A Deny of yours refuses. ... | - | - | - |
| - No question holds a page. Each page ... | - | - | `deny` |
| - The strip. A site whose scripts are ... | - | - | - |
| - Script bytes. Every script, module and worker ... | - | - | - |
| - The store. scripts in the state folder, ... | - | - | - |
| - Settings. The cogwheel's "Script permissions..." opens a ... | - | - | - |
| - Sending elsewhere. A POST to another host ... | - | C5 | - |
<!-- index end -->

LZRBRWSR runs no script you have not allowed `[C26]`. Two layers decide and either one alone
refuses: lzrprf, which holds the only policy and the only store, and the engine of the
application, which asks before any text becomes code and runs nothing without an answer. The
rule form and the layers are in RULES.md.

- **What a script is.** Its kind (inline, external, module, handler, eval, function, timer,
  worker, import, frame), the origin its bytes came from (`inline` for bytes inside the page,
  `data:`, `blob:`, or an https origin), the SHA-256 of its bytes and the capabilities it asks.
  A changed SHA-256, or capabilities no rule names, is a new script and is asked about again.
- **The order.** A Deny of yours refuses. A site whose scripts are not allowed at all (no
  Always rule of yours for it, no Allow Once for this visit) runs none. Then an Always rule,
  then Allow Once, then the built-in table: an inline or same-origin script, never `data:` or
  `blob:`, asking only for `dom`, `layout`, `timers`, `storage-own` or `fetch-same` runs with no
  question, once its site is allowed. Anything else is denied.
- **No question holds a page.** Each page run is told, after its style sheets, the decisions
  lzrprf holds for its site: `=permits N`, `page allow` or `page deny`, then `always` or `deny`
  lines, at most 512 in all. A page asks for anything else with `=permit KIND ORIGIN SHA256 CAPS`
  and is answered at once, `=permitted always`, `once` or `deny`. What no rule allows is denied and
  kept; once the page is drawn lzrprf asks you, in its own modal: Deny Once (the first button, the
  answer when nobody answers; it holds for this visit only and nothing is kept), Deny Always (a
  deny rule for each script asked about, kept until you change it in LZRDFNDR scripts, so the
  question is not asked again for that script), Allow Once, Always Allow. Each script is named, never
  counted: a file by its host and path with its query left out, an inline script by the start of
  its SHA-256 and the page, each with inline or external, its size when seen and who runs it when
  lzrprf knows the host (the small table @PERMIT_TRACKERS). Under the words a code block shows the
  source of each script that did not run, its first 8192 bytes, and says where it is cut; it is
  plain text that is never run, selected and copied as text, and its copy button writes to the
  clipboard only on a press. On an Allow the page is loaded again, at
  most three times in a row; after that you reload it.
- **The strip.** A site whose scripts are not allowed is handed its page with every script
  element, every attribute named `on...`, every `srcdoc` and every attribute whose value is a
  `javascript:` or `vbscript:` address taken out, and its frames the same way. Its script, module
  and worker files are not fetched at all (the page is told `=fetched 403 0 0`). Every part taken out is named in the
  question, so Deny Always keeps a rule for each and the next visit asks nothing: a script file by its
  address resolved against the page, its query left out ("external, size unknown, not fetched"), its rule
  keyed by the SHA-256 of "src " and that address; an inline script, handler, script address or srcdoc by
  the SHA-256 of its text. The strip will
  never read exactly as the engine's parser does; the engine refuses on its own as well.
- **Script bytes.** Every script, module and worker the page asks for (`=fetch ... script|module|worker URL`)
  is hashed, and bytes a Deny rule names are not handed over.
- **The store.** `scripts` in the state folder, one rule a line:
  `always|deny<TAB>site<TAB>class<TAB>script origin<TAB>sha256<TAB>caps<TAB>date`. The class is the
  kind asked when you answered: `code` (inline, external, module, handler, worker, import) or
  `strings` (eval, function, timer, a script turning text into code), so an Always for a script's
  code still asks before that script runs eval; Allow Once holds for the kind asked alone. A line of
  the six fields of before the class is a line of another form. It is made by the first
  Always Allow, written beside the old file and through to the disk, and removed when the last rule
  is. It is read strictly: a link, a file of another owner or with a second name, more than 256 KiB
  or 1000 rules, or one line of another form, and none of its rules counts, which means you are
  asked, never that anything runs; such a file is never written over. Allow Once and Deny Once are held
  in the window's memory and never written; Deny Always writes deny rules. An incognito window reads the file and keeps every rule
  chosen in it in its memory only.
- **Settings.** The cogwheel's "Script permissions..." opens a list page like the bookmarks: every
  rule with its site, where the script came from, its identity (short), its capabilities and its
  day, with Always, Deny and Revoke on each, and "Reset all".
- **Sending elsewhere.** A POST to another host than the page's is never covered by a script
  permission: lzrprf asks you for it, Don't send first, and while a page is still read, before it is
  shown, it is refused `[C5]`.
