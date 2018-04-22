#!/bin/sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MAJOR_VERSION=`defaults read "$DIR/../src/git-annex-mac/Info.plist" CFBundleShortVersionString`
[ -z "$MAJOR_VERSION" ] && echo "unable to read major version number from app" && exit -1
GIT_COMMIT_HASH=`defaults read "$DIR/../src/git-annex-mac/Info.plist" GIT_COMMIT_HASH`
[ -z "$GIT_COMMIT_HASH" ] && echo "unable to read git commit hash from app" && exit -1
VERSION_STRING="$MAJOR_VERSION-$GIT_COMMIT_HASH"
DMG_NAME="git-annex-turtle-$VERSION_STRING.dmg"
DMG_PATH="$DIR/../src/dist/$DMG_NAME"

if [ ! -f $DMG_PATH ]; then
    echo "Could not find DMG at '$DMG_PATH'"
		exit -1
fi

echo "Uploading $DMG_NAME to downloads.andrewringler.com…"

# pipes to /dev/null to minimize chance of pass exposure
# see https://docs.travis-ci.com/user/best-practices-security/
curl -T $DMG_PATH sftp://${TURTLE_DEPLOY_DOWNLOADS_USER}:${TURTLE_DEPLOY_DOWNLOADS_PASS}@downloads.andrewringler.com/~/downloads.andrewringler.com/git-annex-turtle/$DMG_NAME

if [ $? -eq 0 ]
then
	echo "Successfully upload $DMG_NAME to downloads.andrewringler.com"
else 
	echo "error uploading $DMG_NAME to downloads.andrewringler.com"
	exit -1
fi
