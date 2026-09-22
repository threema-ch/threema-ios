protocol Factory {
    associatedtype T
    
    func make() -> T
}
