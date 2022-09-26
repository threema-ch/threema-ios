//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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
#import <CoreData/CoreData.h>

#import "TMAManagedObject.h"
#import "ExternalStorageInfo.h"

@interface ImageData : TMAManagedObject <ExternalStorageInfo>

@property (nonatomic, retain, nonnull) NSNumber * height;
@property (nonatomic, retain, nonnull) NSNumber * width;
@property (nonatomic, retain, nullable) NSData * data;

@property (nonatomic, readonly, nullable) UIImage *uiImage;

#pragma mark - custom methods

- (nullable NSString *)getCaption;

- (void)setCaption:(nonnull NSString *) caption;

- (nullable NSDictionary *)getMetadata;

+ (nullable NSString *)getCaptionForImageData:(nonnull NSData *)imageData;
+ (nullable NSData *)addCaption:(nonnull NSString *)caption toImageData:(nonnull NSData *)imageData;

@end
