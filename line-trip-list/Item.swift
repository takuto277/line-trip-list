//
//  Item.swift
//  line-trip-list
//
//  Created by 小野拓人 on 2025/10/01.
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
