# git-annex-mac
*git-annex-mac* provides git-annex status updates on the Mac via integration with Finder and a Menubar icon (aka menubar extra). This app relies on the Finder Sync API so is only available on OS-X 10.10 (Yosemite) and later.

## Notes
 * https://github.com/liferay/liferay-nativity could provide Finder integration for older OSes if needed.

### Tutorials / Help
 * https://www.raywenderlich.com/98178/os-x-tutorial-menus-popovers-menu-bar-apps menubar tutorial
 * https://www.raywenderlich.com/128039/command-line-programs-macos-tutorial commandline tutorial (XCode 8)
 * https://developer.apple.com/macos/human-interface-guidelines/system-capabilities/search-and-spotlight/ for Spotlight and Search support. It would be nice to add Quicklook support for non-present files and Spotlight support for symlinked files (which are ignored by Spotlight)
 * start of a FinderSync extension for git https://github.com/uliwitness/LittleGit/blob/master/LittleGitFinderSyncExtension/GitFolderStatus.swift
 * example project using Finder Sync https://github.com/glegrain/GitStatus/tree/master/GitStatus
 * Currently UserDefaults is working fine for sharing data between the host app and the Finder Sync extension, but this might not scale for thousands of files, might need to switch to sqLite database, which can be stored in a common location then each target reads/writes to it (or Core Data)
  * https://www.raywenderlich.com/173972/getting-started-with-core-data-tutorial-2
  * https://www.raywenderlich.com/167743/sqlite-swift-tutorial-getting-started
  * http://www.atomicbird.com/blog/sharing-with-app-extensions
  * https://stackoverflow.com/questions/30156107/swift-share-sqlite-database-between-app-and-extension
  * http://dscoder.com/defaults.html
 
Check if our Finder Sync extension is running:

    pluginkit -m | grep finder

Depending on which target is running, debug output might not show up in the XCode console. But if you launch the system Console app, it should be there.
