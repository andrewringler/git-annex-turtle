#!/bin/sh

#
#  Filtered view of immediate children of passed directory
#  return all folders not in git ignore (and not .git)
#  and return all files tracked by git-annex
#
#  childrenNotIgnored.sh
#  git-annex-turtle
#
#  Created by Andrew Ringler on 2/5/18.
#  Copyright © 2018 Andrew Ringler. All rights reserved.

# remove quotes Swift might add
RELATIVE_PATH=$1
RELATIVE_PATH="${RELATIVE_PATH%\"}"
RELATIVE_PATH="${RELATIVE_PATH#\"}"

GIT_CMD=${2:-git}
GIT_CMD="${GIT_CMD%\"}"
GIT_CMD="${GIT_CMD#\"}"

GITANNEX_CMD=${3:-git-annex}
GITANNEX_CMD="${GITANNEX_CMD%\"}"
GITANNEX_CMD="${GITANNEX_CMD#\"}"

#!/bin/bash
find $RELATIVE_PATH -mindepth 1 -maxdepth 1 | sed 's|^\./||' | while read i
do
    $GIT_CMD check-ignore --no-index "$i" &>/dev/null
    if [ $? -ne 0 -a "$i" != ".git" ]; then
        if [ -d "$i" ]; then
            # OK, not in git-ignore
            # if it is a directory, then we want to know about it
            echo $i
        else
            INFO=`$GITANNEX_CMD info --fast --json "$i" 2>/dev/null`
            if [[ $INFO =~ "\"success\":true" ]]; then
                # OK, not a directory, but a file tracked by git-annex
                # we do want to know about it
                echo $i
            fi
        fi
    fi
done
