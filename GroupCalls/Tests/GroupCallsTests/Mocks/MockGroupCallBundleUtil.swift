import Foundation
import UIKit
@testable import GroupCalls

final class MockGroupCallBundleUtil: GroupCallBundleUtilProtocol {
    func image(named: String) -> UIImage {
        UIImage(systemName: "questionmark.square.dashed")!
    }
    
    /// Returns the key itself, so that tests can assert which string was requested
    func localizedString(for key: String) -> String {
        key
    }
}
