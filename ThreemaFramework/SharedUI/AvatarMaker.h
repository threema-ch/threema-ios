//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import <Foundation/Foundation.h>
#import "DatabaseManager.h"

@class Contact, Conversation;

@interface AvatarMaker : NSObject

+ (AvatarMaker* _Nonnull)sharedAvatarMaker;

- (void)clearCacheForProfilePicture;

- (void)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked onCompletion:(void (^)(UIImage *avatarImage, NSString *identity))onCompletion;
- (UIImage*)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked;
- (UIImage*)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked scaled:(BOOL)scaled;
- (UIImage *)initialsAvatarForContact:(nonnull Contact *)contact size:(CGFloat)size masked:(BOOL)masked;

- (void)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked onCompletion:(void (^)(UIImage *avatarImage, NSManagedObjectID *objectID))onCompletion;

- (UIImage* _Nullable)avatarForConversation:(Conversation* _Nonnull)conversation size:(CGFloat)size masked:(BOOL)masked;

- (UIImage* _Nullable)avatarForConversation:(Conversation* _Nonnull)conversation size:(CGFloat)size masked:(BOOL)masked scaled:(BOOL)scaled;

- (UIImage * _Nullable)avatarForFirstName:(NSString * _Nullable)firstName lastName:(NSString * _Nullable)lastName size:(CGFloat)size;

- (UIImage* _Nullable)maskedProfilePicture:(UIImage * _Nonnull)image size:(CGFloat)size;

- (nullable UIImage *)callBackgroundForContact:(nonnull Contact *)contact;

- (UIImage * _Nullable)companyImage;
- (UIImage * _Nullable)unknownPersonImage;
- (UIImage * _Nullable)unknownGroupImage;

- (BOOL)isDefaultAvatarForContact:(Contact * _Nullable)contact;

+ (UIImage *_Nonnull)avatarWithString:(NSString* _Nullable)string size:(CGFloat)size;

+ (UIImage * _Nullable)maskImage:(UIImage* _Nonnull)image;

+ (void)clearCache;

@end
