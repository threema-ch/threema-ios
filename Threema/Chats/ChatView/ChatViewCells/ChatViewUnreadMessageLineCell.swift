//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

/// Implements the unread message line for the new chat view
/// Name is prefixed by new to avoid name conflicts with the previous implementation
final class ChatViewUnreadMessageLineCell: ThemedCodeTableViewCell {
    private typealias Config = ChatViewConfiguration.UnreadMessageLine
    
    // MARK: - Internal Properties
    
    /// Delegate used to handle cell delegates
    weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegateProtocol?
    
    var text: String? {
        didSet {
            textBox.text = text
        }
    }
    
    // MARK: - Private Properties
    
    private let debugColors = false
    
    private lazy var textBox: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.textColor = .primary
        label.font = Config.font
        
        label.numberOfLines = 0
        label.textAlignment = .center
        
        label.textColor = .primary
        label.adjustsFontForContentSizeCategory = true
        
        label.setContentHuggingPriority(.required, for: .horizontal)
        
        return label
    }()
    
    /// Pill Shape containing the text; Only visible if delegate returns `true` for `chatViewHasCustomBackground` or `debugColors` is activated
    private lazy var textRound: UIView = {
        let roundView = UIView()
        roundView.translatesAutoresizingMaskIntoConstraints = false
        roundView.layer.cornerRadius = Config.pillRadius
        
        if let chatViewTableViewCellDelegate = chatViewTableViewCellDelegate,
           chatViewTableViewCellDelegate.chatViewHasCustomBackground || debugColors {
            let blurEffect = UIBlurEffect(style: Config.pillBlurEffectStyle)
            
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            
            blurEffectView.translatesAutoresizingMaskIntoConstraints = false
            blurEffectView.layer.cornerRadius = Config.pillRadius
            blurEffectView.layer.cornerCurve = .continuous
            blurEffectView.layer.masksToBounds = true
            
            roundView.addSubview(blurEffectView)

            NSLayoutConstraint.activate([
                roundView.topAnchor.constraint(equalTo: blurEffectView.topAnchor),
                roundView.leadingAnchor.constraint(equalTo: blurEffectView.leadingAnchor),
                roundView.bottomAnchor.constraint(equalTo: blurEffectView.bottomAnchor),
                roundView.trailingAnchor.constraint(equalTo: blurEffectView.trailingAnchor),
            ])
        }
        
        roundView.addSubview(textBox)
        NSLayoutConstraint.activate([
            roundView.topAnchor.constraint(equalTo: textBox.topAnchor, constant: -Config.pillTopBottomTextInset),
            roundView.leadingAnchor.constraint(
                equalTo: textBox.leadingAnchor,
                constant: -Config.pillLeftRightTextInset
            ),
            roundView.bottomAnchor.constraint(equalTo: textBox.bottomAnchor, constant: Config.pillTopBottomTextInset),
            roundView.trailingAnchor.constraint(
                equalTo: textBox.trailingAnchor,
                constant: Config.pillLeftRightTextInset
            ),
        ])
        
        return roundView
    }()
    
    private lazy var leftLineView = NewUnreadMessageLineLineView(side: .left)
    private lazy var rightLineView = NewUnreadMessageLineLineView(side: .right)
    
    // MARK: - Configuration
    
    func configureCell(with text: String?) {
        super.configureCell()
        
        if UserSettings.shared().flippedTableView {
            transform = CGAffineTransform(scaleX: 1, y: -1)
        }

        isUserInteractionEnabled = false
        
        if let text = text {
            self.text = text
        }
        
        configureLayout()
        updateColors()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeChanged(_:)),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    private func configureLayout() {
        
        defaultMinimalHeightConstraint.constant = Config.minimalCellHeight
        
        contentView.addSubview(leftLineView)
        contentView.addSubview(rightLineView)
        contentView.addSubview(textRound)
        
        NSLayoutConstraint.activate([
            leftLineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            /// Inset by one into the blur view shown on custom backgrounds
            textRound.leadingAnchor.constraint(equalTo: leftLineView.trailingAnchor, constant: -1),
            /// Inset by one into the blur view shown on custom backgrounds
            rightLineView.leadingAnchor.constraint(equalTo: textRound.trailingAnchor, constant: -1),
            
            leftLineView.centerYAnchor.constraint(equalTo: textRound.centerYAnchor),
            rightLineView.centerYAnchor.constraint(equalTo: textRound.centerYAnchor),
            
            leftLineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rightLineView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            /// Constraint left and right line width to the configured screen width multiplier
            leftLineView.widthAnchor.constraint(
                greaterThanOrEqualTo: contentView.widthAnchor,
                multiplier: Config.leftRightLineMaxScreenwidthRatio
            ),
            rightLineView.widthAnchor.constraint(
                greaterThanOrEqualTo: contentView.widthAnchor,
                multiplier: Config.leftRightLineMaxScreenwidthRatio
            ),
            leftLineView.widthAnchor.constraint(equalTo: rightLineView.widthAnchor),
            
            textRound.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    // - MARK: Update Functions
    
    override func updateColors() {
        backgroundColor = .clear
        textBox.textColor = .primary
        leftLineView.updateColors()
        rightLineView.updateColors()
    }
    
    @objc func preferredContentSizeChanged(_ notification: Notification) {
        textBox.font = Config.font
    }
}

// MARK: - Reusable

extension ChatViewUnreadMessageLineCell: Reusable { }
