## General Design
The main application, `git-annex-turtle`, is responsible for launching/re-launching the Finder Sync Extension (`git-annex-turtle-finder`), displaying a Menubar Icon, and periodically monitoring the state of watched folders.

When `git-annex-turtle-finder` is launched it checks the database table `WatchedFolderEntity` for the list of folders to watch. It then registers these so macOS will notify when any of these folders (or their children) become visible/invisible in a Finder window.

When `git-annex-turtle-finder` receives a `requestBadgeIdentifier` it means a new file path (file or folder) is visible in a Finder window that it is observing. So, it first checks if there is an entry in `PathStatus`, if so, it uses it; If not, it adds a new database entry to `PathRequestEntity`. `git-annex-turtle-finder` periodically checks the `PathStatus` table for updates, IE as status of files change in git-annex, present / not-present / number of copies, this is reflected in `PathStatus` and `git-annex-turtle-finder` sees these updates.

The main application, `git-annex-turtle`, periodically monitors the `PathRequestEntity` table for new entries. As it handles them, it deletes the entries and adds them as new entries in the `PathStatus` table. `git-annex-turtle` monitors all entries in `PathStatus` periodically, updating them in the database as their state changes on disk.

## New Users
Should git-annex-turtle be usable by people who have never used git-annex?

One possible workflow for new users:

Create a new local directory for them, lets say at `~/annex` by default with the following settings:

    git annex init --version=6
    git config annex.thin true
    git annex adjust --unlock
    
Clone this repo to a USB hard drive, say `/Volumes/USB-4TB/annex`. Then they can move files back and forth, drop files etc…


## TODO
 * a large root folder can take a long time to compute status for, this can get processor/disc intensive if we need to re-calculate every time any child is invalidated, perhaps we need a full scan of the entire repo and store information for every file, then track updates?
 * menu-bar icon should animate while performing actions. Menu should show list of files querying and give option to pause, since our querying of git could stall a user's operations in the terminal
 * Test with Assistant
 * Test with v6 repos
 * Test with git annex watch
 * save latest commit hashes in Db, start where we left off on restarts
 * replace hard-coded absolute paths to git-annex installation with more graceful solution, probably should save user's path location in git-watch config, let them override, but automatically detect from ~/.bash_profile, and/or paths, see https://askubuntu.com/questions/59126/reload-bashs-profile-without-logging-out-and-back-in-again, https://stackoverflow.com/questions/41535451/how-to-access-the-terminals-path-variable-from-within-my-mac-app-it-seems-to
 * in v5 repo, unlocked present files have no git annex info, so are currently showing up as a ?. We could save the key for these paths, but many git annex commands don't operate on keys. We could use `git annex readpresentkey <key> <remote uuid>`, but we would have to start storing keys, storing remotes and do a bit of calculating. More generally, when files are unlocked the user can change its content at any time, we could do a file system of kqueue watch? Also, in v5 repo, changing state between unlocked and locked does not affect git or git-annex branches
 * what should we do when switching branches? should probably hide badge icons when switching to the git-annex branch, when switching to other branches, like views, it is probably OK to re-calculate all badges?
 * bundle git-annex with turtle, or have some install script that will download it
 * how do we track changes in the numcopies settings from the terminal? changing numcopies in git annex will update numcopies.log in the git-annex branch, so we can detect that, but users can add per file, per path numcopies settings anywhere in the repo in a gitattributes file https://git-annex.branchable.com/copies/, https://git-scm.com/docs/gitattributes
 * don't allow nested repositories watching, 
 * don't display git-annex lock context menu in v5 repos, it always fails without force?
 * show / hide relevant menu items in contextual menu, IE if file is present don't show get menu. TODO, wait until we are more confident we can maintain an accurate representation of file state until doing this?
 * replace all absolute paths to repository roots with Apple File System Bookmark URLS so we can track files correctly even if the user moves the git repository to another location on their hard-drive
 * after a git annex get if we already have an item highlighted the Finder thumb preview doesn't update? possible to do that? or is there just a delay?
 * what icons to display for git files, staged, in a commit, unstaged, etc…, maybe copy what git annex status does
 * rename git-annex-finder process name to 'git-annex-turtle Finder'
 * rename git-annex-mac-cmd to 'git-annex-turtle-cli'
 * better logging? what do people use https://stackoverflow.com/questions/7512211/how-to-output-warnings-to-the-console-during-a-build-in-xcode
 
## Querying git-annex
git-annex-turtle needs to keep informed of the state of files in git-annex repositories. Some file state is slow to query, other state very fast to query. Some state will get quicker to query as Joey adds [caching databases](https://git-annex.branchable.com/design/caching_database/), but given the current, various queries relevant to git-annex-turtle are documented below:

### present
`git annex info --json --fast <path>` will quickly return whether a file is present or not. For a directory this will return local annexed file count vs working tree fill count, which is a good measure of how “present” a directory is. For large directories this can be quite slow.

### copies
`git annex whereis --json --fast <path>` will quickly return the number of copies of a file and which remotes they are in. For directories git-annex returns this information for each file recursively. For large directories this can be quite slow.

### enough copies
The number of copies of a file is a good metric for the “health” of that file. Another useful metric of health is comparing the number of copies of a file to the user specified [numcopies setting](https://git-annex.branchable.com/git-annex-numcopies/) setting. This can be global, or on a per file-type basis.

One way to do that is to use the `find` command with git-annex matching options. The following will return no `stdout` if a file has enough copies, given the user's copy setting:

`git-annex --json --fast --lackingcopies=1 find <path>`

For directories this will recursively check for each file. For large directories this can be quite slow. For git-annex-turtle we could mark a directory as “lacking copies” if any file contained within is lacking copies. With the find command, git-annex, incrementally returns results as it finds them. Since we only care if there is at least one result, we could save time stopping the search as soon as we find one result. 

Alternatively, (to querying lackingcopies) we could count the copies for a given file then compare that to the numcopies setting. Since numcopies can be set on a per file basis, we would also have to manually parse the .gitattributes file. This doesn't seem too future proof, since more complicated expressions for calculating desired numcopies on a per file basis could be added at any time (by Joey).

### caching
For files, all of the questions we want to ask of git-annex are quite speedy. For directories they can get quite slow. We could cache these results, then update the cache as the counts change. We can detect changes in the counts by added a git hook at `git/hooks/post-update-annex`. We would then parse the latest commit `git show git-annex`, and update counts for all files mentioned.
 
Also see https://git-annex.branchable.com/forum/_Does_git_annex_find___40____38___friends__41___batch_queries_to_the_location_log__63__/ for some related thoughts on pulling git-annex information directly from the branch
 
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
 
Check if our Finder Sync extension is running:

    pluginkit -m | grep finder

Depending on which target is running, debug output might not show up in the XCode console. But if you launch the system Console app, it should be there.

Check for open files <https://www.cyberciti.biz/faq/howto-linux-get-list-of-open-files/>, first get process ID

    ps -aef | grep git-annex
    
Then list open files

    lsof -p <process-id> | less
