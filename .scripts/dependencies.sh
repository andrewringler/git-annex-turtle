#!/bin/sh

echo "downloading git-annex_10.20250520_x64.dmg…"
curl -O https://downloads.andrewringler.com/git-annex-turtle-dependencies/git-annex_10.20250520_x64.dmg
VERIFY=`shasum -c git-annex_10.20250520_x64.dmg.sha256`
if [ "$VERIFY" != "git-annex_10.20250520_x64.dmg: OK" ]
then
	echo "invalid checksum for git-annex"
	exit -1
fi
 
echo "installing git-annex…"
hdiutil mount git-annex_10.20250520_x64.dmg
sudo mkdir -p /Applications
sudo cp -R /Volumes/git-annex/git-annex.app /Applications/
export PATH=/Applications/git-annex.app/Contents/MacOS:$PATH
echo "export PATH=/Applications/git-annex.app/Contents/MacOS:$PATH" >> ~/.bash_profile
