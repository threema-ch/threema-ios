import CocoaLumberjackSwift
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

/// Shows an edit view for a provided group or distribution list
///
/// - This is optimized to be used in a modal view
final class CreateEditGroupDistributionViewController: UICollectionViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        static var contactsPerRow: Int {
            AppDelegate.shared().isCompactSizeClass ? 5 : 7
        }

        static let maxMembers = Group.maxGroupMembers
        static let sectionInset = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20)
        static let contactsInterGroupSpacing: CGFloat = 16
        static let contactsInterItemSpacing: CGFloat = 16
    }
    
    // MARK: - Types
    
    private enum Section: Int, Hashable {
        case editPicture
        case editName
        case editContacts
    }
    
    private enum Row: Hashable {
        case profilePicture
        case nameField
        case editContact(_ contact: Contact)
        case addContact
        
        // These are here for future use
        case meContact
        case contact(_ contact: ContactEntity)
        case membersAction(_ action: Details.Action)
    }
    
    // MARK: - Private properties
        
    private lazy var contactProvider = ContactListProvider()
    private lazy var dataSource = {
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Row
        >(collectionView: self.collectionView) { [weak self] collectionView, indexPath, row -> UICollectionViewCell? in
            
            switch row {
            case .profilePicture:
                let profilePictureCell: CreateEditGroupDistributionListProfilePictureCell = collectionView
                    .dequeueCell(for: indexPath)
                
                guard let self else {
                    return profilePictureCell
                }
                
                profilePictureCell.configure(view: editProfilePictureView)
                return profilePictureCell
                
            case .nameField:
                let editNameCell: CreateEditGroupDistributionNameCell = collectionView.dequeueCell(for: indexPath)

                guard let self else {
                    return editNameCell
                }

                editNameCell.nameType = displayMode.isGroup ? .groupName : .distributionListName
                editNameCell.name = name
                editNameCell.onTextChanged = { [weak self] newName in
                    guard let self else {
                        return
                    }
                    
                    name = newName
                    updateSaveButtonState(for: newName)
                }
                return editNameCell
                
            case let .editContact(contact):
                let editContactCell: SelectedItemGridCell = collectionView.dequeueCell(for: indexPath)
                editContactCell.configure(for: SelectableItem(
                    id: contact.objectID,
                    item: .contact(contact),
                    isSelected: false
                ))
                editContactCell.onClear = { [weak self] in
                    guard let self else {
                        return
                    }
                    contacts.removeAll { $0.identity == contact.identity }
                    configureSnapshot(animated: true)
                }
                return editContactCell
                
            case .addContact:
                let addContactCell: ContactGridAddButtonCell = collectionView
                    .dequeueCell(for: indexPath)
                addContactCell.onTap = { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    addMembers()
                }
                return addContactCell
                
            default:
                fatalError("Not supported")
            }
        }
        
        dataSource
            .supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
                guard let section = Section(rawValue: indexPath.section),
                      let self,
                      section == .editContacts,
                      kind == UICollectionView.elementKindSectionHeader else {
                    return nil
                }
            
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: ContactGridHeaderView.reuseIdentifier,
                    for: indexPath
                ) as? ContactGridHeaderView
            
                header?.configure(for: displayMode.countLabelKind, with: contacts.count)
                return header
            }
        
        return dataSource
    }()
    
    private let onReturnFromSelection: ((EditData) -> Void)?
    private let groupManager = BusinessInjector.ui.groupManager
    private let distributionListManager = BusinessInjector.ui.distributionListManager
    private let entityManager = BusinessInjector.ui.entityManager
    private let displayMode: CreateEditGroupDistributionListDisplayMode
    private let myIdentity = MyIdentityStore.shared().identity ?? ""
    private let onSaveDisplayMode: OnSaveDisplayMode
    private var name: String?
    private var profilePictureImageData: Data?
    private var contacts: [Contact] = []
    
    // MARK: Subview
    
    private lazy var cancelBarButtonItem = UIBarButtonItem.cancelButton(
        target: self,
        selector: #selector(cancelButtonTapped)
    )
    
    private lazy var saveBarButtonItem = UIBarButtonItem.saveButton(
        target: self,
        selector: #selector(saveButtonTapped)
    )
    
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
                
                let newProfilePicture = strongSelf.displayMode.generateProfilePicture()
                return (newProfilePicture, true)
            }
                
            // Return new group profile
            return (newProfilePicture, false)
        }
            
        return EditProfilePictureView(
            in: self,
            profilePicture: displayMode.profilePicture,
            isDefaultImage: displayMode.usesNonGeneratedProfilePicture.map { !$0 } ?? true,
            isEditable: true,
            conversationType: displayMode.conversationType,
            imageUpdated: imageUpdated
        )
    }()
    
    // MARK: - Sections
    
    private static var editPictureSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(150)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = Constants.sectionInset
        return section
    }
    
    private static var editNameSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(52)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(52)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = Constants.sectionInset
        return section
    }
    
    private static var membersSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(Constants.contactsPerRow)),
            heightDimension: .estimated(80)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(80)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: Constants.contactsPerRow
        )
        group.interItemSpacing = NSCollectionLayoutSpacing.fixed(Constants.contactsInterItemSpacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Constants.contactsInterGroupSpacing
        section.contentInsets = Constants.sectionInset
        
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(40)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }
    
    // MARK: - Lifecycle
    
    init(
        for displayMode: CreateEditGroupDistributionListDisplayMode,
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails,
        onReturnFromSelection: ((EditData) -> Void)? = nil
    ) {
        self.onSaveDisplayMode = onSaveDisplayMode
        self.displayMode = displayMode
        self.onReturnFromSelection = onReturnFromSelection
        
        let createSection: (Section) -> NSCollectionLayoutSection = { section in
            switch section {
            case .editPicture:
                Self.editPictureSection
            case .editName:
                Self.editNameSection
            case .editContacts:
                Self.membersSection
            }
        }
        
        let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else {
                fatalError(
                    "Unknown section index \(sectionIndex). Make sure to update the `Section` accordingly."
                )
            }
            return createSection(section)
        }
        super.init(collectionViewLayout: layout)
        preFillData()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        updateSaveButtonState(for: name)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent {
            onReturnFromSelection?(
                .init(name: name, profilePicture: profilePictureImageData, contacts: contacts)
            )
        }
    }
    
    // MARK: - Configuration
    
    private func preFillData() {
        switch displayMode {
        case let .group(action):
            switch action {
            case let .edit(group):
                precondition(group.isOwnGroup, "You should only be able to edit the groups you are the creator of.")
                profilePictureImageData = group.old_ProfilePicture
                name = group.name
                contacts = group.sortedMembers.compactMap {
                    if case let .contact(contact) = $0 {
                        return contact
                    }
                    return nil
                }

            case let .clone(group, data):
                profilePictureImageData = data.profilePicture ?? group.old_ProfilePicture
                name = data.name ?? group.name
                contacts = data.contacts

            case let .create(data):
                profilePictureImageData = data.profilePicture
                name = data.name
                contacts = data.contacts
            }

        case let .distributionList(action):
            switch action {
            case let .edit(list):
                name = list.displayName
                contacts = Array(list.recipients)

            case let .create(data):
                profilePictureImageData = data.profilePicture
                name = data.name
                contacts = data.contacts
            }
        }
    }
    
    private func configureController() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = false
        isModalInPresentation = true
    }
    
    private func configureNavigationBar() {
        navigationItem.title = displayMode.title
        
        if displayMode.isEdit {
            navigationItem.leftBarButtonItem = cancelBarButtonItem
        }
        
        saveBarButtonItem.style = .done
        navigationItem.rightBarButtonItem = saveBarButtonItem
    }
    
    private func configureTableView() {
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag
    }
    
    private func registerCells() {
        collectionView.registerCell(CreateEditGroupDistributionNameCell.self)
        collectionView.registerCell(SelectedItemGridCell.self)
        collectionView.registerCell(CreateEditGroupDistributionListProfilePictureCell.self)
        collectionView.registerCell(ContactGridAddButtonCell.self)
        collectionView.register(
            ContactGridHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ContactGridHeaderView.reuseIdentifier
        )
    }

    private func configureSnapshot(animated: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        snapshot.appendSections([.editPicture, .editName, .editContacts])
        snapshot.appendItems([.profilePicture], toSection: .editPicture)
        snapshot.appendItems([.nameField], toSection: .editName)
        snapshot.appendItems(contacts.map { .editContact($0) }, toSection: .editContacts)
        
        if displayMode.isEdit {
            snapshot.appendItems([.addContact], toSection: .editContacts)
        }
        
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            guard let self else {
                return
            }

            let headers = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
            for header in headers {
                guard let headerView = header as? ContactGridHeaderView else {
                    continue
                }
                headerView.configure(for: displayMode.countLabelKind, with: contacts.count)
            }
        }
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
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        
        guard section == .editName else {
            return
        }
        
        guard let editNameCell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        
        editNameCell.becomeFirstResponder()
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
    
    private func updateContentInsets(to newContentInsets: UIEdgeInsets) {
        collectionView.contentInset = newContentInsets
        collectionView.scrollIndicatorInsets = newContentInsets
    }
    
    // MARK: - Actions

    private func addMembers() {
        let mode: SelectContactListDisplayMode

        switch displayMode {
        case .group(.edit):
            mode = .group(.edit(
                data: .init(
                    name: name ?? "",
                    profilePicture: profilePictureImageData,
                    contacts: contacts
                )
            ))

        case .distributionList(.edit):
            mode = .distributionList(.edit(
                data: .init(
                    name: name ?? "",
                    profilePicture: profilePictureImageData,
                    contacts: contacts
                )
            ))

        default:
            assertionFailure("addMembers called while not editing")
            return
        }

        let controller =
            SelectContactListViewController(contentSelectionMode: mode) { [
                weak self
            ] updatedSelection in
                self?.contacts = updatedSelection
                self?.configureSnapshot(animated: true)
            }
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        saveBarButtonItem.isEnabled = false
        Task {
            defer { saveBarButtonItem.isEnabled = true }
            switch displayMode {
            case let .group(action):
                switch action {
                case let .edit(group):
                    await saveEditedGroup(group)

                case .create, .clone:
                    await createGroup()
                }

            case let .distributionList(action):
                switch action {
                case let .edit(list):
                    saveEditedDistributionList(list)

                case .create:
                    await createDistributionList()
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    @objc private func contentSizeCategoryDidChange() {
        collectionView.collectionViewLayout.invalidateLayout()
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

// MARK: - Distribution list helpers

extension CreateEditGroupDistributionViewController {
    private func saveEditedDistributionList(_ list: DistributionList) {
        saveNameIfNeeded(list, newName: name)
        saveProfilePictureIfNeeded(list, newData: profilePictureImageData)
        saveMembersIfNeeded(list, newMembers: contacts)
                
        dismiss(animated: true)
    }
    
    private func createDistributionList() async {
        do {
            var conversation: ConversationEntity?
            entityManager.performAndWaitSave { [weak self] in
                conversation = self?.entityManager.entityCreator.conversationEntity()
            }

            guard let name, let conversation else {
                throw DistributionListManager.DistributionListError.creationFailure
            }

            let distributionList = distributionListManager.createDistributionList(
                conversation: conversation,
                name: name,
                imageData: profilePictureImageData,
                recipients: Set(contacts)
            )
                        
            dismiss(animated: true) { [weak self] in
                guard let self else {
                    return
                }
                
                switch onSaveDisplayMode {
                case .showDetails:
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowDistributionList),
                        object: nil,
                        userInfo: [
                            kKeyDistributionList: distributionList as Any,
                        ]
                    )
                    
                case .showChat:
                    guard let distributionListID = distributionList?.distributionListID else {
                        return
                    }
                    
                    let conversation = entityManager.entityFetcher.conversationEntity(for: distributionListID)
                    let info: [String: Any] = [
                        kKeyConversation: conversation as Any,
                        kKeyForceCompose: true,
                    ]
                    
                    NotificationCenter.default.post(
                        name: Notification.Name(kNotificationShowConversation),
                        object: nil,
                        userInfo: info
                    )
                }
            }
        }
        catch {
            DDLogError("Unable to create distribution list: \(error)")
            NotificationPresenterWrapper.shared.present(type: .createFailed)
        }
    }

    private func saveNameIfNeeded(_ list: DistributionList, newName: String?) {
        guard list.displayName != newName else {
            return
        }
        distributionListManager.setName(of: list, to: newName ?? "")
    }

    private func saveProfilePictureIfNeeded(_ list: DistributionList, newData: Data?) {
        guard list.distributionListImageData != newData else {
            return
        }
        distributionListManager.setProfilePicture(of: list, to: newData)
    }

    private func saveMembersIfNeeded(_ list: DistributionList, newMembers: [Contact]) {
        guard list.recipients != Set(newMembers) else {
            return
        }
        distributionListManager.setRecipients(of: list, to: Set(newMembers))
    }
}

// MARK: Group helpers

extension CreateEditGroupDistributionViewController {
    private func saveEditedGroup(_ group: Group) async {
        do {
            try await saveNameIfNeeded(group, newName: name)
            try await saveProfilePictureIfNeeded(group, newData: profilePictureImageData)
            try await saveMembersIfNeeded(group, newMembers: contacts)
            
            dismiss(animated: true)
        }
        catch {
            NotificationPresenterWrapper.shared.present(type: .saveError)
        }
    }

    private func createGroup() async {
        do {
            let groupID = NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.groupIDLength)) ?? Data()
            let memberIDs = Set(contacts.map(\.identity.rawValue))
            let groupIdentity = GroupIdentity(id: groupID, creator: ThreemaIdentity(myIdentity))
            let result = try await groupManager.createOrUpdate(
                for: groupIdentity,
                members: memberIDs,
                systemMessageDate: Date.now
            )
            
            try await saveNameIfNeeded(result.0, newName: name)
            try await saveProfilePictureIfNeeded(result.0, newData: profilePictureImageData)
                        
            dismiss(animated: true) { [weak self] in
                guard let self else {
                    return
                }
                
                switch onSaveDisplayMode {
                case .showDetails:
                    navigateToGroupDetails(result.0)

                case .showChat:
                    guard let conversationEntity = entityManager
                        .entityFetcher.conversationEntity(for: groupIdentity, myIdentity: myIdentity)
                    else {
                        return
                    }

                    navigateToGroupConversation(conversationEntity)
                }
            }
        }
        catch {
            DDLogError("Unable to create group: \(error)")
            NotificationPresenterWrapper.shared.present(type: .createFailed)
        }
    }

    private func navigateToGroupDetails(_ group: Group) {
        let name = NSNotification.Name(rawValue: kNotificationShowGroup)
        let userInfo: [AnyHashable: Any] = [kKeyGroup: group as Any]
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }

    private func navigateToGroupConversation(_ conversationEntity: ConversationEntity) {
        let name = Notification.Name(kNotificationShowConversation)
        let userInfo: [AnyHashable: Any] = [kKeyConversation: conversationEntity as Any, kKeyForceCompose: true]
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }

    private func saveNameIfNeeded(_ group: Group, newName: String?) async throws {
        guard group.name != newName else {
            return
        }

        do {
            try await groupManager.setName(group: group, name: newName)
        }
        catch {
            DDLogError("Unable to save group name: \(error)")
            throw error
        }
    }

    private func saveProfilePictureIfNeeded(_ group: Group, newData: Data?) async throws {
        guard group.old_ProfilePicture != newData else {
            return
        }

        do {
            if let newData {
                try await groupManager.setPhoto(group: group, imageData: newData, sentDate: Date())
            }
            else {
                try await groupManager.deletePhoto(
                    groupID: group.groupID,
                    creator: group.groupCreatorIdentity,
                    sentDate: Date()
                )
            }
        }
        catch {
            DDLogError("Unable to update/delete group photo: \(error)")
            throw error
        }
    }

    private func saveMembersIfNeeded(_ group: Group, newMembers: [Contact]) async throws {
        guard group.members != Set(newMembers) else {
            return
        }

        do {
            _ = try await groupManager.createOrUpdate(
                for: group.groupIdentity,
                members: Set(newMembers.map(\.identity.rawValue)),
                systemMessageDate: Date.now
            )
        }
        catch {
            DDLogError("Unable to update group members: \(error)")
            throw error
        }
    }
}
