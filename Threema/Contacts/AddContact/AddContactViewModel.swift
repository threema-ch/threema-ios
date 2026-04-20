import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@MainActor
final class AddContactViewModel: ObservableObject {
    
    @Published var identity = "" {
        didSet {
            identityDidChange()
        }
    }

    @Published var canAdd = false
    @Published var isLoading = false
    
    let isScanningDisabled = !DeviceCapabilitiesManager().supportsRecordingVideo

    private let businessInjector = BusinessInjector.ui

    func addContact(onSaveDisplayMode: OnSaveDisplayMode) async throws {
        let myIdentity = MyIdentityStore.shared().identity
        guard identity.count == ThreemaIdentity.length else {
            throw AddContactValidationError.invalidLength
        }
        guard identity != myIdentity else {
            throw AddContactValidationError.ownID
        }
        
        isLoading = true
        defer {
            isLoading = false
        }
        
        try await withCheckedThrowingContinuation { continuation in
            businessInjector.contactStore.addContact(
                with: identity,
                verificationLevel: Int32(VerificationLevel.unverified.rawValue),
                onCompletion: { contact, _ in
                    DispatchQueue.main.async {
                        guard let contact else {
                            return
                        }
                        
                        switch onSaveDisplayMode {
                        case .showDetails:
                            NotificationCenter.default.post(
                                name: Notification.Name(kNotificationShowContact),
                                object: nil,
                                userInfo: [kKeyContact: contact]
                            )
                            
                        case .showChat:
                            let info: [String: Any] = [
                                kKeyContact: contact as Any,
                                kKeyForceCompose: true,
                            ]

                            NotificationCenter.default.post(
                                name: Notification.Name(kNotificationShowConversation),
                                object: nil,
                                userInfo: info
                            )
                        }
                    }
                    
                    continuation.resume()
                },
                onError: { error in
                    if let nsError = error as NSError?,
                       nsError.domain == NSURLErrorDomain,
                       nsError.code == 404 {
                        continuation.resume(throwing: AddContactValidationError.identityNotFound)
                    }
                    else {
                        continuation.resume(throwing: AddContactValidationError.unknown(error))
                    }
                }
            )
        }
    }
    
    // MARK: - Helpers

    private func identityDidChange() {
        canAdd = identity.count == ThreemaIdentity.length
    }
}

enum AddContactValidationError: LocalizedError {
    case ownID
    case invalidLength
    case identityNotFound
    case unknown(Error)

    var errorTitle: String {
        switch self {
        case .ownID, .invalidLength:
            #localize("identity_invalid_title")
        case .identityNotFound:
            #localize("identity_not_found_title")
        case let .unknown(error):
            error.localizedDescription
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .ownID:
            #localize("identity_own_error_message")
        case .invalidLength:
            #localize("identity_invalid_length_message")
        case .identityNotFound:
            #localize("identity_not_found_message")
        case let .unknown(error):
            (error as NSError).localizedFailureReason ?? ""
        }
    }
}
