//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

// MARK: - ChatBarButton.Configuration

extension ChatBarButton {
    struct Configuration {
        var size: CGFloat = ChatViewConfiguration.ChatBarButton.defaultSize
        var scaledSize: CGFloat {
            UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        }
    }
}

class ChatBarButton: ThemedCodeButton {
    
    private lazy var buttonConfiguration = Configuration()
    
    private var defaultColor: () -> UIColor
    
    private var sfSymbolName: String?
    
    init(
        sfSymbolName: String,
        accessibilityLabel: String,
        defaultColor: @escaping (() -> UIColor) = { .primary },
        customScalableSize: CGFloat? = nil,
        action: @escaping Action
    ) {
        
        self.defaultColor = defaultColor
        
        // Setting the actual frame size fixes an Auto Layout error that probably occurs when
        // there is no superview
        let initFrame = CGRect(
            x: 0, y: 0,
            width: 44,
            height: 44
        )
        
        super.init(frame: initFrame, action: action)
        
        if let customScalableSize {
            buttonConfiguration.size = customScalableSize
        }
        
        configureButton(with: sfSymbolName)
        updateColors()
        
        self.accessibilityLabel = accessibilityLabel
    }
    
    // MARK: - Configure
    
    public func updateButton(with sfSymbolName: String) {
        configureButton(with: sfSymbolName)
    }
    
    private func configureButton(
        with sfSymbolName: String
    ) {
        guard self.sfSymbolName != sfSymbolName else {
            return
        }
        
        // Content
        self.sfSymbolName = sfSymbolName
        let image = UIImage(systemName: sfSymbolName)?.withRenderingMode(.alwaysTemplate)
        setImage(image, for: .normal)
        
        setPreferredSymbolConfiguration(
            UIImage
                .SymbolConfiguration(pointSize: buttonConfiguration.scaledSize, weight: .regular, scale: .large),
            forImageIn: .normal
        )
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        imageView?.tintColor = defaultColor()
    }
}
