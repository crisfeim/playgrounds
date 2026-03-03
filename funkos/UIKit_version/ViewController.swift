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
