# SDF / NetBSD Grease

This is the deliberately small Cat Food path for SDF. It does not run the
Debian/Ubuntu provisioner and it does not try to feed the whole source fleet
onto a shared NetBSD host.

## Install the NetBSD Grease package

Build the matching artifact from the Grease branch
`netbsd/sdf-grease`, copy `grease-netbsd-11-amd64.tar.gz` to SDF, then run:

```sh
sh sdf/install-grease.sh ~/grease-netbsd-11-amd64.tar.gz
export PATH="$HOME/opt/bin:$PATH"
grease -c 'echo hello from Grease'
```

The install stays under `$HOME/opt` by default and needs no root access.

To enter a Grease/YSH session:

```sh
exec "$HOME/opt/bin/grease"
```

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
