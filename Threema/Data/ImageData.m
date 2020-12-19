//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "ImageData.h"
#import <ImageIO/ImageIO.h>

@implementation ImageData

@dynamic height;
@dynamic width;
@dynamic data;

- (UIImage*)uiImage {
    return [UIImage imageWithData:self.data];
}

- (NSString *)getCaption {
    if (self.data)
        return [ImageData getCaptionForImageData:self.data];
    
    return nil;
}

- (void)setCaption:(NSString *)caption {
    self.data = [ImageData addCaption:caption toImageData:self.data];
}

- (NSDictionary *)getMetadata {
    CGImageSourceRef  source = CGImageSourceCreateWithData((CFDataRef)self.data, NULL);
    if (source == NULL)
        return nil;
    NSDictionary *metadata = (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    CFRelease(source);

    return metadata;
}

+ (NSString *)getCaptionForImageData:(NSData *)imageData {
    CGImageSourceRef  source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    if (source == NULL)
        return nil;
    NSDictionary *metadata = (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    CFRelease(source);
    
    NSMutableDictionary *tiffData = [metadata objectForKey:(NSString *)kCGImagePropertyTIFFDictionary];
    
    NSString *author = [tiffData objectForKey:(NSString *)kCGImagePropertyTIFFArtist];
    return author;
}

+ (NSData *)addCaption:(NSString *)caption toImageData:(NSData *)imageData {
    CGImageSourceRef  source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    if (source == NULL)
        return imageData;
    NSDictionary *metadata = (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    
    CFStringRef uti = CGImageSourceGetType(source);
    NSMutableDictionary *metadataMutable = [metadata mutableCopy];
    NSMutableDictionary *tiffDataMutable = [metadataMutable objectForKey:(NSString *)kCGImagePropertyTIFFDictionary];
    
    if (caption)
        [tiffDataMutable setObject:caption forKey:(NSString *)kCGImagePropertyTIFFArtist];
    else
        [tiffDataMutable removeObjectForKey:(NSString *)kCGImagePropertyTIFFArtist];
    
    NSMutableData *newData = [NSMutableData data];
    CGImageDestinationRef newImageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)newData, uti, 1, NULL);
    if (!newImageDestination) {
        CFRelease(source);
        return imageData;
    }
    
    CGImageDestinationAddImageFromSource(newImageDestination, source, 0, (__bridge CFDictionaryRef) metadataMutable);
    BOOL success = CGImageDestinationFinalize(newImageDestination);
    
    CFRelease(newImageDestination);
    CFRelease(source);
    
    if (success) {
        return newData;
    }
    
    return imageData;
}

@end
