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

    @IBOutlet weak var observedFoldersView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        observedFoldersView.delegate = self
        observedFoldersView.dataSource = self
        reloadFileList()
    }
    
    public func reloadFileList() {
        DispatchQueue.main.async {
            self.observedFoldersList = self.appDelegate.watchedFolders.getWatchedFolders().sorted()
            self.observedFoldersView.reloadData()
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
