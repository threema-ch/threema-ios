//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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
import UIKit

class SafeSetupViewController: ThemedViewController {

    @IBOutlet weak var safeImageView: UIImageView!
    @IBOutlet weak var safeImageCircle: UIView!
    @IBOutlet weak var safeSwitchLabel: UILabel!
    @IBOutlet weak var safeSwitch: UISwitch!
    @IBOutlet weak var safeActivatedContainer: UIView!
    @IBOutlet weak var safeDeactivatedContainer: UIView!
    @IBOutlet weak var safeSeparatorView: UIView!

    var safeManager: SafeManager
    var mdmSetup: MDMSetup
    
    required init?(coder aDecoder: NSCoder) {
        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
        self.safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Threema Safe"
        self.safeImageCircle.layer.cornerRadius = self.safeImageCircle.frame.height / 2
        self.safeSwitch.isEnabled = !self.mdmSetup.isSafeBackupForce()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshView()
        setupColor()
    }

    //MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard identifier == "SafeSetupPassword",
            sender is UISwitch else {
                
            return true
        }
        
        if self.safeManager.isActivated {
            
            //confirm to delete backup
            UIAlertTemplate.showConfirm(owner: self, popOverSource: self.safeSwitch!, title: NSLocalizedString("safe_deactivate", comment: ""), message: NSLocalizedString("safe_deactivate_explain", comment: ""), titleOk: NSLocalizedString("deactivate", comment: ""), actionOk: { (action) in
                
                self.safeManager.deactivate()
                self.refreshView()
            }, titleCancel: NSLocalizedString("cancel", comment: ""), actionCancel: { (action) in self.safeSwitch.isOn = true })
            return false
        }
        
        return true
    }
    
    func refreshView() {
        
        guard self.safeManager.isActivated else {
            
            self.safeActivatedContainer.isHidden = true
            self.safeDeactivatedContainer.isHidden = false
            
            self.safeSwitch.isOn = false

            return
        }
        
        self.safeActivatedContainer.isHidden = false

        // refresh safe activated container view controller and start backup
        safeActivatedViewController()?.refreshView(updateCell: true)

        self.safeDeactivatedContainer.isHidden = true

        self.safeSwitch.isOn = true
    }
    
    @objc override func refresh() {
        super.refresh()
        for childViewController in self.children {
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
        for childViewController in self.children {
            if let viewController = childViewController as? SafeActivatedViewController {
                return viewController
            }
        }
        return nil
    }
    
    private func setupColor() {
        safeSeparatorView.backgroundColor = Colors.hairline()
        safeImageCircle.backgroundColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
        safeImageView.bringSubviewToFront(self.view)
    }
}

extension SafeSetupViewController  {
    @IBAction func doneSafeSetupPassword(_ segue: UIStoryboardSegue) {
        guard segue.source is SafeSetupPasswordViewController else {
            return
        }
        
        safeActivatedViewController()?.backupNow()
        self.refreshView()
    }
}
