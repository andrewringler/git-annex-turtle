//
//  ViewController.swift
//  git-annex-preferences
//
//  Created by Andrew Ringler on 1/10/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    var appDelegate :AppDelegate? = nil
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-logo"))

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
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
    static func freshController() -> ViewController {
        //1.
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        //2.
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "View Controller")
        //3.
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? ViewController else {
            fatalError("Why cant i find ViewController? - Check Main.storyboard")
        }
        return viewcontroller
    }
    
    
}
