//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "ParallaxPageViewController.h"
#import "PageContentViewController.h"
#import "PageView.h"
#import "RectUtil.h"
#import "UIImage+ColoredImage.h"
//#import "AppDelegate.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@interface ParallaxPageViewController () <PageViewDataSource, PageViewDelegate, PageContentControllerDelegate>

@property PageView *pageContainerView;

@property NSInteger index;

@end

@implementation ParallaxPageViewController

@synthesize parallaxFactor = _parallaxFactor;

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
    [self updateNavigationButtons];
    [self updatePageControl];
        
    _pageContainerView.backgroundColor = [UIColor clearColor];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _pageContainerView.bgView = _bgView;
}

- (void)setViewControllers:(NSArray *)viewControllers {
    _viewControllers = viewControllers;

    // setup parent child relationship
    for (PageContentViewController *vc in _viewControllers) {
        vc.containerDelegate = self;
        [self addChildViewController:vc];
        [vc didMoveToParentViewController:self];
    }
}

- (void)setup {
    _pageContainerView = [[PageView alloc] initWithFrame:self.view.frame];
    _pageContainerView.delegate = self;
    _pageContainerView.datasource = self;
    
    if (_parallaxFactor) {
        _pageContainerView.parallaxFactor = _parallaxFactor.floatValue;
    }
    
    [self.view addSubview:_pageContainerView];

    [self.view bringSubviewToFront:_controlsView];
    
    [_pageLeftButton setImage:[UIImage imageNamed:@"ArrowPrevious" inColor:Colors.primaryWizard] forState:UIControlStateNormal];
    [_pageRightButton setImage:[UIImage imageNamed:@"ArrowNext" inColor:Colors.primaryWizard] forState:UIControlStateNormal];
    _pageLeftButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"previous"];
    _pageRightButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"next"];
    _pageControl.accessibilityLabel = [NSString stringWithFormat:@"%li %@ %li", (long)_pageControl.currentPage + 1, [BundleUtil localizedStringForKey:@"from"], (long)_pageControl.numberOfPages];
    _index = 0;
    _controlsView.frame = CGRectMake(_controlsView.frame.origin.x, _controlsView.frame.origin.y + _controlsView.safeAreaInsets.top, _controlsView.frame.size.width, _controlsView.frame.size.height - _controlsView.safeAreaInsets.bottom);
}

- (void)setParallaxFactor:(NSNumber *)parallaxFactor {
    _parallaxFactor = parallaxFactor;
    _pageContainerView.parallaxFactor = parallaxFactor.floatValue;
}

- (NSNumber *)parallaxFactor {
    return [NSNumber numberWithFloat:_pageContainerView.parallaxFactor];
}

- (NSInteger)nextIndexForIncrement:(NSInteger)increment {
    return _index + increment;
}

- (UIView *)viewAtIndex:(NSInteger)index {
    UIViewController *viewController = (UIViewController *)_viewControllers[index];
    return viewController.view;
}

- (void)updateNavigationButtons {
    if (_index == 0) {
        _pageLeftButton.hidden = YES;
    } else {
        _pageLeftButton.hidden = NO;
    }
    
    if (_index == _viewControllers.count - 1) {
        _pageRightButton.hidden = YES;
    } else {
        _pageRightButton.hidden = NO;
    }
}

- (void)updatePageControl {
    _pageControl.currentPage = _index;
    _pageControl.numberOfPages = _viewControllers.count;
}

#pragma mark - PageViewDataSource

- (UIView *) currentView: (CGRect) frame {
    return [self viewAtIndex:_index];
}

- (UIView *) nextView: (CGRect) frame {
    if (_index == _viewControllers.count - 1) {
        return nil;
    }
    
    NSInteger nextIndex = [self nextIndexForIncrement:1];
    return [self viewAtIndex:nextIndex];
}

- (UIView *) previousView: (CGRect) frame {
    if (_index == 0) {
        return nil;
    }

    NSInteger previousIndex = [self nextIndexForIncrement:-1];
    return [self viewAtIndex:previousIndex];
}

- (BOOL) moveToNext {
    if (_index == _viewControllers.count - 1) {
        return NO;
    }
    
    if ([self canMoveFromCurrentViewController]) {
        return NO;
    }
    
    _index++;
    _pageControl.accessibilityLabel = [NSString stringWithFormat:@"%li %@ %li", _index + 1, [BundleUtil localizedStringForKey:@"from"], (long)_pageControl.numberOfPages];
    return YES;
}

- (BOOL) moveToPrevious {
    if (_index == 0) {
        return NO;
    }
    
    _index--;
    _pageControl.accessibilityLabel = [NSString stringWithFormat:@"%li %@ %li", _index + 1, [BundleUtil localizedStringForKey:@"from"], (long)_pageControl.numberOfPages];
    return YES;
}

- (BOOL)canMoveFromCurrentViewController {
    PageContentViewController *currentVc = _viewControllers[_index];
    
    if ([currentVc respondsToSelector:@selector(isInputValid)]) {
        return [currentVc isInputValid] == NO;
    } else {
        return YES;
    }
}

- (UIViewController *)viewControllerForView:(UIView *)view {
    for (UIViewController *vc in _viewControllers) {
        if (vc.view == view) {
            return vc;
        }
    }
    
    return nil;
}

#pragma mark - PageViewDelegate

- (void) willPageFrom: (UIView *) fromView toView: (UIView *) toView {
    UIViewController *toVc = [self viewControllerForView:toView];
    [toVc beginAppearanceTransition:YES animated:YES];

    UIViewController *fromVc = [self viewControllerForView:fromView];
    [fromVc beginAppearanceTransition:NO animated:YES];
}

- (void) didPageFrom: (UIView *) fromView toView: (UIView *) toView {
    UIViewController *toVc = [self viewControllerForView:toView];
    [toVc endAppearanceTransition];

    UIViewController *fromVc = [self viewControllerForView:fromView];
    [fromVc endAppearanceTransition];

    [self updateNavigationButtons];
    [self updatePageControl];
}

#pragma mark - actions

- (IBAction)pageLeftAction:(id)sender {
    [_pageContainerView pageLeft];
}

- (IBAction)pageRightAction:(id)sender {
    [_pageContainerView pageRight];
}

- (IBAction)pageControlChanged:(id)sender {
    UIPageControl *pc = (UIPageControl *)sender;
    if (_index < pc.currentPage) {
        [_pageContainerView pageLeft];
    } else {
        [_pageContainerView pageRight];
    }
}

#pragma mark - PageContentControllerDelegate

- (void)hideControls:(BOOL)hideControls {
    CGFloat yOffset;
    if (hideControls) {
        yOffset = CGRectGetMaxY(self.view.frame);
    } else {
        yOffset = CGRectGetMaxY(self.view.frame) - CGRectGetHeight(_controlsView.frame);
    }

    CGRect rect = [RectUtil setYPositionOf:_controlsView.frame y:yOffset];
    _controlsView.frame = rect;
    
    [_pageContainerView enablePanGesture:(hideControls == NO)];
}

- (void)pageRight {
    [_pageContainerView pageRight];
}

- (void)pageLeft {
    [_pageContainerView pageLeft];
}

@end
