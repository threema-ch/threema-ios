//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2022 Threema GmbH
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

#import "Colors.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "UIImage+ColoredImage.h"
#import "UITextField+Themed.h"
#import "ContactNameLabel.h"
#import "VoIPHelper.h"
#import "TextStyleUtils.h"
#import "LicenseStore.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#define THREEMA_COLOR_PLACEHOLDER [UIColor lightGrayColor]

#define THREEMA_COLOR_LIGHT_GREY [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0]
#define THREEMA_COLOR_DARK_GREY [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0]
#define THREEMA_COLOR_GREEN [UIColor colorWithRed:96.0/255.0 green:194.0/255.0 blue:57.0/255.0 alpha:1.0]

// MARK: Dark Theme Base
#define THEME_DARK_BACKGROUND_BASE [UIColor colorWithRed:0.0/255.0 green: 0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND [UIColor colorWithRed:33.0/255.0 green:33.0/255.0 blue:33.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND_DARK [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND_CHAT [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define THEME_DARK_CHAT_BACKGROUND_LINES [UIColor colorWithRed:173.0/255.0 green:173.0/255.0 blue:173.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND_CHAT_SYSTEM_MESSAGE [UIColor colorWithRed:97.0/255.0 green:97.0/255.0 blue:97.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND_SELECTED_DARK [UIColor colorWithRed:66.0/255.0 green:66.0/255.0 blue:66.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND_LIGHT [UIColor colorWithRed:66.0/255.0 green:66.0/255.0 blue:66.0/255.0 alpha:1.0]
#define THEME_DARK_BACKGROUND_INVERTED [UIColor colorWithRed:66.0/255.0 green:66.0/255.0 blue:66.0/255.0 alpha:1.0]
#define THEME_DARK_SHARE_EXTENSION_SELECTED_BACKGROUND [UIColor colorWithRed:0.82 green:0.82 blue:0.82 alpha:1.0]
#define THEME_DARK_FONT_NORMAL [UIColor colorWithRed:250.0/255.0 green:250.0/255.0 blue:250.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_LIGHT [UIColor colorWithRed:224.0/255.0 green:224.0/255.0 blue:224.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_VERY_LIGHT [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_DARK [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_INVERTED [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_QUOTE_ID [UIColor colorWithRed:158.0/255.0 green:158.0/255.0 blue:158.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_QUOTE_TEXT [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_DARK_CHATBAR_INPUT [UIColor colorWithRed:33.0/255.0 green:33.0/255.0 blue:33.0/255.0 alpha:1.0]
#define THEME_DARK_CHATBAR_BACKGROUND [UIColor colorWithRed:22.0/255.0 green:22.0/255.0 blue:22.0/255.0 alpha:1.0]
#define THEME_DARK_CHATBAR_BORDER [UIColor colorWithRed:66.0/255.0 green:66.0/255.0 blue:66.0/255.0 alpha:1.0]
#define THEME_DARK_SWITCH_THUMB [UIColor colorWithRed:250.0/255.0 green:250.0/255.0 blue:250.0/255.0 alpha:1.0]
#define THEME_DARK_BALLOT_ROW_LIGHT [UIColor colorWithRed:97.0/255.0 green:97.0/255.0 blue:97.0/255.0 alpha:1.0]
#define THEME_DARK_BALLOT_ROW_DARK [UIColor colorWithRed:66.0/255.0 green:66.0/255.0 blue:66.0/255.0 alpha:1.0]
#define THEME_DARK_HAIRLINE [UIColor colorWithRed:55.0/255.0 green:55.0/255.0 blue:55.0/255.0 alpha:1.0]
#define THEME_DARK_ORANGE [UIColor colorWithRed:246.0/255.0 green:146.0/255.0 blue:30.0/255.0 alpha:1.0]
#define THEME_DARK_RED [UIColor colorWithRed:235.0/255.0 green:29.0/255.0 blue:36.0/255.0 alpha:1.0]
#define THEME_DARK_GRAY [UIColor colorWithRed:158.0/255.0 green:158.0/255.0 blue:158.0/255.0 alpha:1.0]
#define THEME_DARK_SEARCH_BAR_STATUS_BAR [UIColor colorWithRed:46.0/255.0 green:46.0/255.0 blue:41.0/255.0 alpha:1.0]

#define THEME_DARK_MENTION_BACKGROUND [UIColor colorWithRed:158.0/255.0 green:158.0/255.0 blue:158.0/255.0 alpha:1.0]
#define THEME_DARK_MENTION_BACKGROUND_OWN [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:1.0]
#define THEME_DARK_MENTION_BACKGROUND_OVERVIEW [UIColor colorWithRed:158.0/255.0 green:158.0/255.0 blue:158.0/255.0 alpha:1.0]
#define THEME_DARK_MENTION_BACKGROUND_ME [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_DARK_MENTION_BACKGROUND_OWN_ME [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_DARK_MENTION_BACKGROUND_OVERVIEW_ME [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_DARK_MENTION_TEXT_ME THEME_DARK_FONT_INVERTED
#define THEME_DARK_MENTION_TEXT_OWN_ME THEME_DARK_FONT_INVERTED
#define THEME_DARK_MENTION_TEXT_OVERVIEW_ME THEME_DARK_FONT_INVERTED

#define THEME_DARK_BUBBLE_SENT [UIColor colorWithRed:38.0/255.0 green:38.0/255.0 blue:38.0/255.0 alpha:1.0]
#define THEME_DARK_BUBBLE_SENT_SELECTED [UIColor colorWithRed:130.0/255.0 green:130.0/255.0 blue:130.0/255.0 alpha:1.0]
#define THEME_DARK_BUBBLE_RECEIVED [UIColor colorWithRed:55.0/255.0 green:55.0/255.0 blue:55.0/255.0 alpha:1.0]
#define THEME_DARK_BUBBLE_RECEIVED_SELECTED [UIColor colorWithRed:130.0/255.0 green:130.0/255.0 blue:130.0/255.0 alpha:1.0]
#define THEME_DARK_TAG_MARK_BACKGROUND [UIColor colorWithRed:254.0/255.0 green:196.0/255.0 blue:0.0/255.0 alpha:1.0]

#define THEME_DARK_POPUP_MENU_BACKGROUND [UIColor colorWithRed:97.0/255.0 green:97.0/255.0 blue:97.0/255.0 alpha:1.0]
#define THEME_DARK_POPUP_MENU_HIGHTLIGHT [UIColor colorWithRed:130.0/255.0 green:130.0/255.0 blue:130.0/255.0 alpha:1.0]
#define THEME_DARK_POPUP_MENU_SEPARATOR [UIColor colorWithRed:130.0/255.0 green:130.0/255.0 blue:130.0/255.0 alpha:1.0]

#define THEME_DARK_NOTIFICATION_BACKGROUND [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define THEME_DARK_NOTIFICATION_SHADOW [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0]

// MARK: Dark Theme
#define THEME_DARK_MAIN [UIColor colorWithRed:5.0/255.0 green: 166.0/255.0 blue:63.0/255.0 alpha:1.0]

#define THEME_DARK_FONT_LINK THEME_DARK_MAIN
#define THEME_DARK_FONT_LINK_RECEIVED [UIColor colorWithRed:6.0/255.0 green: 204.0/255.0 blue:77.0/255.0 alpha:1.0]
#define THEME_DARK_FONT_PLACEHOLDER THREEMA_COLOR_PLACEHOLDER

#define THEME_DARK_BUBBLE_CALL_BUTTON THEME_DARK_MAIN

#define THEME_DARK_BALLOT_HIGHEST_VOTE THEME_DARK_MAIN

#define THEME_DARK_QUOTE_BAR THEME_DARK_GREEN

#define THEME_DARK_GREEN THEME_DARK_MAIN
#define THEME_DARK_VERIFICATION_GREEN THEME_DARK_MAIN
#define THEME_DARK_WORK_BLUE [UIColor colorWithRed:0.0/255.0 green: 115.0/255.0 blue:196.0/255.0 alpha:1.0]

#define THEME_DARK_CALL_STATUS_BAR [UIColor colorWithRed:2.0/255.0 green:52.0/255.0 blue:20.0/255.0 alpha:1.0]

// MARK: Dark Work Theme
#define THEME_DARK_WORK_MAIN [UIColor colorWithRed:0.0/255.0 green: 150.0/255.0 blue:255.0/255.0 alpha:1.0]

#define THEME_DARK_WORK_FONT_LINK THEME_DARK_WORK_MAIN
#define THEME_DARK_WORK_FONT_LINK_RECEIVED [UIColor colorWithRed:20.0/255.0 green: 158.0/255.0 blue:255.0/255.0 alpha:1.0]
#define THEME_DARK_WORK_FONT_PLACEHOLDER THREEMA_COLOR_PLACEHOLDER

#define THEME_DARK_WORK_BUBBLE_CALL_BUTTON THEME_DARK_WORK_MAIN

#define THEME_DARK_WORK_BALLOT_HIGHEST_VOTE THEME_DARK_WORK_MAIN

#define THEME_DARK_WORK_QUOTE_BAR THEME_DARK_WORK_MAIN

#define THEME_DARK_WORK_GREEN [UIColor colorWithRed:5.0/255.0 green: 166.0/255.0 blue:63.0/255.0 alpha:1.0]
#define THEME_DARK_WORK_VERIFICATION_GREEN [UIColor colorWithRed:70.0/255.0 green: 168.0/255.0 blue:32.0/255.0 alpha:1.0]
#define THEME_DARK_WORK_WORK_BLUE THEME_DARK_WORK_MAIN

#define THEME_DARK_WORK_CALL_STATUS_BAR [UIColor colorWithRed:0.0/255.0 green:50.0/255.0 blue:7.0/255.0 alpha:1.0]

// MARK: Light Theme Base
#define THEME_LIGHT_BACKGROUND_BASE [UIColor colorWithRed:250.0/255.0 green:250.0/255.0 blue:250.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND [UIColor colorWithRed:250.0/255.0 green:250.0/255.0 blue:250.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND_DARK [UIColor colorWithRed:238.0/255.0 green:238.0/255.0 blue:238.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND_SELECTED_DARK [UIColor colorWithRed:212.0/255.0 green:212.0/255.0 blue:212.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND_LIGHT [UIColor colorWithRed:250.0/255.0 green:250.0/255.0 blue:250.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND_INVERTED [UIColor colorWithRed:158.0/255.0 green:158.0/255.0 blue:158.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND_CHAT [UIColor colorWithRed:250.0/255.0 green:250.0/255.0 blue:250.0/255.0 alpha:1.0]
#define THEME_LIGHT_CHAT_BACKGROUND_LINES [UIColor colorWithRed:144.0/255.0 green:144.0/255.0 blue:144.0/255.0 alpha:1.0]
#define THEME_LIGHT_BACKGROUND_CHAT_SYSTEM_MESSAGE [UIColor colorWithRed:224.0/255.0 green:224.0/255.0 blue:224.0/255.0 alpha:1.0]
#define THEME_LIGHT_SHARE_EXTENSION_SELECTED_BACKGROUND [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]

#define THEME_LIGHT_FONT_NORMAL [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] // Normal font color
#define THEME_LIGHT_FONT_LIGHT [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:1.0]
#define THEME_LIGHT_FONT_VERY_LIGHT [UIColor colorWithRed:158.0/255.0 green:158.0/255.0 blue:158.0/255.0 alpha:1.0]
#define THEME_LIGHT_FONT_DARK [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]

#define THEME_LIGHT_FONT_INVERTED [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0]
#define THEME_LIGHT_FONT_QUOTE_ID [UIColor colorWithRed:97.0/255.0 green:97.0/255.0 blue:97.0/255.0 alpha:1.0]
#define THEME_LIGHT_FONT_QUOTE_TEXT [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:1.0]

#define THEME_LIGHT_FONT_PLACEHOLDER THREEMA_COLOR_PLACEHOLDER // Placeholder color (Lightgray)

#define THEME_LIGHT_CHATBAR_INPUT [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0]
#define THEME_LIGHT_CHATBAR_BACKGROUND [UIColor colorWithRed:238.0/255.0 green:238.0/255.0 blue:238.0/255.0 alpha:1.0]
#define THEME_LIGHT_CHATBAR_BORDER [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]

#define THEME_LIGHT_SWITCH_THUMB nil

#define THEME_LIGHT_BALLOT_ROW_LIGHT [UIColor colorWithRed:238.0/255.0 green:238.0/255.0 blue:238.0/255.0 alpha:1.0]
#define THEME_LIGHT_BALLOT_ROW_DARK [UIColor colorWithRed:224.0/255.0 green:224.0/255.0 blue:224.0/255.0 alpha:1.0]

#define THEME_LIGHT_HAIRLINE [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]

#define THEME_LIGHT_ORANGE [UIColor colorWithRed:246.0/255.0 green:146.0/255.0 blue:30.0/255.0 alpha:1.0]
#define THEME_LIGHT_RED [UIColor colorWithRed:235.0/255.0 green:29.0/255.0 blue:36.0/255.0 alpha:1.0]
#define THEME_LIGHT_GRAY [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]

#define THEME_LIGHT_SEARCH_BAR_STATUS_BAR [UIColor colorWithRed:224.0/255.0 green:224.0/255.0 blue:224.0/255.0 alpha:1.0]

#define THEME_LIGHT_MENTION_BACKGROUND [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_LIGHT_MENTION_BACKGROUND_OWN [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_LIGHT_MENTION_BACKGROUND_OVERVIEW [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]
#define THEME_LIGHT_MENTION_BACKGROUND_ME [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:1.0]
#define THEME_LIGHT_MENTION_BACKGROUND_OWN_ME [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:1.0]
#define THEME_LIGHT_MENTION_BACKGROUND_OVERVIEW_ME [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:1.0]
#define THEME_LIGHT_MENTION_TEXT_ME THEME_LIGHT_FONT_INVERTED
#define THEME_LIGHT_MENTION_TEXT_OWN_ME THEME_LIGHT_FONT_INVERTED
#define THEME_LIGHT_MENTION_TEXT_OVERVIEW_ME THEME_LIGHT_FONT_INVERTED

#define THEME_LIGHT_BUBBLE_RECEIVED [UIColor colorWithRed:232.0/255.0 green:232.0/255.0 blue:232.0/255.0 alpha:1.0]
#define THEME_LIGHT_BUBBLE_RECEIVED_SELECTED [UIColor colorWithRed:189.0/255.0 green:189.0/255.0 blue:189.0/255.0 alpha:1.0]

#define THEME_LIGHT_TAG_MARK_BACKGROUND [UIColor colorWithRed:254.0/255.0 green:196.0/255.0 blue:0.0/255.0 alpha:1.0]

#define THEME_LIGHT_POPUP_MENU_BACKGROUND [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0.95]
#define THEME_LIGHT_POPUP_MENU_HIGHTLIGHT [UIColor colorWithRed:85.0/255.0 green:85.0/255.0 blue:85.0/255.0 alpha:0.95]
#define THEME_LIGHT_POPUP_MENU_SEPARATOR [UIColor colorWithRed:117.0/255.0 green:117.0/255.0 blue:117.0/255.0 alpha:0.95]

#define THEME_LIGHT_NOTIFICATION_BACKGROUND [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0]
#define THEME_LIGHT_NOTIFICATION_SHADOW [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]

// MARK: Light Theme
#define THEME_LIGHT_MAIN [UIColor colorWithRed:5.0/255.0 green: 148.0/255.0 blue:61.0/255.0 alpha:1.0]

#define THEME_LIGHT_FONT_LINK THEME_LIGHT_MAIN // Link font color
#define THEME_LIGHT_FONT_LINK_RECEIVED THEME_LIGHT_MAIN

#define THEME_LIGHT_BUBBLE_SENT [UIColor colorWithRed:220.0/255.0 green:242.0/255.0 blue:211.0/255.0 alpha:1.0]
#define THEME_LIGHT_BUBBLE_SENT_SELECTED [UIColor colorWithRed:148.0/255.0 green:215.0/255.0 blue:120.0/255.0 alpha:1.0]
#define THEME_LIGHT_BUBBLE_CALL_BUTTON THEME_LIGHT_MAIN

#define THEME_LIGHT_BALLOT_HIGHEST_VOTE THEME_LIGHT_MAIN

#define THEME_LIGHT_QUOTE_BAR THEME_LIGHT_GREEN

#define THEME_LIGHT_GREEN THEME_LIGHT_MAIN
#define THEME_LIGHT_VERIFICATION_GREEN THEME_LIGHT_MAIN
#define THEME_LIGHT_WORK_BLUE [UIColor colorWithRed:0.0/255.0 green: 115.0/255.0 blue:196.0/255.0 alpha:1.0]
#define THEME_LIGHT_CALL_STATUS_BAR [UIColor colorWithRed:196.0/255.0 green:233.0/255.0 blue:181.0/255.0 alpha:1.0]


// MARK: Light Work Theme
#define THEME_LIGHT_WORK_MAIN [UIColor colorWithRed:0.0/255.0 green: 115.0/255.0 blue:196.0/255.0 alpha:1.0]

#define THEME_LIGHT_WORK_FONT_LINK THEME_LIGHT_WORK_MAIN // Link font color
#define THEME_LIGHT_WORK_FONT_LINK_RECEIVED THEME_LIGHT_WORK_MAIN
#define THEME_LIGHT_WORK_FONT_PLACEHOLDER THREEMA_COLOR_PLACEHOLDER // Placeholder color (Lightgray)

#define THEME_LIGHT_WORK_BUBBLE_SENT [UIColor colorWithRed:196.0/255.0 green:226.0/255.0 blue:255.0/255.0 alpha:1.0]
#define THEME_LIGHT_WORK_BUBBLE_SENT_SELECTED [UIColor colorWithRed:118.0/255.0 green:187.0/255.0 blue:255.0/255.0 alpha:1.0]
#define THEME_LIGHT_WORK_BUBBLE_CALL_BUTTON THEME_LIGHT_WORK_MAIN

#define THEME_LIGHT_WORK_BALLOT_HIGHEST_VOTE THEME_LIGHT_WORK_MAIN

#define THEME_LIGHT_WORK_QUOTE_BAR THEME_LIGHT_WORK_MAIN

#define THEME_LIGHT_WORK_GREEN [UIColor colorWithRed:5.0/255.0 green: 153.0/255.0 blue:63.0/255.0 alpha:1.0]
#define THEME_LIGHT_WORK_VERIFICATION_GREEN [UIColor colorWithRed:5.0/255.0 green: 153.0/255.0 blue:63.0/255.0 alpha:1.0]
#define THEME_LIGHT_WORK_WORK_BLUE THEME_LIGHT_WORK_MAIN
#define THEME_LIGHT_WORK_CALL_STATUS_BAR [UIColor colorWithRed:157.0/255.0 green:207.0/255.0 blue:255.0/255.0 alpha:1.0]


static UIColor *main;

static UIColor *backgroundBaseColor;

static UIColor *background;
static UIColor *backgroundLight;
static UIColor *backgroundDark;
static UIColor *backgroundSelectedDark;
static UIColor *backgroundInverted;
static UIColor *backgroundChat;
static UIColor *chatBackgroundLines;
static UIColor *chatSystemMessageBackground;
static UIColor *shareExtensionSelectedBackground;

static UIColor *fontNormal;
static UIColor *fontLight;
static UIColor *fontVeryLight;
static UIColor *fontDark;
static UIColor *fontLink;
static UIColor *fontLinkReceived;
static UIColor *fontPlaceholder;
static UIColor *fontInverted;
static UIColor *fontQuoteId;
static UIColor *fontQuoteText;

static UIColor *chatBarInput;
static UIColor *chatBarBackground;
static UIColor *chatBarBorder;

static UIColor *switchThumb;

static UIColor *bubbleSent;
static UIColor *bubbleSentSelected;
static UIColor *bubbleReceived;
static UIColor *bubbleReceivedSelected;
static UIColor *bubbleCall;
static UIColor *bubbleCallButton;
static UIColor *popupMenuBackground;
static UIColor *popupMenuHighlight;
static UIColor *popupMenuSeparator;

static UIColor *ballotHighestVote;
static UIColor *ballotRowLight;
static UIColor *ballotRowDark;

static UIColor *hairline;
static UIColor *quoteBar;

static UIColor *orange;
static UIColor *red;
static UIColor *green;
static UIColor *gray;
static UIColor *verificationGreen;
static UIColor *workBlue;

static UIColor *searchBarStatusBar;
static UIColor *callStatusBar;

static UIColor *mentionBackgroundOwnMessageColor;
static UIColor *mentionBackgroundOverviewColor;
static UIColor *mentionBackgroundColor;
static UIColor *mentionBackgroundOwnMessageMeColor;
static UIColor *mentionBackgroundOverviewMeColor;
static UIColor *mentionBackgroundMeColor;
static UIColor *mentionTextOwnMessageMeColor;
static UIColor *mentionTextOverviewMeColor;
static UIColor *mentionTextMeColor;

static UIColor *tagMarkBackground;

static UIColor *notificationBackground;
static UIColor *notificationShadow;

static ColorTheme colorTheme;
static UITraitCollection *traitCollection;

@implementation Colors

+ (void)initialize {
    if (@available(iOS 13.0, *)) {
        if ([[UserSettings sharedUserSettings] useSystemTheme] == true) {
            traitCollection = [UITraitCollection currentTraitCollection];
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                [self setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeDarkWork : ColorThemeDark];
            } else {
                [self setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeLightWork : ColorThemeLight];
            }
        } else {
            if ([UserSettings sharedUserSettings].darkTheme) {
                [self setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeDarkWork : ColorThemeDark];
            } else {
                [self setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeLightWork : ColorThemeLight];
            }
        }
    } else {
        if ([UserSettings sharedUserSettings].darkTheme) {
            [self setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeDarkWork : ColorThemeDark];
        } else {
            [self setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeLightWork : ColorThemeLight];
        }
    }
}

+ (BOOL)areCustomized {
    return colorTheme != ColorThemeLight;
}

+ (void)setTheme:(ColorTheme)newTheme {
    colorTheme = newTheme;
    switch (colorTheme) {
        case ColorThemeDark:
            [self setupDarkTheme];
            [UserSettings sharedUserSettings].darkTheme = YES;
            break;
        case ColorThemeDarkWork:
            [self setupDarkWorkTheme];
            [UserSettings sharedUserSettings].darkTheme = YES;
            break;
        case ColorThemeLight:
            [self setupLightTheme];
            [UserSettings sharedUserSettings].darkTheme = NO;
            break;
        case ColorThemeLightWork:
            [self setupLightWorkTheme];
            [UserSettings sharedUserSettings].darkTheme = NO;
            break;
        case ColorThemeUndefined:
            [self setupLightTheme];
            [UserSettings sharedUserSettings].darkTheme = NO;
            break;
    }
    
    [StyleKit resetThemedCache];
            
    UIWindow *windowAppearance = [UIWindow appearance];
    [self updateWindow:windowAppearance];
    
    UINavigationBar *navigationBarAppearance = [UINavigationBar appearance];
    [self updateNavigationBar:navigationBarAppearance];
    
    UITabBar *tabBarAppearance = [UITabBar appearance];
    [self updateTabBar:tabBarAppearance];
    
    UISwitch *switchAppearance = [UISwitch appearance];
    [self updateSwitch:switchAppearance];
    
    UISearchBar *searchBarAppearance = [UISearchBar appearance];
    [self updateSearchBar:searchBarAppearance];
    
    [[UIView appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setTintColor:[Colors main]];

    [[UIView appearanceWhenContainedInInstancesOfClasses:@[[UIDocumentMenuViewController class]]] setTintColor:[Colors main]];
    [[UIButton appearanceWhenContainedInInstancesOfClasses:@[[UIDocumentMenuViewController class], [UIAlertController class]]] setTintColor:[Colors main]];

    [[UIView appearanceWhenContainedInInstancesOfClasses:@[[UIWindow class], [UIView class]]] setTintColor:[Colors main]];
    
    if(@available(iOS 13, *)) {
        // only use the appearance below iOS 13, in iOS 13 we can set the textColor directly on the searchbar
    } else {
        [[UITextField appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]] setDefaultTextAttributes:@{NSForegroundColorAttributeName: fontNormal}];
    }

}

+ (ColorTheme)getTheme {
    return colorTheme;
}

+ (void)setupLightTheme {
    main = THEME_LIGHT_MAIN;
    
    backgroundBaseColor = THEME_LIGHT_BACKGROUND_BASE;
    
    background = THEME_LIGHT_BACKGROUND;
    backgroundLight = THEME_LIGHT_BACKGROUND_LIGHT;
    backgroundDark = THEME_LIGHT_BACKGROUND_DARK;
    backgroundSelectedDark = THEME_LIGHT_BACKGROUND_SELECTED_DARK;
    backgroundInverted = THEME_LIGHT_BACKGROUND_INVERTED;
    backgroundChat = THEME_LIGHT_BACKGROUND_CHAT;
    chatBackgroundLines = THEME_LIGHT_CHAT_BACKGROUND_LINES;
    chatSystemMessageBackground = THEME_LIGHT_BACKGROUND_CHAT_SYSTEM_MESSAGE;
    shareExtensionSelectedBackground = THEME_LIGHT_SHARE_EXTENSION_SELECTED_BACKGROUND;
    
    fontNormal = THEME_LIGHT_FONT_NORMAL;
    fontLight = THEME_LIGHT_FONT_LIGHT;
    fontVeryLight = THEME_LIGHT_FONT_VERY_LIGHT;
    fontDark = THEME_LIGHT_FONT_DARK;
    fontLink = THEME_LIGHT_FONT_LINK;
    fontLinkReceived = THEME_LIGHT_FONT_LINK_RECEIVED;
    fontPlaceholder = THEME_LIGHT_FONT_PLACEHOLDER;
    fontInverted = THEME_LIGHT_FONT_INVERTED;
    fontQuoteId = THEME_LIGHT_FONT_QUOTE_ID;
    fontQuoteText = THEME_LIGHT_FONT_QUOTE_TEXT;
    
    chatBarBackground = THEME_LIGHT_CHATBAR_BACKGROUND;
    chatBarInput = THEME_LIGHT_CHATBAR_INPUT;
    chatBarBorder = THEME_LIGHT_CHATBAR_BORDER;
    
    switchThumb = THEME_LIGHT_SWITCH_THUMB;
    
    bubbleSent = THEME_LIGHT_BUBBLE_SENT;
    bubbleSentSelected = THEME_LIGHT_BUBBLE_SENT_SELECTED;
    bubbleReceived = THEME_LIGHT_BUBBLE_RECEIVED;
    bubbleReceivedSelected = THEME_LIGHT_BUBBLE_RECEIVED_SELECTED;
    bubbleCallButton = THEME_LIGHT_BUBBLE_CALL_BUTTON;
    
    popupMenuBackground = THEME_LIGHT_POPUP_MENU_BACKGROUND;
    popupMenuHighlight = THEME_LIGHT_POPUP_MENU_HIGHTLIGHT;
    popupMenuSeparator = THEME_LIGHT_POPUP_MENU_SEPARATOR;
    
    ballotHighestVote = THEME_LIGHT_BALLOT_HIGHEST_VOTE;
    ballotRowLight = THEME_LIGHT_BALLOT_ROW_LIGHT;
    ballotRowDark = THEME_LIGHT_BALLOT_ROW_DARK;
    
    hairline = THEME_LIGHT_HAIRLINE;
    quoteBar = THEME_LIGHT_QUOTE_BAR;
    
    orange = THEME_LIGHT_ORANGE;
    red = THEME_LIGHT_RED;
    green = THEME_LIGHT_GREEN;
    gray = THEME_LIGHT_GRAY;
    verificationGreen = THEME_LIGHT_VERIFICATION_GREEN;
    workBlue = THEME_LIGHT_WORK_BLUE;
    
    searchBarStatusBar = THEME_LIGHT_SEARCH_BAR_STATUS_BAR;
    callStatusBar = THEME_LIGHT_CALL_STATUS_BAR;
    
    mentionBackgroundOwnMessageColor = THEME_LIGHT_MENTION_BACKGROUND_OWN;
    mentionBackgroundColor = THEME_LIGHT_MENTION_BACKGROUND;
    mentionBackgroundOverviewColor = THEME_LIGHT_MENTION_BACKGROUND_OVERVIEW;
    mentionBackgroundOwnMessageMeColor = THEME_LIGHT_MENTION_BACKGROUND_OWN_ME;
    mentionBackgroundMeColor = THEME_LIGHT_MENTION_BACKGROUND_ME;
    mentionBackgroundOverviewMeColor = THEME_LIGHT_MENTION_BACKGROUND_OVERVIEW_ME;
    mentionTextOwnMessageMeColor = THEME_LIGHT_MENTION_TEXT_OWN_ME;
    mentionTextMeColor = THEME_LIGHT_MENTION_TEXT_ME;
    mentionTextOverviewMeColor = THEME_LIGHT_MENTION_TEXT_OVERVIEW_ME;
    
    tagMarkBackground = THEME_LIGHT_TAG_MARK_BACKGROUND;
    
    notificationBackground = THEME_LIGHT_NOTIFICATION_BACKGROUND;
    notificationShadow = THEME_LIGHT_NOTIFICATION_SHADOW;
}

+ (void)setupLightWorkTheme {
    main = THEME_LIGHT_WORK_MAIN;
    
    backgroundBaseColor = THEME_LIGHT_BACKGROUND_BASE;
    
    background = THEME_LIGHT_BACKGROUND;
    backgroundLight = THEME_LIGHT_BACKGROUND_LIGHT;
    backgroundDark = THEME_LIGHT_BACKGROUND_DARK;
    backgroundSelectedDark = THEME_LIGHT_BACKGROUND_SELECTED_DARK;
    backgroundInverted = THEME_LIGHT_BACKGROUND_INVERTED;
    backgroundChat = THEME_LIGHT_BACKGROUND_CHAT;
    chatBackgroundLines = THEME_LIGHT_CHAT_BACKGROUND_LINES;
    chatSystemMessageBackground = THEME_LIGHT_BACKGROUND_CHAT_SYSTEM_MESSAGE;
    shareExtensionSelectedBackground = THEME_LIGHT_SHARE_EXTENSION_SELECTED_BACKGROUND;
    
    fontNormal = THEME_LIGHT_FONT_NORMAL;
    fontLight = THEME_LIGHT_FONT_LIGHT;
    fontVeryLight = THEME_LIGHT_FONT_VERY_LIGHT;
    fontDark = THEME_LIGHT_FONT_DARK;
    fontLink = THEME_LIGHT_WORK_FONT_LINK;
    fontLinkReceived = THEME_LIGHT_WORK_FONT_LINK_RECEIVED;
    fontPlaceholder = THEME_LIGHT_WORK_FONT_PLACEHOLDER;
    fontInverted = THEME_LIGHT_FONT_INVERTED;
    fontQuoteId = THEME_LIGHT_FONT_QUOTE_ID;
    fontQuoteText = THEME_LIGHT_FONT_QUOTE_TEXT;
    
    chatBarBackground = THEME_LIGHT_CHATBAR_BACKGROUND;
    chatBarInput = THEME_LIGHT_CHATBAR_INPUT;
    chatBarBorder = THEME_LIGHT_CHATBAR_BORDER;
    
    switchThumb = THEME_LIGHT_SWITCH_THUMB;
    
    bubbleSent = THEME_LIGHT_WORK_BUBBLE_SENT;
    bubbleSentSelected = THEME_LIGHT_WORK_BUBBLE_SENT_SELECTED;
    bubbleReceived = THEME_LIGHT_BUBBLE_RECEIVED;
    bubbleReceivedSelected = THEME_LIGHT_BUBBLE_RECEIVED_SELECTED;
    bubbleCallButton = THEME_LIGHT_WORK_BUBBLE_CALL_BUTTON;
    
    popupMenuBackground = THEME_LIGHT_POPUP_MENU_BACKGROUND;
    popupMenuHighlight = THEME_LIGHT_POPUP_MENU_HIGHTLIGHT;
    popupMenuSeparator = THEME_LIGHT_POPUP_MENU_SEPARATOR;
    
    ballotHighestVote = THEME_LIGHT_WORK_BALLOT_HIGHEST_VOTE;
    ballotRowLight = THEME_LIGHT_BALLOT_ROW_LIGHT;
    ballotRowDark = THEME_LIGHT_BALLOT_ROW_DARK;
    
    hairline = THEME_LIGHT_HAIRLINE;
    quoteBar = THEME_LIGHT_WORK_QUOTE_BAR;
    
    orange = THEME_LIGHT_ORANGE;
    red = THEME_LIGHT_RED;
    green = THEME_LIGHT_WORK_GREEN;
    gray = THEME_LIGHT_GRAY;
    verificationGreen = THEME_LIGHT_WORK_VERIFICATION_GREEN;
    workBlue = THEME_LIGHT_WORK_WORK_BLUE;
    
    searchBarStatusBar = THEME_LIGHT_SEARCH_BAR_STATUS_BAR;
    callStatusBar = THEME_LIGHT_WORK_CALL_STATUS_BAR;
    
    mentionBackgroundOwnMessageColor = THEME_LIGHT_MENTION_BACKGROUND_OWN;
    mentionBackgroundColor = THEME_LIGHT_MENTION_BACKGROUND;
    mentionBackgroundOverviewColor = THEME_LIGHT_MENTION_BACKGROUND_OVERVIEW;
    mentionBackgroundOwnMessageMeColor = THEME_LIGHT_MENTION_BACKGROUND_OWN_ME;
    mentionBackgroundMeColor = THEME_LIGHT_MENTION_BACKGROUND_ME;
    mentionBackgroundOverviewMeColor = THEME_LIGHT_MENTION_BACKGROUND_OVERVIEW_ME;
    mentionTextOwnMessageMeColor = THEME_LIGHT_MENTION_TEXT_OWN_ME;
    mentionTextMeColor = THEME_LIGHT_MENTION_TEXT_ME;
    mentionTextOverviewMeColor = THEME_LIGHT_MENTION_TEXT_OVERVIEW_ME;

    tagMarkBackground = THEME_LIGHT_TAG_MARK_BACKGROUND;
    
    notificationBackground = THEME_LIGHT_NOTIFICATION_BACKGROUND;
    notificationShadow = THEME_LIGHT_NOTIFICATION_SHADOW;
}

+ (void)setupDarkTheme {
    main = THEME_DARK_MAIN;
    
    backgroundBaseColor = THEME_DARK_BACKGROUND_BASE;
    
    background = THEME_DARK_BACKGROUND;
    backgroundLight = THEME_DARK_BACKGROUND_LIGHT;
    backgroundDark = THEME_DARK_BACKGROUND_DARK;
    backgroundSelectedDark = THEME_DARK_BACKGROUND_SELECTED_DARK;
    backgroundInverted = THEME_DARK_BACKGROUND_INVERTED;
    backgroundChat = THEME_DARK_BACKGROUND_CHAT;
    chatBackgroundLines = THEME_DARK_CHAT_BACKGROUND_LINES;
    chatSystemMessageBackground = THEME_DARK_BACKGROUND_CHAT_SYSTEM_MESSAGE;
    shareExtensionSelectedBackground = THEME_DARK_SHARE_EXTENSION_SELECTED_BACKGROUND;
    
    fontNormal = THEME_DARK_FONT_NORMAL;
    fontLight = THEME_DARK_FONT_LIGHT;
    fontVeryLight = THEME_DARK_FONT_VERY_LIGHT;
    fontDark = THEME_DARK_FONT_DARK;
    fontLink = THEME_DARK_FONT_LINK;
    fontLinkReceived = THEME_DARK_FONT_LINK_RECEIVED;
    fontPlaceholder = THEME_DARK_FONT_PLACEHOLDER;
    fontInverted = THEME_DARK_FONT_INVERTED;
    fontQuoteId = THEME_DARK_FONT_QUOTE_ID;
    fontQuoteText = THEME_DARK_FONT_QUOTE_TEXT;
    
    chatBarBackground = THEME_DARK_CHATBAR_BACKGROUND;
    chatBarInput = THEME_DARK_CHATBAR_INPUT;
    chatBarBorder = THEME_DARK_CHATBAR_BORDER;
    
    switchThumb = THEME_DARK_SWITCH_THUMB;
    
    bubbleSent = THEME_DARK_BUBBLE_SENT;
    bubbleSentSelected = THEME_DARK_BUBBLE_SENT_SELECTED;
    bubbleReceived = THEME_DARK_BUBBLE_RECEIVED;
    bubbleReceivedSelected = THEME_DARK_BUBBLE_RECEIVED_SELECTED;
    bubbleCallButton = THEME_DARK_BUBBLE_CALL_BUTTON;
    
    popupMenuBackground = THEME_DARK_POPUP_MENU_BACKGROUND;
    popupMenuHighlight = THEME_DARK_POPUP_MENU_HIGHTLIGHT;
    popupMenuSeparator = THEME_DARK_POPUP_MENU_SEPARATOR;
    
    ballotHighestVote = THEME_DARK_BALLOT_HIGHEST_VOTE;
    ballotRowLight = THEME_DARK_BALLOT_ROW_LIGHT;
    ballotRowDark = THEME_DARK_BALLOT_ROW_DARK;
    
    hairline = THEME_DARK_HAIRLINE;
    quoteBar = THEME_DARK_QUOTE_BAR;
    
    orange = THEME_DARK_ORANGE;
    red = THEME_DARK_RED;
    green = THEME_DARK_GREEN;
    gray = THEME_DARK_GRAY;
    verificationGreen = THEME_DARK_VERIFICATION_GREEN;
    workBlue = THEME_DARK_WORK_BLUE;
    
    searchBarStatusBar = THEME_DARK_SEARCH_BAR_STATUS_BAR;
    callStatusBar = THEME_DARK_CALL_STATUS_BAR;
    
    mentionBackgroundOwnMessageColor = THEME_DARK_MENTION_BACKGROUND_OWN;
    mentionBackgroundColor = THEME_DARK_MENTION_BACKGROUND;
    mentionBackgroundOverviewColor = THEME_DARK_MENTION_BACKGROUND_OVERVIEW;
    mentionBackgroundOwnMessageMeColor = THEME_DARK_MENTION_BACKGROUND_OWN_ME;
    mentionBackgroundMeColor = THEME_DARK_MENTION_BACKGROUND_ME;
    mentionBackgroundOverviewMeColor = THEME_DARK_MENTION_BACKGROUND_OVERVIEW_ME;
    mentionTextOwnMessageMeColor = THEME_DARK_MENTION_TEXT_OWN_ME;
    mentionTextMeColor = THEME_DARK_MENTION_TEXT_ME;
    mentionTextOverviewMeColor = THEME_DARK_MENTION_TEXT_OVERVIEW_ME;
    
    tagMarkBackground = THEME_DARK_TAG_MARK_BACKGROUND;
    
    notificationBackground = THEME_DARK_NOTIFICATION_BACKGROUND;
    notificationShadow = THEME_DARK_NOTIFICATION_SHADOW;
}

+ (void)setupDarkWorkTheme {
    main = THEME_DARK_WORK_MAIN;
    
    backgroundBaseColor = THEME_DARK_BACKGROUND_BASE;
    
    background = THEME_DARK_BACKGROUND;
    backgroundLight = THEME_DARK_BACKGROUND_LIGHT;
    backgroundDark = THEME_DARK_BACKGROUND_DARK;
    backgroundSelectedDark = THEME_DARK_BACKGROUND_SELECTED_DARK;
    backgroundInverted = THEME_DARK_BACKGROUND_INVERTED;
    backgroundChat = THEME_DARK_BACKGROUND_CHAT;
    chatBackgroundLines = THEME_DARK_CHAT_BACKGROUND_LINES;
    chatSystemMessageBackground = THEME_DARK_BACKGROUND_CHAT_SYSTEM_MESSAGE;
    shareExtensionSelectedBackground = THEME_DARK_SHARE_EXTENSION_SELECTED_BACKGROUND;
    
    fontNormal = THEME_DARK_FONT_NORMAL;
    fontLight = THEME_DARK_FONT_LIGHT;
    fontVeryLight = THEME_DARK_FONT_VERY_LIGHT;
    fontDark = THEME_DARK_FONT_DARK;
    fontLink = THEME_DARK_WORK_FONT_LINK;
    fontLinkReceived = THEME_DARK_WORK_FONT_LINK_RECEIVED;
    fontPlaceholder = THEME_DARK_WORK_FONT_PLACEHOLDER;
    fontInverted = THEME_DARK_FONT_INVERTED;
    fontQuoteId = THEME_DARK_FONT_QUOTE_ID;
    fontQuoteText = THEME_DARK_FONT_QUOTE_TEXT;
    
    chatBarBackground = THEME_DARK_CHATBAR_BACKGROUND;
    chatBarInput = THEME_DARK_CHATBAR_INPUT;
    chatBarBorder = THEME_DARK_CHATBAR_BORDER;
    
    switchThumb = THEME_DARK_SWITCH_THUMB;
    
    bubbleSent = THEME_DARK_BUBBLE_SENT;
    bubbleSentSelected = THEME_DARK_BUBBLE_SENT_SELECTED;
    bubbleReceived = THEME_DARK_BUBBLE_RECEIVED;
    bubbleReceivedSelected = THEME_DARK_BUBBLE_RECEIVED_SELECTED;
    bubbleCallButton = THEME_DARK_WORK_BUBBLE_CALL_BUTTON;
    
    popupMenuBackground = THEME_DARK_POPUP_MENU_BACKGROUND;
    popupMenuHighlight = THEME_DARK_POPUP_MENU_HIGHTLIGHT;
    popupMenuSeparator = THEME_DARK_POPUP_MENU_SEPARATOR;
    
    ballotHighestVote = THEME_DARK_WORK_BALLOT_HIGHEST_VOTE;
    ballotRowLight = THEME_DARK_BALLOT_ROW_LIGHT;
    ballotRowDark = THEME_DARK_BALLOT_ROW_DARK;
    
    hairline = THEME_DARK_HAIRLINE;
    quoteBar = THEME_DARK_WORK_QUOTE_BAR;
    
    orange = THEME_DARK_ORANGE;
    red = THEME_DARK_RED;
    green = THEME_DARK_WORK_GREEN;
    gray = THEME_DARK_GRAY;
    verificationGreen = THEME_DARK_WORK_VERIFICATION_GREEN;
    workBlue = THEME_DARK_WORK_WORK_BLUE;
    
    searchBarStatusBar = THEME_DARK_SEARCH_BAR_STATUS_BAR;
    callStatusBar = THEME_DARK_WORK_CALL_STATUS_BAR;
    
    mentionBackgroundOwnMessageColor = THEME_DARK_MENTION_BACKGROUND_OWN;
    mentionBackgroundColor = THEME_DARK_MENTION_BACKGROUND;
    mentionBackgroundOverviewColor = THEME_DARK_MENTION_BACKGROUND_OVERVIEW;
    mentionBackgroundOwnMessageMeColor = THEME_DARK_MENTION_BACKGROUND_OWN_ME;
    mentionBackgroundMeColor = THEME_DARK_MENTION_BACKGROUND_ME;
    mentionBackgroundOverviewMeColor = THEME_DARK_MENTION_BACKGROUND_OVERVIEW_ME;
    mentionTextOwnMessageMeColor = THEME_DARK_MENTION_TEXT_OWN_ME;
    mentionTextMeColor = THEME_DARK_MENTION_TEXT_ME;
    mentionTextOverviewMeColor = THEME_DARK_MENTION_TEXT_OVERVIEW_ME;

    tagMarkBackground = THEME_DARK_TAG_MARK_BACKGROUND;
    
    notificationBackground = THEME_DARK_NOTIFICATION_BACKGROUND;
    notificationShadow = THEME_DARK_NOTIFICATION_SHADOW;
}

+ (void)resetToDefault {
    [self setTheme:ColorThemeLight];
}

+ (void)updateKeyboardAppearanceFor:(id<UITextInputTraits>)textInputTraits {
    if ([textInputTraits respondsToSelector:@selector(setKeyboardAppearance:)]) {
        switch (colorTheme) {
            case ColorThemeDark:
            case ColorThemeDarkWork:
                textInputTraits.keyboardAppearance = UIKeyboardAppearanceDark;
                break;
            case ColorThemeLight:
            case ColorThemeLightWork:
            case ColorThemeUndefined:
                textInputTraits.keyboardAppearance = UIKeyboardAppearanceDefault;
                break;
        }
    }
    
    if ([textInputTraits respondsToSelector:@selector(setTextColor:)]) {
        [textInputTraits performSelector:@selector(setTextColor:) withObject:[Colors fontNormal]];
    }
    
    if ([textInputTraits respondsToSelector:@selector(setTintColor:)]) {
        [textInputTraits performSelector:@selector(setTintColor:) withObject:[Colors main]];
    }
    
    if ([textInputTraits respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        NSAttributedString *placeholder = [textInputTraits performSelector:@selector(attributedPlaceholder)];
        NSMutableAttributedString *mutablePlaceholder = [[NSMutableAttributedString alloc] initWithAttributedString:placeholder];
        [mutablePlaceholder addAttribute:NSForegroundColorAttributeName value:[Colors fontPlaceholder] range:NSMakeRange(0, placeholder.length)];
        
        [textInputTraits performSelector:@selector(setAttributedPlaceholder:) withObject:mutablePlaceholder];
    }
    
    if ([textInputTraits respondsToSelector:@selector(setTintColor:)]) {
        [textInputTraits performSelector:@selector(setTintColor:) withObject:[Colors main]];
    }
    
    if ([textInputTraits isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)textInputTraits;
        [textField colorizeClearButton];
    }
}

+ (void)updateWindow:(UIWindow *)window {
    [window setTintColor:main];
}

+ (void)updateNavigationBar:(UINavigationBar *)navigationBar {
    switch (colorTheme) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            [navigationBar setBarStyle:UIBarStyleBlack];
            [navigationBar setTranslucent:YES];
            [navigationBar setTintColor:main];
            [navigationBar setBackgroundColor:nil];
            
            if (@available(iOS 13.0, *)) {
                navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            }
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            [navigationBar setBarStyle:UIBarStyleDefault];
            [navigationBar setTintColor:main];
            [navigationBar setBackgroundColor:backgroundBaseColor];
            
            if (@available(iOS 13.0, *)) {
                navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
            }
            break;
    }
    if ([VoIPHelper shared].isCallActiveInBackground) {
        [navigationBar setBarTintColor:callStatusBar];
    } else {
        [navigationBar setBarTintColor:nil];
    }
    
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *newAppearance = [[UINavigationBarAppearance alloc] init];
        [newAppearance configureWithDefaultBackground];
        if ([VoIPHelper shared].isCallActiveInBackground) {
            newAppearance.backgroundColor = callStatusBar;
        } else {
            newAppearance.backgroundColor = nil;
        }
        navigationBar.standardAppearance = newAppearance;
        navigationBar.scrollEdgeAppearance = newAppearance;
    } else {
        if (@available(iOS 11.0, *)) {
            [navigationBar setTintColor:main];
            [navigationBar setLargeTitleTextAttributes:@{NSForegroundColorAttributeName: fontNormal}];
        }
    }
}

+ (void)updateTableView:(UITableView *)tableView {
    if (tableView.style == UITableViewStyleGrouped) {
        [tableView setBackgroundColor:[Colors background]];
    } else {
        [tableView setBackgroundColor:[Colors background]];
    }
    
    [tableView setSectionIndexBackgroundColor:[UIColor clearColor]];
    [tableView setSectionIndexColor:[Colors main]];
    
    [tableView setSeparatorColor:[Colors hairline]];
    
    tableView.backgroundView = [[UIView alloc] initWithFrame:tableView.frame];
    tableView.backgroundView.backgroundColor = [Colors backgroundDark];
}

+ (void)updateTableViewCellBackground:(UITableViewCell *)cell {
    [cell setBackgroundColor:[Colors background]];
    
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = [Colors backgroundSelectedDark];
}

+ (void)updateTableViewCell:(UITableViewCell *)cell {
    [self updateTableViewCellBackground:cell];
    
    UIColor *textColor;
    UIColor *detailTextColor;
    
    if (cell.accessibilityTraits & UIAccessibilityTraitNotEnabled && !cell.isUserInteractionEnabled) {
        textColor = [Colors fontLight];
        detailTextColor = [Colors fontVeryLight];
    } else if (cell.accessibilityTraits & UIAccessibilityTraitButton && cell.accessoryType != UITableViewCellAccessoryDisclosureIndicator && cell.accessoryType != UITableViewCellAccessoryDetailButton && ![cell.accessoryView isKindOfClass:[UISwitch class]]) {
        textColor = [Colors main];
        detailTextColor = [Colors fontLight];
    } else {
        textColor = [Colors fontNormal];
        detailTextColor = [Colors fontLight];
    }
    
    // handle custom table cells
    [self setTextColor:textColor inView:cell.contentView];
    
    if (cell.detailTextLabel) {
        cell.detailTextLabel.textColor = detailTextColor;
    }
    
    [cell setTintColor:[Colors main]];
}

+ (void)updateTabBar:(UITabBar *)tabBar {
    switch (colorTheme) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            [tabBar setBarStyle:UIBarStyleBlack];
            [tabBar setTranslucent:YES];
            [tabBar setTintColor:main];
            if (@available(iOS 13.0, *)) {
                tabBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            }
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            [tabBar setBarStyle:UIBarStyleDefault];
            [tabBar setTintColor:main];
            if (@available(iOS 13.0, *)) {
                tabBar.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
            }
            break;
    }
}

+ (void)updateSearchBar:(UISearchBar *)searchBar {
    [self updateKeyboardAppearanceFor:searchBar];
    
    switch (colorTheme) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            searchBar.barStyle = UIBarStyleBlack;
            [searchBar setTranslucent:YES];
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            searchBar.barStyle = UIBarStyleDefault;
            break;
    }
    
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]] setTitleTextAttributes:@{NSForegroundColorAttributeName: main} forState:UIControlStateNormal];
    
    if (@available(iOS 13.0, *)) {
        
        // Since iOS 13 we can set the textColor directly on the searchbar
        searchBar.searchTextField.textColor = fontNormal;
        
        if ([searchBar respondsToSelector:NSSelectorFromString(@"searchTextField")]) {
            id searchTextField = [searchBar valueForKey:@"searchTextField"];
            if ([searchTextField respondsToSelector:NSSelectorFromString(@"backgroundColor")]) {
                [searchTextField setValue:searchBarStatusBar forKey:@"backgroundColor"];
            }
        }
    }
}

+ (void)updateSwitch:(UISwitch *)switchAppearance {
    [switchAppearance setThumbTintColor:[Colors switchThumb]];
    [switchAppearance setOnTintColor:[Colors main]];
    switch (colorTheme) {
        case ColorThemeDarkWork:
        case ColorThemeDark:
        case ColorThemeLight:
        case ColorThemeLightWork:
            [switchAppearance setOnTintColor:[Colors main]];
            break;
        case ColorThemeUndefined:
            [switchAppearance setOnTintColor:THREEMA_COLOR_GREEN];
            break;
    }
    
}

+ (void)setTextColor:(UIColor *)color inView:(UIView *)parentView {
    for (UIView *view in parentView.subviews) {
        if ([view isKindOfClass:[ContactNameLabel class]]) {
            continue;
        }
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            [label setTextColor:color];
            [label setHighlightedTextColor:color];
        } else if ([view isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)view;
            [textField setTextColor:color];
            [textField colorizeClearButton];
            
            if ([textField placeholder] != nil) {
                UIColor *color = [Colors fontPlaceholder];
                textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:[textField placeholder] attributes:@{NSForegroundColorAttributeName: color}];
            }
        } else if ([view isKindOfClass:[UIScrollView class]] || [view isKindOfClass:[UIStackView class]] || [view isKindOfClass:[UIView class]]) {
            [Colors setTextColor:color inView:view];
        }
    }
}

+ (UIColor *)workBlue {
    return workBlue;
}

+ (UIColor *)main {
    return main;
}

+ (UIColor *)background {
    return background;
}

+ (UIColor *)backgroundBaseColor {
    return backgroundBaseColor;
}

+ (UIColor *)backgroundLight {
    return backgroundLight;
}

+ (UIColor *)backgroundDark {
    return backgroundDark;
}

+ (UIColor *)backgroundSelectedDark {
    return backgroundSelectedDark;
}

+ (UIColor *)backgroundInverted {
    return backgroundInverted;
}

+ (UIColor *)backgroundChat {
    return backgroundChat;
}

+ (UIColor *)chatBackgroundLines {
    return chatBackgroundLines;
}

+ (UIColor *)chatSystemMessageBackground {
    return chatSystemMessageBackground;
}

+ (UIColor *)shareExtensionSelectedBackground {
    return shareExtensionSelectedBackground;
}

+ (UIColor *)fontNormal {
    return fontNormal;
}

+ (UIColor *)fontLight {
    return fontLight;
}

+ (UIColor *)fontVeryLight {
    return fontVeryLight;
}

+ (UIColor *)fontDark {
    return fontDark;
}

+ (UIColor *)fontLink {
    return fontLink;
}

+ (UIColor *)fontLinkReceived {
    return fontLinkReceived;
}

+ (UIColor *)fontPlaceholder {
    return fontPlaceholder;
}

+ (UIColor *)fontInverted {
    return fontInverted;
}

+ (UIColor *)fontQuoteId {
    return fontQuoteId;
}

+ (UIColor *)fontQuoteText {
    return fontQuoteText;
}

+ (UIColor *)chatBarBackground {
    return chatBarBackground;
}

+ (UIColor *)chatBarInput {
    return chatBarInput;
}

+ (UIColor *)chatBarBorder {
    return chatBarBorder;
}

+ (UIColor *)switchThumb {
    return switchThumb;
}

+ (UIColor *)bubbleSent {
    return bubbleSent;
}

+ (UIColor *)bubbleSentSelected {
    return bubbleSentSelected;
}

+ (UIColor *)bubbleReceived {
    return bubbleReceived;
}

+ (UIColor *)bubbleReceivedSelected {
    return bubbleReceivedSelected;
}

+ (UIColor *)bubbleCallButton {
    return bubbleCallButton;
}

+ (UIColor *)popupMenuBackground {
    return popupMenuBackground;
}

+ (UIColor *)popupMenuHighlight {
    return popupMenuHighlight;
}

+ (UIColor *)popupMenuSeparator {
    return popupMenuSeparator;
}

+ (UIColor *)ballotHighestVote {
    return ballotHighestVote;
}

+ (UIColor *)ballotRowLight {
    return ballotRowLight;
}

+ (UIColor *)ballotRowDark {
    return ballotRowDark;
}

+ (UIColor *)hairline {
    return hairline;
}

+ (UIColor *)quoteBar {
    return quoteBar;
}

+ (UIColor *)orange {
    return orange;
}

+ (UIColor *)red {
    return red;
}

+ (UIColor *)green {
    return green;
}

+ (UIColor *)verificationGreen {
    return verificationGreen;
}

+ (UIColor *)gray {
    return gray;
}

+ (UIColor *)searchBarStatusBar {
    return searchBarStatusBar;
}

+ (UIColor *)callStatusBar {
    return callStatusBar;
}

+ (UIColor *)mentionBackground:(int)messageInfo {
    switch (messageInfo) {
        case TextStyleUtilsMessageInfoReceivedMessage:
            return mentionBackgroundColor;
        case TextStyleUtilsMessageInfoOwnMessage:
            return mentionBackgroundOwnMessageColor;
        case TextStyleUtilsMessageInfoOverview:
            return mentionBackgroundOverviewColor;
            
        default:
            return mentionBackgroundColor;
    }
}

+ (UIColor *)mentionBackgroundMe:(int)messageInfo {
    switch (messageInfo) {
        case TextStyleUtilsMessageInfoReceivedMessage:
            return mentionBackgroundMeColor;
        case TextStyleUtilsMessageInfoOwnMessage:
            return mentionBackgroundOwnMessageMeColor;
        case TextStyleUtilsMessageInfoOverview:
            return mentionBackgroundOverviewMeColor;
            
        default:
            return mentionBackgroundMeColor;
    }
}

+ (UIColor *)mentionTextMe:(int)messageInfo {
    switch (messageInfo) {
        case TextStyleUtilsMessageInfoReceivedMessage:
            return mentionTextMeColor;
        case TextStyleUtilsMessageInfoOwnMessage:
            return mentionTextOwnMessageMeColor;
        case TextStyleUtilsMessageInfoOverview:
            return mentionTextOverviewMeColor;
            
        default:
            return mentionTextMeColor;
    }
}

+ (UIColor *)privacyPolicyLink {
    if ([LicenseStore requiresLicenseKey]) {
        return THEME_DARK_WORK_FONT_LINK;
    } else {
        return THEME_DARK_FONT_LINK;
    }
}

+ (UIColor *)mainThemeDark {
    if ([LicenseStore requiresLicenseKey]) {
        return THEME_DARK_WORK_MAIN;
    } else {
        return THEME_DARK_MAIN;
    }
}

+ (UIColor *)backgroundThemeDark {
    return THEME_DARK_BACKGROUND_DARK;
}

+ (UIColor *)markTag {
    return tagMarkBackground;
}

+ (UIColor *)white {
    return [UIColor whiteColor];
}

+ (UIColor *)black {
    return [UIColor blackColor];
}

+ (UIColor *)darkGrey {
    return THREEMA_COLOR_DARK_GREY;
}

+ (UIColor *)notificationBackground {
    return notificationBackground;
}

+ (UIColor *)notificationShadow {
    return notificationShadow;
}

@end
