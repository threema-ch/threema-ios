//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2024 Threema GmbH
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

#define MAX_NUMBER_OF_LINES 3
#define LABEL_HEIGHT_PADDING 23.0

#import "BallotVoteTableCell.h"
#import "RectUtil.h"

@implementation BallotVoteTableCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    UIImage *tmpImage = _checkmarkView.image;
    _checkmarkView.image = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    _choiceLabel.maxLines = MAX_NUMBER_OF_LINES;
    _choiceLabel.paddingHeight = LABEL_HEIGHT_PADDING;
}

- (void)setFrame:(CGRect)frame {
    CGRect currentFrame = self.frame;
    [super setFrame:frame];
    
    if (CGRectGetHeight(frame) != CGRectGetHeight(currentFrame)) {
        _choiceLabel.frame = [RectUtil rect:_choiceLabel.frame centerVerticalIn:frame round:YES];
        _checkmarkView.frame = [RectUtil rect:_checkmarkView.frame centerVerticalIn:frame];
        _voteCountLabel.frame = [RectUtil rect:_voteCountLabel.frame centerVerticalIn:frame];
    }
}

+ (CGFloat)calculateHeightFor:(NSString *)text inFrame:(CGRect)rect {
    ResizingLabel *label = [[ResizingLabel alloc] initWithFrame:rect];
    label.maxLines = MAX_NUMBER_OF_LINES;
    label.paddingHeight = LABEL_HEIGHT_PADDING;
    label.text = text;
    
    [label sizeToFit];
    
    return CGRectGetHeight(label.frame);
}

@end
