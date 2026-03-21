import Foundation
import NaturalLanguage

// MARK: - Domain

enum Action {
    case createFile(path: String)
    case createFolder(path: String)
    case deleteFile(path: String)
    case renameFile(from: String, to: String)
    case runCommand(command: String)
    case unknown(input: String)
}

// MARK: - 1. Regex (NSRegularExpression, sin bare slash)

func parseWithRegex(_ input: String) -> [Action] {
    let s = input.trimmingCharacters(in: .whitespaces)
    var results: [Action] = []

    let patterns: [(String, (NSTextCheckingResult, String) -> Action?)] = [
        // rename foo to bar
        (#"(?i)rename\s+(\S+)\s+to\s+(\S+)"#, { match, str in
            guard match.numberOfRanges == 3,
                  let r1 = Range(match.range(at: 1), in: str),
                  let r2 = Range(match.range(at: 2), in: str) else { return nil }
            return .renameFile(from: String(str[r1]), to: String(str[r2]))
        }),
        // create file / touch
        (#"(?i)(?:create file|touch)\s+(\S+)"#, { match, str in
            guard match.numberOfRanges == 2,
                  let r = Range(match.range(at: 1), in: str) else { return nil }
            return .createFile(path: String(str[r]))
        }),
        // create folder / mkdir
        (#"(?i)(?:create folder|mkdir)\s+(\S+)"#, { match, str in
            guard match.numberOfRanges == 2,
                  let r = Range(match.range(at: 1), in: str) else { return nil }
            return .createFolder(path: String(str[r]))
        }),
        // delete / rm
        (#"(?i)(?:delete|rm)\s+(\S+)"#, { match, str in
            guard match.numberOfRanges == 2,
                  let r = Range(match.range(at: 1), in: str) else { return nil }
            return .deleteFile(path: String(str[r]))
        }),
        // run / $
        (#"(?i)(?:run|\$)\s+(.+)"#, { match, str in
            guard match.numberOfRanges == 2,
                  let r = Range(match.range(at: 1), in: str) else { return nil }
            return .runCommand(command: String(str[r]))
        }),
    ]

    // Split on "then" o "and then" para múltiples acciones
    let thenPattern = try! NSRegularExpression(pattern: #"\s+(?:and\s+)?then\s+"#, options: .caseInsensitive)
    let nsString = s as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)
    var parts: [String] = []
    var lastEnd = 0
    for match in thenPattern.matches(in: s, range: fullRange) {
        let partRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
        parts.append(nsString.substring(with: partRange))
        lastEnd = match.range.location + match.range.length
    }
    parts.append(nsString.substring(from: lastEnd))

    for part in parts {
        var matched = false
        for (pattern, builder) in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(part.startIndex..., in: part)
            if let match = re.firstMatch(in: part, range: range),
               let action = builder(match, part) {
                results.append(action)
                matched = true
                break
            }
        }
        if !matched {
            results.append(.unknown(input: part))
        }
    }

    return results
}

// MARK: - 2. NaturalLanguage

// NL no entiende semántica de dominio por sí solo.
// Lo usamos para extraer tokens relevantes (verbos, sustantivos)
// y luego aplicamos nuestra lógica de dominio encima.

func parseWithNaturalLanguage(_ input: String) -> [Action] {
    var verbs: [String] = []
    var nouns: [String] = []

    let tagger = NLTagger(tagSchemes: [.lexicalClass])
    tagger.string = input

    tagger.enumerateTags(
        in: input.startIndex..<input.endIndex,
        unit: .word,
        scheme: .lexicalClass,
        options: [.omitWhitespace, .omitPunctuation]
    ) { tag, range in
        let word = String(input[range]).lowercased()
        switch tag {
        case .verb:       verbs.append(word)
        case .noun:       nouns.append(word)
        default: break
        }
        return true
    }

    // Mapeo de verbos a intenciones
    let createVerbs  = ["create", "make", "add", "touch", "new"]
    let deleteVerbs  = ["delete", "remove", "rm"]
    let renameVerbs  = ["rename", "move", "mv"]
    let runVerbs     = ["run", "execute", "launch"]
    let folderNouns  = ["folder", "directory", "dir"]

    guard let verb = verbs.first else {
        return [.unknown(input: input)]
    }

    let argument = nouns.last ?? ""

    if deleteVerbs.contains(verb) {
        return [.deleteFile(path: argument)]
    }
    if runVerbs.contains(verb) {
        return [.runCommand(command: argument)]
    }
    if renameVerbs.contains(verb) {
        let from = nouns.first ?? ""
        let to   = nouns.last  ?? ""
        return [.renameFile(from: from, to: to)]
    }
    if createVerbs.contains(verb) {
        let isFolder = folderNouns.contains(where: { nouns.contains($0) })
        if isFolder {
            return [.createFolder(path: argument)]
        } else {
            return [.createFile(path: argument)]
        }
    }

    return [.unknown(input: input)]
}

// MARK: - Demo

func printActions(_ actions: [Action], label: String) {
    print("\n[\(label)]")
    for a in actions {
        switch a {
        case .createFile(let p):       print("  createFile(\(p))")
        case .createFolder(let p):     print("  createFolder(\(p))")
        case .deleteFile(let p):       print("  deleteFile(\(p))")
        case .renameFile(let f, let t):print("  renameFile(\(f) -> \(t))")
        case .runCommand(let c):       print("  runCommand(\(c))")
        case .unknown(let i):          print("  unknown(\(i))")
        }
    }
}

let tests = [
    "create file main.swift",
    "mkdir src then touch src/index.html",
    "delete build",
    "rename old.swift to new.swift",
    "run swift main.swift",
    "create folder myproject then create file myproject/main.swift then run swift myproject/main.swift",
]

for test in tests {
    print("\nInput: \"\(test)\"")
//  printActions(parseWithRegex(test),           label: "Regex")
  printActions(parseWithNaturalLanguage(test), label: "NaturalLanguage")
}