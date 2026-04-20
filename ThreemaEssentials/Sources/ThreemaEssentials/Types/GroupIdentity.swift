import CocoaLumberjackSwift
import Foundation

public struct GroupIdentity: Equatable, Hashable, CustomStringConvertible, Sendable, Codable {
    public enum Error: Swift.Error {
        case invalidCreatorIdentityLength
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, creator
    }
    
    /// Expected length of `id`
    public static let idLength = 8

    public let id: Data
    public let creator: ThreemaIdentity

    public init(id: Data, creator: ThreemaIdentity) {
        if id.count != GroupIdentity.idLength {
            assertionFailure("Tried to create a GroupIdentity with id length of \(id.count)")
            DDLogError("Tried to create a GroupIdentity with id length of \(id.count)")
        }

        self.id = id
        self.creator = creator
    }
    
    public init(id: Data, creatorID: String) {
        self.init(id: id, creator: ThreemaIdentity(creatorID))
    }

    // MARK: - CustomStringConvertible
    
    public var description: String {
        "id: \(id.hexString) creator: \(creator)"
    }
}
