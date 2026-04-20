import Foundation
import PromiseKit
import ThreemaProtocols
@testable import ThreemaFramework

final class MediatorReflectedProcessorMock: MediatorReflectedProcessorProtocol {
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
