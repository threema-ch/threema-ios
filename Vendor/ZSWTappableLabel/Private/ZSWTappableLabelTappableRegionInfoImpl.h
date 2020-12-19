//
//  ZSWTappableLabelTappableRegionInfoImpl.h
//  ZSWTappableLabel
//
//  Copyright (c) 2019 Zachary West. All rights reserved.
//
//  MIT License
//  https://github.com/zacwest/ZSWTappableLabel
//

#import <Foundation/Foundation.h>
#import "../ZSWTappableLabel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZSWTappableLabelTappableRegionInfoImpl : NSObject <ZSWTappableLabelTappableRegionInfo>
- (instancetype)initWithFrame:(CGRect)frame
                   attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                containerView:(UIView *)containerView;
@end

NS_ASSUME_NONNULL_END
