
// Package.swift
// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChronoLock",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "ChronoLock",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "ChronoLockTests", dependencies: ["ChronoLock"])
    ]
)


// Sources/ChronoLock.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 31/5/25.

import Foundation

public struct ChronoLock {
    public protocol Encryptor {
        func encrypt<T: Codable>(_ codableObject: T) throws -> Data
    }
    
    public protocol Decryptor {
        func decrypt<T: Decodable>(_ data: Data) throws -> T
    }
    
    public protocol Reader {
        func read(_ fileURL: URL) throws -> Data
    }
    
    public protocol Persister {
        func save(_ data: Data, at outputURL: URL) throws
        func save(_ content: String, at outputURL: URL) throws
    }
    
    public enum Error: Swift.Error, Equatable {
        case alreadyEllapsedDate
        case nonEllapsedDate(TimeInterval)
        case invalidData
    }
    
    let encryptor: Encryptor
    let decryptor: Decryptor
    let reader: Reader
    let persister: Persister
    let currentDate: () -> Date
    
    public init(encryptor: Encryptor, decryptor: Decryptor, reader: Reader, persister: Persister, currentDate: @escaping () -> Date) {
        self.encryptor = encryptor
        self.decryptor = decryptor
        self.reader = reader
        self.persister = persister
        self.currentDate = currentDate
    }
    
   public func encrypt(_ content: String, until date: Date) throws -> Data {
       guard date > currentDate() else { throw Error.alreadyEllapsedDate }
        let item = Item(unlockDate: date, content: content)
        return try encryptor.encrypt(item)
    }
    
    public func decrypt(_ data: Data) throws -> String {
        let decrypted: Item = try decryptor.decrypt(data)
        let now = currentDate()
        guard decrypted.unlockDate <= now else {
            let remaining = decrypted.unlockDate.timeIntervalSince(now)
            throw Error.nonEllapsedDate(remaining)
        }
        return decrypted.content
    }
    
    public struct Item: Codable {
        let unlockDate: Date
        let content: String
        
        public init(unlockDate: Date, content: String) {
            self.unlockDate = unlockDate
            self.content = content
        }
    }
}

// MARK: - I/O
// Infrastructure:
extension Encryptor: ChronoLock.Decryptor {}
extension Encryptor: ChronoLock.Encryptor {}

extension FileManager: ChronoLock.Reader {
    public func read(_ fileURL: URL) throws -> Data {
        try Data(contentsOf: fileURL)
    }
}

extension FileManager: ChronoLock.Persister {
    public func save(_ data: Data, at outputURL: URL) throws {
        try data.write(to: outputURL, options: .atomic)
    }
    
    public func save(_ content: String, at outputURL: URL) throws {
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}

// Coordinator logic:
extension ChronoLock {
   public func encryptAndSave(file inputURL: URL, until date: Date, outputURL: URL) throws {
        let data = try reader.read(inputURL)
        guard let content = String(data: data, encoding: .utf8) else {
            throw Error.invalidData
        }
        let encrypted = try encrypt(content, until: date)
        try persister.save(encrypted, at: outputURL)
    }
}

extension ChronoLock {
    public func decryptAndSave(file fileURL: URL, at outputURL: URL) throws {
        let data = try reader.read(fileURL)
        let decrypted = try decrypt(data)
        try persister.save(decrypted, at: outputURL)
        
    }
}



// Sources/CLI.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 31/5/25.

import ArgumentParser
import Foundation


@main
public struct ChronoLockCLI: ParsableCommand {
    @Option(name: .shortAndLong, help: "Path to input file to encrypt")
    var input: String?
    
    @Option(name: .shortAndLong, help: "Path to output file")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Unlock date (ISO8601)")
    var unlockDate: String?
    
    @Option(name: .shortAndLong, help: "Decrypt mode")
    var mode: Mode?
    
    public var config: Config?
    public init() {}
    
    public struct NonEllapsedDateError: Error {
       public let message: String
    }
    
    public mutating func run() throws {
        let system = Self.makeChronoLock(passphrase: "some really long passphrase", currentDate: config?.currentDate ?? Date.init)
        
        guard let output else {
            throw ValidationError("Missing output path")
        }
        
        guard let input else {
            throw ValidationError("Missing input file for decryption")
        }
        
        switch mode {
        case .decrypt:  try handleDecryption(with: system, i: input, o: output)
        case .encrypt:  try handleEncryption(with: system, i: input, o: output)
        case .none: throw ValidationError("Missing mode. Mode needs to be specified")
        }
    }
}

// MARK: - Helpers
public enum DateParser {
    public static func parse(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current

        guard let date = formatter.date(from: string) else {
            throw ValidationError("Invalid date format. Use yyyy-MM-dd")
        }

        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: formatter.timeZone!, from: date)
        components.hour = 12
        components.minute = 0
        components.second = 0

        return calendar.date(from: components)!
    }
    
    public static func timeIntervalAsString( _ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        return String(format: "%02dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    }

    private static func calendarMiddayReference() -> Date {
        var components = DateComponents()
        components.hour = 12
        components.minute = 0
        components.second = 0
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}

extension String {
    public static func unreachedDate(_ remaining: String) -> String {
        "Unlock date non reached. Remaining \(remaining)"
    }
}
private extension ChronoLockCLI {
    
    func handleDecryption(with system: ChronoLock, i inputPath: String, o outputPath: String) throws {
        do {
            try system.decryptAndSave(
                file: URL(fileURLWithPath: inputPath),
                at: URL(fileURLWithPath: outputPath)
            )
            print("🔓 Decrypted to \(outputPath)")
        } catch  {
            switch (error as? ChronoLock.Error) {
            case .nonEllapsedDate(let timeInterval):
                let formatted = DateParser.timeIntervalAsString(timeInterval)
                throw NonEllapsedDateError(message: formatted)
            default: throw ValidationError("Decryption error")
            }
        }
    }
    
    func handleEncryption(with system: ChronoLock, i inputPath: String, o outputPath: String) throws {
        guard let unlockDate else {
            throw ValidationError("Missing unlock date")
        }
        let date = try DateParser.parse(unlockDate)
        try system.encryptAndSave(
            file: URL(fileURLWithPath: inputPath),
            until: date,
            outputURL: URL(fileURLWithPath: outputPath)
        )
        print("🔒 Encrypted until \(date) at \(outputPath)")
    }

    static func makeChronoLock(passphrase: String, currentDate: @escaping () -> Date) -> ChronoLock {
        ChronoLock(
            encryptor: Encryptor(passphrase: passphrase),
            decryptor: Encryptor(passphrase: passphrase),
            reader: FileManager.default,
            persister: FileManager.default,
            currentDate: currentDate
        )
    }
}

extension ChronoLockCLI {
    enum Mode: String, ExpressibleByArgument, Decodable {
        case decrypt
        case encrypt
        init?(argument: String) {
            self.init(rawValue: argument)
        }
    }
    
    public struct Config {
        var currentDate: (() -> Date)?
        public init(currentDate: (() -> Date)? = nil) {self.currentDate = currentDate}
    }
}


extension ChronoLockCLI.Config: Decodable {
    public init(from decoder: any Decoder) throws {
        self = Self()
    }
    
}


// Sources/Encryptor.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import CryptoKit
import Foundation

public struct Encryptor {
    private let passphrase: String
    
    public init(passphrase: String) {
        self.passphrase = passphrase
    }
    
    private var key: SymmetricKey {
        let keyData = SHA256.hash(data: Data(passphrase.utf8))
        return SymmetricKey(data: keyData)
    }

    public func encrypt<T: Encodable>(_ codableObject: T) throws -> Data {
        let encoded = try JSONEncoder().encode(codableObject)
        let sealedBox = try AES.GCM.seal(encoded, using: key)
        guard let combined = sealedBox.combined else {
            throw CombinedEncodingError()
        }
        return combined
    }
    
    struct CombinedEncodingError: Error {}
    
    public func decrypt<T: Decodable>(_ data: Data) throws -> T {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let data = try AES.GCM.open(sealedBox, using: key)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return decoded
    }
}


// Tests/CLITests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 31/5/25.
import XCTest
import ChronoLock

class CLITests: XCTestCase {
    func test_cliEncryptsAndDecryptsSucceeds_onEllapsedDate() throws {
        
        let inputURL = uniqueTemporaryURL()
        try "some secret content".write(to: inputURL, atomically: true, encoding: .utf8)

        let outputURL = uniqueTemporaryURL()
        let futureDate = "2025-06-01"

        var pastCLI = try ChronoLockCLI.parse([
            "--input", inputURL.path,
            "--output", outputURL.path,
            "--mode", "encrypt",
            "--unlock-date", futureDate
        ])
        
        pastCLI.config = ChronoLockCLI.Config(currentDate: { fixedNow() })
        try pastCLI.run()
        
        
        let decryptedURL = uniqueTemporaryURL()
        var futureCLI = try ChronoLockCLI.parse([
            "--input", outputURL.path,
            "--output", decryptedURL.path,
            "--mode", "decrypt"
        ])
        
        futureCLI.config = ChronoLockCLI.Config(currentDate: { try! DateParser.parse(futureDate) })
        try futureCLI.run()

        XCTAssertEqual(try String(data: Data(contentsOf: decryptedURL), encoding: .utf8), "some secret content")
    }
    
    func test_cliEncryptsAndDecryptsFailsReturningCorrectFormattedTimeInterval_onNonEllapsedUnlockDate() throws {
        
        let inputURL = uniqueTemporaryURL()
        try "some secret content".write(to: inputURL, atomically: true, encoding: .utf8)

        let outputURL = uniqueTemporaryURL()
        let futureDate = "2025-06-01"

        var sut = try ChronoLockCLI.parse([
            "--input", inputURL.path,
            "--output", outputURL.path,
            "--mode", "encrypt",
            "--unlock-date", futureDate
        ])
        
        sut.config = ChronoLockCLI.Config(currentDate: { fixedNow() })
        try sut.run()
        
        
        let decryptedURL = uniqueTemporaryURL()
        sut = try ChronoLockCLI.parse([
            "--input", outputURL.path,
            "--output", decryptedURL.path,
            "--mode", "decrypt"
        ])
        sut.config = ChronoLockCLI.Config(currentDate: { fixedNow() })
        
        XCTAssertThrowsError(try sut.run()) { error in
            
            XCTAssertEqual((error as? ChronoLockCLI.NonEllapsedDateError)?.message, "01d 00h 00m 00s")
        }
    }
    
    func uniqueTemporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
}

private func fixedNow() -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(
        timeZone: TimeZone(identifier: "Europe/Madrid"),
        year: 2025,
        month: 5,
        day: 31,
        hour: 12,
        minute: 0
    ))!
}

private extension Date {
    private func adding(days: Int) -> Date {
        return Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: self)!
    }
}


// Tests/EncryptorTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import XCTest
import ChronoLock

class EncryptorTests: XCTestCase {

    
    func test_encryptAndDecrypt_withCodableObjectAndDifferentPassphrase_failsDecryption() throws {
    
        let itemToEncrypt = AnyCodableObject(message: "any message")
    
        let sut1 = Encryptor(passphrase: "passphrase 1")
        let sut2 = Encryptor(passphrase: "passphrase 2")
        
        let encrypted = try sut1.encrypt(itemToEncrypt)
        XCTAssertThrowsError(try {
            let d: AnyCodableObject = try sut2.decrypt(encrypted)
            return d
        }())
    }
    
    func test_encryptAndDecrypt_withCodableObjectAndSamePassphraseReturnsOriginalObject() throws {
        
        let itemToEncrypt = AnyCodableObject(message: "any message")
        let uniquePassPhraseAcrossInstances = "unique passphrase across instances"
        let sut1 = Encryptor(passphrase: uniquePassPhraseAcrossInstances)
        let sut2 = Encryptor(passphrase: uniquePassPhraseAcrossInstances)
        
        let encrypted = try sut1.encrypt(itemToEncrypt)
        let decrypted: AnyCodableObject = try sut2.decrypt(encrypted)
        
        XCTAssertEqual(decrypted, itemToEncrypt)
    }
}

private extension EncryptorTests {
    struct AnyCodableObject: Codable, Equatable {
        let message: String
    }
}


// Tests/IntegrationTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import XCTest
import ChronoLock



class IntegrationTests: XCTestCase {
    func test_decrypt_deliversDecryptedMessageOnAlreadyEllapsedDate() throws {
        let timestamp = Date()
        let nonEllapsedDate = timestamp.adding(seconds: 10)
        let pastSUT = makeSUT(currentDate: {timestamp})
        let encrypted = try pastSUT.encrypt("any message to encrypt", until: nonEllapsedDate)
        
        let futureSUT = makeSUT(currentDate: {nonEllapsedDate})
        let decryptedMessage = try futureSUT.decrypt(encrypted)
        XCTAssertEqual(decryptedMessage, "any message to encrypt")
    }

    func test_decrypt_failsOnInvalidData() throws {
        let sut = makeSUT()
        let invalidData = Data()
        XCTAssertThrowsError(try sut.decrypt(invalidData))
    }
    
    func test_encryptAndSave_thenDecryptAndSave_restoresOriginalFileContent() throws {
       
        let inputURL = makeTemporaryAleatoryURL()
        let content = "some password"
        try content.write(to: inputURL, atomically: true, encoding: .utf8)
        
        let outputURL = makeTemporaryAleatoryURL()
        
        let timestamp = Date()
        let futureDate = timestamp.adding(seconds: 60)
        let pastSUT = makeSUT(currentDate: {timestamp})
        
        try pastSUT.encryptAndSave(
            file: inputURL,
            until: futureDate,
            outputURL: outputURL
        )
        
        let futureSUT = makeSUT(currentDate: {futureDate})
        
        let decryptedURL = makeTemporaryAleatoryURL()
        try futureSUT.decryptAndSave(file: outputURL, at: decryptedURL)
        let decrypted = try String(data: Data(contentsOf: decryptedURL), encoding: .utf8)
        XCTAssertEqual(decrypted, content)
    }
    
    func test_decrypt_deliversRemainingCountOnNonEllapsedDate() throws {
        let timestamp = Date()
        let nonEllapsedDate = timestamp.adding(seconds: 1)
        let sut = makeSUT(currentDate: { timestamp })
        let encrypted = try sut.encrypt("any message to encrypt", until: nonEllapsedDate)
        XCTAssertThrowsError(try sut.decrypt(encrypted)) { error in
            switch (error as? ChronoLock.Error) {
            case .nonEllapsedDate(let remainingTimeInterval):
                let expectedTimeInterval = nonEllapsedDate.timeIntervalSince(timestamp)
                XCTAssertEqual(remainingTimeInterval, expectedTimeInterval)
            default: XCTFail("Expected NonEllapsedDateError, got \(error) instead")
            }
        }
    }
}

private extension IntegrationTests {
    
    func makeSUT(currentDate: @escaping () -> Date = Date.init) -> ChronoLock {
        ChronoLock(
            encryptor: Encryptor(passphrase: "any passphrase"),
            decryptor: Encryptor(passphrase: "any passphrase"),
            reader: FileManager.default,
            persister: FileManager.default,
            currentDate: currentDate
        )
    }
    
    func makeTemporaryAleatoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
}


// Tests/UseCases/DecryptionUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import ChronoLock
import Foundation
import XCTest


extension ChronoLockTests {
    
    func test_decrypt_deliversErrorOnDecryptorError() throws {
        
        struct DecryptorStub: ChronoLock.Decryptor {
            let error: Error
            func decrypt<T: Decodable>(_ data: Data) throws -> T {
               throw error
            }
        }
        
        let decryptor = DecryptorStub(error: anyError())
        
        let sut = makeSUT(decryptor: decryptor)
        let anyEncryptedData = Data()
        XCTAssertThrowsError(try sut.decrypt(anyEncryptedData))
    }

    
    func test_decrypt_deliversErrorOnNonEllapsedDate() throws {
        let timestamp = Date()
        let nonEllapsedDate = timestamp.adding(seconds: 1)
        let sut = makeSUT(currentDate: { timestamp })
        let encrypted = try sut.encrypt("any message to encrypt", until: nonEllapsedDate)
        XCTAssertThrowsError(try sut.decrypt(encrypted)) { error in
            switch (error as? ChronoLock.Error) {
            case .nonEllapsedDate: break
            default: XCTFail("Expected NonEllapsedDateError, got \(error) instead")
            }
        }
    }
}


// Tests/UseCases/EncryptionUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import XCTest
import ChronoLock

class ChronoLockTests: XCTestCase {
    
    func test_encrypt_deliversErrorOnEncryptorError() throws {
        struct EncryptorStub: ChronoLock.Encryptor {
            let error: Error
            func encrypt<T>(_ codableObject: T) throws -> Data where T : Decodable, T : Encodable {
                throw error
            }
        }
        let encryptor = EncryptorStub(error: anyError())
        let sut = makeSUT(encryptor: encryptor)
        
        XCTAssertThrowsError(try sut.encrypt("any message", until: anyDate()))
    }
    
    func test_encrypt_deliversErrorOnAlreadyEllapsedDate() throws {
        
        let timestamp = Date()
        let alreadyEllapsedDate = timestamp.adding(seconds: -1)
        
        let sut = makeSUT(currentDate: {timestamp})
        
        XCTAssertThrowsError(try sut.encrypt("any message", until: alreadyEllapsedDate)) { error in
            XCTAssertEqual(error as? ChronoLock.Error, .alreadyEllapsedDate)
        }
    }
    
    func test_encrypt_deliversNoErrorOnNonEllapsedDateAndEncryptorSuccess() throws {
        
        let timestamp = Date()
        let nonEllapsedDate = timestamp.adding(seconds: 1)
         
        let sut = makeSUT(currentDate: {timestamp})
        
        XCTAssertNoThrow(try sut.encrypt("any message", until: nonEllapsedDate))
    }
}


// Tests/UseCases/Helpers/ChronoLockTests+Helpers.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import Foundation
import ChronoLock

// MARK: - Doubles
// Dummies
extension ChronoLockTests {
    struct EncryptorDummy: ChronoLock.Encryptor {
        func encrypt<T: Codable>(_ codableObject: T) throws -> Data {
            Data()
        }
    }
    
    
    struct DecryptorDummy: ChronoLock.Decryptor {
        func decrypt<T: Decodable>(_ data: Data) throws -> T {
            return ChronoLock.Item(unlockDate: Date(), content: "any content") as! T
        }
    }
    
    struct ReaderDummy: ChronoLock.Reader {
        func read(_ fileURL: URL) throws -> Data {Data()}
    }
    
    struct PersisterDummy: ChronoLock.Persister {
        func save(_ data: Data, at outputURL: URL) throws {}
        func save(_ content: String, at outputURL: URL) throws {}
    }
}

// MARK: - Factories
extension ChronoLockTests {
    func makeSUT(
        encryptor: ChronoLock.Encryptor = EncryptorDummy(),
        decryptor: ChronoLock.Decryptor = DecryptorDummy(),
        reader: ChronoLock.Reader = ReaderDummy(),
        persister: ChronoLock.Persister = PersisterDummy(),
        currentDate: @escaping () -> Date = Date.init
    ) -> ChronoLock {
        ChronoLock(encryptor: encryptor, decryptor: decryptor, reader: reader, persister: persister, currentDate: currentDate)
    }
    
    func anyError() -> NSError {
        NSError(domain: "any error", code: 0)
    }
    
    func anyDate() -> Date {
        Date()
    } 
}


// Tests/UseCases/Helpers/Date+adding.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import Foundation

extension Date {
    func adding(seconds: TimeInterval) -> Date {
        return self + seconds
    }
}


// Tests/UseCases/IOUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 30/5/25.

import XCTest
import ChronoLock

extension ChronoLockTests {
    func test_encryptAndSave_deliversErrorOnReadError() throws {
        struct ReaderStub: ChronoLock.Reader {
            let error: Error
            func read(_ fileURL: URL) throws -> Data {
                throw error
            }
        }
        let reader = ReaderStub(error: anyError())
        let sut = ChronoLock(encryptor: EncryptorDummy(), decryptor: DecryptorDummy(), reader: reader, persister: PersisterDummy(), currentDate: Date.init)
        let anyInputURL = URL(string: "file:///anyinput-url.txt")!
        let anyOutputURL = URL(string: "file:///anyoutput-url.txt")!
        XCTAssertThrowsError(try sut.encryptAndSave(file: anyInputURL, until: anyDate(), outputURL: anyOutputURL))
    }
    
    func test_encryptAndSave_deliversErrorOnSaveError() throws {
        struct PersisterStub: ChronoLock.Persister {
            let error: Error
            func save(_ content: String, at outputURL: URL) throws {
                throw error
            }
            func save(_ data: Data, at outputURL: URL) throws {
                throw error
            }
        }
      
        let persister = PersisterStub(error: anyError())
        let sut = ChronoLock(
            encryptor: EncryptorDummy(),
            decryptor: DecryptorDummy(),
            reader: ReaderDummy(),
            persister: persister,
            currentDate: Date.init
        )
        let anyInputURL = URL(string: "file:///anyinput-url.txt")!
        let anyOutputURL = URL(string: "file:///anyoutput-url.txt")!
        XCTAssertThrowsError(try sut.encryptAndSave(file: anyInputURL, until: anyDate(), outputURL: anyOutputURL))
    }
}

