import Foundation
import GroupCalls
import ThreemaMacros

final class GroupCallBundleUtil: GroupCallBundleUtilProtocol {
    static let shared = GroupCallBundleUtil()

    // MARK: - Public Functions
    
    public func localizedString(for key: String) -> String {
        BundleUtil.localizedString(forKey: key)
    }
    
    func image(named name: String) -> UIImage {
        BundleUtil.imageNamed(name) ?? UIImage(systemName: "questionmark.square.dashed")!
    }
}
