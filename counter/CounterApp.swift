import SwiftUI

@main
struct CounterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var count = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Contador: \(count)")
                .font(.largeTitle)
            Button("Incrementar") {
                count += 1
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
