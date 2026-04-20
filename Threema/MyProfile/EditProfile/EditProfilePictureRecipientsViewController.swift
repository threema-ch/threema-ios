import CocoaLumberjackSwift
import ThreemaEssentials
import ThreemaMacros
import UIKit

final class EditProfilePictureRecipientsViewController: UICollectionViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        static var contactsPerRow: Int {
            AppDelegate.shared().isCompactSizeClass ? 5 : 7
        }

        static let sectionInset = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20)
        static let contactsInterGroupSpacing: CGFloat = 16
        static let contactsInterItemSpacing: CGFloat = 16
    }
    
    // MARK: - Types
    
    private enum Section: Int, Hashable {
        case actions
        case recipients
    }
    
    private enum Row: Hashable {
        case action(kind: SendProfilePicture, selected: Bool)
        case recipient(_ contact: Contact)
        case addContact
    }
    
    // MARK: - Private properties
        
    private lazy var contactProvider = ContactListProvider()
    
    private lazy var dataSource = CollectionViewDiffableSimpleHeaderAndFooterDataSource<
        Section,
        Row
    >(collectionView: self.collectionView) {
        [weak self] collectionView,
            indexPath,
            row -> UICollectionViewCell? in
        
        switch row {
        case let .action(kind, selected):
            let kindCell: ReleasePictureKindCell = collectionView.dequeueCell(for: indexPath)
            
            guard let self else {
                return kindCell
            }
            
            kindCell.configure(with: kind.localizedText, isChecked: selected)
            return kindCell
            
        case let .recipient(contact):
            let editContactCell: SelectedItemGridCell = collectionView.dequeueCell(for: indexPath)
            let item = SelectableItem(id: contact.objectID, item: .contact(contact), isSelected: false)
            editContactCell.configure(for: item)
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
                
                addRecipients()
            }
            return addContactCell
        }
    } headerProvider: { collectionView, section, indexPath in
        guard section == .recipients else {
            fatalError()
        }

        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ContactGridHeaderView.reuseIdentifier,
            for: indexPath
        )
        
        if let gridHeader = header as? ContactGridHeaderView {
            gridHeader.configure(for: .profilePicture, with: 0)
        }

        return header
    } footerProvider: { collectionView, section, indexPath in
        guard section == .actions else {
            fatalError()
        }
        
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: CollectionListFooterView.reuseIdentifier,
            for: indexPath
        )
        
        if let listFooter = footer as? CollectionListFooterView {
            let text: String =
                if self.sendKind.rawValue == 1 {
                    #localize("profileimage_setting_all_footer")
                }
                else if self.sendKind.rawValue == 2 {
                    #localize("profileimage_setting_contacts_footer")
                }
                else {
                    ""
                }
            listFooter.setText(text)
        }

        return footer
    }
    
    private let profileStore = BusinessInjector.ui.profileStore
    private let settingsStore = BusinessInjector.ui.settingsStore
    private var sendKind: SendProfilePicture
    private var contacts: [Contact]
    private var onDismiss: (() -> Void)?
    
    // MARK: Subview
    
    private lazy var cancelBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancelButtonTapped)
    )
    
    private lazy var saveBarButtonItem = UIBarButtonItem.saveButton(target: self, selector: #selector(saveButtonTapped))
    
    // MARK: - Sections
    
    private static var recipientsSection: NSCollectionLayoutSection {
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
    
    init(sendKind: SendProfilePicture, contacts: [String], onDismiss: (() -> Void)?) {
        self.onDismiss = onDismiss
        self.sendKind = sendKind
        self.contacts = contacts
            .map { BusinessInjector.ui.entityManager.entityFetcher.contactEntity(for: $0) }
            .compactMap { $0.map { Contact(contactEntity: $0) } }

        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            guard let section = Section(rawValue: sectionIndex) else {
                fatalError("Unknown section index \(sectionIndex). Make sure to update the `Section` accordingly.")
            }

            switch section {
            case .actions:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.showsSeparators = true
                config.backgroundColor = .clear
                config.footerMode = .supplementary
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
                
                let footerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(20)
                )
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: footerSize,
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottomLeading
                )
                section.boundarySupplementaryItems = [footer]
                
                return section

            case .recipients:
                return Self.recipientsSection
            }
        }
        
        super.init(collectionViewLayout: layout)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
        configureNavigationBar()
        configureCollectionView()
        registerCells()
        configureSnapshot()
        addObservers()
    }
    
    // MARK: - Configuration
    
    private func configureController() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = false
        isModalInPresentation = true
    }
    
    private func configureNavigationBar() {
        saveBarButtonItem.style = .done
        navigationItem.title = #localize("edit_profile_picture_title")
        navigationItem.rightBarButtonItem = saveBarButtonItem
        navigationItem.leftBarButtonItem = cancelBarButtonItem
    }
    
    private func configureCollectionView() {
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag
    }
    
    private func registerCells() {
        collectionView.registerCell(ReleasePictureKindCell.self)
        collectionView.registerCell(SelectedItemGridCell.self)
        collectionView.registerCell(ContactGridAddButtonCell.self)
        collectionView.register(
            ContactGridHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ContactGridHeaderView.reuseIdentifier
        )
        collectionView.register(
            CollectionListFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: CollectionListFooterView.reuseIdentifier
        )
    }

    private func configureSnapshot(animated: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        let actions: [Row] = [
            .action(kind: SendProfilePictureNone, selected: sendKind == SendProfilePictureNone),
            .action(kind: SendProfilePictureAll, selected: sendKind == SendProfilePictureAll),
            .action(kind: SendProfilePictureContacts, selected: sendKind == SendProfilePictureContacts),
        ]
        
        snapshot.appendSections([.actions])
        snapshot.appendItems(actions, toSection: .actions)
        snapshot.reloadSections([.actions])
        
        if sendKind == SendProfilePictureContacts {
            snapshot.appendSections([.recipients])
            snapshot.appendItems(contacts.map { .recipient($0) }, toSection: .recipients)
            snapshot.appendItems([.addContact], toSection: .recipients)
        }
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
    
    private func dismiss() {
        dismiss(animated: true) {
            self.onDismiss?()
        }
    }
    
    // MARK: - Updates
    
    private func updateContentInsets(to newContentInsets: UIEdgeInsets) {
        collectionView.contentInset = newContentInsets
        collectionView.scrollIndicatorInsets = newContentInsets
    }
    
    // MARK: - Collection view
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        switch item {
        case let .action(kind, _):
            sendKind = kind
            configureSnapshot()
        default:
            break
        }
    }
    
    // MARK: - Actions

    private func addRecipients() {
        let controller =
            SelectContactListViewController(contentSelectionMode: .contact(data: contacts)) { [
                weak self
            ] updatedSelection in
                self?.contacts = updatedSelection
                self?.configureSnapshot(animated: true)
            }
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    @objc private func cancelButtonTapped() {
        dismiss()
    }
    
    @objc private func saveButtonTapped() {
        Task { @MainActor in
            var profile = profileStore.profile
            profile.sendProfilePicture = sendKind
            profile.profilePictureContactList = contacts.map(\.identity.rawValue)
            
            if settingsStore.isMultiDeviceRegistered {
                let progressString = #localize("syncing_profile")
                let syncHelper = UISyncHelper(viewController: self, progressString: progressString)
                syncHelper.execute(profile: profile)
                    .done {
                        self.dismiss()
                    }
                    .catch { _ in
                        self.dismiss()
                    }
            }
            else {
                profileStore.save(profile)
                dismiss()
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
