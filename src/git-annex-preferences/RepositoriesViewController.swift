//
//  RepositoriesViewController.swift
//  git-annex-preferences
//
//  Created by Andrew Ringler on 6/1/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa

class RepositoriesViewController: NSViewController {
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-logo"))
    var observedFoldersList :[WatchedFolder] = []
    var appDelegate :WatchGitAndFinderForUpdates!
    var previouslySelectedRepoUUID: UUID? = nil

    @IBOutlet weak var observedFoldersView: NSTableView!
    @IBOutlet weak var selectedRepoShareLocalPath: NSTextField!
    @IBOutlet weak var selectedRepoShareRemote: NSTextField!
    @IBOutlet weak var chooseSelectedRepoSharePathButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        observedFoldersView.delegate = self
        observedFoldersView.dataSource = self
        
        reloadFileList()
    }
    
    public func reloadFileList() {
        DispatchQueue.main.async {
            // Save selected repo
            if let itemSelectedRowIndex = self.observedFoldersView.selectedRowIndexes.first {
                let item = self.observedFoldersList[itemSelectedRowIndex]
                self.previouslySelectedRepoUUID = item.uuid
            }
            self.observedFoldersList = self.appDelegate.watchedFolders.getWatchedFolders().sorted()
            self.observedFoldersView.reloadData()
            
            // Restore selected repo
            var i = 0
            for repo in self.observedFoldersList {
                if self.previouslySelectedRepoUUID == repo.uuid {
                    self.observedFoldersView.selectRowIndexes([i], byExtendingSelection: false)
                }
                i = i + 1
            }
            self.reloadRepoSettingsDetail()
        }
    }
    
    private func reloadRepoSettingsDetail() {
        if let itemSelectedRowIndex = observedFoldersView.selectedRowIndexes.first {
            let item = observedFoldersList[itemSelectedRowIndex]
            selectedRepoShareRemote.stringValue = item.shareRemote.shareRemote ?? ""
            selectedRepoShareLocalPath.stringValue = item.shareRemote.shareLocalPath ?? ""
            selectedRepoShareRemote.isEnabled = true
            selectedRepoShareLocalPath.isEnabled = true
            chooseSelectedRepoSharePathButton.isEnabled = true
            
            return
        }
        
        // no selection, disable fields
        selectedRepoShareRemote.stringValue = ""
        selectedRepoShareLocalPath.stringValue = ""
        selectedRepoShareRemote.isEnabled = false
        selectedRepoShareLocalPath.isEnabled = false
        chooseSelectedRepoSharePathButton.isEnabled = false
    }
    
    private func selectedRepo() -> WatchedFolder? {
        for itemSelectedRowIndex in observedFoldersView.selectedRowIndexes {
            return observedFoldersList[itemSelectedRowIndex]
        }
        return nil
    }
    
    
    @IBAction func shareLocalPathUpdate(_ sender: NSTextField) {
        if let repo = self.selectedRepo() {
            let repoShareLocalPath = selectedRepoShareLocalPath.stringValue
            TurtleLog.debug("share local path field changed to \(repoShareLocalPath)")
            
            if appDelegate!.config.updateShareRemoteLocalPath(repo: repo.pathString, shareLocalPath: repoShareLocalPath) {
                return // success
            }
            appDelegate!.dialogs.dialogOSWarn(title: "share remote", message: "'\(repoShareLocalPath)' is not a valid subdirectory within the '\(repo.pathString)' repository")
        }
    }
    
    @IBAction func publicShareHelpTooltipButton(_ sender: NSButton) {
        appDelegate!.dialogs.dialogOSWarn(title: "Share", message: "Share will allow you to quickly share annexed files to a public location. First, you must manually setup a public exporttree special remote (see https://git-annex.branchable.com/tips/publishing_your_files_to_the_public/). Once you have setup an exporttree remote for this respository, enter the name of that remote next to 'remote name' and choose a 'local folder' within the repository that will be used to stage changes before exporting.\n\nOnce sharing is setup, you may right-click any file and choose 'Share'. The file will be added to git-annex, copied to your local share folder (if it isn't already there), committed and then the entire local folder will be re-exported. If you delete any files from the local share folder these will be unshared.\n\nNote that share settings are specific to each repository.")
    }
    
    @IBAction func shareRemoteUpdate(_ sender: NSTextField) {
        if let repo = self.selectedRepo() {
            let repoShareRemote = selectedRepoShareRemote.stringValue
            TurtleLog.debug("share remote field changed to \(repoShareRemote)")
            
            if appDelegate!.config.updateShareRemote(repo: repo.pathString, shareRemote: repoShareRemote) {
                return // success
            }
            appDelegate!.dialogs.dialogOSWarn(title: "share remote", message: "'\(repoShareRemote)' is not a valid exporttree remote for the '\(repo.pathString)' repository")
        }
    }

    @IBAction func chooseSelectedRepoShareLocalPath(_ sender: Any) {
        if let repo = selectedRepo() {
            let folderChooseDialog = NSOpenPanel();
            
            folderChooseDialog.title                   = "Select local share path"
            folderChooseDialog.showsResizeIndicator    = true
            folderChooseDialog.showsHiddenFiles        = false
            folderChooseDialog.canChooseDirectories    = true
            folderChooseDialog.canCreateDirectories    = false
            folderChooseDialog.allowsMultipleSelection = false
            folderChooseDialog.treatsFilePackagesAsDirectories = true
            folderChooseDialog.directoryURL = PathUtils.urlFor(absolutePath: repo.pathString)
            
            // TODO validate user has selected a valid path
            // in the dialog itself, instead of waiting until selection
            // see https://stackoverflow.com/questions/5682666/restrict-access-to-certain-folders-using-nsopenpanel
            if (folderChooseDialog.runModal() == NSApplication.ModalResponse.OK) {
                if let chosenURL: URL = folderChooseDialog.url {
                    if let path = PathUtils.relativePath(for: chosenURL, in: repo) {
                        if appDelegate!.config.updateShareRemoteLocalPath(repo: repo.pathString, shareLocalPath: path) {
                            return // success
                        }
                    }
                    let choseURLPath = PathUtils.path(for: chosenURL) ?? ""
                    appDelegate!.dialogs.dialogOSWarn(title: "share remote", message: "'\(choseURLPath)' is not a valid subdirectory within the '\(repo.pathString)' repository")
                }
            }
        }
    }
    
    @IBAction func deleteSelectedWatchFolders(_ sender: Any) {
        for itemSelectedRowIndex in observedFoldersView.selectedRowIndexes {
            let item = observedFoldersList[itemSelectedRowIndex]
            TurtleLog.debug("Stop watching '\(item.pathString)'")
            appDelegate!.config.stopWatchingRepo(repo: item.pathString)
        }
    }
    
    // https://denbeke.be/blog/programming/swift-open-file-dialog-with-nsopenpanel/
    @IBAction func addWatchFolderAction(_ sender: Any) {
        let folderChooseDialog = NSOpenPanel();
        
        folderChooseDialog.title                   = "Choose a git-annex folder"
        folderChooseDialog.showsResizeIndicator    = true
        folderChooseDialog.showsHiddenFiles        = false
        folderChooseDialog.canChooseFiles          = false
        folderChooseDialog.canChooseDirectories    = true
        folderChooseDialog.canCreateDirectories    = false
        folderChooseDialog.allowsMultipleSelection = false
        
        // TODO validate user has selected a git-annex directory
        // in the dialog itself, instead of waiting until selection
        // see https://stackoverflow.com/questions/5682666/restrict-access-to-certain-folders-using-nsopenpanel
        if (folderChooseDialog.runModal() == NSApplication.ModalResponse.OK) {
            if let chosenURL: URL = folderChooseDialog.url {
                if let path :String = PathUtils.path(for: chosenURL) {
                    // valid git-annex folder?
                    if appDelegate != nil, let _ = appDelegate!.gitAnnexQueries.gitGitAnnexUUID(in: path) {
                        appDelegate!.config.watchRepo(repo: path)
                    } else {
                        dialogInvalidGitAnnexDirectory(path: path)
                    }
                }
            }
        }
    }
    
    func dialogInvalidGitAnnexDirectory(path: String) {
        DispatchQueue.main.async {
            // https://stackoverflow.com/questions/29433487/create-an-nsalert-with-swift
            let alert = NSAlert()
            alert.messageText = "Not a git-annex folder"
            alert.informativeText = "'" + path + "' is not a git-annex folder. Please make sure you have selected a folder that 'git annex init' has been run on."
            alert.alertStyle = .warning
            alert.icon = self.gitAnnexTurtleLogo
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// see https://www.raywenderlich.com/143828/macos-nstableview-tutorial
extension RepositoriesViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return observedFoldersList.count
    }
}

extension RepositoriesViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let PathCell = "PathCellID"
        static let UUIDCell = "UUIDCellID"
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        reloadRepoSettingsDetail()
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < observedFoldersList.count else {
            fatalError("asked for row \(row), but only have \(observedFoldersList.count) rows of data")
        }
        
        //        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        // 1
        let item = observedFoldersList[row]
        
        // 2
        if tableColumn == tableView.tableColumns[0] {
            text = item.pathString
            cellIdentifier = CellIdentifiers.PathCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = item.uuid.uuidString
            cellIdentifier = CellIdentifiers.UUIDCell
        }
        
        // 3
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
}
