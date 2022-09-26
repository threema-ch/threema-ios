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

import Foundation
import UIKit

/// Configuration constants for chat view
enum ChatViewConfiguration {
    
    // TODO: Scale the value according with dynamic type?
    
    /// Cache cell heights
    static let enableCellHeightCaching = true
    /// Estimate and cache (estimated) cell heights
    static let enableEstimatedCellHeightCaching = true
    
    /// Configuration for background of message cells
    enum ChatBubble {
        static let cornerRadius: CGFloat = 16.5
        
        /// Default top and bottom space between chat bubbles (4 means 8 in total)
        static let defaultTopBottomInset: CGFloat = 4
        /// Default leading and trailing space of chat bubbles
        static let defaultLeadingTrailingInset: CGFloat = 8
        
        /// Ratio of readable content width that should be the maximum width of a bubble
        static let maxWidthRatio: CGFloat = 0.7
    }
    
    /// Configuration for background of system message cells
    enum SystemMessageBackground {
        static let cornerRadius: CGFloat = 12.5
        
        /// Default top and bottom inset of content in the system message bubble
        static let defaultSystemMessageTopBottomInset: CGFloat = 4.5
        /// Default leading and trailing inset of content in the system message bubble
        static let defaultSystemMessageLeadingTrailingInset: CGFloat = 10
    }
    
    /// Content inside the bubble
    enum Content {
        /// Default top and bottom inset of content in chat bubble
        static let defaultTopBottomInset: CGFloat = 7
        /// Default leading and trailing inset of content in chat bubble
        static let defaultLeadingTrailingInset: CGFloat = 12
        
        /// Vertical space between content and metadata of message cell
        static let contentAndMetadataSpace: CGFloat = 4
        /// Vertical space between text and secondary text label
        static let textAndSecondaryTextSpace: CGFloat = 2
        /// Horizontal space between icon and text labels of message cell
        static let defaultIconAndTextSpace: CGFloat = 8
        /// Horizontal space between icon and text labels of message cell
        static let defaultIconCenterInset: CGFloat = 8
    }
    
    /// Quote view
    enum Quote {
        /// Width of the bar in a quote
        static let quoteBarWidth: CGFloat = 2
        /// Distance between quote bar and text
        static let quoteBarTextDistance: CGFloat = 6
        /// Default font for the name label in quotes
        static let nameFont = UIFont.preferredFont(forTextStyle: .footnote).bold()
        /// Default font for the text label in quotes
        static let quoteFont = UIFont.preferredFont(forTextStyle: .footnote)
        /// Configuration of state symbol
        static let symbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: .footnote,
            scale: .small
        )
        /// Maximal length of quoted string
        static let maxQuoteLength = 200
    }

    /// Default text
    enum Text {
        /// Default font for text messages and captions
        static let font = UIFont.preferredFont(forTextStyle: .body)
        static let emojiFont = UIFont.preferredFont(forTextStyle: .title1)
        /// Configuration of symbols
        static let symbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: .body,
            scale: .default
        )
    }
    
    /// Secondary text
    /// E.g. Address at LocationMessage
    enum SecondaryText {
        /// Default font for secondary text labels
        static let font = UIFont.preferredFont(forTextStyle: .footnote)
        /// Used to make SFSymbols dynamic
        static let fontStyle: UIFont.TextStyle = .footnote
        /// Scale of state symbol
        static let symbolScale: UIImage.SymbolScale = .default
        /// Configuration of Symbol
        static let symbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: ChatViewConfiguration.SecondaryText.fontStyle,
            scale: ChatViewConfiguration.SecondaryText.symbolScale
        )
        static let smallSymbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: ChatViewConfiguration.SecondaryText.fontStyle,
            scale: .small
        )
    }
    
    /// Thumbnail views
    enum Thumbnail {
        /// Default margin around thumbnail
        static let defaultMargin: CGFloat = 2
        /// Corner radius of thumbnail
        static let cornerRadius = ChatBubble.cornerRadius - defaultMargin
        
        /// Default aspect ratio of thumbnail view
        static let defaultAspectRatio: CGFloat = 1
        /// Min aspect ratio of thumbnail view
        static let minAspectRatio: CGFloat = 0.5
        /// Max aspect ratio of thumbnail view
        static let maxAspectRatio: CGFloat = 1.5
        
        /// Space between state and progress
        static let defaultStateAndProgressSpace: CGFloat = 12
    }
    
    /// File views
    enum File {
        /// Font for file name
        static let fileNameFont = UIFont.preferredFont(forTextStyle: .subheadline)
        
        /// Offset of state circle from file icon
        static let defaultStateCircleOffsetFromFileIcon: CGFloat = 3
        
        /// Minimal space between file size and date and state
        static let minFileSizeAndDateAndStateSpace: CGFloat = 8
        /// Vertical Space between name and metadata
        static let fileNameAndMetadataSpace: CGFloat = 4
        /// Horizontal space between file icon and file info
        static let fileIconAndFileInfoSpace: CGFloat = 8
        
        /// Vertical space between file button/info and caption
        static let fileButtonAndCaptionSpace = Content.defaultTopBottomInset
    }

    enum MetaDataBackground {
        static let defaultMargin: CGFloat = 4
        static let cornerRadius = Thumbnail.cornerRadius - defaultMargin
    }

    /// System Message text
    enum SystemMessageText {
        /// Default font for system messages
        static let font = UIFont.preferredFont(forTextStyle: .footnote)
    }
    
    /// Metadata information (eg. date and state or duration in call cells)
    enum MessageMetadata {
        /// Space between label and symbol
        static let defaultLabelAndSymbolSpace: CGFloat = 4
        /// Inset from leading or trailing end to center of symbol
        static let defaultSymbolCenterInset: CGFloat = 6
        /// Minimal space between a leading and trailing metadata view
        static let minimalInBetweenSpace: CGFloat = 8
        
        /// Text style for labels and symbols
        static let textStyle = UIFont.TextStyle.caption1
        /// Font for labels
        static let font = UIFont.preferredFont(forTextStyle: .caption1)
        /// Configuration for symbol
        static let symbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: textStyle,
            scale: .small
        )
    }
    
    /// Background for a metadata view
    enum MetadataBackground {
        /// Default margin for background from rest
        static let defaultMargin: CGFloat = 4
        /// Corner radius of background
        static let cornerRadius = Thumbnail.cornerRadius - defaultMargin
        /// Default top and bottom inset of metadata view
        static let topAndBottomInset: CGFloat = 2
        /// Default leading and trailing inset of metadata view
        static let leadingAndTrailingInset: CGFloat = 8
    }
    
    enum ChatBar {
        /// Size of the send button
        static let sendButtonSize: CGFloat = 26
        /// Size of the attachment add button (plus button)
        static let plusButtonSize: CGFloat = 21
        /// Spacing between the camera and microphone icons
        static let cameraMicSpacing: CGFloat = 18.0
        /// Spacing between the attachment add button and the textInputView and the textInputView and the microphone / camera / send button
        static let textInputButtonSpacing: CGFloat = 12
        /// Vertical distance between border of ChatBar and text view
        static let verticalChatBarTextViewDistance: CGFloat = 7
        /// The maximum number of lines before the textInputView start to scroll
        static let maxNumberOfLines = 7
        /// The default value for the height of a single line
        static let defaultSingleLineHeight: CGFloat = 33.5
        /// Animation configuration for hiding / showing the send button
        enum ShowHideSendButtonAnimation {
            static let totalDuration: CGFloat = 0.25
            static let fadeDuration: CGFloat = 0.15
            static let preFadeDelay: CGFloat = 0.1
        }

        /// Animation shown when the ChatBar changes size
        enum ContentInsetAnimation {
            static let totalDuration: CGFloat = 0.25
            static let delay: CGFloat = 0.15
        }
        
        enum QuoteView {
            static let topBottomInset: CGFloat = 8
            static let leadingTrailingInset: CGFloat = 16
            // The spacing property of the main StackView currently used to layout the quoteview and the dismiss button
            static let stackViewSpacing: CGFloat = 16
        }
    }
    
    /// Button with an SF Symbol used in the ChatBarView
    enum ChatBarButton {
        static let defaultSize: CGFloat = 17
    }
    
    enum ChatTextView {
        static let borderWidth: CGFloat = 1
        static let cornerRadius: CGFloat = ChatBubble.cornerRadius
        static let leadingAndTrailingInset: CGFloat = 10
        // Ideally they fulfill cornerRadius > 2*minTopAndBottomInset + TextView height with one line of text with
        // default dynamic type
        static let minTopAndBottomInset: CGFloat = 4
        static let textStyle = UIFont.TextStyle.body
    }
    
    enum MentionsView {
        static let maxHeight: CGFloat = 250
        /// Animation duration for appearing and disappearing
        static let animationDuration: CGFloat = 0.25
    }
}
