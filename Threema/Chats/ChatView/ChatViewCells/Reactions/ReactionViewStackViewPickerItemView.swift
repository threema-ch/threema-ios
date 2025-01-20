//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

class ReactionViewStackViewPickerItemView: UIView, ReactionViewStackViewItemViewSubView {
        
    // MARK: - Subviews
        
    private lazy var imageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(font: UIFont.preferredFont(forTextStyle: .body))
        
        let image = UIImage(resource: .threemaCustomFaceSmilingBadgePlus)
         
        let imageView = UIImageView(image: image)
        imageView.preferredSymbolConfiguration = config
        imageView.tintColor = Colors.chatReactionBubbleTextColor
        imageView.contentMode = .scaleAspectFit
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private lazy var imageViewConstraints: [NSLayoutConstraint] = [
        imageView.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor),
        imageView.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
        imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
    ]
    
    // MARK: - Lifecycle
    
    init() {
        super.init(frame: .zero)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateView(type: ReactionViewStackViewItemView.ViewType) {
        // No-op
    }
    
    func updateColors() {
        imageView.tintColor = Colors.chatReactionBubbleTextColor
    }
    
    private func configureView() {
        isUserInteractionEnabled = false

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate(imageViewConstraints)
    }
}
