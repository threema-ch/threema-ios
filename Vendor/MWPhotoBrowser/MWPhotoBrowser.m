// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  MWPhotoBrowser.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MWCommon.h"
#import "MWPhotoBrowser.h"
#import "MWPhotoBrowserPrivate.h"
///***** BEGIN THREEMA MODIFICATION *********/
#import <SDWebImage/SDImageCache.h>
///***** END THREEMA MODIFICATION *********/
#import "UIImage+MWPhotoBrowser.h"
///***** BEGIN THREEMA MODIFICATION: Add AppGroup and utils *********/
#import "TTOpenInAppActivity.h"
#import "ForwardURLActivity.h"
#import "ForwardMultipleURLActivity.h"
#import "AppGroup.h"
#import "ThreemaUtilityObjC.h"
#import "Threema-Swift.h"
#import "ActivityUtil.h"
#import "ContactGroupPickerViewController.h"
#import "MediaBrowserFile.h"
///***** END THREEMA MODIFICATION: Add AppGroup and utils *********/

#define PADDING                  10

static void * MWVideoPlayerObservation = &MWVideoPlayerObservation;

///***** BEGIN THREEMA MODIFICATION: Add delegates *********/
@interface MWPhotoBrowser () <ModalNavigationControllerDelegate, ContactGroupPickerDelegate>
@end
///***** END THREEMA MODIFICATION: Add delegates *********/

@implementation MWPhotoBrowser

#pragma mark - Init

- (id)init {
    if ((self = [super init])) {
        [self _initialisation];
    }
    return self;
}

- (id)initWithDelegate:(id <MWPhotoBrowserDelegate>)delegate {
    if ((self = [self init])) {
        _delegate = delegate;
	}
	return self;
}

- (id)initWithPhotos:(NSArray *)photosArray {
	if ((self = [self init])) {
		_fixedPhotosArray = photosArray;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super initWithCoder:decoder])) {
        [self _initialisation];
	}
	return self;
}

- (void)_initialisation {
    
    // Defaults
    NSNumber *isVCBasedStatusBarAppearanceNum = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"];
    if (isVCBasedStatusBarAppearanceNum) {
        _isVCBasedStatusBarAppearance = isVCBasedStatusBarAppearanceNum.boolValue;
    } else {
        _isVCBasedStatusBarAppearance = YES; // default
    }
    self.hidesBottomBarWhenPushed = YES;
    _hasBelongedToViewController = NO;
    _photoCount = NSNotFound;
    _previousLayoutBounds = CGRectZero;
    _currentPageIndex = 0;
    _previousPageIndex = NSUIntegerMax;
    _currentVideoIndex = NSUIntegerMax;
    _displayActionButton = YES;
    _displayNavArrows = NO;
    _zoomPhotosToFill = YES;
    _performingLayout = NO; // Reset on view did appear
    _rotating = NO;
    _viewIsActive = NO;
    _enableGrid = YES;
    _startOnGrid = NO;
    _enableSwipeToDismiss = YES;
    _delayToHideElements = 5;
    ///***** BEGIN THREEMA MODIFICATION: don't hide controll when voiceover is running *********/
    if (UIAccessibilityIsVoiceOverRunning()) {
        _alwaysShowControls = YES;
    } else {
        _alwaysShowControls = NO;
    }
    ///***** END THREEMA MODIFICATION: don't hide controll when voiceover is running *********/
    _visiblePages = [[NSMutableSet alloc] init];
    _recycledPages = [[NSMutableSet alloc] init];
    _photos = [[NSMutableArray alloc] init];
    _thumbPhotos = [[NSMutableArray alloc] init];
    _didSavePreviousStateOfNavBar = NO;
    _testCount = 0;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    // Listen for MWPhoto notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMWPhotoLoadingDidEndNotification:)
                                                 name:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                               object:nil];
    
    /***** BEGIN THREEMA MODIFICATION: listen for application foreground/background events to fix status bar *********/
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    /***** END THREEMA MODIFICATION: listen for application foreground/background events to fix status bar *********/
}

- (void)dealloc {
    [self clearCurrentVideo: true];
    _pagingScrollView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseAllUnderlyingPhotos:NO];
    [[SDImageCache sharedImageCache] clearMemory]; // clear memory
}

- (void)releaseAllUnderlyingPhotos:(BOOL)preserveCurrent {
    // Create a copy in case this array is modified while we are looping through
    // Release photos
    NSArray *copy = [_photos copy];
    for (id p in copy) {
        if (p != [NSNull null]) {
            if (preserveCurrent && p == [self photoAtIndex:self.currentIndex]) {
                continue; // skip current
            }
            [p unloadUnderlyingImage];
        }
    }
    // Release thumbs
    copy = [_thumbPhotos copy];
    for (id p in copy) {
        if (p != [NSNull null]) {
            [p unloadUnderlyingImage];
        }
    }
}

- (void)didReceiveMemoryWarning {

	// Release any cached data, images, etc that aren't in use.
    [self releaseAllUnderlyingPhotos:YES];
	[_recycledPages removeAllObjects];
	
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
}

#pragma mark - View Loading

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
    // Validate grid settings
    if (_startOnGrid) _enableGrid = YES;
    if (_enableGrid) {
        _enableGrid = [_delegate respondsToSelector:@selector(photoBrowser:thumbPhotoAtIndex:)];
    }
    if (!_enableGrid) _startOnGrid = NO;
	
	// View
    ///***** BEGIN THREEMA MODIFICATION *********
	self.view.backgroundColor = [Colors backgroundView];
    ///***** END THREEMA MODIFICATION *********
    self.view.clipsToBounds = YES;
	
	// Setup paging scrolling view
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
	_pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
	_pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_pagingScrollView.pagingEnabled = YES;
	_pagingScrollView.delegate = self;
	_pagingScrollView.showsHorizontalScrollIndicator = NO;
	_pagingScrollView.showsVerticalScrollIndicator = NO;
    ///***** BEGIN THREEMA MODIFICATION *********
    _pagingScrollView.backgroundColor = [Colors backgroundView];
    ///***** END THREEMA MODIFICATION *********
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	[self.view addSubview:_pagingScrollView];
	
    // Toolbar
    _toolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]]];
    ///***** BEGIN THREEMA MODIFICATION *********
    _toolbar.tintColor = [Colors backgroundView];
    ///***** END THREEMA MODIFICATION *********
    _toolbar.barTintColor = nil;
    [_toolbar setBackgroundImage:nil forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [_toolbar setBackgroundImage:nil forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsCompact];
    ///***** BEGIN THREEMA MODIFICATION*********
    _toolbar.barStyle = UIBarStyleDefault;
    ///***** END THREEMA MODIFICATION *********
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    
    // Toolbar
    _gridToolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]]];
    ///***** BEGIN THREEMA MODIFICATION *********
    _gridToolbar.tintColor = [Colors backgroundView];
    ///***** END THREEMA MODIFICATION *********
    _gridToolbar.barTintColor = nil;
    [_gridToolbar setBackgroundImage:nil forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [_gridToolbar setBackgroundImage:nil forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsCompact];
    ///***** BEGIN THREEMA MODIFICATION *********
    _gridToolbar.barStyle = UIBarStyleDefault;
    ///***** END THREEMA MODIFICATION*********
    _gridToolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    
    // Toolbar Items
    if (self.displayNavArrows) {
        NSString *arrowPathFormat = @"MWPhotoBrowser.bundle/UIBarButtonItemArrow%@";
        UIImage *previousButtonImage = [UIImage imageForResourcePath:[NSString stringWithFormat:arrowPathFormat, @"Left"] ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]];
        UIImage *nextButtonImage = [UIImage imageForResourcePath:[NSString stringWithFormat:arrowPathFormat, @"Right"] ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]];
        _previousButton = [[UIBarButtonItem alloc] initWithImage:previousButtonImage style:UIBarButtonItemStylePlain target:self action:@selector(gotoPreviousPage)];
        _nextButton = [[UIBarButtonItem alloc] initWithImage:nextButtonImage style:UIBarButtonItemStylePlain target:self action:@selector(gotoNextPage)];
    }
    if (self.displayActionButton) {
        _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
        _actionMultipleButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionMultipleButtonPressed:)];
    }
    
    /***** BEGIN THREEMA MODIFICATION: add delete button *********/
    if (self.displayDeleteButton) {
        _deleteSingleButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteButtonPressed:)];
        _deleteMultipleButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteMultipleButtonPressed:)];
    }
    /***** END THREEMA MODIFICATION: add delete button *********/
    
    // Update
    [self reloadData: true];
    
    // Swipe to dismiss
    if (_enableSwipeToDismiss) {
        UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(doneButtonPressed:)];
        swipeGesture.direction = UISwipeGestureRecognizerDirectionDown | UISwipeGestureRecognizerDirectionUp;
        [self.view addGestureRecognizer:swipeGesture];
    }
    
	// Super
    [super viewDidLoad];
	
}

- (void)performLayout {
    
    // Setup
    _performingLayout = YES;
    NSUInteger numberOfPhotos = [self numberOfPhotos];
    
	// Setup pages
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    // Navigation buttons
    if ([self.navigationController.viewControllers objectAtIndex:0] == self || self.navigationController == nil) {
        // We're first on stack so show done button
        _doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStylePlain target:self action:@selector(doneButtonPressed:)];
        // Set appearance
        [_doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [_doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsCompact];
        [_doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [_doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsCompact];
        [_doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateNormal];
        [_doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateHighlighted];
        /***** BEGIN THREEMA MODIFICATION: 'done' on left *********/
        self.navigationItem.leftBarButtonItem = _doneButton;
        /***** END THREEMA MODIFICATION: 'done' on left *********/
    } else {
        // We're not first so show back button
        UIViewController *previousViewController = [self.navigationController.viewControllers objectAtIndex:self.navigationController.viewControllers.count-2];
        NSString *backButtonTitle = previousViewController.navigationItem.backBarButtonItem ? previousViewController.navigationItem.backBarButtonItem.title : previousViewController.title;
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStylePlain target:nil action:nil];
        // Appearance
        [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsCompact];
        [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsCompact];
        [newBackButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateNormal];
        [newBackButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateHighlighted];
        _previousViewControllerBackButton = previousViewController.navigationItem.backBarButtonItem; // remember previous
        previousViewController.navigationItem.backBarButtonItem = newBackButton;
    }

    // Toolbar items
    BOOL hasItems = NO;
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpace.width = 32; // To balance action button
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    NSMutableArray *items = [[NSMutableArray alloc] init];

    // Left button - Grid
    if (_enableGrid) {
        hasItems = YES;
        ///***** BEGIN THREEMA MODIFICATION: don't hide controll when voiceover is running *********/
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/UIBarButtonItemGrid" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]] style:UIBarButtonItemStylePlain target:self action:@selector(showGridAnimated)];
        item.accessibilityLabel = NSLocalizedString(@"media_overview", nil);
        [items addObject:item];
        ///***** END THREEMA MODIFICATION: don't hide controll when voiceover is running *********/
    } else {
        [items addObject:fixedSpace];
    }

    // Middle - Nav
    if (_previousButton && _nextButton && numberOfPhotos > 1) {
        hasItems = YES;
        [items addObject:flexSpace];
        [items addObject:_previousButton];
        [items addObject:flexSpace];
        /***** BEGIN THREEMA MODIFICATION: add delete single button *********/
        if (_deleteSingleButton) {
            [items addObject:_deleteSingleButton];
            [items addObject:flexSpace];
        }
        /***** END THREEMA MODIFICATION: add delete single button *********/
        [items addObject:_nextButton];
        [items addObject:flexSpace];
    } else {
        [items addObject:flexSpace];
        /***** BEGIN THREEMA MODIFICATION: add delete single button *********/
        if (_deleteSingleButton) {
            [items addObject:_deleteSingleButton];
            [items addObject:flexSpace];
        }
        /***** END THREEMA MODIFICATION: add delete single button *********/
    }

    // Right - Action
    if (_actionButton && !(!hasItems && !self.navigationItem.rightBarButtonItem)) {
        [items addObject:_actionButton];
    } else {
        // We're not showing the toolbar so try and show in top right
        if (_actionButton)
            self.navigationItem.rightBarButtonItem = _actionButton;
        [items addObject:fixedSpace];
    }

    // Toolbar visibility
    [_toolbar setItems:items];
    BOOL hideToolbar = YES;
    for (UIBarButtonItem* item in _toolbar.items) {
        if (item != fixedSpace && item != flexSpace) {
            hideToolbar = NO;
            break;
        }
    }
    if (hideToolbar) {
        [_toolbar removeFromSuperview];
    } else {
        [self.view addSubview:_toolbar];
    }
    
    ///***** BEGIN THREEMA MODIFICATION: Add grid toolbar *********/

    // Grid toolbar items
    NSMutableArray *gridItems = [[NSMutableArray alloc] init];

    // Left button - Delete multiple
     if (_deleteMultipleButton) {
         [gridItems addObject:_deleteMultipleButton];
     } else {
         [gridItems addObject:fixedSpace];
     }

    // Middle - empty
    [gridItems addObject:flexSpace];
    
    // Right - Action
    if (_actionMultipleButton) {
        [gridItems addObject:_actionMultipleButton];
    } else {
        [gridItems addObject:fixedSpace];
    }

    // GridToolbar visibility
    [_gridToolbar setItems:gridItems];
    [_gridToolbar removeFromSuperview];
    
    ///***** END THREEMA MODIFICATION: Add grid toolbar *********/
    
    // Update nav
	[self updateNavigation];
    
    // Content offset
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:_currentPageIndex];
    [self tilePages];
    _performingLayout = NO;
    
}

- (BOOL)presentingViewControllerPrefersStatusBarHidden {
    UIViewController *presenting = self.presentingViewController;
    if (presenting) {
        if ([presenting isKindOfClass:[UINavigationController class]]) {
            presenting = [(UINavigationController *)presenting topViewController];
        }
    } else {
        // We're in a navigation controller so get previous one!
        if (self.navigationController && self.navigationController.viewControllers.count > 1) {
            presenting = [self.navigationController.viewControllers objectAtIndex:self.navigationController.viewControllers.count-2];
        }
    }
    if (presenting) {
        return [presenting prefersStatusBarHidden];
    } else {
        return NO;
    }
}

#pragma mark - Appearance

- (void)viewWillAppear:(BOOL)animated {
    
	// Super
	[super viewWillAppear:animated];
    
    // Status bar
    if (!_viewHasAppearedInitially) {
        _leaveStatusBarAlone = [self presentingViewControllerPrefersStatusBarHidden];
        // Check if status bar is hidden on first appear, and if so then ignore it
        if (CGRectEqualToRect([[UIApplication sharedApplication] statusBarFrame], CGRectZero)) {
            _leaveStatusBarAlone = YES;
        }
    }
    // Set style
    if (!_leaveStatusBarAlone && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        _previousStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:animated];
    }
    
    // Navigation bar appearance
    if (!_viewIsActive && [self.navigationController.viewControllers objectAtIndex:0] != self) {
        [self storePreviousNavBarAppearance];
    }
    [self setNavBarAppearance:animated];
    
    // Update UI
	[self hideControlsAfterDelay];
    
    // Initial appearance
    if (!_viewHasAppearedInitially) {
        if (_startOnGrid) {
            [self showGrid:NO];
        }
    }
    
    // If rotation occured while we're presenting a modal
    // and the index changed, make sure we show the right one now
    if (_currentPageIndex != _pageIndexBeforeRotation) {
        [self jumpToPageAtIndex:_pageIndexBeforeRotation animated:NO];
    }
    
    // Layout
/***** BEGIN THREEMA MODIFICATION: ios 11 bugfix *********/
    [self layoutVisiblePages];
/***** END THREEMA MODIFICATION: ios 11 bu gfix *********/
    [self.view setNeedsLayout];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsActive = YES;
    
    // Autoplay if first is video
    if (!_viewHasAppearedInitially) {
        if (_autoPlayOnAppear) {
            MWPhoto *photo = [self photoAtIndex:_currentPageIndex];
            if ([photo respondsToSelector:@selector(isVideo)] && photo.isVideo) {
                [self playVideoAtIndex:_currentPageIndex];
            }
        }
    }
    
    _viewHasAppearedInitially = YES;        
}

/***** BEGIN THREEMA MODIFICATION: show controls/status bar when moving into background to avoid iOS 8 back button bug *********/
- (void)applicationDidEnterBackground:(NSNotification*)notification {
    [self setControlsHidden:NO animated:NO permanent:YES];
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    [self hideControlsAfterDelay];
}
/***** END THREEMA MODIFICATION: show controls/status bar when moving into background to avoid iOS 8 back button bug *********/

- (void)viewWillDisappear:(BOOL)animated {
    
    // Detect if rotation occurs while we're presenting a modal
    _pageIndexBeforeRotation = _currentPageIndex;
    
    // Check that we're disappearing for good
    // self.isMovingFromParentViewController just doesn't work, ever. Or self.isBeingDismissed
    if ((_doneButton && self.navigationController.isBeingDismissed) ||
        ([self.navigationController.viewControllers objectAtIndex:0] != self && ![self.navigationController.viewControllers containsObject:self])) {

        // State
        _viewIsActive = NO;
        [self clearCurrentVideo: true]; // Clear current playing video
        
        // Bar state / appearance
        [self restorePreviousNavBarAppearance:animated];
        
    }
    
    // Controls
    [self.navigationController.navigationBar.layer removeAllAnimations]; // Stop all animations on nav bar
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // Cancel any pending toggles from taps
    [self setControlsHidden:NO animated:NO permanent:YES];
    
    // Status bar
    if (!_leaveStatusBarAlone && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:animated];
    }
    
	// Super
	[super viewWillDisappear:animated];
    
}

///***** BEGIN THREEMA MODIFICATION: show controls/status bar when moving into background to avoid iOS 8 back button bug *********/
//- (void)applicationDidEnterBackground:(NSNotification*)notification {
//    [self setControlsHidden:NO animated:NO permanent:YES];
//}
//
//- (void)applicationWillEnterForeground:(NSNotification*)notification {
//        [self hideControlsAfterDelay];
//}
///***** END THREEMA MODIFICATION: show controls/status bar when moving into background to avoid iOS 8 back button bug *********/

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (parent && _hasBelongedToViewController) {
        [NSException raise:@"MWPhotoBrowser Instance Reuse" format:@"MWPhotoBrowser instances cannot be reused."];
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (!parent) _hasBelongedToViewController = YES;
}

#pragma mark - Nav Bar Appearance

- (void)setNavBarAppearance:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.tintColor = [UIColor whiteColor];
    navBar.barTintColor = nil;
    /***** BEGINN THREEMA MODIFICATION *********/
    navBar.shadowImage = nil;
    navBar.translucent = YES;
    /***** END THREEMA MODIFICATION *********/
    navBar.barStyle = UIBarStyleBlack;
    navBar.translucent = YES;
    [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsCompact];
    /***** BEGIN THREEMA MODIFICATION: adapt to own style *********/
    self.navigationItem.scrollEdgeAppearance = [Colors defaultNavigationBarAppearance];
    /***** END THREEMA MODIFICATION *********/
}

- (void)storePreviousNavBarAppearance {
    _didSavePreviousStateOfNavBar = YES;
    _previousNavBarBarTintColor = self.navigationController.navigationBar.barTintColor;
    _previousNavBarTranslucent = self.navigationController.navigationBar.translucent;
    _previousNavBarTintColor = self.navigationController.navigationBar.tintColor;
    _previousNavBarHidden = self.navigationController.navigationBarHidden;
    _previousNavBarStyle = self.navigationController.navigationBar.barStyle;
    _previousNavigationBarBackgroundImageDefault = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault];
    _previousNavigationBarBackgroundImageLandscapePhone = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsCompact];
}

- (void)restorePreviousNavBarAppearance:(BOOL)animated {
    if (_didSavePreviousStateOfNavBar) {
        [self.navigationController setNavigationBarHidden:_previousNavBarHidden animated:animated];
        UINavigationBar *navBar = self.navigationController.navigationBar;
        navBar.tintColor = _previousNavBarTintColor;
        navBar.translucent = _previousNavBarTranslucent;
        navBar.barTintColor = _previousNavBarBarTintColor;
        navBar.barStyle = _previousNavBarStyle;
        [navBar setBackgroundImage:_previousNavigationBarBackgroundImageDefault forBarMetrics:UIBarMetricsDefault];
        [navBar setBackgroundImage:_previousNavigationBarBackgroundImageLandscapePhone forBarMetrics:UIBarMetricsCompact];
        // Restore back button if we need to
        if (_previousViewControllerBackButton) {
            UIViewController *previousViewController = [self.navigationController topViewController]; // We've disappeared so previous is now top
            previousViewController.navigationItem.backBarButtonItem = _previousViewControllerBackButton;
            _previousViewControllerBackButton = nil;
        }
    }
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
}

- (void)layoutVisiblePages {
    
	// Flag
	_performingLayout = YES;
	
	// Toolbar
	_toolbar.frame = [self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
    _gridToolbar.frame = [self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
    
	// Remember index
	NSUInteger indexPriorToLayout = _currentPageIndex;
	
	// Get paging scroll view frame to determine if anything needs changing
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    
	// Frame needs changing
    if (!_skipNextPagingScrollViewPositioning) {
        _pagingScrollView.frame = pagingScrollViewFrame;
    }
    _skipNextPagingScrollViewPositioning = NO;
	
	// Recalculate contentSize based on current orientation
	_pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	
	// Adjust frames and configuration of each visible page
	for (MWZoomingScrollView *page in _visiblePages) {
        NSUInteger index = page.index;
		page.frame = [self frameForPageAtIndex:index];
        if (page.captionView) {
            page.captionView.frame = [self frameForCaptionView:page.captionView atIndex:index];
        }
        if (page.selectedButton) {
            page.selectedButton.frame = [self frameForSelectedButton:page.selectedButton atIndex:index];
        }
        if (page.playButton) {
            page.playButton.frame = [self frameForPlayButton:page.playButton atIndex:index];
        }
        
        // Adjust scales if bounds has changed since last time
        if (!CGRectEqualToRect(_previousLayoutBounds, self.view.bounds)) {
            // Update zooms for new bounds
            [page setMaxMinZoomScalesForCurrentBounds];
            _previousLayoutBounds = self.view.bounds;
        }

	}
    
    // Adjust video loading indicator if it's visible
    [self positionVideoLoadingIndicator];
	
	// Adjust contentOffset to preserve page location based on values collected prior to location
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
	[self didStartViewingPageAtIndex:_currentPageIndex]; // initial
    
	// Reset
	_currentPageIndex = indexPriorToLayout;
	_performingLayout = NO;
    
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
	// Remember page index before rotation
	_pageIndexBeforeRotation = _currentPageIndex;
	_rotating = YES;
    
    /***** BEGIN THREEMA MODIFICATION: Remove this code, its not needed anymore *********/
    // In iOS 7 the nav bar gets shown after rotation, but might as well do this for everything!
//    if ([self areControlsHidden]) {
//        // Force hidden
//        self.navigationController.navigationBarHidden = YES;
//    }
    /***** END THREEMA MODIFICATION: Remove this code, its not needed anymore 8.0 *********/
	
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	
	// Perform layout
	_currentPageIndex = _pageIndexBeforeRotation;
	
	// Delay control holding
	[self hideControlsAfterDelay];
    
    // Layout
    [self layoutVisiblePages];
	
    /***** BEGIN THREEMA MODIFICATION: refresh status bar visibility when rotating on iOS 8.0 *********/
    [self setNeedsStatusBarAppearanceUpdate];
    /***** END THREEMA MODIFICATION: refresh status bar visibility when rotating on iOS 8.0 *********/
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	_rotating = NO;
    // Ensure nav bar isn't re-displayed
    if ([self areControlsHidden]) {
        self.navigationController.navigationBarHidden = NO;
        self.navigationController.navigationBar.alpha = 0;
    }
}

#pragma mark - Data

- (NSUInteger)currentIndex {
    return _currentPageIndex;
}

/***** BEGIN THREEMA MODIFICATION: update for delete files *********/
- (void)reloadData:(BOOL)updateLayout {
    
    // Reset
    _photoCount = NSNotFound;
    
    // Get data
    NSUInteger numberOfPhotos = [self numberOfPhotos];
    [self releaseAllUnderlyingPhotos:YES];
    [_photos removeAllObjects];
    [_thumbPhotos removeAllObjects];
    for (int i = 0; i < numberOfPhotos; i++) {
        [_photos addObject:[NSNull null]];
        [_thumbPhotos addObject:[NSNull null]];
    }

    // Update current page index
    if (numberOfPhotos > 0) {
        _currentPageIndex = MAX(0, MIN(_currentPageIndex, numberOfPhotos - 1));
    } else {
        _currentPageIndex = 0;
    }
    
    if (_gridController) {
        _toolbar.alpha = 0.0;
    }
    
    // Update layout
    if ([self isViewLoaded] && updateLayout) {
        _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
        
        while (_pagingScrollView.subviews.count) {
            [[_pagingScrollView.subviews lastObject] removeFromSuperview];
        }
        [self performLayout];
        [self.view setNeedsLayout];
    }
}
/***** END THREEMA MODIFICATION: update for delete files *********/

- (NSUInteger)numberOfPhotos {
    if (_photoCount == NSNotFound) {
        if ([_delegate respondsToSelector:@selector(numberOfPhotosInPhotoBrowser:)]) {
            _photoCount = [_delegate numberOfPhotosInPhotoBrowser:self];
        } else if (_fixedPhotosArray) {
            _photoCount = _fixedPhotosArray.count;
        }
    }
    if (_photoCount == NSNotFound) _photoCount = 0;
    return _photoCount;
}

- (id<MWPhoto>)photoAtIndex:(NSUInteger)index {
    id <MWPhoto> photo = nil;
    if (index < _photos.count) {
        if ([_photos objectAtIndex:index] == [NSNull null]) {
            if ([_delegate respondsToSelector:@selector(photoBrowser:photoAtIndex:)]) {
                photo = [_delegate photoBrowser:self photoAtIndex:index];
            } else if (_fixedPhotosArray && index < _fixedPhotosArray.count) {
                photo = [_fixedPhotosArray objectAtIndex:index];
            }
            if (photo) [_photos replaceObjectAtIndex:index withObject:photo];
        } else {
            photo = [_photos objectAtIndex:index];
        }
    }
    return photo;
}

- (id<MWPhoto>)thumbPhotoAtIndex:(NSUInteger)index {
    id <MWPhoto> photo = nil;
    if (index < _thumbPhotos.count) {
        if ([_thumbPhotos objectAtIndex:index] == [NSNull null]) {
            if ([_delegate respondsToSelector:@selector(photoBrowser:thumbPhotoAtIndex:)]) {
                photo = [_delegate photoBrowser:self thumbPhotoAtIndex:index];
            }
            if (photo) [_thumbPhotos replaceObjectAtIndex:index withObject:photo];
        } else {
            photo = [_thumbPhotos objectAtIndex:index];
        }
    }
    return photo;
}

- (MWCaptionView *)captionViewForPhotoAtIndex:(NSUInteger)index {
    MWCaptionView *captionView = nil;
    if ([_delegate respondsToSelector:@selector(photoBrowser:captionViewForPhotoAtIndex:)]) {
        captionView = [_delegate photoBrowser:self captionViewForPhotoAtIndex:index];
    } else {
        id <MWPhoto> photo = [self photoAtIndex:index];
        if ([photo respondsToSelector:@selector(caption)]) {
            if ([photo caption]) captionView = [[MWCaptionView alloc] initWithPhoto:photo];
        }
    }
    captionView.alpha = [self areControlsHidden] ? 0 : 1; // Initial alpha
    return captionView;
}

- (BOOL)photoIsSelectedAtIndex:(NSUInteger)index {
    BOOL value = NO;
    if (_displaySelectionButtons) {
        if ([self.delegate respondsToSelector:@selector(photoBrowser:isPhotoSelectedAtIndex:)]) {
            value = [self.delegate photoBrowser:self isPhotoSelectedAtIndex:index];
        }
    }
    return value;
}

- (void)setPhotoSelected:(BOOL)selected atIndex:(NSUInteger)index {
    if (_displaySelectionButtons) {
        if ([self.delegate respondsToSelector:@selector(photoBrowser:photoAtIndex:selectedChanged:)]) {
            [self.delegate photoBrowser:self photoAtIndex:index selectedChanged:selected];
        }
        if ([self.delegate respondsToSelector:@selector(mediaSelectionCount)]) {
            NSUInteger *selectionCount = [self.delegate mediaSelectionCount];
            _deleteMultipleButton.enabled = selectionCount > 0;
            _actionMultipleButton.enabled = selectionCount > 0;
        }
    }
}

- (UIImage *)imageForPhoto:(id<MWPhoto>)photo {
	if (photo) {
		// Get image or obtain in background
		if ([photo underlyingImage]) {
			return [photo underlyingImage];
		} else {
            [photo loadUnderlyingImageAndNotify];
		}
	}
	return nil;
}

- (void)loadAdjacentPhotosIfNecessary:(id<MWPhoto>)photo {
    MWZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        // If page is current page then initiate loading of previous and next pages
        NSUInteger pageIndex = page.index;
        if (_currentPageIndex == pageIndex) {
            if (pageIndex > 0) {
                // Preload index - 1
                id <MWPhoto> photo = [self photoAtIndex:pageIndex-1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    MWLog(@"Pre-loading image at index %lu", (unsigned long)pageIndex-1);
                }
            }
            if (pageIndex < [self numberOfPhotos] - 1) {
                // Preload index + 1
                id <MWPhoto> photo = [self photoAtIndex:pageIndex+1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    MWLog(@"Pre-loading image at index %lu", (unsigned long)pageIndex+1);
                }
            }
        }
    }
}

#pragma mark - MWPhoto Loading Notification

- (void)handleMWPhotoLoadingDidEndNotification:(NSNotification *)notification {
    id <MWPhoto> photo = [notification object];
    MWZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        if ([photo underlyingImage]) {
            // Successful load
            [page displayImage];
            [self loadAdjacentPhotosIfNecessary:photo];
        } else {
            
            // Failed to load
            [page displayImageFailure];
        }
        // Update nav
        [self updateNavigation];
    }
}

#pragma mark - Paging

- (void)tilePages {
	
	// Calculate which pages should be visible
	// Ignore padding as paging bounces encroach on that
	// and lead to false page loads
	CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger iFirstIndex = (NSInteger)floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
	NSInteger iLastIndex  = (NSInteger)floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > [self numberOfPhotos] - 1) iFirstIndex = [self numberOfPhotos] - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > [self numberOfPhotos] - 1) iLastIndex = [self numberOfPhotos] - 1;
	
//    // Recycle no longer needed pages
    NSInteger pageIndex;
    for (MWZoomingScrollView *page in _visiblePages) {
        pageIndex = page.index;
        if (pageIndex < (NSUInteger)iFirstIndex || pageIndex > (NSUInteger)iLastIndex) {
            [_recycledPages addObject:page];
            [page.captionView removeFromSuperview];
            [page.selectedButton removeFromSuperview];
            [page.playButton removeFromSuperview];
            [page prepareForReuse];
            [page removeFromSuperview];
            MWLog(@"Removed page at index %lu", (unsigned long)pageIndex);
        }
    }
    [_visiblePages minusSet:_recycledPages];
    while (_recycledPages.count > 2) // Only keep 2 recycled pages
        [_recycledPages removeObject:[_recycledPages anyObject]];
	
	// Add missing pages
	for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
		if (![self isDisplayingPageForIndex:index]) {
            
            // Add new page
            MWZoomingScrollView *page = [self dequeueRecycledPage];
            if (!page) {
                page = [[MWZoomingScrollView alloc] initWithPhotoBrowser:self];
            }
            [_visiblePages addObject:page];
			[self configurePage:page forIndex:index];

			[_pagingScrollView addSubview:page];
			MWLog(@"Added page at index %lu", (unsigned long)index);
            
            // Add caption
            MWCaptionView *captionView = [self captionViewForPhotoAtIndex:index];
            if (captionView) {
                captionView.frame = [self frameForCaptionView:captionView atIndex:index];
                [_pagingScrollView addSubview:captionView];
                page.captionView = captionView;
            }
            
            // Add play button if needed
            if (page.displayingVideo) {
                UIButton *playButton = [UIButton buttonWithType:UIButtonTypeCustom];
                [playButton setImage:[UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/PlayButtonOverlayLarge" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]] forState:UIControlStateNormal];
                [playButton setImage:[UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/PlayButtonOverlayLargeTap" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]] forState:UIControlStateHighlighted];
                [playButton addTarget:self action:@selector(playButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
                [playButton sizeToFit];
                playButton.frame = [self frameForPlayButton:playButton atIndex:index];
                [_pagingScrollView addSubview:playButton];
                page.playButton = playButton;
            }
            
            // Add selected button
            if (self.displaySelectionButtons) {
                UIButton *selectedButton = [UIButton buttonWithType:UIButtonTypeCustom];
                [selectedButton setImage:[UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/ImageSelectedOff" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]] forState:UIControlStateNormal];
                UIImage *selectedOnImage;
                if (self.customImageSelectedIcon) {
                    ///***** BEGIN THREEMA MODIFICATION: use image instead of name *********/
                    selectedOnImage = self.customImageSelectedIcon;
                    ///***** END THREEMA MODIFICATION: use image instead of name *********/
                } else {
                    selectedOnImage = [UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/ImageSelectedOn" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]];
                }
                [selectedButton setImage:selectedOnImage forState:UIControlStateSelected];
                [selectedButton sizeToFit];
                selectedButton.adjustsImageWhenHighlighted = NO;
                [selectedButton addTarget:self action:@selector(selectedButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
                selectedButton.frame = [self frameForSelectedButton:selectedButton atIndex:index];
                [_pagingScrollView addSubview:selectedButton];
                page.selectedButton = selectedButton;
                selectedButton.selected = [self photoIsSelectedAtIndex:index];
                /***** BEGIN THREEMA MODIFICATION: *********/
                selectedButton.accessibilityLabel = NSLocalizedString(@"mwphotobrowser_select", nil);
                /***** END THREEMA MODIFICATION: *********/
            }
            
		}
	}
	
}

- (void)updateVisiblePageStates {
    NSSet *copy = [_visiblePages copy];
    for (MWZoomingScrollView *page in copy) {
        
        // Update selection
        page.selectedButton.selected = [self photoIsSelectedAtIndex:page.index];
        
    }
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
	for (MWZoomingScrollView *page in _visiblePages)
		if (page.index == index) return YES;
	return NO;
}

- (MWZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index {
	MWZoomingScrollView *thePage = nil;
	for (MWZoomingScrollView *page in _visiblePages) {
		if (page.index == index) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (MWZoomingScrollView *)pageDisplayingPhoto:(id<MWPhoto>)photo {
	MWZoomingScrollView *thePage = nil;
	for (MWZoomingScrollView *page in _visiblePages) {
		if (page.photo == photo) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (void)configurePage:(MWZoomingScrollView *)page forIndex:(NSUInteger)index {
	page.frame = [self frameForPageAtIndex:index];
    page.index = index;
    page.photo = [self photoAtIndex:index];
}

- (MWZoomingScrollView *)dequeueRecycledPage {
	MWZoomingScrollView *page = [_recycledPages anyObject];
	if (page) {
		[_recycledPages removeObject:page];
	}
	return page;
}

// Handle page changes
- (void)didStartViewingPageAtIndex:(NSUInteger)index {
    
    // Handle 0 photos
    if (![self numberOfPhotos]) {
        // Show controls
        [self setControlsHidden:NO animated:YES permanent:YES];
        return;
    }
    
    // Handle video on page change
    if (!_rotating && index != _currentVideoIndex) {
        [self clearCurrentVideo: true];
    }
    
    // Release images further away than +/-1
    NSUInteger i;
    if (index > 0) {
        // Release anything < index - 1
        for (i = 0; i < index-1; i++) { 
            id photo = [_photos objectAtIndex:i];
            if (photo != [NSNull null]) {
                [photo unloadUnderlyingImage];
                [_photos replaceObjectAtIndex:i withObject:[NSNull null]];
                MWLog(@"Released underlying image at index %lu", (unsigned long)i);
            }
        }
    }
    if (index < [self numberOfPhotos] - 1) {
        // Release anything > index + 1
        for (i = index + 2; i < _photos.count; i++) {
            id photo = [_photos objectAtIndex:i];
            if (photo != [NSNull null]) {
                [photo unloadUnderlyingImage];
                [_photos replaceObjectAtIndex:i withObject:[NSNull null]];
                MWLog(@"Released underlying image at index %lu", (unsigned long)i);
            }
        }
    }
    
    // Load adjacent images if needed and the photo is already
    // loaded. Also called after photo has been loaded in background
    id <MWPhoto> currentPhoto = [self photoAtIndex:index];
    if ([currentPhoto underlyingImage]) {
        // photo loaded so load ajacent now
        [self loadAdjacentPhotosIfNecessary:currentPhoto];
    }
    
    /***** BEGIN THREEMA MODIFICATION: always show controls for video *********/
    if ([currentPhoto showControls] && !_peeking) {
        [self setControlsHidden:NO animated:YES permanent:YES];
    } else {
        [self hideControlsAfterDelay];
    }
    /***** END THREEMA MODIFICATION: always show controls for video *********/
    
    // Notify delegate
    if (index != _previousPageIndex) {
        if ([_delegate respondsToSelector:@selector(photoBrowser:didDisplayPhotoAtIndex:)])
            [_delegate photoBrowser:self didDisplayPhotoAtIndex:index];
        _previousPageIndex = index;
    }
    
    // Update nav
    [self updateNavigation];
    
}

#pragma mark - Frame Calculations

- (CGRect)frameForPagingScrollView {
    CGRect frame = self.view.bounds;// [[UIScreen mainScreen] bounds];
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return CGRectIntegral(frame);
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = _pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return CGRectIntegral(pageFrame);
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = _pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self numberOfPhotos], bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index {
	CGFloat pageWidth = _pagingScrollView.bounds.size.width;
	CGFloat newOffset = index * pageWidth;
	return CGPointMake(newOffset, 0);
}

- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation {
    CGFloat height = 44;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape(orientation)) height = 32;
    CGFloat adjust = 0;
    if (@available(iOS 11.0, *)) {
        //Account for possible notch
        /***** BEGIN THREEMA MODIFICATION: Use windows instead of keyWindow *********/
        UIEdgeInsets safeArea = [[[UIApplication sharedApplication] windows] firstObject].safeAreaInsets;
        /***** END THREEMA MODIFICATION: Use windows instead of keyWindow *********/
        adjust = safeArea.bottom;
    }
    return CGRectIntegral(CGRectMake(0, self.view.bounds.size.height - height - adjust, self.view.bounds.size.width, height));
}

- (CGRect)frameForCaptionView:(MWCaptionView *)captionView atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    CGSize captionSize = [captionView sizeThatFits:CGSizeMake(pageFrame.size.width, 0)];
    CGRect toolBarRect = [self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
    CGRect captionFrame = CGRectMake(pageFrame.origin.x,
                                     toolBarRect.origin.y - captionSize.height,
                                     pageFrame.size.width,
                                     captionSize.height);
    return CGRectIntegral(captionFrame);
}

- (CGRect)frameForSelectedButton:(UIButton *)selectedButton atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    CGFloat padding = 20;
    CGFloat yOffset = 0;
    if (![self areControlsHidden]) {
        UINavigationBar *navBar = self.navigationController.navigationBar;
        yOffset = navBar.frame.origin.y + navBar.frame.size.height;
    }
    /***** BEGIN THREEMA MODIFICATION: change button to bottom right instead of top right *********/
    CGRect selectedButtonFrame = CGRectMake(pageFrame.origin.x + pageFrame.size.width - selectedButton.frame.size.width - padding,
                                            pageFrame.origin.y + pageFrame.size.height - selectedButton.frame.size.height - padding,
                                            selectedButton.frame.size.width,
                                            selectedButton.frame.size.height);
    /***** END THREEMA MODIFICATION: change button to bottom right instead of top right *********/
    return CGRectIntegral(selectedButtonFrame);
}

- (CGRect)frameForPlayButton:(UIButton *)playButton atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    return CGRectMake(floorf(CGRectGetMidX(pageFrame) - playButton.frame.size.width / 2),
                      floorf(CGRectGetMidY(pageFrame) - playButton.frame.size.height / 2),
                      playButton.frame.size.width,
                      playButton.frame.size.height);
}

#pragma mark - UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	
    // Checks
	if (!_viewIsActive || _performingLayout || _rotating) return;
	
	// Tile pages
    [self tilePages];
	
	// Calculate current page
	CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger index = (NSInteger)(floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
	if (index > [self numberOfPhotos] - 1) index = [self numberOfPhotos] - 1;
	NSUInteger previousCurrentPage = _currentPageIndex;
	_currentPageIndex = index;
	if (_currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];
    }
	
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	// Hide controls when dragging begins
    /***** BEGIN THREEMA MODIFICATION: do not hide controls when begin dragging *********/
//	[self setControlsHidden:YES animated:YES permanent:NO];
    /***** END THREEMA MODIFICATION: do not hide controls when begin dragging *********/
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	// Update nav when page changes
	[self updateNavigation];
}

#pragma mark - Navigation

- (void)updateNavigation {
    
	// Title
    NSUInteger numberOfPhotos = [self numberOfPhotos];
    if (_gridController) {
        if (_gridController.selectionMode) {
            self.title = NSLocalizedString(@"Select Photos", nil);
        } else {
            NSString *photosText;
            if (numberOfPhotos == 1) {
                photosText = NSLocalizedString(@"photo", @"Used in the context: '1 photo'");
            } else {
                photosText = NSLocalizedString(@"photos", @"Used in the context: '3 photos'");
            }
            self.title = [NSString stringWithFormat:@"%lu %@", (unsigned long)numberOfPhotos, photosText];
        }
    } else if (numberOfPhotos > 1) {
        if ([_delegate respondsToSelector:@selector(photoBrowser:titleForPhotoAtIndex:)]) {
            self.title = [_delegate photoBrowser:self titleForPhotoAtIndex:_currentPageIndex];
        } else {
            self.title = [NSString stringWithFormat:@"%lu %@ %lu", (unsigned long)(_currentPageIndex+1), NSLocalizedString(@"of", @"Used in the context: 'Showing 1 of 3 items'"), (unsigned long)numberOfPhotos];
        }
	} else {
		self.title = nil;
	}
	
	// Buttons
	_previousButton.enabled = (_currentPageIndex > 0);
	_nextButton.enabled = (_currentPageIndex < numberOfPhotos - 1);
    
//    // Disable action button if there is no image or it's a video
//    MWPhoto *photo = [self photoAtIndex:_currentPageIndex];
//    if ([photo underlyingImage] == nil || ([photo respondsToSelector:@selector(isVideo)] && photo.isVideo)) {
//        _actionButton.enabled = NO;
//        _actionButton.tintColor = [UIColor clearColor]; // Tint to hide button
//    } else {
//        _actionButton.enabled = YES;
//        _actionButton.tintColor = nil;
//    }
	
}

- (void)jumpToPageAtIndex:(NSUInteger)index animated:(BOOL)animated {
	
	// Change page
	if (index < [self numberOfPhotos]) {
		CGRect pageFrame = [self frameForPageAtIndex:index];
        [_pagingScrollView setContentOffset:CGPointMake(pageFrame.origin.x - PADDING, 0) animated:animated];
		[self updateNavigation];
	}
	
	// Update timer to give more time
	[self hideControlsAfterDelay];
	
}

- (void)gotoPreviousPage {
    [self showPreviousPhotoAnimated:NO];
}
- (void)gotoNextPage {
    [self showNextPhotoAnimated:NO];
}

- (void)showPreviousPhotoAnimated:(BOOL)animated {
    [self jumpToPageAtIndex:_currentPageIndex-1 animated:animated];
}

- (void)showNextPhotoAnimated:(BOOL)animated {
    [self jumpToPageAtIndex:_currentPageIndex+1 animated:animated];
}

#pragma mark - Interactions

- (void)selectedButtonTapped:(id)sender {
    UIButton *selectedButton = (UIButton *)sender;
    selectedButton.selected = !selectedButton.selected;
    NSUInteger index = NSUIntegerMax;
    for (MWZoomingScrollView *page in _visiblePages) {
        if (page.selectedButton == selectedButton) {
            index = page.index;
            break;
        }
    }
    if (index != NSUIntegerMax) {
        [self setPhotoSelected:selectedButton.selected atIndex:index];
    }
}

- (void)playButtonTapped:(id)sender {
    // Ignore if we're already playing a video
    if (_currentVideoIndex != NSUIntegerMax) {
        return;
    }
    NSUInteger index = [self indexForPlayButton:sender];
    if (index != NSUIntegerMax) {
        if (!_currentVideoPlayerViewController) {
            [self playVideoAtIndex:index];
        }
    }
}

- (NSUInteger)indexForPlayButton:(UIView *)playButton {
    NSUInteger index = NSUIntegerMax;
    for (MWZoomingScrollView *page in _visiblePages) {
        if (page.playButton == playButton) {
            index = page.index;
            break;
        }
    }
    return index;
}

#pragma mark - Video

- (void)playVideoAtIndex:(NSUInteger)index {
    id photo = [self photoAtIndex:index];
    if ([photo respondsToSelector:@selector(getVideoURL:)]) {
        
        // Valid for playing
        [self clearCurrentVideo: true];
        _currentVideoIndex = index;
        [self setVideoLoadingIndicatorVisible:YES atPageIndex:index];
        
        ///***** BEGIN THREEMA MODIFICATION: ignore mute switch *********/
        NSInteger state = [[VoIPCallStateManager shared] currentCallState];
        if (state == CallStateIdle) {
            _prevAudioCategory = [[AVAudioSession sharedInstance] category];
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        }
        ///***** END THREEMA MODIFICATION: ignore mute switch *********/

        // Get video and play
        typeof(self) __weak weakSelf = self;
        [photo getVideoURL:^(NSURL *url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // If the video is not playing anymore then bail
                typeof(self) strongSelf = weakSelf;
                if (!strongSelf) return;
                if (strongSelf->_currentVideoIndex != index || !strongSelf->_viewIsActive) {
                    return;
                }
                if (url) {
                    [weakSelf _playVideo:url atPhotoIndex:index];
                } else {
                    if ([_delegate respondsToSelector:@selector(photoBrowser:objectIDAtIndex:)]) {
                       NSManagedObjectID * objectID = [_delegate photoBrowser:self objectIDAtIndex:index];
                        BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
                        [manager syncBlobsFor:objectID onCompletion:^(enum BlobManagerObjCResult result){
                            NSAssert(result != BlobManagerObjCResultUploaded, @"We never upload a file in this case");
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [weakSelf setVideoLoadingIndicatorVisible:NO atPageIndex:index];
                                [weakSelf playVideoAtIndex:index];
                            });
                        }];
                    } else  {
                        [weakSelf setVideoLoadingIndicatorVisible:NO atPageIndex:index];
                    }
                }
            });
        }];
        
    }
}

- (void)_playVideo:(NSURL *)videoURL atPhotoIndex:(NSUInteger)index {

    AVPlayer *player = [AVPlayer playerWithURL:videoURL];
    _currentVideoPlayerViewController = [AVPlayerViewController new];
    _currentVideoPlayerViewController.player = player;
    ///***** BEGIN THREEMA MODIFICATION: ignore mute switch *********/
    _currentVideoPlayerViewController.delegate = self;
    ///***** END THREEMA MODIFICATION: ignore mute switch *********/
    [self presentViewController:_currentVideoPlayerViewController animated:YES completion:^{
        [_currentVideoPlayerViewController.player play];
        [self clearCurrentVideo: false];
    }];
}

///***** BEGIN THREEMA MODIFICATION: reset audio *********/
- (void)clearCurrentVideo:(BOOL)audioFree {
    [_currentVideoLoadingIndicator removeFromSuperview];
    _currentVideoPlayerViewController = nil;
    _currentVideoLoadingIndicator = nil;
    [[self pageDisplayedAtIndex:_currentVideoIndex] playButton].hidden = NO;
    _currentVideoIndex = NSUIntegerMax;
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (audioFree == true && state == CallStateIdle) {
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}
///***** END THREEMA MODIFICATION: reset audio *********/

- (void)setVideoLoadingIndicatorVisible:(BOOL)visible atPageIndex:(NSUInteger)pageIndex {
    if (_currentVideoLoadingIndicator && !visible) {
        [_currentVideoLoadingIndicator removeFromSuperview];
        _currentVideoLoadingIndicator = nil;
        [[self pageDisplayedAtIndex:pageIndex] playButton].hidden = NO;
    } else if (!_currentVideoLoadingIndicator && visible) {
        _currentVideoLoadingIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
        [_currentVideoLoadingIndicator sizeToFit];
        [_currentVideoLoadingIndicator startAnimating];
        [_pagingScrollView addSubview:_currentVideoLoadingIndicator];
        [self positionVideoLoadingIndicator];
        [[self pageDisplayedAtIndex:pageIndex] playButton].hidden = YES;
    }
}

- (void)positionVideoLoadingIndicator {
    if (_currentVideoLoadingIndicator && _currentVideoIndex != NSUIntegerMax) {
        CGRect frame = [self frameForPageAtIndex:_currentVideoIndex];
        _currentVideoLoadingIndicator.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    }
}

#pragma mark - Grid

- (void)showGridAnimated {
    [self showGrid:YES];
}

- (void)showGrid:(BOOL)animated {

    if (_gridController) return;
    
    // Clear video
    [self clearCurrentVideo: true];
    
    // Init grid controller
    _gridController = [[MWGridViewController alloc] init];
    
    /***** BEGIN THREEMA MODIFICATION: add select button *********/
    _selectButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"mwphotobrowser_select"] style:UIBarButtonItemStylePlain target:self action:@selector(selectButtonPressed:)];
    _selectButton.enabled = [self numberOfPhotos] > 0;
    self.navigationItem.rightBarButtonItem = _selectButton;
    /***** END THREEMA MODIFICATION: add select button *********/
    
    _gridController.browser = self;
    _gridController.selectionMode = _displaySelectionButtons;
    _gridController.view.frame = self.view.bounds;
    _gridController.view.frame = CGRectOffset(_gridController.view.frame, 0, (self.startOnGrid ? -1 : 1) * self.view.bounds.size.height);

    // Stop specific layout being triggered
    _skipNextPagingScrollViewPositioning = YES;
    
    // Add as a child view controller
    [self addChildViewController:_gridController];
    [self.view addSubview:_gridController.view];
    
    // Perform any adjustments
    [_gridController.view layoutIfNeeded];
    [_gridController adjustOffsetsAsRequired];
    
    // Hide action button on nav bar if it exists
    if (self.navigationItem.rightBarButtonItem == _actionButton) {
        _gridPreviousRightNavItem = _actionButton;
        [self.navigationItem setRightBarButtonItem:nil animated:YES];
    } else {
        _gridPreviousRightNavItem = nil;
    }
    
    // Update
    [self updateNavigation];
    [self setControlsHidden:NO animated:YES permanent:YES];
    
    // Animate grid in and photo scroller out
    [_gridController willMoveToParentViewController:self];
    [UIView animateWithDuration:animated ? 0.3 : 0 animations:^(void) {
        _gridController.view.frame = self.view.bounds;
        CGRect newPagingFrame = [self frameForPagingScrollView];
        newPagingFrame = CGRectOffset(newPagingFrame, 0, (self.startOnGrid ? 1 : -1) * newPagingFrame.size.height);
        _pagingScrollView.frame = newPagingFrame;
    } completion:^(BOOL finished) {
        [_gridController didMoveToParentViewController:self];
    }];
    
}

- (void)hideGrid {
    
    if (!_gridController) return;
    
    /***** BEGIN THREEMA MODIFICATION: add select button *********/
    self.navigationItem.rightBarButtonItem = nil;
    /***** END THREEMA MODIFICATION: add select button *********/
    
    // Restore action button if it was removed
    if (_gridPreviousRightNavItem == _actionButton && _actionButton) {
        [self.navigationItem setRightBarButtonItem:_gridPreviousRightNavItem animated:YES];
    }
    
    // Position prior to hide animation
    CGRect newPagingFrame = [self frameForPagingScrollView];
    newPagingFrame = CGRectOffset(newPagingFrame, 0, (self.startOnGrid ? 1 : -1) * newPagingFrame.size.height);
    _pagingScrollView.frame = newPagingFrame;
    
    // Remember and remove controller now so things can detect a nil grid controller
    MWGridViewController *tmpGridController = _gridController;
    _gridController = nil;
    
    // Update
    [self updateNavigation];
    [self updateVisiblePageStates];
    
    // Animate, hide grid and show paging scroll view
    [UIView animateWithDuration:0.3 animations:^{
        tmpGridController.view.frame = CGRectOffset(self.view.bounds, 0, (self.startOnGrid ? -1 : 1) * self.view.bounds.size.height);
        _pagingScrollView.frame = [self frameForPagingScrollView];
    } completion:^(BOOL finished) {
        [tmpGridController willMoveToParentViewController:nil];
        [tmpGridController.view removeFromSuperview];
        [tmpGridController removeFromParentViewController];
        [self setControlsHidden:NO animated:YES permanent:NO]; // retrigger timer
    }];

}

#pragma mark - Control Hiding / Showing

// If permanent then we don't set timers to hide again
// Fades all controls on iOS 5 & 6, and iOS 7 controls slide and fade
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent {
    
    // Force visible
    if (![self numberOfPhotos] || _gridController || _alwaysShowControls)
        hidden = NO;
    
    /***** BEGIN THREEMA MODIFICATION: Hide toolbar only when it's a image *********/
    id currentFile = [self photoAtIndex:_currentPageIndex];
    if ([currentFile isKindOfClass:[MediaBrowserFile class]]) {
        MediaBrowserFile *mediaBrowserFile = (MediaBrowserFile *)currentFile;
        if (![mediaBrowserFile canHideToolBar]) {
            hidden = NO;
        }
    }
    /***** END THREEMA MODIFICATION: Hide toolbar only when it's a image *********/
    
    // Cancel any timers
    [self cancelControlHiding];
    
    // Animations & positions
    CGFloat animatonOffset = 20;
    CGFloat animationDuration = (animated ? 0.35 : 0);
    
    // Status bar
    if (!_leaveStatusBarAlone) {

        // Hide status bar
        if (!_isVCBasedStatusBarAppearance) {
            
            // Non-view controller based
            [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animated ? UIStatusBarAnimationSlide : UIStatusBarAnimationNone];
            
        } else {
            
            // View controller based so animate away
            _statusBarShouldBeHidden = hidden;
            [UIView animateWithDuration:animationDuration animations:^(void) {
                [self setNeedsStatusBarAppearanceUpdate];
            } completion:^(BOOL finished) {}];
            
        }

    }
    
    // Toolbar, nav bar and captions
    // Pre-appear animation positions for sliding
    if ([self areControlsHidden] && !hidden && animated) {
        
        // Toolbar
        _toolbar.frame = CGRectOffset([self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]], 0, animatonOffset);
        _gridToolbar.frame = CGRectOffset([self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]], 0, animatonOffset);
        
        // Captions
        for (MWZoomingScrollView *page in _visiblePages) {
            if (page.captionView) {
                MWCaptionView *v = page.captionView;
                // Pass any index, all we're interested in is the Y
                CGRect captionFrame = [self frameForCaptionView:v atIndex:0];
                captionFrame.origin.x = v.frame.origin.x; // Reset X
                v.frame = CGRectOffset(captionFrame, 0, animatonOffset);
            }
        }
    }
    [UIView animateWithDuration:animationDuration animations:^(void) {
        
        CGFloat alpha = hidden ? 0 : 1;

        // Nav bar slides up on it's own on iOS 7+
        [self.navigationController.navigationBar setAlpha:alpha];
        
        // Toolbar
        _toolbar.frame = [self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
        _gridToolbar.frame = [self frameForToolbarAtOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
        if (hidden) _toolbar.frame = CGRectOffset(_toolbar.frame, 0, animatonOffset);
        _toolbar.alpha = alpha;

        // Captions
        for (MWZoomingScrollView *page in _visiblePages) {
            if (page.captionView) {
                MWCaptionView *v = page.captionView;
                // Pass any index, all we're interested in is the Y
                CGRect captionFrame = [self frameForCaptionView:v atIndex:0];
                captionFrame.origin.x = v.frame.origin.x; // Reset X
                if (hidden) captionFrame = CGRectOffset(captionFrame, 0, animatonOffset);
                v.frame = captionFrame;
                v.alpha = alpha;
            }
        }
        
        // Selected buttons
        for (MWZoomingScrollView *page in _visiblePages) {
            if (page.selectedButton) {
                UIButton *v = page.selectedButton;
                CGRect newFrame = [self frameForSelectedButton:v atIndex:0];
                newFrame.origin.x = v.frame.origin.x;
                v.frame = newFrame;
            }
        }

    } completion:^(BOOL finished) {}];
    
	// Control hiding timer
	// Will cancel existing timer but only begin hiding if
	// they are visible
	if (!permanent) [self hideControlsAfterDelay];
	
}

- (BOOL)prefersStatusBarHidden {
    /***** BEGIN THREEMA MODIFICATION: always hide status bar in landscape mode on iOS 8.0 *********/
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
        return YES;
    }
    /***** END THREEMA MODIFICATION: always hide status bar in landscape mode on iOS 8.0 *********/

    if (!_leaveStatusBarAlone) {
        return _statusBarShouldBeHidden;
    } else {
        return [self presentingViewControllerPrefersStatusBarHidden];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationSlide;
}

- (void)cancelControlHiding {
	// If a timer exists then cancel and release
	if (_controlVisibilityTimer) {
		[_controlVisibilityTimer invalidate];
		_controlVisibilityTimer = nil;
	}
}

// Enable/disable control visiblity timer
- (void)hideControlsAfterDelay {
	if (![self areControlsHidden]) {
        [self cancelControlHiding];
		_controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:self.delayToHideElements target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
	}
}

- (BOOL)areControlsHidden { return (_toolbar.alpha == 0); }
- (void)hideControls { [self setControlsHidden:YES animated:YES permanent:NO]; }
- (void)showControls { [self setControlsHidden:NO animated:YES permanent:NO]; }
- (void)toggleControls { [self setControlsHidden:![self areControlsHidden] animated:YES permanent:NO]; } 

#pragma mark - Properties

- (void)setCurrentPhotoIndex:(NSUInteger)index {
    // Validate
    NSUInteger photoCount = [self numberOfPhotos];
    if (photoCount == 0) {
        index = 0;
    } else {
        if (index >= photoCount)
            index = [self numberOfPhotos]-1;
    }
    _currentPageIndex = index;
	if ([self isViewLoaded]) {
        [self jumpToPageAtIndex:index animated:NO];
        if (!_viewIsActive)
            [self tilePages]; // Force tiling if view is not visible
    }
}

#pragma mark - Misc

- (void)doneButtonPressed:(id)sender {
    // Only if we're modal and there's a done button
    if (_doneButton) {
        // Dismiss view controller
        if ([_delegate respondsToSelector:@selector(photoBrowserDidFinishModalPresentation:)]) {
            // Call delegate method and let them dismiss us
            [_delegate photoBrowserDidFinishModalPresentation:self];
        } else  {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - Actions

- (void)actionButtonPressed:(id)sender {

    // Only react when image has loaded
    id <MWPhoto> photo = [self photoAtIndex:_currentPageIndex];
    if ([self numberOfPhotos] > 0 && [photo underlyingImage]) {
        
        // If they have defined a delegate method then just message them
        if ([self.delegate respondsToSelector:@selector(photoBrowser:actionButtonPressedForPhotoAtIndex:)]) {
            // Let delegate handle things
            [self.delegate photoBrowser:self actionButtonPressedForPhotoAtIndex:_currentPageIndex];
        } else {
            // Share current photo
            [self shareMedia:photo];
        }
        
        // Keep controls hidden
        [self setControlsHidden:NO animated:YES permanent:YES];
    }
    
}

/***** BEGIN THREEMA MODIFICATION: add delete button *********/
- (void)deleteButtonPressed:(id)sender {
    if ([self numberOfPhotos] > 0) {
        if ([self.delegate respondsToSelector:@selector(photoBrowser:deleteButton:pressedForPhotoAtIndex:)]) {
            [self.delegate photoBrowser:self deleteButton:_deleteSingleButton pressedForPhotoAtIndex:_currentPageIndex];
        }
    }
}

- (void)selectButtonPressed:(id)sender {
    if (!self.displaySelectionButtons) {
        self.displaySelectionButtons = YES;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"mwphotobrowser_select_all"] style:UIBarButtonItemStylePlain target:self action:@selector(selectAllButtonPressed:)];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil) style:UIBarButtonItemStylePlain target:self action:@selector(selectButtonPressed:)];
        _deleteMultipleButton.enabled = false;
        _actionMultipleButton.enabled = false;
        [self.view addSubview:_gridToolbar];
    } else {
        self.displaySelectionButtons = NO;
        
        self.navigationItem.leftBarButtonItem = _doneButton;
        self.navigationItem.rightBarButtonItem = _selectButton;
        [_gridToolbar removeFromSuperview];
    }
    if ([self.delegate respondsToSelector:@selector(photoBrowserResetSelection:)]) {
        [self.delegate photoBrowserResetSelection:self];
    }

    [_gridController setSelectionMode:self.displaySelectionButtons];
    [[_gridController collectionView] reloadData];
}

- (void)selectAllButtonPressed:(id)sender {
    if ([self.delegate respondsToSelector:@selector(photoBrowserSelectAll:)]) {
        [self.delegate photoBrowserSelectAll:self];
    }
    [_gridController setSelectionMode:self.displaySelectionButtons];
    [[_gridController collectionView] reloadData];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"mwphotobrowser_deselect_all"] style:UIBarButtonItemStylePlain target:self action:@selector(deselectAllButtonPressed:)];
    _deleteMultipleButton.enabled = true;
    _actionMultipleButton.enabled = true;
}

- (void)deselectAllButtonPressed:(id)sender {
    if ([self.delegate respondsToSelector:@selector(photoBrowserResetSelection:)]) {
        [self.delegate photoBrowserResetSelection:self];
    }
    [_gridController setSelectionMode:self.displaySelectionButtons];
    [[_gridController collectionView] reloadData];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"mwphotobrowser_select_all"] style:UIBarButtonItemStylePlain target:self action:@selector(selectAllButtonPressed:)];
    _deleteMultipleButton.enabled = false;
    _actionMultipleButton.enabled = false;
}

- (void)deleteMultipleButtonPressed:(id)sender {
    if ([self numberOfPhotos] > 0) {
        NSString *actionTitle;
        NSUInteger selectionCount = [self.delegate mediaSelectionCount];
        if (selectionCount == 0) {
            /* clear all */
            actionTitle = NSLocalizedString(@"media_delete_all_confirm", nil);
        } else {
            actionTitle = NSLocalizedString(@"media_delete_selected_confirm", nil);
        }
        UIAlertController *deleteActionSheet = [UIAlertController alertControllerWithTitle:actionTitle message:nil preferredStyle:UIAlertControllerStyleAlert];
        [deleteActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [self showProgressHUDWithMessage:[NSString stringWithFormat:@"%@...", NSLocalizedString(@"delete", "")]];
            if ([self.delegate respondsToSelector:@selector(photoBrowser:deleteButton:)]) {
                [self.delegate photoBrowser:self deleteButton:_deleteMultipleButton];
                
                [self reloadData:YES];
                [self updateNavigation];
            }
        }]];
        [deleteActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        deleteActionSheet.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
        [self presentViewController:deleteActionSheet animated:YES completion:nil];
    }
}

- (void)actionMultipleButtonPressed:(id)sender {    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
    if ([mdmSetup disableShareMedia] == true) {
        // do nothing
    } else {
        NSSet *selectedPhotosIndexes = [self.delegate mediaPhotoSelection];
        
        NSMutableArray *allSelectedPhotos = [NSMutableArray new];
        [selectedPhotosIndexes enumerateObjectsUsingBlock:^(NSNumber *index, BOOL * _Nonnull stop) {
            MWPhoto *photo = [self photoAtIndex:[index unsignedIntegerValue]];
            NSURL *photoUrl = [photo urlForExportData:[index stringValue]];
            if (photoUrl != nil) {
                [allSelectedPhotos addObject:photoUrl];
            }
        }];
        
        if (allSelectedPhotos.count == 0) {
            return;
        }
        
        TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:self.view andBarButtonItem:_actionButton];
        ForwardMultipleURLActivity *forwardUrlActivity = [[ForwardMultipleURLActivity alloc] init];
        
        self.activityViewController = [ActivityUtil activityViewControllerWithActivityItems:allSelectedPhotos applicationActivities:@[forwardUrlActivity, openInAppActivity]];
        
        // Show
        typeof(self) __weak weakSelf = self;
        // iOS 8 - Set the Anchor Point for the popover
        self.activityViewController.popoverPresentationController.barButtonItem = _actionButton;
        
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults setDouble:[ThreemaUtilityObjC systemUptime] forKey:@"UIActivityViewControllerOpenTime"];
        [defaults synchronize];
        
        [self.activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
            
            weakSelf.activityViewController = nil;
            [weakSelf hideControlsAfterDelay];
            [weakSelf hideProgressHUD:YES];
            
            NSUserDefaults *defaults = [AppGroup userDefaults];
            [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
        }];
        
        UIViewController *fakeVC=[[UIViewController alloc] init];
        [self presentViewController:self.activityViewController animated:YES completion:nil];
    }
}

- (void)finishedDeleteMedia {
    [self selectButtonPressed:nil];
    [self hideProgressHUD:true];
    [self reloadData:false];
}
/***** END THREEMA MODIFICATION: add delete button *********/

#pragma mark - Action Progress

- (MBProgressHUD *)progressHUD {
    if (!_progressHUD) {
        _progressHUD = [[MBProgressHUD alloc] initWithView:self.view];
        _progressHUD.minSize = CGSizeMake(120, 120);
        _progressHUD.minShowTime = 1;
        [self.view addSubview:_progressHUD];
    }
    return _progressHUD;
}

- (void)showProgressHUDWithMessage:(NSString *)message {
    self.progressHUD.label.text = message;
    self.progressHUD.mode = MBProgressHUDModeIndeterminate;
    [self.progressHUD showAnimated:YES];
    self.navigationController.navigationBar.userInteractionEnabled = NO;
}

- (void)hideProgressHUD:(BOOL)animated {
    [self.progressHUD hideAnimated:animated];
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

- (void)showProgressHUDCompleteMessage:(NSString *)message {
    if (message) {
        if (self.progressHUD.isHidden) [self.progressHUD showAnimated:YES];
        self.progressHUD.label.text = message;
        self.progressHUD.mode = MBProgressHUDModeCustomView;
        [self.progressHUD hideAnimated:YES afterDelay:1.5];
    } else {
        [self.progressHUD hideAnimated:YES];
    }
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

/***** BEGIN THREEMA MODIFICATION: add peeking *********/
- (BOOL)peeking {
    return _peeking;
}

- (void)setPeeking:(BOOL)peeking {
    _peeking = peeking;
    [self setControlsHidden:peeking animated:!peeking permanent:NO];
}
/***** END THREEMA MODIFICATION: add peeking *********/


///***** BEGIN THREEMA MODIFICATION: ignore mute switch *********/
#pragma mark - AVPlayerViewControllerDelegate

- (void)playerViewControllerWillBeginDismissalTransition:(AVPlayerViewController *)playerViewController {
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (state == CallStateIdle) {
        [[AVAudioSession sharedInstance] setCategory:_prevAudioCategory error:nil];
    }
}

///***** END THREEMA MODIFICATION: ignore mute switch *********/

- (void)shareMedia:(MWPhoto *)item {
    
    /***** BEGIN THREEMA MODIFICATION: use TTOpenInAppActivity, ForwardURLActivity, MDM share restriction *********/
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
    if ([mdmSetup disableShareMedia] == true) {
        ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
        ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
        picker.enableMultiSelection = true;
        picker.enableTextInput = true;
        picker.submitOnSelect = false;
        
        [self presentViewController:navigationController animated:YES completion:nil];
    } else {
        NSURL *photoUrl = [item urlForExportData:@"file"];
        if (photoUrl == nil) {
            [self setControlsHidden:NO animated:YES permanent:YES];
            return;
        }
        NSArray *items = [NSArray arrayWithObject: photoUrl];
        
        TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:self.view andBarButtonItem:_actionButton];
        ForwardURLActivity *forwardUrlActivity = [[ForwardURLActivity alloc] init];
        
        self.activityViewController = [ActivityUtil activityViewControllerWithActivityItems:items applicationActivities:@[forwardUrlActivity, openInAppActivity]];
        
        openInAppActivity.superViewController = self.activityViewController;
                
        // Show
        typeof(self) __weak weakSelf = self;
        // iOS 8 - Set the Anchor Point for the popover
        self.activityViewController.popoverPresentationController.barButtonItem = _actionButton;
        
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults setDouble:[ThreemaUtilityObjC systemUptime] forKey:@"UIActivityViewControllerOpenTime"];
        [defaults synchronize];
        
        [self.activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
            
            weakSelf.activityViewController = nil;
            [weakSelf hideControlsAfterDelay];
            [weakSelf hideProgressHUD:YES];
            
            NSUserDefaults *defaults = [AppGroup userDefaults];
            [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
        }];
        
        UIViewController *fakeVC=[[UIViewController alloc] init];
        [self presentViewController:self.activityViewController animated:YES completion:nil];
    }
    
    ///***** END THREEMA MODIFICATION: use TTOpenInAppActivity, ForwardURLActivity, MDM share restriction *********/
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    ///***** BEGIN THREEMA MODIFICATION: Use own AlertController *********/
    [UIAlertTemplate showAlertWithOwner:self title:title message:message actionOk:nil];
    ///***** END THREEMA MODIFICATION: Use own AlertController *********/
}

///***** BEGIN THREEMA MODIFICATION: ContactGroupPickerDelegate *********/
#pragma mark - Contact picker delegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    id <MWPhoto> photo = [self photoAtIndex:_currentPageIndex];
    if ([self numberOfPhotos] > 0 && [photo underlyingImage]) {
        NSString *filename = [[FileUtility shared] getTemporarySendableFileNameWithBase:@"image"];
        NSURL *photoUrl = [photo urlForExportData:filename];
        
        for (Conversation *conversation in conversations) {
            [URLSender sendURL:photoUrl asFile:sendAsFile caption:contactPicker.additionalTextToSend conversation:conversation];
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else {
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker {
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}
///***** END THREEMA MODIFICATION: ContactGroupPickerDelegate *********/

///***** BEGIN THREEMA MODIFICATION: ModalNavigationControllerDelegate *********/

#pragma mark - ModalNavigationControllerDelegate

- (void)didDismissModalNavigationController {
    // No op
}

///***** END THREEMA MODIFICATION: ModalNavigationControllerDelegate *********/

@end
