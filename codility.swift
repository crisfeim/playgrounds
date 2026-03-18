	import Foundation
	
	
	final class CatImageCell: UICollectionViewCell {
		
		private var imageView: UIImageView!
		private var currentPlaceholder: UIImage?
		
		convenience init(imageView: UIImageView) {
			self.init()
			self.imageView = imageView
		}
		
		override func prepareForReuse() {
			super.prepareForReuse()
			cleanImage()
			cleanIdentity()
		}
		
		func set(model: CatImageCellModel) {
			_set(model: ModelDecorator(model))
		}
		
		private func _set(model: CatImageCellModel) {
			captureModelIdentity(model.placeholderImage)
			setImage(model.placeholderImage)
			model.fetchCatImage { [weak self] result in
				self?.updateImage(from: result, ifMatches: model.placeholderImage)
			}
		}
		
		private func captureModelIdentity(_ placeholder: UIImage) {
			currentPlaceholder = placeholder
		}
		
		private func setImage(_ image: UIImage?) {
			dispatchOnMainThreadIfNeeded { [weak self] in
				self?.imageView.image = image
			}
		}
		
		private func updateImage(from result: CatImageResult, ifMatches model: UIImage) {
			guard matchesModelIdentity(model), case .success(let image) = result else { return }
			setImage(image)
		}
		
		private func matchesModelIdentity(_ placeholder: UIImage) -> Bool {
			currentPlaceholder == placeholder
		}
		
		private func cleanImage() {
			setImage(nil)
		}
		
		private func cleanIdentity() {
			currentPlaceholder = nil
		}
	}
	
	private typealias CatImageResult  = Result<UIImage, ImageFetchingError>
	private typealias CatImageFetcher = (@escaping (CatImageResult) -> Void) -> Void
	
	private struct ModelDecorator: CatImageCellModel {
		private let decoratee: CatImageCellModel
		
		init(_ decoratee: CatImageCellModel) {
			self.decoratee = decoratee
		}
		
		var placeholderImage: UIImage {
			decoratee.placeholderImage
		}
		
		func fetchCatImage(completion: @escaping (CatImageResult) -> Void) {
			withRetry(2, completion: completion)
		}
	
		private func withRetry(_ retries: UInt, completion: @escaping (CatImageResult) -> Void) { 
			decoratee.fetchCatImage { result in
				switch result {
					case .failure(let error) 
					where error == .timeout && retries > 0 : withRetry(retries - 1, completion: completion)
					default: completion(result)
				}
			}
		}
	}
	
	private func dispatchOnMainThreadIfNeeded(block: @escaping () -> Void) {
		guard Thread.isMainThread else {
			return DispatchQueue.main.async { block() }
		}
		block()
	}
	
	
	
	
	
	import Foundation
	
	
	
	
	class UICollectionViewCell {
		func prepareForReuse() {}
	}
	
	class UIImageView {
		var image: UIImage?
	}
	
	
	enum ImageFetchingError: Error {
		case timeout
		case unknown
	}
	
	struct UIImage: Equatable {}
	protocol CatImageCellModel {
		var placeholderImage: UIImage { get }
		func fetchCatImage(completion: @escaping (Result<UIImage, ImageFetchingError>) -> Void)
	}
	
	
	
