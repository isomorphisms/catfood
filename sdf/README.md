# SDF / NetBSD Grease

Cat Food treats SDF as a concrete NetBSD runtime target, not as a Debian/Ubuntu
cloud host. Public and historical machine evidence is kept in
[`PUBLIC-TARGET-INVENTORY.md`](PUBLIC-TARGET-INVENTORY.md); live host receipts remain
the authority for the exact session and any CPU-specific build decision.

On a generic NetBSD amd64/x86_64 host, automatic detection deliberately stops at the host class:

```sh
./catfood --target
# netbsd
```

That class does not provision anything. Once the session is explicitly established as SDF:

```sh
CATFOOD_TARGET=sdf ./catfood
export PATH="$HOME/opt/bin:$PATH"
grease -c 'echo hello from Grease'
```

Not every NetBSD host is SDF; the explicit target declaration prevents Cat Food from turning an OS observation into a site identity.

The SDF path first runs a byte-pinned copy of AICI's host-context executor from commit `7062767b79c5778ed907cc9709fdac918fab24cf`. The executor measures NetBSD, amd64, and release 9.3 itself before it launches either the SDF preflight or fetch stage. Cat Food CI checks the vendored bytes against that exact AICI revision.

Inside that mediated entrypoint, `sdf/preflight.sh` verifies:

- the observed operating system is NetBSD;
- the observed machine is amd64/x86_64;
- the selected install root is writable;
- the basic archive/file commands exist;
- at least one installed downloader is usable: NetBSD `ftp`, `curl`, or `wget`;
- at least one SHA-256 implementation is usable: `sha256`, `cksum`,
  `sha256sum`, or OpenSSL.

It does not assume `gh`, an SSH key, root access, or a package manager.

## Observed SDF host

Direct SDF measurements on 2026-09-29 establish the current production target as:

- NetBSD 9.3 GENERIC, amd64 / x86_64;
- Supermicro X7DBT, Intel Blackford/Tumwater platform, legacy BIOS;
- two Intel Xeon X5460 packages at 3.16 GHz, four cores per package, no SMT (8 CPUs total);
- 16,382 MB physical memory, 15,883 MB available at boot;
- NetBSD base GCC 7.5.0 (nb4) and GNU ld / NetBSD binutils 2.31.1 (nb1);
- local root disk `wd0`, Seagate ST3500630AS, 465 GB;
- the live kernel log has shown NFS traffic to `mx1:/sdf`, so deployment and benchmarks must not assume every SDF path has local-filesystem behavior;
- `/sbin` is not in the ordinary login `PATH`; `/sbin/sysctl` and `/sbin/dmesg` exist, and `/var/run/dmesg.boot` preserves the boot-time hardware enumeration after the live dmesg ring wraps.

The SDF Grease compatibility build therefore targets **NetBSD 9.3 amd64**. A newer NetBSD VM is not acceptance evidence for this host. CPU-specific tuning, if added, must target the X5460/Core-2-era instruction set explicitly rather than using the CI VM's `-march=native` result.

## Grease binary feed

`sdf/grease-package.conf` pins a commit-specific Grease release. The normal
path is:

```
AICI host check -> SDF preflight -> download checksum -> compare pinned checksum
          -> download tarball -> verify pinned SHA-256 -> install under ~/opt
          -> execute greasecpp + grease smoke tests -> receipts
```

The published package comes from
`dilapidated-shed/grease:netbsd/sdf-grease`. The current pin is Grease commit
`60641ddd99844655c0788f790cd3a8a14c7166fd`, built and smoke-tested inside
NetBSD 9.3 before publication. Cat Food pins both that commit-specific release
and SHA-256 `a7f5e35feebd1a222e2ae724bbbf4a2c1fe28c5683ac3aa6561ed770a9bb3136`;
the downloadable checksum file must agree with the independent Cat Food pin.

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
