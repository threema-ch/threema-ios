import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

// MARK: - WorkDataResponse

/// Top-level response from the Work API `fetch2` endpoint.
struct WorkDataResponse: Decodable {
    let checkInterval: Int?
    let directory: WorkDirectory?
    let org: WorkOrganization?
    let logo: WorkLogo?
    let support: String?
    let contacts: [WorkContact]?
    let time: UInt64?

    // MARK: - WorkDirectory
    
    struct WorkDirectory: Decodable {
        let enabled: Bool
        let cat: [String: String]?
        
        enum CodingKeys: String, CodingKey {
            case enabled, cat
        }

        // We need a special decoder, because the fetch2 endpoint once sent an array instead of a dictionary, when
        // directory was disabled.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try container.decode(Bool.self, forKey: .enabled)

            if enabled {
                cat = try container.decode([String: String].self, forKey: .cat)
            }
            else {
                cat = nil
            }
        }
    }
    
    // MARK: - WorkOrganization
    
    struct WorkOrganization: Decodable {
        let name: String?
    }
    
    // MARK: - WorkLogo
    
    struct WorkLogo: Decodable {
        let light: String?
        let dark: String?
    }
    
    // MARK: - WorkContact
    
    struct WorkContact: Decodable {
        let id: String
        let pk: String
        let first: String?
        let last: String?
        let csi: String?
        let jobTitle: String?
        let department: String?
        let availability: String?
        
        private var workAvailabilityStatus: WorkAvailabilityStatus? {
            WorkAvailabilityStatus.fromEncodedString(availability)
        }
        
        /// Decoded public key from the base64-encoded `pk` field.
        var publicKeyData: Data? {
            Data(base64Encoded: pk)
        }
        
        /// Convert to the `BatchAddWorkContact` type used by `ContactStore`.
        func mapToBatchAddWorkContact() -> BatchAddWorkContact {
            BatchAddWorkContact(
                identity: id,
                publicKey: publicKeyData,
                firstName: first,
                lastName: last,
                csi: csi,
                jobTitle: jobTitle,
                department: department,
                availabilityStatus: workAvailabilityStatus
            )
        }
    }
}
