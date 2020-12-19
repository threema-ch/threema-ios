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

#import "ScrollViewContent.h"
#import "RectUtil.h"

@implementation ScrollViewContent

-(instancetype)init {
    self = [super init];
    
    if (self) {
        _minWidth = 0.0f;
    }
    
    return self;
}

- (void)setFrame:(CGRect)frame {
    CGFloat width = fmaxf(_minWidth, frame.size.width);
    
    CGRect newFrame = [RectUtil setWidthOf:frame width:width];
    
    [super setFrame:newFrame];
}

- (CGFloat) adaptToWidth:(CGFloat) width {
    if (_minWidth == 0.0) {
        return width;
    }
    
    CGFloat newWidth;
    if (CGRectGetWidth(self.frame) < width) {
        newWidth = width;
    } else {
        newWidth = _minWidth;
    }

    self.frame = [RectUtil setWidthOf:self.frame width:newWidth];
    
    return newWidth;
}

@end
