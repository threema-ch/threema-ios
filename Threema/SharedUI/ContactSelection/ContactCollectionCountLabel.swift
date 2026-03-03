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

final class ContactCollectionCountLabel: UILabel {
    
    // MARK: - Kind
    
    enum Kind {
        case group
        case distributionList
        case profilePicture
        case none
    }
    
    // MARK: - Constants

    private enum Constants {
        static let maxGroupMembers = Group.maxGroupMembers
    }

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        font = .preferredFont(forTextStyle: .headline)
        textColor = .secondaryLabel
        adjustsFontForContentSizeCategory = true
        numberOfLines = 1
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    func configure(for kind: Kind, count: Int) {
        let format: String =
            switch kind {
            case .group:
                #localize("invite_group_count")
            case .distributionList:
                #localize("invite_distribution_list_count")
            case .profilePicture:
                #localize("send_profileimage_contacts")
            case .none:
                ""
            }
        
        text = String(format: format, "\(count)", "\(Constants.maxGroupMembers)")
    }
}
