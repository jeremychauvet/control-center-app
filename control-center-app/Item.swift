//
//  Item.swift
//  control-center-app
//
//  Created by Captaincy on 18/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
