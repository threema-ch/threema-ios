//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import PromiseKit
import ThreemaProtocols
@testable import ThreemaFramework

class MediatorReflectedProcessorMock: MediatorReflectedProcessorProtocol {
    var process: ((
        D2d_Envelope,
        Date,
        Bool,
        Int,
        Int
    ) -> Promise<Void>)?

    func process(
        reflectedEnvelope: D2d_Envelope,
        reflectedAt: Date,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {
        if let process {
            return process(
                reflectedEnvelope,
                reflectedAt,
                receivedAfterInitialQueueSend,
                maxBytesToDecrypt,
                timeoutDownloadThumbnail
            )
        }

        return Promise()
    }
}
