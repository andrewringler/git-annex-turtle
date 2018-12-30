//
//  GeneralViewController.swift
//  git-annex-preferences
//
//  Created by Andrew Ringler on 6/1/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa

class GeneralViewController: NSViewController {
    @IBOutlet weak var gitBinaryPath: NSTextField!
    @IBOutlet weak var gitAnnexBinaryPath: NSTextField!

    var appDelegate :WatchGitAndFinderForUpdates!

    override func viewDidLoad() {
        super.viewDidLoad()
//        self.appDelegate = (self.presenting as! ViewController).appDelegate
        
        gitBinaryPath.stringValue = appDelegate!.preferences.gitBin() ?? ""
        gitAnnexBinaryPath.stringValue = appDelegate!.preferences.gitAnnexBin() ?? ""
    }
    
    public func updateGitAnnexBin(gitAnnexBin: String) {
        DispatchQueue.main.async {
            self.gitAnnexBinaryPath.stringValue = gitAnnexBin
        }
    }
    
    public func updateGitBin(gitBin: String) {
        DispatchQueue.main.async {
            self.gitBinaryPath.stringValue = gitBin
        }
    }
    
    @IBAction func gitBinaryTextFieldUpdate(_ sender: NSTextField) {
        let newPath = gitBinaryPath.stringValue
        TurtleLog.debug("git binary application field changed to \(newPath)")
        if !appDelegate!.config.setGitBin(gitBin: newPath) {
            appDelegate!.dialogs.dialogOSWarn(title: "git path", message: "'\(newPath)' is not a valid path to a git application.")
            if let oldGitBin = appDelegate!.preferences.gitBin() {
                gitBinaryPath.stringValue = oldGitBin
            }
        }
    }
    
    @IBAction func gitAnnexBinaryTextFieldUpdate(_ sender: NSTextField) {
        let newPath = gitAnnexBinaryPath.stringValue
        TurtleLog.debug("git-annex application text field changed to \(newPath)")
        if !appDelegate!.config.setGitAnnexBin(gitAnnexBin: newPath) {
            appDelegate!.dialogs.dialogOSWarn(title: "git-annex path", message: "'\(newPath)' is not a valid path to a git-annex application.")
            if let oldGitAnnexBin = appDelegate!.preferences.gitAnnexBin() {
                gitAnnexBinaryPath.stringValue = oldGitAnnexBin
            }
        }
    }
    
    @IBAction func chooseGitPath(_ sender: NSButton) {
        let folderChooseDialog = NSOpenPanel();
        
        folderChooseDialog.title                   = "Select git application"
        folderChooseDialog.showsResizeIndicator    = true
        folderChooseDialog.showsHiddenFiles        = false
        folderChooseDialog.canChooseFiles          = true
        folderChooseDialog.canChooseDirectories    = false
        folderChooseDialog.canCreateDirectories    = false
        folderChooseDialog.allowsMultipleSelection = false
        folderChooseDialog.treatsFilePackagesAsDirectories = true
        
        // TODO validate user has selected a valid git binary
        // in the dialog itself, instead of waiting until selection
        // see https://stackoverflow.com/questions/5682666/restrict-access-to-certain-folders-using-nsopenpanel
        if (folderChooseDialog.runModal() == NSApplication.ModalResponse.OK) {
            if let chosenURL: URL = folderChooseDialog.url {
                if let path :String = PathUtils.path(for: chosenURL) {
                    if !appDelegate!.config.setGitBin(gitBin: path) {
                        appDelegate!.dialogs.dialogOSWarn(title: "git path", message: "'\(path)' is not a valid path to a git application.")
                    }
                }
            }
        }
    }
    
    @IBAction func chooseGitAnnexPath(_ sender: NSButton) {
        let folderChooseDialog = NSOpenPanel();
        
        folderChooseDialog.title                   = "Select git-annex application"
        folderChooseDialog.showsResizeIndicator    = true
        folderChooseDialog.showsHiddenFiles        = false
        folderChooseDialog.canChooseFiles          = true
        folderChooseDialog.canChooseDirectories    = false
        folderChooseDialog.canCreateDirectories    = false
        folderChooseDialog.allowsMultipleSelection = false
        folderChooseDialog.treatsFilePackagesAsDirectories = true
        
        // TODO validate user has selected a valid git binary
        // in the dialog itself, instead of waiting until selection
        // see https://stackoverflow.com/questions/5682666/restrict-access-to-certain-folders-using-nsopenpanel
        if (folderChooseDialog.runModal() == NSApplication.ModalResponse.OK) {
            if let chosenURL: URL = folderChooseDialog.url {
                if let path :String = PathUtils.path(for: chosenURL) {
                    if !appDelegate!.config.setGitAnnexBin(gitAnnexBin: path) {
                        appDelegate!.dialogs.dialogOSWarn(title: "git-annex path", message: "'\(path)' is not a valid path to a git-annex application.")
                    }
                }
            }
        }
    }
}
