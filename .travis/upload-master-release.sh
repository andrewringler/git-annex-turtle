#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MAJOR_VERSION=`defaults read "$DIR/../src/git-annex-mac/Info.plist" CFBundleShortVersionString`
[ -z "$MAJOR_VERSION" ] && echo "unable to read major version number from app" && exit -1
GIT_COMMIT_HASH=`defaults read "$DIR/../src/git-annex-mac/Info.plist" GIT_COMMIT_HASH`
[ -z "$GIT_COMMIT_HASH" ] && echo "unable to read git commit hash from app" && exit -1
VERSION_STRING="$MAJOR_VERSION-$GIT_COMMIT_HASH"
DMG_NAME="git-annex-turtle-$VERSION_STRING.dmg"
DMG_PATH="$DIR/../src/dist/$DMG_NAME"
PWD_CMD="$DIR/pwd.sh"

if [ ! -f $DMG_PATH ]; then
    echo "Could not find DMG at $DMG_PATH"
		exit -1
fi

echo "Uploading $DMG_NAME to downloads.andrewringler.com…"

# pipes to /dev/null to minimize chance of pass exposure
# see https://docs.travis-ci.com/user/best-practices-security/
# travi-ci.org does not support SSH keys, use passwords instead
# https://unix.stackexchange.com/a/187368
# https://stackoverflow.com/a/23632210/8671834
# Reads passwords from environment variables, set these up at
# https://travis-ci.org/andrewringler/git-annex-turtle/settings

> /dev/null 2>&1 /usr/bin/expect <<EOD
set timeout 45
spawn scp $DMG_PATH ${TURTLE_DEPLOY_DOWNLOADS_USER}@downloads.andrewringler.com:~/downloads.andrewringler.com/git-annex-turtle/$DMG_NAME

expect {
	"password:" { send "${TURTLE_DEPLOY_DOWNLOADS_PASS}\r"; exp_continue }
	"Permission denied" { exit 1 }
	timeout { puts "timeout uploading DMG"; exit 1 }
	expect eof	
}

lassign [wait] pid spawnid os_error_flag status
exit $status

EOD

if [ $? -eq 0 ]
then
	echo "Successfully uploaded $DMG_NAME to downloads.andrewringler.com"
	exit
else 
	echo "error uploading $DMG_NAME to downloads.andrewringler.com"
	exit -1
fi
