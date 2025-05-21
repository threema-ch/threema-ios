//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "BallotResultViewController.h"
#import "BallotResultMatrixView.h"
#import "RectUtil.h"
#import "BallotHeaderView.h"
#import "NibUtil.h"
#import "BundleUtil.h"

#define IPAD_PADDING_FACTOR (3.0/4.0)

@interface BallotResultViewController ()

@property BallotHeaderView *headerView;
@property BallotResultMatrixView *matrixView;

@end

@implementation BallotResultViewController

+ (instancetype) ballotResultViewControllerForBallot:(BallotEntity *)ballot {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Ballot" bundle:nil];
    
    BallotResultViewController *viewController = (BallotResultViewController *) [storyboard instantiateViewControllerWithIdentifier:@"BallotResultViewController"];
    
    viewController.ballot = ballot;
    
    return viewController;
}

-(void)viewDidLayoutSubviews {
    CGFloat top = self.view.safeAreaInsets.top;
    _headerPlaceholderView.frame = [RectUtil setYPositionOf:_headerPlaceholderView.frame y:top];
    _resultView.frame = [RectUtil setYPositionOf:_headerPlaceholderView.frame y:CGRectGetMaxY(_headerPlaceholderView.frame)];
    
    CGFloat height = self.view.bounds.size.height - CGRectGetMaxY(_headerPlaceholderView.frame);
    _resultView.frame = [RectUtil setHeightOf:_resultView.frame height:height];
    
    [_matrixView adaptToInterfaceRotation];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _headerView = (BallotHeaderView *)[NibUtil loadViewFromNibWithName:@"BallotHeaderView"];
    _headerView.ballot = _ballot;
    _headerView.frame = _headerPlaceholderView.bounds;
    [_headerPlaceholderView addSubview: _headerView];
    
    [_doneButton setTitle:[BundleUtil localizedStringForKey:@"Done"]];
    _doneButton.accessibilityIdentifier = @"BallotResultViewControllerDoneBarButtonItem";
    
    if ([_ballot isClosed]) {
        [self setTitle:[BundleUtil localizedStringForKey:@"ballot_results"]];
    } else {
        [self setTitle:[BundleUtil localizedStringForKey:@"ballot_intermediate_results"]];
    }
    
    [self updateContent];
    
    [self updateColors];
}

- (void)refresh {
    [super refresh];
    
    [self updateColors];
}

- (void)updateColors {
    self.view.backgroundColor = Colors.backgroundNavigationController;
        
    [self updateContent];
}

- (CGSize)preferredContentSize {
    if (SYSTEM_IS_IPAD) {
        CGFloat maxWidth, maxHeight;
        if (self.view.window == nil) {
            // window is not set until view is on screen
            CGSize size = self.view.bounds.size;
            maxWidth = size.width;
            maxHeight = size.height;
        } else {
            CGSize size = self.view.window.bounds.size;
            maxWidth = size.height;
            maxHeight = size.width;
        }
        
        return CGSizeMake(maxWidth * IPAD_PADDING_FACTOR, maxHeight * IPAD_PADDING_FACTOR);
    } else {
        return [super preferredContentSize];
    }
}

- (void)updateContent {
    if (_matrixView != nil) {
        [_matrixView removeFromSuperview];
        _matrixView = nil;
    }
    CGRect rect = _resultView.bounds;
    _matrixView = [[BallotResultMatrixView alloc] initWithFrame: rect];
    _matrixView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _matrixView.ballot = _ballot;
    
    [_resultView addSubview: _matrixView];
}


- (IBAction)dismiss:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

@end
