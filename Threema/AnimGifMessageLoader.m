//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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
#import "EntityManager.h"
#import "FLAnimatedImage.h"
#import "MediaConverter.h"

@implementation AnimGifMessageLoader

- (void)updateDBObjectWithData:(NSData *)data onCompletion:(void(^)(void))onCompletion {
    [super updateDBObjectWithData:data onCompletion:^{
        FLAnimatedImage *animImage = [FLAnimatedImage animatedImageWithGIFData:data];
        
        UIImage *thumbnail = [MediaConverter getThumbnailForImage:animImage.posterImage];
        
        NSData *thumbnailData = UIImageJPEGRepresentation(thumbnail, kJPEGCompressionQuality);
        
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            if (thumbnailData) {
                ImageData *dbThumbnail = [entityManager.entityCreator imageData];
                dbThumbnail.data = thumbnailData;
                dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
                dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
                
                FileMessage *fileMessage = (FileMessage *)self.message;
                fileMessage.thumbnail = dbThumbnail;
            }
        }];
        onCompletion();
    }];
}

@end
