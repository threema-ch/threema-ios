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
import ThreemaMacros
import UIKit

/// Show an edit view for the provided group
///
/// - This is optimized to be used in a modal view
final class EditGroupViewController: ThemedCodeModernGroupedTableViewController {
    
    // MARK: - Types
    
    private enum Section: Hashable {
        case editName
        case editMembers
    }
    
    private enum Row: Hashable {
        case groupName
        
        // These are here for future use
        case meContact
        case contact(_ contact: ContactEntity)
        case membersAction(_ action: Details.Action)
    }
    
    // MARK: - Private properties
        
    private lazy var dataSource = UITableViewDiffableDataSource<
        Section,
        Row
    >(tableView: tableView) { [weak self] tableView, indexPath, row -> UITableViewCell? in
        
        switch row {
        case .groupName:
            let editNameCell: EditNameTableViewCell = tableView.dequeueCell(for: indexPath)
            editNameCell.delegate = self
            editNameCell.nameType = .groupName
            editNameCell.name = self?.groupName
            return editNameCell
        default:
            fatalError("Not supported")
        }
    }
    
    private let group: Group
    
    private var profilePictureImageData: Data?
    private var groupName: String?
    // TODO: Store members or at least member changes?
    
    private var groupManager: GroupManagerProtocol = BusinessInjector.ui.groupManager
    
    // MARK: Subview
    
    private lazy var editProfilePictureView: EditProfilePictureView = {
        let imageUpdated: EditProfilePictureView.ImageUpdated = { [weak self] newImageData -> (UIImage?, Bool) in
            guard let strongSelf = self else {
                return (nil, true)
            }
                
            // Store new image data
            strongSelf.profilePictureImageData = newImageData
                
            // Return default group profile picture if no data is available or readable
            guard let newImageData,
                  let newProfilePicture = UIImage(data: newImageData) else {
                    
                let newProfilePicture = strongSelf.group.generatedProfilePicture()
                    
                return (newProfilePicture, true)
            }
                
            // Return new group profile
            return (newProfilePicture, false)
        }
            
        return EditProfilePictureView(
            in: self,
            profilePicture: group.profilePicture,
            isDefaultImage: !group.usesNonGeneratedProfilePicture,
            isEditable: true,
            conversationType: .group,
            imageUpdated: imageUpdated
        )
    }()
    
    // MARK: - Lifecycle
    
    /// Create a new edit group view controller to present modally embedded in a navigation controller
    /// - Parameter group: Group to be edited
    init(for group: Group) {
        precondition(group.isOwnGroup, "You should only be able to edit your own groups.")
        
        self.group = group
        
        self.profilePictureImageData = group.old_ProfilePicture
        self.groupName = group.name
        
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
        configureNavigationBar()
        configureTableView()
        registerCells()
        configureSnapshot()
        addObservers()
        
        // The text in the textfield should not have changed until here
        updateSaveButtonState(for: groupName)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateEditProfilePictureFrameHeight()
    }
    
    // MARK: - Configuration
    
    private func configureController() {
        isModalInPresentation = true
    }
    
    private func configureNavigationBar() {
        navigationBarTitle = #localize("edit_group_title")
        
        transparentNavigationBarWhenOnTop = true
        
        let cancelBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        let saveBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveButtonTapped)
        )
        saveBarButtonItem.style = .done
        
        navigationItem.leftBarButtonItem = cancelBarButtonItem
        navigationItem.rightBarButtonItem = saveBarButtonItem
    }
    
    private func configureTableView() {
        tableView.tableHeaderView = editProfilePictureView
        tableView.delegate = self
        
        tableView.keyboardDismissMode = .onDrag
    }
    
    private func registerCells() {
        tableView.registerCell(EditNameTableViewCell.self)
    }

    private func configureSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        snapshot.appendSections([.editName])
        snapshot.appendItems([.groupName])
        
        // TODO: Members
        
        dataSource.apply(snapshot)
    }
    
    private func addObservers() {
        // Dynamic type
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
        // Keyboard
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWasShown(notification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillBeHidden(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Updates
    
    private func updateSaveButtonState(for newName: String?) {
        // Deactivate save button if name is empty
        guard let newName, !newName.isEmpty else {
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }
        
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    private func updateEditProfilePictureFrameHeight() {
        let editProfilePictureViewHeight = editProfilePictureView.systemLayoutSizeFitting(view.bounds.size).height
        
        let updateFrameHeight = { self.editProfilePictureView.frame.size.height = editProfilePictureViewHeight }
        
        // Only update if height was 0 before or did change
        // Only animate if previous height was non-zero, otherwise we get unsatisfiable constraints
        if editProfilePictureView.frame.height == 0 {
            updateFrameHeight()
        }
        else if editProfilePictureViewHeight != editProfilePictureView.frame.height {
            // Use table view update to animate height change
            // https://stackoverflow.com/a/32228700/286611
            tableView.performBatchUpdates(updateFrameHeight)
        }
    }
    
    private func updateContentInsets(to newContentInsets: UIEdgeInsets) {
        tableView.contentInset = newContentInsets
        tableView.scrollIndicatorInsets = newContentInsets
    }
    
    // MARK: - Actions
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        saveGroupName()
        saveProfilePicture()
        dismiss(animated: true)
    }
    
    // MARK: - Notifications
    
    @objc private func contentSizeCategoryDidChange() {
        updateEditProfilePictureFrameHeight()
    }
    
    @objc private func keyboardWasShown(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardSizeValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else {
            updateContentInsets(to: .zero)
            return
        }
        
        let keyboardSize = keyboardSizeValue.cgRectValue
        let newContentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        updateContentInsets(to: newContentInset)
    }
    
    @objc private func keyboardWillBeHidden(notification: Notification) {
        updateContentInsets(to: .zero)
    }
}

// MARK: - Helpers

extension EditGroupViewController {
    private var groupNameDidChange: Bool {
        group.name != groupName
    }
    
    private var profilePictureDidChange: Bool {
        group.old_ProfilePicture != profilePictureImageData
    }
    
    private func saveGroupName() {
        guard groupNameDidChange else {
            return
        }
        
        Task { @MainActor in
            do {
                try await groupManager.setName(group: group, name: groupName)
            }
            catch {
                DDLogError("Unable to save group name: \(error)")
            }
        }
    }
    
    private func saveProfilePicture() {
        guard profilePictureDidChange else {
            return
        }
        
        Task { @MainActor in
            do {
                if let profilePictureImageData {
                    try await groupManager.setPhoto(
                        group: group,
                        imageData: profilePictureImageData,
                        sentDate: Date()
                    )
                }
                else {
                    // A `nil` profile picture means it's been deleted
                    try await groupManager.deletePhoto(
                        groupID: group.groupID,
                        creator: group.groupCreatorIdentity,
                        sentDate: Date()
                    )
                }
            }
            catch {
                DDLogError("Unable to update/delete group photo: \(error)")
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension EditGroupViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        
        guard section == .editName else {
            return
        }
        
        guard let editNameCell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        editNameCell.becomeFirstResponder()
    }
}

// MARK: - EditNameTableViewCellDelegate

extension EditGroupViewController: EditNameTableViewCellDelegate {
    func editNameTableViewCell(_ editNameTableViewCell: EditNameTableViewCell, didChangeTextTo newText: String?) {
        assert(editNameTableViewCell.nameType == .groupName, "There should only be a cell for the group name")
        
        groupName = newText
        
        updateSaveButtonState(for: newText)
    }
}
