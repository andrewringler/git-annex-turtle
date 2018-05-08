#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

xcodebuild clean build test -project "src/git-annex-turtle.xcodeproj" -scheme "git-annex-turtle" -configuration "Release" SYMROOT=dist/

if [ $? -ne 0 ]; then echo "Quiting… failure during build|test|release"; exit 1; fi;

.travis/package-release.sh

if [ $? -ne 0 ]; then echo "Unable to package release"; exit 1; fi;

echo "Build release DMG success at src/dist/git-annex-turtle-{VERSION}.dmg"
exit 0
