//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

class MultiThisDeviceCell: MultiDeviceCell {
    
    // MARK: - Public property
    
    weak var parentViewController: MultiDeviceViewController?
    
    var enabled = false {
        didSet {
            enabledSwitch.isOn = enabled
            enabledSwitch.isEnabled = true
        }
    }
    
    // MARK: - Private properties
    
    // MARK: Subviews
    
    lazy var enabledSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        
        uiSwitch.addTarget(self, action: #selector(self.enabledSwitchValueChanged), for: .valueChanged)
        
        return uiSwitch
    }()
    
    @objc func enabledSwitchValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            var duplicates: NSSet?
            guard !BusinessInjector().entityManager.entityFetcher.hasDuplicateContacts(
                withDuplicateIdentities: &duplicates
            ) else {
                var duplicateIdentitiesDesc = "?"
                if let duplicateIdentities = duplicates as? Set<String> {
                    duplicateIdentitiesDesc = duplicateIdentities.joined(separator: ", ")
                }

                UIAlertTemplate.showAlert(
                    owner: parentViewController!,
                    title: #localize("multi_device_linked_duplicate_contacts_title"),
                    message: String(
                        format: #localize("multi_device_linked_duplicate_contacts_desc"),
                        duplicateIdentitiesDesc
                    )
                )
                
                enabledSwitch.isOn = false
                return
            }

            MultiDeviceWizardManager.shared.showWizard(on: (parentViewController?.navigationController)!)
        }
        else {
            UIAlertTemplate.showAlert(
                owner: parentViewController!,
                title: #localize("multi_device_linked_devices_removed_devices_title"),
                message: #localize("multi_device_linked_devices_removed_devices_message"),
                titleOk: #localize("multi_device_linked_devices_removed_devices_ok")
            ) { _ in
                self.parentViewController?.activityIndicator.hidesWhenStopped = true
                self.parentViewController?.activityIndicator.startAnimating()
                
                let dl = DeviceLinking(businessInjector: BusinessInjector())
                dl.disableMultiDevice()
                    .ensure {
                        self.parentViewController?.load()
                        self.parentViewController?.activityIndicator.stopAnimating()
                    }
                    .catch { error in
                        self.enabledSwitch.isOn = true

                        DDLogError("Disable Multi Device failed: \(error)")
                        self.parentViewController?.showAlertRemoveDeviceFailed()
                    }

            } actionCancel: { _ in
                self.enabledSwitch.isOn = true
            }
        }
    }
    
    // MARK: - Lifecycle
    
    override func configureCell() {
        super.configureCell()
        
        // add switch to cell
        accessoryView = enabledSwitch

        if BusinessInjector().userSettings.allowSeveralLinkedDevices {
            let tapGestureRecognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(platformIconTapped(tapGestureRecognizer:))
            )
            platformIcon.addGestureRecognizer(tapGestureRecognizer)
            platformIcon.isUserInteractionEnabled = true
        }
    }

    @objc
    private func platformIconTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let bi = BusinessInjector()
        let deviceGroupKeyManager = DeviceGroupKeyManager(myIdentityStore: bi.myIdentityStore)
        if deviceGroupKeyManager.dgk != nil {
            MultiDeviceWizardManager.shared.showWizard(
                on: (parentViewController?.navigationController)!,
                additionalLinking: true
            )
        }
    }
}
