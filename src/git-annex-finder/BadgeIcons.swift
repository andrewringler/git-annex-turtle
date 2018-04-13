//
//  BadgeIcons.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 1/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync

struct BadgeIconSpec {
    let name: String
    let imagePath: String
    let label: String
    
    init(_ name: String, _ imagePath: String, _ label: String) {
        self.name = name
        self.imagePath = imagePath
        self.label = label
    }
}
class BadgeIconSpecs {
    // still calculating number of copies and presentness
    static let unknownStateInGitAnnex = BadgeIconSpec("unknownStateInGitAnnex", "", "Unknown")
    
    // not tracked by git-annex
    static let notTracked = BadgeIconSpec("notTracked", "QuestionGray12x12", "Not Tracked")

    // there are no known copies of this file
    static let zeroCopies = BadgeIconSpec("zeroCopies", "Red12x12_0", "Zero Copies")
    
    // directory with some absent and some present files, we haven't counted known copies yet
    static let partialPresentUnknownCopies = BadgeIconSpec("partialPresentUnknownCopies", "HalfGray12x12", "Partially Present Unknown Copies")
    
    // directory with all present files, we haven't counted known copies yet
    static let presentUnknownCopies = BadgeIconSpec("presentUnknownCopies", "SolidGray12x12", "Present Unknown Copies")
    
    // directory with all absent files, we haven't counted known copies yet
    static let absentUnknownCopies = BadgeIconSpec("absentUnknownCopies", "OutlineGray12x12", "Absent Unknown Copies")
    
    // directory that is empty, or contains only empty directories, or contains only
    // git files (not annexed files)
    static let emptyOrNotAnnexFolder = BadgeIconSpec("emptyOrNotAnnexFolder", "SolidGreen12x12", "Empty or Not Annexed")
    
    // file or directory that is present, has n-copies
    // and this amount is greater than or equal to user's numcopies setting
    static let present1CopyEnough = BadgeIconSpec("present1CopyEnough", "SolidGreen12x12_1", "Present 1 Copy Enough")
    static let present2CopyEnough = BadgeIconSpec("present2CopyEnough", "SolidGreen12x12_2", "Present 2 Copies Enough")
    static let present3CopyEnough = BadgeIconSpec("present3CopyEnough", "SolidGreen12x12_3", "Present 3 Copies Enough")
    static let present4CopyEnough = BadgeIconSpec("present4CopyEnough", "SolidGreen12x12_4", "Present 4 Copies Enough")
    static let presentMoreThan4CopyEnough = BadgeIconSpec("presentMoreThan4CopyEnough", "SolidGreen12x12_Star", "Present More than 4 Copies Enough")
    
    // file or directory that is present, has n-copiesm
    // but this amount is less than the user's numcopies setting
    static let present1CopyLacking = BadgeIconSpec("present1CopyLacking", "SolidRed12x12_1", "Present 1 Copy and Lacking")
    static let present2CopyLacking = BadgeIconSpec("present2CopyLacking", "SolidRed12x12_2", "Present 2 Copies and Lacking")
    static let present3CopyLacking = BadgeIconSpec("present3CopyLacking", "SolidRed12x12_3", "Present 3 Copies and Lacking")
    static let present4CopyLacking = BadgeIconSpec("present4CopyLacking", "SolidRed12x12_4", "Present 4 Copies and Lacking")
    static let presentMoreThan4CopyLacking = BadgeIconSpec("presentMoreThan4CopyLacking", "SolidRed12x12_Star", "Present More Than 4 Copies and Lacking")
    
    // directory with present and absent files, the least copy count of the file with
    // the least amount of copies is greater than or equal to the user's numcopies setting
    static let partial1CopyEnough = BadgeIconSpec("partial1CopyEnough", "HalfGreen12x12_1", "Partially Present 1 Copy Enough")
    static let partial2CopyEnough = BadgeIconSpec("partial2CopyEnough", "HalfGreen12x12_2", "Partially Present 2 Copies Enough")
    static let partial3CopyEnough = BadgeIconSpec("partial3CopyEnough", "HalfGreen12x12_3", "Partially Present 3 Copies Enough")
    static let partial4CopyEnough = BadgeIconSpec("partial4CopyEnough", "HalfGreen12x12_4", "Partially Present 4 Copies Enough")
    static let partialMoreThan4CopyEnough = BadgeIconSpec("partialMoreThan4CopyEnough", "HalfGreen12x12_Star", "Partially More Than 4 Copies Enough")
    
    // directory with present and absent files, the least copy count of the file with
    // the least amount of copies is less than the user's numcopies setting
    static let partial1CopyLacking = BadgeIconSpec("partial1CopyLacking", "HalfRed12x12_1", "Partially Present 1 Copy and Lacking")
    static let partial2CopyLacking = BadgeIconSpec("partial2CopyLacking", "HalfRed12x12_2", "Partially Present 2 Copies and Lacking")
    static let partial3CopyLacking = BadgeIconSpec("partial3CopyLacking", "HalfRed12x12_3", "Partially Present 3 Copies and Lacking")
    static let partial4CopyLacking = BadgeIconSpec("partial4CopyLacking", "HalfRed12x12_4", "Partially Present 4 Copies and Lacking")
    static let partialMoreThan4CopyLacking = BadgeIconSpec("partialMoreThan4CopyLacking", "HalfRed12x12_Star", "Partially Present More Than 4 Copies and Lacking")
    
    // directory with only absent files, the least copy count of the file with
    // the least amount of copies is greater than or equal to the user's numcopies setting
    static let absent1CopyEnough = BadgeIconSpec("absent1CopyEnough", "OutlineGreen12x12_1", "Absent 1 Copy Enough")
    static let absent2CopyEnough = BadgeIconSpec("absent2CopyEnough", "OutlineGreen12x12_2", "Absent 2 Copies Enough")
    static let absent3CopyEnough = BadgeIconSpec("absent3CopyEnough", "OutlineGreen12x12_3", "Absent 3 Copies Enough")
    static let absent4CopyEnough = BadgeIconSpec("absent4CopyEnough", "OutlineGreen12x12_4", "Absent 4 Copies Enough")
    static let absentMoreThan4CopyEnough = BadgeIconSpec("absentMoreThan4CopyEnough", "OutlineGreen12x12_Star", "Absent More Than 4 Copies Enough")
    
    // directory with only absent files, the least copy count of the file with
    // the least amount of copies is less than the user's numcopies setting
    static let absent1CopyLacking = BadgeIconSpec("absent1CopyLacking", "OutlineRed12x12_1", "Absent 1 Copy and Lacking")
    static let absent2CopyLacking = BadgeIconSpec("absent2CopyLacking", "OutlineRed12x12_2", "Absent 2 Copies and Lacking")
    static let absent3CopyLacking = BadgeIconSpec("absent3CopyLacking", "OutlineRed12x12_3", "Absent 3 Copies and Lacking")
    static let absent4CopyLacking = BadgeIconSpec("absent4CopyLacking", "OutlineRed12x12_4", "Absent 4 Copies and Lacking")
    static let absentMoreThan4CopyLacking = BadgeIconSpec("absentMoreThan4CopyLacking", "OutlineRed12x12_Star", "Absent More Than 4 Copies and Lacking")
    
    static let icons: [BadgeIconSpec] = [
        unknownStateInGitAnnex,
        zeroCopies,
        partialPresentUnknownCopies,
        presentUnknownCopies,
        absentUnknownCopies,
        emptyOrNotAnnexFolder,
        present1CopyEnough,
        present2CopyEnough,
        present3CopyEnough,
        present4CopyEnough,
        presentMoreThan4CopyEnough,
        present1CopyLacking,
        present2CopyLacking,
        present3CopyLacking,
        present4CopyLacking,
        presentMoreThan4CopyLacking,
        partial1CopyEnough,
        partial2CopyEnough,
        partial3CopyEnough,
        partial4CopyEnough,
        partialMoreThan4CopyEnough,
        partial1CopyLacking,
        partial2CopyLacking,
        partial3CopyLacking,
        partial4CopyLacking,
        partialMoreThan4CopyLacking,
        absent1CopyEnough,
        absent2CopyEnough,
        absent3CopyEnough,
        absent4CopyEnough,
        absentMoreThan4CopyEnough,
        absent1CopyLacking,
        absent2CopyLacking,
        absent3CopyLacking,
        absent4CopyLacking,
        absentMoreThan4CopyLacking
    ]
}

class BadgeIcons {
    init(finderSyncController: FIFinderSyncController) {
        // load icons and register with FinderSync controller
        for icon in BadgeIconSpecs.icons {
            if let image = loadNSImage(for: icon) {
                finderSyncController.setBadgeImage(image, label: icon.label , forBadgeIdentifier: icon.name)
            }
        }
    }
    
    public func badgeIconFor(status: PathStatus) -> String {
        // not tracked by git-annex
        if status.isGitAnnexTracked == false {
            return BadgeIconSpecs.notTracked.name
        }
        
        // still calculating…
        if status.presentStatus == nil, status.numberOfCopies == nil {
            return BadgeIconSpecs.unknownStateInGitAnnex.name
        }
        
        // empty directory, or filled with not annex files
        if status.isEmptyFolder() {
            return BadgeIconSpecs.emptyOrNotAnnexFolder.name
        }
        
        // no copies
        if let copies = status.numberOfCopies, copies == 0 {
            return BadgeIconSpecs.zeroCopies.name
        }
        
        // unknown copies
        if status.numberOfCopies == nil, let present = status.presentStatus {
            switch present {
            case .present:
                return BadgeIconSpecs.presentUnknownCopies.name
            case .absent:
                return BadgeIconSpecs.absentUnknownCopies.name
            case .partialPresent:
                return BadgeIconSpecs.partialPresentUnknownCopies.name
            }
        }
        
        // known copies and present status
        if let copies = status.numberOfCopies, let present = status.presentStatus, let enoughCopies = status.enoughCopies  {
            switch present {
            case .present:
                switch enoughCopies {
                case .enough:
                    if copies == 1 { return BadgeIconSpecs.present1CopyEnough.name }
                    if copies == 2 { return BadgeIconSpecs.present2CopyEnough.name }
                    if copies == 3 { return BadgeIconSpecs.present3CopyEnough.name }
                    if copies == 4 { return BadgeIconSpecs.present4CopyEnough.name }
                    if copies > 4 { return BadgeIconSpecs.presentMoreThan4CopyEnough.name }
                case .lacking:
                    if copies == 1 { return BadgeIconSpecs.present1CopyLacking.name }
                    if copies == 2 { return BadgeIconSpecs.present2CopyLacking.name }
                    if copies == 3 { return BadgeIconSpecs.present3CopyLacking.name }
                    if copies == 4 { return BadgeIconSpecs.present4CopyLacking.name }
                    if copies > 4 { return BadgeIconSpecs.presentMoreThan4CopyLacking.name }
                }
            case .absent:
                switch enoughCopies {
                case .enough:
                    if copies == 1 { return BadgeIconSpecs.absent1CopyEnough.name }
                    if copies == 2 { return BadgeIconSpecs.absent2CopyEnough.name }
                    if copies == 3 { return BadgeIconSpecs.absent3CopyEnough.name }
                    if copies == 4 { return BadgeIconSpecs.absent4CopyEnough.name }
                    if copies > 4 { return BadgeIconSpecs.absentMoreThan4CopyEnough.name }
                case .lacking:
                    if copies == 1 { return BadgeIconSpecs.absent1CopyLacking.name }
                    if copies == 2 { return BadgeIconSpecs.absent2CopyLacking.name }
                    if copies == 3 { return BadgeIconSpecs.absent3CopyLacking.name }
                    if copies == 4 { return BadgeIconSpecs.absent4CopyLacking.name }
                    if copies > 4 { return BadgeIconSpecs.absentMoreThan4CopyLacking.name }
                }
            case .partialPresent:
                switch enoughCopies {
                case .enough:
                    if copies == 1 { return BadgeIconSpecs.partial1CopyEnough.name }
                    if copies == 2 { return BadgeIconSpecs.partial2CopyEnough.name }
                    if copies == 3 { return BadgeIconSpecs.partial3CopyEnough.name }
                    if copies == 4 { return BadgeIconSpecs.partial4CopyEnough.name }
                    if copies > 4 { return BadgeIconSpecs.partialMoreThan4CopyEnough.name }
                case .lacking:
                    if copies == 1 { return BadgeIconSpecs.partial1CopyLacking.name }
                    if copies == 2 { return BadgeIconSpecs.partial2CopyLacking.name }
                    if copies == 3 { return BadgeIconSpecs.partial3CopyLacking.name }
                    if copies == 4 { return BadgeIconSpecs.partial4CopyLacking.name }
                    if copies > 4 { return BadgeIconSpecs.partialMoreThan4CopyLacking.name }
                }
            }
        }
        
        TurtleLog.debug("could not find badge icon for \(status), returning unknown state icon")
        return BadgeIconSpecs.unknownStateInGitAnnex.name
    }
    
    private func loadNSImage(for icon: BadgeIconSpec) -> NSImage? {
        if icon.imagePath.isEmpty {
            return nil // empty path means no image for Badge Identifier
        }
        if let image = NSImage(named:NSImage.Name(rawValue: icon.imagePath)) {
            return  image
        }
        TurtleLog.error("could not retrieve image for \(icon.imagePath)")
        fatalError("could not retrieve image for \(icon.imagePath)")
    }
}
