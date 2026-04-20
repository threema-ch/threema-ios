import CocoaLumberjackSwift
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

final class EditProfileViewController: UITableViewController {
    
    // MARK: - Private properties
        
    private lazy var dataSource = TableViewDiffableSimpleHeaderAndFooterDataSource<
        EditProfileSection,
        EditProfileSection.Row
    >(tableView: tableView) {
        [weak self] tableView, indexPath, row -> UITableViewCell? in
        
        switch row {
        case .nameField:
            let editNameCell: EditNameTableViewCell = tableView.dequeueCell(for: indexPath)
            
            guard let self else {
                return editNameCell
            }
            
            editNameCell.nameType = .nickname
            editNameCell.name = name
            editNameCell.delegate = self
            editNameCell.isUserInteractionEnabled = !isProfileReadOnly
            return editNameCell
            
        case let .releasePicture(kind):
            let releasePicture: ReleasePictureCell = tableView.dequeueCell(for: indexPath)
            
            guard let self else {
                return releasePicture
            }
            
            releasePicture.configure(
                secondaryText: kind.localizedText,
                isEnabled: canSendProfilePicture
            )
            return releasePicture
        }
    
    } headerProvider: { [weak self] _, section -> String? in
        guard let self else {
            return nil
        }
        
        switch section {
        case .editName:
            return #localize("nickname")
        
        case .editPictureReceivers:
            return #localize("edit_profile_picture_header_title")
        }
        
    } footerProvider: { [weak self] _, section -> String? in
        guard let self else {
            return nil
        }
        
        switch section {
        case .editName:
            var footer = #localize("edit_profile_footer")
            if isProfileReadOnly {
                footer += "\n\n" + #localize("disabled_by_device_policy")
            }
            return footer
        
        case .editPictureReceivers:
            if isProfileReadOnly || !canSendProfilePicture {
                return #localize("disabled_by_device_policy")
            }
            else {
                return #localize("edit_profile_picture_footer_text")
            }
        }
    }
    
    private lazy var mdmSetup = MDMSetup()
    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var profileStore = BusinessInjector.ui.profileStore
    private lazy var settingsStore = BusinessInjector.ui.settingsStore
    private lazy var myIdentityStore = BusinessInjector.ui.myIdentityStore
    private var name: String?
    private var profilePictureImageData: Data?
    private var isProfileReadOnly: Bool {
        (mdmSetup?.readonlyProfile() ?? false)
    }

    private var canSendProfilePicture: Bool {
        !isProfileReadOnly && !(mdmSetup?.disableSendProfilePicture() ?? true)
    }

    var sendProfilePicture: SendProfilePicture {
        profileStore.profile.sendProfilePicture
    }

    var profilePictureContactList: [String] {
        profileStore.profile.profilePictureContactList
    }
    
    // MARK: Subview
    
    private lazy var cancelBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancelButtonTapped)
    )
    
    private lazy var saveBarButtonItem = UIBarButtonItem.saveButton(target: self, selector: #selector(saveButtonTapped))
    
    private lazy var editProfilePictureView: EditProfilePictureView = {
        let imageUpdated: EditProfilePictureView.ImageUpdated = { [weak self] newImageData -> (UIImage?, Bool) in
            guard let self else {
                return (nil, true)
            }
                
            // Store new image data
            profilePictureImageData = newImageData
                
            // Return default profile picture
            guard let newImageData,
                  let newProfilePicture = UIImage(data: newImageData) else {
                
                let newProfilePicture = ProfilePictureGenerator.generateImage(for: .me, color: myIdentityStore.idColor)
                return (newProfilePicture, true)
            }
                
            // Return new group profile
            return (newProfilePicture, false)
        }
            
        return EditProfilePictureView(
            in: self,
            profilePicture: myIdentityStore.resolvedProfilePicture,
            isDefaultImage: myIdentityStore.isDefaultProfilePicture,
            isEditable: !isProfileReadOnly,
            conversationType: .contact,
            imageUpdated: imageUpdated
        )
    }()
    
    // MARK: - Lifecycle
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        preFillData()
        
        configureController()
        configureNavigationBar()
        configureTableView()
        registerCells()
        configureSnapshot()
        addObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.post(name: .profileUIRefresh, object: nil)
        super.viewWillDisappear(animated)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeaderIfNeeded()
    }
    
    // MARK: - Configuration
    
    private func updateHeaderIfNeeded() {
        editProfilePictureView.setNeedsLayout()
        editProfilePictureView.layoutIfNeeded()
        
        let fittingSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let targetHeight = editProfilePictureView.systemLayoutSizeFitting(fittingSize).height

        if tableView.tableHeaderView?.frame.height != targetHeight {
            editProfilePictureView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: targetHeight)
            tableView.tableHeaderView = editProfilePictureView
        }
    }
    
    private func preFillData() {
        profilePictureImageData = profileStore.profile.profileImage
        name = profileStore.profile.nickname
    }
    
    private func configureController() {
        isModalInPresentation = true
    }
    
    private func configureNavigationBar() {
        navigationItem.title = #localize("edit_profile_title")
        
        saveBarButtonItem.style = .done
        navigationItem.rightBarButtonItem = saveBarButtonItem
        navigationItem.leftBarButtonItem = cancelBarButtonItem
    }
    
    private func configureTableView() {
        tableView.dataSource = dataSource
        tableView.delegate = self
    }
    
    private func registerCells() {
        tableView.registerCell(EditNameTableViewCell.self)
        tableView.registerCell(ReleasePictureCell.self)
    }

    private func configureSnapshot(animated: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<EditProfileSection, EditProfileSection.Row>()
        
        snapshot.appendSections([.editName, .editPictureReceivers])
        snapshot.appendItems([.nameField], toSection: .editName)
        snapshot.appendItems([.releasePicture(kind: sendProfilePicture)], toSection: .editPictureReceivers)
        
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    private func addObservers() {
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
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        
        switch section {
            
        case .editName:
            guard let editNameCell = tableView.cellForRow(at: indexPath) else {
                return
            }
            editNameCell.becomeFirstResponder()
            
        case .editPictureReceivers:
            let controller = EditProfilePictureRecipientsViewController(
                sendKind: sendProfilePicture,
                contacts: profilePictureContactList
            ) { [weak self] in
                self?.configureSnapshot()
            }
            present(UINavigationController(rootViewController: controller), animated: true)
        }
    }
    
    // MARK: - Updates

    private func updateContentInsets(to newContentInsets: UIEdgeInsets) {
        tableView.contentInset = newContentInsets
        tableView.scrollIndicatorInsets = newContentInsets
    }
    
    // MARK: - Actions

    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        Task { @MainActor in
            var profile = profileStore.profile
            profile.nickname = name
            profile.profileImage = profilePictureImageData
            
            if settingsStore.isMultiDeviceRegistered {
                let progressString = #localize("syncing_profile")
                let syncHelper = UISyncHelper(viewController: self, progressString: progressString)
                syncHelper.execute(profile: profile)
                    .done {
                        self.dismiss(animated: true)
                    }
                    .catch { _ in
                        self.dismiss(animated: true)
                    }
            }
            else {
                profileStore.save(profile)
                dismiss(animated: true)
            }
        }
    }
    
    // MARK: - Notifications
    
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

// MARK: - EditNameTableViewCellDelegate

extension EditProfileViewController: EditNameTableViewCellDelegate {
    func editNameTableViewCell(_ editNameTableViewCell: EditNameTableViewCell, didChangeTextTo newText: String?) {
        name = newText
    }
}
