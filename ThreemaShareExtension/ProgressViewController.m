//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "ProgressViewController.h"
#import "RectUtil.h"
#import "BundleUtil.h"

@interface ProgressViewController ()

@property (nonatomic) CGFloat progress;
@property NSMutableDictionary *itemsToSend;
@property UIVisualEffectView *blurView;

@end

@implementation ProgressViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _itemsToSend = [NSMutableDictionary dictionary];
    [_cancelButton setTitle: [BundleUtil localizedStringForKey:@"cancel"] forState:UIControlStateNormal];
}

- (void)setupColors {

    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            self.view.tintColor = [Colors main];
            
            _contentView.backgroundColor = [Colors background];
            _label.textColor = [Colors fontNormal];
            
            [self darkenVisualEffectsView];
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            break;
    }
    _contentView.layer.cornerRadius = 15.0;
}

- (void)darkenVisualEffectsView {
    CGRect rect = self.view.bounds;
    
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    blurStyle = UIBlurEffectStyleDark;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    
    _blurView.frame = rect;
    _blurView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    [_visualEffectsView removeFromSuperview];
    _visualEffectsView = nil;

    [_blurView.contentView addSubview:_contentView];
    [self.view addSubview:_blurView];

    NSLayoutConstraint *horizontal = [NSLayoutConstraint constraintWithItem:_contentView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:_blurView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                 multiplier:1.f constant:0.f];
    
    NSLayoutConstraint *vertical = [NSLayoutConstraint constraintWithItem:_contentView
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_blurView
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1.f constant:0.f];
    
    [_blurView addConstraints:@[horizontal, vertical]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = YES;
    
    [self updateProgressLabel];
    _progressView.progress = 0.0;
    
    [self setupColors];
}

- (void)updateProgressLabel {
    NSInteger inProgressOrSentCount = 0;
    for (NSString *key in _itemsToSend.keyEnumerator) {
        NSNumber *progress = [_itemsToSend objectForKey:key];
        if (progress.floatValue > 0.0) {
            inProgressOrSentCount++;
        };
    }

    NSString *sendingText = NSLocalizedString(@"sending_count", nil);
    NSInteger currentItemCount = inProgressOrSentCount <= _totalCount ? inProgressOrSentCount : _totalCount;
    NSString *text = [NSString stringWithFormat:sendingText, currentItemCount, (long)_totalCount];
    [_label setText: text];
}

- (void)setProgress:(NSNumber *)progress forItem:(id)item {
    if (item) {
        [_itemsToSend setObject:progress forKey:item];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateProgressLabel];
        [self updateProgressView];
    });
}

- (void)finishedItem:(id)item {
    [self setProgress:[NSNumber numberWithFloat:1.0] forItem:item];
}

- (void)updateProgressView {
    CGFloat progress = 0.0;
    for (NSString *key in _itemsToSend.keyEnumerator) {
        NSNumber *itemProgress = [_itemsToSend objectForKey:key];
        progress += itemProgress.floatValue;
    }
    
    _progressView.progress = progress / _totalCount;
}

- (IBAction)didCancel:(id)sender {
    [_delegate progressViewDidCancel];
}

@end
