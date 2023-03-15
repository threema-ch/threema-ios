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
import UIKit

/// Configuration constants for chat view
enum ChatViewConfiguration {
    /// If `strictMode` is enabled failing sanity checks do not only print errors but may also crash for release builds
    static let strictMode = false
    
    // TODO: Scale the value according with dynamic type?
    
    /// Inset at top of all chats. This also adds to the top inset the sticky section header.
    static let topInset = ChatBubble.defaultTopBottomInset
    
    /// Default (additional) inset at the bottom of the chat (scroll) view
    static let bottomInset = ChatBubble.defaultTopBottomInset + (ChatBubble.defaultLeadingTrailingInset / 2)
    /// Default (additional) inset at the bottom of the chat (scroll) view of group chats
    static let groupBottomInset = ChatBubble.defaultGroupTopBottomInset + (ChatBubble.defaultLeadingTrailingInset / 2)
    
    /// Profile on the top in the navigation bar
    enum Profile {
        
        // We use fixed font sizes for the profile in the navigation bar as the navigation bar doesn't adapt
        // its height for different content size categories and also clips them at XXL (no accessibility content
        // sizes are reported)
        
        /// Constant font for contact or group name
        static let nameFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        /// Constant font for group members list
        static let groupMembersListFont = UIFont.systemFont(ofSize: 12)
        
        /// Combined leading and trailing offset from the navigation width
        static let combinedLeadingAndTrailingOffset: CGFloat = 2 * 60
        /// Top and bottom content insets
        ///
        /// All content is offset by these insets on top and bottom
        static let topAndBottomInset: CGFloat = 4
        
        /// Max size for avatar
        static let maxAvatarSize: CGFloat = 34
        
        /// Space between avatar and rest of profile information
        static let avatarAndInfoSpace: CGFloat = 8
        
        /// Height of verification level below name
        static let verificationLevelHeight: CGFloat = 7
        
        /// Vertical space between contact/group name and member list below
        static let nameAndMembersListRegularSpacing: CGFloat = 1
        /// Horizontal space between contact/group name and trailing member list
        static let nameAndMembersListCompactSpacing: CGFloat = 8
        
        /// Call bar button item symbol name
        static let callSymbolName = "threema.phone"
        
        /// Custom ballot bar button item shown in group chats
        enum BallotButton {
            /// Ballot symbol name
            static let ballotSymbolName = "chart.pie"
            /// Ballot symbol configuration to approximate the appearance of a normal bar button item
            static let symbolConfiguration = UIImage.SymbolConfiguration(scale: .large)
            
            /// Size of badge count. Constant as the header height doesn't change
            static let badgeFont = UIFont.systemFont(ofSize: 11)
            
            /// Offset of badge from ballot symbol ratio
            static let badgeOffsetFromBallotSymbolRatio: CGFloat = 2 / 5
            /// Minimal size of badge
            static let minBadgeSize = CGSize(width: 30, height: 18)
            
            /// Min size of button touch area
            static let minimumTouchTargetWidth: CGFloat = 44
            /// Correction of offset to approximate a normal bar button item position
            static let offsetCorrection: CGFloat = 8 // This should always be <= 8
        }
    }
    
    enum SectionHeader {
        /// Default top and bottom insets for section headers (we remove the inset coming from the bubbles around it)
        static let defaultTopAndBottomInset = 16.0 - ChatBubble.defaultTopBottomInset
        
        /// Corner radius for background
        static let cornerRadius = 12.5
        /// Blur effect style for background and vibrancy effect
        static let blurEffectStyle = UIBlurEffect.Style.systemThinMaterial

        /// Configuration for date label in section headers
        enum DateLabel {
            static let font = UIFont.preferredFont(forTextStyle: .footnote).bold()
            
            /// Default top and bottom inset of the label
            static let defaultTopBottomInset = 3.5
            /// Default leading and trailing inset of the label
            static let defaultLeadingTrailingInset = 10.0
        }
    }
    
    /// Cache cell heights
    static let enableCellHeightCaching = false
    /// Estimate and cache (estimated) cell heights
    static let enableEstimatedCellHeightCaching = false
    /// Animation duration
    static let contextMenuBackgroundShowHideAnimationDuration = 0.25
    
    /// Configuration for background of message cells
    enum ChatBubble {
        /// Default corner radius for all bubbles with default and larger `preferredContentSizeCategory`s (i.e. `>= .large`)
        static let cornerRadius = 16.5
        /// Default corner radius for all bubbles with smaller than default `preferredContentSizeCategory`s (i.e. `< .large`)
        static let smallerContentSizeConfigurationCornerRadius = 15.5
        
        /// Default top and bottom space between chat bubbles (4 means 8 in total)
        static let defaultTopBottomInset = 4.0
        /// Default top and bottom space between chat bubbles in group chats (8 means 16 in total)
        static let defaultGroupTopBottomInset = 8.0
        /// Default top and bottom space between chat bubbles when they are grouped (2 means 4 in total)
        static let groupedTopBottomInset = 2.0
        
        /// Default leading and trailing space of chat bubbles
        static let defaultLeadingTrailingInset: CGFloat = 8
        
        /// Ratio of readable content width that should be the maximum width of a bubble
        static let defaultMaxWidthRatio: CGFloat = 0.8
        /// Ratio of readable content width that should be the maximum width of a bubble of a voice message cell
        static let voiceMessageCellMaxWidthRatio: CGFloat = 0.85
        
        /// Duration in seconds of the size change animation if subviews are added to or removed from the chatBubbleView
        /// Should in general be less than or equal to the row height change animation of the table view because otherwise
        /// you will get overlapping cells which doesn't look nice.
        static let bubbleSizeChangeAnimationDurationInSeconds: CGFloat = 0.25
        
        /// Duration in seconds of the show/hide animation of the date and state view for every message
        /// Should in general be less than or equal to the row height change animation of the table view because otherwise
        /// you will get overlapping view which doesn't look nice.
        static let dateAndStateViewShowAndHideAnimationDurationInSeconds: CGFloat = 0.25
        
        enum SwipeInteraction {
            /// This blocks the swipe to quote interaction within n pixels of the left border
            static let swipeDeadZone: CGFloat = 50
            /// Duration for the scaling animation when the swipe to quote action was activated
            static let startQuoteIconAnimationDuration = 0.075
            /// Scale factor for the scaling animation when the swipe to quote action as activated.
            /// Should be chosen such that the multiplicative inverse is a rational number representable with the same type.
            static let startQuoteAnimationScaleFactor = 1.25
            ///  Factor by which the cell moves slower than the finger on the screen after the swipe to quote action was activated
            static let bubbleSlowdownFactorQuote: Double = 1 / 8
            ///  Factor by which the cell moves slower than the finger on the screen after the swipe to details action was activated
            static let bubbleSlowdownFactorDetails: Double = 1 / 4
            /// Number of pixels to swipe before the action activates
            static let swipeActionOffsetThreshold: Double = 55
            /// Number of pixels by which the quote icon is inset from the left edge of the cell bubble
            static let iconInset: Double = swipeActionOffsetThreshold / 1.75
            /// The SFSymbol name of the icon to be used when swiping.
            static let quoteSymbolName = "quote.bubble.fill"
            /// Duration for the reset animation when cell swiping is cancelled
            static let resetDuration = 0.5
            /// Spring dampening for the reset animation when cell swiping is cancelled
            static let springDampening = 0.8
        }
        
        enum MessageDetailsInteraction {
            /// Percentage of the screen that has to be swiped across for the DetailsView to commit to appearing
            static let detailsCommitPercentage = 0.3
            /// Duration in seconds how long the transition to the DetailsView should take
            static let transitionDuration = 0.3
        }
        
        enum HighlightedAnimation {
            /// Duration for which the selected state of the cell is faded in and out
            /// The total duration for the animation is 2 x blinkFadeInOut + highlightedDuration
            static let highlightFadeInOutDuration = 0.5
            /// Duration for which the cell should stay highlighted when used to show it for the user
            static let highlightedDurationLong = 1.75
            /// Duration for which the cell should stay highlighted when tapped
            static let highlightedDurationTap = 0.15
            /// Delay after the tableView has stopped scrolling and the blinkFadeIn should start
            static let highlightDelayAfterScroll = 0.125
        }
        
        enum RetryAndCancelButton {
            /// Name of the SFSymbol displayed in button
            static let symbolName = "arrow.clockwise"
            /// Spacing between the button and the bubble
            static let buttonChatBubbleSpacing = 16.0
        }
    }
    
    enum GroupCells {
        /// Default top and bottom space between name label and cell content
        static let nameLabelDefaultTopBottomInset: CGFloat = 4
        /// Default font for name labels in group message cells
        static let nameLabelFont = UIFont.preferredFont(forTextStyle: .footnote).bold()
        
        /// Inset from the leading side of the cell
        static let avatarLeadingInset: CGFloat = ChatBubble.defaultLeadingTrailingInset
        /// Horizontal space between avatar and message cell
        static let avatarCellSpace: CGFloat = 6.0
        /// Width / height of avatar
        static let maxAvatarSize: CGFloat = 25
        /// Offset of avatar in relation to chat bubble
        static let avatarVerticalOffset: CGFloat = maxAvatarSize / 4
    }
    
    enum CellGrouping {
        /// The maximum amount of time to have passed between two messages for them to still be grouped together in seconds
        static let maxDurationForGroupingTogether = 0.5 * 60 * 60
        
        /// Enable date and state grouping (if both are identical)
        static let enableDateAndStateGrouping = true
    }
    
    enum SystemMessage {
        
        /// Default top and bottom space between system message (8 means 16 in total)
        static let defaultTopBottomInset = 8.0
        /// Default top and bottom space between system message when they are grouped (4 means 8 in total)
        static let groupedDefaultTopBottomInset = 4.0
        
        /// Space between icon and label in WorkConsumerInfoSystemMessageCell
        static let typeIconLabelSpace = 4.0
        
        /// Configuration for background of system message cells
        enum Background {
            static let cornerRadius: CGFloat = 12.5
            
            /// Default top and bottom inset of content in the system message bubble
            static let defaultSystemMessageTopBottomInset: CGFloat = 4.5
            /// Default leading and trailing inset of content in the system message bubble
            static let defaultSystemMessageLeadingTrailingInset: CGFloat = 10
        }
    }
    
    enum TypingIndicator {
        enum AttachedBubble {
            /// Offset from `frame.minX` where `frame` is the frame of the chat bubble
            static let xOffset: CGFloat = 0
            /// Offset from `frame.maxY` where `frame` is the frame of the chat bubble
            static let yOffset: CGFloat = -10
            /// Width of the rectangle in which the oval is contained
            static let width: CGFloat = 8
            /// Height of the rectangle in which the oval is contained
            static let height: CGFloat = 8
        }
        
        enum SmallBubble {
            /// Offset from `frame.minX` where `frame` is the frame of the chat bubble
            static let xOffset: CGFloat = -3
            /// Offset from `frame.maxY` where `frame` is the frame of the chat bubble
            static let yOffset: CGFloat = -3
            /// Width of the rectangle in which the oval is contained
            static let width: CGFloat = 4
            /// Height of the rectangle in which the oval is contained
            static let height: CGFloat = 4
        }
        
        enum Animation {
            /// Darkest color used in the animation
            static let minimumWhiteValue = 0.2
            /// Lightest color used in the animation
            static let maximumWhiteValue = 0.7
            /// Duration of the animation
            static let animationDuration = 1.25
            
            /// Total frames for one transition. In total there will be `3 * (totalFrames + 1)` frames used in the whole animation
            static let totalFrames: Double = 60
            
            /// Offset into the color progression where  `i` of `offseti` indicates the i-th bubble from the left
            static let offset1 = 120
            static let offset2 = 80
            static let offset3 = 40
        }
        
        enum View {
            /// Inset from leadingAnchor of the cells `contentView`. Set to `abs(SmallBubble.xOffset)` for aligning the left most pixel to the other bubbles and to zero for aligning the left most point of the bubble ignoring arrows and bubbles.
            static let leadingInsetConstant: CGFloat = ChatBubble.defaultLeadingTrailingInset
        }
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
        /// Distance between quote view and text cell contents
        static let quoteTextCellDistance: CGFloat = Content.defaultTopBottomInset
        /// Distance between quote bar and text
        static let quoteBarTextDistance: CGFloat = 6
        /// Distance between name and quote text
        static let quoteNameTextDistance: CGFloat = 2
        /// Default font for the name label in quotes
        static let nameFont = UIFont.preferredFont(forTextStyle: .caption1).bold()
        /// Maximal length of quoted string
        static let maxQuoteLength = 200
        /// Maximal lines of quote label
        static let maxQuoteLines = 7
        /// Corner radius of thumbnail
        static let thumbnailCornerRadius = ChatBubble.cornerRadius - ChatBubble.defaultLeadingTrailingInset
        /// Inset of trailing inset of thumbnail
        static let thumbnailTrailingInset = ChatBubble.defaultLeadingTrailingInset
        /// Default size of thumbnail
        static let thumbnailDefaultSize = 40.0
    }

    /// Default text
    enum Text {
        /// Default font for text messages and captions
        static let font = UIFont.preferredFont(forTextStyle: .body)
        static let textStyle = UIFont.TextStyle.body
        static let emojiFont = UIFont.preferredFont(forTextStyle: emojiTextStyle)
        static let emojiTextStyle = UIFont.TextStyle.largeTitle
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
        
        /// Max height of thumbnails (this has higher priority than the aspect ratio)
        static let maxHeight = 350.0
        
        /// Default aspect ratio of thumbnail view
        static let defaultAspectRatio = 1.0
        /// Min aspect ratio of thumbnail view (height/width)
        static let minAspectRatio = 0.3
        /// Max aspect ratio of thumbnail view (height/width)
        static let maxAspectRatio = 1.4
        
        /// The amount of alpha that gets applied on the thumbnail when its cell is highlighted
        static let highlightingAlpha: CGFloat = 0.8
        
        /// Space between state and progress
        static let defaultStateAndProgressSpace: CGFloat = 12
        
        /// The maximum amount of bytes a blob may have in order to be rendered in full resolution
        static let maximumBytesForFullPreview = 5 * 1_000_000
    }
    
    /// File views
    enum File {
        /// Font for file name
        static let fileNameFont = UIFont.preferredFont(forTextStyle: .subheadline)
        
        /// Offset of state circle from file icon
        static let defaultStateCircleOffsetFromFileIcon: CGFloat = 3
        
        /// Default margin around tap view
        static let defaultMargin: CGFloat = 2
        /// Corner radius of tap view
        static let cornerRadius = ChatBubble.cornerRadius - defaultMargin
        /// Inset of the content of the tap view to the border of the tap view
        static let fileLeadingTrailingInset = Content.defaultLeadingTrailingInset - defaultMargin
        /// Inset of the content of the tap view to the border of the tap view
        static let fileTopBottomInset = Content.defaultTopBottomInset - defaultMargin
        
        /// Minimal space between file size and date and state
        static let minFileSizeAndDateAndStateSpace: CGFloat = 8
        /// Vertical Space between name and metadata
        static let fileNameAndMetadataSpace: CGFloat = 4
        /// Horizontal space between file icon and file info
        static let fileIconAndFileInfoSpace: CGFloat = 8
    }
    
    /// Voice Message Views
    enum VoiceMessage {
        /// The point height of the waveform view. the height constraint is set to this.
        /// Together with `PlaybackStateButton.circleFillSymbolSize` this is the major influence on the cell height.
        static let waveformHeight: CGFloat = 35
        
        /// UIStackView spacing between the speed button / mic icon and the waveform view
        static let waveformSpeedIconStackViewSpacing: CGFloat = 2.0
        
        /// TimeInterval in which progress is reported by the voice message cell delegate back to the relevant voice message cell
        static let progressCallbackInterval: CGFloat = 0.01
        
        /// Button showing either a mic symbol or the current playback speed when playing a voice message
        enum SpeedButton {
            /// Duration for the animation shown when switching between mic symbol and playback speed button
            static let hideOrShowAnimationDuration: CGFloat = 0.25
            /// Animation option for the animation shown when switching between mic symbol and playback speed button
            static let hideOrShowAnimationOptions: UIView.AnimationOptions = .curveEaseInOut
            /// Inset for the text in the playback speed button
            static let topBottomInset: CGFloat = 3
            static let leftRightInset: CGFloat = 6
            /// Symbol configuration for the mic symbol
            static let micIconSymbolConfigurationScale: UIImage.SymbolScale = .large
            
            /// Corner radius of the background around the speed label
            static let cornerRadius: CGFloat = 10
            
            /// Label showing the current playback speed
            enum SpeedLabel {
                /// Font used for the speed label
                static let font = UIFont.monospacedDigitSystemFont(ofSize: 14.0, weight: .regular)
            }
        }

        /// Button indicating the current blob state or play state if appropriate
        enum PlaybackStateButton {
            /// Symbol inset from the border of the button for play state symbols
            static let circleFillSymbolInset: CGFloat = 5
            /// Symbol size for play and pause symbols used in the playback state button
            static let circleFillSymbolSize: CGFloat = 44
        }
        
        /// View displaying the waveform for the voice message
        enum WaveformView {
            /// inset of the UIImageView displaying the waveform from it's parent view
            static let waveformImageInset: CGFloat = 0
            
            /// The width of a single bar in the waveform view
            static let singleBarWidth: CGFloat = 2
            /// The spacing between two bars in the waveform view
            static let barSpacing: CGFloat = 2
            
            /// Height of the rendered waveform image. Ideally this is the height of the waveform's parent view minus two times the insets
            static let waveformRenderHeight: CGFloat = 35
        }
        
        enum NeighborPlayback {
            static let maxDurationForNeighborAutomaticPlaybackInSeconds = 0.5 * 60 * 60
        }
    }

    enum MetaDataBackground {
        static let defaultMargin: CGFloat = 4
        static let cornerRadius = Thumbnail.cornerRadius - defaultMargin
    }

    /// System Message text
    enum SystemMessageText {
        /// Default text style for system messages
        static let defaultTextStyle = UIFont.TextStyle.footnote
        /// Work / consumer font for system messages
        static let workConsumerFont = UIFont.preferredFont(forTextStyle: defaultTextStyle).bold()
        /// Configuration for work / consumer info
        static let workConsumerSymbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: defaultTextStyle,
            scale: .large
        )
    }
    
    /// Metadata information (eg. date and state or duration in call cells)
    enum MessageMetadata {
        /// Space between label and symbol
        static let defaultLabelAndSymbolSpace: CGFloat = 4
        /// Inset from leading or trailing end to center of symbol
        static let defaultSymbolCenterInset: CGFloat = 6
        /// Minimal space between a leading and trailing metadata view
        static let minimalInBetweenSpace: CGFloat = 8
        /// space between label and group reaction symbol
        static let defaultLabelGroupReactionSymbolSpace: CGFloat = 1
        
        /// Text style for labels and symbols
        static let textStyle = UIFont.TextStyle.caption1
        /// Font for labels
        /// Remember to update the font in `fontPointSize` as well
        static let font = UIFont.preferredFont(forTextStyle: .caption1)
        /// Font point size for `font`
        static let fontPointSize = {
            /// This must be equal to the font used in `font`
            /// We cannot use `font` directly because otherwise the size doesn't change when updating the font size while the app is running
            UIFont.preferredFont(forTextStyle: .caption1).pointSize
        }

        /// Monospaced digit font of same point size as `font`
        static let monospacedDigitFont = {
            UIFont.monospacedDigitSystemFont(
                ofSize: fontPointSize(),
                weight: .regular
            )
        }

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
        static let borderWidth = 0.5
        static let cornerRadius = ChatBubble.cornerRadius
        static let smallerContentSizeConfigurationCornerRadius = ChatBubble.smallerContentSizeConfigurationCornerRadius
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
    
    enum UnreadMessageLine {
        static let minimalCellHeight = 30.0
        
        static let pillLeftRightTextInset = 8.0
        static let pillTopBottomTextInset = 4.0
        static let pillRadius = 12.0
        static let pillBlurEffectStyle = UIBlurEffect.Style.systemThinMaterial
        
        static let leftRightLineHeight = 3.0
        static let leftRightLineRadius = 1.5
        static let leftRightLineInnerRoundedCorners = true
        static let leftRightLineOuterRoundedCorners = false
        static let leftRightLineMaxScreenwidthRatio = 0.125
        
        static let font = UIFont.monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
            weight: .bold
        )
        
        /// Maximum time in milliseconds before the unread message line disappears when the user scrolls to the bottom of the chat view
        /// Might be shorter than this if the data source applies a snapshot before
        static let timeBeforeDisappear = 1500
        
        /// Timeout in seconds before we cancel the `willEnterForegroundCompletion`
        static let completionTimeout: Double = 2
    }
    
    enum ScrollToBottomButton {
        /// Insets left and right to the content view containing the button and the number of unread messages
        static let leftRightInsets = 15.0
        /// Insets top and bottom to the content view containing the button and the number of unread messages
        static let topBottomInsets = 7.5
        /// Corner radius of the views on the left side
        static let cornerRadius = 5.0
        /// Distance between the bottom edge of the button and the chat bar
        static let distanceToChatBar = 15.0
        
        enum ShowHideAnimation {
            static let duration = 0.5
            static let delay = 0.25
        }
        
        /// Combine throttle in Ms
        /// Applied before new changes are checked
        static let dataUpdateThrottleInMs = 250
    }
    
    enum DataSource {
        static let typingIndicatorThrottle: TimeInterval = 0.25
        static let unreadMessagesSnapshotStateThrottleInMs = 250
        /// Delay before the current messages snapshot is processed by the snapshot provider
        /// This can be increased to multiple hundreds of ms if we actually do snapshot batching
        static let currentMessageSnapshotDelay = 500
    }
    
    enum SearchResults {
        /// Text style for sender name shown in search results
        static let nameTextStyle = UIFont.TextStyle.headline
        /// Text style for date and disclosure indicator
        static let metadataTextStyle = UIFont.TextStyle.subheadline
        /// Spacing between date and disclosure indicator
        static let metadataSpacing = 4.0
        /// Spacing between name and meta
        static let nameAndMetadataSpacing = 8.0
        /// Text style for message preview text
        static let messagePreviewTextTextStyle = UIFont.TextStyle.body
        /// Spacing between name & metadata and message preview
        static let verticalSpacing = 4.0
        /// Color used for highlighting search text in cells is defined directly in `MarkupParser`
    }
    
    enum SearchResultsFetching {
        /// Will display a maximum number of `maxItemsToFetch` of each message type in the search results
        /// 0 means no limit
        static let maxItemsToFetch = 0
        /// The number of seconds to wait before starting a new fetch request
        static let debounceInputSeconds: RunLoop.SchedulerTimeType.Stride = 0.5
    }
    
    enum ScrollCompletionBehavior {
        /// Whether to use `scrollToRow(at:at:animated:)` or`UIView.animate` with `animated` always set to false in `scrollToRow(at:at:animated:)`
        /// `UIView.animate` seems to be more stable but might have not yet discovered side effects.
        static let useCustomViewAnimationBlock = true
        static let animationDuration = 0.25
        /// Delay in ms before the `scrollCompletion` block is called to signal that the scrolling animation has completed
        static let completionBlockCallDelay = 50
    }
    
    enum ScrollBehavior {
        /// Feature Flag for additional workarounds when using flipped mode of the table view
        /// Must not be set to true if flipped table view is disabled
        static var overrideDefaultTableViewBehavior = {
            if !UserSettings.shared().flippedTableView {
                return false
            }
            
            // Actual configuration value
            return true
        }()
        
        /// We need some non-zero additional space above the content height of newly added cells when checking
        /// whether we can adjust the content offset or must scroll down to avoid glitches
        /// You can find a more detailed description of the workaround in `willApplySnapshot(currentDoesIncludeNewestMessage:)` of `ChatViewController`
        static let newCellsContentHeightLeeway = 1.0
    }
}
