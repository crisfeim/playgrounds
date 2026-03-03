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
