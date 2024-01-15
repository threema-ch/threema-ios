//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

class CompanyDirectoryCellView: UIStackView {
    
    private lazy var configuration = CellConfiguration(size: .small)
    private lazy var companyAvatarView: UIImageView = {
        let view = UIImageView()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: configuration.maxAvatarSize).isActive = true
        return view
    }()
    
    private lazy var chevronView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.image = UIImage(systemName: "chevron.forward")
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return view
    }()
    
    private lazy var companyNameLabel: UILabel = {
        let label = UILabel()
        label.text = MyIdentityStore.shared().companyName
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.numberOfLines = 2
        label.lineBreakStrategy = []
        return label
    }()
    
    private lazy var companyDirectoryDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = BundleUtil.localizedString(forKey: "companydirectory_description")
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 2
        label.lineBreakStrategy = []
        return label
    }()
    
    private lazy var labelStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [companyNameLabel, companyDirectoryDescriptionLabel])
        stackView.axis = .vertical
        stackView.spacing = configuration.verticalSpacing
        return stackView
    }()
    
    init() {
        super.init(frame: .zero)
        
        axis = .horizontal
        spacing = configuration.horizontalSpacing
        alignment = .center
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addArrangedSubview(companyAvatarView)
        addArrangedSubview(labelStackView)
        addArrangedSubview(chevronView)

        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: configuration.verticalSpacing,
            leading: configuration.horizontalSpacing,
            bottom: configuration.verticalSpacing,
            trailing: configuration.horizontalSpacing
        )
        isLayoutMarginsRelativeArrangement = true
        
        configureView()
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureView() {
        companyAvatarView.image = AvatarMaker.shared().companyImage()
        companyNameLabel.text = MyIdentityStore.shared().companyName
        companyDirectoryDescriptionLabel.text = BundleUtil.localizedString(forKey: "companydirectory_description")
        layoutIfNeeded()
        
        updateColors()
    }
    
    @objc public func updateColors() {
        companyNameLabel.textColor = Colors.text
        companyDirectoryDescriptionLabel.textColor = Colors.textLight
        companyAvatarView.image = AvatarMaker.shared().companyImage()
        tintColor = .primary
    }
    
    @objc public func refresh() {
        configureView()
    }
}
