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
#import <ThreemaFramework/BlobOrigin.h>
#import <ThreemaFramework/UploadProgressDelegate.h>
#import <ThreemaFramework/Old_BlobUploadDelegate.h>
#import <ThreemaFramework/URLSenderItem.h>

@protocol BlobData;
@interface Old_BlobMessageSender : NSObject <Old_BlobUploadDelegate>

/// Type of `BaseMessageEntity<BlobData>` (or `FileMessageEntity`???)
@property NSObject *messageObject;
/// Type of `ConversationEntity`
@property NSObject *conversationObject;
@property NSString *fileNameFromWeb;

@property id<UploadProgressDelegate> uploadProgressDelegate;

- (void)scheduleUpload;

+ (BOOL)hasScheduledUploads;

#pragma mark - abstract methods

/**
 @param item URLSenderItem
 @param conversationObject Object of type `ConversationEntity`
*/
- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject;

- (void)sendMessage:(NSArray *)bolbIds;

- (NSData *)encryptedData;

- (NSData *)encryptedThumbnailData;

- (void)createDBMessage;

- (BOOL)supportsCaption;

@end
