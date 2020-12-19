// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  ZSWTappableLabel.m
//  ZSWTappableLabel
//
//  Copyright (c) 2019 Zachary West. All rights reserved.
//
//  MIT License
//  https://github.com/zacwest/ZSWTappableLabel
//

#import "ZSWTappableLabel.h"
#import "Private/ZSWTappableLabelTappableRegionInfoImpl.h"
#import "Private/ZSWTappableLabelAccessibilityActionLongPress.h"
#import "Private/ZSWTappableLabelTouchHandling.h"

#pragma mark -

NSAttributedStringKey const ZSWTappableLabelHighlightedBackgroundAttributeName = @"ZSWTappableLabelHighlightedBackgroundAttributeName";
NSAttributedStringKey const ZSWTappableLabelTappableRegionAttributeName = @"ZSWTappableLabelTappableRegionAttributeName";
NSAttributedStringKey const ZSWTappableLabelHighlightedForegroundAttributeName = @"ZSWTappableLabelHighlightedForegroundAttributeName";

typedef NS_ENUM(NSInteger, ZSWTappableLabelNotifyType) {
    ZSWTappableLabelNotifyTypeTap = 1,
    ZSWTappableLabelNotifyTypeLongPress,
};

#pragma mark -

@interface ZSWTappableLabel() <UIGestureRecognizerDelegate>
@property (nonatomic) NSArray<UIAccessibilityElement *> *accessibleElements;
@property (nonatomic) CGRect lastAccessibleElementsBounds;

@property (nonatomic) ZSWTappableLabelTouchHandling *touchHandling;

@property (nonatomic) BOOL needsToWatchTouches;
@property (nonatomic) UILongPressGestureRecognizer *longPressGR;
@property (nonatomic) BOOL hasCurrentEvent;
@end

@implementation ZSWTappableLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self tappableLabelCommonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self tappableLabelCommonInit];
        
        // Text was assigned by IB, possibly, so we need to make sure we're running if there's anything useful.
        [self checkForTappableRegions];
    }
    return self;
}

- (void)tappableLabelCommonInit {
    self.userInteractionEnabled = YES;
    
    self.numberOfLines = 0;
    self.lineBreakMode = NSLineBreakByWordWrapping;
    
    self.longPressDuration = 0.5;
    self.longPressAccessibilityActionName = nil; // reset value
    
    self.longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    self.longPressGR.delegate = self;
    [self addGestureRecognizer:self.longPressGR];
}

- (void)setLongPressDuration:(NSTimeInterval)longPressDuration {
    _longPressDuration = longPressDuration;
    self.longPressGR.minimumPressDuration = longPressDuration;
}

- (void)setLongPressDelegate:(id<ZSWTappableLabelLongPressDelegate>)longPressDelegate {
    _longPressDelegate = longPressDelegate;
    _accessibleElements = nil;
}

- (void)setLongPressAccessibilityActionName:(NSString *)longPressAccessibilityActionName {
    _longPressAccessibilityActionName = longPressAccessibilityActionName ?: NSLocalizedString(@"Open Menu", nil);
    _accessibleElements = nil;
}

- (void)setAccessibilityDelegate:(id<ZSWTappableLabelAccessibilityDelegate>)accessibilityDelegate {
    _accessibilityDelegate = accessibilityDelegate;
    _accessibleElements = nil;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (self.adjustsFontForContentSizeCategory) {
        UIContentSizeCategory previousCategory = previousTraitCollection.preferredContentSizeCategory;
        UIContentSizeCategory currentCategory = self.traitCollection.preferredContentSizeCategory;
        
        if (![previousCategory isEqual:currentCategory] || previousCategory != currentCategory) {
            self.touchHandling = nil;
        }
    }
}

- (ZSWTappableLabelTouchHandling *)createTouchHandlingIfNeeded {
    ZSWTappableLabelTouchHandling *existingTouchHandling = self.touchHandling;
    
    if (existingTouchHandling) {
        if (CGRectEqualToRect(existingTouchHandling.bounds, self.bounds)) {
            // we can continue to use the existing touch handling
            return existingTouchHandling;
        } else {
            // we need to create a new touch handling. additionally, we need to reset from the last one.
            // if the view is resizing while we were handling a touch, we need to cancel out the attributed
            // changes that we performed from the previous touch handling.
            [super setAttributedText:existingTouchHandling.unmodifiedAttributedString];
        }
    }
    
    // If the user doesn't specify a font, UILabel is going to render with the current
    // one it wants, so we need to fill in the blanks
    NSAttributedString *attributedText = [super attributedText];
    NSMutableAttributedString *mutableText = [attributedText mutableCopy];
    UIFont *font = self.font;
    
    [attributedText enumerateAttribute:NSFontAttributeName
                               inRange:NSMakeRange(0, attributedText.length)
                               options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                            usingBlock:^(id value, NSRange range, BOOL *stop) {
                                if (!value) {
                                    [mutableText addAttribute:NSFontAttributeName
                                                        value:font
                                                        range:range];
                                }
                            }];
    
    if (self.textAlignment != NSTextAlignmentLeft) {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = self.textAlignment;
        
        [attributedText enumerateAttribute:NSParagraphStyleAttributeName
                                   inRange:NSMakeRange(0, attributedText.length)
                                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                usingBlock:^(id value, NSRange range, BOOL *stop) {
                                    if (!value) {
                                        [mutableText addAttribute:NSParagraphStyleAttributeName
                                                            value:style
                                                            range:range];
                                    }
                                }];
    }
    
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:mutableText];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:^{
        CGSize size = self.bounds.size;
        
        // On iOS 10, NSLayoutManager will think it doesn't have enough space to fit text
        // compared to UILabel which will render more text in the same given space. I can't seem to find
        // any reason, and it's a 1-2pt difference.
        size.height = CGFLOAT_MAX;
        return size;
    }()];

    textContainer.lineBreakMode = self.lineBreakMode;
    textContainer.maximumNumberOfLines = self.numberOfLines;
    textContainer.lineFragmentPadding = 0;
    [layoutManager addTextContainer:textContainer];
    
    [textStorage addLayoutManager:layoutManager];

    // UILabel vertically centers if it doesn't fill the whole bounds, so compensate for that.
    CGRect usedRect = [layoutManager usedRectForTextContainer:textContainer];
    CGPoint pointOffset = CGPointMake(0, (CGRectGetHeight(self.bounds) - CGRectGetHeight(usedRect))/2.0);
    
    ZSWTappableLabelTouchHandling *touchHandling = [[ZSWTappableLabelTouchHandling alloc] initWithTextStorage:textStorage pointOffset:pointOffset bounds:self.bounds];
    self.touchHandling = touchHandling;
    return touchHandling;
}

- (void)performWithTouchHandling:(void(^)(ZSWTappableLabelTouchHandling *th))block {
    ZSWTappableLabelTouchHandling *touchHandling = [self createTouchHandlingIfNeeded];
    block(touchHandling);
}

#pragma mark - Overloading

- (void)setText:(NSString *)text {
    [super setText:text];
    self.touchHandling = nil;
    [self checkForTappableRegions];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];
    self.touchHandling = nil;
    [self checkForTappableRegions];
}

- (void)checkForTappableRegions {
    NSAttributedString *attributedText = self.attributedText;
    
    __block BOOL containsTappableRegion = NO;
    [attributedText enumerateAttribute:ZSWTappableLabelTappableRegionAttributeName
                               inRange:NSMakeRange(0, attributedText.length)
                               options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                            usingBlock:^(id value, NSRange range, BOOL *stop) {
                                if ([value boolValue]) {
                                    *stop = YES;
                                    containsTappableRegion = YES;
                                }
                            }];
    
    self.needsToWatchTouches = containsTappableRegion;
    self.longPressGR.enabled = containsTappableRegion;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == self.longPressGR && !self.longPressDelegate) {
        // We wait until the last moment to decide if a long press should occur because keeping track of the
        // GR's enabled state when the delegate changes is a bit more state management than seems appropriate.
        return NO;
    }
    
    __block BOOL shouldReceive = NO;
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        shouldReceive = [th isTappableRegionAtPoint:[touch locationInView:self]];
    }];
    
    return shouldReceive;
}

#pragma mark - Touch handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.needsToWatchTouches) {
        [super touchesBegan:touches withEvent:event];
        return;
    }
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        CGPoint point = [touches.anyObject locationInView:self];
        NSUInteger characterIdx = [th characterIndexAtPoint:point];
        
        if ([th isTappableRegionAtCharacterIndex:characterIdx]) {
            // Touching in a tappable region, we're good to start controlling these touches.
            self.hasCurrentEvent = YES;
            [self applyHighlightAtIndex:characterIdx];
        } else {
            // Touching is outside of a tappable region, we should forward the touches onward.
            // This forwarding allows e.g. a UICollectionViewCell we're contained in to highlight, select, etc.
            self.hasCurrentEvent = NO;
            [super touchesBegan:touches withEvent:event];
        }
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.needsToWatchTouches || !self.hasCurrentEvent) {
        [super touchesMoved:touches withEvent:event];
        return;
    }
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        NSUInteger characterIdx = [th characterIndexAtPoint:[touches.anyObject locationInView:self]];
        [self applyHighlightAtIndex:characterIdx];
    }];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.needsToWatchTouches || !self.hasCurrentEvent) {
        [super touchesEnded:touches withEvent:event];
        return;
    }
    
    self.hasCurrentEvent = NO;
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        NSUInteger characterIdx = [th characterIndexAtPoint:[touches.anyObject locationInView:self]];
        [self notifyForCharacterIndex:characterIdx type:ZSWTappableLabelNotifyTypeTap];
        [self removeHighlight];
    }];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.needsToWatchTouches || !self.hasCurrentEvent) {
        [super touchesCancelled:touches withEvent:event];
        return;
    }
    
    self.hasCurrentEvent = NO;
    [self removeHighlight];
}

- (void)applyHighlightAtIndex:(NSUInteger)characterIndex {
    if (characterIndex == NSNotFound) {
        [self removeHighlight];
        return;
    }
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        NSMutableAttributedString *attributedString = [th.unmodifiedAttributedString mutableCopy];
        
        NSRange highlightEffectiveRange = NSMakeRange(0, 0), foregroundEffectiveRange = NSMakeRange(0, 0);
        UIColor *highlightColor = [attributedString attribute:ZSWTappableLabelHighlightedBackgroundAttributeName
                                                      atIndex:characterIndex
                                        longestEffectiveRange:&highlightEffectiveRange
                                                      inRange:NSMakeRange(0, attributedString.length)];
        
        UIColor *foregroundColor = [attributedString attribute:ZSWTappableLabelHighlightedForegroundAttributeName
                                                       atIndex:characterIndex
                                         longestEffectiveRange:&foregroundEffectiveRange
                                                       inRange:NSMakeRange(0, attributedString.length)];
        
        if (highlightColor || foregroundColor) {
            if (highlightColor) {
                [attributedString addAttribute:NSBackgroundColorAttributeName
                                         value:highlightColor
                                         range:highlightEffectiveRange];
            }
            
            if (foregroundColor) {
                [attributedString addAttribute:NSForegroundColorAttributeName
                                         value:foregroundColor
                                         range:foregroundEffectiveRange];
            }
            
            [super setAttributedText:attributedString];
        } else {
            [self removeHighlight];
        }
    }];
}

- (void)removeHighlight {
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        [super setAttributedText:th.unmodifiedAttributedString];
    }];
}

- (void)notifyForCharacterIndex:(NSUInteger)characterIndex type:(ZSWTappableLabelNotifyType)notifyType {
    if (characterIndex == NSNotFound) {
        return;
    }
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        NSDictionary *attributes = [th.unmodifiedAttributedString attributesAtIndex:characterIndex effectiveRange:NULL] ?: @{};
        
        switch (notifyType) {
            case ZSWTappableLabelNotifyTypeTap:
                [self.tapDelegate tappableLabel:self
                                  tappedAtIndex:characterIndex
                                 withAttributes:attributes];
                break;
                
            case ZSWTappableLabelNotifyTypeLongPress:
                [self.longPressDelegate tappableLabel:self
                                   longPressedAtIndex:characterIndex
                                       withAttributes:attributes];
                break;
        }
    }];
}

- (BOOL)longPressForAccessibilityAction:(ZSWTappableLabelAccessibilityActionLongPress *)action {
    [self notifyForCharacterIndex:action.characterIndex type:ZSWTappableLabelNotifyTypeLongPress];
    return YES;
}

- (void)longPress:(UILongPressGestureRecognizer *)longPressGR {
    if (longPressGR.state != UIGestureRecognizerStateBegan) {
        // We only care about began because that is when we notify our delegate. Everything else can be ignored.
        return;
    }
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        NSUInteger characterIndex = [th characterIndexAtPoint:[longPressGR locationInView:self]];
        [self notifyForCharacterIndex:characterIndex type:ZSWTappableLabelNotifyTypeLongPress];
    }];
}

- (NSDictionary *)checkIsPointAction:(CGPoint)longPressPoint {
    ZSWTappableLabelTouchHandling *touchHandling = [self createTouchHandlingIfNeeded];
    if ([touchHandling isTappableRegionAtPoint:longPressPoint]) {
        NSUInteger characterIndex = [touchHandling characterIndexAtPoint:longPressPoint];
         return [touchHandling.unmodifiedAttributedString attributesAtIndex:characterIndex effectiveRange:NULL] ?: nil;
    } else {
        return nil;
    }
}

#pragma mark - Public attribute getting

- (nullable id<ZSWTappableLabelTappableRegionInfo>)tappableRegionInfoAtPoint:(CGPoint)point {
    __block ZSWTappableLabelTappableRegionInfoImpl *regionInfo;
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        NSUInteger characterIndex = [th characterIndexAtPoint:point];
        if (characterIndex == NSNotFound) {
            return;
        }
        
        NSRange effectiveRange;
        NSNumber *attribute = [th.unmodifiedAttributedString attribute:ZSWTappableLabelTappableRegionAttributeName
                                                               atIndex:characterIndex
                                                        effectiveRange:&effectiveRange];
        if (![attribute boolValue]) {
            return;
        }
        
        CGRect frame = [th frameForCharacterRange:effectiveRange];
        NSDictionary<NSAttributedStringKey, id> *attributes = [th.unmodifiedAttributedString attributesAtIndex:characterIndex effectiveRange:NULL];
        
        regionInfo = [[ZSWTappableLabelTappableRegionInfoImpl alloc] initWithFrame:frame
                                                                        attributes:attributes
                                                                     containerView:self];
    }];
    
    return regionInfo;
}

- (nullable id<ZSWTappableLabelTappableRegionInfo>)tappableRegionInfoForPreviewingContext:(id<UIViewControllerPreviewing>)previewingContext location:(CGPoint)location {
    return [self tappableRegionInfoAtPoint:[previewingContext.sourceView convertPoint:location toView:self]];
}

#pragma mark - Accessibility

- (BOOL)isAccessibilityElement {
    return NO; // because we're a container
}

- (NSArray *)accessibleElements {
    if (_accessibleElements && CGRectEqualToRect(self.bounds, self.lastAccessibleElementsBounds)) {
        // As long as our content and bounds don't change, our elements won't need updating, because
        // their frame is based on our container space.
        return _accessibleElements;
    }
    
    NSMutableArray<UIAccessibilityElement *> *accessibleElements = [NSMutableArray array];
    NSAttributedString *unmodifiedAttributedString = self.attributedText;
    
    id<ZSWTappableLabelAccessibilityDelegate> accessibilityDelegate = self.accessibilityDelegate;
    id<ZSWTappableLabelLongPressDelegate> longPressDelegate = self.longPressDelegate;
    NSString *longPressAccessibilityActionName = self.longPressAccessibilityActionName;
    
    [self performWithTouchHandling:^(ZSWTappableLabelTouchHandling *th) {
        if (!unmodifiedAttributedString.length) {
            return;
        }
        
        // Our general strategy is to break apart the string into multiple elements, where the boundary for each
        // element is the tappable region start/stop locations. This produces something like:
        //
        // [This is an] [example: link] [sentence with a link in the middle.]
        //
        // This matches Safari's behavior when it encounters links in the page. Remember that a VoiceOver user can
        // always enumerate and read the entire contents using the two-finger up/down gesture, and this is behavior
        // they are likely used to.
        void (^enumerationBlock)(id, NSRange, BOOL *) = ^(id value, NSRange range, BOOL *stop) {
            
            /***** BEGIN THREEMA MODIFICATION: only add accessibility elements for links, not for static text parts *********/
            if (![value boolValue])
                return;
            /***** END THREEMA MODIFICATION: only add accessibility elements for links, not for static text parts *********/
            
            UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
            element.accessibilityLabel = [unmodifiedAttributedString.string substringWithRange:range];
            element.accessibilityFrameInContainerSpace = [th frameForCharacterRange:range];
            
            if ([value boolValue]) {
                element.accessibilityTraits = UIAccessibilityTraitLink | UIAccessibilityTraitStaticText;
            } else {
                element.accessibilityTraits = UIAccessibilityTraitStaticText;
            }
            
            NSMutableArray<UIAccessibilityCustomAction *> *customActions = [NSMutableArray array];
            
            if (longPressDelegate) {
                ZSWTappableLabelAccessibilityActionLongPress *action = [[ZSWTappableLabelAccessibilityActionLongPress alloc] initWithName:longPressAccessibilityActionName target:self selector:@selector(longPressForAccessibilityAction:)];
                action.characterIndex = range.location;
                [customActions addObject:action];
            }
            
            if (accessibilityDelegate) {
                NSDictionary<NSAttributedStringKey, id> *attributesAtStart = [unmodifiedAttributedString attributesAtIndex:range.location effectiveRange:NULL];
                [customActions addObjectsFromArray:[accessibilityDelegate tappableLabel:self
                                            accessibilityCustomActionsForCharacterRange:range
                                                                  withAttributesAtStart:attributesAtStart]];
            }
            
            if (customActions.count > 0) {
                element.accessibilityCustomActions = customActions;
            }
            
            [accessibleElements addObject:element];
        };
        
        [unmodifiedAttributedString enumerateAttribute:ZSWTappableLabelTappableRegionAttributeName
                                               inRange:NSMakeRange(0, unmodifiedAttributedString.length)
                                               options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                            usingBlock:enumerationBlock];
    }];

    _accessibleElements = [accessibleElements copy];
    self.lastAccessibleElementsBounds = self.bounds;

    return _accessibleElements;
}

- (NSInteger)accessibilityElementCount {
    return [self accessibleElements].count;
}

- (id)accessibilityElementAtIndex:(NSInteger)idx {
    return [self accessibleElements][idx];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return [[self accessibleElements] indexOfObject:element];
}

@end
