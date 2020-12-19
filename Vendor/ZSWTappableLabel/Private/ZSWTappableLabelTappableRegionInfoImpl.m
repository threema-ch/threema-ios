//
//  ZSWTappableLabelTappableRegionInfoImpl.m
//  ZSWTappableLabel
//
//  Copyright (c) 2019 Zachary West. All rights reserved.
//
//  MIT License
//  https://github.com/zacwest/ZSWTappableLabel
//

#import "ZSWTappableLabelTappableRegionInfoImpl.h"

@interface ZSWTappableLabelTappableRegionInfoImpl()
@property (nonatomic, readwrite) CGRect frame;
@property (nonatomic, readwrite) NSDictionary<NSAttributedStringKey, id> *attributes;
@property (nonatomic) UIView *containerView;
@end

@implementation ZSWTappableLabelTappableRegionInfoImpl

- (instancetype)initWithFrame:(CGRect)frame
                   attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                containerView:(UIView *)containerView {
    if ((self = [super init])) {
        _frame = frame;
        _attributes = attributes;
        _containerView = containerView;
    }
    return self;
}

- (void)configurePreviewingContext:(id<UIViewControllerPreviewing>)previewingContext {
    previewingContext.sourceRect = [previewingContext.sourceView convertRect:self.frame
                                                                    fromView:self.containerView];
}

@end
