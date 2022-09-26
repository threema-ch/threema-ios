//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class MultiDeviceViewController: ThemedTableViewController {
    
    // MARK: - Properties

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Private properties

    private let refreshControlTableView = UIRefreshControl()

    private var thisDevice: DeviceInfo?
    private var otherDevices: [DeviceInfo]?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = BundleUtil.localizedString(forKey: "multi_device_linked_devices_title")
        
        registerHeaderAndCells()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        refreshControlTableView
            .attributedTitle = NSAttributedString(
                string: BundleUtil
                    .localizedString(forKey: "multi_device_linked_devices_refresh")
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
    private func load() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        let bi = BusinessInjector()
        thisDevice = bi.multiDeviceManager.thisDevice
        bi.multiDeviceManager.otherDevices()
            .done { items in
                self.otherDevices = items
            }
            .ensure {
                self.tableView.reloadData()
                self.activityIndicator.stopAnimating()
            }
            .catch { error in
                DDLogError(String(
                    format: BundleUtil
                        .localizedString(forKey: "multi_device_linked_devices_loading_failed"),
                    error as CVarArg
                ))

                UIAlertTemplate.showAlert(
                    owner: self,
                    title: BundleUtil.localizedString(forKey: "multi_device_linked_devices_failed_to_load_title"),
                    message: BundleUtil.localizedString(forKey: "multi_device_linked_devices_failed_to_load_message")
                )
            }
    }
}

// MARK: - Table view

extension MultiDeviceViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
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
            cell.deviceInfo = thisDevice
            cell.activated = BusinessInjector().serverConnector.isMultiDeviceActivated
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
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete,
           let item = otherDevices?[indexPath.row] {
            activityIndicator.hidesWhenStopped = true
            activityIndicator.startAnimating()

            // Drop device and reload other devices
            let bi = BusinessInjector()
            bi.multiDeviceManager.drop(device: item)
                .done { (success: Bool) in
                    self.load()

                    if !success {
                        UIAlertTemplate.showAlert(
                            owner: self,
                            title: BundleUtil
                                .localizedString(forKey: "multi_device_linked_devices_failed_remove_title"),
                            message: BundleUtil
                                .localizedString(forKey: "multi_device_linked_devices_failed_remove_message")
                        )
                    }
                }
                .ensure {
                    self.activityIndicator.stopAnimating()
                }
                .catch { error in
                    DDLogError(String(
                        format: BundleUtil
                            .localizedString(forKey: "multi_device_linked_devices_remove_failed"),
                        error as CVarArg
                    ))

                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: BundleUtil.localizedString(forKey: "multi_device_linked_devices_failed_remove_title"),
                        message: BundleUtil
                            .localizedString(forKey: "multi_device_linked_devices_failed_remove_message_2")
                    )
                }
        }
    }

    /// Pull to refresh
    @objc func refreshTableView(refreshControl: UIRefreshControl) {
        load()
        refreshControl.endRefreshing()
    }
}
