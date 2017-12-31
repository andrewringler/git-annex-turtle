//
//  StringExtension.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

extension String {
    func isGitAnnexRepository() -> Bool {
        // TODO
        return true
    }

//    func isAnagramOfString(_ s: String) -> Bool {
//        //1
//        let lowerSelf = self.lowercased().replacingOccurrences(of: " ", with: "")
//        let lowerOther = s.lowercased().replacingOccurrences(of: " ", with: "")
//        //2
//        return lowerSelf.characters.sorted() == lowerOther.characters.sorted()
//    }
    
//    func isPalindrome() -> Bool {
//        //1
//        let f = self.lowercased().replacingOccurrences(of: " ", with: "")
//        //2
//        let s = String(f.characters.reversed())
//        //3
//        return  f == s
//    }
}
