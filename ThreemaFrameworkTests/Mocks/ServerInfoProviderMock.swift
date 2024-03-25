//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
@testable import ThreemaFramework

class ServerInfoProviderMock: ServerInfoProvider {
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
}
