//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import "BallotMatrixLabelView.h"
#import "RectUtil.h"

#define FONT_COLOR [Colors fontNormal]

#define HAIRLINE_WIDTH 1.0f
#define MAX_WIDTH 300.0f

#define X_PADDING 4.0f

@interface BallotMatrixLabelView ()

@property UILabel *label;

@end

@implementation BallotMatrixLabelView

+ (instancetype)labelForString:(NSString *)text at:(CGRect)rect {
    BallotMatrixLabelView *view = [[BallotMatrixLabelView alloc] initWithFrame:rect];

    view.maxWidth = MAX_WIDTH;

    [view setupLabel];
    [view setText:text];
    
    return view;
}

- (void)setText:(NSString *)text {
    [_label setText:text];
}

- (NSString *)text {
    return _label.text;
}

-(void)setFont:(UIFont *)font {
    _label.font = font;
}

-(UIFont *)font {
    return _label.font;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    _label.textAlignment = textAlignment;
}

- (void)setBorderColor: (UIColor *)color {
    self.layer.borderColor = color.CGColor;
}

- (void)setBorderWidth: (CGFloat)width {
    self.layer.borderWidth = width;
}

- (void)setTextColor:(UIColor *)color {
    _label.textColor = color;
}

- (void) setupLabel {
    CGRect labelRect = [RectUtil growRect:self.bounds byDx:-2.0*X_PADDING byDy:0.0];
    _label = [[UILabel alloc] initWithFrame:labelRect];
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _label.textColor = FONT_COLOR;
    
    [self addSubview:_label];
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize labelSize = [_label sizeThatFits:size];
    
    CGFloat width = fminf(_maxWidth, labelSize.width);
    return CGSizeMake(width, self.bounds.size.height);
}

-(void)offsetAndResizeHeight:(CGFloat)yOffset {
    _label.frame = [RectUtil offsetAndResizeRect:_label.frame byX:0.0 byY:yOffset];
}

@end
