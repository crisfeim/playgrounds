import SwiftUI

private struct CartCountKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var cartCount: Binding<Int> {
        get { self[CartCountKey.self] }
        set { self[CartCountKey.self] = newValue }
    }
}

struct Home: View {
    @State var cartCount = 0
    
    var body: some View {
        VStack {
            CartList().environment(\.cartCount, $cartCount)
            Button("Add item to cart") { cartCount += 1 }
        }
    }
}

struct CartList: View {
    @EnvironmentBinding(\.cartCount) private var count
    var body: some View {
        Text(count.description)
    }
}

@propertyWrapper
struct EnvironmentBinding<Value>: DynamicProperty {
    @Environment private var binding: Binding<Value>
    init(_ keyPath: KeyPath<EnvironmentValues, Binding<Value>>) {
        self._binding = Environment(keyPath)
    }
    var wrappedValue: Value {
        get { binding.wrappedValue }
        nonmutating set { binding.wrappedValue = newValue }
    }
    var projectedValue: Binding<Value> {
        binding
    }
}