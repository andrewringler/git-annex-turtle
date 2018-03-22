v0.2
**Features**
 * clicking on watched repo from menubar drop-down now opens folder in Finder

**Minor**
 * added icon for preferences menu
 * added about dialog accessible from the menubar drop-down

**Bug Fixes**
 * more expansive testing
 * fixed: after new files are created, added and committed, their badge icon are now correctly updated without having to navigate away from the folder
 * fixed: various timing issues preventing Finder Sync extensions from seeing latest status updates
 * fixed: first git commit was being ignored by incremental update scanner, various other issues with incremental scanner fixed.
 * fixed: potential issue with reloading list of watched repos in the preferences dialog


v0.1
Initial beta release of git-annex-turtle

**Features**
 * monitor git-annex repositories
 * show badge icons in Finder for files and folders
 * context menus for files and folders
 * limited menubar notifications during git-annex activity

*Requires: macOS 10.12 or later and git-annex*
