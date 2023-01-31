//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2023 Threema GmbH
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

@class Conversation, Contact;

NS_ASSUME_NONNULL_BEGIN

@protocol GroupPhotoSenderProtocol <NSObject>

- (void)startWithImageData:(nullable NSData *)imageData isNoteGroup:(BOOL)isNoteGrp onCompletion:(void (^)(NSData * _Nullable blobId, NSData * _Nullable encryptionKey))onCompletion onError:(void (^)(NSError *))onError;

@end

@interface GroupPhotoSender : NSObject <GroupPhotoSenderProtocol, Old_BlobUploadDelegate>

@end

NS_ASSUME_NONNULL_END
