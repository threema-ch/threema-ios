import ThreemaEssentials

extension LibthreemaGroupIdentity {
    public init(groupIdentity: ThreemaEssentials.GroupIdentity) throws {
        try self.init(
            // swiftformat:disable acronyms
            groupId: groupIdentity.id.littleEndian(),
            creatorIdentity: LibthreemaThreemaID(threemaIdentity: groupIdentity.creator)
        )
    }
}
