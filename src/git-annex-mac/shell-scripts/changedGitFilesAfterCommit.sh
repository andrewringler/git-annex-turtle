#!/bin/sh

#  changedGitFilesAfterCommit.sh
#  git-annex-turtle
#
#  Created by Andrew Ringler on 1/28/18.
#  Copyright © 2018 Andrew Ringler. All rights reserved.

# remove quotes Swift might add
COMMIT_HASH=$1
COMMIT_HASH="${COMMIT_HASH%\"}"
COMMIT_HASH="${COMMIT_HASH#\"}"

GIT_CMD=${2:-git}
GIT_CMD="${GIT_CMD%\"}"
GIT_CMD="${GIT_CMD#\"}"

MAIN_BRANCH="master"
if git show-ref --quiet --branches master; then
    MAIN_BRANCH="master"
elif git show-ref --quiet --branches main; then
    MAIN_BRANCH="main"
fi

$GIT_CMD log --pretty=format:"%H" $COMMIT_HASH..refs/heads/$MAIN_BRANCH | xargs -I {} $GIT_CMD diff-tree --no-commit-id --name-only -r {} | uniq
