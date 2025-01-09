//
//  Item.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
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
