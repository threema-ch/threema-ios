import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaFramework
import ThreemaMacros

final class ShareController: NSObject {

    private var info: [String: Any]?

    var text: String?
    var image: UIImage?
    var url: URL?

    // If nil, a contact picker will be shown
    var contact: ContactEntity?

    func startShare() {
        info = [kKeyForceCompose: NSNumber(booleanLiteral: true)]

        if let text {
            info?[kKeyText] = text
        }

        if let image {
            info?[kKeyImage] = image
        }

        // Do we already know the target contact?
        if let contact {
            share(of: contact)
        }
        else {
            guard let viewController = AppDelegate.shared().window.rootViewController,
                  let navigationController = ContactGroupPickerViewController.pickerFromStoryboard(withDelegate: self),
                  let picker = navigationController.topViewController as? ContactGroupPickerViewController else {
                return
            }

            picker.enableMultiSelection = false
            picker.enableTextInput = false
            picker.submitOnSelect = true

            viewController.present(navigationController, animated: true)
        }
    }

    // MARK: - Private functions

    private func share(of contactEntity: ContactEntity) {
        info?[kKeyContact] = contactEntity

        NotificationCenter.default.post(
            name: Notification.Name(kNotificationShowConversation),
            object: nil,
            userInfo: info
        )
    }

    private func share(of conversationEntity: ConversationEntity, renderType: Int, sendAsFile: Bool) {
        func setAndShowConversation() {
            info?[kKeyConversation] = conversationEntity

            NotificationCenter.default.post(
                name: Notification.Name(kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
        
        guard let url else {
            DDLogError("No URL provided, can't share anything")
            setAndShowConversation()
            return
        }
        
        var item: URLSenderItem?
        
        if sendAsFile {
            let mimeType =
                if let utiString = UTIConverter.uti(forFileURL: url),
                let mimeType = UTIConverter.mimeType(fromUTI: utiString) {
                    mimeType
                }
                else {
                    "application/octet-stream"
                }
            
            item = URLSenderItem(
                url: url,
                type: mimeType,
                renderType: NSNumber(integerLiteral: renderType),
                sendAsFile: true
            )
        }
        else {
            item = URLSenderItemCreator.getSenderItem(for: url)
        }
        
        if let item {
            Task { @MainActor in
                do {
                    try await BusinessInjector.ui.messageSender.sendBlobMessage(
                        for: item,
                        in: conversationEntity.objectID,
                        correlationID: nil,
                        webRequestID: nil
                    )
                    try deleteTmpFile(of: url)
                }
                catch {
                    DDLogError("Error while send and delete tmp file: \(error)")
                    try? deleteTmpFile(of: url)
                }
            }
        }
        setAndShowConversation()
    }

    private func deleteTmpFile(of url: URL) throws {
        guard let range = url.path.range(of: "tmp/Dropped"), !range.isEmpty else {
            return
        }
        try FileUtility.shared.delete(at: url)
    }
}

// MARK: - ContactGroupPickerDelegate

extension ShareController: ContactGroupPickerDelegate {
    func contactPicker(
        _ contactPicker: ContactGroupPickerViewController?,
        didPickConversations conversations: Set<AnyHashable>?,
        renderType: NSNumber?,
        sendAsFile: Bool
    ) {
        guard let contactPicker, let conversations, let renderType else {
            return
        }

        contactPicker.dismiss(animated: true) {
            // Only one expected
            guard let conversationEntity = conversations.first as? ConversationEntity else {
                return
            }
            self.share(of: conversationEntity, renderType: renderType.intValue, sendAsFile: sendAsFile)
        }
    }
    
    func contactPickerDidCancel(_ contactPicker: ContactGroupPickerViewController?) {
        guard let contactPicker else {
            return
        }

        contactPicker.dismiss(animated: true)
    }
}

// MARK: - ModalNavigationControllerDelegate

extension ShareController: ModalNavigationControllerDelegate {
    func didDismissModalNavigationController() {
        // no-op
    }
}
