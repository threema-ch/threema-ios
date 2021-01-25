//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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

@class Contact, Conversation;

@interface AvatarMaker : NSObject

+ (AvatarMaker*)sharedAvatarMaker;

- (void)clearCacheForProfilePicture;

- (void)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked onCompletion:(void (^)(UIImage *avatarImage))onCompletion;
- (UIImage*)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked;
- (UIImage*)avatarForContact:(Contact*)contact size:(CGFloat)size masked:(BOOL)masked scaled:(BOOL)scaled;

- (void)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked onCompletion:(void (^)(UIImage *avatarImage))onCompletion;
- (UIImage*)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked;
- (UIImage*)avatarForConversation:(Conversation*)conversation size:(CGFloat)size masked:(BOOL)masked scaled:(BOOL)scaled;

- (UIImage *)avatarForFirstName:(NSString *)firstName lastName:(NSString *)lastName size:(CGFloat)size;

- (UIImage*)maskedProfilePicture:(UIImage *)image size:(CGFloat)size;
- (nullable UIImage *)callBackgroundForContact:(nonnull Contact *)contact;

- (UIImage *)companyImage;
- (UIImage *)unknownPersonImage;

- (BOOL)isDefaultAvatarForContact:(Contact *)contact;

+ (UIImage *)avatarWithString:(NSString *)string size:(CGFloat)size;

+ (UIImage *)maskImage:(UIImage *)image;

+ (void)clearCache;

@end
