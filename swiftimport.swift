
// Package.swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "swiftimport",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "swiftimport",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .testTarget(
            name: "swiftimportTests",
            dependencies: ["swiftimport"],
            resources: [.copy("files")]
        ),
    ]
)


// Sources/CLI.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 3/6/25.

import ArgumentParser
import Foundation

@main
struct CLI: ParsableCommand {
    @Option(name: .shortAndLong, help: "Input entry point swift file") var input: String
    @Option(name: .shortAndLong, help: "The extension of the file") var ext: String = "swift"
    mutating func run() throws {
       print(try execute())
    }
    
    func execute() throws -> String {
        return try FileImporter(keyword: "// import", ext: ext).makeExecutable(from: input)
    }
}


// Sources/FileHandler.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 3/6/25.

import Foundation

enum File {
    case directory
    case file(Data)
    
    struct Data {
        let url: URL
        let content: String
        let parentDir: URL
    }
}

protocol FileHandler {
    func getFile(_ url: URL) throws -> File?
    func getFileURLsOnDirectory(_ directoryURL: URL) throws -> [URL]
}


// Sources/FileImporter.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 2/6/25.


import Foundation
import RegexBuilder
import Collections

final class FileImporter {
    private let keyword: String
    private let ext: String
    private let fileHandler: FileHandler
    
    private var importedFilesByVisitOrder = OrderedSet<URL>()
    private var orderedFilesForConcatenation: OrderedSet<URL> {
        OrderedSet(importedFilesByVisitOrder.reversed())
    }
    
    init(keyword: String, ext: String, fileHandler: FileHandler = FileManager.default) {
        self.keyword = keyword
        self.ext = ext
        self.fileHandler = fileHandler
    }
    
    struct FileNotFoundError: Error {}
    
    func makeExecutable(from filePath: String) throws -> String {
        try scanImports( URL(fileURLWithPath: filePath))
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }
    
    func scanImports(_ fileURL: URL) throws -> OrderedSet<URL> {
        importedFilesByVisitOrder.removeAll()
        try scanFile(fileURL)
        return orderedFilesForConcatenation
    }
    
    func parseImports(_ content: String) -> OrderedSet<String> {
        let importPattern = Regex {
            Anchor.startOfLine
            "\(keyword) "
            Capture {
                OneOrMore {
                    ChoiceOf {
                        .word
                        "/"
                        "."
                    }
                }
                ChoiceOf {
                    ".swift.txt"
                    "/"
                }
            }
        }
        
        return OrderedSet(content
            .matches(of: importPattern)
            .map { String($0.output.1) })
    }
}

private extension FileImporter {
    
    func scanFile(_ fileURL: URL) throws {
        switch try fileHandler.getFile(fileURL) {
        case .directory: return try handleDirectory(fileURL)
        case .file(let data): return try handleFile(data)
        case .none: throw FileNotFoundError()
        }
    }
    
    func handleDirectory(_ directoryURL: URL) throws {
        try fileHandler.getFileURLsOnDirectory(directoryURL)
            .filter { $0.lastPathComponent.hasSuffix(ext) }
            .forEach { try scanFile($0) }
    }
    
    func handleFile(_ data: File.Data) throws {
        guard fileHasNotBeenAlreadyParsed(data.url) else { return }
        importedFilesByVisitOrder.append(data.url)
        
        try parseImports(data.content)
            .map { data.parentDir.appendingPathComponent($0, isDirectory: $0.hasSuffix("/")) }
            .forEach { try scanFile($0) }
    }
    
    func fileHasNotBeenAlreadyParsed(_ url: URL) -> Bool {
        !importedFilesByVisitOrder.contains(url)
    }
}


// Sources/FileManager.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 3/6/25.


import Foundation

extension FileManager: FileHandler {
    func getFile(_ url: URL) throws -> File? {
        var isDirectory: ObjCBool = false
        let fileExists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard fileExists else { return nil }
        guard !isDirectory.boolValue else { return .directory }
        
        let content = try String(contentsOfFile: url.path, encoding: .utf8)
        let parentDir = url.deletingLastPathComponent()
        return .file(File.Data(url: url, content: content, parentDir: parentDir))
    }
    
    func getFileURLsOnDirectory(_ directoryURL: URL) throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(domain: "Unable to read contents of directory", code: 0)
        }
        
    
        var files: [URL] = []
        
        for case let fileURL as URL in enumerator {
            files.append(fileURL)
        }
        
        return files
    }
}


// Tests/CLITests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 3/6/25.

import XCTest
@testable import swiftimport

class CLITests: XCTestCase {
    
    func test() throws {
        let srcFolder = Bundle.module.testFilesDirectory.appendingPathComponent("integrationTests")
        let entryPointFileURL = srcFolder.appendingPathComponent("a.swift.txt")
        let sut = try CLI.parse([
            "--input", entryPointFileURL.path,
            "--ext", "swift.txt"
        ])
        
        let result = try sut.execute()
        
        let expectedResult = """
        c file
        
        // import nested/c.swift.txt
        b file
        
        // import b.swift.txt
        a file
        
        """
        
        XCTAssertEqual(result, expectedResult)
    }
}


// Tests/FileImporterTests.swift
//
//  Created by Cristian Felipe Patiño Rojas on 2/5/25.

import XCTest
import Collections
@testable import swiftimport

final class FileImporterTests: XCTestCase {
    
    lazy var testSources = Bundle.module.testFilesDirectory
    
    func test_file_parsing() throws {
        let sut = makeSUT()
        let fileURL = testSources.appendingPathComponent("b.swift.txt")
        let output = OrderedSet(try sut.scanImports(fileURL)
            .map { $0.lastPathComponent })
        let expectedOutput = ["a.swift.txt", "b.swift.txt"]
        
        XCTAssertEqual(output, OrderedSet(expectedOutput))
    }
    
    func test_cascade_parsing() throws {
        let sut = makeSUT()
        let fileURL = testSources.appendingPathComponent("cascade_a.swift.txt")
        let output = try sut.scanImports(fileURL)
            .map {$0.lastPathComponent}
        
        let expectedOutput = [
            "cascade_c.swift.txt",
            "cascade_b.swift.txt",
            "cascade_a.swift.txt"
        ]
        
        XCTAssertEqual(OrderedSet(output), OrderedSet(expectedOutput))
    }
    
    func test_infinite_recursion() throws {
        
        let sut = makeSUT()
        let fileURL = testSources.appendingPathComponent("cyclic_a.swift.txt")
        let output = try sut.scanImports(fileURL).map {$0.lastPathComponent}
        
        let expectedOutput = [
            "cyclic_b.swift.txt",
            "cyclic_a.swift.txt",
        ]
        
        XCTAssertEqual(OrderedSet(output), OrderedSet(expectedOutput))
    }
    
    func test_import_file_inside_folder() throws {
        let sut = makeSUT()
        let fileURL = testSources.appendingPathComponent("nested_import.swift.txt")
        let output = try sut.scanImports(fileURL)
        
        let expectedOutput = [
            "nested/a.swift.txt",
            "nested_import.swift.txt",
        ].map {
            testSources.appendingPathComponent($0)
        }
        
        XCTAssertEqual(output,  OrderedSet(expectedOutput))
    }
    
    func test_import_file_inside_folder_cascade() throws {
        let sut = makeSUT()
        let fileURL = testSources.appendingPathComponent("nested_import_b.swift.txt")
        let output = try sut.scanImports(fileURL)
        
        
        let expectedOutput = [
            "nested/a.swift.txt",
            "nested/b.swift.txt",
            "nested_import_b.swift.txt",
        ].map {
            testSources.appendingPathComponent($0)
        }
        
        XCTAssertEqual(output,  OrderedSet(expectedOutput))
    }
    
    func test_import_whole_folder() throws {
        let sut = makeSUT()
        let fileURL = testSources.appendingPathComponent("import_whole_folder.swift.txt")
        
        let output = try sut.scanImports(fileURL).map { url in
            url.path.components(separatedBy: "/files/").last!
        }
        
        let expectedOutput = [
            "nested/nested/a.swift.txt",
            "nested/b.swift.txt",
            "nested/a.swift.txt",
            "import_whole_folder.swift.txt",
        ]
        
        XCTAssertEqual(OrderedSet(output), OrderedSet(expectedOutput))
    }
}


// MARK: - Helpers
extension FileImporterTests {
    func makeSUT(keyword: String = "import", extension: String = "swift.txt") -> FileImporter {
        FileImporter(keyword: keyword, ext: `extension`)
    }
}


// Tests/Helpers.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 2/6/25.

import Foundation

extension Bundle {
    var testFilesDirectory: URL {
        Bundle.module.resourceURL!.appendingPathComponent("files")
    }
}




// Tests/StringParsingTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 3/6/25.

import XCTest
import Collections
@testable import swiftimport

extension FileImporterTests {
    
    func test_parseImports_handlesStandaloneSwiftFilesImports() {
        let sut = makeSUT()
        let code = """
        import a.swift.txt
        import b.swift.txt
        import some_really_long_named_file.swift.txt
        import cascade_b.swift.txt
        
        let a = B()
        """
        
        let output = sut.parseImports(code)
        let expectedOutput = ["a.swift.txt", "b.swift.txt", "some_really_long_named_file.swift.txt", "cascade_b.swift.txt"]
        
        XCTAssertEqual(output, OrderedSet(expectedOutput))
    }
    
    
    func test_parseImports_handlesNestedSwiftFilesImports() {
        let sut = makeSUT()
        let code = """
        import nested/a.swift.txt
        import nested/b.swift.txt
        
        enum SomeEnum {}
        """
        
        let output = sut.parseImports(code)
        let expectedOutput = ["nested/a.swift.txt", "nested/b.swift.txt"]
        
        XCTAssertEqual(output, OrderedSet(expectedOutput))
    }
    
    func test_parseImports_handlesDirectories() {
        let sut = makeSUT()
        let code = """
        import nested/
        """
        
        let output = sut.parseImports(code)
        let expectedOutput = ["nested/"]
        
        XCTAssertEqual(output, OrderedSet(expectedOutput))
    }
}

