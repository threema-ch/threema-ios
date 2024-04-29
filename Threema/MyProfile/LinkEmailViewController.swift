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

import Foundation
import MBProgressHUD

class LinkEmailViewController: ThemedTableViewController {
    
    @IBOutlet var emailTextField: UITextField!
    var serverName = ""
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = BundleUtil.localizedString(forKey: "link_email_title")
        navigationItem.rightBarButtonItem?.title = BundleUtil.localizedString(forKey: "save")
        navigationItem.leftBarButtonItem?.title = BundleUtil.localizedString(forKey: "cancel")
        emailTextField.keyboardAppearance = UIKeyboardAppearance.default
        
        ServerInfoProviderFactory.makeServerInfoProvider()
            .directoryServer(ipv6: UserSettings.shared().enableIPv6) { directoryServerInfo, _ in
                if let urlString = directoryServerInfo?.url,
                   let url = URL(string: urlString) {
                    self.serverName = url.host ?? ""
                }
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        emailTextField.text = MyIdentityStore.shared().linkedEmail
        
        if let mdmSetup = MDMSetup(setup: false), mdmSetup.readonlyProfile() {
            emailTextField.isEnabled = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if emailTextField.isEnabled {
            emailTextField.becomeFirstResponder()
        }
    }

    // MARK: - TableViewDelegates
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if ThreemaApp.current == .onPrem {
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "myprofile_link_email_onprem_footer"),
                serverName,
                ThreemaApp.currentName
            )
        }
        return String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "myprofile_link_email_footer"),
            ThreemaApp.currentName
        )
    }
    
    // MARK: - Helper functions
    
    @IBAction func saveAction(_ sender: Any) {
        if emailTextField.text == MyIdentityStore.shared().linkedEmail {
            dismiss(animated: true, completion: nil)
            return
        }
        navigationItem.rightBarButtonItem?.isEnabled = false
        emailTextField.resignFirstResponder()
        MBProgressHUD.showAdded(to: view, animated: true)
        
        let conn = ServerAPIConnector()
        conn.linkEmail(
            with: MyIdentityStore.shared(),
            email: emailTextField.text,
            onCompletion: { [self] linked in
                
                MBProgressHUD.hide(for: view, animated: true)
                if let text = emailTextField.text, !text.isEmpty, !linked {
                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: BundleUtil.localizedString(forKey: "link_email_sent_title"),
                        message: String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "link_email_sent_message"), text
                        ), actionOk: { [self] _ in
                            dismiss(animated: true)
                        }
                    )
                }
                else {
                    dismiss(animated: true, completion: nil)
                }
                
            }, onError: { _ in
                MBProgressHUD.hide(for: self.view, animated: true)
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                UIAlertTemplate.showAlert(
                    owner: self,
                    title: BundleUtil.localizedString(forKey: "invalid_email_address_title"),
                    message: BundleUtil.localizedString(forKey: "invalid_email_address_message"),
                    actionOk: nil
                )
            }
        )
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
