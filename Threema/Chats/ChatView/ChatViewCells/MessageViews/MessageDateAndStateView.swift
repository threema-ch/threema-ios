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

/// Show appropriate date/time and status symbol if any for provided message
///
/// If the content size category changes you need to recreate this view. The spacing won't adapt to the new category.
final class MessageDateAndStateView: UIView {
    
    /// Message to show date and state for
    ///
    /// Reset to update with current message information.
    var message: BaseMessage? {
        didSet {
            guard let message, !message.willBeDeleted else {
                return
            }
            
            showStatus = message.messageDisplayState != .none
            showGroupReactions = message.isGroupMessage && message.messageGroupReactionState != .none
            showMarkers = message.hasMarkers
            
            let block = {
                self.updateSubviews(for: message)
                self.layoutIfNeeded()
            }
            
            if let oldValue, message.objectID == oldValue.objectID {
                UIView.animate(
                    withDuration: ChatViewConfiguration.ChatBubble
                        .dateAndStateViewShowAndHideAnimationDurationInSeconds,
                    delay: 0.0,
                    options: [.curveEaseInOut]
                ) {
                    block()
                }
            }
            else {
                block()
            }
        }
    }
    
    /// Allows overriding the default text and symbol color to something custom
    var overrideColor: UIColor? {
        didSet {
            updateColors()
        }
    }
    
    // MARK: - Private properties
    
    private lazy var constantScaler = UIFontMetrics(forTextStyle: ChatViewConfiguration.MessageMetadata.textStyle)
    
    /// Offset of a view from trailing end to a symbol
    private lazy var trailingSymbolConstant: CGFloat = {
        // The view is as far away from the symbol center as its center is form the trailing end plus the space
        let offset = symbolXCenterTrailingDistance // This is already scaled
        let scaledSpace = constantScaler.scaledValue(
            for: ChatViewConfiguration.MessageMetadata.defaultLabelAndSymbolSpace
        )
        
        return offset + scaledSpace
    }()
    
    /// Distance of symbol center from trailing end
    private lazy var symbolXCenterTrailingDistance: CGFloat = {
        // Adapt for content size categories
        constantScaler.scaledValue(for: ChatViewConfiguration.MessageMetadata.defaultSymbolCenterInset)
    }()
    
    // MARK: Views & constraints
    
    // Date: Trailing to this view there can be the Status, GroupReactions, Markers or no view.
    private lazy var dateLabel = MessageMetadataTextLabel()
    
    private lazy var dateLabelConstraints: [NSLayoutConstraint] =
        [dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor)]
    
    private lazy var dateLabelStatusViewConstraints: [NSLayoutConstraint] = [dateLabel.trailingAnchor.constraint(
        equalTo: statusImageView.centerXAnchor,
        constant: -trailingSymbolConstant
    )]
    
    private lazy var dateLabelGroupReactionsViewConstraints: [NSLayoutConstraint] =
        [dateLabel.trailingAnchor.constraint(
            equalTo: groupReactionsView.leadingAnchor,
            constant: -ChatViewConfiguration.MessageMetadata.minimalInBetweenSpace
        )]

    private lazy var dateLabelMarkerViewConstraints: [NSLayoutConstraint] = [dateLabel.trailingAnchor.constraint(
        equalTo: markersView.centerXAnchor,
        constant: -trailingSymbolConstant
    )]
    
    // Status: Trailing to this view there can be GroupReactions, Markers or no view.
    private var showStatus = false
    private lazy var statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        return imageView
    }()
    
    private lazy var statusImageViewConstraints: [NSLayoutConstraint] = [
        statusImageView.firstBaselineAnchor.constraint(equalTo: dateLabel.firstBaselineAnchor),
        statusImageView.centerXAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -symbolXCenterTrailingDistance
        ),
    ]
    
    private lazy var statusImageViewGroupReactionsViewConstraints: [NSLayoutConstraint] = [
        statusImageView.firstBaselineAnchor.constraint(equalTo: dateLabel.firstBaselineAnchor),
        statusImageView.centerXAnchor.constraint(
            equalTo: groupReactionsView.leadingAnchor,
            constant: -trailingSymbolConstant
        ),
    ]
    
    private lazy var statusImageViewMarkerViewConstraints: [NSLayoutConstraint] = [
        statusImageView.firstBaselineAnchor.constraint(equalTo: dateLabel.firstBaselineAnchor),
        statusImageView.centerXAnchor.constraint(
            equalTo: markersView.leadingAnchor,
            constant: -trailingSymbolConstant
        ),
    ]
    
    // GroupReactions: Trailing to this view there can be Markers or no view.
    private var showGroupReactions = false
    private lazy var groupReactionsView = MessageGroupReactionView()
    
    private lazy var groupReactionsViewConstraints: [NSLayoutConstraint] = [
        groupReactionsView.trailingAnchor.constraint(
            equalTo: trailingAnchor
        ),
    ]
    
    private lazy var groupReactionsViewMarkerViewConstraints: [NSLayoutConstraint] = [
        groupReactionsView.trailingAnchor.constraint(
            equalTo: markersView.centerXAnchor,
            constant: -trailingSymbolConstant
        ),
    ]
    
    // Markers: Trailing to this view there can only be no view.
    private var showMarkers = false
    private lazy var markersView = MessageMarkersView()
    
    private lazy var markersViewConstraints: [NSLayoutConstraint] = [
        markersView.centerXAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -symbolXCenterTrailingDistance
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
        addSubview(statusImageView)
        addSubview(groupReactionsView)
        addSubview(markersView)
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        groupReactionsView.translatesAutoresizingMaskIntoConstraints = false
        markersView.translatesAutoresizingMaskIntoConstraints = false
                
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: topAnchor),
            dateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    // MARK: - Updates
    
    func updateColors() {
        if let dateColor = overrideColor {
            Colors.setTextColor(dateColor, label: dateLabel)
        }
        else {
            Colors.setTextColor(Colors.textLight, label: dateLabel)
        }
        
        groupReactionsView.updateColors()
        markersView.updateColors()
    }
    
    private func updateSubviews(for message: BaseMessage) {
        updateDateLabel(for: message)
        updateStatusImageView(for: message)
        updateGroupReactionsView(for: message)
        updateMarkersView(for: message)
    }
    
    private func updateDateLabel(for message: BaseMessage) {
        // Show date and time if the `displayDate` is on another day than the date used for sectioning
        if !Calendar.current.isDate(message.displayDate, inSameDayAs: message.sectionDate) {
            dateLabel.text = DateFormatter.relativeMediumDateAndShortTime(for: message.displayDate)
        }
        // Show time
        else {
            dateLabel.text = DateFormatter.shortStyleTimeNoDate(message.displayDate)
        }
        
        if message.lastEditedAt != nil {
            if let dateLabelText = dateLabel.text {
                dateLabel.text = "\("edited_message_state".localized) • \(dateLabelText)"
            }
            else {
                dateLabel.text = "edited_message_state".localized
            }
        }
        
        if showStatus {
            NSLayoutConstraint.activate(dateLabelStatusViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelGroupReactionsViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelMarkerViewConstraints)
        }
        else if showGroupReactions {
            NSLayoutConstraint.activate(dateLabelGroupReactionsViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelStatusViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelMarkerViewConstraints)
        }
        else if showMarkers {
            NSLayoutConstraint.activate(dateLabelMarkerViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelStatusViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelGroupReactionsViewConstraints)
        }
        else {
            NSLayoutConstraint.activate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelStatusViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelGroupReactionsViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelMarkerViewConstraints)
        }
    }
    
    private func updateStatusImageView(for message: BaseMessage) {
        let state = message.messageDisplayState
        guard let symbol = state.symbol(with: Colors.textLight) else {
            statusImageView.isHidden = true
            statusImageView.image = nil
            return
        }
        
        let coloredSymbol: UIImage
        if state != .userAcknowledged, state != .userDeclined, let textColor = overrideColor {
            coloredSymbol = symbol.withTintColor(textColor, renderingMode: .alwaysOriginal)
        }
        else {
            coloredSymbol = symbol
        }
        
        statusImageView.image = coloredSymbol
        
        UIView.performWithoutAnimation {
            if showGroupReactions {
                NSLayoutConstraint.activate(statusImageViewGroupReactionsViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewMarkerViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewConstraints)
            }
            else if showMarkers {
                NSLayoutConstraint.activate(statusImageViewMarkerViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewGroupReactionsViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewConstraints)
            }
            else {
                NSLayoutConstraint.activate(statusImageViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewGroupReactionsViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewMarkerViewConstraints)
            }
        
            // Avoids a slide in from the left
            layoutIfNeeded()
            statusImageView.isHidden = false
        }
    }
    
    private func updateGroupReactionsView(for message: BaseMessage) {
        groupReactionsView.message = message
        
        guard showGroupReactions else {
            groupReactionsView.isHidden = true
            return
        }
        
        UIView.performWithoutAnimation {
            if showMarkers {
                NSLayoutConstraint.activate(groupReactionsViewMarkerViewConstraints)
                NSLayoutConstraint.deactivate(groupReactionsViewConstraints)
            }
            else {
                NSLayoutConstraint.activate(groupReactionsViewConstraints)
                NSLayoutConstraint.deactivate(groupReactionsViewMarkerViewConstraints)
            }
            
            // Avoids a slide in from the left
            layoutIfNeeded()
            groupReactionsView.isHidden = false
        }
    }
    
    private func updateMarkersView(for message: BaseMessage) {
        markersView.message = message
        
        guard showMarkers else {
            markersView.isHidden = true
            NSLayoutConstraint.deactivate(markersViewConstraints)
            return
        }
        
        UIView.performWithoutAnimation {
            NSLayoutConstraint.activate(markersViewConstraints)
            
            // Avoids a slide in from the left
            layoutIfNeeded()
            markersView.isHidden = false
        }
    }
}
