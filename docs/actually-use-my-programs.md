# Actually use my programs

This branch explores a simple requirement: an agent should use the user's
existing named programs instead of silently substituting a generic mechanism.

## Program-selection contract

- If the user names a program, use that program for the requested operation.
- `AZ` means the Cat Food `az` program.
- Any request to search Amazon uses `az`, even when the user does not spell
  out `AZ` in that turn.
- Do not silently substitute a generic web search, browser search, or another
  shopping/search implementation for `az`.
- If the required named program is unavailable, report that boundary instead
  of pretending a substitute satisfied the request.
- Locate repository checkouts with `./catfood where [TOOL]`; do not guess
  paths from repository names.

## Model candidates

The candidates live in `models.tsv`.  They are candidates for instruction-
following and tool-selection evaluation, not accepted runtimes.

The first useful evaluation should test the behavior above directly: explicit
`AZ`, implicit Amazon search, long-context recall, conflicting nearby
instructions, unavailable-tool behavior, and requests involving both `az`
and another tool.  A pass requires choosing the named program, not merely
producing an equivalent-looking answer.
