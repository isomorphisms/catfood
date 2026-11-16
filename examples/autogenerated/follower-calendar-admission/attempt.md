# Exact host-cell calendar admission

Purpose: qualify the existing PR's host metadata and sidecar reader against
impossible artifact expiry dates, retaining the published follower mechanism.

Type sketch: a normalized UTC timestamp is a four-digit positive Gregorian
year, month, valid day in that year/month, hour 0..23, minute and second 0..59,
and literal Z. Availability is permanent or a validated timestamp later than
a validated comparison clock. Synthetic fixture acceptance is not host evidence.

The first added adverse fixture exposed a real false accept: the original
reader accepted `until:2028-13-01T00:00:00Z` as available. The retained before
log records its failure. The repaired reader validates the calendar before
lexicographic ordering in both static host cells and per-job host sidecars.
Eight invalid dates/times, a valid leap-day positive control and an invalid
comparison clock run in the existing complete follower self-test.

This is an existing pre-Grease POSIX interface: the maintained workflow invokes
`sh followers/manage.sh` before provisioning Grease. Its inline portable AWK
calendar predicate repairs that required interpreter boundary. The boundary is
recorded in ci/shell-boundary.tsv; it does not select POSIX for new procedures.

Actual qualification used the existing independent AICI follower verifier
compiled by declared ICK C61, not ambient cc. The workflow now selects the same
declared ICK action. The complete follower fixture suite, Android delivery,
target classification, C67 delivery and target mutants passed on the combined
source with accepted main b5972788d85c04cb8b75881bc0df6fbcad2939bd. No SDF,
Void, phone, tablet or other physical qualification is claimed by these fixtures.

The exact current source still needs its normal pending follower obligations;
no synthetic fixture is recorded as a live accepted host receipt.
