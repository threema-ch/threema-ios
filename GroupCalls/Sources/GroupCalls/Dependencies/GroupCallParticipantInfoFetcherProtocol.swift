import Foundation
import ThreemaEssentials
import UIKit

public protocol GroupCallParticipantInfoFetcherProtocol {
    
    /// Fetches the profile picture image of a contact for the given ThreemaIdentity
    /// - Parameter id: ThreemaIdentity
    /// - Returns: Profile picture or default placeholder image
    func fetchProfilePicture(for id: ThreemaIdentity) -> UIImage
    
    /// Fetches the display name of a contact for the given ThreemaIdentity
    /// - Parameter id: ThreemaIdentity
    /// - Returns: Display name (might also be the ID-string)
    func fetchDisplayName(for id: ThreemaIdentity) -> String
    
    /// Fetches the ID Color of a contact for the given ThreemaIdentity
    /// - Parameter id: ThreemaIdentity
    /// - Returns: ID Color or primary color
    func fetchIDColor(for id: ThreemaIdentity) -> UIColor
    
    /// Checks if a given `ThreemaIdentity` belongs to a member of a group
    /// - Parameters:
    ///   - identity: ThreemaIdentity to check
    ///   - groupID: GroupIdentity of group to check
    func isIdentity(_ identity: ThreemaIdentity, memberOfGroupWith groupID: GroupIdentity) -> Bool
}
