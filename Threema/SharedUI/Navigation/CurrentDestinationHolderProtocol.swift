protocol CurrentDestinationHolderProtocol<CurrentDestination>: AnyObject {
    associatedtype CurrentDestination
    
    var currentDestination: CurrentDestination? { get set }
    
    func resetCurrentDestination()
}

extension CurrentDestinationHolderProtocol {
    func resetCurrentDestination() {
        currentDestination = nil
    }
    
    func eraseToAnyDestinationHolder() -> AnyCurrentDestinationHolder<CurrentDestination> {
        AnyCurrentDestinationHolder(self)
    }
}

final class AnyCurrentDestinationHolder<Destination>: CurrentDestinationHolderProtocol {
    typealias CurrentDestination = Destination
    
    private let box: any CurrentDestinationHolderProtocol<Destination>
    
    var currentDestination: Destination? {
        get { box.currentDestination }
        set { box.currentDestination = newValue }
    }
    
    init<T: CurrentDestinationHolderProtocol>(_ holder: T) where T.CurrentDestination == Destination {
        self.box = WeakCurrentDestinationHolderBox(holder)
    }
    
    func resetCurrentDestination() {
        box.resetCurrentDestination()
    }
}

private final class WeakCurrentDestinationHolderBox<
    T: CurrentDestinationHolderProtocol
>: CurrentDestinationHolderProtocol {
    typealias Destination = T.CurrentDestination
    
    var currentDestination: T.CurrentDestination? {
        get {
            holder?.currentDestination
        }
        set {
            holder?.currentDestination = newValue
        }
    }
    
    weak var holder: T?
    
    init(_ holder: T) {
        self.holder = holder
    }
    
    func resetCurrentDestination() {
        holder?.resetCurrentDestination()
    }
}
