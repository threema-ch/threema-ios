//
//  JKLLockScreenNumber.m
//

#import "JKLLockScreenNumber.h"

static const CGFloat LSNContextSetLineWidth = 0.8f;

@implementation JKLLockScreenNumber

- (void)setHighlighted:(BOOL)highlighted {
    if (super.highlighted != highlighted) {
        super.highlighted = highlighted;
        
        [self setNeedsDisplay];
    }
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    //------------------ Threema edit begin ---------------------------
    // The circle used to be pinned to the left edge, which only looked centered because the nib
    // made every key square. It is laid out by a stack view now, so center it on the actual bounds
    CGFloat diameter = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect));
    CGRect  square   = CGRectMake(CGRectGetMidX(rect) - diameter / 2,
                                  CGRectGetMidY(rect) - diameter / 2,
                                  diameter,
                                  diameter);
    CGRect  inset    = CGRectInset(square, 1, 1);
    //------------------ Threema edit end ---------------------------

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorRef colorRef  = [self tintColor].CGColor;
    UIControlState state = [self state];

    CGContextSetLineWidth(context, LSNContextSetLineWidth);
    if (state == UIControlStateHighlighted) {
        CGContextSetFillColorWithColor(context, colorRef);
        CGContextFillEllipseInRect (context, inset);
        CGContextFillPath(context);
    }
    else {
        CGContextSetStrokeColorWithColor(context, colorRef);
        CGContextAddEllipseInRect(context, inset);
        CGContextStrokePath(context);
    }
}

@end
