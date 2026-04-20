import Foundation
import Testing
@testable import ThreemaEssentials

@Suite("Group Identity Codable")
struct GroupIdentityCodableTests {
    
    @Test("Encode Group Identity")
    func encodeGroupIdentity() throws {
        let rawGroupIdentity = Data(repeating: 1, count: GroupIdentity.idLength)
        let rawIdentity = "ABCDEFGH"
        
        let expectedEncodedString =
            #"{"creator":{"string":"\#(rawIdentity)"},"id":"\#(rawGroupIdentity.base64EncodedString())"}"#
        
        let groupIdentity = GroupIdentity(id: rawGroupIdentity, creator: ThreemaIdentity(rawIdentity))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedGroupIdentity = try encoder.encode(groupIdentity)
        let encodedGroupIdentityString = String(data: encodedGroupIdentity, encoding: .utf8)
        
        #expect(encodedGroupIdentityString == expectedEncodedString)
    }
    
    @Test("Decode Group Identity")
    func decodeGroupIdentity() throws {
        let rawGroupIdentity = Data(repeating: 2, count: GroupIdentity.idLength)
        let rawIdentity = "ABCDEFGH"

        let expectedGroupIdentity = GroupIdentity(id: rawGroupIdentity, creator: ThreemaIdentity(rawIdentity))
        
        let encodedString =
            #"{"creator":{"string":"\#(rawIdentity)"},"id":"\#(rawGroupIdentity.base64EncodedString())"}"#
        let decodedGroupIdentity = try JSONDecoder().decode(GroupIdentity.self, from: Data(encodedString.utf8))
        
        #expect(decodedGroupIdentity == expectedGroupIdentity)
    }
}
