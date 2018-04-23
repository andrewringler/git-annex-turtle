#!/bin/sh

echo "downloading git-annex-2018-4-9.dmg…"
curl -O https://downloads.andrewringler.com/git-annex-turtle-dependencies/git-annex-2018-4-9.dmg
VERIFY=`shasum -c .travis/git-annex-2018-4-9.dmg.sha256`
if [ "$VERIFY" != "git-annex-2018-4-9.dmg: OK" ]
then
	echo "invalid checksum for git-annex"
	exit -1
fi
 
echo "installing git-annex…"
hdiutil mount git-annex-2018-4-9.dmg
sudo mkdir -p /Applications
sudo cp -R /Volumes/git-annex/git-annex.app /Applications/
export PATH=/Applications/git-annex.app/Contents/MacOS:$PATH
echo "export PATH=/Applications/git-annex.app/Contents/MacOS:$PATH" >> ~/.bash_profile
