#!/usr/bin/env bash
#
# Create a git repository
#

USAGE="$0 <GROUP> <PATH_TO_CREATE_REPOSITORY>"

# parse args
group="$1"
dest="$2"

die() { echo "Error: $*" && echo "Usage: $USAGE" >&2; exit 1; }

# ensure args are valid
[ "$group" ] || die "missing group name"
[ "$dest" ] || die "missing name of the repository directory"
[ -e "$dest" ] && die "$dest already exists"

# so we don't need to cd into dest dir
export GIT_DIR="$dest"

# set up dir/permissions
umask 002
mkdir "$dest" || exit 1
chgrp "$group" "$dest" && chmod 2775 "$dest" || exit 1

# initialize repo
git-init --shared || die "git-init failed"

# enable commit hooks
chmod a+x "$dest/hooks/post-update"
