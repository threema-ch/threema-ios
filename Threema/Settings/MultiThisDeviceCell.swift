import CocoaLumberjackSwift
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class MultiThisDeviceCell: MultiDeviceCell {

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
            if let duplicates = BusinessInjector.ui.entityManager.entityFetcher.duplicateContactIdentities() {
                let duplicateIdentitiesDesc = duplicates.joined(separator: ", ")
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
                
                let dl = DeviceLinking(businessInjector: BusinessInjector.ui)
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

        if BusinessInjector.ui.userSettings.allowSeveralLinkedDevices {
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
        let deviceGroupKeyManager = DeviceGroupKeyManager()
        if deviceGroupKeyManager.dgk != nil {
            MultiDeviceWizardManager.shared.showWizard(
                on: (parentViewController?.navigationController)!,
                additionalLinking: true
            )
        }
    }
}
