//
//  ZSWTappableLabelTouchHandling.h
//  ZSWTappableLabel
//
//  Copyright (c) 2019 Zachary West. All rights reserved.
//
//  MIT License
//  https://github.com/zacwest/ZSWTappableLabel
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZSWTappableLabelTouchHandling : NSObject

- (instancetype)initWithTextStorage:(NSTextStorage *)textStorage
                        pointOffset:(CGPoint)pointOffset
                             bounds:(CGRect)bounds;
@property (nonatomic, readonly) NSTextStorage *textStorage;
@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, readonly) NSTextContainer *textContainer;
@property (nonatomic, readonly) CGPoint pointOffset;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) NSAttributedString *unmodifiedAttributedString;

- (NSUInteger)characterIndexAtPoint:(CGPoint)point;
- (BOOL)isTappableRegionAtPoint:(CGPoint)point;
- (BOOL)isTappableRegionAtCharacterIndex:(NSUInteger)characterIndex;
- (CGRect)frameForCharacterRange:(NSRange)characterRange;

@end

NS_ASSUME_NONNULL_END
