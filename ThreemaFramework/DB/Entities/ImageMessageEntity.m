//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "ImageMessageEntity.h"
#import "NSString+Hex.h"
#import "UTIConverter.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation ImageMessageEntity

@dynamic encryptionKey;
@dynamic imageBlobId;
@dynamic imageNonce;
@dynamic imageSize;
@dynamic progress;

@dynamic image;
@dynamic thumbnail;


- (NSString*)logText {
    if ([self.image getCaption] != nil) {
        return [NSString stringWithFormat:@"%@ (%@) %@ %@", [BundleUtil localizedStringForKey:@"image"], [self blobFilename], [BundleUtil localizedStringForKey:@"caption"], [self.image getCaption]];
    }
    return [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"image"], [self blobFilename]];
}

- (NSString*)previewText {
    return [BundleUtil localizedStringForKey:@"image"];
}

- (NSString *)quotePreviewText {
    NSString *caption = nil;
    if (self.image != nil) {
        caption = [self.image getCaption];
        if (caption != nil) {
            NSString *quotePreviewString = [[caption componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
            caption = [quotePreviewString substringWithRange:NSMakeRange(0, MIN(caption.length, 200))];
        }
    }

    if (caption == nil || caption.length == 0) {
        caption = self.previewText;
    }
    return caption;
}

#pragma mark - Misc

#ifdef DEBUG
#else
- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", [self class], self, @"image =", self.image.description, @"thumbnail =", self.thumbnail.description, @"imageBlobId =", @"***", @"imageNonce =", @"***", @"imageSize =", self.imageSize.description, @"progress =", self.progress.description, @"encryptionKey =", self.encryptionKey.description];
}
#endif

@end
