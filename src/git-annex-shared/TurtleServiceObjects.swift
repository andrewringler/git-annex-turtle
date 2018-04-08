//
//  TurtleServiceObjects.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 4/8/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

public struct SendPingData : Codable, CustomStringConvertible {
    public let id: String
    public let timeStamp: Double

    public var description: String { return "\(id) at \(timeStamp)" }
}

public struct PingResponseData : Codable, CustomStringConvertible {
    public let id: String
    public let timeStamp: Double
    
    public var description: String { return "\(id) at \(timeStamp)" }
}
