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

#import "RandomSeedViewController.h"
#import "BundleUtil.h"
#import "MotionEntropyCollector.h"
#import "NaClCrypto.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSString+Hex.h"
#import "UIDefines.h"
#import "RectUtil.h"
#import "LicenseStore.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

#define NUM_POSITIONS_REQUIRED 200
#define NUM_LINES 16
#define NUM_BYTES 16
#define CHARACTER_SPACING 8.0
#define LINE_SPACING 6.0

@interface RandomSeedViewController () <MoveFingerDelegate>

@property MotionEntropyCollector *motionEntropyCollector;
@property BOOL doneCollecting;
@property BOOL startedCollectiong;

@property NSString *randomString;
@property NSMutableAttributedString *attributedString;

@property NSMutableArray *labelMatrix;

@property CGFloat accessabilityLastProgress;

@end

@implementation RandomSeedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
}

- (void)adaptToSmallScreen {
    [super adaptToSmallScreen];
    
    CGFloat yOffset = -20.0;
    _titleLabel.frame = [RectUtil offsetRect:_titleLabel.frame byX:0.0 byY:yOffset];
    
    yOffset -= 24.0;
    _actionLabel.frame = [RectUtil offsetRect:_actionLabel.frame byX:0.0 byY:yOffset];
    _progressView.frame = [RectUtil offsetRect:_progressView.frame byX:0.0 byY:yOffset];
    _randomDataView.frame = [RectUtil offsetRect:_randomDataView.frame byX:0.0 byY:yOffset];
    _fingerView.frame = [RectUtil offsetRect:_fingerView.frame byX:0.0 byY:yOffset];
    
    yOffset = 48.0;
    self.moreView.frame = [RectUtil offsetRect:self.moreView.frame byX:0.0 byY:yOffset];
}

- (void)setup {
    _randomDataBackground.layer.cornerRadius = 5.0;
    
    _progressView.tintColor = [Colors mainThemeDark];
    
    if ([LicenseStore requiresLicenseKey]) {
        _titleLabel.text = [BundleUtil localizedStringForKey:@"welcome_work"];        
    } else {
        _titleLabel.text = [BundleUtil localizedStringForKey:@"welcome"];
    }
    _actionLabel.text = [BundleUtil localizedStringForKey:@"move_your_finger"];
    
    self.moreView.mainView = self.mainContentView;
    self.moreView.moreButtonTitle = [BundleUtil localizedStringForKey:@"more_information"];
    self.moreView.moreMessageText = [BundleUtil localizedStringForKey:@"more_information_random_seed"];
        
    _motionEntropyCollector = [[MotionEntropyCollector alloc] init];
    
    _randomDataView.delegate = self;
    _randomDataView.isAccessibilityElement = YES;
    [_randomDataView setAccessibilityHint:[BundleUtil localizedStringForKey:@"move_your_finger"]];
    _randomDataView.accessibilityIdentifier = @"randomDataView";
    
    [self setupRandomMatrix];
    [self progressUpdate];
    
    [_motionEntropyCollector start];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    _accessabilityLastProgress = 0.0;
    
    _fingerView.image = [StyleKit finger];
}

- (void)setupRandomMatrix {
    CGFloat size = _randomDataView.frame.size.width / NUM_BYTES;
    
    _labelMatrix = [NSMutableArray arrayWithCapacity:NUM_LINES*NUM_BYTES];
    
    NSData *random = [[NaClCrypto sharedCrypto] randomBytes:(NUM_LINES*NUM_BYTES)];
    NSString *randomString = [NSString stringWithHexData:random];
    randomString = [randomString uppercaseString];
    
    for (int n = 0; n < NUM_LINES; n++) {
        for (int i = 0; i < NUM_BYTES; i++) {
            CGRect rect = CGRectMake(i*size, n*size, size, size);
            UILabel *label = [self charLabelAt:rect];
            label.text = [randomString substringWithRange:NSMakeRange((i+1)*(n+1), 1)];
            label.isAccessibilityElement = NO;
            
            [_randomDataView addSubview:label];
            [_labelMatrix addObject:label];
        }
    }
}

- (UILabel *)charLabelAt:(CGRect)rect {
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = THREEMA_COLOR_LIGHT_GREY;
    label.textAlignment = NSTextAlignmentCenter;
    label.lineBreakMode = NSLineBreakByClipping;
    label.backgroundColor = [UIColor clearColor];

    return label;
}

- (void)dealloc {
    [_motionEntropyCollector stop];
}

- (void)didMoveFingerInView:(MoveFingerView *)view {
    if (_startedCollectiong == NO) {
        _startedCollectiong = YES;
        [UIView animateWithDuration:0.3 animations:^{
            _fingerView.alpha = 0.0;
        } completion:^(BOOL finished) {
            _fingerView.hidden = YES;
        }];
    }
    
    [self progressUpdate];
    
    if (_randomDataView.numberOfPositionsRecorded >= NUM_POSITIONS_REQUIRED && !_doneCollecting) {
        /* done! */
        _doneCollecting = YES;
        
        NSData *seed = [self getSeed];
        if ([_delegate respondsToSelector: @selector(generatedRandomSeed:)]) {
            [_delegate generatedRandomSeed:seed];
        }
    }
}

- (void)progressUpdate {
    CGFloat progress = (float)_randomDataView.numberOfPositionsRecorded / NUM_POSITIONS_REQUIRED;
    
    _progressView.progress = progress;
    
    if (progress >= 1.0) {
        for (UILabel *label in _labelMatrix) {
            label.textColor = [Colors mainThemeDark];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [BundleUtil localizedStringForKey:@"done"]);
        });

    } else if (progress > 0) {
        int posIncrement = 1.0/progress + arc4random() % 5;
        
        for (int i=0; i < _labelMatrix.count; i += posIncrement) {
            // some randomness if the color should change
            int random = arc4random();
            if (random % 10 > 8) {
                UILabel *label = _labelMatrix[i];
                label.textColor = [Colors mainThemeDark];
            }
        }

        if (progress - _accessabilityLastProgress >= 0.1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, _progressView.accessibilityValue);
            });
            _accessabilityLastProgress = progress;
        }
    }
}

- (NSData *)getSeed {
    NSData *motionSeed = [_motionEntropyCollector stop];
    NSData *fingerSeed = _randomDataView.digest;
    
    /* mix the two seeds */
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    if (motionSeed.length > 0)
        CC_SHA256_Update(&ctx, motionSeed.bytes, (CC_LONG)motionSeed.length);
    if (fingerSeed.length > 0)
        CC_SHA256_Update(&ctx, fingerSeed.bytes, (CC_LONG)fingerSeed.length);
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);
    NSData *seed = [NSData dataWithBytes:digest length:sizeof(digest)];
    
    return seed;
}

@end
