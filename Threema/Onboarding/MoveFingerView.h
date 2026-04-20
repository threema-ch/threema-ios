#import <UIKit/UIKit.h>

@class MoveFingerView;

@protocol MoveFingerDelegate

- (void)didMoveFingerInView:(MoveFingerView*)view;

@end

@interface MoveFingerView : UIView

@property (nonatomic) NSUInteger numberOfPositionsRecorded;
@property (nonatomic, readonly) NSData* digest;

@property (nonatomic, weak) id<MoveFingerDelegate> delegate;

@end
