#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define MAX_ANIMATION_DURATION 0.3
#define MIN_PAGE_PAN_POINTS 50.0
#define MIN_PAGE_PAN_SPEED 150.0
#define DEFAULT_PAGE_GAP 5.0

typedef enum PagingDirection {
    LEFT,
    RIGHT
} PagingDirection;

@protocol PageViewDataSource

- (UIView *) currentView: (CGRect) frame;
- (UIView *) nextView: (CGRect) frame;
- (UIView *) previousView: (CGRect) frame;

- (BOOL) moveToPrevious;
- (BOOL) moveToNext;

@end

@protocol PageViewDelegate

- (void) willPageFrom: (UIView *) fromView toView: (UIView *) toView;
- (void) didPageFrom: (UIView *) fromView toView: (UIView *) toView;
@end

@interface PageView : UIView

@property (nonatomic) id<PageViewDataSource> datasource;

@property (weak, nonatomic) NSObject<PageViewDelegate> *delegate;

@property (nonatomic) UIView *centerView;
@property (nonatomic) UIView *leftView;
@property (nonatomic) UIView *rightView;

@property CGFloat pageGap;

- (void) resetPageFrames;

- (void) reset;

- (void) pageRight;

- (void) pageLeft;

- (void) enablePanGesture:(BOOL)enablePan;

@end


