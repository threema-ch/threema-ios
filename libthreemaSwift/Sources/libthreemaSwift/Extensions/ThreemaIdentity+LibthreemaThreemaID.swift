import Foundation
import ThreemaEssentials

extension ThreemaEssentials.ThreemaIdentity {
    // swiftformat:disable:next acronyms
    public init(libthreemaThreemaID: ThreemaId) {
        self.init(rawValue: libthreemaThreemaID)
    }
}
