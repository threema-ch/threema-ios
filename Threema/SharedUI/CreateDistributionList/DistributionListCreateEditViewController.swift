//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

class DistributionListCreateEditViewController: ThemedCodeModernGroupedTableViewController {
        
    // MARK: - Types
    
    private enum Section: Hashable {
        case general
        case recipients
    }
    
    private enum Row: Hashable {
        case distributionListName
        case contact(_ contact: ContactEntity)
        case addRecipient(action: Details.Action)
    }
    
    private var recipients = [ContactEntity]()
    private let entityManager = EntityManager()
    
    private var distributionList: DistributionListEntity? = nil
    
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
            contactCell.content = .contact(Contact(contactEntity: contact))
            return contactCell
        case let .addRecipient(action):
            let addRecipientCell: MembersActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            addRecipientCell.action = action
            return addRecipientCell
        default:
            fatalError("Not supported")
        }
    }
    
    private var avatarImageData: Data?
    private var distributionListName: String?
    
    // MARK: - Views
    
    private lazy var editAvatarView: EditAvatarView = {
        
        let initialAvatarImage: UIImage?
        
        if let image = distributionList?.conversation?.groupImage, let uiImage = image.uiImage {
            initialAvatarImage = AvatarMaker.maskImage(uiImage)
            avatarImageData = image.data
        }
        else {
            initialAvatarImage = AvatarMaker.shared().unknownDistributionListImage()
        }
        
        let isDefaultImage = (avatarImageData == nil)
        
        let imageUpdated: EditAvatarView.ImageUpdated = { [weak self] newImageData -> (UIImage?, Bool) in
            guard let strongSelf = self else {
                return (nil, true)
            }
            
            // Store new image data
            strongSelf.avatarImageData = newImageData
            
            // Return default group avatar if no data is available or readable
            guard let newImageData,
                  let newImage = UIImage(data: newImageData) else {
                
                let newAvatarImage = AvatarMaker.shared().unknownGroupImage()
                
                strongSelf.updateSaveButtonState()
                return (newAvatarImage, true)
            }
            
            // Return new avatar image
            let newAvatarImage = AvatarMaker.maskImage(newImage)
            strongSelf.updateSaveButtonState()
            return (newAvatarImage, false)
        }
        
        return EditAvatarView(
            in: self,
            avatarImage: initialAvatarImage,
            isDefaultImage: isDefaultImage,
            isEditable: true,
            imageUpdated: imageUpdated
        )
    }()
    
    private lazy var cancelButton: UIBarButtonItem = {
        let cancelButton = UIBarButtonItem(
            title: "Cancel".localized,
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        return cancelButton
    }()
    
    private lazy var saveButton: UIBarButtonItem = {
        let saveButton = UIBarButtonItem(
            title: "Save".localized,
            style: .done,
            target: self,
            action: #selector(save)
        )
        saveButton.isEnabled = false
        return saveButton
    }()
    
    // MARK: - Lifecycle
        
    convenience init(distributionList: DistributionListEntity?) {
        self.init()
        self.distributionList = distributionList
        
        if distributionList != nil {
            populateInfo()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
        configureNavigationBar()
        configureTableView()
        registerCells()
        configureSnapshot()
        addObservers()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
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
        if distributionList != nil {
            navigationBarTitle = "distribution_list_edit".localized
        }
        else {
            navigationBarTitle = "distribution_list_create".localized
        }
        
        transparentNavigationBarWhenOnTop = true
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = saveButton
    }
    
    private func configureTableView() {
        tableView.tableHeaderView = editAvatarView
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
        distributionListName = String(distributionList?.name ?? "")
        if let preExistingRecipients = distributionList?.conversation?.members {
            recipients = Array(preExistingRecipients)
            refresh()
        }
    }
    
    // MARK: - Updates

    private func updateSaveButtonState() {
        // Deactivate save button as long as name is empty, or no recipients is empty
        guard let distributionListName, !distributionListName.isEmpty, !recipients.isEmpty,
              nameDidChange || avatarImageDidChange else {
            saveButton.isEnabled = false
            return
        }
        
        saveButton.isEnabled = true
    }
    
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

    @objc private func save() {
        let em = EntityManager()
        em.performSyncBlockAndSafe {
            
            if let distributionList = self.distributionList, let conversation = distributionList.conversation {

                distributionList.name = (self.distributionListName ?? "") as NSString

                if let avatarImageData = self.avatarImageData, let image = UIImage(data: avatarImageData) {
                    
                    let dbImage = self.entityManager.entityCreator.imageData()
                    dbImage?.data = avatarImageData
                    dbImage?.width = NSNumber(floatLiteral: Double(image.size.width))
                    dbImage?.height = NSNumber(floatLiteral: Double(image.size.height))
                    conversation.groupImage = dbImage
                }
                conversation.members = Set(self.recipients)
                
                self.dismiss(animated: true)
            }
            else {
                
                guard let conversation = em.entityCreator.conversation(),
                      let distributionList = em.entityCreator.distributionListEntity() else {
                    fatalError()
                }
                
                let id = Int64.random(in: 0..<Int64.max)
                // swiftformat:disable:next acronyms
                distributionList.distributionListId = NSNumber(value: id)
                
                conversation.distributionList = distributionList
                distributionList.name = (self.distributionListName ?? "") as NSString
                
                if let avatarImageData = self.avatarImageData, let image = UIImage(data: avatarImageData) {
                    let dbImage = self.entityManager.entityCreator.imageData()
                    dbImage?.data = avatarImageData
                    dbImage?.width = NSNumber(floatLiteral: Double(image.size.width))
                    dbImage?.height = NSNumber(floatLiteral: Double(image.size.height))
                    conversation.groupImage = dbImage
                }
                
                conversation.members = Set(self.recipients)
                
                self.dismiss(animated: true) {
                    // Open after creation
                    let info = [kKeyConversation: conversation, kKeyForceCompose: true] as [String: Any]
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: info
                    )
                }
            }
        }
    }
    
    @objc private func cancel() {
        dismiss(animated: true)
    }

    func addRecipientsAction() -> Details.Action {
        let localizedAddRecipientsButton = BundleUtil.localizedString(forKey: "group_manage_members_button")
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
                strongSelf.recipients = Array(selection)
                strongSelf.configureSnapshot()
                strongSelf.updateSaveButtonState()
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

// MARK: - Helpers

extension DistributionListCreateEditViewController {
    private var nameDidChange: Bool {
        String(distributionList?.name ?? "") != distributionListName
    }
    
    private var avatarImageDidChange: Bool {
        avatarImageData != distributionList?.conversation?.groupImage?.data
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
            "distribution_list_recipients_section_header".localized,
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
        
        distributionListName = newText
        updateSaveButtonState()
    }
}
