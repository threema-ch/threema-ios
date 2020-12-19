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

#import "VideoCaptionView.h"
#import "VideoMessage.h"
#import "RectUtil.h"

@implementation VideoCaptionView

- (UIView *)customViewInRect:(CGRect)rect {
    UIView *view = [[UIView alloc] initWithFrame:rect];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIImage *tmpImage = [UIImage imageNamed:@"Video"];
    UIImage *cameraImage = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:cameraImage];
    imageView.tintColor = [UIColor whiteColor];

    imageView.frame = [RectUtil rect:imageView.frame centerVerticalIn:rect];
    [view addSubview:imageView];
    
    UILabel *label = [self createLabelInRect:rect];
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    label.textAlignment = NSTextAlignmentRight;

    int seconds = ((VideoMessage *)self.message).duration.intValue;
    int minutes = (seconds / 60);
    seconds -= minutes * 60;
    label.text = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    
    [label sizeToFit];
    label.frame = [RectUtil rect:label.frame centerVerticalIn:rect round:YES];
    label.frame = [RectUtil setXPositionOf:label.frame x:rect.size.width - label.frame.size.width];
    [view addSubview:label];

    return view;
}

@end
