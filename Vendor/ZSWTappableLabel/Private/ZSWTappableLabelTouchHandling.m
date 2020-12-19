//
//  ZSWTappableLabelTouchHandling.m
//  ZSWTappableLabel
//
//  Copyright (c) 2019 Zachary West. All rights reserved.
//
//  MIT License
//  https://github.com/zacwest/ZSWTappableLabel
//

#import "ZSWTappableLabelTouchHandling.h"
#import "../ZSWTappableLabel.h"

@interface ZSWTappableLabelTouchHandling()
@property (nonatomic, readwrite) NSAttributedString *unmodifiedAttributedString;
@property (nonatomic, readwrite) NSTextStorage *textStorage;
@property (nonatomic, readwrite) NSLayoutManager *layoutManager;
@property (nonatomic, readwrite) NSTextContainer *textContainer;
@property (nonatomic, readwrite) CGPoint pointOffset;
@property (nonatomic, readwrite) CGRect bounds;
@end

@implementation ZSWTappableLabelTouchHandling

- (instancetype)initWithTextStorage:(NSTextStorage *)textStorage pointOffset:(CGPoint)pointOffset bounds:(CGRect)bounds {
    if ((self = [super init])) {
        self.unmodifiedAttributedString = [[NSAttributedString alloc] initWithAttributedString:textStorage];
        self.textStorage = textStorage;
        self.layoutManager = textStorage.layoutManagers.lastObject;
        self.textContainer = textStorage.layoutManagers.lastObject.textContainers.lastObject;
        self.bounds = bounds;
        self.pointOffset = pointOffset;
    }
    return self;
}

- (NSUInteger)characterIndexAtPoint:(CGPoint)point {
    point.x -= self.pointOffset.x;
    point.y -= self.pointOffset.y;
    
    CGFloat fractionOfDistanceBetween;
    NSUInteger characterIdx = [self.layoutManager characterIndexForPoint:point
                                                         inTextContainer:self.textContainer
                                fractionOfDistanceBetweenInsertionPoints:&fractionOfDistanceBetween];
    
    characterIdx = MIN(self.textStorage.length - 1, characterIdx + fractionOfDistanceBetween);
    
    NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:NSMakeRange(characterIdx, 1) actualCharacterRange:NULL];
    CGRect glyphRect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
    
    // plus some padding to make it easier in some cases
    glyphRect = CGRectInset(glyphRect, -10, -10);
    
    if (!CGRectContainsPoint(glyphRect, point)) {
        characterIdx = NSNotFound;
    }
    
    return characterIdx;
}

- (BOOL)isTappableRegionAtPoint:(CGPoint)point {
    return [self isTappableRegionAtCharacterIndex:[self characterIndexAtPoint:point]];
}

- (BOOL)isTappableRegionAtCharacterIndex:(NSUInteger)characterIdx {
    if (characterIdx == NSNotFound) {
        return NO;
    }
    
    NSNumber *attribute = [self.textStorage attribute:ZSWTappableLabelTappableRegionAttributeName
                                              atIndex:characterIdx
                                       effectiveRange:NULL];
    return [attribute boolValue];
}

- (CGRect)frameForCharacterRange:(NSRange)characterRange {
    NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:NULL];
    CGRect viewFrame = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
    viewFrame.origin.x += self.pointOffset.x;
    viewFrame.origin.y += self.pointOffset.y;
    return viewFrame;
}

@end
