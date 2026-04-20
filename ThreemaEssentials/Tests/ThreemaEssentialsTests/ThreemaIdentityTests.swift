import Foundation
import Testing
@testable import ThreemaEssentials

@Suite("Threema ID Codable")
struct ThreemaIdentityCodableTests {
    
    @Test("Encode Threema ID")
    func encodeThreemaIdentity() throws {
        let rawIdentity = "ABCDEFGH"
        
        let expectedEncodedString = #"{"string":"\#(rawIdentity)"}"#
        
        let threemaIdentity = ThreemaIdentity(rawIdentity)
        let encodedThreemaIdentity = try JSONEncoder().encode(threemaIdentity)
        let encodedThreemaIdentityString = String(data: encodedThreemaIdentity, encoding: .utf8)
        
        #expect(encodedThreemaIdentityString == expectedEncodedString)
    }
    
    @Test("Decode Threema ID")
    func decodeThreemaIdentity() throws {
        let rawIdentity = "ABCDEFGH"
        
        let expectedThreemaIdentity = ThreemaIdentity(rawIdentity)
        
        let encodedString = #"{"string":"\#(rawIdentity)"}"#
        let decodedThreemaIdentity = try JSONDecoder().decode(ThreemaIdentity.self, from: Data(encodedString.utf8))
        
        #expect(decodedThreemaIdentity == expectedThreemaIdentity)
    }
}
