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
