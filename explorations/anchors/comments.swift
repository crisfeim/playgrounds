struct Comment {
	let x: Double 
	let y: Double
	let username: String
	let content: String
}

protocol CommentsLoader {
	func load() async throws -> [Comment]
}

struct CommentCommand {
	let x: Double 
	let y: Double
	let username: String
	let content: String
}

protocol CommentsCreator {
	func create(_ cmd: CommentCommand) async throws -> Comment
}

typealias CommentsStore = CommentsLoader & CommentsCreator

typealias Observable<T> = (T) -> Void

class CommentsViewModel {
    let store: CommentsStore
	var onLoadingChange: Observable<Bool>?
	var onCommentsChange: Observable<[Comment]>?
	var onCommentCreation: Observable<Comment?>?
	init(store: CommentsStore) { self.store = store }
	
	func load() async throws {
		onLoadingChange?(true)
		let comments = try await store.load()
		onCommentsChange?(comments)
		onLoadingChange?(false)
	}
	
	func create(_ cmd: CommentCommand) async throws {
		onLoadingChange?(true)
		let comment = try? await store.create(cmd)
		onLoadingChange?(false)
		onCommentCreation?(comment)
	}
}

protocol CommentsView {
	var onLoading: (() -> Void)? { get set }
	func load() async throws
	func setLoading(_ bool: Bool)
	func addComment(_ comment: Comment)
	func addComments(_ comments: [Comment])
}

func CommentsComposer(_ store: CommentsStore, vc: CommentsView) -> CommentsView {
	var vc = vc
	let vm = CommentsViewModel(store: store)
	vc.onLoading = { Task { try? await vc.load() }}
	vm.onLoadingChange = vc.setLoading
	vm.onCommentsChange = vc.addComments
	vm.onCommentCreation = { $0.map(vc.addComment) }
	return vc
}

class MockStore: CommentsStore {
	func load() async throws -> [Comment] {
		[ ] // mock data
	}
	func create(_ cmd: CommentCommand) async throws -> Comment {
		.init(x: cmd.x, y: cmd.y, username: cmd.username, content: cmd.content)
	}
}
