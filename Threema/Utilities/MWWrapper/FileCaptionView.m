//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import "FileCaptionView.h"
#import "FileMessageEntity.h"
#import "MediaBrowserFile.h"
#import "RectUtil.h"
#import "ThreemaUtilityObjC.h"
#import "TextStyleUtils.h"

#define PADDING 10.0

@implementation FileCaptionView

- (UIView *)customViewInRect:(CGRect)rect {
    FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.message;
    
    UIView *view = nil;
    
    if (!([fileMessageEntity renderMediaFileMessage] || [fileMessageEntity renderStickerFileMessage])) {
        view = [[UIView alloc] initWithFrame:rect];
        
        CGFloat rightWidth = 100.0;
        CGRect rightRect = CGRectMake(rect.size.width - rightWidth, 0.0, rightWidth, rect.size.height);
        UILabel *labelRight = [self createLabelInRect:rightRect];
        labelRight.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        labelRight.lineBreakMode = NSLineBreakByTruncatingMiddle;
        labelRight.textAlignment = NSTextAlignmentRight;
        labelRight.text = [ThreemaUtilityObjC formatDataLength:fileMessageEntity.fileSize.floatValue];
        [view addSubview:labelRight];
        
        CGRect leftRect = CGRectMake(0.0, 0.0, rect.size.width - rightWidth, rect.size.height);
        UILabel *labelLeft = [self createLabelInRect:leftRect];
        labelLeft.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        labelLeft.lineBreakMode = NSLineBreakByTruncatingMiddle;
        labelLeft.textAlignment = NSTextAlignmentLeft;
        labelLeft.text = fileMessageEntity.fileName;
        [view addSubview:labelLeft];
    }
    
    NSString *caption = fileMessageEntity.caption;
    if (caption) {
        UITextView *textView = [self createTextViewInRect:rect];
        textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        textView.textAlignment = NSTextAlignmentCenter;
        textView.editable = NO;
        textView.userInteractionEnabled = YES;
        textView.scrollEnabled = YES;
        textView.backgroundColor = [UIColor clearColor];
        textView.selectable = NO;
        
        textView.text = [TextStyleUtils makeMentionsStringForText:caption];
        
        CGFloat maxHeight = 200.0;
        CGSize textSize = [textView.text boundingRectWithSize:CGSizeMake(self.frame.size.width, maxHeight)
                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                   attributes:@{NSFontAttributeName:textView.font}
                                                      context:nil].size;
        CGSize size = CGSizeMake(textSize.width, textSize.height);
        
        
        if (view == nil) {
            textView.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + 2.0, self.frame.size.width, size.height);
            return textView;
        } else {
            textView.frame = CGRectMake(0, rect.size.height + 2.0 , rect.size.width, size.height);
            [view addSubview:textView];
            view.frame = [RectUtil setHeightOf:view.frame height:rect.size.height + textView.frame.size.height];
        }
    }
    
    if ([view subviews].count > 0) {
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        return view;
    }
    return [[UIView alloc] initWithFrame:CGRectMake(0.0, rect.origin.y, rect.size.width, 0.0)];
}

@end
