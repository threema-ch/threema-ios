import CocoaLumberjackSwift
import Foundation
import Keychain

/// Decrypts the payload of incoming push notifications
public enum PushPayloadDecryptor {

    private enum PayloadKey {
        static let box = "box"
        static let nonce = "nonce"
    }

    /// Decrypt the payload of a push notification
    ///
    /// - Parameter encryptedPayload: Payload of the push notification
    /// - Returns: Decrypted payload or the passed payload if it is not encrypted or cannot be decrypted
    public static func decryptPushPayload(_ encryptedPayload: [AnyHashable: Any]?) -> [AnyHashable: Any]? {
        guard let encryptedPayload else {
            return nil
        }

        guard let boxBase64 = encryptedPayload[PayloadKey.box] as? String,
              let nonceBase64 = encryptedPayload[PayloadKey.nonce] as? String else {
            // There is nothing to decrypt
            return encryptedPayload
        }

        guard let box = Data(base64Encoded: boxBase64),
              let nonce = Data(base64Encoded: nonceBase64) else {
            DDLogError("[Push] Cannot decode encrypted push payload")
            return encryptedPayload
        }

        guard let key = try? KeychainManager.loadPushNotificationEncryptionKey() else {
            DDLogError("[Push] Cannot decrypt push payload, because the push encryption key is missing")
            return encryptedPayload
        }

        guard let payloadJSON = NaClCrypto.shared().safeSymmetricDecryptData(box, withKey: key, nonce: nonce) else {
            DDLogError("[Push] Cannot decrypt push payload: \(encryptedPayload)")
            return encryptedPayload
        }

        do {
            guard let payload = try JSONSerialization.jsonObject(with: payloadJSON) as? [AnyHashable: Any] else {
                DDLogError("[Push] Decrypted push payload is not a dictionary")
                return encryptedPayload
            }

            return payload
        }
        catch {
            DDLogError("[Push] Error parsing decrypted push payload: \(error)")
            return encryptedPayload
        }
    }
}
