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

#import <Foundation/Foundation.h>

@class UITextInputTraits;

typedef enum : NSUInteger {
    ColorThemeUndefined,
    ColorThemeLight,
    ColorThemeDark,
    ColorThemeDarkWork,
    ColorThemeLightWork
} ColorTheme;


@interface Colors : NSObject

+ (void)setTheme:(ColorTheme)newTheme;

+ (ColorTheme)getTheme;

+ (BOOL)areCustomized;

+ (void)resetToDefault;

+ (void)updateKeyboardAppearanceFor:(id<UITextInputTraits>)textInputTraits;

+ (void)updateWindow:(UIWindow *)window;

+ (void)updateNavigationBar:(UINavigationBar *)navigationBar;

+ (void)updateTabBar:(UITabBar *)tabBar;

+ (void)updateSearchBar:(UISearchBar *)searchBar;

+ (void)updateTableView:(UITableView *)tableView;

+ (void)updateTableViewCellBackground:(UITableViewCell *)cell;

+ (void)updateTableViewCell:(UITableViewCell *)cell;

+ (void)setTextColor:(UIColor *)color inView:(UIView *)parentView;

+ (UIColor *)workBlue;

+ (UIColor *)main;

+ (UIColor *)background;

+ (UIColor *)backgroundBaseColor;

+ (UIColor *)backgroundLight;

+ (UIColor *)backgroundDark;

+ (UIColor *)backgroundSelectedDark;

+ (UIColor *)backgroundInverted;

+ (UIColor *)backgroundChat;

+ (UIColor *)chatBackgroundLines;

+ (UIColor *)chatSystemMessageBackground;

+ (UIColor *)shareExtensionSelectedBackground;

+ (UIColor *)fontNormal;

+ (UIColor *)fontLight;

+ (UIColor *)fontVeryLight;

+ (UIColor *)fontDark;

+ (UIColor *)fontLink;

+ (UIColor *)fontLinkReceived;

+ (UIColor *)fontPlaceholder;

+ (UIColor *)fontInverted;

+ (UIColor *)fontQuoteId;

+ (UIColor *)fontQuoteText;

+ (UIColor *)chatBarBackground;

+ (UIColor *)chatBarInput;

+ (UIColor *)chatBarBorder;

+ (UIColor *)switchThumb;

+ (UIColor *)bubbleSent;

+ (UIColor *)bubbleSentSelected;

+ (UIColor *)bubbleReceived;

+ (UIColor *)bubbleReceivedSelected;

+ (UIColor *)bubbleCallButton;

+ (UIColor *)popupMenuBackground;

+ (UIColor *)popupMenuHighlight;

+ (UIColor *)popupMenuSeparator;

+ (UIColor *)ballotHighestVote;

+ (UIColor *)ballotRowLight;

+ (UIColor *)ballotRowDark;

+ (UIColor *)hairline;

+ (UIColor *)quoteBar;

+ (UIColor *)orange;

+ (UIColor *)red;

+ (UIColor *)green;

+ (UIColor *)verificationGreen;

+ (UIColor *)gray;

+ (UIColor *)searchBarStatusBar;

+ (UIColor *)callStatusBar;

+ (UIColor *)mentionBackground:(int)messageInfo;

+ (UIColor *)mentionBackgroundMe:(int)messageInfo;

+ (UIColor *)mentionTextMe:(int)messageInfo;

+ (UIColor *)privacyPolicyLink;

+ (UIColor *)mainThemeDark;

+ (UIColor *)backgroundThemeDark;

+ (UIColor *)markTag;

+ (UIColor *)white;

+ (UIColor *)black;

+ (UIColor *)darkGrey;

+ (UIColor *)notificationBackground;

+ (UIColor *)notificationShadow;

@end
