# APK delivery boundary

Requirement: fetch an APK declared in the existing packages manifest, verify its
exact SHA-256 before giving it its final name, and record source/package identity.
This command delivers an artifact. It must not claim installation, launch or
physical acceptance. It must reject a missing/duplicate package, a non-APK row,
an unsafe destination, download failure and mismatched bytes. It must never
overwrite an existing destination or silently fall back to a source build.

APK rows extend the existing package inventory with mode `apk`; they do not
invent executable CLI entrypoints. Grease owns post-bootstrap delivery. The
existing POSIX entrypoint and manifest checker remain named migration debt.
The test transport is a checked Ithon fixture, not publication or device proof.
Real release URLs and exact hashes must be fetched separately before enrollment.

The first reuse-check attempt used `\t` inside a Grease double-quoted string;
the real frontend rejected it as an invalid escape. The corrected source obtains
one literal tab through `printf` and interpolates that exact character.

Actual checking also rejected untyped foreign string expressions, string/list
addition outside the admitted static surface, and an Ithon fixture invoked
through a basename without `.pi`. The fixture now uses a Grease argv-preserving
launcher and passes the real `.pi` source to Ithon. Catalog paths contain spaces.
The helper takes its catalog from the explicit root; it does not assume shell
variables import environment values in the modified Grease runtime.

Repeated local tests against one deleted/recreated evidence directory observed
old tampered fixtures reappear; their retained file timestamps predate that
directory's recreation. The external cause is unverified. Each test invocation
now creates a fresh unique directory and retains all attempts, so stale negative
fixtures cannot become the next invocation's positive input.

The independent AI-CI paired-artifact verifier owns package, signer and ELF
qualification before APK bytes enter the approved inventory. The device's
Android package installer remains a separate physical acceptance boundary.

## Admission remains blocked

The compatibility corpus executed both ABI fixtures, safe repeats and ten
rejecting controls. It used the historical compiled C++ Grease engine. The
explicit human correction in Flexible Pipes issue #67 prohibits that runtime
on managed workbenches; it was discovered after those attempts. Those results
are NOT_ELIGIBLE for managed runtime admission. No APK package rows or
publication claims are added. The CI prerequisite stays red until Cat Food
acquires an independently accepted compatible C++-free Grease closure. The
partial D translation and stock shells cannot substitute for it.
