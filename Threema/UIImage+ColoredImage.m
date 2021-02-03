//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "UIImage+ColoredImage.h"

@implementation UIImage (ColoredImage)

static CGFloat scale = -1.0;
static NSCache *imageCache = nil;

+ (UIImage *) imageNamed:(NSString *)name inColor: (UIColor *) color
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@/%@", name, color];
    
    // Check cache first
    UIImage *image;
    if (imageCache != nil) {
        image = [imageCache objectForKey:cacheKey];
        if (image != nil) {
            return image;
        }
    }
    
    image = [[UIImage imageNamed:name] imageWithTint: color];
    
    // Put in cache
    if (imageCache == nil) {
        imageCache = [[NSCache alloc] init];
        imageCache.name = @"ColoredImage cache";
    }
    [imageCache setObject:image forKey:cacheKey];
    
    return image;
}

- (UIImage *) imageWithTint:(UIColor *)tintColor {
    if (@available(iOS 13.0, *)) {
        return [self imageWithTintColor:tintColor];
    }
    
    return [self drawImageWithTintColor:tintColor];
}

// Only use this function before iOS 13 or for non icon images
- (UIImage *)drawImageWithTintColor:(UIColor *)tintColor {
    if (scale<0.0) {
        UIScreen *screen = [UIScreen mainScreen];
        scale = [screen scale];
    }
    
    CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
    
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, self.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextDrawImage(context, rect, self.CGImage);
    
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [tintColor setFill];
    CGContextFillRect(context, rect);
    
    UIImage *coloredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return coloredImage;
}

- (UIImage *) invertedImage {
    CIImage *img = [CIImage imageWithCGImage:self.CGImage];

    CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
    [filter setDefaults];
    [filter setValue:img forKey:@"inputImage"];

    CIContext *context = [[CIContext alloc] init];
    CGImageRef ref = [context createCGImage:filter.outputImage fromRect:filter.outputImage.extent];

    return [UIImage imageWithCGImage:ref];

}

@end
