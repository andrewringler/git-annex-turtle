#!/bin/sh

#  allChangedGitFiles.sh
#  git-annex-turtle
#
#  Created by Andrew Ringler on 1/28/18.
#  Copyright © 2018 Andrew Ringler. All rights reserved.
#
#  retrieve all files mentioned in any git commit
#

# remove quotes Swift might add
GIT_CMD=${1:-git}
GIT_CMD="${GIT_CMD%\"}"
GIT_CMD="${GIT_CMD#\"}"

$GIT_CMD log --pretty=format:"%H" | xargs -I {} $GIT_CMD diff-tree --no-commit-id --name-only --root -r {} | uniq

