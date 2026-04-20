import Foundation

/// Holder for remote secret that is zeroized as soon as it is deinitialized (i.e. no more used)
final class RemoteSecret: @unchecked Sendable {
    // @unchecked Sendable is safe here as `rawValue` is never updated before deinitialization
    
    private(set) var rawValue: Data
    
    init(rawValue: Data) {
        self.rawValue = rawValue
    }
    
    deinit {
        rawValue.zeroize()
    }
}
