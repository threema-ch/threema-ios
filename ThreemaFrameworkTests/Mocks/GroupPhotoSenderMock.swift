//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaFramework

class GroupPhotoSenderMock: NSObject, GroupPhotoSenderProtocol {
    
    let delay: Double
    
    let blobID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength)!
    let encryptionKey: Data = BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!
    
    init(delay: Double = 0) {
        self.delay = delay
        super.init()
    }
    
    func start(
        withImageData imageData: Data?,
        isNoteGroup: Bool,
        onCompletion: @escaping ((Data?, Data?) -> Void),
        onError: (Error) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onCompletion(self.blobID, self.encryptionKey)
        }
    }
}
