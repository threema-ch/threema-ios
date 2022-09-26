//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

NS_ASSUME_NONNULL_BEGIN

@protocol BlobData <NSObject>

- (BOOL)blobIsOutgoing;

- (nullable NSData *)blobGetData;

- (nullable NSData *)blobGetThumbnail;

- (nullable NSString *)blobGetFilename;

- (nullable NSString *)blobGetUTI;

- (nullable NSData *)blobGetId NS_SWIFT_NAME(blobGetID());

- (nullable NSData *)blobGetThumbnailId NS_SWIFT_NAME(blobGetThumbnailID());

- (nullable NSNumber *)blobGetSize;

- (nullable NSData *)blobGetEncryptionKey;

- (void)blobSetData:(NSData *)data;

- (void)blobUpdateProgress:(nullable NSNumber *)progress;

- (nullable NSNumber *)blobGetProgress;

- (void)blobSetError:(BOOL)error;

- (BOOL)blobGetError;

- (NSString *)blobGetWebFilename;

- (nullable NSString *)getExternalFilename;

@optional
- (nullable NSString *)getExternalFilenameThumbnail;

@end

NS_ASSUME_NONNULL_END
