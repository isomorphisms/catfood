# SDF host evidence through checked Ithon

Purpose: reconcile PR #116 with the accepted positive-host/device oracle and
remove its newly introduced owned Python probe and tests. No live SDF access,
mailbox read/move, delivery-lock qualification or device result is claimed.

Type sketch: probe(source ∈ str, destination ∈ str, require_netbsd ∈ bool)
returns list[str] of metadata observations. Paths, OS metadata, argparse and
unittest are explicit standard-library object boundaries; numeric/text values
used by owned policy receive membership types. The command and imported local
library are both .pi modules checked by Ithon's mandatory import loader.

Actual frontend: dilapidated-shed/ithon accepted host-control source
d6e83969f82512e920fb17b44326cb54f31d015c, merged as
9d530f4ad51f5b0a09c3e74dbe45cac5bb6d52d3. Local substrate: Python 3.12.14
on Linux x86_64. No stock-Python execution substitutes for the checked sources.

Retained attempts and observed refusals:

- 01-string-boundary.pi: string concatenation could not infer a foreign join
  result. The final source annotates the standard-library text results.
- 02-optional-location.pi: an optional string was not a Boolean condition.
- 03-optional-comparison.pi: the frontend does not yet compare an optional
  string to None. The final source explicitly converts it with bool().
- 04-command-context.pi: a bare membership expression did not declare the
  command context. The final library has no command effects; its separate
  checked entrypoint owns argparse and printing.
- 05-imported-result.pi: an imported function's result needed an explicit
  list[str] boundary before iteration; the imported implementation is itself
  mandatory-checked Ithon, not foreign first-party Python.
- 06-typed-test-environment.pi: dict needed an explicit builtins import.
- 07-explicit-test-discovery.pi: unittest.main discovered zero tests in the
  host runner's distinct __main__ module and returned status 5. This is FAIL,
  not four passing tests. The final runner selects HostTests explicitly and
  requires exactly four executed tests, successful results and zero skips.

Final local execution: `ithon tests/sdf_mailbox.pi` executes four tests,
zero failures and zero skips. The current identity/ABI regression suite runs
inside the real entrypoint group. The old cloud-default mutation is exercised
against the actual detection function independently of the second host guard.
Both probe modules pass complete checking; the actual command refuses
--require-netbsd on this Linux host and reports UNKNOWN delivery locking.

The earlier historical Python receipts remain historical. Hosted Python 3.9
and 3.12 substrate runs of the new checked modules are still required; actual
SDF NetBSD execution and installed Ithon availability remain NOT_RUN.
