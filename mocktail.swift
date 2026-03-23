
// Package.swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MockTail",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MockTail",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "MockTailTests",
            dependencies: [
                .targetItem(name: "MockTail", condition: .none),
                .product(name: "CustomDump", package: "swift-custom-dump")
            ]
        ),
    ]
)


// Sources/Data/Request.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


public struct Request {
    public let headers: String
    public let body: String

    public init(headers: String, body: String = "") {
        self.headers = headers
        self.body = body
    }
}


// Sources/Data/Response.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


public struct Response: Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let rawBody: String?
    
    public init(statusCode: Int, headers: [String : String], rawBody: String?) {
        self.statusCode = statusCode
        self.headers = headers
        self.rawBody = rawBody
    }
}


// Sources/Helpers/Array+Extension.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

extension Array {
    func get(at index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

// Sources/Helpers/Pipes.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.

import Foundation

// Less esoteric version of my beloved `pipes` operator
func new<T>(_ item: T, withMap map: (inout T) -> Void) -> T {
    item | map
}

// Returns new instance of object with the `rhs` map applied
func |<T>(lhs: T, rhs: (inout T) -> Void) -> T {
    var copy = lhs
    rhs(&copy)
    return copy
}

// Maps `A` to `B`.
// Usage: let intAsString = 3 * String.init
func |<A, B>(lhs: A, rhs: (A) -> B) -> B {
    rhs(lhs)
}

func |<A, B>(lhs: A?, rhs: (A) -> B?) -> B? {
  lhs.flatMap(rhs)
}

func |<A, B>(lhs: A?, rhs: ((A) -> B?)?) -> B? {
    guard let rhs = rhs else {
        return nil
    }
  return lhs.flatMap(rhs)
}


// Sources/Helpers/Requests+Extension.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

extension Request {
    func normalizedURL() -> String? {
        requestHeaders().first?
            .components(separatedBy: " ")
            .get(at: 1)?
            .trimInitialAndLastSlashes()
    }
    
    func requestHeaders() -> [String] {
        headers.components(separatedBy: "\n")
    }
    
    func urlComponents() -> [String] {
        Array(normalizedURL()?.components(separatedBy: "/") ?? [])
    }
    
    func id() -> String? {
        urlComponents().get(at: 1)
    }
    
    func payloadAsJSONItem() -> JSONItem? {
        JSONCoder.decode(body)
    }
    
    func payloadJSONHasID() -> Bool {
        payloadAsJSONItem()?.keys.contains("id") ?? false
    }
    
    func payloadIsInvalidOrEmptyJSON() -> Bool {
        !payloadIsValidNonEmptyJSON()
    }
    
    func payloadIsValidNonEmptyJSON() -> Bool {
        JSONValidator.isValidJSON(body) && !JSONValidator
            .isEmptyJSON(body)
    }
    
    func urlHasNotId() -> Bool {
        route().id == nil
    }

    
    func collectionName() -> String? {
        urlComponents().first
    }
    
    enum HTTPMethod: String {
        case GET
        case POST
        case DELETE
        case PUT
        case PATCH
    }
    
    func httpMethod() -> HTTPMethod? {
        guard let verb = requestHeaders().first?.components(separatedBy: " ").first else {
            return nil
        }
        return HTTPMethod(rawValue: verb)
    }
    
    func isPayloadRequired() -> Bool {
        [HTTPMethod.PUT, .PATCH, .POST].contains(httpMethod())
    }
    
    func allItems() -> Bool {
        urlComponents().count == 1
    }
    
    enum ResourceRoute {
        case collection(name: String)
        case item(id: String, collectionName: String)
        case subroute
        
        init(_ urlComponents: [String]) {
            switch urlComponents.count {
            case 1: self = .collection(name: urlComponents[0])
            case 2: self = .item(id: urlComponents[1], collectionName: urlComponents[0])
            default: self = .subroute
            }
        }
        
        var id: String? {
            if case let .item(id, _) = self {
                return id
            }
            return nil
        }
    }
    
    func route() -> ResourceRoute {
        ResourceRoute(urlComponents())
    }
    
    func hasWrongOrMissingContentType() -> Bool {
        guard let contentType = contentType() else {
            return true
        }
        
        return contentType != "application/json"
    }
    
    func contentType() -> String? {
        for line in requestHeaders() {
            if line.lowercased().starts(with: "content-type:") {
                return line
                    .dropFirst("content-type:".count)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}


// Sources/Helpers/Response+Extension.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

public extension Response {
    nonisolated(unsafe) static let badRequest = Response(statusCode: 400)
    nonisolated(unsafe) static let notFound = Response(statusCode: 404)
    nonisolated(unsafe) static let empty = Response(statusCode: 204)
    nonisolated(unsafe) static let OK = Response(statusCode: 200)
    nonisolated(unsafe) static let unsopportedMethod = Response(statusCode: 405)
    nonisolated(unsafe) static let unsupportedMediaType = Response(statusCode: 415)
    
    static func created(_ rawBody: String?) -> Response {
        Response(statusCode: 201, rawBody: rawBody, contentLength: rawBody?.contentLenght())
    }
    
    static func OK(_ rawBody: String?) -> Response {
        Response(statusCode: 200, rawBody: rawBody, contentLength: rawBody?.contentLenght())
    }
}

public extension Response {
    init(
        statusCode: Int,
        rawBody: String? = nil,
        contentLength: Int? = nil
    ) {
        let date = Self.dateFormatter.string(from: Date())
        
        let headers = [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, HEAD, PUT, PATCH, POST, DELETE",
            "Access-Control-Allow-Headers": "content-type",
            "Content-Type": "application/json",
            "Date": date,
            "Connection": "close",
            "Content-Length": contentLength?.description
        ].compactMapValues { $0 }
        
        self.init(statusCode: statusCode, headers: headers, rawBody: rawBody)
    }
    
    static let dateFormatter = new(DateFormatter()) { df in
        df.dateFormat = "EEE',' dd MMM yyyy HH:mm:ss zzz"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
    }
}


// Sources/Helpers/String+Extension.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

extension String {
    func contentLenght() -> Int {
        data(using: .utf8)?.count ?? count
    }
    
    func removingBreaklines() -> String {
        self.replacingOccurrences(of: "\n", with: "")
    }
    
    func removingSpaces() -> String {
        self.replacingOccurrences(of: " ", with: "")
    }
    
    func trimInitialAndLastSlashes() -> String {
        var copy = self
        if copy.first == "/" {
            copy.removeFirst()
        }
        if copy.last == "/" {
            copy.removeLast()
        }
        
        return copy
    }
}


// Sources/JSON/JSONCoder.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

enum JSONCoder {
    static func encode(_ json: JSON) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func encode(_ json: JSONItem) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func decode<T>(_ data: String) -> T? {
        guard let data = data.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? T
    }
}

enum JSONValidator {
    static func isValidJSON(_ data: String) -> Bool {
        guard let data = data.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
    
    static func isEmptyJSON(_ data: String) -> Bool {
        data.isEmpty || data.removingAllWhiteSpaces() == "{}"
    }
}

fileprivate extension String {
    func removingAllWhiteSpaces() -> String {
        self.removingSpaces().removingBreaklines()
    }
}


// Sources/JSON/JSONRepresentations.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.

public typealias JSON = Any
public typealias JSONItem = [String: JSON]
public typealias JSONArray = [JSONItem]

public extension JSONArray {
    func getItem(with id: String) -> JSONItem? {
        self.first(where: { $0.getId() == id })
    }
}

public extension JSONItem {
     func getId() -> String? {
        self["id"] as? String
    }
    
    func merge(_ item: JSONItem) -> JSONItem {
        new(self) {
            for (key, value) in item { $0[key] = value }
        }
    }
}


// Sources/main.swift



// Sources/Parser/HeadersValidator.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

struct HeadersValidator {
    
    let request: Request
    let collections: [String: JSON]
    
    typealias Result = Int?
    
    var errorCode: Result {
        guard request.headers.contains("Host")  else {
            return Response.badRequest.statusCode
        }
        
        guard let _ = request.httpMethod() else {
            return Response.unsopportedMethod.statusCode
        }
        
        guard request.hasWrongOrMissingContentType() && request.isPayloadRequired() else {
                return nil
        }

        return Response.unsupportedMediaType.statusCode
    }
}


// Sources/Parser/Parser.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.
import Foundation

public struct Parser {
    private let collections: [String: JSON]
    private let idGenerator: () -> String
    
    public init(collections: [String : JSON], idGenerator: @escaping () -> String) {
        self.collections = collections
        self.idGenerator = idGenerator
    }
    
    public func parse(_ request: Request) -> Response {
        let validator = HeadersValidator(
            request: request,
            collections: collections
        )
        
        let router = Router(
            request: request,
            collections: collections,
            idGenerator: idGenerator
        )
        
        switch validator.errorCode {
        case .none:
            return router.handleRequest()
        case let .some(errorCode):
            return Response(statusCode: errorCode)
        }
    }
}


// Sources/Parser/Router.swift
// Created by Cristian Felipe Patiño Rojas on 5/5/25.


import Foundation

struct Router {
    let request: Request
    let collections: [String: JSON]
    let idGenerator: () -> String
    func handleRequest() -> Response {
        switch request.httpMethod() {
        case
                .PUT   where request.payloadIsInvalidOrEmptyJSON(),
                .POST  where request.payloadIsInvalidOrEmptyJSON(),
                .PATCH where request.payloadIsInvalidOrEmptyJSON(),
            
                .PUT   where request.payloadJSONHasID(),
                .POST  where request.payloadJSONHasID(),
                .PATCH where request.payloadJSONHasID(),
            
                .DELETE where request.urlHasNotId(),
                .PATCH  where request.urlHasNotId():
            
            return .badRequest
            
        case .GET   : return handleGET()
        case .DELETE: return handleDELETE()
        case .PUT   : return handlePUT()
        case .POST  : return handlePOST()
        case .PATCH : return handlePATCH()
        default: return Response(statusCode: 405)
        }
    }
    
    private func handleGET() -> Response {
        switch request.route() {
        case let .item(id, collection) where !itemExists(id, collection):
            return .notFound
        case let .collection(name) where !collectionExists(name):
            return .notFound
        case let .collection(name):
            return .OK(collections[name] | JSONCoder.encode)
        case let .item(id, collection) where itemExists(id, collection):
            return .OK(getItem(id, on: collection) | JSONCoder.encode)
            
        default: return .badRequest
        }
    }
    
    private func handleDELETE() -> Response {
        switch request.route() {
        case .collection, .subroute:
            return .badRequest
        case let .item(id, collection) where !itemExists(id, collection):
            return .notFound
        case .item:
            return .empty
        }
    }
    
    private func handlePUT() -> Response {
        switch request.route() {
        case let .item(id, collection) where !itemExists(id, collection):
            return .created(request.body)
        #warning("use JSONValidator instead")
        case .item where request.body.isEmpty:
            return .badRequest
        case let .item(id, collection) where request.payloadIsValidNonEmptyJSON():
            let put: JSONItem? = JSONCoder.decode(request.body)
            let existentItem = getItem(id, on: collection)
            let updated = put | existentItem?.merge
            return .OK(updated | JSONCoder.encode)
        default:
            return .badRequest
        }
    }
    
    private func handlePOST() -> Response {
        switch request.route() {
        case .item: return .badRequest
        case let .collection(name) where !collectionExists(name):
            return .notFound
        case .collection:
            let jsonItem = request.payloadAsJSONItem() | { $0?["id"] = idGenerator() }
            return .created(jsonItem | JSONCoder.encode)
        default: return .badRequest
        }
    }
    
    private func handlePATCH() -> Response {
        switch request.route() {
        case let .item(id, collection) where !itemExists(id, collection):
            return .notFound
        case let .item(id, collection):
            let patch = request.payloadAsJSONItem()!
            let item = getItem(id, on: collection)!
            
            let patched = item.merge(patch) | JSONCoder.encode
            return .OK(patched)
        default:
            return .badRequest
        }
    }
    
    private func getItem(_ id: String, on collection: String) -> JSONItem? {
        let items = collections[collection] as? JSONArray
        let item = items?.getItem(with: id)
        return item
    }

    private func collectionExists(_ collectionName: String) -> Bool {
        collections.keys.contains(collectionName)
    }
    
    private func containsItemId(_ body: String) -> Bool {
        guard let item: JSONItem = JSONCoder.decode(body) else { return false }
        return item.keys.contains("id") 
    }
    
    private func itemExists(_ id: String, _ collectionName: String) -> Bool {
        (collections[collectionName] as? JSONArray)?.getItem(with: id) != nil
    }
    
    private func jsonArray(_ collection: String) -> JSONArray? {
        collections[collection] as? JSONArray
    }
}


// Tests/Parser/ParserCommonTests.swift
//  Created by Cristian Felipe Patiño Rojas on 2/5/25.

import XCTest
import CustomDump
import MockTail


final class ParserTests: XCTestCase {
    func test_parser_delivers405OnUnsupportedMethod() {
        let sut = makeSUT()
        let request = Request(headers: "Unsupported /recipes HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .unsopportedMethod)
    }
}

// MARK: - Common
extension ParserTests {
    func test_parser_delivers400ResponseOnEmptyHeaders() {
        let sut = makeSUT()
        let request = Request(headers: "")
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }
    
    func test_parser_delivers400OnMalformedHeaders() {
        let sut = makeSUT()
        let request = Request(headers: "GETHTTP/1.1")
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }
    
    func test_parser_delivers400OnMissingHostHeader() {
        let sut = makeSUT()
        let request = Request(headers: "GET /recipes HTTP/1.1")
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }
    
    func test_parser_delivers404OnNonExistentCollection() {
        let sut = makeSUT()
        let request = Request(headers: "GET /recipes HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .notFound)
    }
    
    func test_parser_delivers404OnDELETEMalformedId() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(headers: "DELETE /recipes/abc HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .notFound)
    }
    
    func test_parser_delivers404OnNonExistentResource() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(headers: "GET /recipes/2 HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .notFound)
    }
    
    func test_parser_delivers400OnUnknownSubroute() {
        let sut = makeSUT(collections: ["recipes": [1]])
        let request = Request(headers: "GET /recipes/1/helloworld HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }

    func test_parse_delivers415OnPayloadRequiredRequestsMissingContentTypeHeader() {
        let sut = makeSUT(collections: ["recipes": []])
        
        ["POST", "PATCH", "PUT"].forEach { verb in
            let request = Request(headers: "\(verb) /recipes HTTP/1.1\nHost: localhost")
            let response = sut.parse(request)
            
            expectNoDifference(response, .unsupportedMediaType, "Failed on \(verb)")
        }
    }
    
    func test_parse_delivers415OnPayloadRequiredRequestsUnsupportedMediaType() {
        let sut = makeSUT(collections: ["recipes": []])
        
        ["POST", "PATCH", "PUT"].forEach { verb in
            let request = Request(headers: "\(verb) /recipes\nContent-Type: \(anyNonJSONMediaType()) HTTP/1.1\nHost: localhost")
            let response = sut.parse(request)
            
            expectNoDifference(response, .unsupportedMediaType, "Failed on \(verb)")
        }
    }
 
    func test_parse_delivers400OnPayloadAndIDRequiredRequestsWithInvalidJSONBody() {
        let sut = makeSUT(collections: ["recipes": [["id": "1"]]])
        
        ["PATCH", "PUT"].forEach { verb in
            let request = Request(
                headers: "\(verb) /recipes/1\nContent-Type: application/json\nHost: localhost",
                body: "invalid json"
            )
            let response = sut.parse(request)
            
            expectNoDifference(response, .badRequest, "Failed on \(verb)")
        }
    }
    
    func test_parse_delivers400OnPayloadRequiredRequestsWithEmptyJSON() {
        expect(.badRequest, on: "{}", for: "PATCH")
        expect(.badRequest, on: "{ }", for: "PATCH")
        expect(.badRequest, on: "{\n}", for: "PATCH")
        expect(.badRequest, on: nil, for: "PATCH")
        expect(.badRequest, on: "{}", for: "PUT")
        expect(.badRequest, on: "{ }", for: "PUT")
        expect(.badRequest, on: "{\n}", for: "PUT")
        expect(.badRequest, on: nil, for: "PUT")
    }
    
    func test_parse_delivers400OnPayloadAndIDRequiredRequestsWithJSONBodyWithDifferentItemId() {
        let item1: JSONItem = ["id": "1", "title": "KFC Chicken"]
        let item2: JSONItem = ["id": "2", "title": "Sushi rolls"]
        let sut = makeSUT(collections: ["recipes": [item1, item2]])
        
        ["PATCH", "POST"].forEach { verb in
            let request = Request(
                headers: "\(verb) /recipes/1 HTTP/1.1\nHost: localhost\nContent-type: application/json",
                body: #"{"id":"2","title":"Fried chicken"}"#
            )
            
            let response = sut.parse(request)
            expectNoDifference(response, .badRequest)
        }
    }
    
    func test_parse_delivers400OnIdRequiredRequestWithNoIdOnRequestURL() {
        let sut = makeSUT(collections: ["recipes": [:]])
        ["DELETE", "PATCH", "PUT"].forEach { verb in
            let request = Request(headers: "\(verb) /recipes HTTP/1.1\nHost: localhost\nContent-Type: application/json", body: "any payload")
            let response = sut.parse(request)
            expectNoDifference(response, .badRequest, "Expect failed for \(verb)")
        }
    }
    
    func test_parse_delivers400OnIDRequiredRequestsWhenIDPresentWithinPayloadBody()  {
        let sut = makeSUT(collections: ["recipes": ["id":"1"]])
        ["PATCH", "PUT"].forEach { verb in
            let request = Request(
                headers: "\(verb) /recipes HTTP/1.1\nHost: localhost\nContent-Type: application/json",
                body: #"{"id": "2"}"#
            )
            let response = sut.parse(request)
            expectNoDifference(response, .badRequest, "Expect failed for \(verb)")
        }
    }
}

extension Response {
    func body() -> NSDictionary? {
        guard
            let rawBody,
            let responseJSON = try? JSONSerialization.jsonObject(with: Data(rawBody.utf8)),
            let responseDict = responseJSON as? NSDictionary
        else {
            return nil
        }
        return responseDict
    }
}


// Tests/Parser/ParserDELETETests.swift
// Created by Cristian Felipe Patiño Rojas on 6/5/25.

import MockTail
import CustomDump
import XCTest

// MARK: - DELETE
extension ParserTests {
    func test_DELETE_delivers404OnDeleteRequestToAnUnexistentItem() {
        let sut = makeSUT()
        let request = Request(headers: "DELETE /recipes/1 HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        
        expectNoDifference(response, .notFound)
    }
    
    func test_DELETE_delivers204OnSuccessfulItemDeletion() {
        let item = ["id": "1"]
        let sut = makeSUT(collections: ["recipes": [item]])
        let request = Request(headers: "DELETE /recipes/1 HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        
        expectNoDifference(response, .empty)
    }
}


// Tests/Parser/ParserGETTests.swift
// Created by Cristian Felipe Patiño Rojas on 6/5/25.
import MockTail
import CustomDump

// MARK: - GET
extension ParserTests {
    
    func test_GET_delivers200OnRequestOfExistingCollectionWithTrailingSlash() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(headers: "GET /recipes/ HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response.statusCode, 200)
    }
    
    func test_GET_delivers200OnRequestOfExistingEmptyCollection() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(headers: "GET /recipes HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .OK("[]"))
    }
    
    func test_GET_delivers200OnRequestOfExistingNonEmptyCollection() {
        let item1 = ["id": 1]
        let item2 = ["id": 2]
        let sut = makeSUT(collections: ["recipes": [item1, item2]])
        let request = Request(headers: "GET /recipes HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        
        expectNoDifference(response, .OK(#"[{"id":1},{"id":2}]"#))
    }
    
    func test_GET_delivers200OnRequestOfExistingItem() {
        let item = ["id": "1"]
        let sut = makeSUT(collections: ["recipes": [item]])
        let request = Request(headers: "GET /recipes/1 HTTP/1.1\nHost: localhost")
        let response = sut.parse(request)
        expectNoDifference(response, .OK(#"{"id":"1"}"#))
    }
}


// Tests/Parser/ParserPATCHTests.swift
// Created by Cristian Felipe Patiño Rojas on 6/5/25.

import MockTail
import CustomDump
import XCTest

// MARK: - Patch
extension ParserTests {
    
    func test_PATCH_delivers404OnNonExistentResource() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(
            headers: "PATCH /recipes/1 HTTP/1.1\nHost: localhost\nContent-Type: application/json",
            body: #"{"title":"new-title"}"#
        )
        let response = sut.parse(request)
        expectNoDifference(response, .notFound)
    }
    
    func test_PATCH_delivers400OnValidJSONBodyAndMatchingURLId() {
        let item = ["id": "1"]
        let sut = makeSUT(collections: ["recipes": [item]])
        let request = Request(
            headers: "PATCH /recipes/1 HTTP/1.1\nHost: localhost\nContent-type: application/json",
            body: #"{"id":"1","title":"New title"}"#
        )
        
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }


    func test_PATCH_delivers200OnValidJSONBody() throws {
        let original: JSONItem = ["id": "1", "title": "Old title"]
        let sut = makeSUT(collections: ["recipes": [original]])
        let request = Request(
            headers: "PATCH /recipes/1 HTTP/1.1\nHost: localhost\nContent-Type: application/json",
            body: #"{"title":"New title"}"#
        )
        let response = sut.parse(request)
        let expected = Response.OK(#"{"title":"New title","id":"1"}"#)
        
        expectNoDifference(
            try XCTUnwrap(response.body()),
            try XCTUnwrap(expected.body())
        )
    }
}


// MARK: - Helpers
extension ParserTests {
    func makeSUT(collections: [String: JSON] = [:], idGenerator: @escaping () -> String = defaultGenrator, ) -> Parser {
        Parser(collections: collections, idGenerator: idGenerator)
    }
    
    static func defaultGenrator() -> String {
        UUID().uuidString
    }
    
    func anyNonJSONMediaType() -> String {
        "application/freestyle"
    }
    
    func nsDictionary(from jsonString: String) -> NSDictionary? {
        guard
            let responseJSON = try? JSONSerialization.jsonObject(with: Data(jsonString.utf8)),
            let responseDict = responseJSON as? NSDictionary
        else {
            return nil
        }
        return responseDict
    }
    
    func expect(
        _ expectedResponse: Response,
        on emptyJSONRepresentation: String?,
        for verb: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let item = ["id": "1"]
        let sut = makeSUT(collections: ["recipes": [item]])
        
        let request = Request(
            headers: "\(verb) /recipes/1 HTTP/1.1\nHost: localhost\nContent-type: application/json",
            body: ""
        )
        
        let response = sut.parse(request)
        expectNoDifference(response, expectedResponse, "Failed on representation \(emptyJSONRepresentation ?? "null") for verb \(verb)")
    }
}


// Tests/Parser/ParserPOSTTests.swift
// Created by Cristian Felipe Patiño Rojas on 6/5/25.

import MockTail
import CustomDump
import XCTest

// MARK: - POST
extension ParserTests {
    
    func test_POST_delivers400OnInvalidJSONBody() {
        let sut = makeSUT(collections: ["recipes": [["id": 1]]])
     
        let request = Request(
            headers: "POST /recipes\nContent-Type: application/json\nHost: localhost",
            body: "invalid json"
        )
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }
    
    func test_POST_delivers400OnJsonBodyWithItemId() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(
            headers: "POST /recipes HTTP/1.1\nHost: localhost\nContent-type: application/json",
            body: #"{"id": 1,"title":"Fried chicken"}"#
        )
        
        let response = sut.parse(request)
        expectNoDifference(response, .badRequest)
    }
    
    func test_POST_delivers201OnValidJSONBody() throws {
        let newId = UUID().uuidString
        let sut = makeSUT(collections: ["recipes": []], idGenerator: {newId})
        let request = Request(
            headers: "POST /recipes HTTP/1.1\nHost: localhost\nContent-type: application/json",
            body: #"{"title":"Fried chicken"}"#
        )
        let response = sut.parse(request)
        let expectedResponse = Response.created("{\"id\":\"\(newId)\",\"title\":\"Fried chicken\"}")
        
        expectNoDifference(response.statusCode, expectedResponse.statusCode)
        expectNoDifference(response.headers, expectedResponse.headers)
        
        let responseBody = try XCTUnwrap(response.rawBody)
        let expectedBody = try XCTUnwrap(expectedResponse.rawBody)
        
        expectNoDifference(
            try XCTUnwrap(nsDictionary(from: responseBody)),
            try XCTUnwrap(nsDictionary(from: expectedBody))
        )
    }
}
   


// Tests/Parser/ParserPUTTests.swift
// Created by Cristian Felipe Patiño Rojas on 6/5/25.

import MockTail
import XCTest
import CustomDump

// MARK: - PUT
extension ParserTests {
    
    func test_PUT_delivers201OnRequestOfNonExistingResource() {
        let sut = makeSUT(collections: ["recipes": []])
        let request = Request(
            headers: "PUT /recipes/1 HTTP/1.1\nHost: localhost\nContent-type: application/json",
            body: #"{"title":"French fries"}"#
        )
        
        let response = sut.parse(request)
        expectNoDifference(response, .created(#"{"title":"French fries"}"#))
    }
    
    func test_PUT_delivers200OnRequestWithValidJSONBody() {
        let item = ["id": "1"]
        let sut = makeSUT(collections: ["recipes": [item]])
        let request = Request(
            headers: "PUT /recipes/1 HTTP/1.1\nHost: localhost\nContent-type: application/json",
            body: #"{"title":"New title"}"#
        )
        
        let response = sut.parse(request)
        let expected = Response.OK(#"{"id":"1","title":"New title"}"#)
        expectNoDifference(
            response.body(),
            expected.body()
        )
    }
}


