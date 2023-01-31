//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2023 Threema GmbH
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
#import "Old_BlobUploadDelegate.h"
#import "AbstractMessage.h"

@class Conversation, Contact;

@interface ContactPhotoSender : NSObject <Old_BlobUploadDelegate>

NS_ASSUME_NONNULL_BEGIN

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(nonnull NSObject *)entityManagerObject;

+ (void)sendProfilePictureRequest:(NSString *)toIdentity;

/**
 Send my profile picture to the sender of the given received message if necessary.

 @param message: Sender of message is receiver of profile picture
 */
- (void)sendProfilePicture:(AbstractMessage *)message NS_SWIFT_NAME(sendProfilePicture(message:));

- (void)startWithImageToMember:(Contact*)toMember onCompletion:(void (^ _Nullable)(void))onCompletion onError:(void (^ _Nullable) ( NSError * _Nullable ))onError;

NS_ASSUME_NONNULL_END

@end
