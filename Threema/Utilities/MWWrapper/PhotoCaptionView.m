#import "PhotoCaptionView.h"
#import "Threema-Swift.h"

#define PADDING 10.0

@interface PhotoCaptionView ()

@property UITextView *textView;

@end


@implementation PhotoCaptionView

- (UIView *)customViewInRect:(CGRect)rect {
    ImageMessageEntity *imageMessageEntity = (ImageMessageEntity*)self.message;
    
    NSString *caption = [imageMessageEntity.image caption];
    if (caption) {
        _textView = [self createTextViewInRect:rect];
        _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _textView.textAlignment = NSTextAlignmentCenter;
        _textView.editable = NO;
        _textView.userInteractionEnabled = YES;
        _textView.scrollEnabled = YES;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.selectable = NO;
        _textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

        
        MarkupParser *parser = [[MarkupParser alloc] init];
        _textView.attributedText = [parser makeMentionsForMWWrapperAttributedStringFor:caption];
                
        CGFloat maxHeight = 200.0;
        CGSize textSize = [_textView.attributedText boundingRectWithSize:CGSizeMake(self.frame.size.width, maxHeight)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                       context:nil].size;
        CGSize size = CGSizeMake(textSize.width, textSize.height);
        _textView.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + 2.0, self.frame.size.width, size.height);

        return _textView;
    }
    
    return [[UIView alloc] initWithFrame:CGRectMake(0.0, rect.origin.y, rect.size.width, 0.0)];
}

@end
