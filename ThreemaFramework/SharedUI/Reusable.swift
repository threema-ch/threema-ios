import UIKit

/// Protocol for a constant identifier for reusable views (e.g. cells)
public protocol Reusable {
    /// Reuse identifier
    static var reuseIdentifier: String { get }
}

// Default implementation of `Reusable` for all UIView decedents
extension Reusable where Self: UIView {
    public static var reuseIdentifier: String {
        String(describing: self)
    }
}
