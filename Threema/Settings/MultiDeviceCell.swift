//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import SnapKit

class MultiDeviceCell: ThemedCodeStackTableViewCell {
    
    // MARK: - Public property
    
    var deviceInfo: DeviceInfo? {
        didSet {
            guard let deviceInfo else {
                return
            }

            switch deviceInfo.platform {
            case .ios, .android:
                platformIcon.image = UIImage(systemName: "iphone")
            case .desktop, .web, .unspecified:
                platformIcon.image = UIImage(systemName: "desktopcomputer")
            }

            deviceInfoLabel.text = deviceInfo.label
            badgeLabel.text = deviceInfo.badge

            // Badge label with padding
            if deviceInfo.badge?.count ?? 0 > 0 {
                badgeView.backgroundColor = .lightGray
                badgeView.layer.masksToBounds = true
                badgeView.layer.cornerRadius = 4.0

                let padding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
                badgeLabel.snp.makeConstraints { make in
                    make.edges.equalTo(self.badgeView).inset(padding)
                }
                badgeView.isHidden = false
            }
            else {
                badgeView.isHidden = true
            }

            platformDetailsLabel.text = deviceInfo.platformDetails
            lastLoginAtLabel.text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "multi_device_linked_devices_last_login"),
                DateFormatter.relativeLongStyleDateShortStyleTime(deviceInfo.lastLoginAt)
            )
        }
    }
    
    // MARK: - Private properties
    
    // MARK: Subviews
    
    lazy var platformIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        imageView.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 40.0).isActive = true

        return imageView
    }()
    
    lazy var platformStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [deviceInfoStack, detailsStack])
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var deviceInfoStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [deviceInfoLabel, badgeView])
        
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var detailsStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [platformDetailsLabel, lastLoginAtLabel])
        
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var platformDetailsLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var lastLoginAtLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
               
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var deviceInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body).bold()
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var badgeView: UIView = {
        let view = UIView()
        view.addSubview(badgeLabel)
        return view
    }()
    
    private lazy var badgeLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .caption1).bold()
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func configureCell() {
        super.configureCell()
               
        contentStack.distribution = .fill
        contentStack.spacing = 16
        contentStack.addArrangedSubview(platformIcon)
        contentStack.addArrangedSubview(platformStack)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        Colors.setTextColor(Colors.textLight, label: platformDetailsLabel)
        Colors.setTextColor(Colors.textLight, label: lastLoginAtLabel)
    }
}

// MARK: - Reusable

extension MultiDeviceCell: Reusable { }
