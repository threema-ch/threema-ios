import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaMacros

final class QRCodeParser {

    // MARK: - Public Methods

    func parse(_ code: String?) -> QRCodeParserResult? {
        let result: QRCodeParserResult? =
            (try? parseIdentity(code, log: false)) ??
            (try? parseIdentityLink(code, log: false)) ??
            (try? parseMultiDeviceLink(code, log: false)) ??
            (try? parseWebSession(code, log: false))

        if let result {
            DDLogVerbose("Detected a \(result) QR code.")
        }
        else {
            DDLogVerbose("QR Code not recognized.")
        }

        return result
    }

    func parseIdentity(_ code: String?, log: Bool = true) throws -> QRCodeParserResult {
        let identityPrefix = "3mid"
        let code = code ?? ""
        let components = code.components(separatedBy: ":")

        guard components.count == 2 else {
            try fail(
                "Invalid Identity QR code. Expected 2 components separated by `:`.",
                code: code,
                context: "Identity",
                log: log
            )
        }

        guard components.first == identityPrefix else {
            try fail(
                "Invalid Identity QR code. Expected first component `\(identityPrefix)`.",
                code: code,
                context: "Identity",
                log: log
            )
        }

        let values = components.last?.components(separatedBy: ",") ?? []

        guard values.count >= 2 else {
            try fail(
                "Invalid Identity QR code. Expected at least 2 values in second component.",
                code: code,
                context: "Identity",
                log: log
            )
        }

        let identityID = values[0]

        guard identityID.count == ThreemaIdentity.length else {
            try fail(
                "Invalid Identity QR code. Identity string must have length \(ThreemaIdentity.length).",
                code: code,
                context: "Identity",
                log: log
            )
        }

        let threemaIdentity = ThreemaIdentity(identityID)

        let publicKeyHexEncoded = values[1] as NSString

        guard
            let publicKeyData = publicKeyHexEncoded.decodeHex(),
            publicKeyData.count == kNaClCryptoPubKeySize
        else {
            try fail(
                "Invalid Identity QR code. Public key must be hex encoded with length \(kNaClCryptoPubKeySize).",
                code: code,
                context: "Identity",
                log: log
            )
        }

        var expirationDate: Date?

        if values.count >= 3 {
            guard let timeInterval = Double(values[2]) else {
                try fail(
                    "Invalid Identity QR code. Expiration date must be a double.",
                    code: code,
                    context: "Identity",
                    log: log
                )
            }
            expirationDate = Date(timeIntervalSince1970: timeInterval)
        }

        return .identityContact(identity: threemaIdentity, publicKey: publicKeyData, expirationDate: expirationDate)
    }

    func parseMultiDeviceLink(_ code: String?, log: Bool = true) throws -> QRCodeParserResult {
        guard
            let url = URL(string: code ?? ""),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "threema",
            components.host == "device-group",
            components.path == "/join",
            let fragment = components.fragment
        else {
            try fail(
                "Invalid Multi-device Link QR code. Unexpected format.",
                code: code,
                context: "Multi-device Link",
                log: log
            )
        }
        return .multiDeviceLink(urlSafeBase64: fragment)
    }

    func parseWebSession(_ code: String?, log: Bool = true) throws -> QRCodeParserResult {
        guard
            let encoded = code,
            let data = Data(base64Encoded: encoded)
        else {
            try fail("Invalid Web Session QR code. Must be valid base64.", code: code, context: "Web Session", log: log)
        }

        do {
            let session = try makeSession(from: data, log: log)
            let authToken = try makeAuthToken(from: data, log: log)
            return .webSession(session: session, authToken: authToken)
        }
        catch {
            try fail(
                "Invalid Web Session QR code. Session or auth token data invalid.",
                code: code,
                context: "Web Session",
                log: log
            )
        }
    }

    func parseIdentityLink(_ code: String?, log: Bool = true) throws -> QRCodeParserResult {
        guard
            let url = URL(string: code ?? ""),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "https",
            components.host == "threema.id",
            components.path.dropFirst().uppercased().count == kIdentityLen
        else {
            try fail(
                "Invalid Identity Link QR code. Unexpected format.",
                code: code,
                context: "Identity Link",
                log: log
            )
        }
        return .identityLink(url: url)
    }

    // MARK: - Helpers

    private func makeSession(from data: Data, log: Bool) throws -> [String: Any] {
        struct Bitfield: OptionSet {
            let rawValue: Int
            static let selfHosted = Bitfield(rawValue: 1 << 0)
            static let permanent = Bitfield(rawValue: 1 << 1)
        }

        let a = try unpackData(from: data, log: log)
        guard
            let field0 = a[0] as? Int,
            let field1 = a[1] as? Int,
            let field98 = a[98] as? Int,
            let field99 = a[99] as? NSString
        else {
            try fail("Invalid Session QR code. Missing required fields.", context: "Session", log: log)
        }

        let allOptions = Bitfield(rawValue: field1)

        var initiatorPermanentPublicKeyArray = [UInt8]()
        for index in 2...33 {
            guard let field = a[index] as? Int else {
                try fail("Invalid Session QR code. Invalid initiator public key data.", context: "Session", log: log)
            }
            initiatorPermanentPublicKeyArray.append(UInt8(field))
        }

        var serverPermanentPublicKeyArray = [UInt8]()
        for index in 66...97 {
            guard let field = a[index] as? Int else {
                try fail("Invalid Session QR code. Invalid server public key data.", context: "Session", log: log)
            }
            serverPermanentPublicKeyArray.append(UInt8(field))
        }

        var session = [String: Any]()
        session.updateValue(field0, forKey: "webClientVersion")
        session.updateValue(allOptions.contains(.permanent), forKey: "permanent")
        session.updateValue(allOptions.contains(.selfHosted), forKey: "selfHosted")
        session.updateValue(Data(initiatorPermanentPublicKeyArray), forKey: "initiatorPermanentPublicKey")
        session.updateValue(Data(serverPermanentPublicKeyArray), forKey: "serverPermanentPublicKey")
        session.updateValue(field98, forKey: "saltyRTCPort")
        session.updateValue(field99, forKey: "saltyRTCHost")
        return session
    }

    private func makeAuthToken(from data: Data, log: Bool) throws -> Data {
        let a = try unpackData(from: data, log: log)
        var authTokenArray = [UInt8]()
        for index in 34...65 {
            guard let value = a[index] as? Int else {
                try fail("Invalid Auth Token QR code. Invalid data.", context: "Auth Token", log: log)
            }
            authTokenArray.append(UInt8(value))
        }
        return Data(authTokenArray)
    }

    private func unpackData(from data: Data, log: Bool) throws -> [Unpackable] {
        do {
            let format = String(format: ">HB32B32B32BH%is", (data.count) - 101)
            let a = try unpack(format, data)
            return a
        }
        catch {
            try fail("Invalid QR code data. \(error.localizedDescription)", context: "Unpack", log: log)
        }
    }

    private func fail(_ message: String, code: String? = nil, context: String, log: Bool) throws -> Never {
        if log {
            if let code {
                DDLogVerbose("\(context) parse error: \(code). \(message)")
            }
            else {
                DDLogVerbose("\(context) parse error. \(message)")
            }
        }
        throw QRCodeParserError.invalidFormat(message)
    }
}
