//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

typedef enum UploadError {
    UploadErrorSendFailed,
    UploadErrorFileTooBig,
    UploadErrorInvalidFile,
    UploadErrorCancelled
} UploadError;

@class Old_BlobMessageSender;

@protocol UploadProgressDelegate <NSObject>

- (BOOL)blobMessageSenderUploadShouldCancel:(nonnull Old_BlobMessageSender *)blobMessageSender;

/**
 @param blobMessageSender Old_BlobMessageSender
 @param progress NSNumber
 @param messageObject Object of type `BaseMessageEntity`
 */
- (void)blobMessageSender:(nonnull Old_BlobMessageSender *)blobMessageSender uploadProgress:(nonnull NSNumber *)progress forMessage:(nonnull NSObject *)messageObject;

/**
 @param blobMessageSender Old_BlobMessageSender
 @param messageObject Object of type `BaseMessageEntity`
 @param error UploadError
 */
- (void)blobMessageSender:(nonnull Old_BlobMessageSender *)blobMessageSender uploadFailedForMessage:(nullable NSObject *)messageObject error:(UploadError)error;

/**
 @param blobMessageSender Old_BlobMessageSender
 @param messageObject Object of type `BaseMessageEntity`
 */
- (void)blobMessageSender:(nonnull Old_BlobMessageSender *)blobMessageSender uploadSucceededForMessage:(nonnull NSObject *)messageObject;

@end
