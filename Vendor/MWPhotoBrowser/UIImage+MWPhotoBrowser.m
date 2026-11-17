//
//  UIImage+MWPhotoBrowser.m
//  Pods
//
//  Created by Michael Waterfall on 05/07/2015.
//
//

#import "UIImage+MWPhotoBrowser.h"

@implementation UIImage (MWPhotoBrowser)

+ (UIImage *)imageForResourcePath:(NSString *)path ofType:(NSString *)type inBundle:(NSBundle *)bundle {
    return [UIImage imageWithContentsOfFile:[bundle pathForResource:path ofType:type]];
}

+ (UIImage *)clearImageWithSize:(CGSize)size {
    return [self clearImageWithSize:size traitCollection:[UITraitCollection currentTraitCollection]];
}

+ (UIImage *)clearImageWithSize:(CGSize)size traitCollection:(UITraitCollection *)traitCollection {
    UIGraphicsBeginImageContextWithOptions(size, NO, traitCollection.displayScale);
    UIImage *blank = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return blank;
}

@end
