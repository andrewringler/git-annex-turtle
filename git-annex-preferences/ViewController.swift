//
//  ViewController.swift
//  git-annex-preferences
//
//  Created by Andrew Ringler on 1/10/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    private var appDelegate :AppDelegate? = nil
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-logo"))
    var observedFoldersList :[WatchedFolder]?
    
    @IBOutlet weak var watchedFolderView: NSScrollView!
    @IBOutlet weak var observedFoldersView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        observedFoldersView.delegate = self
        observedFoldersView.dataSource = self
    }

    public func reloadFileList() {
        DispatchQueue.main.async {
            self.observedFoldersList = self.appDelegate?.watchedFolders.sorted()
            self.observedFoldersView?.reloadData()
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func deleteSelectedWatchFoldres(_ sender: Any) {
        for itemSelectedRowIndex in observedFoldersView.selectedRowIndexes {
            guard let item = observedFoldersList?[itemSelectedRowIndex] else {
                continue
            }
            NSLog("Stop watching '\(item.pathString)'")
            Config().stopWatchingRepo(repo: item.pathString)
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
//        folderChooseDialog.
        // TODO validate user has selected a git-annex directory
        // in the dialog itself
        // see https://stackoverflow.com/questions/5682666/restrict-access-to-certain-folders-using-nsopenpanel
        if (folderChooseDialog.runModal() == NSApplication.ModalResponse.OK) {
            if let chosenURL: URL = folderChooseDialog.url {
                if let path :String = PathUtils.path(for: chosenURL) {
                    // valid git-annex folder?
                    if let _ = GitAnnexQueries.gitGitAnnexUUID(in: path) {
                        Config().watchRepo(repo: path)
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

extension ViewController {
    // MARK: Storyboard instantiation
    static func freshController(appDelegate: AppDelegate) -> ViewController {
        //1.
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        //2.
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "View Controller")
        //3.
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? ViewController else {
            fatalError("Why cant i find ViewController? - Check Main.storyboard")
        }
        viewcontroller.appDelegate = appDelegate
        return viewcontroller
    }
}

// see https://www.raywenderlich.com/143828/macos-nstableview-tutorial
extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return observedFoldersList?.count ?? 0
    }
}

extension ViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let PathCell = "PathCellID"
        static let UUIDCell = "UUIDCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
//        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        // 1
        guard let item = observedFoldersList?[row] else {
            return nil
        }
        
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
