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

class MultiDeviceViewController: ThemedTableViewController {
    
    // MARK: - Properties

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Private properties

    private let refreshControlTableView = UIRefreshControl()

    var thisDevice: DeviceInfo?
    var otherDevices: [DeviceInfo]?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = BundleUtil.localizedString(forKey: "multi_device_linked_devices_title")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wizardUpdate),
            name: NSNotification.Name(rawValue: kNotificationMultiDeviceWizardDidUpdate),
            object: nil
        )
        
        registerHeaderAndCells()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        refreshControlTableView.attributedTitle = NSAttributedString(
            string: BundleUtil.localizedString(forKey: "multi_device_linked_devices_refresh")
        )
        refreshControlTableView.addTarget(self, action: #selector(refreshTableView), for: UIControl.Event.valueChanged)
        tableView?.addSubview(refreshControlTableView)
        
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableView.automaticDimension

        load()
    }
    
    // MARK: - Configuration

    func registerHeaderAndCells() {
        tableView.registerCell(MultiThisDeviceCell.self)
        tableView.registerCell(MultiDeviceCell.self)
    }
    
    // MARK: - Private functions
    
    /// Load this device, other devices and reload view
    func load() {
        DispatchQueue.main.async {
            self.activityIndicator.hidesWhenStopped = true
            self.activityIndicator.startAnimating()
        }

        let bi = BusinessInjector()
        thisDevice = bi.multiDeviceManager.thisDevice

        if bi.userSettings.enableMultiDevice {
            bi.multiDeviceManager.otherDevices()
                .done { items in
                    self.otherDevices = items
                }
                .ensure {
                    self.tableView.reloadData()
                    self.activityIndicator.stopAnimating()
                }
                .catch { error in
                    DDLogError(String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "multi_device_linked_devices_loading_failed"),
                        error as CVarArg
                    ))

                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: BundleUtil.localizedString(forKey: "multi_device_linked_devices_failed_to_load_title"),
                        message: BundleUtil.localizedString(
                            forKey: "multi_device_linked_devices_failed_to_load_message"
                        )
                    )
                }
        }
        else {
            otherDevices = []

            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.activityIndicator.stopAnimating()
            }
        }
    }

    func showAlertRemoveDeviceFailed() {
        UIAlertTemplate.showAlert(
            owner: self,
            title: BundleUtil.localizedString(forKey: "multi_device_linked_devices_failed_remove_title"),
            message: BundleUtil
                .localizedString(forKey: "multi_device_linked_devices_failed_remove_message_2")
        )
    }

    @objc private func wizardUpdate() {
        load()
    }
}

// MARK: - Table view

extension MultiDeviceViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard let otherDevicesCount = otherDevices?.count else {
            return 1
        }
        
        guard otherDevicesCount > 0 else {
            return 1
        }
        
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : otherDevices?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "MultiThisDeviceCell",
                for: indexPath
            ) as! MultiThisDeviceCell
            cell.parentViewController = self
            cell.deviceInfo = thisDevice

            let bi = BusinessInjector()

            cell.enabled = bi.userSettings.enableMultiDevice
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "MultiDeviceCell",
                for: indexPath
            ) as! MultiDeviceCell
            cell.deviceInfo = otherDevices?[indexPath.row]
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? BundleUtil.localizedString(forKey: "multi_device_linked_devices_this") : BundleUtil
            .localizedString(forKey: "multi_device_linked_devices_others")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return BundleUtil.localizedString(forKey: "multi_device_linked_devices_desc")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete,
           let otherDevicesCount = otherDevices?.count {
            activityIndicator.hidesWhenStopped = true
            activityIndicator.startAnimating()

            let dl = DeviceLinking(businessInjector: BusinessInjector())

            if otherDevicesCount == 1 {
                dl.disableMultiDevice()
                    .ensure {
                        self.load()
                        self.activityIndicator.stopAnimating()
                    }
                    .catch { error in
                        DDLogError("Disable Multi Device failed: \(error)")
                        self.showAlertRemoveDeviceFailed()
                    }
            }
            else if let item = otherDevices?[indexPath.row] {
                dl.drop(items: [item])
                    .ensure {
                        self.load()
                        self.activityIndicator.stopAnimating()
                    }
                    .catch { error in
                        DDLogError("Drop device failed: \(error)")
                        self.showAlertRemoveDeviceFailed()
                    }
            }
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let multiDeviceCell = cell as? MultiDeviceCell else {
            return
        }
        
        // This a hack, because `ThemedTableViewController` resets all the colors. We should remove this behavior
        // of `ThemedTableViewController` in the future.
        multiDeviceCell.updateColors()
    }

    /// Pull to refresh
    @objc func refreshTableView(refreshControl: UIRefreshControl) {
        load()
        refreshControl.endRefreshing()
    }
}

// MARK: - UIViewControllerRepresentable

struct MultiDeviceViewControllerRepresentable: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "MultiDeviceViewController")
        return vc
    }
}
