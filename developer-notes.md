## TODO
 * migrate to Github Actions
 
## Bugs, definitely fix
 * if a repo is added when head is not master, a full scan should be run head becomes master again otherwise folders will never get added properly
 * quitting from the menubar icon should quit running git processes too
 * during a full-scan process memory spikes for git-annex-turtle process, and does not seem to return after some period of time, possibly memory leak here?
 * various timing issues with Queries related to parsing new information from git commits, probably need to switch to SQL (instead of CoreData), use transactions, or time updates more carefully in concert with analyzing git commits, see https://www.raywenderlich.com/167743/sqlite-swift-tutorial-getting-started, https://github.com/stephencelis/SQLite.swift
 * Test with v6 repos
 * Test with v7 repos
 * Test with git annex watch
 * some process is adding just filenames (not complete relative paths) to the database, verify fixed?
 * occasional UI lockup (IE menubar icon doesn't work) when manual terminal git tasks are running concurrently with git-annex-turtle, verify fixed?

## Bugs, can't fix?
 * after a git annex get if we already have an item highlighted the Finder thumb preview doesn't update? Finder bug?
 * occasionally all my sidebar favorites and settings disappear, then re-appear on reboot. Perhaps from too frequent restarting of Finder? This does not seem to be a resolvable issue http://www.iphoneincanada.ca/how-to/fix-missing-finder-favourites/, https://apple.stackexchange.com/questions/208205/file-open-dialog-is-missing-sidebar-items

## Not greats, should fix & UX issues
 * don't process command requests if older than 2-seconds, IE they should only ever be immediate responses to user actions, LOG if older than 2-seconds since this should never happen
 * crop or scroll large git error messages that appear in Dialogs
 * don’t do command requests for folders still scanning? or at least figure out how to handle them well, also don’t enable context menus until folders done scanning, or figure out how to handle them quickly :)
 * how can we get more control over how and when Finder Sync is actually launched?, do we actually need to restart Finder when installing extension, this kills and reloads all finder windows…
 * how do we track changes in the numcopies settings from the terminal? changing numcopies in git annex will update numcopies.log in the git-annex branch, so we can detect that, but users can add per file, per path numcopies settings anywhere in the repo in a gitattributes file https://git-annex.branchable.com/copies/, https://git-scm.com/docs/gitattributes
 * partially empty icons are hard to read, possibly switching from horizontally filled to diagonally filled would fix this.
 * get badge icons to grab higher resolution versions of PNG icons when available, currently it is always grabbing the low res one

## New Features, yes
 * add sidebar icon, so the icon is shown when the user has dragged the repo folder onto the sidebar
 * log to our own logs folder in ~/Library/Logs/git-annex-turtle/git-annex-turtle.log, ~/Library/Logs/git-annex-turtle/git-annex-finder-{process-id}.log, etc… instead of directly to Console, see logging frameworks, https://stackoverflow.com/a/5938021/8671834, https://github.com/DaveWoodCom/XCGLogger, https://github.com/CocoaLumberjack/CocoaLumberjack#readme
 * enable verbose logging in UI, link to open logs folder from UI
 * actually use and expose in UI all per repo settings currently in turtle-monitor namely the flags: finder-integration, context-menus, track-folder-status, track-file-status
 * add auto-launch at Login feature in UI, maybe this project https://github.com/sindresorhus/LaunchAtLogin would be useful for that… or just write a file and copy it to the correct place.
 * Handle branch switching, track branches separately in database
 * Button to launch webapp (from menubar icon and toolbar icon)
 * expose PATHS in config. We use PATHS to determine location of git special remote binararies. user should be able to choose if they want ~/.bash_profile to be loaded before issuing shell commands (to calculate PATH) or just choose their own manual PATH string.

## New Features, maybe
 * Change main icon to blocky turtle, animated menubar icon to swimming turtle
 * commit workflows, commit, sync, sync --content, show un-committed file status (new icon or badge)
 * Menubar window should show list of remote transfers 
 * Menubar window should show list of files querying and give option to pause, since our querying of git could stall a user's operations in the terminal
 * add copy --to buttons, need to add support for listing on remotes for this.
 * what icons to display for git files, staged, in a commit, unstaged, etc…, maybe copy what git annex status does
 * in v5 repo, unlocked present files have no git annex info, so are currently showing up as a ?. We could save the key for these paths, but many git annex commands don't operate on keys. We could use `git annex readpresentkey <key> <remote uuid>`, but we would have to start storing keys, storing remotes and do a bit of calculating. More generally, when files are unlocked the user can change its content at any time, we could do a file system of kqueue watch? Also, in v5 repo, changing state between unlocked and locked does not affect git or git-annex branches. Doing a git annex drop from the context menus does nothing and has no feedback, git annex drop from command-line has similar behavior.
 * show / hide relevant menu items in contextual menu, IE if file is present don't show get menu. TODO, wait until we are more confident we can maintain an accurate representation of file state until doing this? IE, v6 repos we don't need git add, vs git annex add (they are the same), right? don't display git-annex lock context menu in v5 repos, it always fails without force?
 * replace all absolute paths to repository roots with Apple File System Bookmark URLS so we can track files correctly even if the user moves the git repository to another location on their hard-drive
 * Search? it would be nice to have a search interface integrated into the menubar icon, search working directory, search git history, etc…
 * Intro dialog the first time git-annex-turtle is ever launched, containing found repos, git/git-annex install locations, preferences. Possibly a wizard for creating a new repo if the user doesn't have any.
 * On, first launch, auto find repos in https://myrepos.branchable.com/ (~/.mrconfig), and ~/.config/git-annex/autostart and ask user if they want to add them.
 * Save to git-annex button in Chrome. We could create a chrome extension to save current page to git-annex using addurl. See http://git-annex.branchable.com/tips/Using_Git-annex_as_a_web_browsing_assistant/, https://developer.chrome.com/extensions/messaging#native-messaging. We could use git-annex-turtle as a native messaging host?

## Chores
 * investigate all uses of `limitToMasterBranch: true` are these needed and/or working with users who have `main` as their main branch?
 * remove custom guards for limiting git-annex requests to the master branch and replace with the newly added `--branch=ref` param where applicable
 * rename git-annex-finder process name to 'git-annex-turtle Finder'
 * bundle git-annex with turtle, or have some install script that will download it. Yes, Joey actually suggested bundling it with the mac version of git-annex.
 * running git-annex-turtle from XCode in debug mode uses and registers finder sync extensions at ~/Library/Developer/Xcode/DerivedData/, but production app installed to /Applications/git-annex-turtle.app wants to use the finder sync extension in the .app bundle. This creates errors on launch. Perhaps the production Finder sync extension needs a different name, so they don't collide? Cleanup of the debug extension is difficult since involves removing the extension using `pluginkit -m -v -i com.andrewringler.git-annex-mac.git-annex-finder` to find the path of the extension we are using, removing that extension with pluginkit -r <full path>, then rebooting

## Performance, probably
 * re-use Process and Shells for the same repo? --batch would be useful for this, would need to detect and stop broken shells. Will probably need to implement a Swift Worker Queue for thread re-using and expiration based on GCD, namely git-annex info --json --batch would be very useful, we can quickly detect broken shells with '.git/config' which should always return success false and some other info.
 * add back in ignoring of duplicate path requests in HandleStatusRequestsProduction, this is especially noticeable during something like drop all files
 * nice, renice git during full scan (or always?)
 * childrenNotIgnored.sh is super slow (4seconds for a small directory) and is probably not necessary, this is delaying getting full folder information
 * we are sharing a single sqlite instance among many processes, I imagine there must be some contention here, I think it would be simpler and faster to just have main turtle app deal with the database and have all Finder Sync extensions communicate with it via our CFMessagePorts
 * requestBadgeIdentifier already has information on whether a path is a file vs directory, I believe the call url.hasDirectoryPath is cached, might as well hold onto this during Finder Sync requests so we don't have to re-calculate
 * Delete old entries in database. unused repos are never deleted, deleted, renamed files still have database entries. (deleted files are now deleted if their parent folder is scanned) 
 * during incremental updates combine multiple queries for the same repo into a single request, saves the overhead of spinning up a Process and Shell for each request and git-annex is probably faster at serving a single request for multiple files, than multiple requests
 * .app size (uncompressed) is now down to 14.2mb. 11.1mb of this is from embedded frameworks, apparently this is required because of ever-changing Swift (see https://www.reddit.com/r/swift/comments/3fq7dy/what_affects_libswiftcoredylibs_size/ and https://owensd.io/2016/08/22/swift-app-bundle-sizes/). currently the only way around this is to place your App in the app store (in which case “thinning” will occur before download, or to include less stuff in your build like no 32-bit version

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
 * get bridging headers to build in test targets this https://medium.com/if-let-swift-programming/ios-tests-working-with-objective-c-and-swift-class-together-aaf40f91a27c plus this https://stackoverflow.com/a/26855206/8671834
 
## Useful Troubleshooting Notes 
Check if our Finder Sync extension is running:

    pluginkit -m | grep finder

    show installed location of plugin
    pluginkit -m -v -i com.andrewringler.git-annex-mac.git-annex-finder
    
    remove plugin at installed location
    pluginkit -r <path>

Depending on which target is running, debug output might not show up in the XCode console. But if you launch the system Console app, it should be there.

Check for open files <https://www.cyberciti.biz/faq/howto-linux-get-list-of-open-files/>, first get process ID

    ps -aef | grep git-annex
    
Then list open files

    lsof -p <process-id> | less
    
Full scan
took 22min. for my 60,000 file repo on solid-state drive


While running from XCode the app is sandboxed so your user home directory is not `~`. The logs print out the current home directory usually something like: `/Users/<username>/Library/Containers/com.andrewringler.git-annex-turtle/Data`. If you need to edit the configuration file during development, you'll do that relative to that home directory for example the `turtle-monitor` file would be here: `/Users/andrew/Library/Containers/com.andrewringler.git-annex-turtle/Data/.config/git-annex/turtle-monitor`.