import XCTest
@testable import ThreemaEssentials

final class ThreemaEssentialsTests: XCTestCase {
    func testTypeThreemaIdentityDescription() throws {
        let identityString = "ECHOECHO"

        let threemaIdentity = ThreemaIdentity(identityString)

        XCTAssertEqual(threemaIdentity.rawValue, identityString)
        XCTAssertEqual(threemaIdentity.description, identityString)
    }

    func testTypeGroupIdentityDescription() throws {
        let groupID = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        let groupCreator = ThreemaIdentity("ECHOECHO")

        let groupIdentity = GroupIdentity(id: groupID, creator: groupCreator)

        XCTAssertEqual(groupIdentity.id, groupID)
        XCTAssertEqual(groupIdentity.creator, groupCreator)
        XCTAssertEqual(groupIdentity.description, "id: \(groupID.hexString) creator: \(groupCreator)")
    }
}
