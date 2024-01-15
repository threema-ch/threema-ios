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

import UIKit

/// Show an edit view for the provided contact
///
/// - This is optimized to be used in a modal view
/// - Only use with a contact that is not linked to a system contact!
final class EditContactViewController: ThemedCodeModernGroupedTableViewController {
    
    // MARK: - Types
    
    private enum Section: Hashable {
        case editName
    }
    
    private enum Row: Hashable {
        case firstName
        case lastName
    }
    
    // MARK: - Private properties
        
    private lazy var dataSource = UITableViewDiffableDataSource<Section, Row>(
        tableView: tableView
    ) { [weak self] tableView, indexPath, row -> UITableViewCell? in
        
        let editNameCell: EditNameTableViewCell = tableView.dequeueCell(for: indexPath)
        editNameCell.delegate = self

        switch row {
        case .firstName:
            editNameCell.nameType = .firstName
            editNameCell.name = self?.firstName
        case .lastName:
            editNameCell.nameType = .lastName
            editNameCell.name = self?.lastName
        }
        
        return editNameCell
    }
    
    private let contact: ContactEntity
    
    private var avatarImageData: Data?
    private let avatarImageIsEditable: Bool
    
    private var firstName: String?
    private var lastName: String?
    
    private var entityManager = EntityManager()
    
    // MARK: Subview
    
    private lazy var editAvatarView: EditAvatarView = {
        let initialAvatarImage = AvatarMaker.shared().avatar(
            for: contact,
            size: EditAvatarView.avatarImageSize,
            masked: true
        )
        
        let isDefaultImage = avatarImageData == nil
        
        let imageUpdated: EditAvatarView.ImageUpdated = { [weak self] newImageData -> (UIImage?, Bool) in
            guard let strongSelf = self else {
                return (nil, true)
            }
            
            // Store new image data
            strongSelf.avatarImageData = newImageData
            
            // Return default initials avatar if no data is available or readable
            guard let newImageData,
                  let newImage = UIImage(data: newImageData) else {
                
                let newAvatarImage = AvatarMaker.shared().initialsAvatar(
                    for: strongSelf.contact,
                    size: EditAvatarView.avatarImageSize,
                    masked: true
                )
                
                return (newAvatarImage, true)
            }
            
            // Return new avatar image
            let newAvatarImage = AvatarMaker.maskImage(newImage)
            return (newAvatarImage, false)
        }
        
        return EditAvatarView(
            in: self,
            avatarImage: initialAvatarImage,
            isDefaultImage: isDefaultImage,
            isEditable: avatarImageIsEditable,
            imageUpdated: imageUpdated
        )
    }()
    
    // MARK: - Lifecycle
    
    /// Create a new edit contact view controller to present modally embedded in a navigation controller
    /// - Parameter contact: Contact to be edited
    init(for contact: ContactEntity) {
        assert(contact.cnContactID == nil, "Only use with a contact that is not linked to a system contact")
        
        self.contact = contact
        
        // Prevent editing of avatar if received profile pictures are shown and we actually received one
        let showProfilePictures = UserSettings.shared()?.showProfilePictures ?? false
        if contact.isGatewayID() {
            // Special case for gateway ids as avatar is not editable
            self.avatarImageIsEditable = false
        }
        else if let contactImageData = contact.contactImage?.data, showProfilePictures {
            // A received avatar image is not editable
            self.avatarImageData = contactImageData
            self.avatarImageIsEditable = false
        }
        else {
            // The avatar is set by the user, thus it can be changed
            self.avatarImageData = contact.imageData
            self.avatarImageIsEditable = true
        }
        
        self.firstName = contact.firstName
        self.lastName = contact.lastName
        
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateEditAvatarFrameHeight()
    }
    
    // MARK: - Configuration
    
    private func configureController() {
        isModalInPresentation = true
    }
    
    private func configureNavigationBar() {
        navigationBarTitle = BundleUtil.localizedString(forKey: "edit_contact_title")
        
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
        tableView.tableHeaderView = editAvatarView
        tableView.delegate = self
        
        tableView.keyboardDismissMode = .onDrag
    }
    
    private func registerCells() {
        tableView.registerCell(EditNameTableViewCell.self)
    }

    private func configureSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        snapshot.appendSections([.editName])
        snapshot.appendItems([.firstName, .lastName])
        
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
    
    private func updateEditAvatarFrameHeight() {
        let editAvatarViewHeight = editAvatarView.systemLayoutSizeFitting(view.bounds.size).height
        
        let updateFrameHeight = { self.editAvatarView.frame.size.height = editAvatarViewHeight }
        
        // Only update if height was 0 before or did change
        // Only animate if previous height was non-zero, otherwise we get unsatisfiable constraints
        if editAvatarView.frame.height == 0 {
            updateFrameHeight()
        }
        else if editAvatarViewHeight != editAvatarView.frame.height {
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
        saveChanges()
        dismiss(animated: true)
    }
    
    // MARK: - Notifications
    
    @objc private func contentSizeCategoryDidChange() {
        updateEditAvatarFrameHeight()
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

// MARK: - Helper

extension EditContactViewController {
    private func saveChanges() {
        // Save the data
        BusinessInjector().contactStore.updateContact(
            withIdentity: contact.identity,
            avatar: avatarImageData,
            firstName: firstName,
            lastName: lastName
        )
    }
}

// MARK: - UITableViewDelegate

extension EditContactViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let editNameCell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        editNameCell.becomeFirstResponder()
    }
}

// MARK: - EditNameTableViewCellDelegate

extension EditContactViewController: EditNameTableViewCellDelegate {
    func editNameTableViewCell(_ editNameTableViewCell: EditNameTableViewCell, didChangeTextTo newText: String?) {
        switch editNameTableViewCell.nameType {
        case .firstName:
            firstName = newText
        case .lastName:
            lastName = newText
        default:
            fatalError("Not supported EditNameTableViewCell.NameType \(editNameTableViewCell.nameType)")
        }
    }
}
