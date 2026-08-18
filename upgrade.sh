#!/bin/bash

set -Eeuo pipefail

SETUP_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export SETUP_ROOT

source "$SETUP_ROOT/scripts/lib/common.sh"

cd "$SETUP_ROOT"

command_exists git || die "git is required"
[[ -d .git ]] || die "$SETUP_ROOT is not a git checkout; clone the repository instead of downloading a copy"

if [[ -n $(git status --porcelain) ]]; then
  die "Uncommitted changes in $SETUP_ROOT; commit or stash them before upgrading"
fi

note "Fetching latest changes"
git fetch --quiet origin

branch=$(git rev-parse --abbrev-ref HEAD)
local_rev=$(git rev-parse HEAD)
remote_rev=$(git rev-parse "@{u}" 2>/dev/null) || die "Branch $branch has no upstream to pull from"

if [[ $local_rev == "$remote_rev" ]]; then
  note "Already up to date ($branch @ ${local_rev:0:12})"
else
  note "Updating $branch: ${local_rev:0:12} -> ${remote_rev:0:12}"
  git merge --ff-only "@{u}"
fi

note "Re-running setup to apply any changes"
exec "$SETUP_ROOT/setup.sh"
