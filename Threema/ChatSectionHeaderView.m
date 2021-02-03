//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "ChatSectionHeaderView.h"
#import "Threema-Swift.h"

@interface ChatSectionHeaderView ()

@property UILabel *dateLabel;

@end

@implementation ChatSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
}

- (void)makeRoundRectLabel {
    CGRect labelFrame = CGRectMake(0.0, 8.0, self.frame.size.width, _fontSize + 6.0);
    _dateLabel = [[RoundedRectLabel alloc] initWithFrame:labelFrame];
    
    _dateLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _dateLabel.clearsContextBeforeDrawing = NO;
    _dateLabel.font = [UIFont boldSystemFontOfSize:_fontSize];
    _dateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _dateLabel.textAlignment = NSTextAlignmentCenter;
    _dateLabel.contentMode = UIViewContentModeCenter;

    _dateLabel.alpha = 0.8;
    _dateLabel.backgroundColor = [Colors backgroundDark];
    _dateLabel.textColor = [Colors fontLight];
    
    [self addSubview:_dateLabel];
    
    _dateLabel.text = _text;
}

- (void)setText:(NSString *)text {
    _text = text;
    _dateLabel.text = text;
}

- (void)setFontSize:(CGFloat)fontSize {
    _fontSize = fontSize;
    [self makeRoundRectLabel];
}

- (void)setHidden:(BOOL)hidden {
    _dateLabel.hidden = hidden;
}

- (void)setAlpha:(CGFloat)alpha {
    _dateLabel.alpha = alpha;
}

- (CGFloat)alpha {
    return _dateLabel.alpha;
}

@end
