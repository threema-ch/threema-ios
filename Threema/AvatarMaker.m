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

#import "AvatarMaker.h"
#import "Contact.h"
#import "Conversation.h"
#import "EntityManager.h"
#import "ImageData.h"
#import "UIImage+Mask.h"
#import "UserSettings.h"
#import "GatewayAvatarMaker.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"
#import "UIImage+Resize.h"

static AvatarMaker *sharedInstance = nil;

@interface AvatarMaker ()

@property NSCache *avatarCache;
@property NSCache *maskedImageCache;

@end

@implementation AvatarMaker

+ (AvatarMaker*)sharedAvatarMaker {
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        sharedInstance = [[AvatarMaker alloc] init];
    });
    
    return sharedInstance;
}

+ (void)clearCache {
    [sharedInstance.avatarCache removeAllObjects];
}

+ (UIImage *)avatarWithString:(NSString *)string size:(CGFloat)size {
    CGSize canvasSize = CGSizeMake(size, size);
    UIColor *fontColor = [Colors fontLight];
    UIFont *initialsFont = [UIFont fontWithName:@"Helvetica" size:0.4*size];
    
    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(context);
    
    /* Circle */
    CGFloat lineWidth = 0.018f * size;
    CGContextSetLineWidth(context, lineWidth);
    CGContextSetStrokeColorWithColor(context, fontColor.CGColor);
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    
    CGRect circleRect = CGRectMake(0, 0, canvasSize.width, canvasSize.height);
    circleRect = CGRectInset(circleRect, lineWidth/2, lineWidth/2);
    
    CGContextFillEllipseInRect(context, circleRect);
    CGContextStrokeEllipseInRect(context, circleRect);
    
    /* Initials */
    if (string) {
        [fontColor set];
        CGSize textSize = [string sizeWithAttributes:@{NSFontAttributeName: initialsFont}];
        [string drawAtPoint:CGPointMake((canvasSize.width - textSize.width)/2, (canvasSize.height - textSize.height)/2) withAttributes:@{NSFontAttributeName: initialsFont, NSForegroundColorAttributeName: fontColor}];
    }
    UIGraphicsPopContext();
    UIImage *avatar = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return avatar;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        _avatarCache = [[NSCache alloc] init];
        _maskedImageCache = [[NSCache alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectImageChanged:) name:@"ThreemaContactImageChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectImageChanged:) name:@"ThreemaGroupConversationImageChanged" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidReceiveMemoryWarning:(NSNotification*)notification {
    [_avatarCache removeAllObjects];
    [_maskedImageCache removeAllObjects];
}

- (void)clearCacheForProfilePicture {
    [sharedInstance.maskedImageCache removeObjectForKey:@"myProfilePicture"];
    [_maskedImageCache removeAllObjects];
}

- (void)managedObjectImageChanged:(NSNotification*)notification {
    NSManagedObject *managedObject = notification.object;
    [_maskedImageCache removeObjectForKey:managedObject.objectID];
}

- (void)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked onCompletion:(void (^)(UIImage *avatarImage))onCompletion {
    EntityManager *newBackgroundEntityManager = [[EntityManager alloc] initForBackgroundProcess:YES];
    
    [newBackgroundEntityManager performBlock:^{
        Contact *privateContact = [newBackgroundEntityManager.entityFetcher getManagedObjectById:contact.objectID];
        UIImage *avatarImage = [self avatarForContact:privateContact size:size masked:masked];
        onCompletion(avatarImage);
    }];
}

- (UIImage*)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked {
    return [self avatarForContact:contact size:size masked:masked scaled:YES];
}

- (UIImage*)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked scaled:(BOOL)scaled {
    /* If this contact has sent us an image, we'll use that and not make an avatar */
    CGFloat sizeScaled = size;
    if (scaled)
        sizeScaled = sizeScaled * [UIScreen mainScreen].scale;
    if (contact.contactImage != nil && [UserSettings sharedUserSettings].showProfilePictures) {
        if (contact.contactImage.data != nil) {
            UIImage *avatar;
            if (masked) {
                avatar = [self maskedImageForContact:contact ownImage:NO];
            } else {
                avatar = [UIImage imageWithData:contact.contactImage.data];
            }
            if (avatar != nil) {
                return [avatar resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(sizeScaled, sizeScaled) interpolationQuality:kCGInterpolationHigh];
            }
        }
    }
    
    /* If this contact has an image (but not from abRecord), we'll use that and not the received image */
    if (contact.imageData != nil && (contact.cnContactId == nil)) {
        UIImage *avatar;
        if (masked) {
            avatar = [self maskedImageForContact:contact ownImage:YES];
        } else {
            avatar = [UIImage imageWithData:contact.imageData];
        }
        if (avatar != nil) {
            return [avatar resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(sizeScaled, sizeScaled) interpolationQuality:kCGInterpolationHigh];
        }
    }
    
    /* If this contact has an image from abRecord, we'll use that and not a generic icon */
    if (contact.imageData != nil && contact.cnContactId != nil) {
        UIImage *avatar;
        if (masked) {
            avatar = [self maskedImageForContact:contact ownImage:YES];
        } else {
            avatar = [UIImage imageWithData:contact.imageData];
        }
        if (avatar != nil) {
            return [avatar resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(sizeScaled, sizeScaled) interpolationQuality:kCGInterpolationHigh];
        }
    }
    
    if (contact.isGatewayId) {
        UIImage *avatar = [BundleUtil imageNamed:@"Asterisk"];
        avatar = [avatar resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(sizeScaled, sizeScaled) interpolationQuality:kCGInterpolationHigh];
        return [avatar imageWithTint:[Colors fontLight]];
    }
    
    /* If there is no contact, then use a generic icon */
    if (contact == nil) {
        UIImage *avatar = [self unknownPersonImage];
        avatar = [avatar resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(sizeScaled, sizeScaled) interpolationQuality:kCGInterpolationHigh];
        return [avatar imageWithTint:[Colors fontLight]];
    }
    
    NSString *initials = [self initialsForContact:contact];
    
    /* check cache first */
    NSString *cacheKey = [NSString stringWithFormat:@"%@-%.0f", initials, sizeScaled];
    UIImage *cachedImage = [_avatarCache objectForKey:cacheKey];
    if (cachedImage != nil) {
        return cachedImage;
    }
    
    UIImage *avatar = [AvatarMaker avatarWithString:initials size:sizeScaled];
    
    /* Put in cache */
    [_avatarCache setObject:avatar forKey:cacheKey];
    
    return avatar;
}

- (void)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked onCompletion:(void (^)(UIImage *avatarImage))onCompletion {
    EntityManager *newBackgroundEntityManager = [[EntityManager alloc] initForBackgroundProcess:YES];
    
    [newBackgroundEntityManager performBlock:^{
        Conversation *privateConversation = [newBackgroundEntityManager.entityFetcher getManagedObjectById:conversation.objectID];
        UIImage *avatarImage = [self avatarForConversation:privateConversation size:size masked:masked];
        onCompletion(avatarImage);
    }];
}

- (UIImage*)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked {
    return [self avatarForConversation:conversation size:size masked:masked scaled:YES];
}

- (UIImage*)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked scaled:(BOOL)scaled {
    if (conversation.groupId == nil)
        return [self avatarForContact:conversation.contact size:size masked:masked];
    
    /* For groups, use the group image if available, or a default image otherwise */
    if (conversation.groupImage != nil) {
        UIImage *avatar;
        if (masked) {
            avatar = [self maskedImageForGroupConversation:conversation];
        } else {
            avatar = [UIImage imageWithData:conversation.groupImage.data];
        }
        if (scaled)
            size = size * [UIScreen mainScreen].scale;
        return [avatar resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(size, size) interpolationQuality:kCGInterpolationHigh];
    } else {
        UIImage *groupImage = [BundleUtil imageNamed:@"UnknownGroup"];
        if (scaled)
            size = size * [UIScreen mainScreen].scale;
        groupImage = [groupImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(size, size) interpolationQuality:kCGInterpolationHigh];
        return [groupImage imageWithTint:[Colors fontLight]];
    }
}

- (UIImage *)avatarForFirstName:(NSString *)firstName lastName:(NSString *)lastName size:(CGFloat)size {
    CGFloat sizeScaled = size * [UIScreen mainScreen].scale;;
    
    NSString *initials = nil;
    
    if (firstName.length > 0 && lastName.length > 0) {
        if ([UserSettings sharedUserSettings].displayOrderFirstName)
            initials = [NSString stringWithFormat:@"%@%@", [firstName substringToIndex:1], [lastName substringToIndex:1]];
        else
            initials = [NSString stringWithFormat:@"%@%@", [lastName substringToIndex:1], [firstName substringToIndex:1]];
    } else {
        return [self unknownPersonImage];
    }
    
    /* check cache first */
    NSString *cacheKey = [NSString stringWithFormat:@"%@-%.0f", initials, sizeScaled];
    UIImage *cachedImage = [_avatarCache objectForKey:cacheKey];
    if (cachedImage != nil) {
        return cachedImage;
    }
    
    UIImage *avatar = [AvatarMaker avatarWithString:initials size:sizeScaled];
    
    /* Put in cache */
    [_avatarCache setObject:avatar forKey:cacheKey];
    
    return avatar;
}

- (UIImage*)maskedProfilePicture:(UIImage *)image size:(CGFloat)size {
    
    if (image == nil) {
        return [self unknownPersonImage];
    }

    UIImage *maskedImage = [_maskedImageCache objectForKey:@"myProfilePicture"];
    
    if (maskedImage == nil) {
        maskedImage = [AvatarMaker maskImage:image];
        if (maskedImage) {
            [_maskedImageCache setObject:maskedImage forKey:@"myProfilePicture"];
        }
    }
    
    return maskedImage;
}

- (UIImage *)callBackgroundForContact:(Contact *)contact {
    /* If this contact has send us a image, we'll use that and not make an avatar */
    if (contact.contactImage != nil && [UserSettings sharedUserSettings].showProfilePictures) {
        return [UIImage imageWithData:contact.contactImage.data];
    }
    
    /* If this contact has an image (but not from abRecord), we'll use that and not the received image */
    if (contact.imageData != nil && contact.cnContactId == nil) {
        return [UIImage imageWithData:contact.imageData];
    }
    
    /* If this contact has an image from abRecord, we'll use that and not a generic icon */
    if (contact.imageData != nil && contact.cnContactId != nil) {
        return [UIImage imageWithData:contact.imageData];
    }
    
    NSString *initials = [self initialsForContact:contact];
    
    /* check cache first */
    NSString *cacheKey = [NSString stringWithFormat:@"%@-background", initials];
    UIImage *cachedImage = [_avatarCache objectForKey:cacheKey];
    if (cachedImage != nil) {
        return cachedImage;
    }
    
    UIImage *avatar = [AvatarMaker avatarWithString:initials size:[[UIScreen mainScreen] bounds].size.width];
    
    /* Put in cache */
    [_avatarCache setObject:avatar forKey:cacheKey];
    
    return avatar;
}

- (UIImage*)maskedImageForContact:(Contact*)contact ownImage:(BOOL)ownImage {
    if (ownImage) {
        return [self maskedImageForManagedObject:contact imageData:contact.imageData];
    }
    else {
        return [self maskedImageForManagedObject:contact imageData:contact.contactImage.data];
    }
}

- (UIImage*)maskedImageForGroupConversation:(Conversation*)conversation {
    return [self maskedImageForManagedObject:conversation imageData:conversation.groupImage.data];
}

- (UIImage*)maskedImageForManagedObject:(NSManagedObject*)managedObject imageData:(NSData*)imageData {
    if (imageData == nil) {
        return nil;
    }
    
    UIImage *maskedImage = [_maskedImageCache objectForKey:managedObject.objectID];
    
    if (maskedImage == nil) {
        maskedImage = [UIImage imageWithData:imageData];
        maskedImage = [AvatarMaker maskImage:maskedImage];
        if (maskedImage) {
            [_maskedImageCache setObject:maskedImage forKey:managedObject.objectID];
        }
    }
    
    return maskedImage;
}

+ (UIImage *)maskImage:(UIImage *)image {
    UIImage *personMask = [BundleUtil imageNamed:@"PersonMask"];
    UIImage *maskedImage = [image maskWithImage:personMask];
    
    return maskedImage;
}

- (UIImage *)companyImage {
    return [[BundleUtil imageNamed:@"Asterisk"] imageWithTint:[Colors main]];
}

- (UIImage *)unknownPersonImage {
    return [[BundleUtil imageNamed:@"UnknownPerson"] imageWithTint:[Colors fontLight]];
}

- (NSString*)initialsForContact:(Contact*)contact {
    if (contact.firstName.length > 0 && contact.lastName.length > 0) {
        if ([UserSettings sharedUserSettings].displayOrderFirstName)
            return [NSString stringWithFormat:@"%@%@", [contact.firstName substringToIndex:1], [contact.lastName substringToIndex:1]];
        else
            return [NSString stringWithFormat:@"%@%@", [contact.lastName substringToIndex:1], [contact.firstName substringToIndex:1]];
    } else if (contact.displayName.length >= 2) {
        return [contact.displayName substringToIndex:2];
    } else {
        return @"-";
    }
}

- (BOOL)isDefaultAvatarForContact:(Contact *)contact {
    /* If this contact has send us a image, we'll use that and not make an avatar */
    if (contact.contactImage != nil && [UserSettings sharedUserSettings].showProfilePictures) {
        return false;
    }
    
    /* If this contact has an image (but not from abRecord), we'll use that and not the received image */
    if (contact.imageData != nil && contact.cnContactId == nil) {
        return false;
    }
    
    /* If this contact has an image from abRecord, we'll use that and not a generic icon */
    if (contact.imageData != nil && contact.cnContactId != nil) {
        return false;
    }
    
    return true;
}

@end
