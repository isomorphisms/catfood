# Historical context

PR #16 was opened on 2026-08-26, when Cat Food's host provisioning path was much smaller than the present repository.

The work was paired conceptually with ai-ci PR #9, **“Exercise Cat Food from a bare cloud container.”** Cat Food #16 concentrated on construction and provenance: build the source tuple and say exactly what revisions were built. ai-ci #9 concentrated on independent acceptance from outside Cat Food.

A concrete failure shaped the PR. The first full provision successfully bootstrapped Idriç and then reached ICU, but an Idriç-generated Chez launcher could not find `scheme`. The correction was not to install an arbitrary system Chez. Instead, the PR exported Idriç's own checked/pinned `.tools/bin` runtime during dependent builds and placed that same runtime on the path used by stable wrappers.

That distinction matters: the intended evidence was about the compiler/runtime tuple Cat Food had actually built, not merely about whether some executable happened to run on the CI host.

The branch also expanded IB from a simple checkout into an actually exercised participant in the tuple, compiling several deterministic programs and exposing the arXiv prepaint command.

There were no PR discussion comments or inline review threads at archival time; the design rationale is therefore primarily in the PR description, commits, code comments, tests, and the failure/correction recorded above.
