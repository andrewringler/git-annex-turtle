#!/bin/sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# adpated from https://github.com/andreyvit/create-dmg
CREATE_DMG_BIN="$DIR/create-dmg/create-dmg"
BACKGROUND_IMG="$DIR/../assets/dmg/dmg-background.png"
VOL_ICON="$DIR/../assets/dmg/AppIcon.icns"
APP_LOCATION="$DIR/../src/dist/Release/git-annex-turtle.app"

MAJOR_VERSION=`defaults read "$DIR/../src/git-annex-mac/Info.plist" CFBundleShortVersionString`
[ -z "$MAJOR_VERSION" ] && echo "unable to read major version number from app" && exit -1
GIT_COMMIT_HASH=`defaults read "$DIR/../src/git-annex-mac/Info.plist" GIT_COMMIT_HASH`
[ -z "$GIT_COMMIT_HASH" ] && echo "unable to read git commit hash from app" && exit -1
VERSION_STRING="$MAJOR_VERSION-$GIT_COMMIT_HASH"
DMG_NAME="git-annex-turtle-$VERSION_STRING.dmg"
DMG_PATH="$DIR/../src/dist/$DMG_NAME"

$CREATE_DMG_BIN --hide-extension git-annex-turtle.app --icon git-annex-turtle.app 180 170 --window-size 660 400 --app-drop-link 480 170 --icon-size 160 --background $BACKGROUND_IMG --volicon $VOL_ICON --no-internet-enable $DMG_PATH $APP_LOCATION
