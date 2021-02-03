//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#ifndef Threema_UIDefines_h
#define Threema_UIDefines_h

#define kContactsTabBarIndex 0
#define kChatTabBarIndex 1
#define kMyIdentityTabBarIndex 2
#define kSettingsTabBarIndex 3

#define kDefaultInitialTabIndex kChatTabBarIndex

#define kMinimumPasswordLength 8

#define kExportConversationMediaSizeLimit 300  /* MB */

#define kMaxMediaSendAtOnce 5

#define kContactImageSize 512

#define THREEMA_COLOR_PLACEHOLDER [UIColor lightGrayColor]
#define THREEMA_COLOR_LIGHT_GREY [UIColor colorWithRed:153.0/256.0 green:153.0/256.0 blue:153.0/256.0 alpha:1.0]
#define THREEMA_COLOR_GREEN [UIColor colorWithRed:63.0/256.0 green:230.0/256.0 blue:105.0/256.0 alpha:1.0]

#if __LP64__
#define is64Bit (int) 1
#else
#define is64Bit (int) 0
#endif


#endif
