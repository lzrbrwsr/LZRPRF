# lzrprf script permissions: the sandbox and the curated rules

SYNC: lzrprf (sub curated, curated_read, curated_rule, permit_site, permit_decided, @PERMIT_SANDBOX) ·
selftest (runs permitsandbox, permitboxoff, permitcurated, permitunsigned, lostcurated, and the check of rules/) ·
docs/script-permissions.md · the installer and the release, which join rules/ into permit-rules

LZRBRWSR runs no script you have not allowed. Four layers decide, in this order, and a Deny of yours wins
over every one of them:

1. **E1, the sandbox.** A site with no rule of yours runs its own scripts inside lzrprf's sandbox.
2. **E2, the curated rules.** Reviewed rules for known scripts of a few sites, shipped signed with the release.
3. **E3, your rules.** Always Allow and Deny, kept in the file scripts, and Allow Once for one visit.
4. **Ask.** Deny, Allow Once, Always Allow; Deny is the answer when nobody answers.

A page with a password field, or at an address of signing in, has no sandbox and no curated rule: every
script on it is asked about. An address is one of signing in when its first host label is one of login,
signin, sso, auth, oauth, idp, accounts, account, id, identity, tunnistus, tunnistautuminen, kirjaudu, or a
segment of its path (before any ".") is one of login, signin, sign-in, log-in, sso, oauth, auth, kirjaudu,
kirjautuminen, tunnistaudu, tunnistautuminen.

## E1, the sandbox

lzrprf enforces it on what it fetches, so it does not depend on what the engine says of a script's
capabilities. The table is @PERMIT_SANDBOX in lzrprf, by name; Script permissions shows it:

| name | verdict | what it means |
|---|---|---|
| own-scripts | runs | the page's own scripts, inline and external from its own origin, asking only capabilities of low risk |
| other-scripts | asks | a script or module from another origin: fetched, hashed and asked about, unless a curated rule names it |
| strings | asks | eval, Function, a timer given a string |
| fetch-own | runs | a GET or HEAD of the page to its own origin |
| fetch-other | refused | any other request of the page to another origin: answered 403 and never fetched |
| post | refused | a POST of the page to any origin, its own included: answered 403 and never sent |
| credentials | refused | lzrprf sends no cookie and no credential, and a request of a page carries no header of its own |
| keep | refused | nothing is written for the site; what the sandbox decided is held in the window's memory |
| sign-in | off | a page for signing in has no sandbox |

The sandbox is lifted for a site only by a rule of yours for it, or by Allow Once on the visit. One switch in
Script permissions turns E1 off; off is pure default deny. The switch is the line "e1 off" in the file
scriptlayers of the settings folder.

## E2, the curated rules

### Where they live

- rules/SITE.rules in this repository: one file per site, reviewed. Unreviewed drafts are kept outside
  this repository; lzrprf never uses a draft, and the release never ships one.
- At release, site.sh joins rules/*.rules in the order of their names into one file, permit-rules. The
  release's manifest names it by its SHA-256 (a line "file permit-rules SHA256"), so the release key and the
  owner's approval sign it with the installer and the download.
- The installer fetches permit-rules from both places, refuses a pair that differs or a file the manifest does
  not name, and keeps it in ~/.lzrprf beside release.manifest, release.manifest.sig and
  release.manifest.approval. A release that names no permit-rules has the four taken away.

### When lzrprf uses them

Every one of these, once a window, or no curated rule is used and lzrprf asks:

- the four files are plain files of yours, with one link each, within their bounds;
- the manifest is in its form, approved with an approval key lzrprf carries and signed with its release key;
- the manifest is of the release the application's release file names;
- the manifest names permit-rules by the SHA-256 of the file beside it.

A file changed after it was installed is therefore never used. Script permissions lists every curated rule in
use with its layer, and each can be switched off there (a line "curated off" in scriptlayers). The
expiry of the manifest is not held against rules already installed with it.

### The form

Line based, printable ASCII, every line ending in a line end. A file is one or more parts; a part is one site.

    lzrprf permit rules 1
    # a comment: "# " and up to 300 characters, between rules only
    rule
    site https://www.example.fi
    script-origin https://cdn.example.fi
    script sha256 0123...64 lowercase hex digits
    class code
    caps dom,layout,timers
    justification what the script does and why it may run with no question
    source https://cdn.example.fi/app/main.js as fetched 2026-11-22
    reviewer the reviewer's name
    reviewed 2026-11-22
    end

The nine fields come in this order, each "NAME VALUE" with a value of 1 to 400 printable characters:

| field | value |
|---|---|
| site | the page's origin: https and small letters, no path |
| script-origin | inline, or the https origin the bytes came from |
| script | "sha256 HEX" (64 small hex digits of the bytes), or "path PATTERN reason TEXT": a reviewed path pattern with why the bytes change (8 to 300 characters) |
| class | code (the script runs) or strings (it may turn text into code) |
| caps | the capabilities granted, comma-joined, or "-"; low risk only: dom, layout, timers, storage-own, fetch-same |
| justification | why the script may run with no question, at least 12 characters |
| source | what was inspected, at least 8 characters |
| reviewer | who read the source; empty, "unreviewed", "-" or "none" is never used |
| reviewed | the day of the review, YYYY-MM-DD, never later than today |

A path pattern is 2 to 16 segments of letters, digits and . _ ~ - and *, ends in .js or .mjs, has at most two
"*", no segment that is only "*", and at least one folder segment with no "*". It never applies to an inline
script. It is matched against the path the bytes were fetched from on this visit.

### What is never used

A part is not used at all, with its reason shown in Script permissions, when any rule in it:

- is unreviewed;
- grants a sensitive action (post-other, payment, credentials) or a capability only you grant (clipboard,
  camera, microphone, location, files), or a name lzrprf does not know;
- names a whole domain: no SHA-256 and no path pattern with a fixed folder;
- is for a site whose first host label is one of signing in;
- is not of the form above, or names a site other than the part's.

A file that breaks the form outside a rule (a line where a part or a rule must begin) is not used at all.

### How a curated rule decides

A curated rule answers "once" for its script on a page that is not one of signing in. A site that a curated
rule names keeps the sandbox's network limits (no POST, nothing else of another origin) even with E1 switched
off; with E1 off only the scripts its curated rules name run there. A rule by SHA-256 is also told in the =permits frame; a rule by
path pattern is answered when the page asks. A changed script is a new SHA-256 and falls through to the
question. A Deny of yours wins.

## Where a rule comes from

A rule starts as an unreviewed draft, written from what scripts a public page runs, and kept outside this
repository. It becomes a file in rules/ only when a person who read the script's source writes their name
and the day into it.
