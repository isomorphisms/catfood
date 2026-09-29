# SDF public target inventory

Public and historical evidence about SDF's machines belongs beside the live
host receipts, but it must not replace them.

This snapshot was assembled 2026-09-29.  Treat a public page as evidence for
what that page says, not as proof that the exact login node in the current
session still has the same hardware, operating-system release, storage, or
toolchain.

## Current public SDF descriptions

### Cluster topology

SDF's user wiki says a normal user can log in to `sdf.org`, but SDF has
several servers collectively called "The Cluster".  The wiki explicitly says
the MetaArray is separate from that cluster.

Source:

- https://wiki.sdf.org/doku.php?id=logging_in_to_sdf_servers

This distinction matters for target receipts.  Record the hostname/node
observed by a live session instead of treating the public `sdf.org` name as
one immutable physical computer.

### Published shell-host inventory

SDF's FAQ currently exposes the following machine table:

| Host | Published hardware/storage | Published OS | Published role/access |
| --- | --- | --- | --- |
| `ol.sdf.org` | AMD64, 4 GB, 4 TB disk | NetBSD 6.1.2 | fileserver; no shell login |
| `mx.sdf.org` | AMD64, 4 GB, 2 TB disk | NetBSD 6.1.2 | mail server; no shell login |
| `sdf.org` | AMD64, 4 GB, NFS client | NetBSD 9.3 | general access |
| `ukato.sdf.org` | AMD64, 4 GB, NFS client | NetBSD-current | development |
| `bjork.sdf.org` | AMD64, 2 GB, NFS client | NetBSD 9.3 | development |
| `miku.sdf.org` | AMD64, 4 GB, NFS client | NetBSD 6.1.2 | motd.org / toobnix.org |
| `faeroes.sdf.org` | AMD64, 4 GB, NFS client | NetBSD 9.3 | ARPA access |
| `norge.sdf.org` | AMD64, 4 GB, NFS client | NetBSD 6.1.2 | VHOST member access |
| `iceland.sdf.org` | AMD64, 4 GB, NFS client | NetBSD 9.3 | MetaARPA only |
| `ma.sdf.org` | AMD64, 32 GB, 6 TB disk | Debian 12.7 | MetaARPA only |
| `vpn.sdf.org` | Alpha, 2 GB, 73 GB disk | NetBSD 4.0.1 | VPN/PPTP |
| `vps1.sdf.org` | AMD64, 32 GB, 2 TB disk | NetBSD 5.1 | VPS members |
| `vps2.sdf.org` | AMD64, 32 GB, 2 TB disk | NetBSD 5.1 | VPS members |

Source:

- https://sdf.org/?faq?BASICS?08=

The table is useful provenance, but some entries are plainly old.  In
particular, do not overwrite a newer live `uname`, `sysctl`, mount, or
toolchain receipt with the version printed in this FAQ.

### Hardware-family statement

SDF's public home/welcome material says SDF uses DEC Alpha and AMD Opteron
machines running NetBSD, alongside TOPS-20 and Symbolics Genera systems.

Sources:

- https://sdf.org/ooindex.cgi
- https://sdf.org/welcome.html

This is an organization-level hardware-family statement, not sufficient
evidence for `-march=opteron` or another CPU-specific compiler setting on a
particular login node.

## Independently preserved observations

These records come from public bug reports or mailing-list messages that
contain system output from SDF hosts.  They are useful because they preserve
actual observed host strings at known dates.

### `sdf`, September 2020

NetBSD PR 55684 records:

- host: `sdf`;
- NetBSD `8.1_STABLE`;
- machine: `amd64`;
- architecture: `x86_64`;
- GENERIC kernel;
- kernel build path rooted at `root@ol:/sdf/sys/NetBSD-8/...`.

Source:

- https://gnats.netbsd.org/55684

The `root@ol` build path is also historical evidence for the fileserver/build
relationship between `ol` and cluster clients.

### `faeroes`, July 2022

NetBSD PR 56916 records:

- host: `faeroes`;
- NetBSD `9.1`;
- `amd64` / `x86_64`;
- `Intel 686-class` in the reported environment string.

Source:

- https://gnats.netbsd.org/56916

This observation is especially important for optimization policy: the SDF
homepage's AMD Opteron statement must not be converted into a claim that every
SDF amd64 login node has an AMD CPU.

### `faeroes`, June 2015

A GNU Bash bug discussion records:

- host: `faeroes.sdf.org`;
- NetBSD `6.1_STABLE`;
- custom kernel name `SDF6.amd64`;
- amd64;
- kernel build path rooted at `root@bjork:/spare/netbsd/...`.

Source:

- https://lists.gnu.org/r/bug-bash/2015-06/msg00042.html

## Historical cluster architecture

SDF's long-form history records the physical evolution of the cluster.

In January 2002 the published inventory included dual Alpha 5305 systems for
`sdf`, `otaku`, `droog`, and experimental `bjork`, plus SPARC systems.
The table records storage and memory per machine.

In March 2003 SDF created `ol` for file service and rebuilt `sdf`,
`otaku`, and `norge` as client machines served by `ol`.  In June 2005
the history describes a NetBSD upgrade covering the fileserver, mail server,
and six NFS client systems.

Sources:

- https://gopherproxy.meulie.net/sdf.org/0/sdf/faq/BASICS/02
- https://sdfeu.org/w/faq:basics02

These are historical facts, not current target specifications, but they explain
why NFS-backed client hosts recur in later SDF documentation.

## Consequences for Cat Food and optimized builds

Public evidence is enough to justify a NetBSD amd64 baseline and to preserve
the cluster/NFS history.  It is not enough to choose a microarchitecture.

For every live SDF receipt used to build, benchmark, or select an optimized
binary, record at least:

- observed hostname;
- `uname -a`, plus `uname -s -r -m`;
- `sysctl hw.model hw.ncpu hw.physmem hw.pagesize` when available;
- CPU feature/cache information available to the unprivileged account;
- filesystem and mount facts relevant to source, temporary files, and output;
- quota/free-space facts when they can affect a build;
- compiler, assembler, linker, libc, and C++ runtime versions;
- exact executable/tool paths used;
- source revision, flags, artifact hash, and benchmark workload.

Optimization rules:

- do not infer AMD versus Intel from the SDF organization-level hardware page;
- do not use `-march=native` for a distributable cluster artifact unless the
  artifact is explicitly bound to the measured node/CPU;
- keep a generic NetBSD amd64 artifact when cluster heterogeneity is possible;
- treat NFS as a public/historical expectation until the current session
  confirms the relevant mount;
- bind performance results to the observed hostname and receipt, because two
  SDF sessions need not describe identical hardware.

## Source classes

| Class | Meaning |
| --- | --- |
| SDF official page/wiki | Strong evidence for SDF's published organization, host inventory, and intended roles; may lag live state |
| SDF historical FAQ | Strong provenance for historical topology; not current configuration |
| NetBSD GNATS / upstream mailing list with captured SDF output | Dated observation of one named host |
| Live Cat Food receipt | Authority for the exact session and target-specific build decision |

The public dossier and live receipt should be retained together.  Neither one
should silently overwrite the other.
