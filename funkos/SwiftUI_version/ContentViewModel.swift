//
//  ContentViewModel.swift
//  GuessTheFunkoSwiftUI
//
//  Created by Nicholas Boleky on 6/26/25.
//

import Foundation
@MainActor
class ContentViewModel: ObservableObject {
    @Published var cards: [FunkoCard] = FunkoCard.allCards.shuffled() //googled randomizing array
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    
    private var firstFlippedIndex: Int?
    private var isFlippingBack = false //optimization
    
    func handleCardTap(at index: Int) {
        //check its face down (if face up we ignore), check we arent handling two cards already
        guard cards[index].showBack,
                !isFlippingBack
        else { return }
        cards[index].showBack = false //first, flips the tapped card
        
        //this if condition checks if this is the second card being flipped. If this is the second, it will compare the tag of the first flipped index with the card that was just being fipped. if they match, score increases, else the flipping back sequence begins
        if let firstIndex = firstFlippedIndex {
            if cards[firstIndex].tag == cards[index].tag {
                score += 1
                firstFlippedIndex = nil
                //leave matched cards face up
                //check game over after scoring
                //https://stackoverflow.com/questions/29588158/check-if-all-elements-of-an-array-have-the-same-value-in-swift
//                if cards.allSatisfy({ !$0.showBack }) {
//                    isGameOver = true
//                }
                if score == cards.count / 2 {
                    isGameOver = true
                }
            } else {
                isFlippingBack = true
                //https://stackoverflow.com/questions/59682446/how-to-trigger-an-action-after-x-seconds-in-swiftui
                Task {
                    try? await Task.sleep(nanoseconds: 500000000)
                    cards[firstIndex].showBack = true
                    cards[index].showBack = true
                    firstFlippedIndex = nil
                    isFlippingBack = false
                }
            }
        } else {
            firstFlippedIndex = index
        }
    }
    
    func playAgain() {
        cards = FunkoCard.allCards.shuffled()
            score = 0
            firstFlippedIndex = nil
            isFlippingBack = false
            isGameOver = false
        }
}
