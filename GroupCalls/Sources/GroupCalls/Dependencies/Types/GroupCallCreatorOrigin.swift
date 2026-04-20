import Foundation
import ThreemaEssentials

/// Used to post system messages
public enum GroupCallCreatorOrigin {
    case db
    case local
    case remote(ThreemaIdentity)
}
