//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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
import MBProgressHUD
import UIKit

class SafeSetupViewController: ThemedViewController {

    @IBOutlet var safeImageView: UIImageView!
    @IBOutlet var safeImageCircle: UIView!
    @IBOutlet var safeSwitchLabel: UILabel!
    @IBOutlet var safeSwitch: UISwitch!
    @IBOutlet var safeActivatedContainer: UIView!
    @IBOutlet var safeDeactivatedContainer: UIView!
    @IBOutlet var safeSeparatorView: UIView!

    var safeManager: SafeManager
    var mdmSetup: MDMSetup
    
    required init?(coder aDecoder: NSCoder) {
        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: BusinessInjector().groupManager
        )
        self.safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Threema Safe"
        safeImageCircle.layer.cornerRadius = safeImageCircle.frame.height / 2
        safeSwitch.isEnabled = !mdmSetup.isSafeBackupForce()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshView()
        setupColor()
    }

    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard identifier == "SafeSetupPassword",
              sender is UISwitch else {
                
            return true
        }
        
        if safeManager.isActivated {
            
            // confirm to delete backup
            UIAlertTemplate.showConfirm(
                owner: self,
                popOverSource: safeSwitch!,
                title: BundleUtil.localizedString(forKey: "safe_deactivate"),
                message: BundleUtil.localizedString(forKey: "safe_deactivate_explain"),
                titleOk: BundleUtil.localizedString(forKey: "deactivate"),
                actionOk: { _ in
                    DispatchQueue.main.async {
                        MBProgressHUD.showAdded(to: self.view, animated: true)
                    }
                    self.safeManager.deactivate()
                    self.refreshView()
                    DispatchQueue.main.async {
                        MBProgressHUD.hide(for: self.view, animated: true)
                    }
                },
                titleCancel: BundleUtil.localizedString(forKey: "cancel"),
                actionCancel: { _ in self.safeSwitch.isOn = true }
            )
            return false
        }
        
        return true
    }
    
    func refreshView() {
        
        guard safeManager.isActivated else {
            
            safeActivatedContainer.isHidden = true
            safeDeactivatedContainer.isHidden = false
            
            safeSwitch.isOn = false

            return
        }
        
        safeActivatedContainer.isHidden = false

        // refresh safe activated container view controller and start backup
        safeActivatedViewController()?.refreshView(updateCell: true)

        safeDeactivatedContainer.isHidden = true

        safeSwitch.isOn = true
    }
    
    @objc override func refresh() {
        super.refresh()
        for childViewController in children {
            if let viewController = childViewController as? SafeActivatedViewController {
                viewController.refresh()
            }
            if let viewController = childViewController as? SafeDeactivatedViewController {
                viewController.refresh()
            }
        }
        setupColor()
    }
    
    // MARK: Private functions
    
    private func safeActivatedViewController() -> SafeActivatedViewController? {
        for childViewController in children {
            if let viewController = childViewController as? SafeActivatedViewController {
                return viewController
            }
        }
        return nil
    }
    
    private func setupColor() {
        view.backgroundColor = Colors.backgroundTableViewCell
        
        safeSeparatorView.backgroundColor = Colors.separator
        safeImageCircle.backgroundColor = Colors.backgroundSafeImageCircle
        safeImageView.bringSubviewToFront(view)
    }
}

extension SafeSetupViewController {
    @IBAction func doneSafeSetupPassword(_ segue: UIStoryboardSegue) {
        guard segue.source is SafeSetupPasswordViewController else {
            return
        }
        
        safeActivatedViewController()?.backupNow()
        refreshView()
    }
}
