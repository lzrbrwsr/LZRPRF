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
| 1. The Tor window opens first. lzrprf says `startup ready`, the window is put on the screen, and only
   then does it say `torsession made` (`sub behind`). Nothing connects by itself (Henry, 2026-11-24,
   HC-0858): Tor is started only by Connect to Tor in the window's LZRTNNL modal (run `torwait`: a Tor
   window left alone says `made`, starts no client and fetches nothing). The modal flies out of the onion
   (`function tnnlShown`; while the window is not on the screen yet, it looks again a moment later). It
   holds Connect to Tor and a box, Use also VPN; "LZRTNNL: Tor, and a VPN of your own under it" below.
2. Connect to Tor says `tor on`; then `sub tor_session_on` says `torsession connecting` and the modal of
   Tor shows (`function torShown`). Its five stations light from the client's own log lines,
   `tor step N PERCENT WORDS`, read by `sub tor_on`: the real progress of Arti, not a timer.
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

## LZRTNNL: Tor, and a VPN of your own under it

LZRTNNL is the part of LZRBRWSR that holds Tor (Henry, 2026-11-24, HC-0858). It is installed only when
you include it (the installer, or "Add or remove LZR modules"); left out, the onion is not shown and
lzrprf refuses a Tor window (`sub tor_window_opened`, `sub part_on`). The decision, its sources and the
design are in the LZRBRWSR repository's `architecture/lzrtnnl.md`; in short:

- The order is you, then the VPN, then Tor ("Tor over VPN"). Your provider sees that you use Tor and
  never where you go; Tor's first relay sees the VPN's address, never yours. Tor keeps its own circuits
  and onion services; nothing comes after Tor.
- The VPN is your own provider's WireGuard file, imported and activated in the WireGuard app, which you
  install yourself. lzrprf bundles no VPN client and changes no setting of this Mac. The file is read
  once (`sub tnnl_file`): its IPv4 address and its server are kept, its private key is overwritten in
  memory and never kept, and a file whose AllowedIPs is not 0.0.0.0/0, or that names more than one
  server, is refused (`sub tnnl_read`).
- Connect to Tor with the box ticked first asks whether the VPN is active (`tnnl vpn look`): an
  interface `utunN` that is up and holds the file's address (`sub tnnl_interface`). Only then is Tor
  started, through a relay that opens each of Tor's connections bound to that interface alone
  (`IP_BOUND_IF`, `sub tnnl_bound`), and the Tor client's container may reach the loopback alone, that
  is the relay (`sub tnnl_container`). A connection that the interface cannot carry fails; it never
  takes another route.
- Every 2 s the interface is looked at again (`sub tnnl_watch`). When the VPN drops, or its address
  moves, the relay and every connection it carries are ended, Tor stops (`sub tor_failed`) and stays
  wanted, so nothing is fetched on the clear road until you connect again or close the window.
- Names are never looked up by the relay (a SOCKS name is refused): Tor resolves at its exits, and the
  DNS lines of the file are not used. IPv6 goes through the relay only when the file's AllowedIPs
  carries `::/0`. The engine has no WebRTC.

The package test (`scripts/test-package-parts.sh` of LZRBRWSR, step 26) shows each point with the
loopback standing in for the VPN: `lzrprf tnnlconf`, `lzrprf tnnlrelay` and `lzrprf tnnldrop`.
