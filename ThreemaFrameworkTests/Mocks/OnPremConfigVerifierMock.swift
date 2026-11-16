import Foundation
@testable import ThreemaFramework

final class OnPremConfigVerifierMock: OnPremConfigVerifierProtocol {
    private(set) var verifyCalls = [String]()
    private(set) var checkExpirationCalls = [Bool]()

    func verify(oppfData: String, checkExpiration: Bool) throws -> OnPremConfig {
        verifyCalls.append(oppfData)
        checkExpirationCalls.append(checkExpiration)

        return OnPremConfig(
            version: "1.0",
            signatureKey: Data(),
            refresh: 0,
            license: OnPremLicense(id: "", expires: Date(), count: 0),
            chat: OnPremConfigChat(hostname: "", ports: [Int](), publicKey: Data()),
            directory: OnPremConfigDirectory(url: ""),
            // swiftformat:disable:next all
            blob: OnPremConfigBlob(uploadUrl: "", downloadUrl: "", doneUrl: ""),
            avatar: nil, safe: nil, work: nil, mediator: nil, web: nil, rendezvous: nil, domains: nil, maps: nil
        )
    }
}
