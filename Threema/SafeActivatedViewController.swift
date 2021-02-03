//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

import UIKit

class SafeActivatedViewController: ThemedTableViewController {
    
    let refreshViewNotificationName = Notification.Name(kSafeBackupUIRefresh)
    
    @IBOutlet weak var backupNowCell: UITableViewCell!

    @IBOutlet weak var serverNameLabel: UILabel!
    @IBOutlet weak var serverNameValueLabel: UILabel!
    @IBOutlet weak var maxBackupBytesLabel: UILabel!
    @IBOutlet weak var maxBackupBytesValueLabel: UILabel!
    @IBOutlet weak var retentionDaysLabel: UILabel!
    @IBOutlet weak var retentionDaysValueLabel: UILabel!
    @IBOutlet weak var lastBackupLabel: UILabel!
    @IBOutlet weak var lastBackupValueLabel: UILabel!
    @IBOutlet weak var backupSizeLabel: UILabel!
    @IBOutlet weak var backupSizeValueLabel: UILabel!
    @IBOutlet weak var lastResultLabel: UILabel!
    @IBOutlet weak var lastResultValueLabel: UILabel!
    
    @IBOutlet weak var explainButton: UIButton!
    @IBOutlet weak var backupNowButtonLabel: UILabel!
    @IBOutlet weak var changePasswordButtonLabel: UILabel!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var tapGestureRecognizer: UITapGestureRecognizer!
    
    private var backupTimer: Timer?
    private var mdmSetup: MDMSetup
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.serverNameLabel.text = NSLocalizedString("safe_server_name", comment: "")
        self.maxBackupBytesLabel.text = NSLocalizedString("safe_max_backup_size", comment: "")
        self.retentionDaysLabel.text = NSLocalizedString("safe_retention", comment: "")
        self.lastBackupLabel.text = NSLocalizedString("safe_last_backup", comment: "")
        self.backupSizeLabel.text = NSLocalizedString("safe_size", comment: "")
        self.lastResultLabel.text = NSLocalizedString("safe_result", comment: "")

        self.backupNowButtonLabel.text = NSLocalizedString("safe_backup_now", comment: "")
        self.changePasswordButtonLabel.text = NSLocalizedString("safe_change_password", comment: "")
        
        self.activityIndicator.hidesWhenStopped = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshViewNotification(notification:)), name: self.refreshViewNotificationName, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: self.refreshViewNotificationName, object: nil)
    }
    
    // MARK: - Public
    
    func backupNow() {
        // object: 0 -> 0s backup delay and force it
        
        // show activity on backup cell
        self.activityIndicator.startAnimating()
        self.backupNowButtonLabel.isHidden = true
        backupNowCell.isUserInteractionEnabled = false
        
        // start timer to hide activity on backup cell if backup is to fast
        backupTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(maybeHideActivityIndicator), userInfo: nil, repeats: false)
        
        NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupTrigger), object: 0)
    }
    
    @objc func refreshViewNotification(notification: Notification) {
        refreshView(updateCell: true)
    }
    
    @objc override func refresh() {
        super.refresh()
        setupColors()
    }
    
    @objc func refreshView(updateCell: Bool) {
        let hyphen: String = "-"
        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
        let safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())

        if updateCell {
            if safeManager.isBackupRunning {
                self.activityIndicator.startAnimating()
                self.backupNowButtonLabel.isHidden = true
                backupNowCell.isUserInteractionEnabled = false
            } else {
                if backupTimer == nil {
                    self.activityIndicator.stopAnimating()
                    self.backupNowButtonLabel.isHidden = false
                    backupNowCell.isUserInteractionEnabled = true
                }
            }
        }

        guard safeConfigManager.getKey() != nil else {
            self.serverNameValueLabel.text = hyphen
            self.maxBackupBytesValueLabel.text = hyphen
            self.retentionDaysValueLabel.text = hyphen
            self.lastBackupValueLabel.text = hyphen
            self.lastResultValueLabel.text = hyphen

            return
        }
        
        self.serverNameValueLabel.text = safeStore.getSafeServerToDisplay()

        self.maxBackupBytesValueLabel.text = safeConfigManager.getMaxBackupBytes() != nil ? String.localizedStringWithFormat("%1.2f KB", Float(safeConfigManager.getMaxBackupBytes()!) / 1024) : hyphen
        self.retentionDaysValueLabel.text = safeConfigManager.getRetentionDays() != nil ? String.localizedStringWithFormat(NSLocalizedString("number_of_days", comment: ""), safeConfigManager.getRetentionDays()!) : hyphen
        self.backupSizeValueLabel.text = safeConfigManager.getBackupSize() != nil ? String.localizedStringWithFormat(NSLocalizedString("%1.2f KB", comment: ""), Float(safeConfigManager.getBackupSize()!) / 1024) : hyphen
        self.lastBackupValueLabel.text = safeConfigManager.getLastBackup() != nil ? DateFormatter.mediumStyleDateShortStyleTime(safeConfigManager.getLastBackup()!) : hyphen
        self.lastResultValueLabel.text = safeConfigManager.getLastResult() != nil ? safeConfigManager.getLastResult()! : hyphen
        self.tableView.reloadData()
        
        setupColors()
    }
    
    @objc private func maybeHideActivityIndicator() {
        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
        let safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())
        if !safeManager.isBackupRunning {
            self.activityIndicator.stopAnimating()
            self.backupNowButtonLabel.isHidden = false
            backupNowCell.isUserInteractionEnabled = true
        }
        backupTimer = nil
    }
    
    private func setupColors() {
        let explainImage = self.explainButton.imageView?.image!.withTint(Colors.main())
        self.explainButton.setImage(explainImage, for: .normal)
        
        serverNameValueLabel.textColor = Colors.fontLight()
        maxBackupBytesValueLabel.textColor = Colors.fontLight()
        retentionDaysValueLabel.textColor = Colors.fontLight()
        lastBackupValueLabel.textColor = Colors.fontLight()
        backupSizeValueLabel.textColor = Colors.fontLight()
        lastResultValueLabel.textColor = Colors.fontLight()
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            activityIndicator.style = .white
            break
        case ColorThemeUndefined, ColorThemeLight, ColorThemeLightWork:
            activityIndicator.style = .gray
            break
        default:
            activityIndicator.style = .gray
            break
        }
        
        if self.lastResultValueLabel.text == NSLocalizedString("safe_successful", comment: "") {
            self.lastResultValueLabel.textColor = Colors.green()
        } else if self.lastResultValueLabel.text != "-" {
            self.lastResultValueLabel.textColor = UIColor.red
        }
    }
    
    // MARK: UITableViewDelegates

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 2:
            return indexPath.row == 2 && self.mdmSetup.isSafeBackupPasswordPreset() ? 0.0 : UITableView.automaticDimension
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 2 {
            switch indexPath.row {
            case 0:
                UIAlertTemplate.showAlert(owner: self, title: "Threema Safe", message: NSLocalizedString("safe_enable_explain", comment: ""))
                break
            case 1:
                backupNow()
                break
            case 2:
                if !self.mdmSetup.isSafeBackupPasswordPreset(),
                    let safeSetupViewController = self.parent as? SafeSetupViewController {
                    
                    safeSetupViewController .performSegue(withIdentifier: "SafeSetupPassword", sender: nil)
                }
                break
            default: break
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Colors.update(cell)
        setupColors()
    }
}

extension SafeActivatedViewController {
    
    @IBAction func touchDownExplainButton(_ sender: UIButton, forEvent event: UIEvent) {
        UIAlertTemplate.showAlert(owner: self, title: "Threema Safe", message: NSLocalizedString("safe_enable_explain", comment: ""))
    }
}
