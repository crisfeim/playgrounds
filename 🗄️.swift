// Codility:
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

// EnvironmentBindings:
    import SwiftUI
    
    private struct CartCountKey: EnvironmentKey {
        static let defaultValue: Binding<Int> = .constant(0)
    }
    
    extension EnvironmentValues {
        var cartCount: Binding<Int> {
            get { self[CartCountKey.self] }
            set { self[CartCountKey.self] = newValue }
        }
    }
    
    struct Home: View {
        @State var cartCount = 0
        
        var body: some View {
            VStack {
                CartList().environment(\.cartCount, $cartCount)
                Button("Add item to cart") { cartCount += 1 }
            }
        }
    }
    
    struct CartList: View {
        @EnvironmentBinding(\.cartCount) private var count
        var body: some View {
            Text(count.description)
        }
    }
    
    @propertyWrapper
    struct EnvironmentBinding<Value>: DynamicProperty {
        @Environment private var binding: Binding<Value>
        init(_ keyPath: KeyPath<EnvironmentValues, Binding<Value>>) {
            self._binding = Environment(keyPath)
        }
        var wrappedValue: Value {
            get { binding.wrappedValue }
            nonmutating set { binding.wrappedValue = newValue }
        }
        var projectedValue: Binding<Value> {
            binding
        }
    }
// CrossCuttingConcerns:
	    import Foundation
    
    public typealias Guid = String
    
    
    public protocol IBookingService {
        func BookFlight(passengerId: Guid, flightId: Guid)
    }
    
    public protocol ICheckInService {
        func PerformCheckIn(ticketId: Guid)
    }
    
    public protocol IMaintenanceService {
        func ScheduleRepair(planeId: Guid)
    }
    
    public protocol IStatusRegistry {
        func IsSystemLocked() -> Bool
    }
    
    
    struct BookingService: IBookingService {
        func BookFlight(passengerId: Guid, flightId: Guid) {}
    }
    
    struct CheckingInService: ICheckInService {
        func PerformCheckIn(ticketId: Guid) {} 
    }
    
    struct MaintenanceService: IMaintenanceService {
        func ScheduleRepair(planeId: Guid) {}
    }
    
    struct StatusRegistry: IStatusRegistry {
        func IsSystemLocked() -> Bool {true}
    }
    
    func isLockedDecorator<each Param>(_ decoratee: @escaping (repeat each Param) -> Void, _ isLocked: () -> Bool) -> (repeat each Param) throws -> Void {
        if isLocked() { return decoratee }
        return { (params: repeat each Param) in throw NSError(domain: "testng", code: 0) }
    }
    
    struct System {
        let bookFlight: (Guid, Guid) throws -> Void
        let performCheckIn: (Guid) throws -> Void
        let scheduleRepair: (Guid) throws -> Void
    }
    
    func composer() -> System {
        let status         = StatusRegistry()
        let bookFlight     = BookingService().BookFlight(passengerId:flightId:)
        let performCheckIn = CheckingInService().PerformCheckIn(ticketId:)
        let scheduleRepair = MaintenanceService().ScheduleRepair(planeId:)
        
        return System(
            bookFlight    : isLockedDecorator(bookFlight    , status.IsSystemLocked),
            performCheckIn: isLockedDecorator(performCheckIn, status.IsSystemLocked),
            scheduleRepair: isLockedDecorator(scheduleRepair, status.IsSystemLocked)
        )
    }
