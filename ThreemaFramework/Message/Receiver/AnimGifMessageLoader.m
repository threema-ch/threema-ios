//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import "AnimGifMessageLoader.h"
#import "EntityCreator.h"
#import "FLAnimatedImage.h"
#import "MediaConverter.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation AnimGifMessageLoader

- (void)updateDBObject:(BaseMessage<BlobData> *)message with:(NSData *)data {
    if (![message isKindOfClass:FileMessageEntity.class]) {
        return;
    }

    [super updateDBObject:message with:data];

    FLAnimatedImage *animImage = [FLAnimatedImage animatedImageWithGIFData:data];

    UIImage *thumbnail = [MediaConverter getThumbnailForImage:animImage.posterImage];
    if (thumbnail) {
        NSData *thumbnailData = UIImageJPEGRepresentation(thumbnail, kJPEGCompressionQualityLow);
        if (thumbnailData) {
            ImageData *dbThumbnail = [self.entityManager.entityCreator imageData];
            dbThumbnail.data = thumbnailData;
            dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];

            ((FileMessageEntity *)message).thumbnail = dbThumbnail;
        }
    }
}

@end
