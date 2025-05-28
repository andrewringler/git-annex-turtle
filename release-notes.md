v0.3
This release contains updates to build on XCode 16.2.

**Upgrade Notes from v0.2**
The minimum required OS is now macOS 10.13.

**Features**
 * added Share context menu for sharing a single file to a public git exporttree

**Minor**
 * tests are now running in Github Workflows instead of Travis
 * we are now building with XCode 16.2 from macOS 15.3
 
**Bug Fixes**
 * fixed: now sourcing `~/.bash_profile` before running commands so we now have locations for git-annex special remote binaries
 * fixed [issue #3](https://github.com/andrewringler/git-annex-turtle/issues/3): missing `~/.config/git-annex` folder is created automatically now. thanks to [johannesjh](https://github.com/johannesjh) for reporting
 
v0.2
This release contains primarily bug fixes and performance improvements.

**Upgrade Notes from v0.1**
 * I have rev-ed the database version to v2. All full-scans will automatically re-occur, sorry, I know this is slow on large repositories. There were too many consistency issues in v0.1 to attempt a data migration. You may safely delete the old databases with suffix v1 stored at ~/Library/Group Containers/group.com.andrewringler.git-annex-mac.sharedgroup.
 
**Features**
 * clicking on watched repo from menubar drop-down now opens folder in Finder
 * edit git/git-annex paths from menubar preferences
 * added Finder Toolbar menu with repo-level and current folder level commands

**Minor**
 * added icon for preferences menu
 * added about dialog accessible from the menubar drop-down
 * all tests running on travis-ci now

**Bug Fixes**
 * fixed: PathStatus equals method was ignoring number of copies field causing us to miss many updates, creating database inconsistencies.
 * fixed: issue with running shell commands, resulting in a minimum of a 1-second delay, now badge icons should appear much quicker after commands like get/add/etc…
 * more expansive testing
 * fixed: after new files are created, added and committed, their badge icon are now correctly updated without having to navigate away from the folder
 * fixed: various timing issues preventing Finder Sync extensions from seeing latest status updates
 * fixed: first git commit was being ignored by incremental update scanner, various other issues with incremental scanner fixed.
 * fixed: potential issue with reloading list of watched repos in the preferences dialog
 * fixed: Finder Sync extension is following symlinks into .git/annex/object… sometimes, I don't know why and I can't reproduce reliably, but these are now always ignored in requestBadgeIdentifier calls
 * fixed: all tests running as suite now, instead of individually, all tests properly removing temporary directories on completion

v0.1
Initial beta release of git-annex-turtle

**Features**
 * monitor git-annex repositories
 * show badge icons in Finder for files and folders
 * context menus for files and folders
 * limited menubar notifications during git-annex activity

*Requires: macOS 10.12 or later and git-annex*
