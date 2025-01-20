//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaMacros

/// Shows who can see the profile picture and saves possible changes.
///
/// A user can choose between no one, anybody who receives a message from the user or select a set of recipients.
class ProfilePictureSettingViewController: ThemedTableViewController {
    
    var editProfileVC: EditProfileViewController?
    
    private var selectedIndexPath: IndexPath?
    private let businessInjector = BusinessInjector()
    private let receiverOfProfilePicture = [SendProfilePictureNone, SendProfilePictureAll, SendProfilePictureContacts]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = #localize("release_profilepicture_to")
    }
    
    // MARK: - Helper functions
    
    private func label(for sendProfilePicture: SendProfilePicture) -> String {
        switch sendProfilePicture {
        case SendProfilePictureNone:
            return #localize("send_profileimage_off")
        case SendProfilePictureAll:
            return #localize("send_profileimage_on")
        case SendProfilePictureContacts:
            return #localize("send_profileimage_contacts")
        default:
            DDLogError("An invalid SendProfilePicture options was chosen")
            return ""
        }
    }
    
    private func presentPickContact() {
        let storyboard = UIStoryboard(name: "ProfilePicture", bundle: nil)
        let pickContactsVC: PickContactsViewController? = storyboard
            .instantiateViewController(identifier: "PickContactsViewController")
        
        pickContactsVC?.editProfileVC = editProfileVC
        let indexPath = IndexPath(row: 0, section: 1)
        let cell = tableView.cellForRow(at: indexPath)
        if let vc = pickContactsVC, let cell {
            let navigationVC = ThemedNavigationController(rootViewController: vc)
            ModalPresenter.present(navigationVC, on: self, from: cell.frame, in: view)
        }
        else {
            DDLogError("pickContactsViewController or the cell could not be loaded.")
        }
    }
}

// MARK: - UITableViewDataSource

extension ProfilePictureSettingViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if let send = editProfileVC, send.sendProfilePicture == SendProfilePictureContacts {
            return 2
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return 1
        }
        return receiverOfProfilePicture.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard indexPath.section == 0 else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SendProfilePictureContactsCell", for: indexPath)
            cell.textLabel?.text = #localize("profile_picture_recipients")
            return cell
        }
        
        let cell: UITableViewCell = tableView.dequeueReusableCell(
            withIdentifier: "ProfilePictureSettingCell",
            for: indexPath
        )
        cell.accessoryType = .none
        
        cell.textLabel?.text = label(for: receiverOfProfilePicture[indexPath.row])
        if let send = editProfileVC, send.sendProfilePicture == receiverOfProfilePicture[indexPath.row] {
            cell.accessoryType = .checkmark
            selectedIndexPath = indexPath
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let send = editProfileVC, section == 0, send.sendProfilePicture == SendProfilePictureAll {
            return #localize("profileimage_setting_all_footer")
        }
        else if section == 1 {
            return #localize("profileimage_setting_contacts_footer")
        }
        return nil
    }
}

// MARK: - UITableViewDelegate

extension ProfilePictureSettingViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard indexPath.section == 0 else {
            tableView.performBatchUpdates {
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadSections([0], with: .automatic)
            }
            
            presentPickContact()
            return
        }
        editProfileVC?.sendProfilePicture = receiverOfProfilePicture[indexPath.row]
        
        let shouldShowPicker = indexPath.row == 2 && selectedIndexPath?.row != 2
        
        tableView.performBatchUpdates {
            tableView.deselectRow(at: indexPath, animated: true)
            
            if shouldShowPicker {
                tableView.insertSections([1], with: .fade)
            }
            else if let selected = selectedIndexPath, selected.row == 2, indexPath.row != 2 {
                tableView.deleteSections([1], with: .fade)
            }
            tableView.reloadSections([0], with: .automatic)
        }
        
        selectedIndexPath = indexPath
        
        if shouldShowPicker {
            presentPickContact()
        }
    }
}
