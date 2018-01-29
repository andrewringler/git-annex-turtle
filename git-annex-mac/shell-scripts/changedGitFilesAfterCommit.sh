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

/Applications/git-annex.app/Contents/MacOS/git log --pretty=format:"%H" $COMMIT_HASH..HEAD | xargs -I {} /Applications/git-annex.app/Contents/MacOS/git diff-tree --no-commit-id --name-only -r {} | uniq
