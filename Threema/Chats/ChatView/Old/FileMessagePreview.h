//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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
#import "FileMessageEntity.h"

@interface FileMessagePreview : NSObject

/// You must store a reference to the returned instance otherwise it will be immediately deallocated and the preview will show "No file to preview"
/// @param fileMessageEntity The FileMessageEntity for which the preview should be shown.
+ (instancetype)fileMessagePreviewFor:(FileMessageEntity *)fileMessageEntity;

+ (UIImage *)thumbnailForFileMessageEntity:(FileMessageEntity *)fileMessageEntity;

- (void)showOn:(UIViewController *)targetViewController;

@end
