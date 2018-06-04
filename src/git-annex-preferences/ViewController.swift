//
//  ViewController.swift
//  git-annex-preferences
//
//  Created by Andrew Ringler on 1/10/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa

class ViewController: NSTabViewController, ViewControllerProtocol {
    var appDelegate :WatchGitAndFinderForUpdates? = nil
    var repositoriesViewController: RepositoriesViewController!
    var generalViewController: GeneralViewController!
    
    func updateGitAnnexBin(gitAnnexBin: String) {
        // update git-annex bin on generalViewController if it is visible
        DispatchQueue.main.async {
            if self.generalViewController?.view.superview != nil {
                self.generalViewController!.updateGitAnnexBin(gitAnnexBin: gitAnnexBin)
            }
        }
    }
    
    func updateGitBin(gitBin: String) {
        // update git bin on generalViewController if it is visible
        DispatchQueue.main.async {
            if self.generalViewController?.view.superview != nil {
                self.generalViewController!.updateGitBin(gitBin: gitBin)
            }
        }
    }
    
    func reloadFileList() {
        // reload file list on repositoriesViewController if it is visible
        DispatchQueue.main.async {
            if self.repositoriesViewController?.view.superview != nil {
                self.repositoriesViewController!.reloadFileList()
            }
        }
    }
}

extension ViewController {
    // MARK: Storyboard instantiation
    static func freshController(appDelegate: WatchGitAndFinderForUpdates) -> ViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "ViewController")
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? ViewController else {
            fatalError("Why cant i find ViewController? - Check Main.storyboard")
        }
        viewcontroller.appDelegate = appDelegate
        
        guard viewcontroller.childViewControllers.count == 2 else {
            fatalError("ViewController should have 2 children, but has \(viewcontroller.childViewControllers.count)")
        }
        
        viewcontroller.repositoriesViewController = viewcontroller.childViewControllers[0] as! RepositoriesViewController
        viewcontroller.repositoriesViewController.appDelegate = appDelegate
        viewcontroller.generalViewController = viewcontroller.childViewControllers[1] as! GeneralViewController
        viewcontroller.generalViewController.appDelegate = appDelegate
        
        viewcontroller.reloadFileList()
        return viewcontroller
    }
}


