import Testing
import Threema
import ThreemaEssentials

@testable import Threema

private let prefixEmpty = ""
private let prefixValid = "3mid"
private let identityInvalid = "ECHOECH"
private let identityValid = "ECHOECHO"
private let publicKeyEmpty = ""
private let publicKeyInvalid = "aaaaaaaaaaaaa"
private let publicKeyValid = "4a6a1b34dcef15d43cb74de2fd36091be99fbbaf126d099d47d83d919712c72b"
private let expirationDataInvalid = "ABCD"
private let expirationDataValid: TimeInterval = 1_924_684_800

@Suite("QR codes parser")
@MainActor struct QRCodeParserTests {

    @Suite("Parse Contact Identity Data")
    struct ContactIdentity {

        private let sut = QRCodeParser()

        @Test("Code null should throw error")
        func null() throws {
            do {
                _ = try sut.parseIdentity(nil)
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Identity QR code. Expected 2 components separated by `:`.")
                }
            }
        }

        @Test("Code empty should throw error")
        func empty() throws {
            do {
                _ = try sut.parseIdentity("")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Identity QR code. Expected 2 components separated by `:`.")
                }
            }
        }

        @Test("Code with wrong prefix should throw error")
        func prefix() throws {
            do {
                _ = try sut.parseIdentity("\(prefixEmpty):\(identityValid),\(publicKeyValid),\(expirationDataValid)")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Identity QR code. Expected first component `\(prefixValid)`.")
                }
            }
        }

        @Test("Code with invalid identity ID length should throw error")
        func invalidIdentityLength() throws {
            do {
                _ = try sut.parseIdentity("\(prefixValid):\(identityInvalid),\(publicKeyValid),\(expirationDataValid)")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Identity QR code. Identity string must have length 8.")
                }
            }
        }

        @Test("Code with no public key should throw error")
        func noPublicKey() throws {
            do {
                _ = try sut.parseIdentity("\(prefixValid):\(identityValid)\(publicKeyEmpty)")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Identity QR code. Expected at least 2 values in second component.")
                }
            }
        }

        @Test("Code with invalid public key length should throw error")
        func publicKeyLength() throws {
            do {
                _ = try sut.parseIdentity("\(prefixValid):\(identityValid),\(publicKeyInvalid),\(expirationDataValid)")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason.contains("Public key must be hex encoded"))
                }
            }
        }

        @Test("Code with invalid expiration date should throw error")
        func invalidExpirationDate() throws {
            do {
                _ = try sut.parseIdentity("\(prefixValid):\(identityValid),\(publicKeyValid),\(expirationDataInvalid)")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason.contains("Expiration date must be a double."))
                }
            }
        }

        @Test("Code with valid identity ID, public key should return data")
        func valid() throws {
            let data = try sut.parseIdentity("\(prefixValid):\(identityValid),\(publicKeyValid)")
            guard case let .identityContact(threemaIdentity, publicKey, expirationDate) = data else {
                Issue.record("Expecting parse result to be an identity.")
                return
            }
            #expect(threemaIdentity.rawValue == identityValid)
            #expect(publicKey.hexEncodedString() == publicKeyValid)
            #expect(expirationDate == nil)
        }

        @Test("Code with valid identity ID, public key and expiration date should return data")
        func validWithExpirationDate() throws {
            let data = try sut.parseIdentity("\(prefixValid):\(identityValid),\(publicKeyValid),\(expirationDataValid)")
            guard case let .identityContact(threemaIdentity, publicKey, expirationDate) = data else {
                Issue.record("Expecting parse result to be an identity.")
                return
            }
            #expect(threemaIdentity.rawValue == identityValid)
            #expect(publicKey.hexEncodedString() == publicKeyValid)
            #expect(expirationDate == Date(timeIntervalSince1970: expirationDataValid))
        }
    }

    @Suite("Parse Web Session Data")
    struct WebSession {
        private let sut = QRCodeParser()

        private let codeInvalid = Data("ABC1235".utf8).base64EncodedString()
        private let codeValid = """
            AAIANx/hjaczVNeeL/MLCs32p6KmvQq2weWcdqQrVX5mcit+tos5JjaLRloU5I4dYVbA2mUjO8sCgf3nw\
            t+0Jdgz57Ezf8hAL3246mOeBe0F1lRj4kgJeS+R7KKeiBAbSiFxAbtzYWx0eXJ0Yy0zNy50aHJlZW1hLmNo
            """

        @Test("Code null should throw error")
        func null() throws {
            do {
                _ = try sut.parseWebSession(nil)
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                #expect(error is QRCodeParserError)
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason.contains("Must be valid base64."))
                }
            }
        }

        @Test("Code empty should throw error")
        func empty() throws {
            do {
                _ = try sut.parseWebSession("")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                #expect(error is QRCodeParserError)
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Web Session QR code. Session or auth token data invalid.")
                }
            }
        }

        @Test("Code that is not base64encoded should throw error")
        func base64() throws {
            do {
                _ = try sut.parseWebSession("12121212")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                #expect(error is QRCodeParserError)
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Web Session QR code. Session or auth token data invalid.")
                }
            }
        }

        @Test("Code that has no valid session data or auth token should throw error")
        func invalidData() throws {
            do {
                _ = try sut.parseWebSession(codeInvalid)
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                #expect(error is QRCodeParserError)
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason.contains("Session or auth token data invalid."))
                }
            }
        }

        @Test("Code with valid session and auth token should return data")
        func valid() throws {
            let data = try sut.parseWebSession(codeValid)
            guard case let .webSession(session: session, authToken: authToken) = data else {
                Issue.record("Expecting parse result to be an identity.")
                return
            }
            #expect(authToken.base64EncodedString() == "fraLOSY2i0ZaFOSOHWFWwNplIzvLAoH958LftCXYM+c=")
            #expect(session["permanent"] as? Bool == false)
            #expect(session["selfHosted"] as? Bool == false)
            #expect(session["saltyRTCHost"] as? String == "saltyrtc-37.threema.ch")
            #expect(session["saltyRTCPort"] as? Int == 443)
            #expect(session["webClientVersion"] as? Int == 2)
        }
    }

    @Suite("Parse Identity Links")
    struct IdentityLink {
        private let sut = QRCodeParser()

        @Test("Invalid URL should throw error")
        func invalidURL() throws {
            do {
                _ = try sut.parseIdentityLink("not_a_url")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                #expect(error is QRCodeParserError)
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason.contains("Unexpected format."))
                }
            }
        }

        @Test("Valid identity link should return data")
        func valid() throws {
            let url = "https://threema.id/\(identityValid)"
            let result = try sut.parseIdentityLink(url)
            guard case let .identityLink(urlResult) = result else {
                Issue.record("Expecting parse result to be an identity.")
                return
            }
            #expect(urlResult.absoluteString == url)
        }
    }

    @Suite("Parse Multi Device Links")
    struct MultiDeviceLink {
        private let sut = QRCodeParser()

        @Test("Invalid URL should throw error")
        func invalidURL() throws {
            do {
                _ = try sut.parseMultiDeviceLink("not_a_url")
                Issue.record("Expecting error to be thrown.")
            }
            catch {
                #expect(error is QRCodeParserError)
                if case let .invalidFormat(reason) = error as? QRCodeParserError {
                    #expect(reason == "Invalid Multi-device Link QR code. Unexpected format.")
                }
            }
        }

        @Test("Valid URL should parse successfully")
        func validURL() throws {
            let urlSafeBase64 = """
                CAASAgoAGpIBCAASIH4K-cVibsRPcucVTtQRmtAScUO4oTTYDIqyu4B8SeeDGmwIARAAGmZ3c3M6Ly9yZW5kZXp2b3VzLWIudGVz\
                dC50aHJlZW1hLmNoL2IyL2IyODlkNDk0ZjQ3YzgzYTYxMzVjNTk3ZWM2ODBhOGM3NWJmNWQzYzVlZGM4OGYxMTkyNDE1NDNhMzJl\
                NTY2NDMgAg==
                """
            let urlString = "threema://device-group/join#\(urlSafeBase64)"

            do {
                let result = try sut.parseMultiDeviceLink(urlString)

                guard case let .multiDeviceLink(actualURLSafeBase64) = result else {
                    Issue.record("Expecting parse result to be a multi-device link.")
                    return
                }
                #expect(actualURLSafeBase64 == urlSafeBase64)
            }
            catch {
                Issue.record("Expecting no error to be thrown.")
            }
        }
    }

    @Suite("Parse any QRCode (detect QRCodes)")
    struct Detector {
        private let sut = QRCodeParser()

        private let codeValidWebSession = """
            AAIANx/hjaczVNeeL/MLCs32p6KmvQq2weWcdqQrVX5mcit+tos5JjaLRloU5I4dYVbA2mUjO8sCgf3nw\
            t+0Jdgz57Ezf8hAL3246mOeBe0F1lRj4kgJeS+R7KKeiBAbSiFxAbtzYWx0eXJ0Yy0zNy50aHJlZW1hLmNo
            """

        let multiDeviceLink = "threema://device-group/join#" + """
            CAASAgoAGpIBCAASIH4K-cVibsRPcucVTtQRmtAScUO4oTTYDIqyu4B8SeeDGmwIARAAGmZ3c3M6Ly9yZW5kZXp2b3VzLWIudGVz\
            dC50aHJlZW1hLmNoL2IyL2IyODlkNDk0ZjQ3YzgzYTYxMzVjNTk3ZWM2ODBhOGM3NWJmNWQzYzVlZGM4OGYxMTkyNDE1NDNhMzJl\
            NTY2NDMgAg==
            """

        @Test("Nil code returns nil result")
        func nilCode() {
            let result = sut.parse(nil)
            #expect(result == nil)
        }

        @Test("Empty code returns nil result")
        func emptyCode() {
            let result = sut.parse("")
            #expect(result == nil)
        }

        @Test("Valid identity code returns identity")
        func identity() {
            let code = "\(prefixValid):\(identityValid),\(publicKeyValid)"
            let result = sut.parse(code)
            guard case .identityContact = result else {
                Issue.record("Wrong parsing result.")
                return
            }
        }

        @Test("Valid identity link returns identityLink")
        func identityLink() {
            let url = "https://threema.id/\(identityValid)"
            let result = sut.parse(url)
            guard case .identityLink = result else {
                Issue.record("Wrong parsing result.")
                return
            }
        }

        @Test("Valid web session returns webSession")
        func webSession() {
            let result = sut.parse(codeValidWebSession)
            guard case .webSession = result else {
                Issue.record("Wrong parsing result.")
                return
            }
        }

        @Test("Valid multi device link returns safeurl")
        func multiDeviceLinkSafeURL() {
            let result = sut.parse(multiDeviceLink)
            guard case .multiDeviceLink(urlSafeBase64: _) = result else {
                Issue.record("Wrong parsing result.")
                return
            }
        }
    }
}
