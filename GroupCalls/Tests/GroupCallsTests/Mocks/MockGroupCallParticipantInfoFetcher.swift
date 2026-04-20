import Foundation
import ThreemaEssentials
import UIKit
@testable import GroupCalls

final class MockGroupCallParticipantInfoFetcher { }

// MARK: - GroupCallParticipantInfoFetcherProtocol

extension MockGroupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol {
    func fetchProfilePicture(for id: ThreemaEssentials.ThreemaIdentity) -> UIImage {
        UIImage(systemName: "person.fill")!
    }
    
    func fetchDisplayName(for id: ThreemaEssentials.ThreemaIdentity) -> String {
        id.rawValue
    }
    
    func fetchIDColor(for id: ThreemaEssentials.ThreemaIdentity) -> UIColor {
        UIColor.red
    }
    
    func isIdentity(_ identity: ThreemaIdentity, memberOfGroupWith groupID: GroupIdentity) -> Bool {
        true
    }
}
