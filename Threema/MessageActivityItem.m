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

#import "MessageActivityItem.h"
#import "TextMessage.h"
#import "ImageMessage.h"
#import "VideoMessage.h"
#import "AudioMessage.h"
#import "FileMessage.h"
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

- (NSURL *)getNewDataURL {
    if ([_message isKindOfClass:[AudioMessage class]]) {
        return [self audioUrl];
    } else if ([_message isKindOfClass:[ImageMessage class]]) {
        return [self imageUrl];
    } else if ([_message isKindOfClass:[VideoMessage class]]) {
        return [self videoUrl];
    } else if ([_message isKindOfClass:[FileMessage class]]) {
        NSString *filename = [FileUtility getTemporaryFileName];
        return [((FileMessage *)_message) tmpURL:filename];
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

- (NSURL *)exportData {
    if (_url == nil) {
        _url = [self getNewDataURL];
    }
    if (_didExportData) {
        return _url;
    }
    
    _didExportData = YES;
    
    if ([_message isKindOfClass:[AudioMessage class]]) {
        AudioMessage *audioMessage = (AudioMessage*)self.message;
        [audioMessage.audio.data writeToURL:_url atomically:NO];
    } else if ([_message isKindOfClass:[ImageMessage class]]) {
        ImageMessage *imageMessage = (ImageMessage*)self.message;

        // strip image metadata
        UIImage *image = imageMessage.image.uiImage;
        NSData *imageData = UIImageJPEGRepresentation(image, kJPEGCompressionQualityLow);

        [imageData writeToURL:_url atomically:NO];
    } else if ([_message isKindOfClass:[VideoMessage class]]) {
        VideoMessage *videoMessage = (VideoMessage*)self.message;
        [videoMessage.video.data writeToURL:_url atomically:NO];
    } else if ([_message isKindOfClass:[FileMessage class]]) {
        FileMessage *fileMessage = (FileMessage *)self.message;
        [fileMessage exportDataToURL:_url];
    }
    return _url;
}

- (NSURL *)getURL {
    return _url;
}

#pragma mark - UIActivityItemSource

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([_message isKindOfClass:[TextMessage class]]) {
        return ((TextMessage *)_message).text;
    }
    NSURL *exportURL = [self exportData];
    
    if ([_message isKindOfClass:[FileMessage class]] && [activityType isEqualToString:@"ch.threema.iapp.forwardMsg"]) {
        NSNumber *type = ((FileMessage *)_message).type;
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
    if ([_message isKindOfClass:[TextMessage class]]) {
        return ((TextMessage *)_message).text;
    }
    // don't try to return thumbnail image, it won't work

    // some activities only appear in menu if file is exported at this point in time
    // that's ok since files will be deleted after activity controller finishes (ActivityUtil)
    return [self exportData];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType {
    if ([_message isKindOfClass:[TextMessage class]]) {
        return UTTYPE_PLAIN_TEXT;
    } else if ([_message respondsToSelector:@selector(blobGetUTI)]) {
        return [((id<BlobData>)self.message) blobGetUTI];
    }

    return nil;
}

@end
