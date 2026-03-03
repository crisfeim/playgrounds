// © 2025  Cristian Felipe Patiño Rojas. Created on 18/7/25.

import Foundation

public struct FunkoCard: Identifiable, Equatable {
    public let id = UUID().uuidString
    public let image: String
    public let tag: Int
    public var showBack: Bool = true
    
    public init(image: String, tag: Int) {
        self.image = image
        self.tag = tag
    }
    
    ///  Provides an array of all the cards available.
    ///  NOTE: default ordering places matches as horizontal neighbors (handled on vm with .shuffle)
    public static let allCards: [FunkoCard] = {
        (1...8).reduce(into: [FunkoCard](), {
            $0.append(FunkoCard(image: $1.description, tag: $1))
            $0.append(FunkoCard(image: $1.description, tag: $1))
        })
    }()
}
