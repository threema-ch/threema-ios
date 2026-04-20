import ContactsUI
import FileUtility
import MobileCoreServices
import ThreemaMacros
import UIKit
import UniformTypeIdentifiers

final class DocumentPicker: NSObject {
    
    // MARK: - Properties
    
    private lazy var messageSender = BusinessInjector.ui.messageSender
    
    private let conversation: ConversationEntity
    private weak var presenter: UIViewController?

    // MARK: - Lifecycle
    
    init(for conversation: ConversationEntity, presenter: UIViewController?) {
        self.conversation = conversation
        self.presenter = presenter
    }
    
    // MARK: - Show pickers
    
    func checkPermissionAndShowContactPicker() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        let isAuthorizedOrLimited: Bool =
            if #available(iOS 18.0, *) {
                status == .authorized || status == .limited
            }
            else {
                status == .authorized
            }

        if isAuthorizedOrLimited {
            showContactPicker()
        }
        else if status == .denied {
            showContactAlert()
        }
        else {
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    granted ? self.showContactPicker() : self.showContactAlert()
                }
            }
        }
    }

    private func showContactPicker() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    func showDocumentPicker() {
        let allowedTypes: [UTType] = [.item, .data, .content, .archive, .contact, .message]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presenter?.present(picker, animated: true)
    }
    
    // MARK: - Helpers
    
    private func showContactAlert() {
        guard let presenter else {
            return
        }
        
        UIAlertTemplate.showOpenSettingsAlert(
            owner: presenter,
            noAccessAlertType: .contacts
        )
    }
    
    private func sendItem(_ item: URLSenderItem) {
        let messageFormat = #localize("send_file_message")
        let message = String(format: messageFormat, item.getName(), conversation.displayName)
        let title = #localize("send_file_title")

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = #localize("optional_caption")
        }

        let sendAction = UIAlertAction(title: #localize("send"), style: .default) { [weak self] _ in
            guard let self else {
                return
            }
            
            let caption = alertController.textFields?.first?.text ?? ""
            if !caption.isEmpty {
                item.caption = caption
            }

            sendBlobMessage(for: item, in: conversation.objectID)
        }

        let cancelAction = UIAlertAction(title: #localize("cancel"), style: .cancel)

        alertController.addAction(sendAction)
        alertController.addAction(cancelAction)

        presenter?.present(alertController, animated: true)
    }
    
    private func sendBlobMessage(for item: URLSenderItem, in conversationObjectID: NSManagedObjectID) {
        guard let presenter else {
            return
        }

        Task {
            do {
                try await messageSender.sendBlobMessage(
                    for: item,
                    in: conversationObjectID,
                    correlationID: nil,
                    webRequestID: nil
                )
            }
            catch let error as MessageSenderError {
                Task { @MainActor in
                    let title = #localize("error_sending_failed")
                    let message: String
                    switch error {
                    case .tooBig:
                        let format = #localize("error_message_file_too_big")
                        message = String(
                            format: format,
                            arguments: [FileUtility.shared.getFileSizeDescription(from: Int64(kMaxFileSize))]
                        )

                    case .noData:
                        message = #localize("error_message_invalid_file")

                    default:
                        message = #localize("error_message_generic")
                    }

                    UIAlertTemplate.showAlert(
                        owner: presenter,
                        title: title,
                        message: message,
                    )
                }
            }
            catch let error as BlobManagerError {
                guard error != .noteGroupNeedsNoSync else {
                    return
                }
                Task { @MainActor in
                    let title = #localize("error_sending_failed")
                    let message = error.localizedDescription

                    UIAlertTemplate.showAlert(
                        owner: presenter,
                        title: title,
                        message: message,
                    )
                }
            }
            catch {
                Task { @MainActor in
                    let title = #localize("error_sending_failed")
                    let message = error.localizedDescription

                    UIAlertTemplate.showAlert(
                        owner: presenter,
                        title: title,
                        message: message,
                    )
                }
            }
        }
    }
}

// MARK: - CNContactPickerDelegate

extension DocumentPicker: CNContactPickerDelegate {
    
    // MARK: - Delegate functions
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        guard let vCardData = ContactUtil.vCardData(for: contact) else {
            return
        }

        guard let item = URLSenderItem(
            data: vCardData,
            fileName: nil,
            type: UTType.vCard.identifier,
            renderType: 0,
            sendAsFile: true
        ) else {
            return
        }

        picker.dismiss(animated: true) { [weak self] in
            self?.sendItem(item)
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension DocumentPicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return
        }

        let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
        guard let item = URLSenderItem(
            data: data,
            fileName: url.lastPathComponent,
            type: uti,
            renderType: 0,
            sendAsFile: true
        ) else {
            return
        }

        sendItem(item)
    }
}
