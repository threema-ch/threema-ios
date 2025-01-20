//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "ResizingLabel.h"

@interface ResizingLabel ()

@end

@implementation ResizingLabel


- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _maxHeight = 0.0;
    }
    
    return self;
}

- (void)setText:(NSString *)text
{
    self.numberOfLines = _maxLines;
    [super setText: text];
}

- (CGSize) sizeThatFits:(CGSize)size
{
    return CGSizeMake(size.width, [self calculateHeightThatFits]);
}

- (CGFloat) calculateHeightThatFits
{
    CGSize size = [self.text sizeWithAttributes:@{NSFontAttributeName : self.font}];
    if (size.width < self.frame.size.width && [self containsNewLine: self.text] == NO) {
        self.numberOfLines = 1;
        return fmaxf(size.height + _paddingHeight, _minHeight);
    } else {
        self.numberOfLines = _maxLines;
        
        CGSize maxSize = CGSizeMake(self.frame.size.width, _maxHeight - _paddingHeight);
        CGSize uiLabelSize = [super sizeThatFits: maxSize];
        
        if (_maxHeight > 0.0) {
            int maxPossibleLines = (_maxHeight - _paddingHeight) / size.height;
            
            CGFloat height = MIN(maxPossibleLines * size.height, uiLabelSize.height);
            return height + _paddingHeight;
        } else {
            return uiLabelSize.height + _paddingHeight;
        }
    }
}

- (BOOL) containsNewLine: (NSString *) string
{
    NSRange range = [string rangeOfString:@"\n"];
    if (range.location != NSNotFound) {
        return YES;
    }
    
    return NO;
}

@end
