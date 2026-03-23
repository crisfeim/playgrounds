
// CodePaperApp.swift
// © 2026  Cristian Felipe Patiño Rojas. Created on 15/3/26.

import SwiftUI

@main
struct CodePaperApp: App {
    @StateObject var engine = TaskPaperEngine()
    var body: some Scene {
        WindowGroup {
            CodepaperView(engine: engine)
                .navigationTitle(engine.currentFileURL?.lastPathComponent ?? "Untitled")
                .onOpenURL(perform: engine.loadExternalFile)
            
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    engine.saveFile()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            
            CommandGroup(replacing: .importExport) {
                Button("Open...") {
                    engine.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}



// ContentView.swift
import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - TaskPaperEngine
class TaskPaperEngine: ObservableObject {
    @Published var rawText: String = "// Proyecto A:\n\t// Tarea 1:\n\t\t// Subtarea 1.1:\n\t\t\tprint(\"hello\")\n// Proyecto B:\n\tprint(\"mundo\")"
    @Published var focusRange: ClosedRange<Int>? = nil
    @Published var consoleOutput: String = ""
    @Published var currentFileURL: URL? = nil
    
    @Published var navStack: [Int] = []
    @Published var forwardStack: [Int] = []
    @Published var foldedIds: Set<Int> = []
    
    var rootNavID: Int? { navStack.last }
    private let fm = FileManager.default
    
    var currentScopeName: String? {
        guard let rootID = rootNavID else { return nil }
        let lines = rawText.components(separatedBy: .newlines)
        guard rootID < lines.count else { return "FOLDER" }
        let line = lines[rootID]
        var displayName = line.trimmingCharacters(in: .whitespaces)
        if displayName.hasPrefix("//") { displayName = String(displayName.dropFirst(2)) }
        return displayName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ":", with: "").uppercased()
    }

    var navigationNodes: [(id: Int, text: String, depth: Int, visualLevel: Int, hasChildren: Bool)] {
        let lines = rawText.components(separatedBy: .newlines)
        let all = allScopes(in: lines)
        var visibleNodes: [(id: Int, text: String, depth: Int, hasChildren: Bool)] = []
        var skipUntilDepth: Int? = nil

        for (index, node) in all.enumerated() {
            if let skipDepth = skipUntilDepth {
                if node.depth > skipDepth { continue }
                else { skipUntilDepth = nil }
            }
            let hasChildren = (index + 1 < all.count) && (all[index + 1].depth > node.depth)
            if let rootID = rootNavID {
                if node.id <= rootID { continue }
                let rootDepth = getDepth(lines[rootID])
                if node.depth <= rootDepth { break }
                visibleNodes.append((node.id, node.text, node.depth, hasChildren))
            } else {
                visibleNodes.append((node.id, node.text, node.depth, hasChildren))
            }
            if foldedIds.contains(node.id) { skipUntilDepth = node.depth }
        }
        let sortedDepths = Array(Set(visibleNodes.map { $0.depth })).sorted()
        return visibleNodes.map { node in
            let level = sortedDepths.firstIndex(of: node.depth) ?? 0
            return (node.id, node.text, node.depth, level, node.hasChildren)
        }
    }

    private func allScopes(in lines: [String]) -> [(id: Int, text: String, depth: Int)] {
        lines.enumerated().compactMap { (i, line) in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix(":") else { return nil }
            var displayName = trimmed
            if displayName.hasPrefix("//") { displayName = String(displayName.dropFirst(2)) }
            displayName = displayName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ":", with: "")
            return (id: i, text: displayName, depth: getDepth(line))
        }
    }

    // --- NAVEGACIÓN ---
    func navigateTo(_ id: Int) {
        if rootNavID != id {
            navStack.append(id)
            forwardStack.removeAll()
        }
    }
    func goBack() { guard let last = navStack.popLast() else { return }; forwardStack.append(last) }
    func goForward() { guard let next = forwardStack.popLast() else { return }; navStack.append(next) }
    func toggleFold(_ id: Int) {
        if foldedIds.contains(id) { foldedIds.remove(id) } else { foldedIds.insert(id) }
    }
    func setFocus(at index: Int) {
        let lines = rawText.components(separatedBy: .newlines)
        let baseDepth = getDepth(lines[index])
        var end = index + 1
        while end < lines.count && (getDepth(lines[end]) > baseDepth || lines[end].trimmingCharacters(in: .whitespaces).isEmpty) { end += 1 }
        focusRange = index...(end - 1)
    }

    // --- BINDING ---
    var focusedText: Binding<String> {
        Binding(
            get: {
                guard let range = self.focusRange else { return self.rawText }
                let lines = self.rawText.components(separatedBy: .newlines)
                let safeRange = range.clamped(to: 0...(lines.count - 1))
                if self.rootNavID == safeRange.lowerBound {
                    let contentStart = safeRange.lowerBound + 1
                    guard contentStart <= safeRange.upperBound else { return "" }
                    let rootDepth = self.getDepth(lines[safeRange.lowerBound]) + 4
                    return lines[contentStart...safeRange.upperBound].map { String(self.dropLeadingVisualWidth($0, width: rootDepth)) }.joined(separator: "\n")
                }
                let rootDepth = self.getDepth(lines[safeRange.lowerBound])
                return lines[safeRange].map { String(self.dropLeadingVisualWidth($0, width: rootDepth)) }.joined(separator: "\n")
            },
            set: { newValue in
                guard let range = self.focusRange else { self.rawText = newValue; return }
                let linesBefore = self.rawText.components(separatedBy: .newlines)
                let safeRange = range.clamped(to: 0...(linesBefore.count - 1))
                let isNavMode = (self.rootNavID == safeRange.lowerBound)
                let headerPadding = String(linesBefore[safeRange.lowerBound].prefix(while: { $0 == " " || $0 == "\t" }))
                var finalLines: [String] = []
                if isNavMode {
                    finalLines.append(linesBefore[safeRange.lowerBound])
                    let contentPadding = headerPadding + "\t"
                    finalLines.append(contentsOf: newValue.components(separatedBy: .newlines).map { $0.isEmpty ? "" : contentPadding + $0 })
                } else {
                    finalLines = newValue.components(separatedBy: .newlines).map { $0.isEmpty ? "" : headerPadding + $0 }
                }
                var linesArray = linesBefore
                linesArray.replaceSubrange(safeRange, with: finalLines)
                self.rawText = linesArray.joined(separator: "\n")
                self.focusRange = safeRange.lowerBound...(safeRange.lowerBound + finalLines.count - 1)
            }
        )
    }

    // --- ARCHIVOS (Restaurado) ---
    func openFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.swiftSource, .text, .plainText]
        if panel.runModal() == .OK, let url = panel.url { loadExternalFile(from: url) }
    }
    func loadExternalFile(from url: URL) {
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            DispatchQueue.main.async {
                self.rawText = content; self.currentFileURL = url; self.focusRange = nil
                self.navStack = []; self.forwardStack = []; self.foldedIds = []
            }
        }
    }
    func saveFile() {
        guard let url = currentFileURL else { saveAsFile(); return }
        try? rawText.write(to: url, atomically: true, encoding: .utf8)
    }
    func saveAsFile() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.swiftSource, .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? rawText.write(to: url, atomically: true, encoding: .utf8)
            self.currentFileURL = url
        }
    }

    // --- UTILIDADES ---
    func getDepth(_ line: String) -> Int {
        let prefix = line.prefix(while: { $0 == " " || $0 == "\t" })
        return prefix.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
    }
    func dropLeadingVisualWidth(_ line: String, width: Int) -> Substring {
        var currentWidth = 0
        var dropIndex = line.startIndex
        for char in line {
            if currentWidth >= width || (char != " " && char != "\t") { break }
            currentWidth += (char == "\t" ? 4 : 1)
            dropIndex = line.index(after: dropIndex)
        }
        return line[dropIndex...]
    }
    func runCurrentScope() {
        let codeLines = focusedText.wrappedValue.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).hasSuffix(":") }
        let tmpURL = fm.temporaryDirectory.appendingPathComponent("temp_run.swift")
        try? codeLines.joined(separator: "\n").write(to: tmpURL, atomically: true, encoding: .utf8)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/env"); process.arguments = ["swift", tmpURL.path]
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        try? process.run(); process.waitUntilExit()
        if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
            DispatchQueue.main.async { self.consoleOutput = output.isEmpty ? "Finalizado" : output }
        }
    }
}

// MARK: - CodepaperView
import CodeMirror


struct CodepaperView: View {
    @ObservedObject var engine: TaskPaperEngine

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Button(action: { engine.goBack() }) { Image(systemName: "chevron.left") }
                            .buttonStyle(.plain).disabled(engine.navStack.isEmpty).keyboardShortcut(.leftArrow, modifiers: .command)
                        Button(action: { engine.goForward() }) { Image(systemName: "chevron.right") }
                            .buttonStyle(.plain).disabled(engine.forwardStack.isEmpty).keyboardShortcut(.rightArrow, modifiers: .command)
                    }
                    Text(engine.currentScopeName ?? "OUTLINE").font(.caption).bold().foregroundColor(.secondary)
                    Spacer()
                }.padding().frame(height: 50)

                List {
                    if engine.navStack.isEmpty {
                        HStack {
                            Color.clear.frame(width: 12)
                            Text("Home").font(.system(.callout, design: .monospaced)).fontWeight(engine.focusRange == nil ? .bold : .regular)
                        }.contentShape(Rectangle()).onTapGesture { engine.focusRange = nil }
                    }
                    ForEach(engine.navigationNodes, id: \.id) { node in
                        navigationRow(node: node).padding(.leading, CGFloat(node.visualLevel * 14))
                    }
                }
            }.frame(width: 250).background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: engine.runCurrentScope) { Image(systemName: "play.fill") }.keyboardShortcut("r", modifiers: .command)
                }.padding([.top, .horizontal])
                
                CodeMirror(value: engine.focusedText)
                    .cmLineNumber(.constant(true))
                    .cmFoldGutter(.constant(true))
                    .cmHighlightActiveLine(.constant(false))
                    .cmFontSize(.constant(14))
                    .cmLanguage(.constant(.swift))
                    .cmTheme(.constant(.xcodedark))
                    .border(.blue)
//                TextEditor(text: engine.focusedText)
//                    .border(.blue)
                    .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding()
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    Text("CONSOLE").font(.caption).bold().padding([.top, .leading])
                    TextEditor(text: .constant(engine.consoleOutput)).font(.system(.subheadline, design: .monospaced)).scrollContentBackground(.hidden).padding(8).frame(height: 150).background(Color.black.opacity(0.05))
                }
            }
        }.frame(minWidth: 900, minHeight: 600).onOpenURL(perform: engine.loadExternalFile)
    }
    
    func navigationRow(node: (id: Int, text: String, depth: Int, visualLevel: Int, hasChildren: Bool)) -> some View {
        let isFolded = engine.foldedIds.contains(node.id)
        let isFocused = engine.focusRange?.lowerBound == node.id
        return HStack(spacing: 4) {
            Group {
                if node.hasChildren {
                    Image(systemName: isFolded ? "chevron.right" : "chevron.down").font(.system(size: 8, weight: .black)).foregroundColor(.secondary).frame(width: 12, height: 24).contentShape(Rectangle()).onTapGesture { engine.toggleFold(node.id) }
                } else { Color.clear.frame(width: 12, height: 24) }
            }
            Text(node.text).font(.system(.callout, design: .monospaced)).fontWeight(isFocused ? .bold : .regular).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).onTapGesture { engine.setFocus(at: node.id) }
                .simultaneousGesture(TapGesture(count: 2).onEnded { engine.setFocus(at: node.id); engine.navigateTo(node.id) })
        }.frame(height: 24)
    }
}

