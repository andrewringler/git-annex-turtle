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

scp -i ~/.ssh/id_rsa_andrewringlerdownloads $DMG_PATH ${TURTLE_DEPLOY_DOWNLOADS_USER}@downloads.andrewringler.com:~/downloads.andrewringler.com/git-annex-turtle/$DMG_NAME

if [ $? -eq 0 ]
then
	echo "Successfully uploaded $DMG_NAME to downloads.andrewringler.com"
	exit
else 
	echo "error uploading $DMG_NAME to downloads.andrewringler.com"
	exit -1
fi
