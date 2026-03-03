//
//  Models.swift
//  GuessTheFunko
//
//  Created by Alex Chase on 3/2/23.
//

import Foundation
import UIKit

struct FunkoCard: Identifiable {
    let id = UUID().uuidString
    let uiImage: UIImage
    let tag: Int
    var showBack: Bool = true
    
    init(uiImage: UIImage, tag: Int) {
        self.uiImage = uiImage
        self.tag = tag
    }
    
    init(tag: Int) {
        self.init(uiImage: .init(named: "\(tag)")!, tag: tag)
    }
    
    ///  Provides an array of all the cards available.
    ///  NOTE: default ordering places matches as horizontal neighbors (handled on vm with .shuffle)
    static let allCards: [FunkoCard] = {
        // valid cards have tags from 1 to 8 inclusive
        (1...8).reduce(into: [FunkoCard](), {
            // Add a card
            $0.append(FunkoCard(tag: $1))
            // Add a match for the card
            $0.append(FunkoCard(tag: $1))
        })
    }()
}

