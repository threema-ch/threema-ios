public protocol DelegateFactory {
    associatedtype T
    associatedtype Delegate

    func make(with delegate: Delegate) -> T
}
