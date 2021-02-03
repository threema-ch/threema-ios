//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "ChatVideoMessageCell.h"
#import "VideoMessage.h"
#import "ImageData.h"
#import "VideoData.h"
#import "ChatDefines.h"
#import <QuartzCore/QuartzCore.h>
#import "Utils.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif


@implementation ChatVideoMessageCell {
    UIImageView *thumbnailView;
    UILabel *durationLabel;
    UIImageView *durationBackground;
    UILabel *downloadSizeLabel;
    UIImageView *downloadBackground;
    CALayer *tintLayer;
    UIImageView *playImageView;
}

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {
    VideoMessage *videoMessage = (VideoMessage*)message;
    CGSize scaledSize = [ChatVideoMessageCell scaleImageSizeToCell:CGSizeMake(videoMessage.thumbnail.width.floatValue, videoMessage.thumbnail.height.floatValue) forTableWidth:tableWidth];
    if (scaledSize.height != scaledSize.height || scaledSize.height < 0) {
        scaledSize.height = 120.0;
    }
    return scaledSize.height + 6.0f - 17.0f;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        thumbnailView = [[UIImageView alloc] init];
        thumbnailView.clearsContextBeforeDrawing = NO;
        
        /* Add layer with a very slight tint so that very bright messages will still stand out against a white background */
        tintLayer = [CALayer layer];
        [self setBubbleHighlighted:NO];
        [thumbnailView.layer addSublayer:tintLayer];
        [self.contentView addSubview:thumbnailView];
        
        durationBackground = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"VideoDurationBg"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 32, 0, 0)]];
        durationBackground.opaque = NO;
        [thumbnailView addSubview:durationBackground];
        
        downloadBackground = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"VideoDownloadBg"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 32, 0, 0)]];
        downloadBackground.opaque = NO;
        [thumbnailView addSubview:downloadBackground];
        
        durationLabel = [[UILabel alloc] init];
        durationLabel.backgroundColor = [UIColor clearColor];
        durationLabel.opaque = NO;
        durationLabel.font = [UIFont boldSystemFontOfSize:12.0];
        durationLabel.textColor = [UIColor whiteColor];
        durationLabel.textAlignment = NSTextAlignmentRight;
        [durationBackground addSubview:durationLabel];
        
        downloadSizeLabel = [[UILabel alloc] init];
        downloadSizeLabel.backgroundColor = [UIColor clearColor];
        downloadSizeLabel.opaque = NO;
        downloadSizeLabel.font = [UIFont boldSystemFontOfSize:12.0];
        downloadSizeLabel.textColor = [UIColor whiteColor];
        downloadSizeLabel.textAlignment = NSTextAlignmentRight;
        downloadSizeLabel.adjustsFontSizeToFitWidth = YES;
        [downloadBackground addSubview:downloadSizeLabel];
        
        if (@available(iOS 11.0, *)) {
            thumbnailView.accessibilityIgnoresInvertColors = true;
        }
        
        playImageView = [[UIImageView alloc] init];
        playImageView.image = [[BundleUtil imageNamed:@"Play"] imageWithTint:[UIColor whiteColor]];
        [thumbnailView addSubview:playImageView];
    }
    return self;
}

- (void)dealloc {
    @try {
        [self.message removeObserver:self forKeyPath:@"video"];
    }
    @catch(NSException *e) {}
}

- (void)layoutSubviews {
    
    VideoMessage *videoMessage = (VideoMessage*)self.message;
    
    CGSize size = CGSizeMake(videoMessage.thumbnail.width.floatValue, videoMessage.thumbnail.height.floatValue);
    
    /* scale to fit maximum cell size */
    size = [ChatVideoMessageCell scaleImageSizeToCell:size forTableWidth:self.frame.size.width];
    if (size.height != size.height) {
        size.height = 120.0;
    }
    if (size.width != size.width) {
        size.width = 120.0;
    }
    UIEdgeInsets imageInsets = UIEdgeInsetsMake(1, 1, 5, 1);
    CGSize bubbleSize = CGSizeMake(size.width + imageInsets.left + imageInsets.right, size.height + imageInsets.top + imageInsets.bottom);
    [self setBubbleSize:bubbleSize];
    
    [super layoutSubviews];
    
    thumbnailView.frame = self.msgBackground.frame;
    
    CALayer *mask = [self bubbleMaskForImageSize:CGSizeMake(thumbnailView.frame.size.width, thumbnailView.frame.size.height)];
    thumbnailView.layer.mask = mask;
    thumbnailView.layer.masksToBounds = YES;
    
    tintLayer.bounds = thumbnailView.bounds;
    tintLayer.position = CGPointMake(thumbnailView.bounds.size.width/2.0, thumbnailView.bounds.size.height/2.0);
    
    if (self.message.isOwn.boolValue) {
        self.resendButton.frame = CGRectMake(thumbnailView.frame.origin.x - kMessageScreenMargin, thumbnailView.frame.origin.y + (thumbnailView.frame.size.height - 32) / 2, 114, 32);
    }
    
    /* progress bar */
    self.progressBar.frame = CGRectMake(thumbnailView.frame.origin.x + 16.0f, thumbnailView.frame.origin.y + thumbnailView.frame.size.height - 40.0f, size.width - 32.0f, 16);
    
    /* duration label */
    durationBackground.frame = CGRectMake(0, thumbnailView.frame.size.height - 22, thumbnailView.frame.size.width + 1, 18);
    durationLabel.frame = CGRectMake(durationBackground.frame.size.width / 2, 0, durationBackground.frame.size.width / 2 - 12, 16);
    
    /* download size label */
    downloadBackground.frame = CGRectMake(0, 1, thumbnailView.frame.size.width + 1, 18);
    downloadSizeLabel.frame = CGRectMake(downloadBackground.frame.size.width / 2, 1, downloadBackground.frame.size.width / 2 - 12, 16);
    
    if (bubbleSize.height > 44.0 && bubbleSize.width > 44.0) {
        playImageView.frame = CGRectMake((bubbleSize.width / 2) - 22.0, (bubbleSize.height / 2) - 22.0 - 2.0, 44.0, 44.0);
    } else {
        CGFloat min = MIN(bubbleSize.width, bubbleSize.height);
        min = min - 20.0;
        playImageView.frame = CGRectMake((bubbleSize.width / 2) - (min/2), (bubbleSize.height / 2) - (min/2) - 2.0, min, min);
    }
}

- (NSString *)accessibilityLabelForContent {
    return [NSString stringWithFormat:@"%@, %d %@", NSLocalizedString(@"video", nil), ((VideoMessage*)self.message).duration.intValue, NSLocalizedString(@"seconds", nil)];
}

- (void)setMessage:(BaseMessage *)newMessage {
    if (!self.chatVc.isOpenWithForceTouch) {
        [self.message removeObserver:self forKeyPath:@"video"];
    }
    
    VideoMessage *videoMessage = (VideoMessage*)newMessage;
    
    [super setMessage:newMessage];
    
    if (!self.chatVc.isOpenWithForceTouch) {
        [self.message addObserver:self forKeyPath:@"video" options:0 context:nil];
    }
    thumbnailView.image = videoMessage.thumbnail.uiImage;// thumbnailWithPlayOverlay;
    
    if (videoMessage.isOwn.boolValue) {
        thumbnailView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        durationBackground.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        downloadBackground.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        downloadSizeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else {
        thumbnailView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        durationBackground.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        durationLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        downloadBackground.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        downloadSizeLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    int seconds = videoMessage.duration.intValue;
    int minutes = (seconds / 60);
    seconds -= minutes * 60;
    durationLabel.text = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    
    [downloadSizeLabel setText: [Utils formatDataLength:videoMessage.videoSize.floatValue]];

    [self updateDownloadSize];
    
    [self setNeedsLayout];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == self.message && [keyPath isEqualToString:@"video"]) {
            [self updateDownloadSize];
        }
    });
}

- (void)updateDownloadSize {
    VideoMessage *videoMessage = (VideoMessage*)self.message;
    if (videoMessage.video != nil) {
        downloadBackground.hidden = YES;
        downloadSizeLabel.hidden = YES;
    } else {
        // blob ID equals nil means media was deleted
        downloadBackground.hidden = videoMessage.videoBlobId != nil ? NO : YES;
        downloadSizeLabel.hidden = NO;
    }
}

- (void)messageTapped:(id)sender {
    [self.chatVc videoMessageTapped:(VideoMessage*)self.message];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    VideoMessage *videoMessage = (VideoMessage*)self.message;
    if (action == @selector(resendMessage:) && videoMessage.isOwn.boolValue && videoMessage.sendFailed.boolValue) {
        return YES;
    } else if (action == @selector(deleteMessage:) && videoMessage.isOwn.boolValue && videoMessage.progress != nil) {
        return NO; /* don't allow messages in progress to be deleted */
    } else if (action == @selector(copyMessage:)) {
        return NO;  /* cannot copy videos */
    } else if (action == @selector(shareMessage:)) {
        if (@available(iOS 13.0, *)) {
            MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
            if ([mdmSetup disableShareMedia] == true) {
                return NO;
            }
        }
        return (videoMessage.video != nil);  /* can only save downloaded videos */
    } else if (action == @selector(forwardMessage:)) {
        if (@available(iOS 13.0, *)) {
             return (videoMessage.video != nil);  /* can only save downloaded videos */
        } else {
            return NO;
        }
    } else {
        return [super canPerformAction:action withSender:sender];
    }
}

- (void)resendMessage:(UIMenuController*)menuController {
    DDLogError(@"VideoMessages can not be resent anymore.");
}

- (BOOL)performPlayActionForAccessibility {
    [self messageTapped:self];
    return YES;
}

- (BOOL)shouldHideBubbleBackground {
    VideoMessage *videoMessage = (VideoMessage*)self.message;
    return (videoMessage.thumbnail != nil);
}

- (void)setBubbleHighlighted:(BOOL)bubbleHighlighted {
    [super setBubbleHighlighted:bubbleHighlighted];
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    if (bubbleHighlighted) {
        tintLayer.backgroundColor = [[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0] CGColor];
        [tintLayer setOpacity:0.25];
    } else {
        tintLayer.backgroundColor = [[UIColor colorWithRed:0 green:0 blue:0 alpha:1.0] CGColor];
        [tintLayer setOpacity:0.03];
    }
    [CATransaction commit];
}

- (UIViewController *)previewViewController {
    return [self.chatVc.headerView getPhotoBrowserAtMessage:self.message forPeeking:YES];
}

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (self.editing) {
         return nil;
     }
    VideoMessage *videoMessage = (VideoMessage*)self.message;
    if (videoMessage.video != nil) {
        if (videoMessage.video.data != nil) {
            
            UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
                return [self previewViewController];
            } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
                NSMutableArray *menuItems = [NSMutableArray arrayWithArray:[super contextMenuItems]];
                
                UIImage *copyImage = [UIImage systemImageNamed:@"square.and.arrow.down.fill" compatibleWithTraitCollection:self.traitCollection];
                UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"save"] image:copyImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    NSString *filename = [NSString stringWithFormat:@"%f.%@", [[NSDate date] timeIntervalSinceReferenceDate], MEDIA_EXTENSION_VIDEO];
                    NSURL *tmpurl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]];
                    if (![videoMessage.video.data writeToURL:tmpurl atomically:NO]) {
                        DDLogWarn(@"Writing movie to temporary file failed");
                    } else {
                        [[AlbumManager shared] saveMovieToLibraryWithMovieURL:tmpurl completionHandler:^(BOOL success) {
                            [[NSFileManager defaultManager] removeItemAtPath:tmpurl.path error:nil];
                        }];
                    }
                }];
                if (self.message.isOwn.boolValue == true || self.chatVc.conversation.isGroup == true) {
                    [menuItems insertObject:action atIndex:0];
                } else {
                    [menuItems insertObject:action atIndex:1];
                }
                
                return [UIMenu menuWithTitle:@"" image:nil identifier:UIMenuApplication options:UIMenuOptionsDisplayInline children:menuItems];
            }];
            return conf;
        } else {
            return [super getContextMenu:indexPath point:point];
        }
    } else {
        return [super getContextMenu:indexPath point:point];
    }
}

@end
