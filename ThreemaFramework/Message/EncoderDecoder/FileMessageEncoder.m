//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "FileMessageEncoder.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "JsonUtil.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation FileMessageEncoder

+ (BoxFileMessage *)encodeFileMessageEntity:(FileMessageEntity *)message {
    NSData *jsonData = [self jsonDataForMessage:message];
    
    BoxFileMessage *boxMessage = [[BoxFileMessage alloc] init];
    boxMessage.messageId = [AbstractMessage randomMessageId];
    boxMessage.date = [NSDate date];
    boxMessage.jsonData = jsonData;
    
    return boxMessage;

}

+ (GroupFileMessage *)encodeGroupFileMessageEntity:(FileMessageEntity *)message {
    NSData *jsonData = [self jsonDataForMessage:message];
    
    GroupFileMessage *boxMessage = [[GroupFileMessage alloc] init];
    boxMessage.messageId = [AbstractMessage randomMessageId];
    boxMessage.date = [NSDate date];
    boxMessage.jsonData = jsonData;
    
    return boxMessage;
}

+ (NSString *)jsonStringForFileMessageEntity:(FileMessageEntity *)message {
    NSData *jsonData = [self jsonDataForMessage:message];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (NSData *)jsonDataForMessage:(FileMessageEntity *)message {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (message.fileName) {
        [dictionary setObject:message.fileName forKey:JSON_FILE_KEY_FILENAME];
    }
    
    [dictionary setObject:message.fileSize forKey:JSON_FILE_KEY_FILESIZE];
    [dictionary setObject:message.mimeType forKey:JSON_FILE_KEY_MIMETYPE];
    [dictionary setObject:message.type forKey:JSON_FILE_KEY_TYPE];
    [dictionary setObject:[NSNumber numberWithInt:0] forKey:JSON_FILE_KEY_TYPE_DEPRECATED];
    
    if (message.correlationId) {
        [dictionary setObject:message.correlationId forKey:JSON_FILE_KEY_CORRELATION];
    }

    NSString *encryptionKeyHex = [NSString stringWithHexData:message.encryptionKey];
    [dictionary setObject:encryptionKeyHex forKey:JSON_FILE_KEY_ENCRYPTION_KEY];

    if (message.blobId) {
        NSString *blobIdHex = [NSString stringWithHexData:message.blobId];
        [dictionary setObject:blobIdHex forKey:JSON_FILE_KEY_FILE_BLOB];
    }

    if (message.blobThumbnailId) {
        NSString *thumbnailIdHex = [NSString stringWithHexData:message.blobThumbnailId];
        [dictionary setObject:thumbnailIdHex forKey:JSON_FILE_KEY_THUMBNAIL_BLOB];
    }
    
    if (message.caption) {
        [dictionary setObject:message.caption forKey:JSON_FILE_KEY_DESCRIPTION];
    }
    
    NSMutableDictionary *metaDict = [NSMutableDictionary dictionary];
    if ([message.duration intValue] > 0) {
        NSNumber *duration = [[NSNumber alloc] initWithFloat:message.duration.floatValue];
        [metaDict setObject:duration forKey:JSON_FILE_KEY_METADATA_DURATION];
    }
    
    if ([message.height intValue] > 0) {
        [metaDict setObject:message.height forKey:JSON_FILE_KEY_METADATA_HEIGHT];
    }
    
    if ([message.width intValue] > 0) {
        [metaDict setObject:message.width forKey:JSON_FILE_KEY_METADATA_WIDTH];
    }
    
    if ([metaDict count] > 0) {
        [dictionary setObject:metaDict forKey:JSON_FILE_KEY_METADATA];
    }
    
    NSError *error;
    NSData *jsonData = [JsonUtil serializeJsonFrom:dictionary error:error];
    if (jsonData == nil) {
        DDLogError(@"Error encoding json data %@, %@", error, [error userInfo]);
    }
 
    return jsonData;
}

@end
