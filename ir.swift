// © 2026  Cristian Felipe Patiño Rojas. Created on 31/1/26.

import XCTest
import SwiftUI
import CustomDump

enum ViewNode: Equatable {
    case vstack([ViewNode])
    case hstack([ViewNode])
    case zstack([ViewNode])
    case button([ViewNode])
    case group ([ViewNode])
    case text (String)
    case image(String)
}

extension ViewNode {
    static func vstack(_ children: ViewNode...) -> Self {
        vstack(children)
    }

    static func hstack(_ children: ViewNode...) -> Self {
        hstack(children)
    }
    
    static func zstack(_ children: ViewNode...) -> Self {
        zstack(children)
    }
    
    static func group(_ children: ViewNode...) -> Self {
        group(children)
    }
  
    static func button(_ children: ViewNode...) -> Self {
        button(children)
    }
}

struct ViewNodeFactory {
    func parseView(_ view: Any) -> ViewNode? {
        let mirror = Mirror(reflecting: view)
        let typeString = String(describing: type(of: view))
        
        
        if typeString.contains("Optional") {
            let mirror = Mirror(reflecting: view)
            if mirror.displayStyle == .optional {
                if let child = mirror.children.first {
                    return parseView(child.value)
                }
                return nil
            }
        }
        
        if typeString.contains("Text"), let storage = mirror.descendant("storage") {
             let storageMirror = Mirror(reflecting: storage)
            if let anyTextStorage = storageMirror.descendant("anyTextStorage") {
                let keyMirror = Mirror(reflecting: anyTextStorage)
                if let key = keyMirror.descendant("key", "key") as? String {
                    return .text(key)
                }
            }
        }
        
        if typeString.contains("Image"), let provider = mirror.descendant("provider", "base"), let name = Mirror(reflecting: provider).descendant("name") {
            let name = String(describing: name)
            return .image(name)
        }
        
        if let tree = mirror.descendant("_tree") {
            let treeMirror = Mirror(reflecting: tree)
            if let content = treeMirror.descendant("content") {
                let children = parseChildren(content)
                if typeString.contains("VStack") { return .vstack(children) }
                if typeString.contains("HStack") { return .hstack(children) }
                if typeString.contains("ZStack") { return .zstack(children) }
            }
        }
        
        if typeString.contains("Button"), let label = mirror.descendant("label") {
            return .button(parseChildren(label))
        }
        
        if typeString.contains("Group"), let content = mirror.descendant("content") {
            return .group(parseChildren(content))
        }
        
        return nil
    }
    
    func parseChildren(_ content: Any) -> [ViewNode] {
        let mirror = Mirror(reflecting: content)
        let typeString = String(describing: type(of: content))
        
        if typeString.contains("TupleView"), let value = mirror.descendant("value") {
            let valueMirror = Mirror(reflecting: value)
            return valueMirror.children.compactMap { parseView($0.value) }
        }
        
        if let singleNode = parseView(content) {
            return [singleNode]
        }
        
        return []
    }
}

@MainActor
class SwiftUIViewNodeTests: XCTestCase {
    struct MyView: View {
        @State var some = "some"
        var body: some View {
            VStack {
                HStack {
                    Button("hello world") {}
                    Image("someImage")
                    if true {
                        ZStack {
                            Text("Hola")
                            Text("Mundo")
                        }
                    }
                }
                Group {
                    Text("Hola")
                    Text("Mundo")
                }
                Text("Hola")
                Text("Mundo")
            }
        }
    }
    
    
    func test() throws {
        let sut = ViewNodeFactory()
        dump(MyView().body)
        let node = try XCTUnwrap(sut.parseView(MyView().body))
        expectNoDifference(node, .vstack(
            .hstack(
                .button(.text("hello world")),
                .image("someImage"),
                .zstack(
                    .text("Hola"),
                    .text("Mundo")
                )
            ),
            .group(
                .text("Hola"),
                .text("Mundo")
            ),
            .text("Hola"),
            .text("Mundo")
        ))
    }
}
