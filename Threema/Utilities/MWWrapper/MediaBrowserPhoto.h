#import <Foundation/Foundation.h>

#import "MWPhoto.h"

@class ImageMessageEntity;

@interface MediaBrowserPhoto : NSObject <MWPhoto>

@property (nonatomic, strong) NSString *caption;

/// Must be type of `ImageMessageEntity` or nil
@property (nonatomic, readonly) ImageMessageEntity *imageMessageEntity;
@property (nonatomic) BOOL isUtiPreview;

/**
 @param imageMessageEntity Must be type of `ImageMessageEntity` or nil
 */
+ (instancetype)photoWithImageMessageEntity:(ImageMessageEntity *)imageMessageEntity thumbnail:(BOOL)thumbnail;

@end
