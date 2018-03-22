## General Design
The main application, `git-annex-turtle`, is responsible for launching/re-launching the Finder Sync Extension (`git-annex-turtle-finder`), displaying a Menubar Icon, and periodically monitoring the state of watched folders.

When `git-annex-turtle-finder` is launched it checks the database table `WatchedFolderEntity` for the list of folders to watch. It then registers these so macOS will notify when any of these folders (or their children) become visible/invisible in a Finder window.

When `git-annex-turtle-finder` receives a `requestBadgeIdentifier` it means a new file path (file or folder) is visible in a Finder window that it is observing. So, it first checks if there is an entry in `PathStatus`, if so, it uses it; If not, it adds a new database entry to `PathRequestEntity`. `git-annex-turtle-finder` periodically checks the `PathStatus` table for updates, IE as status of files change in git-annex, present / not-present / number of copies, this is reflected in `PathStatus` and `git-annex-turtle-finder` sees these updates.

The main application, `git-annex-turtle`, periodically monitors the `PathRequestEntity` table for new entries. As it handles them, it deletes the entries and adds them as new entries in the `PathStatus` table. `git-annex-turtle` monitors all entries in `PathStatus` periodically, updating them in the database as their state changes on disk.
 
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
