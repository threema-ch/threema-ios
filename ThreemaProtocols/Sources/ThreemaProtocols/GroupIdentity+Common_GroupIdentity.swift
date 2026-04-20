import ThreemaEssentials

extension GroupIdentity {
    /// Create new group identity from `Common_GroupIdentity`
    /// - Parameter commonGroupIdentity: Common Group Identity to use
    /// - Throws: `GroupIdentity.Error` if `commonGroupIdentity` is not a valid group identity
    public init(commonGroupIdentity: Common_GroupIdentity) throws {
        // `commonGroupIdentity.groupID` will always be valid, also if it is 0
        
        guard commonGroupIdentity.creatorIdentity.count == ThreemaIdentity.length else {
            throw Error.invalidCreatorIdentityLength
        }
        
        self.init(
            id: commonGroupIdentity.groupID.littleEndianData,
            creator: ThreemaIdentity(commonGroupIdentity.creatorIdentity)
        )
    }
    
    public var asCommonGroupIdentity: Common_GroupIdentity {
        var commonGroupIdentity = Common_GroupIdentity()
        commonGroupIdentity.groupID = id.paddedLittleEndian()
        commonGroupIdentity.creatorIdentity = creator.rawValue
        return commonGroupIdentity
    }
}
