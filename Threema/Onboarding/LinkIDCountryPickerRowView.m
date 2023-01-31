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

#import "LinkIDCountryPickerRowView.h"

@implementation LinkIDCountryPickerRowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat nameWidth = frame.size.width * 0.8;
        CGFloat codeWidth = frame.size.width - nameWidth;
        
        CGFloat height = frame.size.height;
        CGFloat x = 0.0;
        // Name label needs the leading space for iOS 14
        if (@available(iOS 14.0, *)) {
            x = 16.0;
        }
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, 0.0, nameWidth, height)];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:16.0];
        [self addSubview:_nameLabel];
        
        _codeLabel = [[UILabel alloc] initWithFrame:CGRectMake(nameWidth, 0.0, codeWidth, height)];
        _codeLabel.textColor = [UIColor whiteColor];
        _codeLabel.font = _nameLabel.font;
        [self addSubview:_codeLabel];
    }
    
    return self;
}

@end
