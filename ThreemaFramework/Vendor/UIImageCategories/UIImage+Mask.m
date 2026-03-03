//
//  UIImage+Mask.m
//  Threema
//
//  Copyright (c) 2013 Threema GmbH. All rights reserved.
//

#import "UIImage+Mask.h"
#import "UIImage+Resize.h"

@implementation UIImage (Mask)

- (UIImage*) maskWithImage:(UIImage *)maskImage {
    if (maskImage == nil) {
        return nil;
    }
    
	CGImageRef maskRef = maskImage.CGImage;
    
    /* scale image to same size as mask */
    CGFloat maskImageRealWidth = roundf(maskImage.size.width * maskImage.scale);
    CGFloat maskImageRealHeight = roundf(maskImage.size.height * maskImage.scale);
    UIImage *scaledImage = [self resizedImageWithContentMode:UIViewContentModeScaleAspectFill
                                 bounds:CGSizeMake(maskImageRealWidth, maskImageRealHeight)
                                 interpolationQuality:kCGInterpolationDefault];
    
	CGImageRef mask = CGImageMaskCreate(CGImageGetWidth(maskRef),
                                        CGImageGetHeight(maskRef),
                                        CGImageGetBitsPerComponent(maskRef),
                                        CGImageGetBitsPerPixel(maskRef),
                                        CGImageGetBytesPerRow(maskRef),
                                        CGImageGetDataProvider(maskRef), NULL, false);
    
    CGImageRef masked;
    if ((scaledImage.size.width != maskImageRealWidth) || (scaledImage.size.height != maskImageRealHeight)) {
        /* must crop */
        CGRect cropRect = CGRectMake(roundf((scaledImage.size.width - maskImageRealWidth) / 2), roundf((scaledImage.size.height - maskImageRealHeight) / 2), maskImageRealWidth, maskImageRealHeight);
        CGImageRef croppedImage = CGImageCreateWithImageInRect([scaledImage CGImage], cropRect);
        masked = CGImageCreateWithMask(croppedImage, mask);
        CGImageRelease(croppedImage);
    } else {
        masked = CGImageCreateWithMask([scaledImage CGImage], mask);
    }
    
    CGImageRelease(mask);
    
    UIImage *maskedImage = [UIImage imageWithCGImage:masked scale:maskImage.scale orientation:UIImageOrientationUp];
    
    CGImageRelease(masked);
    
	return maskedImage;
}

@end
