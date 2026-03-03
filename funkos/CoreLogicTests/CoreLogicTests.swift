// © 2025  Cristian Felipe Patiño Rojas. Created on 18/7/25.

import XCTest
import CoreLogic

final class CoreLogicTests: XCTestCase {

    func test_game_init() throws {
        let game = Game(cards: FunkoCard.allCards)
        XCTAssertEqual(game.cards, FunkoCard.allCards)
    }
    
    func test_toggleCard_togglesCard() throws {
        let card = anyCard(tag: 0)
        let game = Game(cards: [card])
        game.toggleCardAndResetIfNeeded(index: 0)
        XCTAssertEqual(game.cards[0].showBack, false)
    }
    
    func test_isFirstPairMovement() throws {
        let card1 = anyCard(tag: 1)
        let card2 = anyCard(tag: 2)
        let card3 = anyCard(tag: 3)
        let card4 = anyCard(tag: 4)
        
        let game = Game(cards: [card1, card2, card3, card4])
        
        game.toggleCardAndResetIfNeeded(index: 0)
        XCTAssertTrue(game.userStartedNewPairMatch)
        
        game.toggleCardAndResetIfNeeded(index: 1)
        XCTAssertFalse(game.userStartedNewPairMatch)
        
        game.toggleCardAndResetIfNeeded(index: 2)
        XCTAssertTrue(game.userStartedNewPairMatch)
        
        game.toggleCardAndResetIfNeeded(index: 3)
        XCTAssertFalse(game.userStartedNewPairMatch)
    }
    
    func test_lastToggledCardIndex() {
        let game = Game(cards: [anyCard(), anyCard(), anyCard(), anyCard()])
        XCTAssertNil(game.lastToggledCardIndex)
        
        game.toggleCardAndResetIfNeeded(index: 0)
        XCTAssertEqual(game.lastToggledCardIndex, 0)
        
        game.toggleCardAndResetIfNeeded(index: 1)
        XCTAssertEqual(game.lastToggledCardIndex, 1)
        
        game.toggleCardAndResetIfNeeded(index: 2)
        XCTAssertEqual(game.lastToggledCardIndex, 2)
        
        game.toggleCardAndResetIfNeeded(index: 3)
        XCTAssertEqual(game.lastToggledCardIndex, 3)
    }
    
    func test_togglesCardAndResetIfNeeded_resetsCardsIfCardsDontMatch() throws {
        let card1 = anyCard(tag: 0)
        let card2 = anyCard(tag: 2)
        let card3 = anyCard(tag: 3)
        
        let game = Game(cards: [card1, card2, card3])
        game.toggleCardAndResetIfNeeded(index: 0)
        game.toggleCardAndResetIfNeeded(index: 2)
        
        XCTAssertEqual(game.cards[0].showBack, true)
        XCTAssertEqual(game.cards[2].showBack, true)
    }
    
    func test_togglesCardAndResetIfNeeded_doesntResetCardsIfCardsMatch() throws {
        
        let game = Game(cards: [anyCard(), anyCard()])
        game.toggleCardAndResetIfNeeded(index: 0)
        game.toggleCardAndResetIfNeeded(index: 1)

        XCTAssertEqual(game.cards[0].showBack, false)
        XCTAssertEqual(game.cards[1].showBack, false)
    }
    
    
    func anyCard(tag: Int = 0) -> FunkoCard {
        FunkoCard(image: "any-image", tag: tag)
    }
}


