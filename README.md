# git-annex-turtle
*git-annex-turtle* provides Apple Finder integration, including badge icons, contextual menus and a Menubar icon (aka menubar extra) for [git-annex](http://git-annex.branchable.com/) on the Mac. It it a native Mac app written in Swift 4 with XCode 9.2 and requires macOS 10.12 or later.

*git-annex-turtle* is open-source, licensed under [The MIT License](https://opensource.org/licenses/MIT).

## Getting Started
### Install
Download and install [git-annex](http://git-annex.branchable.com/install/OSX/) for macOS. Follow the git-annex [walkthrough](http://git-annex.branchable.com/walkthrough/) if you have never used git-annex before.

Download and install git-annex-turtle.

### Usage
Click the git-annex-turtle Menubar icon, then click `Watch a repository`, select a git-annex repository to watch.

You are now all set. Open your git-annex repository in Apple Finder to see updated badge icons. Right click (control-click) on a file or folder to see git-annex specific context menus.

### Requirements
macOS 10.12 or later

*git-annex-turtle* relies on the Apple Finder Sync API so is only available on OS-X 10.10 (Yosemite) and later and all versions of macOS. The [Liferay Nativity](https://github.com/liferay/liferay-nativity) library could potentially be used to enable *git-annex-turtle* to run on older Mac OSs. I am also using CoreData which is only available on the mac for OS 10.12 and later.

*git-annex-turtle* is released for the the Mac only; it is written in Swift with XCode so is probably not easily portable to Linux and Windows. You may, of course, adapt and use this app's user experience, design, workflow and icon sets when porting to other OSs. See git-annex [related software](http://git-annex.branchable.com/related_software/) for options already built for other OSs.

### Issues
The Apple Finder Sync Extension only allows one app to register per folder, so other apps might be conflicting with *git-annex-turtle*. For example, Dropbox, registers his Finder Sync extension on your entire home folder (Users/yourname), regardless of where your actual Dropbox folder is located. Dropbox does this, apparently, so they can have “move to Dropbox” context menus on every single file. Launch `System Preferences > Extensions > Finder` to see what apps have Finder Sync extensions registered.

### Important Directories
`~/Library/Group Containers/group.com.andrewringler.git-annex-mac.sharedgroup`
App Group location for UserDefaults and sqlite database.

 `~/.config/git-annex/turtle-watch`
List of UNIX-style folder paths for git-annex-turtle to watch. Update manually or with the GUI. One folder per line.
 

## Name
*git-annex-turtle* takes inspiration in function and name from [TortoiseCVS](https://en.wikipedia.org/wiki/TortoiseCVS) and many other tools which have provided OS-level icons for source revisions control over the years.

## Build a Release
 * Open git-annex-turtle.xcodeproj in XCode 9.2
 * Click on the git-annex-turtle scheme (to the right of the triangle play button top of screen), click Edit Scheme, Make sure Run > Build Configuration is set to Release
 * Select the Scheme 'git-annex-turtle' then build: Product > Build 
 * You will find the .app in Open the ~/Library/Developer/Xcode/DerivedData/ directory and Look for git-annex-turtle-…/Build/Products/Release/git-annex-turtle.app
