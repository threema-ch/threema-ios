import ThreemaEssentials
import ThreemaProtocols

extension Common_GroupIdentity {
    static func from(_ groupIdentity: GroupIdentity) -> Common_GroupIdentity {
        Common_GroupIdentity.with {
            $0.groupID = groupIdentity.id.paddedLittleEndian()
            $0.creatorIdentity = groupIdentity.creator.rawValue
        }
    }
}
