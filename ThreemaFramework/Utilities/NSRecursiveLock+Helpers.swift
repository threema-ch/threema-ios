import Foundation

// MARK: - NSRecursiveLock + Helpers

extension NSRecursiveLock {
    
    public func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { self.unlock() }
        
        return body()
    }
    
    public func withLockGet<T>(_ body: @autoclosure () -> T) -> T {
        lock()
        defer { self.unlock() }
        
        return body()
    }
}
