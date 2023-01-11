//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import ThreemaFramework
import UIKit

/// Label with correct font and background for a system message
final class ChatViewSectionHeaderLabel: UILabel {

    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height += ChatViewConfiguration.SectionHeader.DateLabel.defaultTopBottomInset * 2
        contentSize.width += ChatViewConfiguration.SectionHeader.DateLabel.defaultLeadingTrailingInset * 2
        return contentSize
    }
    
    // TODO: (IOS-3021) Remove this workaround
    override var textColor: UIColor! {
        didSet {
            if textColor != Colors.textLight {
                textColor = Colors.textLight
            }
        }
    }
    
    // TODO: (IOS-3021) Remove this workaround
    override var backgroundColor: UIColor? {
        didSet {
            if backgroundColor != Colors.newSystemMessageBackground {
                backgroundColor = Colors.newSystemMessageBackground
            }
        }
    }

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabel()
        updateColors()
        registerObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
        updateColors()
        registerObserver()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureLabel() {
        font = ChatViewConfiguration.SectionHeader.DateLabel.font
        adjustsFontForContentSizeCategory = true
        translatesAutoresizingMaskIntoConstraints = false
        
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        textAlignment = .center
        
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(
            top: ChatViewConfiguration.SectionHeader.DateLabel.defaultTopBottomInset,
            left: ChatViewConfiguration.SectionHeader.DateLabel.defaultLeadingTrailingInset,
            bottom: ChatViewConfiguration.SectionHeader.DateLabel.defaultTopBottomInset,
            right: ChatViewConfiguration.SectionHeader.DateLabel.defaultLeadingTrailingInset
        )
        super.drawText(in: rect.inset(by: insets))
        updateCornerRadius()
    }
    
    private func registerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateColors),
            name: Notification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
    }
    
    // MARK: - Update
    
    @objc func updateColors() {
        textColor = Colors.textLight
        backgroundColor = Colors.newSystemMessageBackground
    }
    
    func updateCornerRadius() {
        layer.cornerRadius = frame.height / 2
    }
}
