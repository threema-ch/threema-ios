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

#import <CommonCrypto/CommonCrypto.h>
#import <sys/utsname.h>
#import "NSString+Hex.h"
#import <CoreLocation/CoreLocation.h>
#import <time.h>
#import <sys/sysctl.h>
#import "UserSettings.h"
#import "BundleUtil.h"
#import "LicenseStore.h"
#import <UserNotifications/UserNotifications.h>
#import "ThreemaFramework/ThreemaFramework-swift.h"
#import "UIImage+ColoredImage.h"
#import "AppGroup.h"
#import "ThreemaUtilityObjC.h"

#define OVERLAY_DIAMETER 80.0

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation ThreemaUtilityObjC

+ (unsigned)unitFlags {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
#pragma clang diagnostic pop
}

+ (void)reverseGeocodeNearLatitude:(double)latitude longitude:(double)longitude accuracy:(double)accuracy completion:(void (^)(NSString *label))completion onError:(void(^)(NSError *error))onError {
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:0 horizontalAccuracy:accuracy verticalAccuracy:-1 timestamp:[NSDate date]];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (placemarks == nil) {
            DDLogWarn(@"Reverse geocode failed: %@", error);
            onError(error);
            return;
        }
        
        CLPlacemark *placemark = [placemarks objectAtIndex:0];
        NSString *label;
        
        NSArray *addressLines = [placemark.addressDictionary objectForKey:@"FormattedAddressLines"];
        if (addressLines == nil) {
            label = placemark.name;
        } else {
            label = [addressLines componentsJoinedByString:@", "];
        }
        completion(label);
    }];
}

+ (time_t)systemUptime {
    struct timeval boottime;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    time_t now;
    time_t uptime = -1;
    
    (void)time(&now);
    
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0) {
        uptime = now - boottime.tv_sec;
    }
    return uptime;
}

// Use `ThreemaUtility.timeString() instead`
+ (NSString *)timeStringForSeconds: (NSInteger) totalSeconds {
    NSInteger minutes = totalSeconds / 60;
    NSInteger seconds = totalSeconds % 60;
    
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

+ (NSString *)accessibilityTimeStringForSeconds: (NSInteger) totalSeconds {    
    NSDateComponentsFormatter* formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.collapsesLargestUnit = YES;
    formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    
    return [formatter stringFromTimeInterval:totalSeconds];
}

+ (NSString *)accessibilityStringAtTime:(NSTimeInterval)timeInterval withPrefix:(NSString *)prefixKey {
    NSString *accessibilityTime = [self accessibilityTimeStringForSeconds:timeInterval];
    NSString *at = [BundleUtil localizedStringForKey:prefixKey];
    
    return [NSString stringWithFormat:@"%@ %@", at, accessibilityTime];
}

+ (NSDate*)parseISO8601DateString:(NSString*)dateString {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"YYYY-MM-dd'T'HH:mm:ssZZZ";
    return [dateFormatter dateFromString:dateString];
}

+ (NSString *)formatDataLength:(CGFloat)numBytes {
    if (numBytes > 256.0 * 1024.0) {
        return [NSString stringWithFormat:@"%.1f MB", numBytes / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f kB", numBytes / 1024.0];
    }
}

+ (BOOL)isValidEmail:(NSString *)email {
    // most basic verification: contains @ and .
    if (email.length < 2) {
        return NO;
    }
    
    NSString *regExPattern = @"^.+@.+\\..+$";
    NSRegularExpression *regEx = [[NSRegularExpression alloc] initWithPattern:regExPattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSUInteger regExMatches = [regEx numberOfMatchesInString:email options:0 range:NSMakeRange(0, [email length])];
    return regExMatches == 1;
}

+ (UIViewAnimationOptions)animationOptionsFor:(NSNotification *)notification animationDuration:(NSTimeInterval*)animationDuration {
    NSNumber *durationValue = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
    *animationDuration = durationValue.doubleValue;
    
    NSNumber *curveValue = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve animationCurve = curveValue.intValue;
    
    return (animationCurve << 16 | UIViewAnimationOptionBeginFromCurrentState);
}

+ (UIImage *)makeThumbWithOverlayFor:(UIImage *)image {
    UIGraphicsBeginImageContext(image.size);
    
    [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    
    UIImage *playOverlayImage = [[UIImage systemImageNamed:@"play.circle.fill"] applyingWithSymbolWeight:UIImageSymbolWeightSemibold symbolScale:UIImageSymbolScaleLarge paletteColors:@[[UIColor whiteColor]]];
    CGSize playImageSize = CGSizeMake(OVERLAY_DIAMETER,OVERLAY_DIAMETER);
    CGFloat x = (image.size.width - playImageSize.width)/2.0;
    CGFloat y = (image.size.height - playImageSize.height)/2.0;
    [playOverlayImage drawInRect:CGRectMake(x, y, playImageSize.width, playImageSize.height) blendMode:kCGBlendModeNormal alpha:0.8];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return resultImage;
}

+ (NSData*)truncatedUTF8String:(NSString*)str maxLength:(NSUInteger)maxLength {
    /* Keep removing characters at the end until the encoded length is less than
	   or equal to the desired maximum length. This avoids producing invalid UTF-8 encoded strings
       which are possible if the encoded byte array is truncated, potentially in the middle of
	   an encoded multi-byte character.
     */
    NSString *curString = str;
    NSData *data = [curString dataUsingEncoding:NSUTF8StringEncoding];
    while (data.length > maxLength) {
        /* Note: some characters (e.g. Emojis) don't fit in UTF-16, which is what NSString deals with,
           so we need to correctly determine the offset to cut off and can't simply remove the last "character". */
        NSUInteger lastCharIndex = curString.length - 1;
        NSRange rangeOfLastChar = [curString rangeOfComposedCharacterSequenceAtIndex:lastCharIndex];
        curString = [curString substringToIndex:rangeOfLastChar.location];
        data = [curString dataUsingEncoding:NSUTF8StringEncoding];
    }
    return data;
}

+ (BOOL)hideThreemaTypeIconForContact:(ContactEntity *)contact {
    // Always hide if there is no contact (e.g. it's a group)
    if (!contact) {
        return YES;
    }
    
    if (contact.isEchoEcho || contact.isGatewayId || [LicenseStore isOnPrem]) {
        return YES;
    }
    
    if ([LicenseStore requiresLicenseKey]) {
        return [[UserSettings sharedUserSettings].workIdentities containsObject:contact.identity];
    } else {
        return ![[UserSettings sharedUserSettings].workIdentities containsObject:contact.identity];
    }
}

+ (UIImage *)threemaTypeIcon {
    if ([LicenseStore requiresLicenseKey]) {
        return [StyleKit houseIcon];
    } else {
        return [StyleKit workIcon];
    }
}

+ (void)sendErrorLocalNotification:(NSString *)title body:(NSString *)body userInfo:(NSDictionary *)userInfo {
    [self sendErrorLocalNotification:title body:body userInfo:userInfo onCompletion:nil];
}

+ (void)sendErrorLocalNotification:(NSString *)title body:(NSString *)body userInfo:(NSDictionary *)userInfo onCompletion:(void(^)(void))onCompletion {
    UNMutableNotificationContent *notification = [[UNMutableNotificationContent alloc] init];
    notification.title = title;
    notification.body = body;
    notification.badge = @1;
    if (userInfo != nil) {
        notification.userInfo = userInfo;
    } else {
        notification.userInfo = @{@"threema": @{@"cmd": @"error"}};
    }
    if (![[UserSettings sharedUserSettings].pushGroupSound isEqualToString:@"none"]) {
        notification.sound = [UNNotificationSound soundNamed:[NSString stringWithFormat:@"%@.caf", [UserSettings sharedUserSettings].pushGroupSound]];
    }
    NSString *notificationIdentifier = @"ErrorMessage";
    UNNotificationRequest *notificationRequest = [UNNotificationRequest requestWithIdentifier:notificationIdentifier content:notification trigger:nil];
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:notificationRequest withCompletionHandler:^(NSError * _Nullable error) {
        if (onCompletion != nil) {
            onCompletion();
        }
    }];
}

+ (void)waitForSeconds:(int)count finish:(void(^)(void))finish {
    if (count > 0 && [AppGroup getActiveType] == AppGroupTypeApp) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self waitForSeconds:count-1 finish:finish];
        });
    } else {
        finish();
    }
}

@end
