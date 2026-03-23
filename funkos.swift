
// CoreLogic/FunkoCard.swift
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


// CoreLogic/Game.swift
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


// CoreLogicTests/CoreLogicTests.swift
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




// Shared/Models.swift
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



// SwiftUI_version/ContentView.swift
//
//  ContentView.swift
//  GuessTheFunko
//
//  Created by Alex Chase on 3/17/23.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        // https://stackoverflow.com/questions/57244713/get-index-in-foreach-in-swiftui
        VStack(alignment: .center) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.cards.indices, id: \.self) { index in
                    let card = viewModel.cards[index]
                    Image(uiImage: card.showBack ? UIImage(named: "cardBack")! : card.uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(5)
                        .onTapGesture {
                            viewModel.handleCardTap(at: index)
                        }
                }
            }
            .padding(.horizontal)
            
            Text(viewModel.isGameOver ? "Game Over" : "Score \(viewModel.score)" )
                .font(.title2)
                .padding()
            
            Button("Play Again") {
                viewModel.playAgain()
            }
            .padding()
            .buttonStyle(.borderedProminent)
            .opacity(viewModel.isGameOver ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isGameOver) //optimization
        }
    }
    
    let columns = [
        GridItem(.fixed(80)),
        GridItem(.fixed(80)),
        GridItem(.fixed(80)),
        GridItem(.fixed(80))
    ]
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


// SwiftUI_version/ContentViewModel.swift
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


// SwiftUI_version/GuessTheFunkoSwiftUIApp.swift
//
//  GuessTheFunkoSwiftUIApp.swift
//  GuessTheFunkoSwiftUI
//
//  Created by Abe Hunt on 8/1/23.
//

import SwiftUI

@main
struct GuessTheFunkoSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


// UIKit_version/AppDelegate.swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}



// UIKit_version/SceneDelegate.swift
import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let scene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: scene)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}



// UIKit_version/ViewController.swift
import UIKit
import CoreLogic

final class ViewController: UIViewController {
    let game = Game(cards: FunkoCard.allCards.shuffled())
    lazy var rootView = makeGameUI()
    
    var tapHandler: (Int, UIButton) -> Void = { _,_ in }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        tapHandler =  { [weak self] index, btn in
            btn.setImage(self?.game.cards[index].toggledImage, for: .normal)
            self?.game.toggleCardAndResetIfNeeded(index: index)
            self?.reloadData()
        }
        
        view.backgroundColor = .white
        drawGameState()
    }
    
    func reloadData() {
        rootView.resultLabel.text = "Score: \(game.score)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.rootView.buttons.forEach { cardID, btn in
                let matchingCard = self?.game.cards.first(where: {$0.id == cardID })
                btn.setImage(matchingCard?.uiImage, for: .normal)
            }
        }
    }
}

extension ViewController {
    // @todo: this could be ideally abstracted into its own uiview
    // with delegation methods
    typealias GameUI = (stack: UIStackView, resultLabel: UILabel, buttons: [String: UIButton])
    func makeGameUI() -> GameUI {
        var buttons = [String: UIButton]()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        let rows: Int = 4
        let columns: Int = 4
        
        for row in 0 ..< rows {
            let horizontalSv = UIStackView()
            horizontalSv.axis = .horizontal
            horizontalSv.alignment = .fill
            horizontalSv.distribution = .fillEqually
            horizontalSv.spacing = 5

            for col in 0 ..< columns {
                let button = UIButton()
              
                let index = row*columns + col
                let card = game.cards[index]
                buttons[card.id] = button
                button.setImage(card.uiImage, for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
                button.addAction(UIAction(handler: {[weak self] _ in
                    self?.tapHandler(index, button)
                }), for: .touchUpInside)
                horizontalSv.addArrangedSubview(button)
            }
            stackView.addArrangedSubview(horizontalSv)
        }
        
        let resultLabel = UILabel()
        resultLabel.text = "Result:"
        resultLabel.textAlignment = .center
        stackView.addArrangedSubview(resultLabel)
        return (stackView, resultLabel, buttons)
    }
    
    func drawGameState() {
        let stackView = rootView.stack
        view.addSubview(stackView)

        let width = self.view.bounds.width - 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        stackView.widthAnchor.constraint(equalToConstant: width).isActive = true
        stackView.heightAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 1.0).isActive = true
    }
}


extension FunkoCard {
    
    var toggledImage: UIImage {
        showBack ? faceImage : backImage
    }
    
    var uiImage: UIImage {
        showBack ? backImage : faceImage
    }
    
    private var backImage: UIImage {
        .init(named: "cardBack")!
    }
    
    private var faceImage: UIImage {
        .init(named: "\(tag)")!
    }
    
}

