import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class MetadataCoderTests: XCTestCase {
    private var myIdentityStoreA: MyIdentityStoreProtocol!
    private var myIdentityStoreB: MyIdentityStoreProtocol!
    
    private var publicKeyA: Data!
    private var publicKeyB: Data!
    
    override func setUp() {
        myIdentityStoreA = MyIdentityStoreMock(
            identity: "AAAAAAAA",
            secretKey: Data(base64Encoded: "2Hi7lA4boz9eLl0ozdeb2uKj2+i/wD2PUTRczwshp1Y=")!
        )
        myIdentityStoreB = MyIdentityStoreMock(
            identity: "BBBBBBBB",
            secretKey: Data(base64Encoded: "WE2g/Mu8jeGHMUX0pqyCP+ypW6gCu2xEBKESOyqgbn0=")!
        )
        
        publicKeyA = NaClCrypto.shared()!.derivePublicKey(fromSecretKey: myIdentityStoreA.clientKey)
        publicKeyB = NaClCrypto.shared()!.derivePublicKey(fromSecretKey: myIdentityStoreB.clientKey)
    }
    
    func testEncodeDecode() throws {
        let nickname = "John Doe"
        let messageID = Data(BytesUtility.toBytes(hexString: "0123456789abcdef")!)
        let createdAt = Date()
        
        let metadata = MessageMetadata(nickname: nickname, messageID: messageID, createdAt: createdAt)
        let nonce = (NaClCrypto.shared()?.randomBytes(kNonceLen))!
        let box = MetadataCoder(myIdentityStoreA).encode(metadata: metadata, nonce: nonce, publicKey: publicKeyB)!
        
        let metadataDecoded = try MetadataCoder(myIdentityStoreB).decode(nonce: nonce, box: box, publicKey: publicKeyA)
        
        XCTAssertEqual(metadataDecoded.nickname, nickname)
        XCTAssertEqual(metadataDecoded.messageID, messageID)
        
        // Ensure dates are equal to within 2 ms
        let diff = abs(metadataDecoded.createdAt!.timeIntervalSince1970 - createdAt.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(diff, 0.002)
    }
    
    func testOptionalFields() throws {
        let metadata = MessageMetadata(nickname: nil, messageID: nil, createdAt: nil)
        let nonce = (NaClCrypto.shared()?.randomBytes(kNonceLen))!
        let box = MetadataCoder(myIdentityStoreA).encode(metadata: metadata, nonce: nonce, publicKey: publicKeyB)!
        
        let metadataDecoded = try MetadataCoder(myIdentityStoreB).decode(nonce: nonce, box: box, publicKey: publicKeyA)
        
        XCTAssertNil(metadataDecoded.nickname)
        XCTAssertNil(metadataDecoded.messageID)
        XCTAssertNil(metadataDecoded.createdAt)
    }
}
