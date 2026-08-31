#!/usr/bin/env sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

sh -n termux-bootstrap.sh
sh -n bootstrap.sh
sh -n update-tools.ysh

grep -Fx '#!/usr/bin/env sh' termux-bootstrap.sh >/dev/null
grep -Fx '#!/usr/bin/env grease' termux-setup.grease >/dev/null
grep -F 'CATFOOD_ROOT:-$HOME/opt' termux-bootstrap.sh >/dev/null
grep -F 'CATFOOD_DEPTH:-1' termux-bootstrap.sh >/dev/null
grep -F 'SKIP %-21s' termux-bootstrap.sh >/dev/null
grep -F 'OPENAI_API_KEY_FILE' termux-bootstrap.sh >/dev/null
grep -F 'openai-api-key SKIP' termux-setup.grease >/dev/null || \
    grep -F 'openai-api-key' termux-setup.grease >/dev/null

# Fetching a named branch alone updates FETCH_HEAD but need not create or
# refresh origin/<branch>.  Every updater that later consumes origin/<branch>
# must fetch that remote-tracking ref explicitly.
grep -F 'refs/remotes/origin/$branch' termux-bootstrap.sh >/dev/null
grep -F 'refs/remotes/origin/$grease_branch' bootstrap.sh >/dev/null
grep -F 'refs/remotes/origin/$branch' update-tools.ysh >/dev/null

if grep -E 'sk-(proj-)?[A-Za-z0-9_-]{20,}' termux-bootstrap.sh termux-setup.grease TERMUX.md >/dev/null; then
    printf '%s\n' 'secret-shaped OpenAI key material found in tracked Termux setup files' >&2
    exit 1
fi

printf '%s\n' 'Termux bootstrap structural checks passed'
