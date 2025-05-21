//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import UIKit

/// Show appropriate date/time and status symbol if any for provided message
///
/// If the content size category changes you need to recreate this view. The spacing won't adapt to the new category.
final class MessageDateAndStateView: UIView {
    
    /// Message to show date and state for
    ///
    /// Reset to update with current message information.
    var message: BaseMessageEntity? {
        didSet {
            guard let message, !message.willBeDeleted else {
                return
            }
            
            showStatus = message.messageDisplayState != .none && message.deletedAt == nil
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
            if let overrideColor {
                dateLabel.textColor = overrideColor
            }
            else {
                dateLabel.textColor = .secondaryLabel
            }
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
    private lazy var symbolXCenterTrailingDistance: CGFloat = constantScaler.scaledValue(
        // Adapt for content size categories
        for: ChatViewConfiguration.MessageMetadata.defaultSymbolCenterInset
    )
    
    // MARK: Views & constraints
    
    // Date: Trailing to this view there can be the Status, Markers or no view.
    private lazy var dateLabel = MessageMetadataTextLabel()
    
    private lazy var dateLabelConstraints: [NSLayoutConstraint] =
        [dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor)]
    
    private lazy var dateLabelStatusViewConstraints: [NSLayoutConstraint] = [dateLabel.trailingAnchor.constraint(
        equalTo: statusImageView.centerXAnchor,
        constant: -trailingSymbolConstant
    )]

    private lazy var dateLabelMarkerViewConstraints: [NSLayoutConstraint] = [dateLabel.trailingAnchor.constraint(
        equalTo: markersView.centerXAnchor,
        constant: -trailingSymbolConstant
    )]
    
    // Status: Trailing to this view there can be Markers or no view.
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
    
    private lazy var statusImageViewMarkerViewConstraints: [NSLayoutConstraint] = [
        statusImageView.firstBaselineAnchor.constraint(equalTo: dateLabel.firstBaselineAnchor),
        statusImageView.centerXAnchor.constraint(
            equalTo: markersView.leadingAnchor,
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
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureLayout() {
        addSubview(dateLabel)
        addSubview(statusImageView)
        addSubview(markersView)
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        markersView.translatesAutoresizingMaskIntoConstraints = false
                
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: topAnchor),
            dateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    // MARK: - Updates
    
    private func updateSubviews(for message: BaseMessageEntity) {
        updateDateLabel(for: message)
        updateStatusImageView(for: message)
        updateMarkersView(for: message)
    }
    
    private func updateDateLabel(for message: BaseMessageEntity) {
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
                dateLabel.text = "\(#localize("edited_message_state")) • \(dateLabelText)"
            }
            else {
                dateLabel.text = #localize("edited_message_state")
            }
        }
        
        if showStatus {
            NSLayoutConstraint.activate(dateLabelStatusViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelMarkerViewConstraints)
        }
        else if showMarkers {
            NSLayoutConstraint.activate(dateLabelMarkerViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelStatusViewConstraints)
        }
        else {
            NSLayoutConstraint.activate(dateLabelConstraints)
            NSLayoutConstraint.deactivate(dateLabelStatusViewConstraints)
            NSLayoutConstraint.deactivate(dateLabelMarkerViewConstraints)
        }
    }
    
    private func updateStatusImageView(for message: BaseMessageEntity) {
        
        guard showStatus else {
            statusImageView.isHidden = true
            statusImageView.image = nil
            return
        }
        
        let state = message.messageDisplayState
        guard let symbol = state.symbol(with: .secondaryLabel) else {
            statusImageView.isHidden = true
            statusImageView.image = nil
            return
        }
        
        statusImageView.image = symbol
        
        UIView.performWithoutAnimation {
            if showMarkers {
                NSLayoutConstraint.activate(statusImageViewMarkerViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewConstraints)
            }
            else {
                NSLayoutConstraint.activate(statusImageViewConstraints)
                NSLayoutConstraint.deactivate(statusImageViewMarkerViewConstraints)
            }
        
            // Avoids a slide in from the left
            layoutIfNeeded()
            statusImageView.isHidden = false
        }
    }
    
    private func updateMarkersView(for message: BaseMessageEntity) {
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
