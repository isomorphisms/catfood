# Host-boundary receipts — 2026-10-06

Source: isomorphisms/catfood `45503779705972d915f3509cc639a94b45e97669`.
Host fixture/test revision is that same source; test SHA-256:
`71f3ad09ab37634b244777619b5469ae494580804a63c17226fccd3e9942d968`.
Local host: Linux 6.18.44 x86_64; Python 3.12.14; Git 2.51.1;
dash 0.5.12-6ubuntu5. The published Git tree matches the locally committed source.

| Exact command | Result and scope |
| --- | --- |
| `python3 /workspace/scratch/2d7520fd064e/catfood/tests/sdf_mailbox.py` | 4 passed / 0 failed / 0 skipped; real entrypoint with synthetic platform evidence, old-default mutant, positive distro and read-only probe fixtures |
| `sh /workspace/scratch/2d7520fd064e/catfood/tests/entrypoint.sh` | PASS; existing cloud/generic-Termux/inventory/location suite; individual count not emitted |

`published-host-tests.txt` is the recheck on the fetched exact published HEAD.
`entrypoint-tests.txt` ran on the identical local source tree. The initial
known-bad adapter omitted `repository-aliases.tsv`, so it failed before target
detection; the adapter was repaired and the full 4-test suite rerun. That failure
was not counted as a killed target-detection mutant.

Hosted source run https://github.com/isomorphisms/catfood/actions/runs/37465846498
passed on Python 3.9.25 and 3.12.14. Retrieved logs establish exact checkout and
4 passes per version. Stage-zero smoke, AICI and IB handoff checks also passed.

The separate follower reconciliation run
https://github.com/isomorphisms/catfood/actions/runs/37465846528 failed at the
source-trigger lookup: no follower records establish a leader for this new source,
and no recorded trigger has identical non-control source state. Later runtime
workbench/receipt steps were skipped. This is a real outstanding follower gate;
fixture execution is not a Cat Food runtime/physical-device leader receipt.
No leader or acceptance record was fabricated to make that gate green.

Actual NetBSD/SDF, live host probe and mailbox scan are NOT_RUN. No SDF session
was established. The fake NetBSD fixtures do not substitute for that boundary.
The probe requires Python 3.9+ and records delivery-lock UNKNOWN. No live mail
was read or mutated. PR: https://github.com/isomorphisms/catfood/pull/116.
This PR is not claimed universally green or merge-ready.
