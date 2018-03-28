## TODO (move into github issues)
 * PERFORMANCE: childrenNotIgnored.sh is super slow (4seconds for a small directory) and is probably not necessary, this is delaying getting full folder information
 * PERFORMANCE: we are sharing a single sqlite instance among many processes, I imagine there must be some contention here, I think it would be simpler and faster to just have main turtle app deal with the database and have all Finder Sync extensions communicate with it via IPC, see http://nshipster.com/inter-process-communication/, https://github.com/itssofluffy/NanoMessage, https://stackoverflow.com/questions/41016558/how-should-finder-sync-extension-and-main-app-communicate?utm_medium=organic&utm_source=google_rich_qa&utm_campaign=google_rich_qa
 * BUG: some process is adding just filenames (not complete relative paths) to the database
 * commit workflows, commit, sync, sync --content, show un-committed file status (new icon or badge)
 * TODO, requestBadgeIdentifier already has information on whether a path is a file vs directory, I believe the call url.hasDirectoryPath is cached, might as well hold onto this during Finder Sync requests so we don't have to re-calculate
 * Delete old entries in database. unused repos are never deleted, deleted, renamed files still have database entries. (deleted files are now deleted if their parent folder is scanned) 
 * crop or scroll large git error messages that appear in Dialogs
 * don't process command requests if older than 2-seconds, IE they should only ever be immediate responses to user actions, LOG if older than 2-seconds since this should never happen
 * don’t do command requests for folders still scanning? or at least figure out how to handle them well, also don’t enable context menus until folders done scanning, or figure out how to handle them quickly :)
 * occasional UI lockup (IE menubar icon doesn't work) when manual terminal git tasks are running concurrently with git-annex-turtle
 * add sidebar icon, so the icon is shown when the user has dragged the repo folder onto the sidebar
 * nice, renice git during full scan (or always?)
 * BUG: quiting from menubar icon should quit running git processes too
 * Finder Sync extension should quit automatically if menubar app is not running, this could happen if it crashes and doesn't tell the Finder Sync extension to quit, or is killed by a user or XCode
 * how can we get more control over how and when Finder Sync is actually launched?, do we actually need to restart Finder when installing extension, this kills and reloads all finder windows…
 * get tests running on https://travis-ci.org/
 * Menubar window should show list of files querying and give option to pause, since our querying of git could stall a user's operations in the terminal
 * Menubar window should show list of remote transfers 
 * let user view/set git and git-annex binary paths from GUI
 * let user view/set per repo git-annex-turtle settings from GUI
 * Test with v6 repos
 * Test with git annex watch
 * in v5 repo, unlocked present files have no git annex info, so are currently showing up as a ?. We could save the key for these paths, but many git annex commands don't operate on keys. We could use `git annex readpresentkey <key> <remote uuid>`, but we would have to start storing keys, storing remotes and do a bit of calculating. More generally, when files are unlocked the user can change its content at any time, we could do a file system of kqueue watch? Also, in v5 repo, changing state between unlocked and locked does not affect git or git-annex branches
 * what should we do when switching branches? should probably hide badge icons when switching to the git-annex branch, when switching to other branches, like views, it is probably OK to re-calculate all badges?
 * bundle git-annex with turtle, or have some install script that will download it. Yes, Joey actually suggested bundling it with the mac version of git-annex.
 * how do we track changes in the numcopies settings from the terminal? changing numcopies in git annex will update numcopies.log in the git-annex branch, so we can detect that, but users can add per file, per path numcopies settings anywhere in the repo in a gitattributes file https://git-annex.branchable.com/copies/, https://git-scm.com/docs/gitattributes
 * don't allow nested repositories watching, git-annex probably doesn't allow this anyway, but who knows what this would do to our database!
 * don't display git-annex lock context menu in v5 repos, it always fails without force?
 * show / hide relevant menu items in contextual menu, IE if file is present don't show get menu. TODO, wait until we are more confident we can maintain an accurate representation of file state until doing this? IE, v6 repos we don't need git add, vs git annex add (they are the same), right?
 * replace all absolute paths to repository roots with Apple File System Bookmark URLS so we can track files correctly even if the user moves the git repository to another location on their hard-drive
 * after a git annex get if we already have an item highlighted the Finder thumb preview doesn't update? possible to do that? or is there just a delay?
 * what icons to display for git files, staged, in a commit, unstaged, etc…, maybe copy what git annex status does
 * rename git-annex-finder process name to 'git-annex-turtle Finder'
 * rename git-annex-mac-cmd to 'git-annex-turtle-cli'
 * Search? it would be nice to have a search interface integrated into the menubar icon, search working directory, search git history, etc…
 * Change main icon to blocky turtle, animated menubar icon to swimming turtle

## New Users (Thoughts) UX
Should git-annex-turtle be usable by people who have never used git-annex?

One possible workflow for new users:

Create a new local directory for them, lets say at `~/annex` by default with the following settings:

   git annex init --version=6
   git config annex.thin true
   git annex adjust --unlock
   
Clone this repo to a USB hard drive, say `/Volumes/USB-4TB/annex`. Then they can move files back and forth, drop files etc…

It would be nice if there was some affordable, scalable cloud options for new users…

Combining annex.thin with say a bup repo stored in the .git directory, might provide some safety while limiting disk usage?
 
## Internal: Tutorials, References, XCode & Swift Help
 * https://www.raywenderlich.com/98178/os-x-tutorial-menus-popovers-menu-bar-apps menubar tutorial
 * https://www.raywenderlich.com/128039/command-line-programs-macos-tutorial commandline tutorial (XCode 8)
 * https://developer.apple.com/macos/human-interface-guidelines/system-capabilities/search-and-spotlight/ for Spotlight and Search support. It would be nice to add Quicklook support for non-present files and Spotlight support for symlinked files (which are ignored by Spotlight)
 * https://www.raywenderlich.com/151741/macos-development-beginners-part-1
 * start of a FinderSync extension for git https://github.com/uliwitness/LittleGit/blob/master/LittleGitFinderSyncExtension/GitFolderStatus.swift
 * example project using Finder Sync https://github.com/glegrain/GitStatus/tree/master/GitStatus
 * DispatchGroups barriers, https://blog.vishalvshekkar.com/swift-dispatchgroup-an-effortless-way-to-handle-unrelated-asynchronous-operations-together-5d4d50b570c6
 * Currently UserDefaults is working fine for sharing data between the host app and the Finder Sync extension, but this might not scale for thousands of files, might need to switch to sqLite database, which can be stored in a common location then each target reads/writes to it (or Core Data)
 * https://www.raywenderlich.com/173972/getting-started-with-core-data-tutorial-2
 * https://www.raywenderlich.com/167743/sqlite-swift-tutorial-getting-started
 * http://www.atomicbird.com/blog/sharing-with-app-extensions
 * https://stackoverflow.com/questions/30156107/swift-share-sqlite-database-between-app-and-extension
 * http://dscoder.com/defaults.html
 * TODO, more fine grain control of how often we query git-annex, see The Dispatch queue https://www.raywenderlich.com/148513/grand-central-dispatch-tutorial-swift-3-part-1
 * See https://developer.apple.com/documentation/foundation/userdefaults section Persisting File References for advice on preserving permalink links to folders that work even across renames, probably better to do this, instead of using string paths :)
 * Interprocess communication http://ddeville.me/2015/02/interprocess-communication-on-ios-with-berkeley-sockets
 * https://stackoverflow.com/questions/2405305/how-to-tell-if-a-file-is-git-tracked-by-shell-exit-code maybe useful tricks for files that are in git, but not annex, also see https://git-scm.com/docs/git-ls-files for more details
 
## Useful Troubleshooting Notes 
 Check if our Finder Sync extension is running:

     pluginkit -m | grep finder

 Depending on which target is running, debug output might not show up in the XCode console. But if you launch the system Console app, it should be there.

 Check for open files <https://www.cyberciti.biz/faq/howto-linux-get-list-of-open-files/>, first get process ID

     ps -aef | grep git-annex
     
 Then list open files

     lsof -p <process-id> | less
     
 Full scan
 took 22min. for my 60,000 file repo on solid-state drive
