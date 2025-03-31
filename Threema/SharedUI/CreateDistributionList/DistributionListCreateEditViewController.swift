//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaFramework
import ThreemaMacros

class DistributionListCreateEditViewController: ThemedCodeModernGroupedTableViewController {
        
    // MARK: - Types
    
    private enum Section: Hashable {
        case general
        case recipients
    }
    
    private enum Row: Hashable {
        case distributionListName
        case contact(_ contact: Contact)
        case addRecipient(action: Details.Action)
    }
    
    private var recipients = Set<Contact>()
    private let businessInjector = BusinessInjector.ui
    
    private var distributionList: DistributionList?
    private var conversation: ConversationEntity?

    // MARK: - Private properties

    private lazy var dataSource = UITableViewDiffableDataSource<
        Section,
        Row
    >(tableView: tableView) { [weak self] tableView, indexPath, row -> UITableViewCell? in
        
        switch row {
        case .distributionListName:
            let editNameCell: EditNameTableViewCell = tableView.dequeueCell(for: indexPath)
            editNameCell.delegate = self
            editNameCell.nameType = .distributionListName
            editNameCell.name = self?.distributionListName
            return editNameCell
        
        case let .contact(contact):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.content = .contact(contact)
            return contactCell
            
        case let .addRecipient(action):
            let addRecipientCell: MembersActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            addRecipientCell.action = action
            return addRecipientCell
        }
    }
    
    private var profilePictureData: Data?
    private var distributionListName = ""
    
    // MARK: - Views
    
    private lazy var editProfilePictureView: EditProfilePictureView = {
        
        let initialProfilePicture: UIImage? = distributionList?.profilePicture
        let isDefaultImage = (profilePictureData == nil)
        
        let imageUpdated: EditProfilePictureView.ImageUpdated = { [weak self] newImageData -> (UIImage?, Bool) in
            guard let strongSelf = self else {
                return (nil, true)
            }
            
            // Store new image data
            strongSelf.profilePictureData = newImageData
            
            // Return default group profile picture if no data is available or readable
            guard let newImageData,
                  let newProfilePicture = UIImage(data: newImageData) else {
                let newProfilePicture: UIImage =
                    if let distributionList = strongSelf.distributionList {
                    
                        distributionList.generatedProfilePicture()
                    }
                    else {
                        ProfilePictureGenerator.unknownDistributionListImage
                    }
                
                strongSelf.updateSaveButtonState()
                return (newProfilePicture, true)
            }
            
            // Return new profile picture
            strongSelf.updateSaveButtonState()
            return (newProfilePicture, false)
        }
        
        return EditProfilePictureView(
            in: self,
            profilePicture: initialProfilePicture,
            isDefaultImage: isDefaultImage,
            isEditable: true,
            conversationType: .distributionList,
            imageUpdated: imageUpdated
        )
    }()
    
    private lazy var cancelButton: UIBarButtonItem = {
        let cancelButton = UIBarButtonItem(
            title: #localize("cancel"),
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        return cancelButton
    }()
    
    private lazy var saveButton: UIBarButtonItem = {
        let saveButton = UIBarButtonItem(
            title: #localize("Save"),
            style: .done,
            target: self,
            action: #selector(save)
        )
        saveButton.isEnabled = false
        return saveButton
    }()
    
    // MARK: - Lifecycle
        
    convenience init(distributionList: DistributionList?) {
        self.init()
        self.distributionList = distributionList
        
        guard let distributionList else {
            return
        }
        
        self.conversation = businessInjector.entityManager.entityFetcher
            .conversation(for: distributionList.distributionListID as NSNumber)
        
        populateInfo()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
        configureNavigationBar()
        configureTableView()
        updateRecipientsCountLabel()
        registerCells()
        configureSnapshot()
        addObservers()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
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
        if distributionList != nil {
            navigationBarTitle = #localize("distribution_list_edit")
        }
        else {
            navigationBarTitle = #localize("distribution_list_create")
        }
        
        transparentNavigationBarWhenOnTop = true
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = saveButton
    }
    
    private func configureTableView() {
        tableView.tableHeaderView = editProfilePictureView
        tableView.delegate = self
        
        tableView.keyboardDismissMode = .onDrag
    }
    
    private func registerCells() {
        tableView.registerHeaderFooter(DetailsSectionHeaderView.self)
        tableView.registerCell(EditNameTableViewCell.self)
        tableView.registerCell(ContactCell.self)
        tableView.registerCell(MembersActionDetailsTableViewCell.self)
    }
    
    private func configureSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        // General
        snapshot.appendSections([.general])
        snapshot.appendItems([.distributionListName], toSection: .general)
        
        // Recipients
        snapshot.appendSections([.recipients])
        let recipient = recipients.compactMap { Row.contact($0) }
        snapshot.appendItems(recipient, toSection: .recipients)
        snapshot.appendItems([.addRecipient(action: addRecipientsAction())], toSection: .recipients)
        
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
    
    private func populateInfo() {
        distributionListName = String(distributionList?.displayName ?? "")
        if let preExistingRecipients = distributionList?.recipients {
            recipients = preExistingRecipients
            refresh()
        }
    }
    
    // MARK: - Updates

    private func updateSaveButtonState() {
        // Deactivate save button as long as name is empty, recipients is empty, or nothing changed
        guard !distributionListName.isEmpty, !recipients.isEmpty,
              nameDidChange || profilePictureDidChange || recipientsDidChange else {
            saveButton.isEnabled = false
            return
        }
        
        saveButton.isEnabled = true
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
    
    private func updateRecipientsCountLabel() {
        guard let header = tableView.headerView(forSection: 1) as? DetailsSectionHeaderView else {
            return
        }
        
        header.title = String.localizedStringWithFormat(
            #localize("distribution_list_recipients_section_header"),
            recipients.count
        )
    }
  
    // MARK: - Actions

    @objc private func save() {
        let distributionListManager = businessInjector.distributionListManager

        if let distributionList {
                
            distributionListManager.setName(of: distributionList, to: distributionListName)
            distributionListManager.setRecipients(of: distributionList, to: recipients)
            distributionListManager.setProfilePicture(of: distributionList, to: profilePictureData)
            dismiss(animated: true)
        }
        else {
            let entityManager = businessInjector.entityManager
            var conversation: ConversationEntity?
                
            do {
                entityManager.performAndWaitSave {
                    conversation = entityManager.entityCreator.conversationEntity()
                }
                    
                guard let conversation else {
                    throw DistributionListManager.DistributionListError.creationFailure
                }
                    
                try distributionListManager.createDistributionList(
                    conversation: conversation,
                    name: distributionListName,
                    imageData: profilePictureData,
                    recipients: recipients
                )
                    
                dismiss(animated: true) {
                    // Open after creation
                    let info = [kKeyConversation: conversation, kKeyForceCompose: true] as [String: Any]
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: info
                    )
                }
            }
            catch {
                UIAlertTemplate.showAlert(owner: self, title: "something went wrong", message: "OOPS")
            }
        }
    }
    
    @objc private func cancel() {
        dismiss(animated: true)
    }

    private func addRecipientsAction() -> Details.Action {
        let localizedAddRecipientsButton = #localize("group_manage_members_button")
        let action = Details.Action(
            title: localizedAddRecipientsButton,
            imageName: "plus"
        ) { [weak self] cell in
            guard let strongSelf = self
            else {
                return
            }
            
            let storyboard = UIStoryboard(name: "CreateGroup", bundle: nil)
            guard let pickRecipientsViewController = storyboard
                .instantiateViewController(
                    withIdentifier: "PickGroupMembersViewController"
                ) as? PickGroupMembersViewController
            else {
                DDLogWarn("Unable to load PickGroupMembersViewController from storyboard")
                return
            }
            
            let completion: ((Set<AnyHashable>?) -> Void) = { selection in
                guard let selection = selection as? Set<ContactEntity> else {
                    return
                }
                strongSelf.recipients = Set(selection.map {
                    Contact(contactEntity: $0)
                })
                strongSelf.configureSnapshot()
                strongSelf.updateSaveButtonState()
                strongSelf.updateRecipientsCountLabel()
            }
            
            if !strongSelf.recipients.isEmpty {
                strongSelf.businessInjector.entityManager.performAndWait {
                    let contactEntities: Set<ContactEntity> = Set(strongSelf.recipients.compactMap {
                        strongSelf.businessInjector.entityManager.entityFetcher.contact(for: $0.identity.string)
                    })
                    pickRecipientsViewController.setMembers(contactEntities)
                }
            }
            
            pickRecipientsViewController.didSelect = completion
            
            let navigationViewController =
                ThemedNavigationController(rootViewController: pickRecipientsViewController)
            
            ModalPresenter.present(
                navigationViewController,
                on: strongSelf,
                from: cell.frame,
                in: strongSelf.view
            )
        }
        return action
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

extension DistributionListCreateEditViewController {
    private var nameDidChange: Bool {
        distributionList?.displayName != distributionListName
    }
    
    private var recipientsDidChange: Bool {
        distributionList?.recipients != recipients
    }
    
    private var profilePictureDidChange: Bool {
        // TODO: (IOS-4366) Fix check
        if let distributionList, true {
            return false
        }
        return true
    }
    
    @objc private func hideKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITableViewDelegate

extension DistributionListCreateEditViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        
        switch section {
        case .general:
            guard let editNameCell = tableView.cellForRow(at: indexPath) else {
                break
            }
            
            editNameCell.becomeFirstResponder()
            
        case .recipients:
            let row = dataSource.snapshot().itemIdentifiers[indexPath.row + 1]
            switch row {
            case let .addRecipient(action):
                guard let cell = tableView.cellForRow(at: indexPath) else {
                    fatalError("We should have a cell that was tapped for an action.")
                }
                action.run(cell)
            default:
                break
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else {
            return nil
        }
        let headerView: DetailsSectionHeaderView? = tableView.dequeueHeaderFooter()
        headerView?.title = String.localizedStringWithFormat(
            #localize("distribution_list_recipients_section_header"),
            recipients.count
        )
        return headerView
    }
}

// MARK: - EditNameTableViewCellDelegate

extension DistributionListCreateEditViewController: EditNameTableViewCellDelegate {
    func editNameTableViewCell(_ editNameTableViewCell: EditNameTableViewCell, didChangeTextTo newText: String?) {
        assert(
            editNameTableViewCell.nameType == .distributionListName,
            "There should only be a cell for the group name"
        )
        
        distributionListName = newText ?? ""
        updateSaveButtonState()
    }
}
