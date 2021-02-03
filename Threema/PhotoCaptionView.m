//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2021 Threema GmbH
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

#import "PhotoCaptionView.h"
#import "ImageMessage.h"
#import "RectUtil.h"
#import "TextStyleUtils.h"

#define PADDING 10.0

@interface PhotoCaptionView ()

@property UITextView *textView;

@end


@implementation PhotoCaptionView

- (UIView *)customViewInRect:(CGRect)rect {
    ImageMessage *imageMessage = (ImageMessage*)self.message;
    
    NSString *caption = [imageMessage.image getCaption];
    if (caption) {
        _textView = [self createTextViewInRect:rect];
        _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _textView.textAlignment = NSTextAlignmentCenter;
        _textView.editable = NO;
        _textView.userInteractionEnabled = YES;
        _textView.scrollEnabled = YES;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.selectable = NO;
        
        _textView.text = [TextStyleUtils makeMentionsStringForText:caption];
                
        CGFloat maxHeight = 200.0;
        CGSize textSize = [_textView.text boundingRectWithSize:CGSizeMake(self.frame.size.width, maxHeight)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:@{NSFontAttributeName:_textView.font}
                                                       context:nil].size;
        CGSize size = CGSizeMake(textSize.width, textSize.height);
        _textView.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + 2.0, self.frame.size.width, size.height);
        
        return _textView;
    }
    
    return [[UIView alloc] initWithFrame:CGRectMake(0.0, rect.origin.y, rect.size.width, 0.0)];
}

@end
