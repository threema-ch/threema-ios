import Foundation
@testable import ThreemaFramework

final class ServerInfoProviderMock: ServerInfoProvider {
    let baseURLString: String

    init(baseURLString: String) {
        self.baseURLString = baseURLString
    }

    func chatServer(ipv6: Bool, completionHandler: @escaping (ChatServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func directoryServer(ipv6: Bool, completionHandler: @escaping (DirectoryServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func blobServer(ipv6: Bool, completionHandler: @escaping (BlobServerInfo?, Error?) -> Void) {
        let info = BlobServerInfo(
            downloadURL: baseURLString.appending("/download/{blobId}"),
            uploadURL: baseURLString.appending("/upload/"),
            doneURL: baseURLString.appending("/done/{blobId}")
        )
        completionHandler(info, nil)
    }

    func workServer(ipv6: Bool, completionHandler: @escaping (WorkServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func avatarServer(ipv6: Bool, completionHandler: @escaping (AvatarServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func safeServer(ipv6: Bool, completionHandler: @escaping (SafeServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func mediatorServer(
        deviceGroupIDFirstByteHex: String,
        completionHandler: @escaping (MediatorServerInfo?, Error?) -> Void
    ) {
        completionHandler(nil, nil)
    }

    func webServer(ipv6: Bool, completionHandler: @escaping (WebServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func rendezvousServer(completionHandler: @escaping (ThreemaFramework.RendezvousServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func domains(completionHandler: @escaping ([Domain]?, Error?) -> Void) {
        completionHandler(nil, nil)
    }
    
    func mapsServer(completionHandler: @escaping (MapsServerInfo?, Error?) -> Void) {
        completionHandler(nil, nil)
    }

    func doRecovery() async throws {
        // no-op
    }
}
