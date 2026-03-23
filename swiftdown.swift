
// example/sources/main.swift
// Hello world
//
//
func helloWorld() {
    print("Hello world!")
}

helloWorld()


// Package.swift
// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swiftdown",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/JohnSundell/Splash", from: "0.1.0"),
        .package(url: "https://github.com/crisfeim/package-mini-swift-server", branch: "main")
    ],
    targets: [
        .target(name: "Core", dependencies: ["Splash"]),
        .executableTarget(
            name: "swiftdown",
            dependencies: [
                "Core",
                .product(name: "MiniSwiftServer", package: "package-mini-swift-server"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core", "swiftdown", .product(name: "MiniSwiftServer", package: "package-mini-swift-server")],
            resources: [.copy("input")]
        )
    ]
)


// Sources/Core/App/Swiftdown.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public struct Swiftdown: FileHandler {
    
    let runner         : Runner
    
    let syntaxParser   : Parser
    let logsParser     : Parser
    let markdownParser : Parser
    
    let sourcesURL     : URL
    let outputURL      : URL
    let themeURL       : URL
    let langExtension  : String
    
    let author         : Author
    
    public init(
        runner: Runner,
        syntaxParser: Parser,
        logsParser: Parser,
        markdownParser: Parser,
        sourcesURL: URL,
        outputURL: URL,
        themeURL: URL,
        langExtension: String,
        author: Author
    ) {
        self.runner = runner
        self.syntaxParser = syntaxParser
        self.logsParser = logsParser
        self.markdownParser = markdownParser
        self.sourcesURL = sourcesURL
        self.outputURL = outputURL
        self.themeURL = themeURL
        self.langExtension = langExtension
        self.author = author
    }
    
    public func build() throws {
        try FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try writeTemplateAssets()
        
        try getFileURLs().forEach {
            let rendered = try parse($0)
            let outputURL = outputURL.appendingPathComponent($0.lastPathComponent + ".html")
            try write(rendered, to: outputURL)
        }
    }
    
    func getFileURLs() throws -> [URL] {
        try getFileURLs(in: sourcesURL).filter { $0.lastPathComponent.contains(".\(langExtension)") }
    }
    
    // @nicetohave:
    // If I had a more sophisticated templating engine,
    // this wouldn't be render here...
    func renderFiles() throws -> String {
        let elements = try getFileURLs().reduce("") { current, next in
            let path = next.lastPathComponent
            return current + """
   <li>
   <a	href="#"
    onclick="loadContent('/\(path)', 'main'); return false;">
    \(path)
   </a>
   """
        }
        return "<ul>\(elements)</ul>"
    }
    
    public func parse(_ url: URL) throws -> String {
        let filename = url.lastPathComponent
        let contents = try String(contentsOf: url, encoding: .utf8)
        
        let logs = logsParser.parse(try runner.run(contents, with: filename, extension: nil))
        
        var parse: (String) -> String { syntaxParser.parse >>> markdownParser.parse }
        
        let data = [
            "$title": filename,
            "$content": parse(contents),
            "$author-name": author.name,
            "$author-website": author.website,
            "$logs": logs,
            "$files": try renderFiles()
        ]
        
        return try TemplateEngine(folder: themeURL, data: data).render()
    }
    
    func writeTemplateAssets() throws {
        try copyFiles(from: themeURL, to: outputURL, excluding: ["index.html"])
    }
}

infix operator >>> : AdditionPrecedence
func >>><A>(first: @escaping (A) -> A, second: @escaping (A) -> A) -> (A) -> A {
    return { input in second(first(input)) }
}

extension Swiftdown {
    public struct Author {
        let name: String
        let website: String
        
        public init(name: String, website: String) {
            self.name = name
            self.website = website
        }
    }
}

extension SwiftSyntaxHighlighter: Parser {}
extension MarkdownParser		 : Parser {}
extension LogsParser			 : Parser {}
extension CodeRunner			 : Runner {}


// Sources/Core/App/TemplateEngine.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public struct TemplateEngine {
	let folder: URL
	let data: [String: String]

	var index: URL {
		folder.appendingPathComponent("index.html")
	}
    
    public init(folder: URL, data: [String : String]) {
        self.folder = folder
        self.data = data
    }
    
	public func render() throws -> String {
		data.reduce(try String(contentsOf: index, encoding: .utf8)) { content, data in
			content.replacingOccurrences(of: data.key, with: data.value)
		}
	}
}


// Sources/Core/Domain/Parser.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public protocol Parser {
	func parse(_ string: String) -> String
}


// Sources/Core/Domain/Runner.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public protocol Runner {
	func run(_ code: String, with tmpFilename: String, extension ext: String?) throws -> String
}


// Sources/Core/Infra/Coderunner.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public struct CodeRunner {
    let executablePath: String

    func run(_ code: String) throws -> String {
        try run(code, with: "temp", extension: nil)
    }

    public func run(_ code: String, with tmpFilename: String, extension ext: String?) throws -> String {
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(tmpFilename).\(ext ?? "no-extension")")
        try write(code, to: tempFileURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [tempFileURL.path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let log = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Unable to read output", code: 0)
        }
        return log
    }

    func write(_ string: String, to url: URL) throws {
        let folderURL = url.deletingLastPathComponent()
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(
                at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }

        try string.write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated(unsafe) public static let swift = CodeRunner(executablePath: "/usr/bin/swift")
}


// Sources/Core/Infra/Parsing/LogsParser.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation
import RegexBuilder

public struct LogsParser {
	
    public init() {}
	public func parse(_ string: String) -> String {
		replaceLineNumberWithButton(in: string)
	}
	
	func replaceLineNumberWithButton(in text: String) -> String {
		let regex = Regex {
			Capture {
				OneOrMore(.digit)
			}
			OneOrMore(.whitespace) 
			Capture {
				ChoiceOf { 
					"✅"
					"❌"
				}
			}
			OneOrMore(.whitespace) 
		}
		
		let result = text.replacing(regex) { match in
			let lineNumber = match.1
			let symbol = match.2
			return "<button onclick=\"gotomatchingline(\(lineNumber))\">\(lineNumber)</button> \(symbol) "
		}
        return result
	}
}

func test_logparser() {
	let sut = LogsParser()
	let output = sut.parse("207 ✅ test_login_success()")
	let expectedOutput = #"<button onclick="gotomatchingline(207)">207</button> ✅ test_login_success()"#
	print(output)
	assert(output == expectedOutput)
}


// Sources/Core/Infra/Parsing/MarkdownParser.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public struct MarkdownParser {
    public init() {}
	public func parse(_ string: String) -> String {
		string.replacingOccurrences(of: #"^### (.*)$"#, with: "<h3>$1</h3>", options: .regularExpression)
		.replacingOccurrences(of: #"^## (.*)$"#, with: "<h2>$1</h2>", options: .regularExpression)
		.replacingOccurrences(of: #"^# (.*)$"#, with: "<h1>$1</h1>", options: .regularExpression)
		.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
		.replacingOccurrences(of: "\\*(.*?)\\*", with: "<em>$1</em>", options: .regularExpression)
		.replacingOccurrences(of: "__(.*?)__", with: "<u>$1</u>", options: .regularExpression)
		.replacingOccurrences(of: "~~(.*?)~~", with: "<del>$1</del>", options: .regularExpression)
		.replacingOccurrences(of: "!\\[(.*?)\\]\\((.*?)\\)", with: "<img src=\"$2\" alt=\"$1\" />", options: .regularExpression)
		.replacingOccurrences(of: "`(.*?)`", with: "<code>$1</code>")
	}
}


// Sources/Core/Infra/Parsing/SwiftSyntaxHighlighter.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation
import Splash

public struct SwiftSyntaxHighlighter {
    
    private let splash = SyntaxHighlighter(format: HTMLOutputFormat())
	private let lineInjector = LineInjector()
	private let defintionHighlighter = DefinitionsHighlighter()
	private let customTypeParser = CustomTypeHighlighter()
	
    
    public init() {}
	 func run(_ string: String) -> String {
		let customTypes = customTypeParser.extractCustomTypes(from: string)
		let paserCustomTypes = { customTypeParser.run($0, from: customTypes) }
		return (
			splash.highlight >>>
			lineInjector.run >>>
			defintionHighlighter.run >>>
			parseKeywords >>>
			paserCustomTypes >>>
			parseComments >>>
			parseOperators
		)(string)
	}

	public func parse(_ string: String) -> String { run(string) }
	
	fileprivate func parseKeywords(on string: String) -> String {
		
		string.replacingOccurrences(
			of: #"<span class="call">throws</span>"#, 
			with: #"<span class="keyword">throws</span>"#
		)
		.replacingOccurrences(
			of: #"<span class="keyword">extension</span>"#,
			with: #"<span class="keyword-extension">extension</span>"#
		)
	}
	
	private func parseOperators(on string: String) -> String {
		string.replacingOccurrences(of: "infix operator", with: #"<span class="keyword">infix operator</span>"#)
		.replacingOccurrences(of: "prefix operator", with: #"<span class="keyword">prefix operator</span>"#)
		.replacingOccurrences(of: "postfix operator", with: #"<span class="keyword">postfix operator</span>"#)
	}
	
	private func parseComments(on string: String) -> String {
		string
		.replacingOccurrences(of: "/// ", with: "")
		.replacingOccurrences(of: "// ", with: "")
		.replacingOccurrences(of: "///", with: "")
		.replacingOccurrences(of: "//", with: "")
		.replacingOccurrences(of: "/*", with: "")
		.replacingOccurrences(of: "*/", with: "")
	}
}


fileprivate final class SwiftSyntaxHighlighterTests {
	func run() {
		test_keyword()
	}
	
	
	func test_keyword() {
		let sut = SwiftSyntaxHighlighter()
		let sourceCode = """
		<span class="call">throws</span>
		<span class="keyword">extension</span>
		"""
		let result = sut.parseKeywords(on: sourceCode)
		let expectedResult = """
		<span class="keyword">throws</span>
		<span class="keyword-extension">extension</span>
		"""
		
		assert(result == expectedResult)
	}
}



infix operator >>> : AdditionPrecedence
fileprivate func >>>(first: @escaping (String) -> String, second: @escaping (String) -> String) -> (String) -> String {
	return { input in second(first(input)) }
}

// MARK: - Definitions
extension SwiftSyntaxHighlighter {
	public struct DefinitionsHighlighter {
		public enum Definition: String, CaseIterable {
			case `class`
			case `enum` 
			case `struct`
			case `protocol`
			case `typealias`
			case `func`
			case `let`
			case `var`
			case `case`
			
			var cssClassName: String {
				switch self {
					case .func, .let, .var, .case: return "other-definition"
					default: return "type-definition"
				}
			}
		}
		
        public init() {}
		public func run(_ string: String) -> String {
			highlightDefinition(on: Definition.allCases.reduce(string) { current, keyword in
				highlightDefinition(on: current, keyword)
			}, definition: "final class", cssClassName: "type-definition")
		}
		
        public func highlightDefinition(on string: String,_ definition: Definition) -> String {
			highlightDefinition(on: string, definition: definition.rawValue, cssClassName: definition.cssClassName)
		} 
		
		func highlightDefinition(on string: String, definition: String, cssClassName: String) -> String {
			let pattern = "(<span class=\"keyword\">\(definition)</span>)\\s+([A-Za-z][A-Za-z0-9_]*)"
			
			let template = "$1 <span class=\"\(cssClassName)\">$2</span>"
			
			do {
				let regex = try NSRegularExpression(pattern: pattern, options: [])
				let range = NSRange(string.startIndex..<string.endIndex, in: string)
				
				let modifiedString = regex.stringByReplacingMatches(
					in: string,
					options: [],
					range: range,
					withTemplate: template
				)
				
				return modifiedString
			} catch {
				print("Error en la regex: \(error)")
				return string
			}
		}
	}
}



// MARK: - LineInjector
extension SwiftSyntaxHighlighter {
  public struct LineInjector {
      
      public init() {}
		// Injects lines as html `<span>`
      public func run(_ string: String) -> String {
			string.components(separatedBy: "\n").enumerated().reduce("") { (result, line) in
				let (index, content) = line
				return result + makeLine(index, content)
			}
		}
		
		private func makeLine(_ index: Int, _ content: String) -> String {
			"<span id=\"line-\(index + 1)\" class=\"line-number \(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "empty-line" : "")\">\(index + 1)</span>" + content + "\n"
		}
	}
}

// MARK: - CustopType 
extension SwiftSyntaxHighlighter {

	fileprivate struct CustomTypeHighlighter {
		
		func run(_ string: String, from types: Set<String>) -> String {
//			let types = extractCustomTypes(from: string)
			var result = string
			
			let pattern = #"<span class="type">([^<]+)</span>"#
			
			guard let regex = try? NSRegularExpression(pattern: pattern) else {
				return string
			}
			
			let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
			
			for match in matches.reversed() {
				guard let typeRange = Range(match.range(at: 1), in: string) else { continue }
				let foundType = String(string[typeRange])
				
				if types.contains(foundType) {
					if let matchRange = Range(match.range, in: string) {
						let replacement = "<span class=\"custom-type\">\(foundType)</span>"
						result = result.replacingCharacters(in: matchRange, with: replacement)
					}
				}
			}
			return result
		}
	
		/// Gets custom types (created by the developper) on a given swift sourceCode
		func extractCustomTypes(from sourceCode: String) -> Set<String> {
			let typeDeclarationPatterns = [
						#"(?:class|struct|enum|protocol|typealias)\s+(\w+)"#
					]
			
			var customTypes = Set<String>()
			for pattern in typeDeclarationPatterns {
				guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
				let matches = regex.matches(
					in: sourceCode,
					range: NSRange(sourceCode.startIndex..., in: sourceCode)
				)
				for match in matches {
					if let range = Range(match.range(at: 1), in: sourceCode) {
						let typeName = String(sourceCode[range])
						customTypes.insert(typeName)
					}
				}
			}
			return customTypes
		}
	}
}


// Sources/Core/Utilities/Filehandler.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation

public struct TextFile {
	let name: String
	let content: String
}

protocol FileHandler: FileReader, FileWriter {}

public protocol FileReader {}
public extension FileReader {
	var fm: FileManager {.default}
	
	func getFileURLs(in folderURL: URL) throws -> [URL] {
		return try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
	}
	
	func readFile(at url: URL) throws -> String {
		try String(contentsOf: url, encoding: .utf8)
	}
	
	static func readFile(at url: URL) throws -> String {
		try String(contentsOf: url, encoding: .utf8)
	}
	
	func isFile(at url: URL) throws -> Bool {
		var isDirectory: ObjCBool = false
		fm.fileExists(atPath: url.path, isDirectory: &isDirectory) 
		return !isDirectory.boolValue
	}
	
	func isNotDStore(at url: URL) -> Bool {!url.lastPathComponent.contains(".DS_Store")}
	
	func readContentsOfAllFiles(in folderURL: URL) throws -> [TextFile] {
		return try getFileURLs(in: folderURL)
		.filter(isFile)
		.filter(isNotDStore)
		.map {
			TextFile(
				name: $0.lastPathComponent, 
				content: try readFile(at: $0) 
			)
		}
	}
	
	func copyFiles(from sourceURL: URL, to destinationURL: URL, excluding excludedFileNames: [String]) throws {
		let fileManager = FileManager.default
		if !fileManager.fileExists(atPath: destinationURL.path) {
			try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
		}
		
		let fileURLs = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)
		
		for fileURL in fileURLs {
			if excludedFileNames.contains(fileURL.lastPathComponent) { continue }
			let destinationFileURL = destinationURL.appendingPathComponent(fileURL.lastPathComponent)
			
			if fileManager.fileExists(atPath: destinationFileURL.path) {
				try fileManager.removeItem(at: destinationFileURL)
			}
			
			try fileManager.copyItem(at: fileURL, to: destinationFileURL)
		}
	}
}


protocol FileWriter  {}
extension FileWriter {
	func write(_ string: String, to url: URL) throws {
		let folderURL = url.deletingLastPathComponent()
		let fileManager = FileManager.default
		if !fileManager.fileExists(atPath: folderURL.path) {
			try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
		}
		
		try string.write(to: url, atomically: true, encoding: .utf8)
	}
}




// Sources/swiftdown/App.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation
import ArgumentParser
import Core

@main
struct SwiftDownCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftdown",
        abstract: "Static-site generator for Swift snippets.",
        subcommands: [Build.self, Serve.self]
    )
}

extension SwiftDownCLI {
    struct Build: ParsableCommand {
        @Argument(help: "Project folder's path")
                var folder: String = "."
        
        func run() throws {
            let (ssg, _) = try Composer.compose(with: folder)
            try ssg.build()
        }
    }
    
    struct Serve: ParsableCommand {
        @Argument(help: "Project folder's path")
                var folder: String = "."
        func run() throws {
            let (_, server) = try Composer.compose(with: folder)
            server.run()
        }
    }
}




// Sources/swiftdown/Composer.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation
import ArgumentParser
import Core
import MiniSwiftServer

enum Composer {
    static func compose(with pathURL: String) throws -> (Swiftdown, Server) {
        let folderURL   = URL(fileURLWithPath: pathURL).standardizedFileURL
        let sourcesURL  = folderURL.appendingPathComponent("sources")
        let themeURL    = folderURL.appendingPathComponent("theme")
        let outputURL   = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                           .appendingPathComponent("build")

        guard FileManager.default.fileExists(atPath: sourcesURL.path) else {
            throw ValidationError("Sources folder not found at: \(sourcesURL.path)")
        }
        guard FileManager.default.fileExists(atPath: themeURL.path) else {
            throw ValidationError("Sources folder not found at: \(themeURL.path)")
        }
        
        return make(sourcesURL: sourcesURL, themeURL: themeURL, outputURL: outputURL)
    }
    
   private static func make(
        sourcesURL: URL,
        themeURL: URL,
        outputURL: URL
    ) -> (Swiftdown, Server) {

        let ssg = Swiftdown(
            runner: CodeRunner.swift,
            syntaxParser: SwiftSyntaxHighlighter(),
            logsParser: LogsParser(),
            markdownParser: MarkdownParser(),
            sourcesURL: sourcesURL,
            outputURL: outputURL,
            themeURL: themeURL,
            langExtension: "swift",
            author: .init(name: "Cristian Felipe Patiño Rojas", website: "https://crisfe.me")
        )
        
        let requestHandler = RequestHandler(
            parser: ssg.parse,
            themeURL: themeURL,
            sourcesURL: sourcesURL,
            sourceExtension: "swift"
        )
        
        let server = Server(
            port: 4000,
            requestHandler: requestHandler.process
        )
        
        return (ssg, server)
    }
}


// Sources/swiftdown/RequestHandler.swift
// Copyright © 2025 Cristian Felipe Patiño Rojas
// Released under the MIT License

import Foundation
import MiniSwiftServer
import Core

public struct RequestHandler {
    let parser    : (URL) throws -> String
    let themeURL  : URL
    let sourcesURL: URL
    let sourceExtension: String
    
    public init(
        parser: @escaping (URL) throws -> String,
        themeURL: URL,
        sourcesURL: URL,
        sourceExtension: String
    ) {
        self.parser = parser
        self.themeURL = themeURL
        self.sourcesURL = sourcesURL
        self.sourceExtension = sourceExtension
    }
    
    public func process(_ request: Request) -> Response {
        if request.path == "/" || request.path.isEmpty {
            return handleIndex()
        }
        // if request has parameters, it's a resource
        guard !request.path.contains("?") else {
            return handleResourceFileWithParameters(request)
        }
        
        guard let ext = request.path.components(separatedBy: ".").last else {
            return Response(
                statusCode: 400,
                contentType: "text/html",
                body: .text("Paths need to have an extension")
            )
        }
        
        if ext == sourceExtension {
            return handleSourceFile(request.path)
        } else if ext == "html" {
            return handleSourceFileWithHTMLExtension(request.path)
        } else {
            return handleResourceFile(request.path, ext: ext)
        }
    }
    
    private func handleIndex() -> Response {
        let fileURL = sourcesURL.appendingPathComponent("main.\(sourceExtension)")
        guard let parsed = try? parser(fileURL) else {
            return Response(statusCode: 400, contentType: "text/html", body: .text("Add your main.swift file!"))
        }
        
        return Response(statusCode: 200, contentType: "text/html", body: .text(parsed))
    }
    
    func handleSourceFileWithHTMLExtension(_ path: String) -> Response {
        handleSourceFile(path.replacingOccurrences(of: ".html", with: "") + ".swift")
    }
    
    func handleSourceFile(_ path: String) -> Response {
        let fileURL = sourcesURL.appendingPathComponent(path)
        guard let parsed = try? parser(fileURL) else {
            return Response(statusCode: 400, contentType: "text/html", body: .text("Unable to parse contents of \(path)"))
        }
        return Response(statusCode: 200, contentType: "text/html", body: .text(parsed))
    }
    
    // Ignore any param in the url, useful when using
    // livereloadx
    func handleResourceFileWithParameters(_ request: Request) -> Response {
        let cleanPath = request.path.components(separatedBy: "?").first ?? request.path
        guard let ext = cleanPath.components(separatedBy: ".").last else {
            return Response(statusCode: 400, contentType: "text/html", body: .text("Paths need to have an extension"))
        }
        return handleResourceFile(cleanPath, ext: ext)
    }
    
    func handleResourceFile(_ path: String, ext: String) -> Response {
        
        let fileURL = themeURL.appendingPathComponent(path)
        
        let data = try? Data(contentsOf: fileURL)
        let content = try? String(contentsOf: fileURL, encoding: .utf8)
        
        if ext == "woff2", let data = data {
            return Response(statusCode: 200, contentType: "font/woff2", body: .binary(data))
        }
        
        if ext == "woff", let data = data {
            return Response(statusCode: 200, contentType: "font/woff", body: .binary(data))
        }
        
        if ext == "jpg", let data = data {
            return Response(statusCode: 200, contentType: "image/jpeg", body: .binary(data))
        }
        
        if ext == "css", let content {
            return Response(statusCode: 200, contentType: "text/css", body: .text(content))
        }
        
        if ext == "js", let content {
            return Response(statusCode: 200, contentType: "application/javascript", body: .text(content))
        }
        
        return Response(statusCode: 400, contentType: "text/html", body: .text("Unable to handle extension on \(path)"))
    }
}


// Tests/CoreTests/RequestHandlerTests.swift
// Created by Cristian Felipe Patiño Rojas on 7/5/25.

import XCTest
import MiniSwiftServer
import swiftdown

final class RequestHandlerTests: XCTestCase {
    
    func test_process_requestWithURLParametersIgnoresParametersAndCorrectlyReturnResourceContent() throws {
        let sut = makeSUT()
        let response = sut.process(anyRequestWithURLParameter(onPath: "css/styles.css"))
        let expectedResult = try readThemeResource("css/styles.css")
        XCTAssertEqual(response.contentType, "text/css")
        XCTAssertEqual(response.bodyAsText, expectedResult)
    }
    
    func test_process_swiftFileRequestReturnsSwiftFile() throws {
        let sut = makeSUT()
        let request = Request(method: .get, path: "example.swift.txt")
        let response = sut.process(request)
        let expectedResult = try readSwiftFile("example.swift.txt")
        XCTAssertEqual(response.bodyAsText, expectedResult)
    }
    
    func test_process_cssFileRequestReturnsCSSFile() throws {
        let sut = makeSUT()
        let request = Request(method: .get, body: nil, path: "css/styles.css")
        let response = sut.process(request)
        let expectedResult = try readThemeResource("css/styles.css")
        XCTAssertEqual(response.contentType , "text/css")
        XCTAssertEqual(response.bodyAsText , expectedResult)
    }
    
    func test_process_imageRequestsReturnsImage() throws {
        let sut = makeSUT()
        let response = sut.process(Request(method: .get, body: nil, path: "assets/author.jpg"))
        let expectedResult = try readThemeResourceAsData("assets/author.jpg")
        
        XCTAssertEqual(response.contentType , "image/jpeg")
        XCTAssertEqual(response.binaryData , expectedResult)
    }
    
    func makeSUT() -> RequestHandler {
        RequestHandler(
            parser: {try String(contentsOf: $0, encoding: .utf8)},
            themeURL: themeFolder(),
            sourcesURL: sourcesFolder(),
            sourceExtension: "txt"
        )
    }
}

extension RequestHandlerTests {
    
    private func anyRequestWithURLParameter(onPath path: String) -> Request {
        Request(method: .get, path: "\(path)?livereload=1729723229700")
    }
    
    private func readSwiftFile(_ path: String) throws -> String {
        try String(
            contentsOf: sourcesFolder().appendingPathComponent(path),
            encoding: .utf8
        )
    }
    
    private func readThemeResourceAsData(_ path: String) throws -> Data {
        try Data(contentsOf: themeFolder().appendingPathComponent(path))
    }
    
    private func readThemeResource(_ path: String) throws -> String {
        try String(
            contentsOf: themeFolder().appendingPathComponent(path),
            encoding: .utf8
        )
    }
    
    func testsResourceDirectory() -> URL {
        Bundle.module.bundleURL.appendingPathComponent("Contents/Resources")
    }
    
    func sourcesFolder() -> URL {
        inputFolder().appendingPathComponent("sources")
    }
    
    func inputFolder() -> URL {
        testsResourceDirectory().appendingPathComponent("input")
    }
    
    func themeFolder() -> URL {
        inputFolder().appendingPathComponent("theme")
    }
    
    func outputFolder() -> URL {
        testsResourceDirectory().appendingPathExtension("output")
    }
}


// Tests/CoreTests/SwiftDownTests.swift
// Created by Cristian Felipe Patiño Rojas on 7/5/25.

import XCTest
import Core

final class SwiftDownTests: XCTestCase, FileReader {
    
    override func setUp() {
        try? FileManager.default.removeItem(at: outputFolder())
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: outputFolder())
    }
    
    func test_theme_resources_are_coppied() throws {
        try makeSUT().build()
        
        let outputFiles = try fm.contentsOfDirectory(atPath: outputFolder().path)
        XCTAssert(outputFiles.contains("css"))
        XCTAssert(outputFiles.contains("js"))
        XCTAssert(outputFiles.contains("assets"))
        XCTAssert(!outputFiles.contains("index.html"))
    }
    
    func test_codesource_files_are_copied_as_html() throws {
        try makeSUT().build()
        let outputFiles = try fm.contentsOfDirectory(atPath: outputFolder().path)
        XCTAssert(outputFiles.contains("example.swift.txt.html"))
    }
    
    func getFileContents(fileName: String) throws -> String {
        let url = testsResourceDirectory().appendingPathComponent("example.swift")
        return try String(contentsOfFile: url.path, encoding: .utf8)
    }
    
    func makeSUT() -> Swiftdown {
        Swiftdown(
            runner: CodeRunner.swift,
            syntaxParser: SwiftSyntaxHighlighter(),
            logsParser: LogsParser(),
            markdownParser: MarkdownParser(),
            sourcesURL: sourcesFolder(),
            outputURL: outputFolder(),
            themeURL: themeFolder(),
            langExtension: "swift",
            author: .init(name: "Cristian Felipe Patiño Rojas", website: "https://cristian.lat")
        )
    }
    
    func testsResourceDirectory() -> URL {
        Bundle.module.bundleURL.appendingPathComponent("Contents/Resources")
    }
    
    func inputFolder() -> URL {
        testsResourceDirectory().appendingPathComponent("input")
    }
    
    func sourcesFolder() -> URL {
        inputFolder().appendingPathComponent("sources")
    }
    
    func themeFolder() -> URL {
        inputFolder().appendingPathComponent("theme")
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func testSpecificURL() -> URL {
        return cachesDirectory().appendingPathComponent("\(type(of: self))")
    }
    
    func outputFolder() -> URL {
        testSpecificURL().appendingPathComponent("output")
    }
}


// Tests/CoreTests/SyntaxHighlighterTests.swift
// Created by Cristian Felipe Patiño Rojas on 8/5/25.

import XCTest
import Core

class DefinitionsHighlighterTests: XCTestCase {
    
    func test_class() {
        let sut = SwiftSyntaxHighlighter.DefinitionsHighlighter()
        let input = #"<span class="keyword">class</span> MyType"#
        let expectedOutput = #"<span class="keyword">class</span> <span class="type-definition">MyType</span>"#
        let output = sut.highlightDefinition(on: input, .class)
        XCTAssertEqual(output, expectedOutput)
    }
    
    func test_enum() {
        let sut = SwiftSyntaxHighlighter.DefinitionsHighlighter()
        let input = #"<span class="keyword">enum</span> MyType"#
        let expectedOutput = #"<span class="keyword">enum</span> <span class="type-definition">MyType</span>"#
        let output = sut.highlightDefinition(on: input, .enum)
        XCTAssertEqual(output, expectedOutput)
    }
    
    func test() {
        let sut = SwiftSyntaxHighlighter.DefinitionsHighlighter()
        let input = #"<span class="keyword">class</span> MyType"#
        let expectedOutput = #"<span class="keyword">class</span> <span class="type-definition">MyType</span>"#
        let output = sut.run(input)
        XCTAssertEqual(output, expectedOutput)
    }
}


class LineInjectorTests: XCTestCase {
    func testRunWithEmptyString() {
        let injector = SwiftSyntaxHighlighter.LineInjector()
        let input = ""
        let expectedOutput = "<span id=\"line-1\" class=\"line-number empty-line\">1</span>\n"
        let output = injector.run(input)
        XCTAssertEqual(output, expectedOutput)
    }
}


// Tests/CoreTests/TemplateEngineTests.swift
// Created by Cristian Felipe Patiño Rojas on 7/5/25.
import XCTest
import Core

final class TemplateEngineTests: XCTestCase {
    
    func test() throws {
        let themeFolder = try makeTemporaryFolder(name: "theme")
        
        try "$title\n$content".write(
            to: themeFolder.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        
        let sut = TemplateEngine(
            folder: themeFolder,
            data: ["$title": "Hello world!", "$content": "Template rendered"]
        )
        let rendered = try sut.render()
        
        XCTAssertEqual(rendered, "Hello world!\nTemplate rendered")
    }
    
    @discardableResult
    func makeTemporaryFolder(name: String) throws -> URL {
        let tmpFolder  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: tmpFolder, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: tmpFolder, withIntermediateDirectories: true, attributes: nil)
        return tmpFolder
    }
}

