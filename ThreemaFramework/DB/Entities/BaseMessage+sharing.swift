//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

extension BaseMessage {
    /// Is saving of this message (e.g. to Photos) allowed?
    public var supportsSaving: Bool {
        guard let blobDataMessage = self as? BlobData else {
            return false
        }

        if MDMSetup(setup: false).disableShareMedia() {
            return false
        }
        else {
            return blobDataMessage.isDataAvailable
        }
    }
    
    /// Is copying of this message allowed?
    public var supportsCopying: Bool {
        guard let blobDataMessage = self as? BlobData else {
            return true
        }
        
        if MDMSetup(setup: false).disableShareMedia() {
            return false
        }
        else {
            return blobDataMessage.isDataAvailable
        }
    }
    
    /// Is forwarding of this message allowed?
    public var supportsForwarding: Bool {
        guard let blobDataMessage = self as? BlobData else {
            return true
        }
        
        // Forwarding is also allowed if the `disableShareMedia` MDM parameter is set. In combination with
        // `blockUnknown` this allows forwarding of media to known contacts, but prevents sharing to any other place.
        
        return blobDataMessage.isDataAvailable
    }
    
    /// Is sharing of this message using a share sheet allowed?
    public var supportsSharing: Bool {
        guard let blobDataMessage = self as? BlobData else {
            return true
        }
        
        if MDMSetup(setup: false).disableShareMedia() {
            return false
        }
        else {
            return blobDataMessage.isDataAvailable
        }
    }
}
