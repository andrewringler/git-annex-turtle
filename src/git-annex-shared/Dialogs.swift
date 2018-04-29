//
//  Dialogs.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/14/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

protocol Dialogs {
    func dialogGitAnnexWarn(title: String, message: String)
    func dialogOSWarn(title: String, message: String)
    func about()
}
