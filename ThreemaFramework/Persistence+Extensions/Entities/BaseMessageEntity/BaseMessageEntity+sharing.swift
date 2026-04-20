extension BaseMessageEntity {
    /// Is saving of this message (e.g. to Photos) allowed?
    public var supportsSaving: Bool {
        guard let blobDataMessage = self as? BlobData else {
            return false
        }

        if MDMSetup().disableShareMedia() {
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
        
        if MDMSetup().disableShareMedia() {
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
        
        if MDMSetup().disableShareMedia() {
            return false
        }
        else {
            return blobDataMessage.isDataAvailable
        }
    }
}
