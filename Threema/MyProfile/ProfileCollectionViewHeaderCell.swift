//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import ThreemaMacros

class ProfileCollectionViewHeaderCell: UICollectionViewListCell, Reusable {
    
    // MARK: - Properties
    
    weak var coordinator: ProfileCoordinator?
    
    private lazy var identityStore = BusinessInjector.ui.myIdentityStore
   
    private lazy var quickActions: [QuickAction] =
        if TargetManager.isOnPrem {
            [qrAction]
        }
        else {
            [shareAction, qrAction]
        }
    
    private lazy var qrAction = QuickAction(
        imageName: "qrcode",
        title: #localize("profile_show_qr_code"),
        accessibilityIdentifier: "qr_code"
    ) { [weak self] _ in
        guard let self, let coordinator else {
            return
        }
        
        coordinator.show(.qrCode)
    }
    
    private lazy var shareAction = QuickAction(
        imageName: "square.and.arrow.up.fill",
        title: String.localizedStringWithFormat(
            #localize("profile_share_id"),
            TargetManager.localizedAppName
        ),
        accessibilityIdentifier: "share_id_button"
    ) { [weak self] action in
        guard let self, let coordinator else {
            return
        }
        
        coordinator.show(.shareID(sourceView: action.popOverSourceView() ?? quickActionsView))
    }

    // MARK: - Subviews
    
    private lazy var profilePictureView: ProfilePictureImageView = {
        let profilePictureView = ProfilePictureImageView()
        profilePictureView.info = .me
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        return profilePictureView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .title1).bold()
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .title3)
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var quickActionsView: QuickActionsView = {
        let view = QuickActionsView(quickActions: quickActions)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
  
    private lazy var noIDLabelConsraint: [NSLayoutConstraint] = [
        quickActionsView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 20),
        quickActionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        quickActionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        quickActionsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ]
    
    private lazy var idLabelConsraints: [NSLayoutConstraint] = [
        idLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor),
        idLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor),
        idLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
        idLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        
        quickActionsView.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 20),
        quickActionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        quickActionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        quickActionsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ]
    
    private lazy var nameTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer()
        gestureRecognizer.addTarget(self, action: #selector(copyID))
        return gestureRecognizer
    }()
    
    private lazy var idTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer()
        gestureRecognizer.addTarget(self, action: #selector(copyID))
        return gestureRecognizer
    }()

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    private func configure() {
        idLabel.addGestureRecognizer(nameTapGestureRecognizer)
        nameLabel.addGestureRecognizer(idTapGestureRecognizer)
        
        contentView.addSubview(profilePictureView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(quickActionsView)
        
        NSLayoutConstraint.activate([
            profilePictureView.topAnchor.constraint(equalTo: contentView.topAnchor),
            profilePictureView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            profilePictureView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            profilePictureView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: profilePictureView.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        checkIDLabel()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private functions
    
    private func checkIDLabel() {
        if let nickname = identityStore.pushFromName, !nickname.isEmpty {
            contentView.addSubview(idLabel)
            nameLabel.text = nickname
            idLabel.text = identityStore.identity
            NSLayoutConstraint.deactivate(noIDLabelConsraint)
            NSLayoutConstraint.activate(idLabelConsraints)
        }
        else {
            idLabel.removeFromSuperview()
            nameLabel.text = identityStore.identity
            idLabel.text = nil
            NSLayoutConstraint.deactivate(idLabelConsraints)
            NSLayoutConstraint.activate(noIDLabelConsraint)
        }
        
        layoutIfNeeded()
    }
    
    @objc private func copyID() {
        UIPasteboard.general.string = identityStore.identity
        NotificationPresenterWrapper.shared.present(type: .copyIDSuccess)
    }
}
