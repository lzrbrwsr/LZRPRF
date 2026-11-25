# What "proof" means here

This text was the README section "What "proof" means here" until release 76. It moved here unchanged except
for the corrections listed below. Subs are named, never line numbers: `perl tools/sub-map` prints
the line of each.

## Corrections made in the move

- The marks run to [C27], not [C17].
- The README check now covers 27 marks and twelve numbers, and reads README.md only.

## Statement index

Each row is a paragraph, list item or table row below, with the subs it names, the condition marks it
cites and the `selftest` runs it names. A "-" means the statement names none of that kind and is for
the reader to check against the code. Regenerate with `perl tools/doc-index --write docs/proof.md`.

<!-- index begin -->
| statement begins | subs | marks | selftest runs |
| --- | --- | --- | --- |
| Not a mathematical proof. Nobody has proven macOS ... | - | - | - |
| 1. It is a condition in the code: ... | - | C1 C27 | - |
| 2. It is probed on your computer: selftest ... | - | - | - |
| 3. The test is shown not to be ... | - | C1 C2 C3 C10 C11 | `nofeeder`, `leftpage`, `leftkilled`, `lostswap`, `lostlook`, `lostcode`, `lostsoft`, `lostbeside`, `lostfiles`, `lostsheets` |
| 4. It is proven again when what it ... | - | C11 | - |
| So a run that held is evidence for ... | - | - | - |
| selftest also reads README.md when it stands beside ... | - | - | - |
<!-- index end -->

Not a mathematical proof. Nobody has proven macOS correct, and nothing here says so. A promise in
this repository is proven in this sense, and in no stronger one:

1. It is a **condition in the code**: one line, or a few, that you can read. Each has a mark,
   `[C1]` to `[C27]`, listed in the first lines of `lzrprf` and set again at the line that holds it.
2. It is **probed on your computer**: `selftest` runs a hostile application against that
   condition. A probe on a container is first made outside every container, where it must
   succeed, so a refusal inside is the container's and not a probe that could never have
   worked. A condition that is not a container's (what is fetched, what is logged, what is
   drawn) is judged by what the test's own site received and by what the log holds. The hostile
   application is the test's own (`$hostile` in `selftest`), put in the closed application's
   place. The closed application is never run by the test, so what is shown is what the
   container does to any program, whatever LZRBRWSR is.
3. The test is **shown not to be blind** for the page container `[C1]`, the tries of `[C2]`,
   the start inside the container `[C3]`, the window container `[C10]`, the yes to untried
   checks `[C11]`, the limit on memory and the pair check, and from release 17 on for the
   keeper, the second read of the program, the files beside it and the limit on open files.
   `selftest` builds copies of `lzrprf`, each with one or two things taken out (`%lost`, the
   runs whose names begin `lost`, and `nofeeder`, `leftpage`, `leftkilled`, in `selftest`), and what comes after it must
   stop each or show the difference: a page container that
   refuses nothing is stopped by `[C2]`; that container without the tries of `[C2]`, and a
   start outside the container, are both stopped by `[C3]`; a page container without its limit
   on memory is stopped by `[C2]`, and with the tries of `[C2]` taken out too, the probe on
   memory is made in it and its line says so; a window container with one refusal taken out is
   stopped by `[C10]`; a copy whose pair check is taken out, and a copy that counts a mark
   with untried checks without your yes, each fetch without the window or the question the
   real `lzrprf` puts first, and their lines say so; a copy without the keeper leaves the
   application running when lzrprf is killed (`leftkilled`), a copy that does not read the
   program again starts a program that was swapped (`lostswap`), a copy that does not read
   it before a site is asked fetches for a program that changed (`lostlook`), a copy whose
   page container does not refuse it lets the application load another file of its own
   folder as code (`lostcode`), a copy whose limits may be raised again lets it allow
   itself more processor time (`lostsoft`), a copy that does not look
   beside the program starts with a file there that is not named (`lostbeside`), and a copy
   without the page container's limit on open files lets the hostile application allow
   itself more (`lostfiles`; the same limit on `curl` has no such copy), a copy that shows a second run which names style sheets again shows its page (`lostsheets`), and their lines say so. The other conditions have no such copy yet.
4. It is **proven again when what it rests on changes**: after an update of macOS, or a change
   of `lzrprf` or of the `selftest` beside it, no page is shown before the probes were made
   again `[C11]`. A run of `selftest` takes the mark of what it tests away at its start and
   writes it again only when nothing failed, so a run that fails takes back an earlier proof.
   The one module the test uses that is not part of perl itself (`IO::Socket::SSL`) is loaded
   only after the mark is out.

So a run that held is evidence for the probes it names, each with its control outside the
container and, for the things named in point 3, the weakened copies it must catch. It is not
a proof that no other probe exists.

`selftest` also reads README.md when it stands beside it. What it checks there, and the twelve
numbers it compares, are listed in README.md under "What "proof" means here". It does not read the
files under docs/. Whether a sentence is true of the code is for a reader to decide. An installed
copy of `selftest` has no README beside it and skips this check.
