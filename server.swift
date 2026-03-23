
// Package.swift
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MiniSwiftServer",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "MiniSwiftServer",
            targets: ["MiniSwiftServer"]
        ),
    ],
    targets: [
        .target(
            name: "MiniSwiftServer"
        ),
    ]
)


// Request.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 16/6/25.

import Foundation

public struct Request  {
    public let method: Method
    public let body: Data?
    public let path: String
    
    public init(method: Method, body: Data? = nil, path: String) {
        self.method = method
        self.body = body
        self.path = path
    }
}

extension Request {
    public enum Method: String {
        case get
        case post
        case patch
        case put
        case delete
    }
    
    public enum Error: Swift.Error {
        case noMethodFound
        case invalidMethod(String)
        case noPathFound
    }
    
}


extension Request {
    init(_ request: String) throws {
        let components = request.components(separatedBy: "\n\n")
        let headers = components.first?.components(separatedBy: "\n") ?? []
        let payload = components.count > 1 ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        
        method = try Self.method(headers)
        body   = try Self.body  (payload)
        path   = try Self.path  (headers)
    }
    
    init(_ buffer: Array<UInt8>) throws {
        try self.init(String(bytes: buffer, encoding: .utf8) ?? "")
    }
}

extension Request {
    static func method(_ headers: [String]) throws -> Method {
        let firstLine = headers.first?.components(separatedBy: " ")
        
        guard let stringMethod = firstLine?.first?.lowercased() else {
            throw Error.noMethodFound
        }
        
        guard let method = Method.init(rawValue: stringMethod) else {
            throw Error.invalidMethod(stringMethod)
        }
        
        return method
    }
    
    static func body(_ payload: String?) throws -> Data? {
        guard let payload, let data = payload.data(using: .utf8) else { return nil }
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        let normalizedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
        
        return normalizedData
    }
    
    static func path(_ headers: [String]) throws -> String {
        let firstLine = headers.first?.components(separatedBy: " ")
        guard let path = firstLine?[idx: 1] else { throw Error.noPathFound }
        return path.first == "/" ? String(path.dropFirst()) : path
    }
}

fileprivate extension Array {
    subscript(idx idx: Int) -> Element? {
        indices.contains(idx) ? self[idx] : nil
    }
}


// Response.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 16/6/25.

import Foundation

public struct Response {
    public let statusCode: Int
    public let contentType: String
    public let body: Body
    
    public init(statusCode: Int, contentType: String, body: Body) {
        self.statusCode = statusCode
        self.contentType = contentType
        self.body = body
    }
}

extension Response {
    public enum Body {
        case text(String)
        case binary(Data)
    }
    
    func toHTTPResponse() -> String {
        var response = "HTTP/1.1 \(statusCode)\r\n"
        response += "Content-Type: \(contentType)\r\n"
        
        switch body {
        case .text(let textBody):
            response += "Content-Length: \(textBody.utf8.count)\r\n"
            response += "\r\n"
            response += textBody
        case .binary(let binaryBody):
            response += "Content-Length: \(binaryBody.count)\r\n"
            response += "\r\n"
        }
        
        return response
    }
    
    public var bodyAsText: String? {
        switch body {
            case .text(let text): return text
            default: return nil
        }
    }
    
    public var binaryData: Data? {
        switch body {
        case .binary(let binaryBody):
            return binaryBody
        case .text:
            return nil
        }
    }
}


// Server.swift
//  © 2025  Cristian Felipe Patiño Rojas. Created on 16/6/25.

import Foundation

public struct Server {
    public typealias RequestHandler = (Request) -> Response
    let port: UInt16
    let requestHandler: RequestHandler

    public init(port: UInt16, requestHandler: @escaping RequestHandler) {
        self.port = port
        self.requestHandler = requestHandler
    }
    
    public func run() {
        
        let _socket = socket(AF_INET, SOCK_STREAM, 0)
        guard _socket >= 0 else {
            fatalError("Unable to create socket")
        }
        
        var value: Int32 = 1
        setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))
        
        var serverAddress = sockaddr_in()
        serverAddress.sin_family = sa_family_t(AF_INET)
        serverAddress.sin_port = in_port_t(port).bigEndian
        serverAddress.sin_addr = in_addr(s_addr: INADDR_ANY)
        
        let bindResult = withUnsafePointer(to: &serverAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(_socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult >= 0 else {
            fatalError("Error on socket launch.")
        }
        
        guard listen(_socket, 10) >= 0 else {
            fatalError("Error on socket listning.")
        }
        
        print("Server listening on port \(port)...")
        
        while true {
            var clientAddress = sockaddr_in()
            var clientAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(_socket, $0, &clientAddressLength)
                }
            }
            
            guard clientSocket >= 0 else {
                print("Error on connxion")
                continue
            }
            
            var buffer = [UInt8](repeating: 0, count: 1024)
            let bytesRead = read(clientSocket, &buffer, 1024)
            
            guard bytesRead > 0 else {
                print("Unable to read data")
                close(clientSocket)
                continue
            }
            
            do {
                
                let request = try Request(buffer)
                let response = requestHandler(request)
                
                let headersAndBody = response.toHTTPResponse()
                
                    write(clientSocket, headersAndBody, headersAndBody.utf8.count)
                
                    if let binaryData = response.binaryData {
                        _ = binaryData.withUnsafeBytes { bytes in
                            write(clientSocket, bytes.baseAddress!, binaryData.count)
                        }
                    }
                
                
                if response.statusCode != 200 {
                    print("Failed response at \(request.path):")
                    print(response)
                }
                
                close(clientSocket)
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    
    enum ServerError: Error {
        case noEndpointFound(String)
        
        var message: String {
            switch self {
                case .noEndpointFound(let path): return "No endpoint found for \(path)"
            }
        }
    }
}




