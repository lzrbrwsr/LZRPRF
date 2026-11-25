# Verify a release by hand

This file shows how to check a LZRBRWSR release with the stock `ssh-keygen`, `shasum`, `curl` and
`cmp` of macOS, without running anything the release contains. Each step names what it shows and what
it does not show.

Signatures begin with release 76. Up to release 75 nothing is signed with a key, and
steps 3 to 6 do not apply to those releases.

## What a signed release publishes

Each file stands in two places, which must hold the same bytes:

- the site: `https://lzrbrwsr.com/NAME`
- this repository: `https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/NAME`

| file | what it is |
| --- | --- |
| `install.sh` | the installer |
| `lzrbrwsr-macos-arm64.tar.gz` | the download |
| `release.txt` | the SHA-256 of the installer, the download, each file in the download, and `lzrprf`, `selftest` and `blocklist` |
| `release.manifest` | the manifest: the release number, when it was signed, until when it holds, and the SHA-256 of `install.sh`, `lzrbrwsr-macos-arm64.tar.gz` and `release.txt` |
| `release.manifest.sig` | the release signature over the manifest, namespace `lzrbrwsr-release` |
| `release.manifest.approval` | the approval signature over the manifest, namespace `lzrbrwsr-approval` |

The manifest has exactly this form, at most 36 lines and 4096 bytes:

```
lzrbrwsr release manifest 1
release N
signed YYYY-MM-DDTHH:MM:SSZ
expires YYYY-MM-DDTHH:MM:SSZ
file install.sh SHA256
file lzrbrwsr-macos-arm64.tar.gz SHA256
file release.txt SHA256
```

The public keys are in this repository:

- `release-key.pub`: the release key, Ed25519. Its private half is on the project's server.
- `approval-keys.pub`: the approval keys, ECDSA P-256, one per line. The owner's key is in the Secure
  Enclave of his phone. A line that ends `valid-until YYYY-MM-DD` holds through that day (UTC) and never
  after: the agent approval key is such a line, and its private half is held by the signing service on
  the project's server (THREAT_MODEL.md). A release that drops a line revokes that key.

The same keys are written into `lzrprf` (`$RELEASE_KEY`, `@APPROVAL_KEYS`) and into each installer
(`RELEASE_KEY=`, `APPROVAL_KEYS=`).

## 1. Fetch everything from both places

```
mkdir site repo
for f in install.sh lzrbrwsr-macos-arm64.tar.gz release.txt release.manifest release.manifest.sig release.manifest.approval; do
  curl -q -fsS -o "site/$f" "https://lzrbrwsr.com/$f"
  curl -q -fsS -o "repo/$f" "https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/$f"
  cmp "site/$f" "repo/$f"
done
curl -q -fsS -O https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/release-key.pub
curl -q -fsS -O https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/approval-keys.pub
curl -q -fsS -O https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/lzrprf
cd repo
```

`cmp` prints nothing when the two copies are the same. A difference means one place does not hold
this release yet, or holds another. Fetch both again a few minutes later, and install nothing while
they differ.

**Shows:** both places serve the same files. **Does not show:** that either place is honest. Both
are run by one maker.

## 2. Check the release key's fingerprint

```
ssh-keygen -lf ../release-key.pub
```

It must print:

```
256 SHA256:iN/qb7iC/v07aNa/RWpqgm8kchzJ9CDId4YlK7KoMlE lzrbrwsr-release (ED25519)
```

Compare the key with the one `lzrprf` carries and with the one in the installer:

```
grep "^my \$RELEASE_KEY" ../lzrprf
grep '^RELEASE_KEY=' install.sh
```

All three must show the same `ssh-ed25519` key.

For the approval keys:

```
grep '^ecdsa-sha2-nistp256 ' ../approval-keys.pub | ssh-keygen -lf -
grep '^APPROVAL_KEYS=' install.sh
```

Each key of `approval-keys.pub` must be in `APPROVAL_KEYS` and in `@APPROVAL_KEYS` of `lzrprf`. When
`approval-keys.pub` holds no key line, no release can be approved, and both the installer and lzrprf
refuse every release.

**Shows:** the keys you check against are the keys the code checks against. **Does not show:** who
holds the private halves. THREAT_MODEL.md says what is assumed about them.

## 3. Write the two allowed-signers files

```
printf 'lzrbrwsr-release namespaces="lzrbrwsr-release" %s\n' "$(cut -d' ' -f1-2 ../release-key.pub)" > allowed-release
grep '^ecdsa-sha2-nistp256 ' ../approval-keys.pub | awk -v today="$(date -u +%Y-%m-%d)" '$(NF-1) != "valid-until" || $NF >= today' | while read -r kind blob _; do
  printf 'lzrbrwsr-approval namespaces="lzrbrwsr-approval" %s %s\n' "$kind" "$blob"
done > allowed-approval
```

A key whose `valid-until` day has passed is left out, as lzrprf and the installer leave it out. This is the same form `sub signature_holds` writes before it runs `ssh-keygen` in the verifier
container. The `namespaces=` option means a signature made for anything else does not hold.

## 4. Check both signatures

```
ssh-keygen -Y verify -f allowed-release  -I lzrbrwsr-release  -n lzrbrwsr-release  -s release.manifest.sig      < release.manifest
ssh-keygen -Y verify -f allowed-approval -I lzrbrwsr-approval -n lzrbrwsr-approval -s release.manifest.approval < release.manifest
```

They must print, in order:

```
Good "lzrbrwsr-release" signature for lzrbrwsr-release with ED25519 key SHA256:iN/qb7iC/v07aNa/RWpqgm8kchzJ9CDId4YlK7KoMlE
Good "lzrbrwsr-approval" signature for lzrbrwsr-approval with ECDSA key SHA256:...
```

Any other output, or a non-zero exit, is a refusal. lzrprf checks the approval first and then the
release signature, and accepts only output that begins as shown (`sub signature_holds`).

**Shows:** the release key signed exactly these manifest bytes, and an approval key approved exactly
these bytes. **Does not show:** that the release is good. A signature says who approved a file, not
what the file does.

## 5. Check the manifest's form and dates

```
sed -n '1,4p' release.manifest
wc -lc release.manifest
date -u +%Y-%m-%dT%H:%M:%SZ
curl -q -fsS https://raw.githubusercontent.com/lzrbrwsr/lzrprf/main/latest
```

The manifest must:

- begin with the line `lzrbrwsr release manifest 1`;
- name in its `release` line the number in `latest`;
- say it was signed no later than one day after now;
- not have expired;
- hold at most 400 days from `signed` to `expires`;
- have only `file NAME SHA256` lines after line 4, no name twice;
- be at most 36 lines and 4096 bytes.

These are the checks of `sub manifest_read` and `sub release_signed` in `lzrprf`, and of the
installer before it installs.

## 6. Check the files against the manifest

```
shasum -a 256 install.sh lzrbrwsr-macos-arm64.tar.gz release.txt
sed -n 's/^file //p' release.manifest
```

Each SHA-256 must equal the manifest's line for that file.

## 7. Check the download against `release.txt`

```
mkdir unpacked && tar -xpzf lzrbrwsr-macos-arm64.tar.gz -C unpacked
(cd unpacked && find . -type f | sed 's|^\./||' | sort | while read -r f; do shasum -a 256 "$f"; done)
grep '  LZRBRWSR.app/' release.txt
```

Every file in the download must appear in `release.txt` with the same SHA-256, and nothing else may be
in the download. `release.txt` also names the commit of this repository whose `lzrprf`, `selftest`
and `blocklist` the installer fetches. Check those three:

```
commit=$(sed -n 's/.* at commit \([0-9a-f]\{40\}\)\./\1/p' release.txt)
for f in lzrprf selftest blocklist; do
  curl -q -fsS "https://raw.githubusercontent.com/lzrbrwsr/lzrprf/$commit/$f" | shasum -a 256
done
grep -E '  (lzrprf|selftest|blocklist)$' release.txt
```

## 8. Check the record of the selftest

`selftest-output.txt` in this repository is the selftest run made when the release was made. Its line that begins
`Nothing failed.` names the macOS build and the SHA-256 of the `lzrprf` and `selftest` that ran. Those sums must
equal the lines of `release.txt`. To run it yourself: `perl selftest` beside `lzrprf` (AUDIT.md).

## What the signatures add, and what they do not

- **Add:** a release installs only when the release key on the server and an approval key of
  `approval-keys.pub` both signed exactly its manifest. Without a `valid-until` line in that file, the
  approval key is the owner's phone and automation alone cannot publish an installable release. While
  the agent approval key is listed, the maker's tooling can, until its `valid-until` day. A changed file in either place fails step 6.
- **Do not add:** any statement about what the closed application does. That is held by the
  containers and the conditions `[C1]` to `[C26]` of `lzrprf`, checked by `selftest` on your Mac.
- **Key changes:** a new release key is accepted by an lzrprf that carries the old one only through a
  release signed by the old key and approved on the phone. A new approval key reaches users only
  inside a release approved by an existing approval key. The signing side is described in the maker's
  repository; that description is not published here.
