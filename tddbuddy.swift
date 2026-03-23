
// Package.swift
// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TddBuddy",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .target(name: "Core"),
        
        .executableTarget(
            name: "tddbuddy",
            dependencies: [
                "Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "CoreE2ETests", dependencies: ["Core", "tddbuddy"], resources: [.copy("inputs")])
    ]
)


// Sources/Core/Infrastructure/FileManager+FileReader.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import Foundation

extension FileManager: FileReader {
    public func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}


// Sources/Core/Infrastructure/FilePersistor.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.
import Foundation

public class FilePersistor: Persistor {
    public init() {}
    public func persist(_ string: String, outputURL: URL) throws {
        try string.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}


// Sources/Core/Infrastructure/OllamaClient.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.


import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OllamaClient: Client {
    private let model = "llama3.2"
    private let url = "http://localhost:11434/api/chat"
    public init() {}
    public func send(messages: [Message]) async throws -> String {
        let url = URL(string: url)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try makeBody(messages)
        //request.timeoutInterval = 10
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(Response.self, from: data).message.content
    }
    
    private func makeBody(_ messages: [Message]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": messages,
            "stream": false
        ], options: [])
    }

    struct Response: Decodable {
        let message: Message
        // MARK: - Message
        struct Message: Decodable {
            let role: String
            let content: String
        }
    }
}


// Sources/Core/Infrastructure/SwiftRunner.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import Foundation

public struct SwiftRunner: Runner {
    private let fm = FileManager.default
    public init() {}
    public typealias ProcessOutput = (stdout: String, stderr: String, exitCode: Int)
    public func run(_ code: String) throws -> ProcessOutput {
        let tmpURL = fm.temporaryDirectory.appendingPathComponent("generated.swift")
        try code.write(to: tmpURL, atomically: true, encoding: .utf8)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", tmpURL.path]
        
        let stdOutPipe = Pipe()
        let stdErrPipe = Pipe()
        process.standardOutput = stdOutPipe
        process.standardError = stdErrPipe
        
        try process.run()
        process.waitUntilExit()
        
        let stdOutData = stdOutPipe.fileHandleForReading.readDataToEndOfFile()
        let stdErrData = stdErrPipe.fileHandleForReading.readDataToEndOfFile()
        
        return (
            stdout: String(data: stdOutData, encoding: .utf8) ?? "",
            stderr: String(data: stdErrData, encoding: .utf8) ?? "",
            exitCode: Int(process.terminationStatus)
        )
    }
}


// Sources/Core/IO/FileReader.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.


import Foundation

public protocol FileReader {
    func read(_ url: URL) throws -> String
}

// Sources/Core/IO/Iterator.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

public class Iterator {
    public init() {}
    public func iterate<T>(nTimes n: Int, until condition: (T) -> Bool, action: () async throws -> T) async throws -> T {
        var results = [T]()
        while results.count < n {
            let result = try await action()
            if condition(result) { return result }
            results.append(result)
        }
        return results.first!
    }
}


// Sources/Core/IO/Persistor.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.


import Foundation

public protocol Persistor {
    func persist(_ string: String, outputURL: URL) throws
}

// Sources/Core/Main/Client.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.


public protocol Client {
    typealias Message = [String: String]
    func send(messages: [Message]) async throws -> String
}


// Sources/Core/Main/Coordinator.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import Foundation

public class Coordinator {
    
    public typealias Output = (generatedCode: String, procesOutput: Runner.ProcessOutput)
   
    private let reader: FileReader
    private let client: Client
    private let runner: Runner
    private let persistor: Persistor
    private let iterator = Iterator()
    public init(
        reader: FileReader,
        client: Client,
        runner: Runner,
        persistor: Persistor
    ) {
        self.reader = reader
        self.client = client
        self.runner = runner
        self.persistor = persistor
    }
   
    @discardableResult
    public func generateAndSaveCode(systemPrompt: String, specsFileURL: URL, outputFileURL: URL, maxIterationCount: Int = 1) async throws -> Output {
        let specs = try reader.read(specsFileURL)
        var previousOutput: Output?
        let output = try await iterator.iterate(
            nTimes: maxIterationCount,
            until: { previousOutput = $0 ; return isSuccess($0) }
        ) {
            try await self.generateCode(systemPrompt: systemPrompt, from: specs, previous: previousOutput)
        }
        
        try persistor.persist(output.generatedCode, outputURL: outputFileURL)
        return output
    }
    
    private func generateCode(systemPrompt: String, from specs: String, previous: Output?) async throws -> Output {
        var messages: [Client.Message] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": specs]
        ]
        
        if let previous {
            messages.append([
                "role": "assistant",
                "content": "failed attempt.\ncode:\(previous.generatedCode)\nerror:\(previous.procesOutput.stderr)"
            ])
        }
        let generated = try await client.send(messages: messages)
        let concatenated = generated + "\n" + specs
        let processOutput = try runner.run(concatenated)
        return (generated, processOutput)
    }
    
    private func isSuccess(_ o: Output) -> Bool { o.procesOutput.exitCode == 0 }
}


// Sources/Core/Main/Runner.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.


public protocol Runner {
    typealias ProcessOutput = (stdout: String, stderr: String, exitCode: Int)
    func run(_ code: String) throws -> ProcessOutput
}


// Sources/tddbuddy/Logging.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.
import Foundation
import Core

#if canImport(os)
import os
#endif

enum Logger {
    #if canImport(os)
    static let logger = os.Logger(subsystem: "me.crisfe.tddbuddy.cli", category: "core")
    #endif
    static func info(_ message: String) {
        #if canImport(os)
        logger.info("\(message, privacy: .public)")
        #else
        print(message)
        #endif
    }
}

public final class LoggerDecorator<T> {
    let decoratee: T
    
    public init(_ decoratee: T) {
        self.decoratee = decoratee
    }
}


// MARK: - Runner
extension LoggerDecorator: Runner where T: Runner {
    public func run(_ code: String) throws -> ProcessOutput {
        try decoratee.run(code)
    }
}

// MARK: - Persistor
extension LoggerDecorator: Persistor where T: Persistor {
    public func persist(_ string: String, outputURL: URL) throws {
        try decoratee.persist(string, outputURL: outputURL)
        Logger.info("📍 Output saved to \(outputURL.path):")
    }
}

// MARK: - FileReader
extension LoggerDecorator: FileReader where T: FileReader {
    public func read(_ url: URL) throws -> String {
        let contents = try decoratee.read(url)
        return contents
    }
}


// Sources/tddbuddy/TddBuddy.swift
// main.swift
import Foundation
import ArgumentParser
import Core

@main
struct TDDBuddy: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Custom system prompt to use instead of the default.")
    var prompt: String?
    
    @Option(name: .shortAndLong, help: "The path to the specs file.")
    var input: String

    @Option(name: .shortAndLong, help: "The path where the generated code will be saved.")
    var output: String

    @Option(name: .shortAndLong, help: "Maximum number of iterations (default is 5).")
    var iterations: Int = 5

    func run() async throws {
        let client = OllamaClient()
        let runner = LoggerDecorator(SwiftRunner())
        let persistor = LoggerDecorator(FilePersistor())

        let coordinator = Coordinator(
            reader: FileManager.default,
            client: client,
            runner: runner,
            persistor: persistor
        )

        let inputURL = URL(fileURLWithPath: input)
        let outputURL = URL(fileURLWithPath: output)

        let result = try await coordinator.generateAndSaveCode(
            systemPrompt: prompt ?? TDDBuddy.systemPrompt,
            specsFileURL: inputURL,
            outputFileURL: outputURL,
            maxIterationCount: iterations
        )
        
        result.procesOutput.exitCode != 0
        ? Logger.info("❌ Code generated didn't meet the specs")
        : ()
        
    }
}

private extension TDDBuddy {
    static let systemPrompt = """
        Imagine that you are a programmer and the user's responses are feedback from compiling your code in your development environment. Your responses are the code you write, and the user's responses represent the feedback, including any errors.
        
        Implement the SUT's code in Swift based on the provided specs (unit tests).
        
        Follow these strict guidelines:
        
        1. Provide ONLY runnable Swift code. No explanations, comments, or formatting (no code blocks, markdown, symbols, or text).
        2. DO NOT include unit tests or any test-related code.
        3. ALWAYS IMPORT ONLY Foundation. No other imports are allowed.
        4. DO NOT use access control keywords (`public`, `private`, `internal`) or control flow keywords in your constructs.
        
        If your code fails to compile, the user will provide the error output for you to make adjustments.
        """
}


// Tests/CoreE2ETests/IntegrationTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core
import tddbuddy

class IntegrationTests: XCTestCase {
    func test_adder_generation() async throws {
        let systemPrompt = """
            Imagine that you are a programmer and the user's responses are feedback from compiling your code in your development environment. Your responses are the code you write, and the user's responses represent the feedback, including any errors.
            
            Implement the SUT's code in Swift based on the provided specs (unit tests).
            
            Follow these strict guidelines:
            
            1. Provide ONLY runnable Swift code. No explanations, comments, or formatting (no code blocks, markdown, symbols, or text).
            2. DO NOT include unit tests or any test-related code.
            3. ALWAYS IMPORT ONLY Foundation. No other imports are allowed.
            4. DO NOT use access control keywords (`public`, `private`, `internal`) or control flow keywords in your constructs.
            
            If your code fails to compile, the user will provide the error output for you to make adjustments.
            """
        let reader = FileManager.default
        let client = OllamaClient()
        let runner = LoggerDecorator(SwiftRunner())
        let persistor = LoggerDecorator(FilePersistor())
        let sut = Coordinator(
            reader: reader,
            client: client,
            runner: runner,
            persistor: persistor
        )
        let adderSpecs = specsURL("adder.swift.txt")
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("adder.swift.txt")
        let output = try await sut.generateAndSaveCode(systemPrompt: systemPrompt, specsFileURL: adderSpecs, outputFileURL: tmpURL, maxIterationCount: 5)
        
        XCTAssertFalse(output.generatedCode.isEmpty)
        XCTAssertEqual(output.procesOutput.exitCode, 0)
    }
    
    func specsURL(_ filename: String) -> URL {
        inputFolder().appendingPathComponent(filename)
    }
    
    func testsResourceDirectory() -> URL {
        Bundle.module.bundleURL.appendingPathComponent("Contents/Resources")
    }
    
    func inputFolder() -> URL {
        testsResourceDirectory().appendingPathComponent("inputs")
    }
}


// Tests/CoreE2ETests/OllamaClientTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Foundation
import Core

class OllamaClientTests: XCTestCase {
    
    func test_send_withRunningOllamaServer_returnsContent() async throws {
        let sut = OllamaClient()
        let response = try await sut.send(messages: [["role": "user", "content": "hello"]])
        XCTAssert(!response.isEmpty)
    }
}


// Tests/CoreTests/Infrastructure/FilePersistorTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core

class FilePersistorTests: XCTestCase {
    
    override func setUp() {
        setupEmptyState()
    }
    
    override func tearDown() {
        cleanTestsArtifacts()
    }
    
    func test_persist_savesStringToDisk() throws {
        let sut = FilePersistor()
        try sut.persist("any string", outputURL: temporaryFileURL())
        XCTAssertEqual(try String(contentsOf: temporaryFileURL(), encoding: .utf8), "any string")
    }
    
    func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("output.txt")
    }
    
    func cleanTestsArtifacts() {
        try? removeTemporyFile()
    }
    
    func setupEmptyState() {
       try? removeTemporyFile()
    }
    
    func removeTemporyFile() throws {
        try FileManager.default.removeItem(at: temporaryFileURL())
    }
}


// Tests/CoreTests/Infrastructure/FileReaderTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core

class FileReaderTests: XCTestCase {
    override func setUp() {
        setupEmptyState()
    }
    
    override func tearDown() {
        cleanTestsArtifacts()
    }
    
    func test_read_readsFileWhenExists() throws {
        let sut = FileManager.default
        let stringToWrite = "Hello, world!"
        try stringToWrite.write(to: temporaryFileURL(), atomically: true, encoding: .utf8)
        let content = try sut.read(temporaryFileURL())
        XCTAssertEqual(stringToWrite, content)
    }
    
    func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("output.txt")
    }
    
    func cleanTestsArtifacts() {
        try? removeTemporyFile()
    }
    
    func setupEmptyState() {
       try? removeTemporyFile()
    }
    
    func removeTemporyFile() throws {
        try FileManager.default.removeItem(at: temporaryFileURL())
    }
}


// Tests/CoreTests/Infrastructure/SwiftRunnerTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core

class SwiftRunnerTests: XCTestCase {
    
    func test_run_deliversRunsCode() throws {
        let sut = SwiftRunner()
        let swiftCode = #"print("hello world")"#
        let processOutput = try sut.run(swiftCode)
        let expectedStdout = "hello world\n"
        let expectedStderr = ""
        let expectedExitCode = 0
        
        XCTAssertEqual(processOutput.stdout, expectedStdout)
        XCTAssertEqual(processOutput.stderr, expectedStderr)
        XCTAssertEqual(processOutput.exitCode, expectedExitCode)
    }
}


// Tests/CoreTests/IO/IteratorTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.


import XCTest
import Core



class IteratorTests: XCTestCase {
    
    func test_iterator_iteratesNtimes() async throws {
        let sut = Iterator()
        var iterationCount = 0
        try await sut.iterate(
            nTimes: 5,
            until: neverFullfillsCondition,
            action: { iterationCount += 1 }
        )
        XCTAssertEqual(iterationCount, 5)
    }
    
    func test_iterator_stopsWhenConditionIsMet() async throws {
        let sut = Iterator()
        var iterationCount = 0
        try await sut.iterate(
            nTimes: 5,
            until: { iterationCount == 1 },
            action: { iterationCount += 1 })
        XCTAssertEqual(iterationCount, 1)
    }
    
    private func neverFullfillsCondition() -> Bool { false }
}


// Tests/CoreTests/UseCases/CodeGenerationUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.

import Core

extension CoordinatorTests {
    func test_generateAndSaveCode_deliversErrorOnClientError() async throws {
        let client = ClientStub(result: .failure(anyError()))
        let coordinatior = makeSUT(client: client)
        
        await XCTAssertThrowsErrorAsync(
            try await coordinatior.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }
    
    func test_generateAndSaveCode_deliversNoErrorOnClientSuccess() async throws {
        let client = ClientStub(result: .success("any genereted code"))
        let sut = makeSUT(client: client)
        await XCTAssertNoThrowAsync(
            try await sut.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }
    
    private func makeSUT(client: Client) -> Coordinator {
        Coordinator(
            reader: FileReaderDummy(),
            client: client,
            runner: RunnerDummy(),
            persistor: PersistorDummy()
        )
    }
}


// Tests/CoreTests/UseCases/CoordinatorTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core

class CoordinatorTests: XCTestCase {    
    
    func test_generateAndSaveCode_usesConcatenatedCodeAsRunnerInputInTheRightOrder() async throws {
        class RunnerSpy: Runner {
            var code: String?
            func run(_ code: String) throws -> Runner.ProcessOutput {
                self.code = code
                return ("", "", 0)
            }
        }
        
        let readerStub = FileReaderStub(result: .success(anySpecs()))
        let clientStub = ClientStub(result: .success(anyGeneratedCode()))
        let runnerSpy = RunnerSpy()
        
        let sut = makeSUT(reader: readerStub, client: clientStub, runner: runnerSpy)
        try await sut.generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL()
        )
        
        XCTAssertEqual(runnerSpy.code, "\(anyGeneratedCode())\n\(anySpecs())")
    }
   
    func test_generateAndSaveCode_sendsContentsOfReadFileToClient() async throws {
        let reader = FileReaderStub(result: .success(anyString()))
        let clientSpy = ClientSpy()
        let sut = makeSUT(reader: reader, client: clientSpy)
        
        try await sut.generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL()
        )
        
        let expectedMessages = [
            ["role": "system", "content": anySystemPrompt()],
            ["role": "user", "content": anyString()]
        ]
        XCTAssertEqual(clientSpy.messages, [expectedMessages])
    }
    
    func test_generateAndSaveCode_persistsGeneratedCode() async throws {
        class PersistorSpy: Persistor {
            var persistedString: String?
            func persist(_ string: String, outputURL: URL) throws {
                persistedString = string
            }
        }
        
        let clientStub = ClientStub(result: .success(anyGeneratedCode()))
        let persistorSpy = PersistorSpy()
        
        let sut = makeSUT(client: clientStub, persistor: persistorSpy)
        
        try await sut.generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL()
        )
        
        XCTAssertEqual(persistorSpy.persistedString, anyGeneratedCode())
    }
    
    func test_generateAndSaveCode_retriesUntilMaxIterationWhenProcessFails() async throws {
        let clientStub = ClientStub(result: .success(anyGeneratedCode()))
        let runnerStub = RunnerStubResults(results: [
            anyFailedProcessOutput(),
            anyFailedProcessOutput(),
            anyFailedProcessOutput()
        ])
        
        let sut = makeSUT(client: clientStub, runner: runnerStub)
        try await sut.generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL(),
            maxIterationCount: 3
        )
        
        XCTAssertEqual(runnerStub.results.count, 0)
    }
    
    func test_generateAndSaveCode_retiresUntilSucessWhenProcessSucceedsAfterNRetries() async throws {
        let clientStub = ClientStub(result: .success(anyGeneratedCode()))
        let runnerStub = RunnerStubResults(results: [
            anyFailedProcessOutput(),
            anyFailedProcessOutput(),
            anyFailedProcessOutput(),
            anySuccessProcessOutput()
        ])

       try await makeSUT(client: clientStub, runner: runnerStub).generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL(),
            maxIterationCount: 5
        ) .* {
            XCTAssertEqual($0.generatedCode, anyGeneratedCode())
            XCTAssertEqual($0.procesOutput.stderr, anySuccessProcessOutput().stderr)
            XCTAssertEqual($0.procesOutput.stdout, anySuccessProcessOutput().stdout)
            XCTAssertEqual($0.procesOutput.exitCode, anySuccessProcessOutput().exitCode)
        }
        
        XCTAssertEqual(runnerStub.results.count, 0)
    }

    
    func test_generateAndSaveCode_buildsMessagesWithPreviousFeedbackWhenIterationFails() async throws {
        let reader = FileReaderStub(result: .success(anySpecs()))
        let client = ClientSpy()
        let runner = RunnerStub(result: .success(anyFailedProcessOutput()))
        let sut = makeSUT(reader: reader, client: client, runner: runner)
        
        let _ = try await sut.generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL(),
            maxIterationCount: 2
        )
        
        let expectedMessages = [
            ["role": "system", "content": anySystemPrompt()],
            ["role": "user", "content": anySpecs()],
            ["role": "assistant", "content": "failed attempt.\ncode:\(anyGeneratedCode())\nerror:\(anyFailedProcessOutput().stderr)"]
        ]
        
        XCTAssertEqual(client.messages.last?.normalized(), expectedMessages.normalized())
        
    }
    private func makeSUT(
        reader: FileReader = FileReaderDummy(),
        client: Client = ClientDummy(),
        runner: Runner = RunnerDummy(),
        persistor: Persistor = PersistorDummy()
    ) -> Coordinator {
        Coordinator(
            reader: reader,
            client: client,
            runner: runner,
            persistor: persistor
        )
    }
}

private extension [[String: String]] {
    func normalized() -> [NSDictionary] {
        map { $0 as NSDictionary }
    }
}


// Tests/CoreTests/UseCases/Helpers/CoordinatorTests+Asserts.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.


import XCTest

extension CoordinatorTests {
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "Expected no error, but error was thrown",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail(message(), file: file, line: line)
        }
    }
    
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown, but no error was thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}


// Tests/CoreTests/UseCases/Helpers/CoordinatorTests+Asterisk.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/5/25.

infix operator .*: AdditionPrecedence

@discardableResult
func .*<T>(lhs: T, rhs: (inout T) -> Void) -> T {
  var copy = lhs
  rhs(&copy)
  return copy
}


// Tests/CoreTests/UseCases/Helpers/CoordinatorTests+Helpers.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.

import Foundation
import Core

extension CoordinatorTests {
    
    func anyURL() -> URL {
        URL(string: "http://any-url.com")!
    }
    
    func anyError() -> NSError {
        NSError(domain: "", code: 0)
    }
    
    func anyGeneratedCode() -> String {
        "any generated code"
    }
    
    func anyString() -> String {
        "any string"
    }
    
    func anySystemPrompt() -> String {
        "any system prompt"
    }
    
    func anySpecs() -> String {
        "any specs"
    }
    
    func anySuccessProcessOutput() -> Runner.ProcessOutput {
        ("", "", 0)
    }
    
    private static var failedExitCode: Int { 1 }
    func anyFailedProcessOutput() -> Runner.ProcessOutput {
        (stdout: "", stderr: "any stderr error", exitCode: Self.failedExitCode)
    }
}


// Tests/CoreTests/UseCases/Helpers/CoordinatorTests+Mocks.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.

import Foundation
import Core


// Stubs
extension CoordinatorTests {
    struct RunnerStub: Runner {
        let result: Result<ProcessOutput, Error>
        func run(_ code: String) throws -> ProcessOutput {
            try result.get()
        }
    }
    
    class RunnerStubResults: Runner {
        var results = [ProcessOutput]()
        
        init(results: [ProcessOutput]) {
            self.results = results
        }
        
        func run(_ code: String) throws -> ProcessOutput {
            results.removeFirst()
        }
    }
    
    struct FileReaderStub: FileReader {
        let result: Result<String, Error>
        func read(_: URL) throws -> String {
            try result.get()
        }
    }
    
    struct PersistorStub: Persistor {
        let result: Result<Void, Error>
        func persist(_ string: String, outputURL: URL) throws {
            try result.get()
        }
    }
    
    struct ClientStub: Client {
        let result: Result<String, Error>
        func send(messages: [Message]) async throws -> String {
            try result.get()
        }
    }
}


// Dummies
extension CoordinatorTests {
    
    struct PersistorDummy: Persistor {
        func persist(_ string: String, outputURL: URL) throws {
        }
    }
    
    struct ClientDummy: Client {
        func send(messages: [Message]) async throws -> String {
            ""
        }
    }
    
    struct RunnerDummy: Runner {
        func run(_ code: String) throws -> ProcessOutput {
            (stdout: "", stderr: "", exitCode: 0)
        }
    }
    
    struct FileReaderDummy: FileReader {
        func read(_ url: URL) throws -> String {
            ""
        }
    }
}

// MARK: - Spies
extension CoordinatorTests {
    class ClientSpy: Client {
        var messages = [[Message]]()
        func send(messages: [Message]) async throws -> String {
            self.messages.append(messages)
            return "any generated code"
        }
    }
}


// Tests/CoreTests/UseCases/PersistUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.

// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core

extension CoordinatorTests {
    
    func test_generateAndSaveCode_deliversErrorOnPersistenceError() async throws {
        let persistor = PersistorStub(result: .failure(anyError()))
        let sut = makeSUT(persistor: persistor)
        await XCTAssertThrowsErrorAsync(
            try await sut.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }
    
    func test_generateAndSaveCode_deliversNoErrorOnPersistenceSuccess() async throws {
        let persistor = PersistorStub(result: .success(()))
        let sut = makeSUT(persistor: persistor)
        await XCTAssertNoThrowAsync(
            try await sut.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }

    private func makeSUT(persistor: Persistor) -> Coordinator {
        Coordinator(
            reader: FileReaderDummy(),
            client: ClientDummy(),
            runner: RunnerDummy(),
            persistor: persistor
        )
    }
}


// Tests/CoreTests/UseCases/ReadFileUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.

import XCTest
import Core

extension CoordinatorTests {
    
    func test_generateAndSaveCode_deliversErrorOnReaderError() async throws {
        let reader = FileReaderStub(result: .failure(anyError()))
        let sut = makeSUT(reader: reader)
        
        await XCTAssertThrowsErrorAsync(
            try await sut.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }
    
    func test_generateAndSaveCode_deliversNoErrorOnReaderSuccess() async throws {
        let reader = FileReaderStub(result: .success(""))
        let sut = makeSUT(reader: reader)
        
        await XCTAssertNoThrowAsync(
            try await sut.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }
    
    // MARK: - Helpers
    private func makeSUT(reader: FileReader) -> Coordinator {
        Coordinator(
            reader: reader,
            client: ClientDummy(),
            runner: RunnerDummy(),
            persistor: PersistorDummy()
        )
    }
}


// Tests/CoreTests/UseCases/RunCodeUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 26/5/25.

// © 2025  Cristian Felipe Patiño Rojas. Created on 9/5/25.

import XCTest
import Core

extension CoordinatorTests {
  
    func test_generateAndSaveCode_deliversErrorOnRunnerError() async throws {
        let runner = RunnerStub(result: .failure(anyError()))
        let sut = makeSUT(runner: runner)
        await XCTAssertThrowsErrorAsync(
            try await sut.generateAndSaveCode(
                systemPrompt: anySystemPrompt(),
                specsFileURL: anyURL(),
                outputFileURL: anyURL()
            )
        )
    }
    
    func test_generateAndSaveCode_deliversOutputOnRunnerSuccess() async throws {
        let runner = RunnerStub(result: .success(anySuccessProcessOutput()))
        let sut = makeSUT(runner: runner)
        let result = try await sut.generateAndSaveCode(
            systemPrompt: anySystemPrompt(),
            specsFileURL: anyURL(),
            outputFileURL: anyURL()
        )
        
        let output = result.procesOutput
        anySuccessProcessOutput() .* { expected in
            XCTAssertEqual(output.stderr, expected.stderr)
            XCTAssertEqual(output.stdout, expected.stdout)
            XCTAssertEqual(output.exitCode, expected.exitCode)
        }
    }
    
    
    private func makeSUT(runner: Runner) -> Coordinator {
        Coordinator(
            reader: FileReaderDummy(),
            client: ClientDummy(),
            runner: runner,
            persistor: PersistorDummy()
        )
    }
}

