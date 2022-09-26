//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2022 Threema GmbH
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

#import "CaptionView.h"
#import "MediaBrowserFile.h"
#import "RectUtil.h"

static const CGFloat labelPadding = 10.0;
static const CGFloat defaultCustomViewHeight = 24.0;

@interface CaptionView ()

@property BaseMessage *message;
@property UIView *customView;
@property UILabel *timeLabel;

@end

@implementation CaptionView

-(id)initWithPhoto:(id<MWPhoto>)photo {
    self = [super initWithPhoto:photo];
    if (self) {
        if ([photo respondsToSelector:@selector(sourceReference)]) {
            _message = [photo performSelector:@selector(sourceReference)];
            
            CGRect customViewRect = CGRectMake(labelPadding, labelPadding, self.bounds.size.width-labelPadding*2, defaultCustomViewHeight);
            _customView = [self customViewInRect:customViewRect];
            [self addSubview:_customView];
            
            CGRect timeLabelRect = [RectUtil setYPositionOf:customViewRect y:CGRectGetMaxY(customViewRect) + labelPadding];
            _timeLabel = [self createLabelInRect:timeLabelRect];
            [_timeLabel setText: [DateFormatter shortStyleDateTime:_message.remoteSentDate]];
            [self addSubview:_timeLabel];
            
            // adapt to height of resulting custom view
            if (_customView.frame.size.height != defaultCustomViewHeight) {
                _timeLabel.frame = [RectUtil setYPositionOf:_timeLabel.frame y:CGRectGetMaxY(_customView.frame)];
                self.frame = [RectUtil setHeightOf:self.frame height:CGRectGetMaxY(_timeLabel.frame)];
            }
        }
    }
    
    self.userInteractionEnabled = YES;
    
    return self;
}

- (void)setupCaption {
    ;//    ignore
}

-(CGSize)sizeThatFits:(CGSize)size {
    CGSize labelSize = CGSizeMake(size.width, CGRectGetMaxY(_timeLabel.frame) + labelPadding);
    return labelSize;
}

- (UIView *)customViewInRect:(CGRect)rect {
    return nil;
}

- (UILabel *)createLabelInRect:(CGRect)rect {
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    
    label.numberOfLines = 1;
    ///***** BEGIN THREEMA MODIFICATION*********
    label.textColor = [Colors textLight];
    ///***** END THREEMA MODIFICATION *********
    label.font = [UIFont systemFontOfSize:17];
    
    return label;
}

- (UITextView *)createTextViewInRect:(CGRect)rect {
    UITextView *textView = [[UITextView alloc] initWithFrame:rect];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    textView.opaque = NO;
    textView.backgroundColor = [UIColor clearColor];
    textView.textAlignment = NSTextAlignmentCenter;
    ///***** BEGIN THREEMA MODIFICATION*********
    textView.textColor = [Colors text];
    ///***** END THREEMA MODIFICATION *********
    textView.font = [UIFont systemFontOfSize:17.0];
        
    return textView;    
}

@end
