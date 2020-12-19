//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "PreviewImageViewController.h"
#import "FLAnimatedImage.h"

@interface PreviewImageViewController ()

@end

@implementation PreviewImageViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.gifData != nil) {
        FLAnimatedImageView *animatedImageView;
        animatedImageView = [[FLAnimatedImageView alloc] init];
        animatedImageView.animatedImage = [FLAnimatedImage animatedImageWithGIFData:self.gifData];
        animatedImageView.frame = self.imageView.frame;
        animatedImageView.contentMode = self.imageView.contentMode;
        animatedImageView.autoresizingMask = self.imageView.autoresizingMask;
        [self.imageView removeFromSuperview];
        [self.view addSubview:animatedImageView];
        self.imageView = animatedImageView;
    } else {
        self.imageView.image = [UIImage imageWithData:self.image];
    }
    
    if (!self.hasCancelButton)
        self.navigationItem.leftBarButtonItem = nil;
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (IBAction)sendAction:(id)sender {
    if (self.gifData != nil)
        [self.delegate previewImageControllerDidChooseToSend:self gif:self.gifData];
    else
        [self.delegate previewImageControllerDidChooseToSend:self imageData:self.image];
}

- (IBAction)cancelAction:(id)sender {
    [self.delegate previewImageControllerDidChooseToCancel:self];
}

@end
