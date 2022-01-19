//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
#if compiler(>=5.3)
import PhotosUI
#endif

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
    func checknewPhotosApi() -> Bool
}

@objc class PhotosRightsHelper : NSObject, PhotosRightsHelperProtocol {
    
    func haveFullAccess() -> Bool {
        #if compiler(>=5.3)
        if #available(iOS 14, *) {
            let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return authStatus == .authorized
        }
        #endif
        // Fallback on earlier versions
        let authStatus = PHPhotoLibrary.authorizationStatus()
        return authStatus == .authorized
    }
    
    func haveLimitedAccess() -> Bool {
        #if compiler(>=5.3)
        if #available(iOS 14, *) {
            let authStatus = PHPhotoLibrary.authorizationStatus()
            return authStatus == .limited
        }
        #endif
        // Fallback on earlier versions
        return false
    }
    
    static func checkAccessAllowed(rightsHelper : PhotosRightsHelperProtocol) -> PhotosRights {
        var accessAllowed = PhotosRights.none
        if !rightsHelper.accessLevelDetermined() {
            if rightsHelper.checknewPhotosApi() {
                accessAllowed = rightsHelper.requestWriteAccess() ? .write : .none
            } else {
                accessAllowed = rightsHelper.requestReadAccess() ? .full : .potentialWrite
            }
        } else {
            if rightsHelper.haveFullAccess() {
                accessAllowed = .full
            } else {
                accessAllowed = rightsHelper.haveWriteAccess() ? .write : .potentialWrite
            }
        }
        return accessAllowed
    }
    
    func checknewPhotosApi() -> Bool {
        if #available(iOS 14, *) {
            return true
        }
        return false
    }
    
    /// Check whether we have write access to the photos
    /// There is no sepearte check for the write permission on iOS 13 and lower. True in that case.
    /// - Returns: True if we have access or on iOS 13 and lower. False if access was not granted or not yet granted
    func haveWriteAccess() -> Bool {
        #if compiler(>=5.3)
        if #available(iOS 14, *) {
            let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            return authStatus == .authorized
        }
        #endif
        // Fallback on earlier versions
        return true
    }
    
    func requestReadAccess() -> Bool {
        #if compiler(>=5.3)
        if #available(iOS 14, *) {
            return requestAccess(accessLevel: .readWrite)
        }
        #endif
        // Fallback on earlier versions
        return requestAccess()
    }
    
    func requestWriteAccess() -> Bool {
        #if compiler(>=5.3)
        if #available(iOS 14, *) {
            return requestAccess(accessLevel: .addOnly)
        }
        #endif
        // Fallback on earlier versions
        return requestAccess()
    }
    
    func accessLevelDetermined() -> Bool {
        #if compiler(>=5.3)
        if #available(iOS 14, *) {
            let ao = PHPhotoLibrary.authorizationStatus(for: .addOnly) != .notDetermined
            let rw = PHPhotoLibrary.authorizationStatus(for: .readWrite) != .notDetermined
            return ao && rw
        }
        #endif
        return PHPhotoLibrary.authorizationStatus() != .notDetermined
    }
    
    private func requestAccess() -> Bool {
        var status = PHAuthorizationStatus.notDetermined
        let sema = DispatchSemaphore.init(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).sync {
            PHPhotoLibrary.requestAuthorization({ authStat in
                status = authStat
                sema.signal()
            })
        }
        sema.wait()
        return status == .authorized
    }
    
    #if compiler(>=5.3)
    @available(iOS 14, *)
    private func requestAccess(accessLevel : PHAccessLevel) -> Bool {
        
        var status = PHAuthorizationStatus.notDetermined
        let sema = DispatchSemaphore.init(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).sync {
            PHPhotoLibrary.requestAuthorization(for: accessLevel, handler: { authStat in
                status = authStat
                sema.signal()
            })
        }
        sema.wait()
        return status == .authorized
    }
    #endif
}
