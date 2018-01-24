//
//  BadgeIcons.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 1/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync

class BadgeIcons {
    // still calculating number of copies and presentness
    private let unknownStateInGitAnnex = NSImage(named:NSImage.Name(rawValue: "Clear12x12"))!
    
    // not tracked by git-annex
    private let notTracked = NSImage(named:NSImage.Name(rawValue: "QuestionGray12x12"))!
    
    // there are no known copies of this file
    private let zeroCopies = NSImage(named:NSImage.Name(rawValue: "Red12x12_0"))!
    
    // directory with some absent and some present files, we haven't counted known copies yet
    private let partialPresentUnknownCopies = NSImage(named:NSImage.Name(rawValue: "HalfGray12x12"))!
    
    // directory with all present files, we haven't counted known copies yet
    private let presentUnknownCopies = NSImage(named:NSImage.Name(rawValue: "SolidGray12x12"))!
    
    // directory with all absent files, we haven't counted known copies yet
    private let absentUnknownCopies = NSImage(named:NSImage.Name(rawValue: "OutlineGray12x12"))!
    
    // file or directory that is present, has n-copies
    // and this amount is greater than or equal to user's numcopies setting
    private let present1CopyEnough = NSImage(named:NSImage.Name(rawValue: "SolidGreen12x12_1"))!
    private let present2CopyEnough = NSImage(named:NSImage.Name(rawValue: "SolidGreen12x12_2"))!
    private let present3CopyEnough = NSImage(named:NSImage.Name(rawValue: "SolidGreen12x12_3"))!
    private let present4CopyEnough = NSImage(named:NSImage.Name(rawValue: "SolidGreen12x12_4"))!
    private let presentMoreThan4CopyEnough = NSImage(named:NSImage.Name(rawValue: "SolidGreen12x12_Star"))!
    
    // file or directory that is present, has n-copiesm
    // but this amount is less than the user's numcopies setting
    private let present1CopyLacking = NSImage(named:NSImage.Name(rawValue: "SolidRed12x12_1"))!
    private let present2CopyLacking = NSImage(named:NSImage.Name(rawValue: "SolidRed12x12_2"))!
    private let present3CopyLacking = NSImage(named:NSImage.Name(rawValue: "SolidRed12x12_3"))!
    private let present4CopyLacking = NSImage(named:NSImage.Name(rawValue: "SolidRed12x12_4"))!
    private let presentMoreThan4CopyLacking = NSImage(named:NSImage.Name(rawValue: "SolidRed12x12_Star"))!
    
    // directory with present and absent files, the least copy count of the file with
    // the least amount of copies is greater than or equal to the user's numcopies setting
    private let partial1CopyEnough = NSImage(named:NSImage.Name(rawValue: "HalfGreen12x12_1"))!
    private let partial2CopyEnough = NSImage(named:NSImage.Name(rawValue: "HalfGreen12x12_2"))!
    private let partial3CopyEnough = NSImage(named:NSImage.Name(rawValue: "HalfGreen12x12_3"))!
    private let partial4CopyEnough = NSImage(named:NSImage.Name(rawValue: "HalfGreen12x12_4"))!
    private let partialMoreThan4CopyEnough = NSImage(named:NSImage.Name(rawValue: "HalfGreen12x12_Star"))!
    
    // directory with present and absent files, the least copy count of the file with
    // the least amount of copies is less than the user's numcopies setting
    private let partial1CopyLacking = NSImage(named:NSImage.Name(rawValue: "HalfRed12x12_1"))!
    private let partial2CopyLacking = NSImage(named:NSImage.Name(rawValue: "HalfRed12x12_2"))!
    private let partial3CopyLacking = NSImage(named:NSImage.Name(rawValue: "HalfRed12x12_3"))!
    private let partial4CopyLacking = NSImage(named:NSImage.Name(rawValue: "HalfRed12x12_4"))!
    private let partialMoreThan4CopyLacking = NSImage(named:NSImage.Name(rawValue: "HalfRed12x12_Star"))!
    
    // directory with only absent files, the least copy count of the file with
    // the least amount of copies is greater than or equal to the user's numcopies setting
    private let absent1CopyEnough = NSImage(named:NSImage.Name(rawValue: "OutlineGreen12x12_1"))!
    private let absent2CopyEnough = NSImage(named:NSImage.Name(rawValue: "OutlineGreen12x12_2"))!
    private let absent3CopyEnough = NSImage(named:NSImage.Name(rawValue: "OutlineGreen12x12_3"))!
    private let absent4CopyEnough = NSImage(named:NSImage.Name(rawValue: "OutlineGreen12x12_4"))!
    private let absentMoreThan4CopyEnough = NSImage(named:NSImage.Name(rawValue: "OutlineGreen12x12_Star"))!
    
    // directory with only absent files, the least copy count of the file with
    // the least amount of copies is less than the user's numcopies setting
    private let absent1CopyLacking = NSImage(named:NSImage.Name(rawValue: "OutlineRed12x12_1"))!
    private let absent2CopyLacking = NSImage(named:NSImage.Name(rawValue: "OutlineRed12x12_2"))!
    private let absent3CopyLacking = NSImage(named:NSImage.Name(rawValue: "OutlineRed12x12_3"))!
    private let absent4CopyLacking = NSImage(named:NSImage.Name(rawValue: "OutlineRed12x12_4"))!
    private let absentMoreThan4CopyLacking = NSImage(named:NSImage.Name(rawValue: "OutlineRed12x12_Star"))!
    
    init(finderSyncController: FIFinderSyncController) {
        // register our icons with FinderSync controller
        finderSyncController.setBadgeImage(unknownStateInGitAnnex, label: "Unknown" , forBadgeIdentifier: unknownStateInGitAnnex.name()!.rawValue)
        finderSyncController.setBadgeImage(notTracked, label: "Not Tracked" , forBadgeIdentifier: notTracked.name()!.rawValue)
        finderSyncController.setBadgeImage(zeroCopies, label: "Zero Copies" , forBadgeIdentifier: zeroCopies.name()!.rawValue)
        finderSyncController.setBadgeImage(partialPresentUnknownCopies, label: "Partially Present Unknown Copies" , forBadgeIdentifier: partialPresentUnknownCopies.name()!.rawValue)
        finderSyncController.setBadgeImage(presentUnknownCopies, label: "Present Unknown Copies" , forBadgeIdentifier: presentUnknownCopies.name()!.rawValue)
        finderSyncController.setBadgeImage(absentUnknownCopies, label: "Absent Unknown Copies" , forBadgeIdentifier: absentUnknownCopies.name()!.rawValue)
        finderSyncController.setBadgeImage(present1CopyEnough, label: "Present 1 Copy Enough" , forBadgeIdentifier: present1CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(present2CopyEnough, label: "Present 2 Copies Enough" , forBadgeIdentifier: present2CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(present3CopyEnough, label: "Present 3 Copies Enough" , forBadgeIdentifier: present3CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(present4CopyEnough, label: "Present 4 Copies Enough" , forBadgeIdentifier: present4CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(presentMoreThan4CopyEnough, label: "Present More than 4 Copies Enough" , forBadgeIdentifier: presentMoreThan4CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(present1CopyLacking, label: "Present 1 Copy and Lacking" , forBadgeIdentifier: present1CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(present2CopyLacking, label: "Present 2 Copies and Lacking" , forBadgeIdentifier: present2CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(present3CopyLacking, label: "Present 3 Copies and Lacking" , forBadgeIdentifier: present3CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(present4CopyLacking, label: "Present 4 Copies and Lacking" , forBadgeIdentifier: present4CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(presentMoreThan4CopyLacking, label: "Present More Than 4 Copies and Lacking" , forBadgeIdentifier: presentMoreThan4CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(partial1CopyEnough, label: "Partially Present 1 Copy Enough" , forBadgeIdentifier: partial1CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(partial2CopyEnough, label: "Partially Present 2 Copies Enough" , forBadgeIdentifier: partial2CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(partial3CopyEnough, label: "Partially Present 3 Copies Enough" , forBadgeIdentifier: partial3CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(partial4CopyEnough, label: "Partially Present 4 Copies Enough" , forBadgeIdentifier: partial4CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(partialMoreThan4CopyEnough, label: "Partially More Than 4 Copies Enough" , forBadgeIdentifier: partialMoreThan4CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(partial1CopyLacking, label: "Partially Present 1 Copy and Lacking" , forBadgeIdentifier: partial1CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(partial2CopyLacking, label: "Partially Present 2 Copies and Lacking" , forBadgeIdentifier: partial2CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(partial3CopyLacking, label: "Partially Present 3 Copies and Lacking" , forBadgeIdentifier: partial3CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(partial4CopyLacking, label: "Partially Present 4 Copies and Lacking" , forBadgeIdentifier: partial4CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(partialMoreThan4CopyLacking, label: "Partially Present More Than 4 Copies and Lacking" , forBadgeIdentifier: partialMoreThan4CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(absent1CopyEnough, label: "Absent 1 Copy Enough" , forBadgeIdentifier: absent1CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(absent2CopyEnough, label: "Absent 2 Copies Enough" , forBadgeIdentifier: absent2CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(absent3CopyEnough, label: "Absent 3 Copies Enough" , forBadgeIdentifier: absent3CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(absent4CopyEnough, label: "Absent 4 Copies Enough" , forBadgeIdentifier: absent4CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(absentMoreThan4CopyEnough, label: "Absent More Than 4 Copies Enough" , forBadgeIdentifier: absentMoreThan4CopyEnough.name()!.rawValue)
        finderSyncController.setBadgeImage(absent1CopyLacking, label: "Absent 1 Copy and Lacking" , forBadgeIdentifier: absent1CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(absent2CopyLacking, label: "Absent 2 Copies and Lacking" , forBadgeIdentifier: absent2CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(absent3CopyLacking, label: "Absent 3 Copies and Lacking" , forBadgeIdentifier: absent3CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(absent4CopyLacking, label: "Absent 4 Copies and Lacking" , forBadgeIdentifier: absent4CopyLacking.name()!.rawValue)
        finderSyncController.setBadgeImage(absentMoreThan4CopyLacking, label: "Absent More Than 4 Copies and Lacking" , forBadgeIdentifier: absentMoreThan4CopyLacking.name()!.rawValue)
    }
    
    public func badgeIconForNotTracked() -> String {
        return notTracked.name()!.rawValue
    }
    
    public func badgeIconFor(status: PathStatus) -> String {
        return badgeIconFor(optionalPresent: status.presentStatus, optionalNumberOfCopies: status.numberOfCopies, optionalEnoughCopies: status.enoughCopies)
    }
    
    public func badgeIconFor(optionalPresent: Present?, optionalNumberOfCopies: UInt8?, optionalEnoughCopies: EnoughCopies?) -> String {
        // still calculating…
        if optionalPresent == nil, optionalNumberOfCopies == nil {
            return unknownStateInGitAnnex.name()!.rawValue
        }
        
        // no copies
        if let copies = optionalNumberOfCopies, copies == 0 {
            return zeroCopies.name()!.rawValue
        }
        
        // unknown copies
        if optionalNumberOfCopies == nil, let present = optionalPresent {
            switch present {
            case .present:
                return presentUnknownCopies.name()!.rawValue
            case .absent:
                return absentUnknownCopies.name()!.rawValue
            case .partialPresent:
                return partialPresentUnknownCopies.name()!.rawValue
            }
        }
        
        // known copies and present status
        if let copies = optionalNumberOfCopies, let present = optionalPresent, let enoughCopies = optionalEnoughCopies  {
            switch present {
            case .present:
                switch enoughCopies {
                case .enough:
                    if copies == 1 { return present1CopyEnough.name()!.rawValue }
                    if copies == 2 { return present2CopyEnough.name()!.rawValue }
                    if copies == 3 { return present3CopyEnough.name()!.rawValue }
                    if copies == 4 { return present4CopyEnough.name()!.rawValue }
                    if copies > 4 { return presentMoreThan4CopyEnough.name()!.rawValue }
                case .lacking:
                    if copies == 1 { return present1CopyLacking.name()!.rawValue }
                    if copies == 2 { return present2CopyLacking.name()!.rawValue }
                    if copies == 3 { return present3CopyLacking.name()!.rawValue }
                    if copies == 4 { return present4CopyLacking.name()!.rawValue }
                    if copies > 4 { return presentMoreThan4CopyLacking.name()!.rawValue }
                }
            case .absent:
                switch enoughCopies {
                case .enough:
                    if copies == 1 { return absent1CopyEnough.name()!.rawValue }
                    if copies == 2 { return absent2CopyEnough.name()!.rawValue }
                    if copies == 3 { return absent3CopyEnough.name()!.rawValue }
                    if copies == 4 { return absent4CopyEnough.name()!.rawValue }
                    if copies > 4 { return absentMoreThan4CopyEnough.name()!.rawValue }
                case .lacking:
                    if copies == 1 { return absent1CopyLacking.name()!.rawValue }
                    if copies == 2 { return absent2CopyLacking.name()!.rawValue }
                    if copies == 3 { return absent3CopyLacking.name()!.rawValue }
                    if copies == 4 { return absent4CopyLacking.name()!.rawValue }
                    if copies > 4 { return absentMoreThan4CopyLacking.name()!.rawValue }
                }
            case .partialPresent:
                switch enoughCopies {
                case .enough:
                    if copies == 1 { return partial1CopyEnough.name()!.rawValue }
                    if copies == 2 { return partial2CopyEnough.name()!.rawValue }
                    if copies == 3 { return partial3CopyEnough.name()!.rawValue }
                    if copies == 4 { return partial4CopyEnough.name()!.rawValue }
                    if copies > 4 { return partialMoreThan4CopyEnough.name()!.rawValue }
                case .lacking:
                    if copies == 1 { return partial1CopyLacking.name()!.rawValue }
                    if copies == 2 { return partial2CopyLacking.name()!.rawValue }
                    if copies == 3 { return partial3CopyLacking.name()!.rawValue }
                    if copies == 4 { return partial4CopyLacking.name()!.rawValue }
                    if copies > 4 { return partialMoreThan4CopyLacking.name()!.rawValue }
                }
            }
        }
        
        NSLog("could not find badge icon for \(optionalPresent) \(optionalNumberOfCopies) \(optionalEnoughCopies), returning unknown state icon")
        return unknownStateInGitAnnex.name()!.rawValue
    }
}
