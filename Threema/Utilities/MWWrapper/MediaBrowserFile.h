#import <Foundation/Foundation.h>

#import "MWPhoto.h"

@class MediaBrowserFile, FileMessageEntity;

@protocol MWFileDelegate

/**
 @param fileMessageEntity Must be type of `FileMessageEntity`
 */
-(void)showFile:(nonnull FileMessageEntity *)fileMessageEntity;

/**
 @param fileMessageEntity Must be type of `FileMessageEntity`
 */
-(void)playFileVideo:(nonnull FileMessageEntity *)fileMessageEntity;
-(void)toggleControls;

@end


@interface MediaBrowserFile : NSObject <MWPhoto>

@property (weak) id<MWFileDelegate> delegate;

@property (nonatomic, strong) NSString *caption;

@property (nonatomic) BOOL isUtiPreview;

/**
 @param fileMessageEntity Must be type of `FileMessageEntity` or nil
 */
+ (instancetype)fileWithFileMessageEntity:(FileMessageEntity *)fileMessageEntity thumbnail:(BOOL)thumbnail;

- (id)sourceReference;

- (BOOL)canHideToolBar;

@end
