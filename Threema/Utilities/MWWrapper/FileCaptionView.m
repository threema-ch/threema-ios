#import "FileCaptionView.h"
#import "MediaBrowserFile.h"
#import "ThreemaUtilityObjC.h"
#import "Threema-Swift.h"

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
        
        
        view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, rect.size.height + fmax(labelLeft.frame.size.height, labelRight.frame.size.height));
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
        textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        
        MarkupParser *parser = [[MarkupParser alloc] init];
        textView.attributedText = [parser makeMentionsForMWWrapperAttributedStringFor:caption];
        
        CGFloat maxHeight = 200.0;
        CGSize textSize = [textView.attributedText boundingRectWithSize:CGSizeMake(rect.size.width, maxHeight)
                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                      context:nil].size;
        CGFloat calcHeight = textSize.height;
        
        if (textSize.height <= textView.font.lineHeight) {
            calcHeight = textView.font.lineHeight + 16;
            textView.scrollEnabled = false;
        }
        CGSize size = CGSizeMake(textSize.width, calcHeight);
        
        if (view == nil) {
            textView.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + 2.0, self.frame.size.width, size.height);
            return textView;
        } else {
            textView.frame = CGRectMake(0, rect.size.height + 2.0 , rect.size.width, size.height);
            [view addSubview:textView];
            view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, rect.size.height + textView.frame.size.height);
        }
    }
    
    if ([view subviews].count > 0) {
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        return view;
    }
    return [[UIView alloc] initWithFrame:CGRectMake(0.0, rect.origin.y, rect.size.width, 0.0)];
}

@end
