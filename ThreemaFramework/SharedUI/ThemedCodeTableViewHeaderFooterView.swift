//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import UIKit

/// Base class for `UITableViewHeaderFooterView` that are implemented in code
open class ThemedCodeTableViewHeaderFooterView: UITableViewHeaderFooterView {
    
    // Normally you don't need to override `init`. Just do you configuration in `configureView()`.
    override public init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        configureView()
        updateColors()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Called during initialization
    open func configureView() {
        // no-op
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        updateColors()
    }
    
    /// Called whenever the colors of the views should be set to the current theme colors
    open func updateColors() {
        // no-op
    }
}
