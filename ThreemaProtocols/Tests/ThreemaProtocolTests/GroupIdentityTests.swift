import Testing
import ThreemaEssentials
@testable import ThreemaProtocols

@Test("Initialize group identity with empty common group identity")
func testGroupIdentityWithEmptyCommonGroupIdentity() throws {
    let commonGroupIdentity = Common_GroupIdentity()
    
    try #require(throws: GroupIdentity.Error.invalidCreatorIdentityLength, performing: {
        try GroupIdentity(commonGroupIdentity: commonGroupIdentity)
    })
}
