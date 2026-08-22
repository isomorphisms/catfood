#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOOLS="$ROOT/tools"
GREASE="$TOOLS/grease"
GREASE_URL=https://github.com/isomorphisms/grease.git
GREASE_BRANCH=main

mkdir -p "$TOOLS"

if [ -d "$GREASE/.git" ]; then
  printf '%s\n' '==> grease'
  git -C "$GREASE" fetch --prune origin "$GREASE_BRANCH"
  git -C "$GREASE" checkout "$GREASE_BRANCH"
  git -C "$GREASE" merge --ff-only "origin/$GREASE_BRANCH"
else
  git clone --branch "$GREASE_BRANCH" --single-branch --recurse-submodules \
    "$GREASE_URL" "$GREASE"
fi

git -C "$GREASE" submodule sync --recursive
git -C "$GREASE" submodule update --init --recursive

exec "$GREASE/source/bin/ysh" "$ROOT/update-tools.ysh"
