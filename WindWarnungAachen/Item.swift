//
//  Item.swift
//  WindWarnungAachen
//
//  Created by Alexander Peters on 04.07.26.
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
