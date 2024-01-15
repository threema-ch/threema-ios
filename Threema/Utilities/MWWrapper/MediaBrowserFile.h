//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2024 Threema GmbH
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

#import "MWPhoto.h"
#import "FileMessageEntity.h"

@class MediaBrowserFile;

@protocol MWFileDelegate

-(void)showFile:(FileMessageEntity *)fileMessageEntity;
-(void)playFileVideo:(FileMessageEntity *)fileMessageEntity;
-(void)toggleControls;

@end


@interface MediaBrowserFile : NSObject <MWPhoto>

@property (weak) id<MWFileDelegate> delegate;

@property (nonatomic, strong) NSString *caption;

@property (nonatomic) BOOL isUtiPreview;

+ (instancetype)fileWithFileMessageEntity:(FileMessageEntity *)fileMessageEntity thumbnail:(BOOL)thumbnail;

- (id)sourceReference;

- (BOOL)canHideToolBar;

@end
