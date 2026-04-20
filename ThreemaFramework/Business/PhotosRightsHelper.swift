import Foundation
import PhotosUI

enum PhotosRights {
    case full
    case write
    case potentialWrite
    case none
}

public protocol PhotosRightsHelperProtocol {
    func accessLevelDetermined() -> Bool
    func requestWriteAccess() -> Bool
    func requestReadAccess() -> Bool
    func haveFullAccess() -> Bool
    func haveWriteAccess() -> Bool
}

@objc public final class PhotosRightsHelper: NSObject, PhotosRightsHelperProtocol {
    
    public func haveFullAccess() -> Bool {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return authStatus == .authorized
    }
    
    func haveLimitedAccess() -> Bool {
        let authStatus = PHPhotoLibrary.authorizationStatus()
        return authStatus == .limited
    }
    
    static func checkAccessAllowed(rightsHelper: PhotosRightsHelperProtocol) -> PhotosRights {
        var accessAllowed = PhotosRights.none
        if !rightsHelper.accessLevelDetermined() {
            accessAllowed = rightsHelper.requestWriteAccess() ? .write : .none
        }
        else {
            if rightsHelper.haveFullAccess() {
                accessAllowed = .full
            }
            else {
                accessAllowed = rightsHelper.haveWriteAccess() ? .write : .potentialWrite
            }
        }
        return accessAllowed
    }
    
    /// Check whether we have write access to the photos
    /// - Returns: True if we have access
    public func haveWriteAccess() -> Bool {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        return authStatus == .authorized
    }
    
    public func requestReadAccess() -> Bool {
        requestAccess(accessLevel: .readWrite)
    }
    
    public func requestWriteAccess() -> Bool {
        requestAccess(accessLevel: .addOnly)
    }
    
    public func accessLevelDetermined() -> Bool {
        let ao = PHPhotoLibrary.authorizationStatus(for: .addOnly) != .notDetermined
        let rw = PHPhotoLibrary.authorizationStatus(for: .readWrite) != .notDetermined
        return ao && rw
    }
    
    private func requestAccess() -> Bool {
        var status = PHAuthorizationStatus.notDetermined
        let sema = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).sync {
            PHPhotoLibrary.requestAuthorization { authStat in
                status = authStat
                sema.signal()
            }
        }
        sema.wait()
        return status == .authorized
    }
    
    private func requestAccess(accessLevel: PHAccessLevel) -> Bool {
    
        var status = PHAuthorizationStatus.notDetermined
        let sema = DispatchSemaphore(value: 0)
    
        DispatchQueue.global(qos: .userInitiated).sync {
            PHPhotoLibrary.requestAuthorization(for: accessLevel, handler: { authStat in
                status = authStat
                sema.signal()
            })
        }
        sema.wait()
        return status == .authorized
    }
}
