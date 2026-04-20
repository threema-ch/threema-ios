import Foundation
import ThreemaFramework

final class PhotosRightsHelperMock: PhotosRightsHelperProtocol {
    private var accessLevelDeterminedResult: Bool
    private var requestWriteAccessResult: Bool
    private var requestReadAccessResult: Bool
    private var readAccess: Bool
    private var fullAccess: Bool
    private var writeAccess: Bool
    
    init(
        accessLevelDetermined: Bool,
        requestWriteAccess: Bool,
        requestReadAccess: Bool,
        readAccess: Bool,
        fullAccess: Bool,
        writeAccess: Bool
    ) {
        self.accessLevelDeterminedResult = accessLevelDetermined
        self.writeAccess = writeAccess
        self.readAccess = readAccess
        self.fullAccess = fullAccess
        self.requestWriteAccessResult = requestWriteAccess
        self.requestReadAccessResult = requestReadAccess
    }
    
    func accessLevelDetermined() -> Bool {
        accessLevelDeterminedResult
    }

    func requestWriteAccess() -> Bool {
        requestWriteAccessResult
    }

    func requestReadAccess() -> Bool {
        requestReadAccessResult
    }

    func haveFullAccess() -> Bool {
        fullAccess
    }

    func haveWriteAccess() -> Bool {
        writeAccess
    }
}
