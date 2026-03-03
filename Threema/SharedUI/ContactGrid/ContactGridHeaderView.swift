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

import ThreemaMacros

final class ContactGridHeaderView: UICollectionReusableView {
    
    // MARK: - Constants

    private enum Constants {
        static let horizontalInset: CGFloat = 0
        static let verticalInset: CGFloat = 8
    }
    
    // MARK: - Subviews

    private lazy var countLabel = ContactCollectionCountLabel()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(countLabel)
        backgroundColor = .clear
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalInset),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalInset),
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: Constants.verticalInset),
            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.verticalInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(for kind: ContactCollectionCountLabel.Kind, with count: Int) {
        countLabel.configure(for: kind, count: count)
    }
}

// MARK: - Reusable

extension ContactGridHeaderView: Reusable { }
