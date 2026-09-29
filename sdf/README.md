# SDF / NetBSD Grease

Cat Food treats SDF as a concrete NetBSD runtime target, not as a Debian/Ubuntu
cloud host. On NetBSD amd64/x86_64:

```sh
./catfood --target
# sdf

./catfood
export PATH="$HOME/opt/bin:$PATH"
grease -c 'echo hello from Grease'
```

The SDF path runs `sdf/preflight.sh` before network access. Preflight verifies:

- the observed operating system is NetBSD;
- the observed machine is amd64/x86_64;
- the selected install root is writable;
- the basic archive/file commands exist;
- at least one installed downloader is usable: NetBSD `ftp`, `curl`, or `wget`;
- at least one SHA-256 implementation is usable: `sha256`, `cksum`,
  `sha256sum`, or OpenSSL.

It does not assume `gh`, an SSH key, root access, or a package manager.

## Grease binary feed

`sdf/grease-package.conf` pins a commit-specific Grease release. The normal
path is:

```
preflight -> download checksum -> download tarball -> verify SHA-256
          -> install under ~/opt -> execute Grease smoke test -> receipt
```

The published package comes from
`dilapidated-shed/grease:netbsd/sdf-grease`. That workflow compiles and
smoke-tests the exact pinned Oils-derived source inside NetBSD 11 before
publishing the tarball as an immutable commit-specific prerelease asset.

For local/offline testing, `CATFOOD_GREASE_URL` and
`CATFOOD_GREASE_SHA256_URL` may point at `file://` paths. A specific
installed downloader can be selected with `CATFOOD_SDF_DOWNLOADER=ftp|curl|wget`.

## Mailbox pipeline benchmark

The benchmark is read-only with respect to the mailbox. It executes exactly:

```sh
grep -aEi '^(To|Cc):.*SPEC-LIST' /var/mail/isomorphisms | sort -fu | head -50
```

under the current login shell and then under Grease, checks that both outputs
match, and records portable `time -p` output:

```sh
sh sdf/benchmark-grep.sh
```

Override `MAILBOX`, `BASELINE_SHELL`, `GREASE`, or `CATFOOD_SDF_STATE`
when needed.

This is a shell/runtime control measurement, not yet the pipeline look-ahead
optimization. Because `sort -fu` needs the complete input before it can know
the globally first 50 sorted unique lines, ordinary shell pipeline scheduling
cannot make `head -50` stop this exact scan early.
