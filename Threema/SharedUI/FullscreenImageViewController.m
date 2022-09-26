//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "FullscreenImageViewController.h"

#define bgColor [UIColor colorWithRed:0.93 green:0.93 blue:0.96 alpha:1.0]

@interface FullscreenImageViewController () <UINavigationControllerDelegate>

@property BOOL controlsHidden;
@property UIImageView *imageView;
@property UIImage *image;

@property CGSize imageSize;

@end

@implementation FullscreenImageViewController

+ (instancetype)controllerForImage:(UIImage *)image {
    FullscreenImageViewController *controller = [FullscreenImageViewController new];
    controller.image = image;
    controller.imageSize = image.size;
    
    return controller;
}

- (UIImageView *)createImageView {
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageView.userInteractionEnabled = YES;
    imageView.frame = [self imageRect];
    imageView.image = _image;
    
    return imageView;
}

- (void)viewDidLoad {
    self.view.backgroundColor = bgColor;
    
    _imageView = [self createImageView];
    [self.view addSubview:_imageView];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toogleControls)];
    [self.view addGestureRecognizer:tapRecognizer];
    self.view.userInteractionEnabled = YES;
    
    [self.view setBackgroundColor:Colors.backgroundView];
    
    _imageView.accessibilityIgnoresInvertColors = true;
}

- (void)viewWillAppear:(BOOL)animated {
    _imageView.image = _image;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    UINavigationController *nav = self.navigationController;
    [self fadeInControls:nav];
}

-(void)viewDidLayoutSubviews {
    _imageView.frame = [self imageRect];
}

- (CGRect)imageRect {
    CGSize boundsSize = self.view.bounds.size;
    
    CGFloat zoomScale = [self getZoomScale];
    
    CGFloat w = zoomScale * _imageSize.width;
    CGFloat h = zoomScale * _imageSize.height;
    
    CGFloat dx = (boundsSize.width - w) / 2.0;
    CGFloat dy = (boundsSize.height - h) / 2.0;
    
    return CGRectMake(dx, dy, w, h);
}

- (CGFloat)getZoomScale
{
    CGSize boundsSize = self.view.bounds.size;
    
    CGFloat xScale = boundsSize.width / _imageSize.width;
    CGFloat yScale = boundsSize.height / _imageSize.height;
    
    if (boundsSize.width > boundsSize.height) {
        return yScale;
    }
    
    return xScale;
}

#pragma mark - Toogle controls

- (void)toogleControls
{
    UINavigationController *nav = self.navigationController;
    
    if (_controlsHidden) {
        [self fadeInControls:nav];
    } else {
        [self fadeAwayControls:nav];
    }
}

- (void)fadeInControls:(UINavigationController *)nav
{
    _controlsHidden = NO;
    
    [nav.navigationBar setAlpha:0.0f];
    
    [UIView animateWithDuration:0.2 animations:^{
        [nav.navigationBar setAlpha:1.0f];
        self.view.backgroundColor = Colors.backgroundView;
        
        [self setNeedsStatusBarAppearanceUpdate];

        if (self.tabBarController) {
            [self.tabBarController.tabBar setAlpha:1.0f];
        }
    }];
}

- (void)fadeAwayControls:(UINavigationController *)nav
{
    _controlsHidden = YES;
    
    [self.navigationController.interactivePopGestureRecognizer setDelegate:nil];
    
    [UIView animateWithDuration:0.2 animations:^{
        [nav.navigationBar setAlpha:0.0f];
        [nav.toolbar setAlpha:0.0f];
        
        [self setNeedsStatusBarAppearanceUpdate];

        self.view.backgroundColor = [UIColor blackColor];
        
       if (self.tabBarController) {
            [self.tabBarController.tabBar setAlpha:0.0f];
        }
    }];
}

@end
