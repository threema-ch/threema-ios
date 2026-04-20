import Foundation
import UIKit
@testable import GroupCalls

final class MockGroupCallBundleUtil: GroupCallBundleUtilProtocol {
    func image(named: String) -> UIImage {
        UIImage(systemName: "questionmark.square.dashed")!
    }
    
    func localizedString(for key: String) -> String {
        ""
    }
}
