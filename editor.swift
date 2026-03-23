import AppKit
import UniformTypeIdentifiers

// MARK: - Theme

struct Theme {
    let name: String
    let background:   NSColor
    let plainText:    NSColor
    let keywords:     NSColor
    let strings:      NSColor
    let comments:     NSColor
    let types:        NSColor
    let numbers:      NSColor
    let functions:    NSColor
    let operators:    NSColor
    // Gutter
    let gutterBackground: NSColor
    let gutterActiveLine: NSColor
    let gutterInactiveLine: NSColor

    // MARK: - Presets

    /// The original "Dark" preset — system colors, matches the app's initial look.
    static let dark = Theme(
        name:               "Dark",
        background:         .black,
        plainText:          .white,
        keywords:           .systemOrange,
        strings:            .systemYellow,
        comments:           .systemGray,
        types:              NSColor(red: 0.9, green: 0.6, blue: 0.4, alpha: 1),
        numbers:            .systemYellow,
        functions:          .systemBlue,
        operators:          .systemCyan,
        gutterBackground:   NSColor(white: 0.08, alpha: 1),
        gutterActiveLine:   NSColor.white.withAlphaComponent(0.85),
        gutterInactiveLine: NSColor.white.withAlphaComponent(0.25)
    )

    /// Xcode Default Dark theme — colors extracted from the official Xcode theme.
    static let xcodeDark = Theme(
        name:               "Xcode Dark",
        background:         NSColor(hex: "#292A30"),
        plainText:          NSColor(hex: "#DFDFE0"),
        keywords:           NSColor(hex: "#FF7AB2"),  // pink
        strings:            NSColor(hex: "#FF8170"),  // salmon
        comments:           NSColor(hex: "#7F8C98"),  // slate gray
        types:              NSColor(hex: "#DABAFF"),  // soft purple
        numbers:            NSColor(hex: "#D9C97C"),  // warm yellow
        functions:          NSColor(hex: "#4EB0CC"),  // sky blue
        operators:          NSColor(hex: "#DFDFE0"),  // plain text (dimmed punctuation)
        gutterBackground:   NSColor(hex: "#23232A"),
        gutterActiveLine:   NSColor(hex: "#DFDFE0").withAlphaComponent(0.85),
        gutterInactiveLine: NSColor(hex: "#DFDFE0").withAlphaComponent(0.25)
    )

    // Active theme — change this to switch themes app-wide.
    static var active: Theme = .dark
}

// MARK: - NSColor hex convenience init

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >>  8) & 0xFF) / 255
        let b = CGFloat( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - HighlightedStorage

final class HighlightedStorage: NSTextStorage {

    private let backing = NSMutableAttributedString()
    private let highlighter = SyntaxHighlighter()

    override var string: String { backing.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override func processEditing() {
        let nsString = backing.string as NSString
        let lineRange = nsString.lineRange(for: editedRange)
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        backing.addAttribute(.font, value: font, range: lineRange)
        backing.addAttribute(.foregroundColor, value: Theme.active.plainText, range: lineRange)

        // Small edits: highlight synchronously — zero latency at the cursor.
        // Large ranges (file load, big paste): highlight async so UI stays
        // responsive. Text appears white first, then gets colored.
        if lineRange.length < 3000 {
            let attributes = highlighter.computeAttributes(for: backing.string, in: lineRange)
            for attr in attributes {
                backing.addAttribute(.foregroundColor, value: attr.color, range: attr.range)
            }
            super.processEditing()
        } else {
            super.processEditing()
            let snapshot  = backing.string
            let snapRange = lineRange
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self else { return }
                let attributes = self.highlighter.computeAttributes(for: snapshot, in: snapRange)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.backing.string == snapshot else { return }
                    self.beginEditing()
                    for attr in attributes {
                        self.backing.addAttribute(.foregroundColor, value: attr.color, range: attr.range)
                    }
                    self.endEditing()
                }
            }
        }
    }
}

// MARK: - VimTextView

class VimTextView: NSTextView {

    enum VimMode { case normal, insert, replace }

    private let caretLayer = CAShapeLayer()

    private var vimMode: VimMode = .normal {
        didSet { updateCaretVisuals() }
    }

    // MARK: - Setup
    func setupVimEditor() {
        self.wantsLayer = true
        self.allowsUndo = true
        self.backgroundColor = Theme.active.background
        self.insertionPointColor = .controlAccentColor
        self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        caretLayer.zPosition = 100
        caretLayer.actions = ["position": NSNull(), "bounds": NSNull(), "path": NSNull()]
        self.layer?.addSublayer(caretLayer)
        disableAutomaticFeatures()
        updateCaretVisuals()
        setupAutocomplete()
    }

    private func disableAutomaticFeatures() {
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticSpellingCorrectionEnabled = false
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        // Guard against invalid ranges — can happen when textView.string is set
        // and AppKit tries to restore/update selection before layout is ready.
        let length = (string as NSString).length
        let safeRanges = ranges.filter { v in
            let r = v.rangeValue
            return r.location <= length && NSMaxRange(r) <= length
        }
        guard !safeRanges.isEmpty else { return }
        super.setSelectedRanges(safeRanges, affinity: affinity, stillSelecting: flag)
        updateCaretPosition()
        if !ghostSuffix.isEmpty { updateAutocomplete() }
        if vimMode == .normal {
            scrollOneLineIfNeeded()
        }
    }

    override func didChangeText() {
        super.didChangeText()
        if vimMode == .insert || vimMode == .replace {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0
                    self.scrollRangeToVisible(NSMakeRange(self.selectedRange().location, 0))
                }
                self.gutterNeedsDisplay()
            }
        }
    }

    /// For normal mode navigation: move viewport by exactly one line if cursor
    /// is outside the visible area — never more.
    func scrollOneLineIfNeeded() {
        guard let lm = layoutManager,
              let sv = enclosingScrollView,
              lm.numberOfGlyphs > 0 else { return }

        let loc   = selectedRange().location
        let nsStr = string as NSString
        guard nsStr.length > 0 else { return }

        // Don't force layout if glyphs aren't ready yet — happens during file load
        guard lm.firstUnlaidCharacterIndex() > loc else { return }

        let origin = textContainerOrigin
        let glyphIdx: Int
        if loc >= nsStr.length {
            glyphIdx = lm.numberOfGlyphs - 1
        } else {
            let gr = lm.glyphRange(forCharacterRange: NSMakeRange(loc, 0), actualCharacterRange: nil)
            glyphIdx = min(gr.location, lm.numberOfGlyphs - 1)
        }
        guard glyphIdx >= 0 && glyphIdx < lm.numberOfGlyphs else { return }

        var lineRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
        guard lineRect != .zero else { return }
        lineRect.origin.x += origin.x
        lineRect.origin.y += origin.y

        let visible = sv.documentVisibleRect
        if lineRect.minY < visible.minY {
            sv.contentView.setBoundsOrigin(NSPoint(x: visible.origin.x, y: lineRect.minY))
            sv.reflectScrolledClipView(sv.contentView)
        } else if lineRect.maxY > visible.maxY {
            sv.contentView.setBoundsOrigin(NSPoint(x: visible.origin.x, y: lineRect.maxY - visible.height))
            sv.reflectScrolledClipView(sv.contentView)
        }
    }

    private func updateCaretVisuals() {
        if vimMode == .insert {
            caretLayer.isHidden = true
            self.insertionPointColor = .controlAccentColor
        } else {
            caretLayer.isHidden = false
            self.insertionPointColor = .clear
            let color: NSColor = vimMode == .replace ? .systemRed : .systemGray
            caretLayer.fillColor = color.withAlphaComponent(0.3).cgColor
            caretLayer.strokeColor = color.cgColor
            caretLayer.lineWidth = 1.0
            updateCaretPosition()
        }
    }

    private func updateCaretPosition() {
        guard vimMode != .insert,
              let layoutManager = self.layoutManager,
              let textContainer = self.textContainer else { return }
        let loc = self.selectedRange()
        // Skip if layout hasn't reached the cursor yet — but always allow
        // position 0 (empty doc or start of file) since it's always laid out.
        if loc.location > 0 {
            guard layoutManager.firstUnlaidCharacterIndex() > loc.location else { return }
        }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: loc, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let origin = self.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        if rect.size.width <= 1 { rect.size.width = 8 }
        caretLayer.path = CGPath(rect: rect.insetBy(dx: 0.5, dy: 0.5), transform: nil)
        caretLayer.frame = self.bounds
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        if vimMode == .insert {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
        }
    }

    // MARK: - Key constants
    private let ESC = 53
    private let Caret = 33
    private let BEAKLINE = 10

    // MARK: - Pair balancing
    private let pairMap: [Character: Character] = [
        "(": ")", "[": "]", "{": "}", "<": ">",
        "\"": "\"", "'": "'", "`": "`",
        "¿": "?", "¡": "!",
    ]
    private let closers: Set<Character> = [")", "]", "}", ">", "\"", "'", "`", "?", "!"]

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "s", "o":
                if let vc = window?.contentViewController as? ViewController {
                    _ = vc.performKeyEquivalent(with: event)
                    return
                }
            default: break
            }
        }
        switch vimMode {
        case .normal:
            if event.keyCode == Caret {
                jumpToFirstNonBlank()
                return
            }
            // Arrow keys in normal mode — route through our moveUp/moveDown
            // so scrollOneLineIfNeeded is called correctly.
            switch event.keyCode {
            case 125: moveDown(nil); stack.clear(); return   // ↓
            case 126: moveUp(nil);   stack.clear(); return   // ↑
            case 123: moveCursor(to: max(0, selectedRange().location - 1)); stack.clear(); return  // ←
            case 124: moveCursor(to: min((string as NSString).length, selectedRange().location + 1)); stack.clear(); return  // →
            default: break
            }
            if handleNormalMode(event) { return }
        case .insert:
            if event.keyCode == ESC {
                dismissGhost()
                vimMode = .normal
                return
            }
            if event.keyCode == 48 {
                if event.modifierFlags.contains(.shift) {
                    // Shift+Tab — dedent selection or current line
                    indentSelectedLines(dedent: true)
                    return
                }
                if !ghostSuffix.isEmpty { acceptGhost(); return }
                if selectedRange().length > 0 {
                    indentSelectedLines(dedent: false)
                    return
                }
            }
            if event.keyCode == 36 {
                if !ghostSuffix.isEmpty { acceptGhost(); return }
                handleSmartEnter()
                updateAutocomplete()
                return
            }
            if let char = event.characters?.first,
               handlePairBalancing(char: char) {
                updateAutocomplete()
                return
            }
            super.keyDown(with: event)
            updateAutocomplete()
        case .replace:
            if let char = event.characters?.first {
                replaceCharacter(at: self.selectedRange().location, with: String(char))
            }
            vimMode = .normal
        }
    }

    private func handlePairBalancing(char: Character) -> Bool {
        let sel = self.selectedRange()
        let text = self.string as NSString
        if sel.length > 0, let closer = pairMap[char] {
            let selected = text.substring(with: sel)
            let wrapped = String(char) + selected + String(closer)
            insertAndNotify(wrapped, replacing: sel)
            self.setSelectedRange(NSMakeRange(sel.location + 1, sel.length))
            return true
        }
        if closers.contains(char) {
            let loc = sel.location
            if loc < text.length,
               let next = Unicode.Scalar(text.character(at: loc)).map(Character.init),
               next == char {
                moveCursor(to: loc + 1)
                return true
            }
        }
        if let closer = pairMap[char] {
            let pair = String(char) + String(closer)
            insertAndNotify(pair, replacing: sel)
            moveCursor(to: sel.location + 1)
            return true
        }
        return false
    }

    override func deleteBackward(_ sender: Any?) {
        guard vimMode == .insert else { super.deleteBackward(sender); return }
        let sel = self.selectedRange()
        let text = self.string as NSString
        let loc = sel.location
        if sel.length == 0, loc > 0, loc < text.length,
           let opener = Unicode.Scalar(text.character(at: loc - 1)).map(Character.init),
           let expectedCloser = pairMap[opener],
           let actualCloser  = Unicode.Scalar(text.character(at: loc)).map(Character.init),
           actualCloser == expectedCloser {
            insertAndNotify("", replacing: NSMakeRange(loc - 1, 2))
            updateAutocomplete()
            return
        }
        super.deleteBackward(sender)
        updateAutocomplete()
    }

    private func insertAndNotify(_ string: String, replacing range: NSRange) {
        guard self.shouldChangeText(in: range, replacementString: string) else { return }
        self.undoManager?.beginUndoGrouping()
        self.textStorage?.replaceCharacters(in: range, with: string)
        self.didChangeText()
        self.undoManager?.endUndoGrouping()
    }

    // Arrow keys go through a different internal path than setSelectedRanges —
    // override them to ensure one-line scroll and gutter redraw in all modes.
    override func moveUp(_ sender: Any?) {
        super.moveUp(sender)
        scrollOneLineIfNeeded()
        gutterNeedsDisplay()
    }

    override func moveDown(_ sender: Any?) {
        super.moveDown(sender)
        scrollOneLineIfNeeded()
        gutterNeedsDisplay()
    }

    private func gutterNeedsDisplay() {
        if let lnv = superview?.superview?.subviews.first(where: { $0 is LineNumberView }) {
            lnv.needsDisplay = true
        }
    }

    private func jumpToFirstNonBlank() {
        let text = self.string as NSString
        let lineRange = text.lineRange(for: NSMakeRange(self.selectedRange().location, 0))
        moveCursor(to: findFirstNonBlank(in: text, range: lineRange))
    }

    private func moveCursor(to location: Int) {
        self.setSelectedRange(NSMakeRange(location, 0))
    }

    var stack = CharacterStack()
    var unnamedRegister = ""

    // MARK: - Autocomplete

    private let ghostLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        f.textColor = NSColor.white.withAlphaComponent(0.3)
        f.backgroundColor = .clear
        f.isBezeled = false
        f.isEditable = false
        f.isSelectable = false
        f.cell?.wraps = false
        f.cell?.isScrollable = true
        return f
    }()

    private var ghostSuffix: String = ""

    func setupAutocomplete() {
        addSubview(ghostLabel)
    }

    func updateAutocomplete() {
        guard vimMode == .insert else { dismissGhost(); return }
        let loc = self.selectedRange().location
        let text = self.string as NSString

        // Don't suggest if cursor is mid-word (character to the right is word char)
        if loc < text.length,
           let scalar = Unicode.Scalar(text.character(at: loc)) {
            let c = Character(scalar)
            if c.isLetter || c.isNumber || c == "_" { dismissGhost(); return }
        }

        let prefix = currentWordPrefix(in: text, at: loc)
        guard !prefix.isEmpty,
              let match = AutocompleteProvider.shared.suggest(for: prefix),
              match != prefix
        else { dismissGhost(); return }
        ghostSuffix = String(match.dropFirst(prefix.count))
        ghostLabel.stringValue = ghostSuffix
        positionGhost(at: loc)
        ghostLabel.isHidden = false
    }

    func dismissGhost() {
        ghostSuffix = ""
        ghostLabel.stringValue = ""
        ghostLabel.isHidden = true
    }

    func acceptGhost() {
        guard !ghostSuffix.isEmpty else { return }
        insertAndNotify(ghostSuffix, replacing: NSMakeRange(self.selectedRange().location, 0))
        dismissGhost()
    }

    private func positionGhost(at charLocation: Int) {
        guard let lm = self.layoutManager, let tc = self.textContainer else { return }
        let glyphRange = lm.glyphRange(forCharacterRange: NSMakeRange(charLocation, 0),
                                       actualCharacterRange: nil)
        var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        let origin = self.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        ghostLabel.sizeToFit()
        ghostLabel.frame.origin = rect.origin
    }

    private func currentWordPrefix(in text: NSString, at location: Int) -> String {
        // Don't suggest if cursor is mid-word — char to the right is also an identifier char
        if location < text.length,
           let scalar = Unicode.Scalar(text.character(at: location)) {
            let c = Character(scalar)
            if c.isLetter || c.isNumber || c == "_" { return "" }
        }
        var start = location
        while start > 0 {
            guard let scalar = Unicode.Scalar(text.character(at: start - 1)) else { break }
            let c = Character(scalar)
            guard c.isLetter || c.isNumber || c == "_" else { break }
            start -= 1
        }
        guard start < location else { return "" }
        return text.substring(with: NSMakeRange(start, location - start))
    }
}

// MARK: - Autocomplete provider

final class AutocompleteProvider {
    static let shared = AutocompleteProvider()
    private let keywords: [String]
    private init() {
        keywords = [
            "associatedtype","async","await",
            "break",
            "case","catch","class","continue","convenience",
            "default","defer","deinit","didSet",
            "else","enum","extension",
            "fallthrough","false","fileprivate","final","for","func",
            "get","guard",
            "if","import","in","indirect","infix","init","inout","internal","is",
            "lazy","let",
            "mutating",
            "nil","none","nonisolated",
            "operator","optional","override",
            "postfix","precedencegroup","prefix","private","protocol","public",
            "repeat","required","rethrows","return",
            "self","set","some","static","struct","subscript","super","switch",
            "throw","throws","true","try","typealias",
            "unowned",
            "var",
            "weak","while","willSet",
        ].sorted { a, b in
            // Shorter matches first; break ties alphabetically
            a.count != b.count ? a.count < b.count : a < b
        }
    }
    func suggest(for prefix: String) -> String? {
        return keywords.first { $0.hasPrefix(prefix) }
    }
}

// MARK: - Normal mode

extension VimTextView {

    private func replaceCharacter(at location: Int, with newChar: String) {
        let text = self.string as NSString
        if location >= text.length { return }
        let range = NSMakeRange(location, 1)
        if text.character(at: location) == BEAKLINE { return }
        if self.shouldChangeText(in: range, replacementString: newChar) {
            self.undoManager?.beginUndoGrouping()
            self.textStorage?.replaceCharacters(in: range, with: newChar)
            self.didChangeText()
            self.undoManager?.endUndoGrouping()
            moveCursor(to: location)
        }
    }

    private func handleNormalMode(_ event: NSEvent) -> Bool {
        guard let char = event.charactersIgnoringModifiers?.first else { return false }
        let currentLoc = self.selectedRange().location
        let text = self.string as NSString
        let length = text.length

        switch char {
        case "i": vimMode = .insert; stack.clear(); return true
        case "a": moveCursor(to: min(length, currentLoc + 1)); vimMode = .insert; stack.clear(); return true
        case "d":
            if stack.last == "d" { deleteCurrentLine(); stack.pop() }
            else { stack.clear(); stack.push("d") }
            return true
        case "c": stack.clear(); stack.push("c"); return true
        case "u": self.undoManager?.undo(); stack.clear(); return true
        case "y":
            if stack.last == "y" { yankCurrentLine(); stack.pop() }
            else { stack.clear(); stack.push("y") }
            return true
        case "w":
            if stack.last == "d" { deleteWord(from: currentLoc); stack.pop() }
            else if stack.last == "c" { changeWord(from: currentLoc); stack.pop() }
            else if stack.last == "y" { yankWord(from: currentLoc); stack.pop() }
            else { moveCursor(to: findNextWord(in: text, from: currentLoc)) }
            stack.clear(); return true
        case "g":
            if stack.last == "g" { moveCursor(to: 0); stack.pop() }
            else { stack.clear(); stack.push("g") }
            return true
        case "p": pasteFromRegister(currentLoc: currentLoc, text: text); stack.clear(); return true
        case "o": openLineBelow(currentLoc: currentLoc, text: text); stack.clear(); return true
        case "^":
            let lineRange = text.lineRange(for: NSMakeRange(currentLoc, 0))
            moveCursor(to: findFirstNonBlank(in: text, range: lineRange))
            stack.clear(); return true
        case "x": deleteCharacter(at: currentLoc); stack.clear(); return true
        case "$":
            let lineRange = text.lineRange(for: NSMakeRange(currentLoc, 0))
            var end = lineRange.location + lineRange.length
            if end > 0 && text.character(at: end - 1) == 10 { end -= 1 }
            moveCursor(to: max(lineRange.location, end)); stack.clear(); return true
        case "0":
            let lineRange = text.lineRange(for: NSMakeRange(currentLoc, 0))
            moveCursor(to: lineRange.location); stack.clear(); return true
        case "h": moveCursor(to: max(0, currentLoc - 1)); stack.clear(); return true
        case "l": moveCursor(to: min(length, currentLoc + 1)); stack.clear(); return true
        case "j": self.moveDown(nil); stack.clear(); return true
        case "k": self.moveUp(nil); stack.clear(); return true
        case "G": moveCursor(to: length); stack.clear(); return true
        case "b": moveCursor(to: findPreviousWord(in: text, from: currentLoc)); stack.clear(); return true
        case "r": vimMode = .replace; stack.clear(); return true
        default: stack.clear(); return true
        }
    }

    private func pasteFromRegister(currentLoc: Int, text: NSString) {
        guard !unnamedRegister.isEmpty else { return }
        let insertionPoint: Int
        if unnamedRegister.hasSuffix("\n") {
            let lineRange = text.lineRange(for: NSMakeRange(currentLoc, 0))
            insertionPoint = lineRange.location + lineRange.length
        } else {
            insertionPoint = min(text.length, currentLoc + 1)
        }
        if self.shouldChangeText(in: NSMakeRange(insertionPoint, 0), replacementString: unnamedRegister) {
            self.undoManager?.beginUndoGrouping()
            self.insertText(unnamedRegister, replacementRange: NSMakeRange(insertionPoint, 0))
            self.didChangeText()
            self.undoManager?.endUndoGrouping()
            moveCursor(to: insertionPoint)
        }
    }

    private func openLineBelow(currentLoc: Int, text: NSString) {
        var endOfLine = text.length
        if currentLoc < text.length {
            let searchRange = NSMakeRange(currentLoc, text.length - currentLoc)
            let nextNewline = text.range(of: "\n", options: [], range: searchRange)
            if nextNewline.location != NSNotFound { endOfLine = nextNewline.location + 1 }
        }
        self.setSelectedRange(NSMakeRange(endOfLine, 0))
        self.insertText("\n", replacementRange: NSMakeRange(endOfLine, 0))
        self.setSelectedRange(NSMakeRange(endOfLine, 0))
        self.vimMode = .insert
    }

    private func yankCurrentLine() {
        let text = self.string as NSString
        let lineRange = text.lineRange(for: NSMakeRange(self.selectedRange().location, 0))
        unnamedRegister = text.substring(with: lineRange)
    }

    private func yankWord(from location: Int) {
        let text = self.string as NSString
        if location >= text.length { return }
        let end = findNextWord(in: text, from: location)
        unnamedRegister = text.substring(with: NSMakeRange(location, end - location))
    }

    private func deleteCharacter(at location: Int) {
        let text = self.string as NSString
        if location >= text.length { return }
        unnamedRegister = text.substring(with: NSMakeRange(location, 1))
        let range = NSMakeRange(location, 1)
        if self.shouldChangeText(in: range, replacementString: "") {
            self.textStorage?.replaceCharacters(in: range, with: "")
            self.didChangeText()
            let newLength = (self.string as NSString).length
            if location >= newLength && newLength > 0 { moveCursor(to: max(0, newLength - 1)) }
        }
    }

    private func deleteCurrentLine() {
        let text = self.string as NSString
        let currentLoc = self.selectedRange().location
        let lineRange = text.lineRange(for: NSMakeRange(currentLoc, 0))
        unnamedRegister = text.substring(with: lineRange)
        if self.shouldChangeText(in: lineRange, replacementString: "") {
            self.textStorage?.replaceCharacters(in: lineRange, with: "")
            self.didChangeText()
            let newLoc = min(lineRange.location, (self.string as NSString).length)
            let newLineRange = (self.string as NSString).lineRange(for: NSMakeRange(newLoc, 0))
            moveCursor(to: findFirstNonBlank(in: self.string as NSString, range: newLineRange))
        }
    }

    private func deleteWord(from location: Int) {
        let text = self.string as NSString
        if location >= text.length { return }
        let end = findNextWord(in: text, from: location)
        let range = NSMakeRange(location, end - location)
        unnamedRegister = text.substring(with: range)
        executeDeletion(in: range)
    }

    private func executeDeletion(in range: NSRange) {
        if self.shouldChangeText(in: range, replacementString: "") {
            self.undoManager?.beginUndoGrouping()
            self.textStorage?.replaceCharacters(in: range, with: "")
            self.didChangeText()
            self.undoManager?.endUndoGrouping()
        }
    }

    private func changeWord(from location: Int) {
        let text = self.string as NSString
        if location >= text.length { return }
        let end = findEndOfWordForChange(in: text, from: location)
        let range = NSMakeRange(location, end - location)
        unnamedRegister = text.substring(with: range)
        if self.shouldChangeText(in: range, replacementString: "") {
            self.textStorage?.replaceCharacters(in: range, with: "")
            self.didChangeText()
            self.vimMode = .insert
        }
    }

    private func findFirstNonBlank(in text: NSString, range: NSRange) -> Int {
        guard range.length > 0 else { return range.location }
        let whitespace = CharacterSet.whitespaces
        var loc = range.location
        let end = range.location + range.length
        while loc < end {
            let c = text.character(at: loc)
            if c == 10 { break }
            if let scalar = Unicode.Scalar(c), !whitespace.contains(scalar) { break }
            loc += 1
        }
        return min(loc, text.length)
    }

    private func findNextWord(in text: NSString, from location: Int) -> Int {
        let set = CharacterSet.whitespacesAndNewlines
        var loc = location
        while loc < text.length, let s = Unicode.Scalar(text.character(at: loc)), !set.contains(s) { loc += 1 }
        while loc < text.length, let s = Unicode.Scalar(text.character(at: loc)),  set.contains(s) { loc += 1 }
        return loc
    }

    private func findEndOfWordForChange(in text: NSString, from location: Int) -> Int {
        let set = CharacterSet.whitespacesAndNewlines
        var loc = location
        if loc >= text.length { return text.length }
        if let s = Unicode.Scalar(text.character(at: loc)), set.contains(s) {
            while loc < text.length, let s2 = Unicode.Scalar(text.character(at: loc)), set.contains(s2) { loc += 1 }
            return loc
        }
        while loc < text.length, let s = Unicode.Scalar(text.character(at: loc)), !set.contains(s) { loc += 1 }
        return loc
    }

    private func findPreviousWord(in text: NSString, from location: Int) -> Int {
        if location <= 0 { return 0 }
        var loc = location - 1
        let set = CharacterSet.whitespacesAndNewlines
        while loc > 0, let s = Unicode.Scalar(text.character(at: loc)),     set.contains(s) { loc -= 1 }
        while loc > 0, let s = Unicode.Scalar(text.character(at: loc - 1)), !set.contains(s) { loc -= 1 }
        return loc
    }
}

// MARK: - Smart indent

extension VimTextView {

    func handleSmartEnter() {
        let sel = self.selectedRange()
        let loc = sel.location
        let text = self.string as NSString
        let lineRange = text.lineRange(for: NSMakeRange(loc, 0))
        let indent = leadingTabs(in: text, lineRange: lineRange)
        let charBefore: Character? = loc > 0
            ? Unicode.Scalar(text.character(at: loc - 1)).map(Character.init) : nil
        let charAfter: Character? = loc < text.length
            ? Unicode.Scalar(text.character(at: loc)).map(Character.init) : nil
        if charBefore == "{" && charAfter == "}" {
            let insertion = "\n\(indent)\t\n\(indent)"
            insertAndNotify(insertion, replacing: sel)
            moveCursor(to: loc + 1 + indent.count + 1)
        } else {
            let extraTab = charBefore == "{" ? "\t" : ""
            let insertion = "\n\(indent)\(extraTab)"
            insertAndNotify(insertion, replacing: sel)
            moveCursor(to: loc + insertion.count)
        }
    }

    private func leadingTabs(in text: NSString, lineRange: NSRange) -> String {
        var count = 0
        var i = lineRange.location
        while i < lineRange.location + lineRange.length {
            guard let scalar = Unicode.Scalar(text.character(at: i)) else { break }
            if scalar == "\t" { count += 1; i += 1 } else { break }
        }
        return String(repeating: "\t", count: count)
    }

    /// Indent (or dedent) every line touched by the current selection.
    func indentSelectedLines(dedent: Bool) {
        let sel  = self.selectedRange()
        let text = self.string as NSString
        let firstLine = text.lineRange(for: NSMakeRange(sel.location, 0))
        let lastLine  = text.lineRange(for: NSMakeRange(max(sel.location, NSMaxRange(sel) - 1), 0))
        let fullRange = NSUnionRange(firstLine, lastLine)
        var lines = text.substring(with: fullRange).components(separatedBy: "\n")
        // Don't process the empty string after a trailing newline
        let count = lines.last == "" ? lines.count - 1 : lines.count
        for i in 0..<count {
            if dedent {
                if lines[i].hasPrefix("\t") { lines[i] = String(lines[i].dropFirst()) }
            } else {
                lines[i] = "\t" + lines[i]
            }
        }
        let newText = lines.joined(separator: "\n")
        insertAndNotify(newText, replacing: fullRange)
        // Restore a selection that covers the same lines
        let delta = dedent ? -count : count
        self.setSelectedRange(NSMakeRange(sel.location, max(0, sel.length + delta)))
    }
}

extension VimTextView {

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.charactersIgnoringModifiers == "b" else {
            return super.performKeyEquivalent(with: event)
        }
        expandScope()
        return true
    }

    private func expandScope() {
        let text = self.string as NSString
        let sel  = self.selectedRange()

        // Step 0: if no selection, first select the current word.
        if sel.length == 0 {
            if let wordRange = currentWordRange(in: text, at: sel.location) {
                self.setSelectedRange(wordRange)
                return
            }
        }

        // Step 1: if selection is exactly a word, try to extend it to include
        // an immediately-following pair (e.g. Person → Person(name: "Cristian")).
        if sel.length > 0 {
            let wordEnd = NSMaxRange(sel)
            if wordEnd < text.length,
               let scalar = Unicode.Scalar(text.character(at: wordEnd)) {
                let nextChar = Character(scalar)
                // Only extend if pair opens immediately after word (no space)
                let openerToCloser: [Character: Character] = ["{": "}", "(": ")", "[": "]", "<": ">"]
                if let closer = openerToCloser[nextChar],
                   let (_, close) = enclosingAsymmetricPair(
                       in: text, from: wordEnd + 1,
                       opener: nextChar, closer: closer) {
                    let extended = NSMakeRange(sel.location, close - sel.location + 1)
                    if extended.length > sel.length {
                        if let safe = validRange(extended, in: text) {
                            self.setSelectedRange(safe)
                            return
                        }
                    }
                }
            }
        }

        // Strategy: find the smallest pair/decl that is strictly larger than sel.
        // This always moves outward regardless of how sel was created.

        // Collect all candidate ranges that strictly contain sel
        var candidates: [NSRange] = []

        // Find all enclosing pairs of any kind from cursor (or start of sel)
        let anchor = sel.length == 0 ? sel.location : sel.location + 1

        // Try every pair type and collect innerBody, fullPair, fullDecl
        let asymmetric: [(Character, Character)] = [
            ("{", "}"), ("(", ")"), ("[", "]"),
            ("¿", "?"), ("¡", "!"),
        ]
        let openerToCloser: [Character: Character] = ["{": "}", "(": ")", "[": "]"]
        for (opener, closer) in asymmetric {
            var searchLoc = anchor
            var lastOpen = -1
            while searchLoc > 0 {
                guard let (open, close) = enclosingAsymmetricPair(
                    in: text, from: searchLoc, opener: opener, closer: closer) else { break }
                guard open != lastOpen else { break }
                lastOpen = open
                let inner = NSMakeRange(open + 1, close - open - 1)
                let full  = NSMakeRange(open, close - open + 1)
                candidates.append(inner)
                candidates.append(full)
                if opener == "{" {
                    candidates.append(fullDeclarationRange(in: text, openBrace: open, closeBrace: close))
                }
                // Also add word+pair (e.g. Person(…)) if a word precedes the opener
                if openerToCloser[opener] != nil,
                   let wordRange = currentWordRange(in: text, at: open > 0 ? open - 1 : 0),
                   NSMaxRange(wordRange) == open {
                    candidates.append(NSMakeRange(wordRange.location, close - wordRange.location + 1))
                }
                searchLoc = open
            }
        }
        for delim in ["\"", "'", "`"] as [Character] {
            // Don't search if cursor is sitting on the delimiter itself —
            // we can't tell if it's an opener or closer without a parser.
            let cursorChar = anchor < text.length
                ? Unicode.Scalar(text.character(at: anchor)).map(Character.init) : nil
            guard cursorChar != delim else { continue }
            if let (open, close) = enclosingSymmetricPair(in: text, from: anchor, delimiter: delim) {
                candidates.append(NSMakeRange(open + 1, close - open - 1))
                candidates.append(NSMakeRange(open, close - open + 1))
            }
        }

        // Compute current line range once — used for both = search and line candidate
        let lineRange = text.lineRange(for: NSMakeRange(anchor > 0 ? anchor - 1 : 0, 0))
        var lineEnd = NSMaxRange(lineRange)
        if lineEnd > lineRange.location,
           let scalar = Unicode.Scalar(text.character(at: lineEnd - 1)),
           scalar == "\n" { lineEnd -= 1 }

        // Add the RHS of an assignment (after `=`) as a candidate.
        // Only matches a bare `=` — not ==, !=, <=, >=, +=, -=, *=, /=.
        let lineStart = lineRange.location
        var eqPos = -1
        var i = lineStart
        while i < lineEnd {
            guard let scalar = Unicode.Scalar(text.character(at: i)) else { i += 1; continue }
            if scalar == "=" {
                let prev = i > lineStart ? Unicode.Scalar(text.character(at: i - 1)) : nil
                let next = i + 1 < text.length ? Unicode.Scalar(text.character(at: i + 1)) : nil
                let notAssign: Set<Unicode.Scalar> = ["=", "!", "<", ">", "+", "-", "*", "/"]
                if (prev == nil || !notAssign.contains(prev!)) &&
                   (next == nil || next! != "=") {
                    eqPos = i; break
                }
            }
            i += 1
        }
        if eqPos >= 0 {
            var rhsStart = eqPos + 1
            while rhsStart < lineEnd,
                  let scalar = Unicode.Scalar(text.character(at: rhsStart)),
                  scalar == " " || scalar == "\t" { rhsStart += 1 }
            if rhsStart < lineEnd {
                candidates.append(NSMakeRange(rhsStart, lineEnd - rhsStart))
            }
        }

        // Also add the current line (trimmed of trailing \n) as a candidate
        if lineEnd > lineRange.location {
            candidates.append(NSMakeRange(lineRange.location, lineEnd - lineRange.location))
        }

        // Filter: must strictly contain sel (larger and starts at or before sel)
        let strictly = candidates.compactMap { validRange($0, in: text) }.filter { r in
            r.length > sel.length &&
            r.location <= sel.location &&
            NSMaxRange(r) >= NSMaxRange(sel)
        }

        // Pick the smallest one
        guard let best = strictly.min(by: { $0.length < $1.length }),
              let safe = validRange(best, in: text) else { return }
        self.setSelectedRange(safe)
    }

    /// Returns the (open, close) indices of the smallest pair of any kind
    /// that strictly contains `location`. Considers both asymmetric pairs
    /// ({}, (), [], <>) and symmetric pairs (", ', `, ?, !).
    private func smallestEnclosingPair(in text: NSString, from location: Int) -> (Int, Int)? {
        var best: (Int, Int)? = nil

        // Check all asymmetric pairs
        let asymmetric: [(Character, Character)] = [
            ("{", "}"), ("(", ")"), ("[", "]"),
            ("¿", "?"), ("¡", "!"),
        ]
        for (opener, closer) in asymmetric {
            if let pair = enclosingAsymmetricPair(in: text, from: location,
                                                   opener: opener, closer: closer) {
                if best == nil || (pair.1 - pair.0) < (best!.1 - best!.0) {
                    best = pair
                }
            }
        }

        // Check symmetric pairs
        let symmetric: [Character] = ["\"", "'", "`"]
        for delim in symmetric {
            if let pair = enclosingSymmetricPair(in: text, from: location, delimiter: delim) {
                if best == nil || (pair.1 - pair.0) < (best!.1 - best!.0) {
                    best = pair
                }
            }
        }

        return best
    }

    /// Finds the innermost asymmetric pair (e.g. `{…}`) containing `location`.
    private func enclosingAsymmetricPair(in text: NSString, from location: Int,
                                          opener: Character, closer: Character) -> (Int, Int)? {
        var depth = 0
        var i = location - 1
        var openIdx: Int? = nil
        while i >= 0 {
            guard let scalar = Unicode.Scalar(text.character(at: i)) else { i -= 1; continue }
            let c = Character(scalar)
            if c == closer { depth += 1 }
            else if c == opener {
                if depth == 0 { openIdx = i; break }
                else { depth -= 1 }
            }
            i -= 1
        }
        guard let open = openIdx else { return nil }
        depth = 0
        var j = open
        while j < text.length {
            guard let scalar = Unicode.Scalar(text.character(at: j)) else { j += 1; continue }
            let c = Character(scalar)
            if c == opener { depth += 1 }
            else if c == closer {
                depth -= 1
                if depth == 0 { return (open, j) }
            }
            j += 1
        }
        return nil
    }

    /// Finds the innermost symmetric pair (e.g. `"…"`) containing `location`.
    private func enclosingSymmetricPair(in text: NSString, from location: Int,
                                         delimiter: Character) -> (Int, Int)? {
        // Find start of line
        let lineRange = text.lineRange(for: NSMakeRange(min(location, text.length - 1), 0))
        let lineStart = lineRange.location

        // Count delimiters from line start to location.
        // If count is even → cursor is outside any pair on this line → no match.
        // If count is odd → cursor is inside a pair → the last delimiter before
        // location is the opener.
        var count = 0
        var lastDelimPos = -1
        var i = lineStart
        while i < location && i < text.length {
            guard let scalar = Unicode.Scalar(text.character(at: i)) else { i += 1; continue }
            if Character(scalar) == delimiter {
                count += 1
                lastDelimPos = i
            }
            i += 1
        }

        // Even count → cursor is outside any pair
        guard count % 2 == 1, lastDelimPos >= 0 else { return nil }

        let open = lastDelimPos
        // Find closing delimiter after location on the same line
        var j = location
        while j < text.length {
            guard let scalar = Unicode.Scalar(text.character(at: j)) else { j += 1; continue }
            if scalar == "\n" { break }
            if Character(scalar) == delimiter { return (open, j) }
            j += 1
        }
        return nil
    }

    private func enclosingBracePair(in text: NSString, from location: Int) -> (Int, Int)? {
        enclosingAsymmetricPair(in: text, from: location, opener: "{", closer: "}")
    }

    /// Returns the range of the word under/adjacent to `location`, or nil if
    /// the cursor is on whitespace/punctuation.
    private func currentWordRange(in text: NSString, at location: Int) -> NSRange? {
        guard text.length > 0 else { return nil }
        let loc = min(location, text.length - 1)

        // Check if cursor is on a word character
        let isWordChar: (Int) -> Bool = { i in
            guard i >= 0, i < text.length,
                  let scalar = Unicode.Scalar(text.character(at: i)) else { return false }
            let c = Character(scalar)
            return c.isLetter || c.isNumber || c == "_"
        }

        // If cursor is not on a word char, try one position to the left
        var start = loc
        if !isWordChar(start) {
            guard start > 0, isWordChar(start - 1) else { return nil }
            start = start - 1
        }

        // Expand left
        var wordStart = start
        while wordStart > 0 && isWordChar(wordStart - 1) { wordStart -= 1 }

        // Expand right
        var wordEnd = start
        while wordEnd < text.length && isWordChar(wordEnd) { wordEnd += 1 }

        guard wordEnd > wordStart else { return nil }
        return NSMakeRange(wordStart, wordEnd - wordStart)
    }

    private func fullDeclarationRange(in text: NSString, openBrace: Int, closeBrace: Int) -> NSRange {
        var i = openBrace - 1
        while i >= 0, let s = Unicode.Scalar(text.character(at: i)),
              s == " " || s == "\t" { i -= 1 }
        let headerLineRange = text.lineRange(for: NSMakeRange(max(0, i), 0))
        let loc = headerLineRange.location
        let len = closeBrace - loc + 1
        guard len > 0, loc + len <= text.length else {
            return NSMakeRange(openBrace, max(0, closeBrace - openBrace + 1))
        }
        return NSMakeRange(loc, len)
    }

    private func validRange(_ r: NSRange, in text: NSString) -> NSRange? {
        guard r.location <= text.length,
              r.length >= 0,
              NSMaxRange(r) <= text.length else { return nil }
        return r
    }

    private func rangeContains(_ outer: NSRange, _ inner: NSRange) -> Bool {
        outer.location <= inner.location &&
        outer.location + outer.length >= inner.location + inner.length
    }
}

// MARK: - CharacterStack

struct CharacterStack {
    private var a = [Character]()
    var last: Character? { a.last }
    mutating func push(_ element: Character) { a.append(element) }
    @discardableResult mutating func pop() -> Character? { a.popLast() }
    mutating func clear() { a.removeAll() }
}

// MARK: - LineNumberView

final class LineNumberView: NSView {

    private weak var textView: VimTextView?
    private weak var scrollView: NSScrollView?

    static let width: CGFloat = 44

    private let gutterFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private var activeColor:    NSColor { Theme.active.gutterActiveLine }
    private var inactiveColor:  NSColor { Theme.active.gutterInactiveLine }
    private var gutterBg:       NSColor { Theme.active.gutterBackground }
    private var separatorColor: NSColor { Theme.active.gutterActiveLine.withAlphaComponent(0.07) }

    // Cache of newline positions — keeps draw() O(log n) instead of O(n).
    // newlinePositions[i] = character index of the i-th '\n' (0-based).
    private var newlinePositions: [Int] = []

    init(textView: VimTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: NSTextView.didChangeSelectionNotification, object: textView)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    override var isFlipped: Bool { true }

    @objc private func refresh() { needsDisplay = true }

    @objc private func textDidChange() {
        rebuildNewlineCache()
        updateWidth()
        DispatchQueue.main.async { [weak self] in self?.needsDisplay = true }
    }

    /// Rebuild the full newline cache. O(n) but only called on text change,
    /// not on every draw/scroll/selection.
    private func rebuildNewlineCache() {
        guard let tv = textView else { return }
        let s = tv.string as NSString
        var positions: [Int] = []
        positions.reserveCapacity(s.length / 40)  // rough estimate: ~40 chars/line
        var i = 0
        while i < s.length {
            if s.character(at: i) == 10 { positions.append(i) }
            i += 1
        }
        newlinePositions = positions
    }

    /// 1-based line number for a character index. O(log n) via binary search.
    private func lineNumber(for charIndex: Int) -> Int {
        // Binary search: count how many newlines are before charIndex
        var lo = 0, hi = newlinePositions.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if newlinePositions[mid] < charIndex { lo = mid + 1 } else { hi = mid }
        }
        return lo + 1  // 1-based
    }

    /// Call after loading a document to rebuild the newline cache.
    func invalidateCache() {
        rebuildNewlineCache()
        updateWidth()
        needsDisplay = true
    }

    func updateWidth() {
        let lineCount = max(1, newlinePositions.count + 1)
        let digits = max(3, "\(lineCount)".count)
        let sample = String(repeating: "8", count: digits) as NSString
        let w = sample.size(withAttributes: [.font: gutterFont]).width
        let newWidth = ceil(w) + 24
        if abs(frame.width - newWidth) > 0.5 {
            frame.size.width = newWidth
            (window?.contentViewController as? ViewController)?.layoutSubviews()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let tv  = textView,
              let lm  = tv.layoutManager,
              let tc  = tv.textContainer,
              let sv  = scrollView else { return }

        gutterBg.setFill()
        bounds.fill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()

        let content         = tv.string as NSString
        let visibleRect     = sv.documentVisibleRect
        let containerOrigin = tv.textContainerOrigin
        let cursorLoc       = tv.selectedRange().location

        // Cursor line index via binary search — O(log n)
        let cursorLineIndex = lineNumber(for: min(cursorLoc, max(0, content.length - 1))) - 1

        let visibleGlyphs = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        let visibleChars  = lm.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        let visibleEnd = content.length > 0 &&
                         content.character(at: content.length - 1) == 10 &&
                         NSMaxRange(visibleChars) >= content.length - 1
            ? content.length + 1
            : NSMaxRange(visibleChars)

        // First visible line number via binary search — O(log n)
        var lineNum = lineNumber(for: visibleChars.location)
        var currentLineIndex = lineNum - 1

        // Pre-compute label attributes once
        let activeAttrs:   [NSAttributedString.Key: Any] = [.font: gutterFont, .foregroundColor: activeColor]
        let inactiveAttrs: [NSAttributedString.Key: Any] = [.font: gutterFont, .foregroundColor: inactiveColor]

        var charIdx = visibleChars.location
        while charIdx < visibleEnd && charIdx <= content.length {
            let lineRange = content.lineRange(for: NSMakeRange(charIdx, 0))
            var lineRect: NSRect
            if lineRange.length == 0 {
                lineRect = lm.extraLineFragmentRect
                if lineRect == .zero {
                    let next = NSMaxRange(lineRange)
                    if next == charIdx { break }
                    charIdx = next; continue
                }
            } else {
                let glyphs = lm.glyphRange(forCharacterRange: NSMakeRange(charIdx, lineRange.length),
                                           actualCharacterRange: nil)
                lineRect = lm.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            }
            lineRect.origin.y += containerOrigin.y
            let y = lineRect.origin.y - visibleRect.origin.y
            let attrs = currentLineIndex == cursorLineIndex ? activeAttrs : inactiveAttrs
            let label = "\(lineNum)" as NSString
            let size  = label.size(withAttributes: attrs)
            label.draw(at: CGPoint(x: bounds.width - size.width - 12,
                                   y: y + (lineRect.height - size.height) / 2),
                       withAttributes: attrs)
            lineNum += 1
            currentLineIndex += 1
            let next = NSMaxRange(lineRange)
            if next == charIdx { break }
            charIdx = next
        }
    }
}

// MARK: - NonAnimatingClipView
// Subclass NSClipView to disable AppKit's built-in scroll animation,
// which fires when arrow keys move the cursor near the edge of the viewport.
final class NonAnimatingClipView: NSClipView {
    override func scroll(to newOrigin: NSPoint) {
        // Call setBoundsOrigin directly — skips the animation path entirely.
        setBoundsOrigin(newOrigin)
    }
}

// MARK: - ViewController

class ViewController: NSViewController {

    private var textView: VimTextView!
    private var scrollView: NSScrollView!
    private var lineNumberView: LineNumberView!
    private var currentFileURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true

        let storage = HighlightedStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(
            size: CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.scrollerStyle = .overlay
        // Replace the default clip view with our non-animating version
        let clipView = NonAnimatingClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        scrollView.contentView.postsBoundsChangedNotifications = true

        textView = VimTextView(frame: .zero, textContainer: textContainer)
        textView.setupVimEditor()
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        scrollView.documentView = textView

        lineNumberView = LineNumberView(textView: textView, scrollView: scrollView)
        lineNumberView.updateWidth()

        view.addSubview(lineNumberView)
        view.addSubview(scrollView)

        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification, object: textView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
        view.window?.delegate = self
        updateWindowTitle()
        layoutSubviews()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutSubviews()
    }

    func layoutSubviews() {
        let gutterW = lineNumberView.frame.width == 0 ? LineNumberView.width : lineNumberView.frame.width
        let total   = view.bounds
        lineNumberView.frame = NSRect(x: 0, y: 0, width: gutterW, height: total.height)
        scrollView.frame     = NSRect(x: gutterW, y: 0,
                                      width: total.width - gutterW, height: total.height)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "s": saveDocument(); return true
        case "o": openDocument(); return true
        default:  return super.performKeyEquivalent(with: event)
        }
    }

    private func saveDocument() {
        if let url = currentFileURL { write(to: url) } else { saveAs() }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.swiftSource, .plainText]
        panel.nameFieldStringValue = "Untitled.swift"
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.currentFileURL = url
            self?.write(to: url)
        }
    }

    private func write(to url: URL) {
        do {
            try textView.string.write(to: url, atomically: true, encoding: .utf8)
            currentFileURL = url
            updateWindowTitle()
            view.window?.isDocumentEdited = false
        } catch { presentError(error) }
    }

    private func openDocument() {
        if view.window?.isDocumentEdited == true {
            let alert = NSAlert()
            alert.messageText = "Unsaved changes"
            alert.informativeText = "Open a new file? Unsaved changes will be lost."
            alert.addButton(withTitle: "Open Anyway")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: view.window!) { [weak self] response in
                if response == .alertFirstButtonReturn { self?.runOpenPanel() }
            }
        } else {
            runOpenPanel()
        }
    }

    private func runOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.swiftSource, .plainText, .sourceCode]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.load(url: url)
        }
    }

    func load(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            guard let storage = textView.textStorage else { return }
            // Replace all content in one atomic operation — avoids the race between
            // string= assignment triggering setSelectedRanges and processEditing.
            storage.beginEditing()
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length),
                                      with: content)
            storage.endEditing()
            textView.setSelectedRange(NSMakeRange(0, 0))
            currentFileURL = url
            updateWindowTitle()
            view.window?.isDocumentEdited = false
            lineNumberView.invalidateCache()
        } catch { presentError(error) }
    }

    private func updateWindowTitle() {
        if let url = currentFileURL {
            view.window?.title = url.lastPathComponent
            view.window?.representedURL = url
        } else {
            view.window?.title = "Untitled"
        }
    }

    @objc private func textDidChange(_ notification: Notification) {
        view.window?.isDocumentEdited = true
    }
}

// MARK: - NSWindowDelegate

extension ViewController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.isDocumentEdited else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes?"
        alert.informativeText = "Save \"\(currentFileURL?.lastPathComponent ?? "Untitled")\" before closing?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: sender) { [weak self] response in
            switch response {
            case .alertFirstButtonReturn:  self?.saveDocument(); sender.close()
            case .alertSecondButtonReturn: sender.close()
            default: break
            }
        }
        return false
    }
}

// MARK: - SyntaxHighlighter

final class SyntaxHighlighter {

    private var theme: [String: NSColor] {
        let t = Theme.active
        return [
            "strong": t.keywords,
            "em":     t.strings,
            "sup":    t.comments,
            "label":  t.types,
            "num":    t.numbers,
            "b":      t.functions,
            "i":      t.operators,
        ]
    }

    private let SWIFT_KEYWORDS = "associatedtype|async|await|break|case|catch|class|continue|convenience|default|defer|deinit|do|else|enum|extension|fallthrough|false|fileprivate|final|for|func|get|guard|if|import|in|indirect|infix|init|inout|internal|is|lazy|let|mutating|nil|none|nonisolated|operator|optional|override|postfix|precedencegroup|prefix|private|protocol|public|repeat|required|rethrows|return|self|set|some|static|struct|subscript|super|switch|throw|throws|true|try|typealias|unowned|var|weak|while|willSet|didSet"

    struct TagRule {
        let tag: String
        let re: NSRegularExpression
        let shift: Bool
    }

    private let rules: [TagRule]

    init() {
        let rawRules: [(String, String, Bool)] = [
            ("sup",    "//.+",                                            false),
            ("em",     "\"[^\"]*\"|'[^']*'",                             false),
            ("strong", "\\b(\(SWIFT_KEYWORDS))\\b",                      false),
            ("num",    "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",                  false),
            ("label",  "\\b[A-Z][\\w\\d]*\\b",                          false),
            ("b",      "([\\w\\d]+)(?=\\s*\\()",                         true),
            ("b",      "([\\w\\d]+)(?=\\s*[:=\\.])",                     true),
            ("i",      "[\\{\\}\\(\\)\\[\\]\\.:,;\\+\\-\\*/&\\|!=<>]+", false),
        ]
        rules = rawRules.compactMap { tag, pattern, shift in
            guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
            return TagRule(tag: tag, re: re, shift: shift)
        }
    }

    func computeAttributes(for fullString: String, in limitRange: NSRange) -> [(range: NSRange, color: NSColor)] {
        var results: [(range: NSRange, color: NSColor)] = []
        var occupiedRanges = IndexSet()
        for rule in rules {
            guard let color = theme[rule.tag] else { continue }
            rule.re.enumerateMatches(in: fullString, options: [], range: limitRange) { match, _, _ in
                guard let match else { return }
                let targetRange = rule.shift && match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                let swiftRange = targetRange.location ..< (targetRange.location + targetRange.length)
                guard !occupiedRanges.intersects(integersIn: swiftRange) else { return }
                results.append((targetRange, color))
                occupiedRanges.insert(integersIn: swiftRange)
            }
        }
        return results
    }
}
