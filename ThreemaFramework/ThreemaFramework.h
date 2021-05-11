//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import <UIKit/UIKit.h>

// In this header, you should import all the public headers of your framework using statements like #import <ThreemaFramework/PublicHeader.h>

#import <ThreemaFramework/Constants.h>
#import <ThreemaFramework/ProtocolDefines.h>
#import <ThreemaFramework/Colors.h>
#import <ThreemaFramework/MDMSetup.h>
#import <ThreemaFramework/MyIdentityStore.h>
#import <ThreemaFramework/AppGroup.h>
#import <ThreemaFramework/DatabaseManager.h>
#import <ThreemaFramework/Conversation.h>
#import <ThreemaFramework/BaseMessage.h>
#import <ThreemaFramework/AudioMessage.h>
#import <ThreemaFramework/FileMessage.h>
#import <ThreemaFramework/FileMessageSender.h>
#import <ThreemaFramework/MediaConverter.h>
#import <ThreemaFramework/UTIConverter.h>
#import <ThreemaFramework/ImageMessage.h>
#import <ThreemaFramework/VideoMessage.h>
#import <ThreemaFramework/ValidationLogger.h>
#import <ThreemaFramework/ExternalStorageInfo.h>
#import <ThreemaFramework/LogLevelCustom.h>
#import <ThreemaFramework/LogFormatterCustom.h>
#import <ThreemaFramework/FileLoggerCustom.h>
#import <ThreemaFramework/UserSettings.h>
#import <ThreemaFramework/Reachability.h>
#import <ThreemaFramework/FeatureMask.h>
#import <ThreemaFramework/SSLCAHelper.h>


#import <ThreemaFramework/ContactGroupPickerViewController.h>
#import <ThreemaFramework/LicenseStore.h>
#import <ThreemaFramework/KKPasscodeLock.h>
#import <ThreemaFramework/TouchIdAuthentication.h>
#import <ThreemaFramework/ServerConnector.h>
#import <ThreemaFramework/MessageQueue.h>
#import <ThreemaFramework/Utils.h>
#import <ThreemaFramework/BundleUtil.h>
#import <ThreemaFramework/Colors.h>
#import <ThreemaFramework/EntityManager.h>
#import <ThreemaFramework/TextMessage.h>
#import <ThreemaFramework/FileMessageSender.h>
#import <ThreemaFramework/MessageSender.h>
#import <ThreemaFramework/TextStyleUtils.h>
#import <ThreemaFramework/UIImage+ColoredImage.h>
#import <ThreemaFramework/BrandingUtils.h>

#import <ThreemaFramework/JKLLockScreenViewController.h>

#import <ThreemaFramework/FLAnimatedImage.h>
#import <ThreemaFramework/FLAnimatedImageView.h>

//! Project version number for ThreemaFramework.
FOUNDATION_EXPORT double ThreemaFrameworkVersionNumber;

//! Project version string for ThreemaFramework.
FOUNDATION_EXPORT const unsigned char ThreemaFrameworkVersionString[];
