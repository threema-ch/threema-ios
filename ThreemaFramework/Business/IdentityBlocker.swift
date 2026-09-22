import ThreemaEssentials

public enum IdentityBlockingState {
    case blocked
    case notBlocked
}

/// Validate if an identity is blocked
public protocol IdentityBlocking {
    func check(identity: ThreemaIdentity) -> IdentityBlockingState
}

/// Implementation of the _Identity Blocked Steps_ defined by protocol
///
/// Based on v24 of the protocol
public struct IdentityBlocker: IdentityBlocking {
    
    private let businessInjector: BusinessInjectorProtocol
    
    public init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    public func check(
        identity: ThreemaIdentity
    ) -> IdentityBlockingState {
        // 1.  Let `identity` be the Threema ID to be checked.
        // 2.  If `identity` is a _Special Contact_, return that it is not blocked.
        guard identity.isSpecialContact == false else {
            return .notBlocked
        }
        
        // 3.  If `identity` is explicitly blocked, return that it is blocked.
        if businessInjector.settingsStore.blacklist.contains(identity.rawValue) {
            return .blocked
        }
        
        // 4.  If the settings indicate that unknown contacts should not be blocked,
        //     return that it is not blocked.
        if businessInjector.settingsStore.blockUnknown == false {
            return .notBlocked
        }
        
        // 5.  If `identity` is a _Predefined Contact_, return that it is not blocked.
        guard identity.isPredefinedContact == false else {
            return .notBlocked
        }
        
        return businessInjector.runInBackgroundAndWait { backgroundBusinessInjector in
            
            // 6.  Let `contact` be the associated contact to `identity`.
            // 7.  If `contact` is not defined, return that it is blocked.
            guard let contact = backgroundBusinessInjector.entityManager.entityFetcher.contactEntity(
                for: identity.rawValue
            ) else {
                return .blocked
            }
            
            // 8.  If `contact` has acquaintance level _direct_, return that it is not
            //     blocked.
            
            let isHidden = backgroundBusinessInjector.entityManager.performAndWait {
                contact.isHidden
            }
            
            guard isHidden == true else {
                return .notBlocked
            }
            
            // 9.  If `contact` is part of a group that is not marked as _left_, return
            //     that it is not blocked.
            guard backgroundBusinessInjector.entityManager.entityFetcher.isInNotLeftGroup(contact: contact) == false else {
                return .notBlocked
            }
            
            // 10. Return that it is blocked.
            return .blocked
        }
    }
}

extension ThreemaIdentity {
    fileprivate var isSpecialContact: Bool {
        PredefinedContacts(rawValue: rawValue).isSpecialContact
    }
    
    fileprivate var isPredefinedContact: Bool {
        PredefinedContacts(rawValue: rawValue).identity != nil
    }
}
