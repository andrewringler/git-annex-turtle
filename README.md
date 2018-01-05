# git-annex-mac
*git-annex-mac* provides git-annex status updates on the Mac via integration with Finder and a Menubar icon (aka menubar extra). This app relies on the Finder Sync API so is only available on OS-X 10.10 (Yosemite) and later.

## TODO
 * Get context menus working for get and drop
 * after a git annex get if we already have an item highlighted the Finder thumb preview doesn't update? possible to do that? or is there just a delay?

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
* See https://developer.apple.com/documentation/foundation/userdefaults section Persisting File References for advice on preserving permalink links to folders that work even across renames, probably better to do this, instead of using string paths :)
* https://stackoverflow.com/questions/2405305/how-to-tell-if-a-file-is-git-tracked-by-shell-exit-code maybe useful tricks for 
 
Check if our Finder Sync extension is running:

    pluginkit -m | grep finder

Depending on which target is running, debug output might not show up in the XCode console. But if you launch the system Console app, it should be there.

Check for open files <https://www.cyberciti.biz/faq/howto-linux-get-list-of-open-files/>, first get process ID

    ps -aef | grep git-annex
    
Then list open files

    lsof -p <process-id> | less
