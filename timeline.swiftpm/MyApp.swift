import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ItemListComposer()
        }
    }
}

import SwiftUI

struct ItemsState: Equatable {
    var movies = [Item]()
    var isLoading = true
}

struct Item: Identifiable, Equatable {
    let id: UUID
    let title: String
}

struct ItemList: View {
    @Binding var state: ItemsState
    
    var body: some View {
        List {
            ForEach(state.movies) { movie in
                Text(movie.title)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(movie)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
            }
        }
        .toolbar {
            Button {
                addMovie()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    private func addMovie() {
        let newMovie = Item(id: UUID(), title: "Item \(UUID().uuidString.prefix(8))")
        state.movies.append(newMovie)
    }
    
    private func delete(_ movie: Item) {
        state.movies.removeAll { $0.id == movie.id }
    }
}

@MainActor
final class StateTimeline_B<State> {
    private let clock = ContinuousClock()
    private var snapshots: [(instant: ContinuousClock.Instant, state: State)] = []

    func add(_ state: State) {
        snapshots.append((clock.now, state))
    }
}

struct Counter: View {
    let count: Int
    @Binding var action: Action?
    enum Action {
        case increase
        case decrease
    }
    
    var body: some View {
        VStack {
            Text(count.description)
            Button("+") { action = .increase }
            Button("-") { action = .decrease }
        }
    }
}

@MainActor
func Reducer<T>(_ reduce: @escaping (T) -> Void) -> Binding<T?> {
    .init(get: { .none }, set: { $0.map(reduce) })
}

struct CounterStore: View {
    @State var count = 0
    
    var body: some View {
        Counter(
            count: count,
            action: Reducer { action in
                reduce(&count, action)
            }
        )
    }
    
    func reduce(_ state: inout Int, _ action: Counter.Action) {
        switch action {
        case .increase: state += 1
        case .decrease: state -= 1
        }
    }
}

@MainActor
class StateTimeline<State: Sendable> {
    private var _history = [Date: State]()
    
    var history: [TimeInterval: State] {
        guard let firstDate = _history.keys.min() else { return [:] }
        return _history.reduce(into: [TimeInterval: State]()) {
            let offset = $1.key.timeIntervalSince(firstDate)
            $0[offset] = $1.value
        }
    }
    
    func add(_ state: State) {
        _history[Date()] = state
    }
    
    func replay() -> AsyncStream<State> {
        let sortedHistory = _history.sorted { $0.key < $1.key }
        
        return AsyncStream { continuation in
            let task = Task {
                for i in 0..<sortedHistory.count {
                    let current = sortedHistory[i]
                    continuation.yield(current.value)
                    
                    if i < sortedHistory.count - 1 {
                        let next = sortedHistory[i + 1]
                        let duration = next.key.timeIntervalSince(current.key)
                        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
struct ItemListComposer: View {
    @State var state = ItemsState()
    private let tl = StateTimeline<ItemsState>()
    @State var isReplaying = false
    @State var showHistorySheet = false
    
    var body: some View {
        NavigationStack {
            ItemList(state: $state.onChange(tl.add))
                .disabled(isReplaying)
                .animation(.linear, value: state)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            Task { await replay() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isReplaying)
                    }
                    
                    ToolbarItem(placement: .bottomBar) {
                        
                        Button("Show history") {
                            showHistorySheet = true
                        }
                    }
                }
                .sheet(isPresented: $showHistorySheet) {
                    NavigationStack {
                        List {
                            ForEach(tl.history.keys.sorted(), id: \.self) { timeInterval in
                                Section(header: Text("T + \(String(format: "%.2f", timeInterval))s")) {
                                    if let historicalState = tl.history[timeInterval] {
                                        ForEach(historicalState.movies) { movie in
                                            Text(movie.title)
                                                .font(.caption)
                                        }
                                        if historicalState.movies.isEmpty {
                                            Text("No movies")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("History")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
    }
    

    func replay() async {
        isReplaying = true
        for await states in tl.replay() {
            state = states
        }
        isReplaying = false
    }
}


extension Binding {
    @MainActor
    func onChange(_ observe: @escaping (Value) -> Void) -> Self {
        .init(get: { self.wrappedValue }, set: { self.wrappedValue  = $0 ; observe($0) })
    }
}
