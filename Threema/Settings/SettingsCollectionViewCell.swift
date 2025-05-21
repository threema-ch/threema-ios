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

class SettingsCollectionViewCell: UICollectionViewListCell, Reusable {
    
    // MARK: - Properties
    
    var rowType: SettingsCollectionViewDataSource.Row? {
        didSet {
            updateContent()
        }
    }
    
    private let imageConfig = UIImage.SymbolConfiguration(textStyle: .body, scale: .small)

    // MARK: - Subviews
    
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [imageContainerView, textLabel])
        
        stackView.axis = .horizontal
        stackView.alignment = .leading
        stackView.spacing = 16
        
        return stackView
    }()
    
    private lazy var imageContainerView: UIView = {
        let view = UIView()
        
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5
        view.backgroundColor = .gray
        
        view.addSubview(imageView)
       
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: UIFontMetrics(forTextStyle: .body).scaledValue(for: 28)),
            view.heightAnchor.constraint(equalTo: view.widthAnchor),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            view.isHidden = true
        }
        
        return view
    }()
    
    private lazy var imageView: UIImageView = {
        let image = UIImage(systemName: "popcorn.fill")?.withConfiguration(imageConfig)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    private func configure() {
        accessories = [.disclosureIndicator()]
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerStack)
       
        NSLayoutConstraint.activate([
            imageContainerView.centerYAnchor.constraint(equalTo: textLabel.centerYAnchor),
            containerStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            separatorLayoutGuide.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateContent() {
        textLabel.text = rowType?.title
        imageView.image = rowType?.icon?.withConfiguration(imageConfig)
    }
}
