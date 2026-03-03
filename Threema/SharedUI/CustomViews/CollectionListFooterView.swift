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

final class CollectionListFooterView: UICollectionReusableView {
    
    // MARK: - Constants

    private enum Constants {
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 8
    }
    
    // MARK: - Subviews

    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        return label
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(label)
        backgroundColor = .clear
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalInset),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalInset),
            label.topAnchor.constraint(equalTo: topAnchor, constant: Constants.verticalInset),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.verticalInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func setText(_ text: String) {
        label.text = text
    }
}

// MARK: - Reusable

extension CollectionListFooterView: Reusable { }
