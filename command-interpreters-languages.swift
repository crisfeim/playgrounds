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

// MARK: - Synonym dictionaries per language

// All synonyms map to canonical English keywords that the regex understands.
// Structure: [languageCode: [synonym: canonical]]
private let synonymDicts: [String: [String: String]] = [
    "en": [
        "make": "create file", "touch": "create file", "new file": "create file",
        "add file": "create file", "generate": "create file",
        "mkdir": "create folder", "new folder": "create folder",
        "make folder": "create folder", "add folder": "create folder",
        "remove": "delete", "rm": "delete", "erase": "delete", "destroy": "delete",
        "move": "rename", "mv": "rename",
        "execute": "run", "exec": "run", "launch": "run",
    ],
    "es": [
        // create file
        "crear archivo": "create file", "crear fichero": "create file",
        "hacer archivo": "create file", "nuevo archivo": "create file",
        "crear": "create file",
        // create folder
        "crear carpeta": "create folder", "nueva carpeta": "create folder",
        "hacer carpeta": "create folder",
        // delete
        "borrar": "delete", "eliminar": "delete", "quitar": "delete",
        "remover": "delete",
        // rename
        "renombrar": "rename", "mover": "rename",
        // run
        "ejecutar": "run", "correr": "run", "lanzar": "run",
        // connector
        "luego": "then", "después": "then", "y luego": "then",
    ],
    "fr": [
        "créer fichier": "create file", "créer": "create file",
        "nouveau fichier": "create file",
        "créer dossier": "create folder", "nouveau dossier": "create folder",
        "supprimer": "delete", "effacer": "delete", "enlever": "delete",
        "renommer": "rename", "déplacer": "rename",
        "exécuter": "run", "lancer": "run",
        "puis": "then", "ensuite": "then",
    ],
    "de": [
        "erstelle datei": "create file", "neue datei": "create file",
        "erstelle ordner": "create folder", "neuer ordner": "create folder",
        "löschen": "delete", "entfernen": "delete",
        "umbenennen": "rename", "verschieben": "rename",
        "ausführen": "run", "starten": "run",
        "dann": "then", "danach": "then",
    ],
]

// MARK: - Language detection

func detectLanguage(_ input: String) -> String {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(input)
    return recognizer.dominantLanguage?.rawValue ?? "en"
}

// MARK: - Normalization

func normalize(_ input: String, languageCode: String? = nil) -> String {
    let lang = languageCode ?? detectLanguage(input)

    // Merge: language-specific dict + English fallback
    var dict = synonymDicts["en"] ?? [:]
    if lang != "en", let langDict = synonymDicts[lang] {
        dict.merge(langDict) { _, new in new }
    }

    var result = input.lowercased()

    // Sort by length descending so longer phrases match before shorter ones
    // e.g. "crear archivo" matches before "crear"
    let sorted = dict.sorted { $0.key.count > $1.key.count }

    for (synonym, canonical) in sorted {
        // Word boundary aware replacement
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: synonym))\\b"
        if let re = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = re.stringByReplacingMatches(in: result, range: range,
                                                  withTemplate: canonical)
        }
    }

    return result
}

// MARK: - Parser

func parse(_ input: String) -> [Action] {
    let normalized = normalize(input)
    return parseNormalized(normalized)
}

private func parseNormalized(_ s: String) -> [Action] {
    let patterns: [(String, (NSTextCheckingResult, String) -> Action?)] = [
        (#"(?i)rename\s+(\S+)\s+to\s+(\S+)"#, { match, str in
            guard match.numberOfRanges == 3,
                  let r1 = Range(match.range(at: 1), in: str),
                  let r2 = Range(match.range(at: 2), in: str) else { return nil }
            return .renameFile(from: String(str[r1]), to: String(str[r2]))
        }),
        (#"(?i)create file\s+(\S+)"#, { match, str in
            guard let r = Range(match.range(at: 1), in: str) else { return nil }
            return .createFile(path: String(str[r]))
        }),
        (#"(?i)create folder\s+(\S+)"#, { match, str in
            guard let r = Range(match.range(at: 1), in: str) else { return nil }
            return .createFolder(path: String(str[r]))
        }),
        (#"(?i)delete\s+(\S+)"#, { match, str in
            guard let r = Range(match.range(at: 1), in: str) else { return nil }
            return .deleteFile(path: String(str[r]))
        }),
        (#"(?i)run\s+(.+)"#, { match, str in
            guard let r = Range(match.range(at: 1), in: str) else { return nil }
            return .runCommand(command: String(str[r]))
        }),
    ]

    // Split on "then"
    let thenRe = try! NSRegularExpression(pattern: #"\s+(?:and\s+)?then\s+"#, options: .caseInsensitive)
    let ns = s as NSString
    var parts: [String] = []
    var lastEnd = 0
    for match in thenRe.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
        parts.append(ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd)))
        lastEnd = match.range.location + match.range.length
    }
    parts.append(ns.substring(from: lastEnd))

    return parts.map { part in
        for (pattern, builder) in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let match = re.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)),
                  let action = builder(match, part) else { continue }
            return action
        }
        return .unknown(input: part)
    }
}

// MARK: - Demo

func printActions(_ actions: [Action], label: String) {
    print("  [\(label)]")
    for a in actions {
        switch a {
        case .createFile(let p):        print("    createFile(\(p))")
        case .createFolder(let p):      print("    createFolder(\(p))")
        case .deleteFile(let p):        print("    deleteFile(\(p))")
        case .renameFile(let f, let t): print("    renameFile(\(f) -> \(t))")
        case .runCommand(let c):        print("    runCommand(\(c))")
        case .unknown(let i):           print("    unknown(\(i))")
        }
    }
}

let tests: [(input: String, lang: String?)] = [
    // English
    ("make main.swift", nil),
    ("mkdir src then touch src/index.html", nil),
    ("delete build", nil),
    ("rename old.swift to new.swift", nil),
    ("run swift main.swift", nil),
    // Spanish
    ("crear archivo main.swift", nil),
    ("borrar build luego ejecutar swift main.swift", nil),
    ("crear carpeta src luego crear archivo src/index.html", nil),
    // Mixed (forced lang detection)
    ("make main.swift then borrar old.swift", nil),
]

for test in tests {
    print("\nInput: \"\(test.input)\"")
    let detected = detectLanguage(test.input)
    print("  Detected language: \(detected)")
    printActions(parse(test.input), label: "Result")
}