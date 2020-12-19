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

#import <SDWebImage/UIImageView+WebCache.h>

#import "BrandingUtils.h"
#import "LicenseStore.h"
#import "MyIdentityStore.h"
#import "Colors.h"
#import "UIImage+ColoredImage.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation BrandingUtils

+ (void)updateTitleLogoOfNavigationItem:(UINavigationItem*)navigationItem navigationController:(UINavigationController *)navigationController {
    if ([LicenseStore requiresLicenseKey]) {
        // If the license key includes a logo URL, use it
        NSString *logoUrl = nil;
        switch ([Colors getTheme]) {
            case ColorThemeDark:
            case ColorThemeDarkWork:
                logoUrl = [MyIdentityStore sharedMyIdentityStore].licenseLogoDarkUrl;
                break;
            case ColorThemeLight:
            case ColorThemeLightWork:
            case ColorThemeUndefined:
                logoUrl = [MyIdentityStore sharedMyIdentityStore].licenseLogoLightUrl;
                break;
        }
        
        if (logoUrl != nil) {
            UIImageView *logoView = [[UIImageView alloc] init];
            [logoView sd_setImageWithURL:[[NSURL alloc] initWithString:logoUrl] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                if (error == nil) {
                    [self setupLogoForThreema:false logo:image navigationItem:navigationItem navigationController:navigationController];
                } else {
                    DDLogError(@"Loading logo failed: %@", error);
                }
            }];
        } else {
            // Default work logo
            UIImage *logo;
            switch ([Colors getTheme]) {
                case ColorThemeDark:
                case ColorThemeDarkWork:
                    logo = [UIImage imageNamed:@"ThreemaWorkWhite"];
                    break;
                case ColorThemeLight:
                case ColorThemeLightWork:
                case ColorThemeUndefined:
                    logo = [UIImage imageNamed:@"ThreemaWorkBlack"];
                    
                    break;
            }
            [self setupLogoForThreema:true logo:logo navigationItem:navigationItem navigationController:navigationController];
        }
    } else {
        // Default threema logo
        UIImage *logo;
        switch ([Colors getTheme]) {
            case ColorThemeDark:
            case ColorThemeDarkWork:
                logo = [UIImage imageNamed:@"ThreemaWhite"];
                break;
            case ColorThemeLight:
            case ColorThemeLightWork:
            case ColorThemeUndefined:
                logo = [UIImage imageNamed:@"ThreemaBlack"];
                break;
        }
        [self setupLogoForThreema:true logo:logo navigationItem:navigationItem navigationController:navigationController];
    }
}

+ (void)setupLogoForThreema:(BOOL)threema logo:(UIImage *)logo navigationItem:(UINavigationItem*)navigationItem navigationController:(UINavigationController *)navigationController {
    if (navigationController == nil) {
        return;
    }
    
    UIImageView *logoView = [[UIImageView alloc] initWithImage:logo];
    logoView.contentMode = UIViewContentModeScaleAspectFit;
    CGFloat height = threema == true ? 15.0 : 28.0;
    int y = 0;
    CGFloat navigationBarWidth = navigationController.navigationBar.frame.size.width;
    BOOL correctSize = NO;
    while (correctSize == NO && height > 0) {
        CGFloat totalFreeWidth = navigationBarWidth;
        CGFloat width = height * logo.size.width / logo.size.height;
        
        
        for (UIBarButtonItem *item in navigationItem.leftBarButtonItems) {
            UIView *view = [item valueForKey:@"view"];
            totalFreeWidth -= view.frame.size.width;
        }
        for (UIBarButtonItem *item in navigationItem.rightBarButtonItems) {
            UIView *view = [item valueForKey:@"view"];
            totalFreeWidth -= view.frame.size.width;
        }
        
        logoView.frame = CGRectMake(0, y, width, height);
        
        if (totalFreeWidth - 30.0 > logoView.frame.size.width) {
            correctSize = YES;
        } else {
            height = height - 2;
            y = y + 1;
        }
    }
    
    // Wrap in UIView to keep iOS from messing with the size
    UIView *wrapView = [[UIView alloc] initWithFrame:logoView.frame];
    [wrapView addSubview:logoView];
    wrapView.accessibilityElementsHidden = true;
    // If we're running on the main thread (common if the image is already cached, e.g. when switching tabs),
    // then set the title view immediately; if we dispatch, the user might see the normal title for a brief
    // instance.
    if ([[NSOperationQueue currentQueue] underlyingQueue] != dispatch_get_main_queue()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            navigationItem.titleView = wrapView;
        });
    } else {
        navigationItem.titleView = wrapView;
    }
}

@end
