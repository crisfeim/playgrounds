
// Package.swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MinimalAuthExample",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "GenericAuth", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
            .product(name: "JWTKit", package: "jwt-kit"),
        ]),
        .executableTarget(
            name: "MinimalAuthExample",
            dependencies: [
                "GenericAuth",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .testTarget(
            name: "MinimalAuthExampleTests",
            dependencies: [
                .target(name: "MinimalAuthExample"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        )
    ]
)


// Sources/GenericAuth/AuthRequest.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


public struct AuthRequest: Codable {
    public let email: String
    public let password: String
    
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}


// Sources/GenericAuth/Controllers/LoginController.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

public struct LoginController<UserId> {
    
    public typealias UserFinder = (_ email: String) throws -> User?
    public struct User {
        fileprivate let id: UserId
        fileprivate let hashedPassword: String
        
        public init(id: UserId, hashedPassword: String) {
            self.id = id
            self.hashedPassword = hashedPassword
        }
    }
    
    private let userFinder: UserFinder
    private let emailValidator: EmailValidator
    private let passwordValidator: PasswordValidator
    private let tokenProvider: AuthTokenProvider<UserId>
    private let passwordVerifier: PasswordVerifier
    
    public init(
        userFinder: @escaping UserFinder,
        emailValidator: @escaping EmailValidator,
        passwordValidator: @escaping PasswordValidator,
        tokenProvider: @escaping AuthTokenProvider<UserId>,
        passwordVerifier: @escaping PasswordVerifier
    ) {
        self.userFinder = userFinder
        self.emailValidator = emailValidator
        self.passwordValidator = passwordValidator
        self.tokenProvider = tokenProvider
        self.passwordVerifier = passwordVerifier
    }
    
    public func login(email: String, password: String) async throws -> String {
        guard emailValidator(email) else {
            throw InvalidEmailError()
        }
        
        guard passwordValidator(password) else {
            throw InvalidPasswordError()
        }
        
        guard let user = try userFinder(email) else {
            throw NotFoundUserError()
        }
        
        guard try await passwordVerifier(password, user.hashedPassword) else {
            throw IncorrectPasswordError()
        }
        
        return try await tokenProvider(user.id, email)
    }
}


// Sources/GenericAuth/Controllers/RegisterController.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import Foundation

public typealias UserMaker<UserId> = (_ email: String, _ hashedPassword: String) throws -> UserId
public typealias UserExists = (_ email: String) throws -> Bool

public struct RegisterController<UserId> {
    private let userMaker: UserMaker<UserId>
    private let userExists: UserExists
    private let emailValidator: EmailValidator
    private let passwordValidator: PasswordValidator
    private let tokenProvider: AuthTokenProvider<UserId>
    private let passwordHasher: PasswordHasher
    
    public init(
        userMaker: @escaping UserMaker<UserId>,
        userExists: @escaping UserExists,
        emailValidator: @escaping EmailValidator,
        passwordValidator: @escaping PasswordValidator,
        tokenProvider: @escaping AuthTokenProvider<UserId>,
        passwordHasher: @escaping PasswordHasher
    ) {
        self.userMaker = userMaker
        self.userExists = userExists
        self.emailValidator = emailValidator
        self.passwordValidator = passwordValidator
        self.tokenProvider = tokenProvider
        self.passwordHasher = passwordHasher
    }
    
    public func register(email: String, password: String) async throws -> String {
        guard try !userExists(email) else {
            throw UserAlreadyExists()
        }
        
        guard emailValidator(email) else {
            throw InvalidEmailError()
        }
        
        guard passwordValidator(password) else {
            throw InvalidPasswordError()
        }
        
        let hashedPassword = try await passwordHasher(password)
        let userID = try userMaker(email, hashedPassword)
        return try await tokenProvider(userID, email)
    }
}


// Sources/GenericAuth/Errors.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

public struct InvalidEmailError: Error {}
public struct InvalidPasswordError: Error {}
public struct NotFoundUserError: Error {}
public struct IncorrectPasswordError: Error {}
public struct UserAlreadyExists: Error {}


// Sources/GenericAuth/Hashing/BCryptPasswordHasher.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


import HummingbirdBcrypt
import NIOPosix

public struct BCryptPasswordHasher {
    public init() {}
    public func execute(_ password: String) async throws -> String {
       return try await NIOThreadPool.singleton.runIfActive { Bcrypt.hash(password, cost: 12) }
    }
}


// Sources/GenericAuth/Hashing/BCryptPasswordVerifier.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import HummingbirdBcrypt
import NIOPosix

public struct BCryptPasswordVerifier {
    public init() {}
    public func execute(_ password: String, _ hash: String) async throws -> Bool {
        try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.verify(password, hash: hash)
        }
    }
}


// Sources/GenericAuth/Interactors.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation

public typealias EmailValidator  = (_ email: String) -> Bool
public typealias PasswordValidator = (_ password: String) -> Bool
public typealias AuthTokenProvider<UserId> = (_ userId: UserId, _ email: String) async throws -> String
public typealias AuthTokenVerifier = (_ token: String) async throws -> UUID
public typealias PasswordHasher = (_ input: String) async throws -> String
public typealias PasswordVerifier = (_ password: String, _ hash: String) async throws -> Bool


// Sources/GenericAuth/JWT/JWTPayloadData.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


import JWTKit

public struct JWTPayloadData: JWTPayload, Equatable {
    var subject: SubjectClaim
    private var expiration: ExpirationClaim
    private var email: String
    
    public init(subject: SubjectClaim, expiration: ExpirationClaim, email: String) {
        self.subject = subject
        self.expiration = expiration
        self.email = email
    }

    public func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}


// Sources/GenericAuth/JWT/TokenProvider.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation
import JWTKit

public struct TokenProvider {
    private let kid: JWKIdentifier
    private let jwtKeyCollection: JWTKeyCollection
    
    public init(kid: JWKIdentifier, jwtKeyCollection: JWTKeyCollection) {
        self.kid = kid
        self.jwtKeyCollection = jwtKeyCollection
    }
    
    public func execute(userId: UUID, email: String) async throws -> String {
        let payload = JWTPayloadData(
            subject: .init(value: userId.uuidString),
            expiration: .init(value: Date(timeIntervalSinceNow: 12 * 60 * 60)),
            email: email
        )
        return try await self.jwtKeyCollection.sign(payload, kid: self.kid)
    }
}


// Sources/GenericAuth/JWT/TokenVerifier.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation
import JWTKit

public struct TokenVerifier {
    private let jwtKeyCollection: JWTKeyCollection
    
    public init(jwtKeyCollection: JWTKeyCollection) {
        self.jwtKeyCollection = jwtKeyCollection
    }

    public func execute(_ token: String) async throws -> UUID {
        let payload = try await jwtKeyCollection.verify(token, as: JWTPayloadData.self)
        
        guard let uuid = UUID(uuidString: payload.subject.value) else {
            throw InvalidSubjectError()
        }
        return uuid
    }

    struct InvalidSubjectError: Error {}
}


// Sources/MinimalAuthExample/AppComposer.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation
import Hummingbird
import JWTKit
import GenericAuth

public enum AppComposer {
    static public func execute(with configuration: ApplicationConfiguration, secretKey: HMACKey, userStore: UserStore, recipeStore: RecipeStore) async -> some ApplicationProtocol {
        
        let jwtKeyCollection = JWTKeyCollection()
        await jwtKeyCollection.add(
            hmac: secretKey,
            digestAlgorithm: .sha256,
            kid: JWKIdentifier("auth-jwt")
        )
        
        let tokenProvider = TokenProvider(kid: JWKIdentifier("auth-jwt"), jwtKeyCollection: jwtKeyCollection)
        let tokenVerifier = TokenVerifier(jwtKeyCollection: jwtKeyCollection)
        let passwordHasher = BCryptPasswordHasher()
        let passwordVerifier = BCryptPasswordVerifier()
        
        let emailValidator: EmailValidator = { _ in true }
        let passwordValidator: PasswordValidator = { _ in true }
        
    
        let registerController = RegisterController<UUID>(
            userMaker: userStore.createUser,
            userExists: userStore.findUser |>> isNotNil,
            emailValidator: emailValidator,
            passwordValidator: passwordValidator,
            tokenProvider: tokenProvider.execute,
            passwordHasher: passwordHasher.execute
        ) |> RegisterControllerAdapter.init
         
        let loginController = LoginController<UUID>(
            userFinder: userStore.findUser |>> UserMapper.map,
            emailValidator: emailValidator,
            passwordValidator: passwordValidator,
            tokenProvider: tokenProvider.execute,
            passwordVerifier: passwordVerifier.execute
        ) |> LoginControllerAdapter.init
        
        let recipesController = RecipesController(store: recipeStore, tokenVerifier: tokenVerifier.execute) |> RecipesControllerAdapter.init
        
        return Application(router: Router() .* { router in
            router.post("/register", use: registerController.handle)
            router.post("/login", use: loginController.handle)
            router.addRoutes(recipesController.endpoints, atPath: "/recipes")
        }, configuration: configuration )
    }
}


enum UserMapper {
    static func map(_ user: User) -> LoginController<UUID>.User {
        .init(id: user.id, hashedPassword: user.hashedPassword)
    }
}

// MARK:  Functional operators
infix operator .*: AdditionPrecedence

private func .*<T>(lhs: T, rhs: (inout T) -> Void) -> T {
    var copy = lhs
    rhs(&copy)
    return copy
}

precedencegroup PipePrecedence {
    associativity: left
    lowerThan: LogicalDisjunctionPrecedence
}

infix operator |> : PipePrecedence
func |><A, B>(lhs: A, rhs: (A) -> B) -> B {
    rhs(lhs)
}

typealias Throwing<A, B> = (A) throws -> B
typealias Mapper<A, B> = (A) -> B

infix operator |>>
private func |>><A, B, C>(lhs:  @escaping Throwing<A, B?>, rhs: @escaping Mapper<B, C>) -> Throwing<A, C?> {
    return { a in
        try lhs(a).map(rhs)
    }
}

private func |>><A, B, C>(lhs:  @escaping Throwing<A, B>, rhs: @escaping Mapper<B, C>) -> Throwing<A, C> {
    return { a in
        let b = try lhs(a)
        return rhs(b)
    }
}

private func isNotNil<T>(_ value: T?) -> Bool { value != nil }


// Sources/MinimalAuthExample/CLI.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import ArgumentParser
import Foundation
import Hummingbird

@main
struct CLI: AsyncParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    func run() async throws {
        let userStoreURL = appDataURL().appendingPathComponent("users.json")
        let recipeStoreURL = appDataURL().appendingPathComponent("recipes.json")
        
        let userStore = CodableUserStore(storeURL: userStoreURL)
        let recipeStore = CodableRecipeStore(storeURL: recipeStoreURL)
        
        let config = ApplicationConfiguration(address: .hostname(self.hostname, port: self.port), serverName: "Hummingbird")
        
       return try await AppComposer.execute(
            with: config,
            secretKey: "my secret key that should come from deployment environment",
            userStore: userStore,
            recipeStore: recipeStore
       ).runService()
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func appDataURL() -> URL {
        cachesDirectory().appendingPathComponent("\(type(of: self))")
    }
}


// Sources/MinimalAuthExample/CodableStore.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation

final class CodableStore<T: Codable> {
    let storeURL: URL
    
    init(storeURL: URL) {
        self.storeURL = storeURL
    }
    
    func save(_ object: T) throws {
        var objects = try get()
        objects.append(object)
        let data = try JSONEncoder().encode(objects)
        try data.write(to: storeURL)
    }
    
    func get() throws -> [T] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            let directory = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return []
        }
        let data = try Data(contentsOf: storeURL)
        return try JSONDecoder().decode([T].self, from: data)
    }
}


// Sources/MinimalAuthExample/Helpers/ResponseGeneratorEncoder.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


import Foundation
import Hummingbird

enum ResponseGeneratorEncoder {
    static func execute<T: Encodable>(_ encodable: T, from request: Request, context: some RequestContext) throws -> Response {
        let data = try JSONEncoder().encode(encodable)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        
        var headers = HTTPFields()
        headers.reserveCapacity(4)
        headers.append(.init(name: .contentType, value: "application/json"))
        headers.append(.init(name: .contentLength, value: buffer.readableBytes.description))

        return Response(
            status: .ok,
            headers: headers,
            body: .init(byteBuffer: buffer)
        )
    }
}


// Sources/MinimalAuthExample/Modules/Auth/Adapters/LoginControllerAdapter.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import Foundation
import Hummingbird
import GenericAuth

struct LoginControllerAdapter: @unchecked Sendable   {
    let controller: LoginController<UUID>
    
    init(_ controller: LoginController<UUID>) {
        self.controller = controller
    }
    
    func handle(request: Request, context: BasicRequestContext) async throws  -> Response {
        let registerRequest = try await request.decode(as: AuthRequest.self, context: context)
        let token = try await controller.login(
            email: registerRequest.email,
            password: registerRequest.password
        )
        return try ResponseGeneratorEncoder.execute(
            TokenResponse(token: token),
            from: request,
            context: context
        )
    }
}


// Sources/MinimalAuthExample/Modules/Auth/Adapters/RegisterControllerAdapter.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import Foundation
import Hummingbird
import GenericAuth

struct RegisterControllerAdapter: @unchecked Sendable {
    let controller: RegisterController<UUID>
    
    init(_ controller: RegisterController<UUID>) {
        self.controller = controller
    }
    
    func handle(request: Request, context: BasicRequestContext) async throws  -> Response {
        let registerRequest = try await request.decode(as: AuthRequest.self, context: context)
        let token = try await controller.register(email: registerRequest.email, password: registerRequest.password)
        
        return try ResponseGeneratorEncoder.execute(
            TokenResponse(token: token),
            from: request,
            context: context
        )
    }
}


// Sources/MinimalAuthExample/Modules/Auth/Domain/User.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.
import Foundation

public struct User: Equatable {
    public let id: UUID
    public let email: String
    public let hashedPassword: String
    
    public init(id: UUID, email: String, hashedPassword: String) {
        self.id = id
        self.email = email
        self.hashedPassword = hashedPassword
    }
}


// Sources/MinimalAuthExample/Modules/Auth/Infrastructure/CodableUserStore.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation

public class CodableUserStore: UserStore {
    private let store: CodableStore<CodableUser>
    public init(storeURL: URL) {
        self.store = .init(storeURL: storeURL)
    }
    
    public func getUsers() throws -> [User] {
        try store.get().map(CodableUserMapper.map)
    }
    
    @discardableResult
    public func createUser(email: String, hashedPassword: String) throws -> UUID {
        let id = UUID()
        try store.save(CodableUser(id: id, email: email, hashedPassword: hashedPassword))
        return id
    }
    
    public func findUser(byEmail email: String) throws -> User? {
        return try store.get().first { $0.email == email }.map(CodableUserMapper.map)
    }
}


private struct CodableUser: Codable {
    let id: UUID
    let email: String
    let hashedPassword: String
}

private enum CodableUserMapper {
    static func map(_ user: CodableUser) -> User {
        User(id: user.id, email: user.email, hashedPassword: user.hashedPassword)
    }
    
    static func map(_ user: User) -> CodableUser {
        CodableUser(id: user.id, email: user.email, hashedPassword: user.hashedPassword)
    }
}


// Sources/MinimalAuthExample/Modules/Auth/Responses/TokenResponse.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

public struct TokenResponse: Codable, Equatable {
    public let token: String
}


// Sources/MinimalAuthExample/Modules/Auth/UserStore.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation

public protocol UserStore {
    func createUser(email: String, hashedPassword: String) throws -> UUID
    func findUser(byEmail email: String) throws -> User?
}


// Sources/MinimalAuthExample/Modules/Recipes/Adapters/RecipesControllerAdapter.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import Hummingbird

struct RecipesControllerAdapter: @unchecked Sendable {
    let controller: RecipesController
    
    init(_ controller: RecipesController) {
        self.controller = controller
    }
    
    var endpoints: RouteCollection<BasicRequestContext> {
        return RouteCollection(context: BasicRequestContext.self)
            .get(use: get)
            .post(use: post)
    }
    
    func post(request: Request, context: BasicRequestContext) async throws -> Response {
        guard let authHeader = request.headers[values: .init("Authorization")!].first,
              authHeader.starts(with: "Bearer "),
              let token = authHeader.split(separator: " ").last.map(String.init)
        else {
            return Response(status: .unauthorized)
        }
        
        let recipeRequest = try await request.decode(as: CreateRecipeRequest.self, context: context)
        let recipe = try await controller.postRecipe(accessToken: token, title: recipeRequest.title)
        return try ResponseGeneratorEncoder.execute(recipe, from: request, context: context)
    }
    
    func get(request: Request, context: BasicRequestContext) async throws -> Response {
        guard let authHeader = request.headers[values: .init("Authorization")!].first,
              authHeader.starts(with: "Bearer "),
              let token = authHeader.split(separator: " ").last.map(String.init)
        else {
            return Response(status: .unauthorized)
        }
        let recipes = try await controller.getRecipes(accessToken: token)
        return try ResponseGeneratorEncoder.execute(recipes, from: request, context: context)
    }
}


// Sources/MinimalAuthExample/Modules/Recipes/Controllers/RecipesController.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import Foundation
import GenericAuth

public struct RecipesController {
    private let store: RecipeStore
    private let tokenVerifier: AuthTokenVerifier
    
    struct UnauthorizedError: Error {}
    private let jsonDecoder = JSONDecoder()
    
    public init(store: RecipeStore, tokenVerifier: @escaping AuthTokenVerifier) {
        self.store = store
        self.tokenVerifier = tokenVerifier
    }
    
    public func postRecipe(accessToken: String, title: String) async throws -> Recipe {
        let userId = try await tokenVerifier(accessToken)
        return try store.createRecipe(userId: userId, title: title)
    }
    
    public func getRecipes(accessToken: String) async throws -> [Recipe] {
        let userId = try await tokenVerifier(accessToken)
        let recipes = try store.getRecipes()

        return recipes.filter { $0.userId == userId }
    }
}


// Sources/MinimalAuthExample/Modules/Recipes/Domain/Recipe.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.
import Foundation

public struct Recipe: Equatable, Codable {
    let id: UUID
    public let userId: UUID
    public let title: String
    
    public init(id: UUID, userId: UUID, title: String) {
        self.id = id
        self.userId = userId
        self.title = title
    }
}


// Sources/MinimalAuthExample/Modules/Recipes/Infrastructure/CodableRecipeStore.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation

public class CodableRecipeStore: RecipeStore {
    private let store: CodableStore<CodableRecipe>
    
    public init(storeURL: URL) {
        self.store = .init(storeURL: storeURL)
    }
    
    public func getRecipes() throws -> [Recipe] {
        try store.get().map(RecipeMapper.map)
    }
    
    public func createRecipe(userId: UUID, title: String) throws -> Recipe {
        let recipe = CodableRecipe(id: UUID(), userId: userId, title: title)
        try store.save(recipe)
        return RecipeMapper.map(recipe)
    }
}

private struct CodableRecipe: Codable {
    let id: UUID
    let userId: UUID
    let title: String
}

private enum RecipeMapper {
    static func map(_ recipe: Recipe) -> CodableRecipe {
        CodableRecipe(
            id: recipe.id,
            userId: recipe.userId,
            title: recipe.title
        )
    }
    
    static func map(_ recipe: CodableRecipe) -> Recipe {
        Recipe(
            id: recipe.id,
            userId: recipe.userId,
            title: recipe.title
        )
    }
}


// Sources/MinimalAuthExample/Modules/Recipes/RecipeStore.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


import Foundation

public protocol RecipeStore {
    func getRecipes() throws -> [Recipe]
    func createRecipe(userId: UUID, title: String) throws -> Recipe
}

// Sources/MinimalAuthExample/Modules/Recipes/Requests/CreateRecipeRequest.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

public struct CreateRecipeRequest: Codable {
    let title: String
    public init(title: String) {
        self.title = title
    }
}


// Tests/Infrastructure/CodableRecipeStoreTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import XCTest
import MinimalAuthExample

class CodableRecipeStoreTests: XCTestCase {
    
    
    
    override func setUp() {
        try? FileManager.default.removeItem(at: testSpecificURL())
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testSpecificURL())
    }
    
    func test_getRecipes_deliversNoRecipesOnEmptyStore() throws {
        let sut = CodableRecipeStore(storeURL: testSpecificURL())
        let recipes = try sut.getRecipes()
        XCTAssertEqual(recipes, [])
    }
    
    func test_createRecipe_createsRecipe() throws {
        let sut = CodableRecipeStore(storeURL: testSpecificURL())
        let recipe = try sut.createRecipe(userId: anyUUID(), title: "any recipe title")
        XCTAssertTrue(try sut.getRecipes().contains(recipe))
    }
    
    private func anyUUID() -> UUID { UUID() }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func testSpecificURL() -> URL {
        cachesDirectory().appendingPathComponent("\(type(of: self))")
    }
}


// Tests/Infrastructure/CodableUserStoreTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import XCTest
import MinimalAuthExample

class CodableUserStoreTests: XCTestCase {
    override func setUp() {
        try? FileManager.default.removeItem(at: testSpecificURL())
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testSpecificURL())
    }
    
    func test_getUsers_deliversNoUsersOnEmptyStore() throws {
        let sut = CodableUserStore(storeURL: testSpecificURL())
        let users = try sut.getUsers()
        XCTAssertEqual(users, [])
    }
    
    func test_saveUser_savesUser() throws {
        let sut = CodableUserStore(storeURL: testSpecificURL())
        let user = anyUser()
        try sut.createUser(email: user.email, hashedPassword: user.hashedPassword)
        let users = try sut.getUsers()
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.email, user.email)
        XCTAssertEqual(users.first?.hashedPassword, user.hashedPassword)
    }
    
    func test_findUserByEmail_returnsUserIfExists() throws {
        let sut = CodableUserStore(storeURL: testSpecificURL())
        try sut.createUser(email: "hi@crisfe.im", hashedPassword: "any password")
        let foundUser = try sut.findUser(byEmail: "hi@crisfe.im")
        XCTAssertEqual(foundUser?.email, "hi@crisfe.im")
        XCTAssertEqual(foundUser?.hashedPassword, "any password")
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func testSpecificURL() -> URL {
        cachesDirectory().appendingPathComponent("\(type(of: self)).json")
    }
}


// Tests/Integration/AppTests.swift
import MinimalAuthExample
import Hummingbird
import HummingbirdTesting
import XCTest
import GenericAuth

final class AppTests: XCTestCase, @unchecked Sendable {
    
    override func setUp() {
        try? FileManager.default.removeItem(at: testSpecificURL())
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testSpecificURL())
    }
    
    func testApp() async throws {
        let userStoreURL = testSpecificURL().appendingPathComponent("users.json")
        let recipeStoreURL = testSpecificURL().appendingPathComponent("recipes.json")
        
        let userStore = CodableUserStore(storeURL: userStoreURL)
        let recipeStore = CodableRecipeStore(storeURL: recipeStoreURL)
    
        let app = await AppComposer.execute(
            with: .init(),
            secretKey: "my secret key that should come from deployment environment",
            userStore: userStore,
            recipeStore: recipeStore
        )
        
        try await app.test(.router) { client in
            try await assertPostRegisterSucceeds(client, email: "hi@crisfe.im", password: "123456")
            
            let token = try await assertPostLoginSucceeds(client, email: "hi@crisfe.im", password: "123456")
            
            let recipesState0 = try await assertGetRecipesSucceeds(client, accessToken: token)
            XCTAssertEqual(recipesState0, [])
            
            let recipe = try await assertPostRecipeSucceeds(client, accessToken: token, request: CreateRecipeRequest(title: "Test recipe"))
            
            let recipesState1 = try await assertGetRecipesSucceeds(client, accessToken: token)
            XCTAssertEqual(recipesState1, [recipe])
        }
    }
}
    
private extension AppTests {
    func assertPostRegisterSucceeds(_ client: TestClientProtocol, email: String, password: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        
        try await client.execute(
            uri: "/register",
            method: .post,
            headers: [.init("Content-Type")!: "application/json"],
            body: try bufferFrom(AuthRequest(email: email, password: password))
        ) { response in
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: response.body)
            XCTAssertFalse(tokenResponse.token.isEmpty, file: file, line: line)
            XCTAssertEqual(response.status, .ok, file: file, line: line)
        }
    }
    
    func assertPostLoginSucceeds(_ client: TestClientProtocol, email: String, password: String, file: StaticString = #filePath, line: UInt = #line) async throws -> String {
        try await client.execute(
            uri: "/login",
            method: .post,
            headers: [.init("Content-Type")!: "application/json"],
            body: try bufferFrom(AuthRequest(email: email, password: password))
        ) { response in
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: response.body)
            XCTAssertFalse(tokenResponse.token.isEmpty, file: file, line: line)
            XCTAssertEqual(response.status, .ok, file: file, line: line)
            return tokenResponse.token
        }
    }
    
    func assertPostRecipeSucceeds(_ client: TestClientProtocol, accessToken: String, request: CreateRecipeRequest, file: StaticString = #filePath, line: UInt = #line) async throws -> Recipe {
        try await client.execute(
            uri: "/recipes",
            method: .post,
            headers: [
                .init("Content-Type")!: "application/json",
                .init("Authorization")!: "Bearer \(accessToken)"
            ],
            body: try bufferFrom(request)
        ) { response in
            try JSONDecoder().decode(Recipe.self, from: response.body)
        }
    }
    
    func assertGetRecipesSucceeds(_ client: TestClientProtocol, accessToken: String, file: StaticString = #filePath, line: UInt = #line) async throws -> [Recipe] {
        try await client.execute(
            uri: "/recipes",
            method: .get,
            headers: [
                .init("Content-Type")!: "application/json",
                .init("Authorization")!: "Bearer \(accessToken)"
            ]
        ) { response in
            return try JSONDecoder().decode([Recipe].self, from: response.body)
        }
    }
}

extension AppTests {
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func testSpecificURL() -> URL {
        cachesDirectory().appendingPathComponent("\(type(of: self))")
    }
}

private func bufferFrom<T: Encodable>(_ payload: T) throws -> ByteBuffer {
    let data = try JSONEncoder().encode(payload)
    var buffer = ByteBufferAllocator().buffer(capacity: data.count)
    buffer.writeBytes(data)
    return buffer
}


// Tests/UseCases/Auth/AuthTestCaseDoubles.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


import XCTest
import MinimalAuthExample

class UserStoreSpy: UserStore {
    private(set) var messages = [Message]()
    
    enum Message: Equatable {
        case findUser(byEmail: String)
        case saveUser(email: String, hashedPassword: String)
    }
    
    func createUser(email: String, hashedPassword: String) throws -> UUID {
        messages.append(.saveUser(email: email, hashedPassword: hashedPassword))
        return UUID()
    }
    
    func findUser(byEmail email: String) throws -> User? {
        messages.append(.findUser(byEmail: email))
        return nil
    }
}

struct UserStoreStub: UserStore {
    let findUserResult: Result<User?, Error>
    let saveResult: Result<Void, Error>
    func findUser(byEmail email: String) throws -> User? {
        try findUserResult.get()
    }
    
    func createUser(email: String, hashedPassword: String) throws -> UUID {
        try saveResult.get()
        return UUID()
    }
}


// Tests/UseCases/Auth/LoginControllerTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import XCTest
import GenericAuth

class LoginControllerTests: XCTestCase {
    
    func test_login_deliversErrorOnUserFinder() async throws {
        let sut = makeSUT(userFinder: { _ in throw self.anyError() })
        await XCTAssertThrowsErrorAsync(try await sut.login(email: "any-email", password: "any-password"))
    }
    
    func test_login_deliversErrorOnNotFoundUser() async throws {
        let sut = makeSUT(userFinder: { _ in return nil })
        await XCTAssertThrowsErrorAsync(try await sut.login(email: "any-email", password: "any-password")) { error in
            XCTAssertTrue(error is NotFoundUserError)
        }
    }
    
    func test_login_deliversErrorOnInvalidEmail() async throws {
        let sut = makeSUT(userFinder: { _ in self.anyUser() }, emailValidator: { _ in false })
        await XCTAssertThrowsErrorAsync(try await sut.login(email: "any-email", password: "any-password")) { error in
            XCTAssertTrue(error is InvalidEmailError)
        }
    }
    
    func test_login_deliversErrorOnInvalidPassword() async throws {
        let sut = makeSUT(userFinder: { _ in self.anyUser() }, passwordValidator: { _ in false })
        await XCTAssertThrowsErrorAsync(try await sut.login(email: "any-email", password: "any-password")) { error in
            XCTAssertTrue(error is InvalidPasswordError)
        }
    }
    
    func test_login_deliversErrorOnPasswordVerifierError() async throws {
        let sut = makeSUT(userFinder: { _ in self.anyUser() }, passwordVerifier: { _, _ in throw self.anyError() })
        await XCTAssertThrowsErrorAsync(try await sut.login(email: "any-email", password: "any-password"))
    }
    
    func test_login_deliversErrorOnIncorrectPassword() async throws {
        let sut = makeSUT(userFinder: { _ in self.anyUser() }, passwordVerifier: { _, _ in false })
        await XCTAssertThrowsErrorAsync(try await sut.login(email: "any-email", password: "any-password")) { error in
            XCTAssertTrue(error is IncorrectPasswordError)
        }
    }
    
    func test_login_deliversProvidedTokenOnCorrectCredentialsAndFoundUser() async throws {
        let sut = makeSUT(userFinder: { _ in self.anyUser() }, tokenProvider: { _,_ in "any-provided-token" })
        let token = try await sut.login(email: "any-email", password: "any-password")
        XCTAssertEqual(token, "any-provided-token")
    }
    
    func test_login_passwordIsValidatedWithPasswordValidator() async throws {
        var password: String?
        let sut = makeSUT(passwordValidator: {
            password = $0
            return true
        })
        
        _ = try? await sut.login(email: "any email", password: "any password")
        XCTAssertEqual(password, "any password")
    }
    
    func test_login_emailIsValidatedWithEmailValidator() async throws {
        var email: String?
        let sut = makeSUT(emailValidator: {
            email = $0
            return true
        })
        
        _ = try? await sut.login(email: "any email", password: "any password")
        XCTAssertEqual(email, "any email")
    }
    
    func makeSUT(
        userFinder: @escaping LoginController<UUID>.UserFinder = { _ in nil },
        emailValidator: @escaping EmailValidator = { _ in true },
        passwordValidator: @escaping PasswordValidator = { _ in true },
        tokenProvider: @escaping AuthTokenProvider<UUID> = { _,_ in "any-token" },
        passwordVerifier: @escaping PasswordVerifier = { _,_ in true }
    ) -> LoginController<UUID> {
        return LoginController<UUID>(
            userFinder: userFinder,
            emailValidator: emailValidator,
            passwordValidator: passwordValidator,
            tokenProvider: tokenProvider,
            passwordVerifier: passwordVerifier
        )
    }
    
    
    func anyUser() -> LoginController<UUID>.User {
        .init(id: UUID(), hashedPassword: "any hashed password")
    }
}


// Tests/UseCases/Auth/RegisterControllerTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 27/6/25.

import XCTest
import GenericAuth

class RegisterControllerTests: XCTestCase {

    func test_register_deliversErrorOnStoreSaveError() async throws {
        let sut = makeSUT(userMaker: { _,_ in throw self.anyError() }, userExists: { _ in true })
        await XCTAssertThrowsErrorAsync(try await sut.register(email: "any-email", password: "any-password"))
    }
    
    func test_register_deliversErrorOnAlreadyExistingUser() async throws {
        let sut = makeSUT(userMaker: { _,_ in self.anyUser().id }, userExists: { _ in true })
        await XCTAssertThrowsErrorAsync(try await sut.register(email: "any-email", password: "any-password")) { error in
            XCTAssertTrue(error is UserAlreadyExists)
        }
    }
    
    func test_register_deliversErrorOnInvalidEmail() async throws {
        let sut = makeSUT(userMaker: { _,_ in self.anyUser().id }, userExists: { _ in false }, emailValidator: { _ in false })
        await XCTAssertThrowsErrorAsync(try await sut.register(email: "any-email", password: "any-password")) { error in
            
            XCTAssertTrue(error is InvalidEmailError)
        }
    }
    
    func test_register_deliversErrorOnInvalidPassword() async throws {
        let sut = makeSUT(userMaker: { _,_ in self.anyUser().id }, userExists: { _ in false }, passwordValidator: { _ in false })
        await XCTAssertThrowsErrorAsync(try await sut.register(email: "any-email", password: "any-password")) { error in
            XCTAssertTrue(error is InvalidPasswordError)
        }
    }
    
    func test_register_deliversProvidedTokenOnNewUserValidCredentialsAndUserStoreSuccess() async throws {
        let sut = makeSUT(userMaker: { _,_ in self.anyUser().id }, userExists: { _ in false }, tokenProvider: { _,_ in "any-provided-token" })
        let token = try await sut.register(email: "any-email", password: "any-password")
        XCTAssertEqual(token, "any-provided-token")
    }
    
    func test_register_deliversErrorOnHasherError() async throws {
        let sut = makeSUT(userMaker: { _,_ in self.anyUser().id }, userExists: { _ in true }, hasher: { _ in throw self.anyError() })
        await XCTAssertThrowsErrorAsync(try await sut.register(email: "any-email", password: "any-password"))
    }
    
    
    func makeSUT(
        userMaker: @escaping UserMaker<UUID>,
        userExists: @escaping UserExists,
        emailValidator: @escaping EmailValidator = { _ in true },
        passwordValidator: @escaping PasswordValidator = { _ in true },
        tokenProvider: @escaping AuthTokenProvider<UUID> = { _,_ in "any" },
        hasher: @escaping PasswordHasher = { $0 }
    ) -> RegisterController<UUID> {
        return RegisterController<UUID>(
            userMaker: userMaker,
            userExists: userExists,
            emailValidator: emailValidator,
            passwordValidator: passwordValidator,
            tokenProvider: tokenProvider,
            passwordHasher: hasher,
        )
    }
}


// Tests/UseCases/Helpers/XCTAssertThrowsErrorAsync.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.


import XCTest
import MinimalAuthExample

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown, but no error was thrown. \(message())", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}


// Tests/UseCases/Helpers/XCTestCaseHelpers.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import XCTest
import MinimalAuthExample

extension XCTestCase {
    
    func anyError() -> NSError {
        NSError(domain: "any error", code: 0)
    }
    
    func anyRecipe() -> Recipe {
        Recipe(id: UUID(), userId: UUID(), title: "any-title")
    }
    
    func anyUser() -> User {
        User(id: UUID(), email: "any-user@email.com", hashedPassword: "any-hashed-password")
    }
}


// Tests/UseCases/Recipes/CreateRecipesUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import XCTest
import MinimalAuthExample
import GenericAuth

class CreateRecipesUseCaseTests: XCTestCase {
    func test_postRecipe_deliversErrorOnStoreError() async throws {
        let store = RecipeStoreStub(result: .failure(anyError()))
        let sut = makeSUT(store: store)
        await XCTAssertThrowsErrorAsync(try await sut.postRecipe(accessToken: "any valid access token", title: "Fried chicken")) { error in
            XCTAssertEqual(error as NSError, anyError())
        }
    }
    
    func test_postRecipe_deliversErrorOnInvalidAccessToken() async throws {
        let store = RecipeStoreStub(result: .success(anyRecipe()))
        let sut = makeSUT(store: store, tokenVerifier: { _ in throw self.anyError() })
        
        await XCTAssertThrowsErrorAsync(try await sut.postRecipe(accessToken: "any valid access token", title: "Fried chicken")) { error in
            XCTAssertEqual(error as NSError, anyError())
        }
    }
    
    func test_postRecipe_deliversRecipeOnSuccess() async throws {
        let stubbedRecipe = anyRecipe()
        let store = RecipeStoreStub(result: .success(stubbedRecipe))
        let sut = makeSUT(store: store)
        
        let recipe = try await sut.postRecipe(accessToken: "any valid access token", title: "Fried chicken")
        
        XCTAssertEqual(recipe, stubbedRecipe)
    }
    
    func test_postRecipe_createsRecipeWithUserIdFromToken() async throws {
        let stubbedUserId = UUID()
        let store = RecipeStoreSpy(result: .success(anyRecipe()))
        let sut = makeSUT(store: store, tokenVerifier: { _ in stubbedUserId })
        
        let _ = try await sut.postRecipe(accessToken: "any valid access token", title: "Fried chicken")
        
        XCTAssertEqual(store.capturedMessages, [
            .init(userId: stubbedUserId, title: "Fried chicken")
        ])
    }
    
    func makeSUT(
        store: RecipeStore,
        tokenVerifier: @escaping AuthTokenVerifier = { _ in UUID() },
    ) -> RecipesController {
        RecipesController(store: store, tokenVerifier: tokenVerifier)
    }
    
    struct RecipeStoreStub: RecipeStore {
        let result: Result<Recipe, Error>
        
        func getRecipes() throws -> [Recipe] {
            fatalError("should never be called within test case context")
        }
        
        func createRecipe(userId: UUID, title: String) throws -> Recipe {
            try result.get()
        }
    }
}


// Tests/UseCases/Recipes/GetRecipesUseCaseTests.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import XCTest
import MinimalAuthExample
import GenericAuth

class GetRecipesUseCaseTests: XCTestCase {
   
    func test_getRecipes_deliversErrorOnStoreError() async throws {
        let store = RecipeStoreStub(result: .failure(anyError()))
        let sut = makeSUT(store: store)
        await XCTAssertThrowsErrorAsync(try await sut.getRecipes(accessToken: "any valid access token"))
    }
    
    func test_getRecipes_deliversErrorOnTokenVerifierError() async throws {
        let store = RecipeStoreStub(result: .success([]))
        let sut = makeSUT(store: store, tokenVerifier: { _ in throw self.anyError() })
        await XCTAssertThrowsErrorAsync(try await sut.getRecipes(accessToken: "any invalid access token"))
    }
    
    func test_getRecipes_deliversErrorOnInvalidAccessToken() async throws {
        let store = RecipeStoreStub(result: .success([]))
        let sut = makeSUT(store: store, tokenVerifier: { _ in throw self.anyError() })
        await XCTAssertThrowsErrorAsync(try await sut.getRecipes(accessToken: "any invalid access token"))
    }
    
    func test_getRecipes_deliversUserRecipesOnCorrectAccessToken() async throws {
        let user = User(id: UUID(), email: "any@email.com", hashedPassword: "1234")
        let otherUserRecipes = [anyRecipe(), anyRecipe(), anyRecipe()]
        let userRecipes = [Recipe(id: UUID(), userId: user.id, title: "any-title")]
        let store = RecipeStoreStub(result: .success(otherUserRecipes + userRecipes))
        let sut = makeSUT(store: store, tokenVerifier: { _ in user.id })
        let recipes = try await sut.getRecipes(accessToken: "anyvalidtoken")
        XCTAssertEqual(userRecipes, recipes)
    }
    
    func makeSUT(
        store: RecipeStore,
        tokenVerifier: @escaping AuthTokenVerifier = { _ in UUID() },
    ) -> RecipesController {
        return RecipesController(
            store: store,
            tokenVerifier: tokenVerifier,
        )
    }
    
    struct RecipeStoreStub: RecipeStore {
        let result: Result<[Recipe], Error>
        
        func getRecipes() throws -> [Recipe] {
            try result.get()
        }
        
        func createRecipe(userId: UUID, title: String) throws -> Recipe {
            fatalError("should not be called in current test context")
        }
    }
}


// Tests/UseCases/Recipes/RecipesTestCaseDoubles.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation
import MinimalAuthExample

class RecipeStoreSpy: RecipeStore {
    let result: Result<Recipe, Error>
    struct CreateRecipeCommand: Equatable {
        let userId: UUID
        let title: String
    }
    
    var capturedMessages = [CreateRecipeCommand]()
    
    init(result: Result<Recipe, Error>) {
        self.result = result
    }
    
    func getRecipes() throws -> [Recipe] {
        fatalError("should never be called within test case context")
    }
    
    func createRecipe(userId: UUID, title: String) throws -> Recipe {
        capturedMessages.append(.init(userId: userId, title: title))
        return try result.get()
    }
}

