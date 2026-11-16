# SDF mailbox boundary

SDF is a separate NetBSD target. Current conversation observation (2026-10-06)
reports NetBSD 11 and YSH 0.37; this is not execution in this job. Earlier mailbox
history recorded Python 3.9 and a UnicodeDecodeError on `~/mbox`.

The account's incoming spool is `/var/mail/isomorphisms`; `~/mbox` is a different
input. The requested archive is `~/Mail/spec-list`, and the established executable
directory is `~/opt/bin`. None of these observations proves current readability,
free space, permissions, installed interpreter, or the active host's delivery lock.

The read-only checked-Ithon `probes/sdf_mailbox.pi` takes absolute source/archive paths and
reports actual uname, account, ownership/modes, free space, Python version and
available locking utilities. Use `--require-netbsd` for the SDF boundary.
It does not assume GNU stat/readlink/sed, /proc, gh, apt, root, or Linux flock.
Its checked library is `probes/sdf_mailbox_host.pi`. The accepted mandatory
Ithon host frontend checks both modules before execution, using Python 3.9+
standard-library APIs as explicit substrate boundaries. The CLI and tests do
not import a first-party Python implementation. Actual SDF execution and an
installed Ithon command on SDF remain NOT_RUN.

`delivery-lock UNKNOWN` is deliberate. Availability of a locking utility, or a
Postfix setting alone, does not establish which lock the actual delivery agent
and spool writer use. A live archive/move stays disabled until that protocol,
permissions, inode replacement effects, and exact target executor are qualified.
The disposable executor's cooperative flock is not SDF mail-delivery evidence.

Cat Food's stage-zero entrypoint now refuses automatic cloud provisioning on
NetBSD. The POSIX change stays within the existing documented stage-zero boundary
(`ci/shell-boundary.tsv`); it does not extend post-bootstrap shell exceptions.

The current source oracle also rejects explicit cloud/container/Hetzner
workbench overrides on NetBSD. Android identity comes from observed product,
model and ABI properties; an ARM architecture alone is not a device identity.
The offline tests exercise these current rules, six distribution fixtures,
the historical negative cloud-default mutant, and nonmutation of mailbox bytes
and metadata. Their fixed OS-command adapters are stage-zero fixtures only.
