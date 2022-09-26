//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

/// Shows the standard contact and group picker.
///
/// Wraps the `ContactGroupPickerViewController` for it to be used in the new chat view.
@objc class ContactGroupPickerWrapper: NSObject, ContactGroupPickerDelegate {
        
    private let message: BaseMessage
    private weak var modalNavController: ModalNavigationController?

    init(message: BaseMessage) {
        self.message = message
    }
        
    public func showPicker() {
        guard let pickerModal = ContactGroupPickerViewController.pickerFromStoryboard(withDelegate: nil),
              let pickerVC = pickerModal.topViewController as? ContactGroupPickerViewController else {
            return
        }
        modalNavController = pickerModal
        pickerVC.delegate = self
        pickerVC.submitOnSelect = false
        
        let topView = AppDelegate.shared().currentTopViewController()
        topView?.present(pickerModal, animated: true)
    }
    
    // MARK: - ContactGroupPickerDelegate
    
    func contactPicker(
        _ contactPicker: ContactGroupPickerViewController!,
        didPickConversations conversations: Set<AnyHashable>!,
        renderType: NSNumber!,
        sendAsFile: Bool
    ) {
        
        for case let conversation as Conversation in conversations {
            MessageForwarder.forwardMessage(message, to: conversation)
            
            if let text = contactPicker.additionalTextToSend {
                MessageSender.sendMessage(text, in: conversation, quickReply: false, requestID: nil)
            }
        }
        
        modalNavController?.dismiss(animated: true)
    }
    
    func contactPickerDidCancel(_ contactPicker: ContactGroupPickerViewController!) {
        modalNavController?.dismiss(animated: true)
    }
}
