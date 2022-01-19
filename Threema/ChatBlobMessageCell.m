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

#import "ChatBlobMessageCell.h"
#import "BaseMessage.h"
#import "BlobData.h"
#import "AppDelegate.h"

@interface ChatBlobMessageCell ()

@end

@implementation ChatBlobMessageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        [self setupActivityIndicator];
        [self setupResendButton];
        [self setupProgressBar];

        [self setupTapAction];
    }
    
    return self;
}

- (void)dealloc {
    @try {
        [self.message removeObserver:self forKeyPath:@"progress"];
        [self.message removeObserver:self forKeyPath:@"sendFailed"];
    }
    @catch(NSException *e) {}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    if (editing) {
        _resendButton.hidden = YES;
    } else {
        [self updateResendButton];
    }
}

- (void)setupProgressBar {
    _progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    
    if (self.message.isOwn.boolValue) {
        _progressBar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else {
        _progressBar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    _progressBar.progressTintColor = [Colors main];

    _progressBar.hidden = YES;

    [self.contentView addSubview:_progressBar];
    [self setNeedsLayout];
}

- (void)setupActivityIndicator {
    UIActivityIndicatorViewStyle style = UIActivityIndicatorViewStyleGray;
    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            style = UIActivityIndicatorViewStyleWhite;
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            break;
    }
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];

    _activityIndicator.hidesWhenStopped = YES;
    
    [self.contentView addSubview:_activityIndicator];
}

- (void)setupResendButton {
    _resendButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _resendButton.clearsContextBeforeDrawing = NO;
    [_resendButton setTitle:NSLocalizedString(@"try_again", nil) forState:UIControlStateNormal];
    _resendButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    _resendButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_resendButton addTarget:self action:@selector(resendButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    _resendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    [self.contentView addSubview:_resendButton];
}

- (void)setupTapAction {
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapped:)];
    gestureRecognizer.delegate = self;
    self.msgBackground.userInteractionEnabled = YES;
    [self.msgBackground addGestureRecognizer:gestureRecognizer];
}

- (void)setMessage:(BaseMessage *)newMessage {
    @try {
        [self.message removeObserver:self forKeyPath:@"progress"];
        [self.message removeObserver:self forKeyPath:@"sendFailed"];
    }
    @catch(NSException *e) {}
    
    BaseMessage<BlobData> *blobMessage = (BaseMessage<BlobData> *)self.message;

    /* Check if this blob has not been sent yet and is also not in progress. This can happen if the app is terminated while an upload is in progress */
    if (blobMessage.isOwn.boolValue && !blobMessage.sent.boolValue && !blobMessage.sendFailed.boolValue && [blobMessage blobGetProgress] == nil && [blobMessage.date compare:[AppDelegate sharedAppDelegate].appLaunchDate] == NSOrderedAscending) {
        newMessage.sendFailed = [NSNumber numberWithBool:YES];
    }

    [super setMessage:newMessage];
    
    if (!self.chatVc.isOpenWithForceTouch) {
        [self.message addObserver:self forKeyPath:@"progress" options:0 context:nil];
        [self.message addObserver:self forKeyPath:@"sendFailed" options:0 context:nil];
    }
    [self updateResendButton];
    [self updateProgress];
    
    [self setNeedsLayout];
}

- (void)deleteMessage:(UIMenuController*)menuController {
    if (self.message.isOwn.boolValue && !self.message.sent.boolValue && !self.message.sendFailed.boolValue)
        return;
    else
        [super deleteMessage:menuController];
}

- (BOOL)showActivityIndicator {
    return NO;
}

- (BOOL)showProgressBar {
    return YES;
}

- (void)updateActivityIndicator {
    if ([self showActivityIndicator] == NO) {
        return;
    }
    
    BaseMessage<BlobData> *blobMessage = (BaseMessage<BlobData> *)self.message;

    if ([blobMessage blobGetProgress] == nil ) {
        [_activityIndicator stopAnimating];
        return;
    }
    
    if (blobMessage.isOwn.boolValue) {
        [_activityIndicator stopAnimating];
    } else {
        
        if ([blobMessage blobGetThumbnail] != nil) {
            [_activityIndicator stopAnimating];
        } else {
            if ([blobMessage blobGetProgress] != nil) {
                [_activityIndicator startAnimating];
                [self.contentView bringSubviewToFront:_activityIndicator];
            } else {
                [_activityIndicator stopAnimating];
            }
        }
    }
}

- (void)updateProgress {
    [self updateActivityIndicator];
    
    if ([self showProgressBar] == NO) {
        return;
    }
    
    BaseMessage<BlobData> *blobMessage = (BaseMessage<BlobData> *)self.message;
    
    if ([blobMessage blobGetProgress] == nil) {
        _progressBar.hidden = YES;
    } else {
        _progressBar.progress = [blobMessage blobGetProgress].floatValue;
        _progressBar.hidden = NO;
        [self.contentView bringSubviewToFront:_progressBar];
    }
    
}

- (void)messageTapped:(id)sender {
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if (object != self.message || [self.message wasDeleted]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([keyPath isEqualToString:@"progress"] || [keyPath isEqualToString:@"sent"]) {
            [self updateProgress];
            [self updateResendButton];
        } else if ([keyPath isEqualToString:@"sendFailed"]) {
            [self updateProgress];
            [self updateStatusImage];
            [self updateResendButton];
        }
    });
}

- (void)updateStatusImage {
    BaseMessage<BlobData> *blobMessage = (BaseMessage<BlobData> *)self.message;
    if (self.message.sendFailed.boolValue && [blobMessage blobGetProgress] == nil) {
        self.statusImage.image = [UIImage imageNamed:@"MessageStatus_sendfailed"];
        self.statusImage.alpha = 0.8;
        self.statusImage.hidden = NO;
        [self setNeedsLayout];
    } else {
        [super updateStatusImage];
    }
}

- (void)resendButtonTapped:(id)sender {
    [self resendMessage:nil];
}

- (void)resendMessage:(UIMenuController*)menuController {
}

- (void)updateResendButton {
    BaseMessage<BlobData> *blobMessage = (BaseMessage<BlobData> *)self.message;
    
    if (blobMessage.isOwn.boolValue && (blobMessage.sendFailed.boolValue || blobMessage.sent.boolValue == NO) && [blobMessage blobGetProgress] == nil) {
        _resendButton.hidden = NO;
    } else {
        _resendButton.hidden = YES;
    }
}

- (CALayer*)bubbleMaskForImageSize:(CGSize)imageSize {
    
    CALayer *mask = [CALayer layer];
    
    UIImage *maskImage;
    if (self.message.isOwn.boolValue)
        maskImage = [UIImage imageNamed:@"ChatBubbleSentMask"];
    else
        maskImage = [UIImage imageNamed:@"ChatBubbleReceivedMask"];
    
    mask.contents = (id)maskImage.CGImage;
    
    if (self.message.isOwn.boolValue)
        mask.contentsCenter = CGRectMake(15.0/maskImage.size.width, 13.0/maskImage.size.height, 1.0/maskImage.size.width, 1.0/maskImage.size.height);
    else
        mask.contentsCenter = CGRectMake(23.0/maskImage.size.width, 15.0/maskImage.size.height, 1.0/maskImage.size.width, 1.0/maskImage.size.height);
    
    mask.contentsScale = maskImage.scale;
    mask.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
    
    return mask;
}

- (CALayer*)bubbleMaskWithoutArrowForImageSize:(CGSize)imageSize {
    
    CALayer *mask = [CALayer layer];
    
    UIImage *maskImage;
    if (self.message.isOwn.boolValue)
        maskImage = [UIImage imageNamed:@"ChatBubbleSentMaskWithoutArrow"];
    else
        maskImage = [UIImage imageNamed:@"ChatBubbleReceivedMaskWithoutArrow"];
    
    mask.contents = (id)maskImage.CGImage;
    
    if (self.message.isOwn.boolValue)
        mask.contentsCenter = CGRectMake(15.0/maskImage.size.width, 13.0/maskImage.size.height, 1.0/maskImage.size.width, 1.0/maskImage.size.height);
    else
        mask.contentsCenter = CGRectMake(23.0/maskImage.size.width, 15.0/maskImage.size.height, 1.0/maskImage.size.width, 1.0/maskImage.size.height);
    
    mask.contentsScale = maskImage.scale;
    mask.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
    
    return mask;
}

+ (CGSize)scaleImageSizeToCell:(CGSize)size forTableWidth:(CGFloat)tableWidth {
    CGFloat maxWidth = [ChatMessageCell maxContentWidthForTableWidth:tableWidth];
    CGFloat maxHeight;
    CGFloat minWidth = 40.0;
    CGFloat minHeight = 40.0;
    
    /* maximum height is 50% of screen height in current rotation */
    if ((int)tableWidth > (int)[UIScreen mainScreen].bounds.size.width)
        maxHeight = [UIScreen mainScreen].bounds.size.width / 2;
    else
        maxHeight = [UIScreen mainScreen].bounds.size.height / 2;
    
    /* upper bound on size (for large phones and iPads) */
    if (maxHeight > 256.0) {
        maxHeight = 256.0;
    }
    
    CGSize scaledSize = size;
    
    if (scaledSize.width < minWidth) {
        scaledSize.height *= minWidth / scaledSize.width;
        scaledSize.width = minWidth;
    }
    
    if (scaledSize.height < minHeight) {
        scaledSize.width *= minHeight / scaledSize.height;
        scaledSize.height = minHeight;
    }
    
    if (scaledSize.width > maxWidth) {
        scaledSize.height *= maxWidth / scaledSize.width;
        scaledSize.width = maxWidth;
    }
    
    if (scaledSize.height > maxHeight) {
        scaledSize.width *= maxHeight / scaledSize.height;
        scaledSize.height = maxHeight;
    }
    
    scaledSize.height = roundf(scaledSize.height);
    scaledSize.width = roundf(scaledSize.width);
    
    return scaledSize;
}

@end
