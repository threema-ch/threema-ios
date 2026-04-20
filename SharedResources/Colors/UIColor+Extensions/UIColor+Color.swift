import Foundation
import SwiftUI

extension UIColor {
    /// For use in SwiftUI
    public var color: Color {
        Color(self)
    }
    
    public var dark: UIColor {
        resolvedColor(with: .init(userInterfaceStyle: .dark))
    }
    
    public var light: UIColor {
        resolvedColor(with: .init(userInterfaceStyle: .light))
    }
}
