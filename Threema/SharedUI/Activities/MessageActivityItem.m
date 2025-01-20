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

#import "MessageActivityItem.h"
#import "UTIConverter.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface MessageActivityItem ()

@property BaseMessage *message;
@property NSURL *url;
@property BOOL didExportData;

@end

@implementation MessageActivityItem

+ (instancetype)activityItemFor:(BaseMessage *)message {
    return [[MessageActivityItem alloc] initWith: message];
}

- (instancetype)initWith:(BaseMessage *)message
{
    self = [super init];
    if (self) {
        self.message = message;
        self.didExportData = NO;
    }
    
    return self;
}

- (nullable NSURL *)getNewDataURL {
    if ([_message isKindOfClass:[AudioMessageEntity class]]) {
        return [self audioUrl];
    } else if ([_message isKindOfClass:[ImageMessageEntity class]]) {
        return [self imageUrl];
    } else if ([_message isKindOfClass:[VideoMessageEntity class]]) {
        return [self videoUrl];
    } else if ([_message isKindOfClass:[FileMessageEntity class]]) {
        NSString *filename = [[FileUtility shared] getTemporaryFileName];
        return [((FileMessageEntity *)_message) tempFileURLWithFallBackFileName:filename];
    }

    return nil;
}

- (NSURL *)tmpShareDirUrl {
    NSURL *tmpDirUrl = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [tmpDirUrl URLByAppendingPathComponent:SHARE_FILE_PREFIX];
}

- (NSURL *)audioUrl {
    return [[self tmpShareDirUrl] URLByAppendingPathExtension: MEDIA_EXTENSION_AUDIO];
}

- (NSURL *)imageUrl {
    return [[self tmpShareDirUrl] URLByAppendingPathExtension:MEDIA_EXTENSION_IMAGE];
}

- (NSURL *)videoUrl {
    return [[self tmpShareDirUrl] URLByAppendingPathExtension: MEDIA_EXTENSION_VIDEO];
}

- (nullable NSURL *)exportData {
    if (_url == nil) {
        _url = [self getNewDataURL];
    }
    
    if (_url == nil) {
        DDLogError(@"Unable to create export URL");
        return nil;
    }
    
    if (_didExportData) {
        return _url;
    }
    
    _didExportData = YES;
    
    if ([_message isKindOfClass:[AudioMessageEntity class]]) {
        AudioMessageEntity *audioMessageEntity = (AudioMessageEntity*)self.message;
        [audioMessageEntity.audio.data writeToURL:_url atomically:NO];
    } else if ([_message isKindOfClass:[ImageMessageEntity class]]) {
        ImageMessageEntity *imageMessageEntity = (ImageMessageEntity*)self.message;

        // strip image metadata
        UIImage *image = imageMessageEntity.image.uiImage;
        if (image == nil) {
            DDLogError(@"No image to export");
            return nil;
        }
        NSData *imageData = UIImageJPEGRepresentation(image, kJPEGCompressionQualityLow);

        [imageData writeToURL:_url atomically:NO];
    } else if ([_message isKindOfClass:[VideoMessageEntity class]]) {
        VideoMessageEntity *videoMessageEntity = (VideoMessageEntity*)self.message;
        [videoMessageEntity.video.data writeToURL:_url atomically:NO];
    } else if ([_message isKindOfClass:[FileMessageEntity class]]) {
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.message;
        [fileMessageEntity exportDataTo:_url];
    }
    return _url;
}

- (nullable NSURL *)getURL {
    return _url;
}

#pragma mark - UIActivityItemSource

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([_message isKindOfClass:[TextMessageEntity class]]) {
        return ((TextMessageEntity *)_message).text;
    }
    NSURL *exportURL = [self exportData];
    
    if ([_message isKindOfClass:[FileMessageEntity class]] && [activityType isEqualToString:@"ch.threema.iapp.forwardMsg"]) {
        NSNumber *type = ((FileMessageEntity *)_message).type;
        if (type == nil) {
            type = @0;
        }
        return @{@"url": exportURL, @"renderType": type};
    } else {
        return exportURL;
    }

    // unsupported message type
    DDLogError(@"MessageActivityItem: unsupported message type");
    return nil;
}

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
    if ([_message isKindOfClass:[TextMessageEntity class]]) {
        return ((TextMessageEntity *)_message).text;
    }
    // don't try to return thumbnail image, it won't work

    // some activities only appear in menu if file is exported at this point in time
    // that's ok since files will be deleted after activity controller finishes (ActivityUtil)
    return [self exportData];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType {
    if ([_message isKindOfClass:[TextMessageEntity class]]) {
        return UTTYPE_PLAIN_TEXT;
    } else if ([_message respondsToSelector:@selector(blobUTTypeIdentifier)]) {
        return ((id<BlobData>)self.message).blobUTTypeIdentifier;
    }

    return nil;
}

@end
