// © 2025  Cristian Felipe Patiño Rojas. Created on 18/7/25.

import Foundation

public class Game {
    public var cards: [FunkoCard]
    public var lastToggledCardIndex: Int?
    
    public init(cards: [FunkoCard]) {
        self.cards = cards
    }
    
    private var countOfFaceUpCards: Int {
        return cards.filter { !$0.showBack }.count
    }
    
    public var score: Int {
        countOfFaceUpCards / 2
    }
    
    public var isGameOver: Bool {
        score == cards.count / 2
    }
    
    public var userStartedNewPairMatch: Bool {
        let facedUpCards = cards.filter { !$0.showBack }
        let countOfFaceUpCardsIsEven = facedUpCards.count % 2 == 0
        return !countOfFaceUpCardsIsEven
    }
   
    public func toggleCardAndResetIfNeeded(index: Int) {
       
        let previousCardIndex = lastToggledCardIndex
        // 1. Toggle the card
        toggleCard(index: index)
        // 2. If first move -> do nothing:
        if userStartedNewPairMatch { return }
        // 2. If second move we verify if it matches previous card
        // If same tag -> do nothing
        if cards[index].tag == cards[previousCardIndex!].tag { return }
        // Else -> reset cards (show back)
        cards[index].showBack = true
        cards[previousCardIndex!].showBack = true
    }
    
    private func toggleCard(index cardIndex: Int) {
        cards[cardIndex].showBack.toggle()
        lastToggledCardIndex = cardIndex
    }
}
