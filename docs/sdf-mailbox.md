# SDF mailbox boundary

SDF is a separate NetBSD target. Current conversation observation (2026-10-06)
reports NetBSD 11 and YSH 0.37; this is not execution in this job. Earlier mailbox
history recorded Python 3.9 and a UnicodeDecodeError on `~/mbox`.

The account's incoming spool is `/var/mail/isomorphisms`; `~/mbox` is a different
input. The requested archive is `~/Mail/spec-list`, and the established executable
directory is `~/opt/bin`. None of these observations proves current readability,
free space, permissions, installed interpreter, or the active host's delivery lock.

The read-only `probes/sdf_mailbox.py` takes absolute source/archive paths and
reports actual uname, account, ownership/modes, free space, Python version and
available locking utilities. Use `--require-netbsd` for the SDF boundary.
It does not assume GNU stat/readlink/sed, /proc, gh, apt, root, or Linux flock.
It uses Python 3.9+ standard-library APIs; actual SDF execution is NOT_RUN.

`delivery-lock UNKNOWN` is deliberate. Availability of a locking utility, or a
Postfix setting alone, does not establish which lock the actual delivery agent
and spool writer use. A live archive/move stays disabled until that protocol,
permissions, inode replacement effects, and exact target executor are qualified.
The disposable executor's cooperative flock is not SDF mail-delivery evidence.

Cat Food's stage-zero entrypoint now refuses automatic cloud provisioning on
NetBSD. The POSIX change stays within the existing documented stage-zero boundary
(`ci/shell-boundary.tsv`); it does not extend post-bootstrap shell exceptions.
