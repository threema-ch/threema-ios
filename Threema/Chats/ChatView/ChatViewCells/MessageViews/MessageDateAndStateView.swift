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

import UIKit

/// Show appropriate date/time and status symbol if any for provided message
///
/// If the content size category changes you need to recreate this view. The spacing won't adapt to the new category.
final class MessageDateAndStateView: UIView {
    
    /// Message to show date and state for
    ///
    /// Reset to update with current message information.
    var message: BaseMessage? {
        didSet {
            guard let message = message else {
                return
            }
                    
            updateDate(for: message)
            updateState(to: message.messageDisplayState)
        }
    }
    
    // MARK: - Private properties
    
    private lazy var constantScaler = UIFontMetrics(forTextStyle: ChatViewConfiguration.MessageMetadata.textStyle)
    
    /// Offset of date label from trailing end
    private lazy var dateLabelTrailingInset: CGFloat = {
        // The date label is as far away from the symbol center as its center is form the trailing end plus the space
        let offset = 2 * statusSymbolXCenterTrailingDistance // This is already scaled
        let scaledSpace = constantScaler.scaledValue(
            for: ChatViewConfiguration.MessageMetadata.defaultLabelAndSymbolSpace
        )
        
        return offset + scaledSpace
    }()
    
    /// Distance of symbol center from trailing end
    private lazy var statusSymbolXCenterTrailingDistance: CGFloat = {
        // Adapt for content size categories
        constantScaler.scaledValue(for: ChatViewConfiguration.MessageMetadata.defaultSymbolCenterInset)
    }()
    
    // MARK: Views & constraints
    
    private lazy var dateLabel = MessageMetadataTextLabel()
    
    private lazy var dateLabelInsetConstraint = dateLabel.trailingAnchor.constraint(
        equalTo: trailingAnchor,
        constant: -dateLabelTrailingInset
    )
    
    private lazy var statusSymbolImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        
        return imageView
    }()
    
    private lazy var statusSymbolImageViewConstraints: [NSLayoutConstraint] = [
        statusSymbolImageView.firstBaselineAnchor.constraint(equalTo: dateLabel.firstBaselineAnchor),
        statusSymbolImageView.centerXAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -statusSymbolXCenterTrailingDistance
        ),
    ]

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        updateColors()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
        updateColors()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureLayout() {
        addSubview(dateLabel)
        addSubview(statusSymbolImageView)
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        statusSymbolImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: topAnchor),
            dateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            dateLabelInsetConstraint,
        ])
        NSLayoutConstraint.activate(statusSymbolImageViewConstraints)
    }
    
    // MARK: - Updates
    
    func updateColors() {
        Colors.setTextColor(Colors.textLight, label: dateLabel)
        
        if let message = message {
            updateState(to: message.messageDisplayState)
        }
    }
    
    // MARK: Date label
    
    private func updateDate(for message: BaseMessage) {
        // Show date and time if the `displayDate` is on another day than the date used for sectioning
        if !Calendar.current.isDate(message.displayDate, inSameDayAs: message.sectionDate) {
            dateLabel.text = DateFormatter.shortStyleDateTime(message.displayDate)
        }
        // Show time
        else {
            dateLabel.text = DateFormatter.shortStyleTimeNoDate(message.displayDate)
        }
    }
    
    // MARK: Status symbol
    
    private func updateState(to state: BaseMessage.DisplayState) {
        guard let symbol = state.symbol(with: Colors.textLight) else {
            hideStatusSymbol()
            statusSymbolImageView.image = nil
            return
        }
        
        statusSymbolImageView.image = symbol
        showStatusSymbol()
    }
    
    private func showStatusSymbol() {
        guard statusSymbolImageView.isHidden else {
            return
        }
        statusSymbolImageView.isHidden = false

        NSLayoutConstraint.activate(statusSymbolImageViewConstraints)
        dateLabelInsetConstraint.constant = -dateLabelTrailingInset
    }
    
    private func hideStatusSymbol() {
        guard !statusSymbolImageView.isHidden else {
            return
        }
        statusSymbolImageView.isHidden = true
        
        NSLayoutConstraint.deactivate(statusSymbolImageViewConstraints)
        dateLabelInsetConstraint.constant = 0
    }
}