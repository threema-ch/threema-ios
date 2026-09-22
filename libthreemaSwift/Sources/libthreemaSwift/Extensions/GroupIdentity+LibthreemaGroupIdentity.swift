import Foundation
import ThreemaEssentials

extension ThreemaEssentials.GroupIdentity {
    public init(libthreemaGroupIdentity: GroupIdentity) {
        self.init(
            // swiftformat:disable:next acronyms
            id: libthreemaGroupIdentity.groupId.littleEndianData,
            creator: ThreemaIdentity(libthreemaThreemaID: libthreemaGroupIdentity.creatorIdentity)
        )
    }
}
