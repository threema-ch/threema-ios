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

#import "ChatFileMessageCell.h"
#import "FileMessage.h"
#import "ImageData.h"
#import "FileMessageSender.h"
#import "RectUtil.h"
#import "Utils.h"
#import "BlobMessageLoader.h"
#import "ProtocolDefines.h"
#import "UTIConverter.h"
#import "BundleUtil.h"
#import "FileMessagePreview.h"
#import "UIImage+ColoredImage.h"
#import "MDMSetup.h"
#import "BlobUtil.h"
#import "PinnedHTTPSURLLoader.h"
#import "NaClCrypto.h"
#import "EntityManager.h"

#define DOWNLOAD_VIEW_HEIGHT 18.0f
#define THUMBNAIL_SIZE 64.0
#define THUMBNAIL_SMALL_SIZE 36.0
#define MIN_HEIGHT 34.0f
#define NAME_LABEL_PADDING 16.0f
#define PROGRESSBAR_PADDING 40.0f
#define THUMBNAIL_PADDING 8.0f
#define RESEND_BUTTON_WIDTH 114.0f

@interface ChatFileMessageCell ()

@property UIImageView *thumbnailView;
@property UILabel *downloadSizeLabel;
@property UILabel *nameLabel;
@property UIImageView *downloadBackground;

@property FileMessagePreview *fileMessagPreview;

@end

@implementation ChatFileMessageCell

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {
    CGSize maxSize = CGSizeMake([ChatMessageCell maxContentWidthForTableWidth:tableWidth] - NAME_LABEL_PADDING, CGFLOAT_MAX);

    static UILabel *dummyLabel = nil;
    
    if (dummyLabel == nil) {
        dummyLabel = [[UILabel alloc] init];
        dummyLabel.clearsContextBeforeDrawing = NO;
        dummyLabel.numberOfLines = 0;
        dummyLabel.lineBreakMode = NSLineBreakByWordWrapping;
        dummyLabel.textAlignment = NSTextAlignmentCenter;
    }
    
    dummyLabel.font = [ChatMessageCell textFont];
    dummyLabel.attributedText = [self displayTextForMessage:message];
    
    CGSize textSize = [dummyLabel sizeThatFits:maxSize];
    textSize.height = ceilf(textSize.height);
    
    CGFloat thumbnailSize = [self thumbnailSizeForMessage:(FileMessage*)message];
    
    return MAX(textSize.height + DOWNLOAD_VIEW_HEIGHT + thumbnailSize + 2*THUMBNAIL_PADDING, MIN_HEIGHT);
}

+ (CGFloat)thumbnailSizeForMessage:(FileMessage *)message {
    CGFloat thumbnailSize = THUMBNAIL_SIZE;
    if (((FileMessage*)message).thumbnail == nil) {
        thumbnailSize = THUMBNAIL_SMALL_SIZE;
    }
    
    return thumbnailSize;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        CGRect rect = CGRectMake(0.0, 0.0, THUMBNAIL_SIZE, THUMBNAIL_SIZE);
        _thumbnailView = [[UIImageView alloc] initWithFrame:rect];
        _thumbnailView.clearsContextBeforeDrawing = NO;
        _thumbnailView.contentMode = UIViewContentModeScaleAspectFit;
        
        [self setBubbleHighlighted:NO];
        [self.contentView addSubview:self.thumbnailView];
        
        UIImage *downloadBackgroundImage = [[UIImage imageNamed:@"VideoDownloadBg"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 32, 0, 0)];
        _downloadBackground = [[UIImageView alloc] initWithImage:downloadBackgroundImage];
        _downloadBackground.opaque = NO;
        [self.contentView addSubview:self.downloadBackground];
        
        _downloadSizeLabel = [[UILabel alloc] init];
        _downloadSizeLabel.backgroundColor = [UIColor clearColor];
        _downloadSizeLabel.opaque = NO;
        _downloadSizeLabel.font = [UIFont boldSystemFontOfSize:12.0];
        _downloadSizeLabel.textColor = [UIColor whiteColor];
        _downloadSizeLabel.textAlignment = NSTextAlignmentRight;
        _downloadSizeLabel.adjustsFontSizeToFitWidth = YES;
        [self.contentView addSubview:_downloadSizeLabel];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.clearsContextBeforeDrawing = NO;
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.numberOfLines = 0;
        _nameLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _nameLabel.font = [ChatMessageCell textFont];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_nameLabel];
    }
    
    return self;
}

- (void)setupColors {
    [super setupColors];
    
    _nameLabel.textColor = [Colors fontNormal];
}

- (void)dealloc {
    @try {
        [self.message removeObserver:self forKeyPath:@"data"];
    }
    @catch(NSException *e) {}
}


- (void)setMessage:(BaseMessage *)newMessage {
    @try {
        [self.message removeObserver:self forKeyPath:@"data"];
    }
    @catch(NSException *e) {}
    
    FileMessage *fileMessage = (FileMessage*)newMessage;
    [super setMessage:fileMessage];
    
    if (!self.chatVc.isOpenWithForceTouch) {
        [self.message addObserver:self forKeyPath:@"data" options:0 context:nil];
    }
    
    [_nameLabel setAttributedText:[ChatFileMessageCell displayTextForMessage:self.message]];
    [_downloadSizeLabel setText: [Utils formatDataLength:fileMessage.fileSize.floatValue]];
    
    [self updateThumbnailImage];
    
    UIViewAutoresizing resizing = UIViewAutoresizingFlexibleRightMargin;
    if (fileMessage.isOwn.boolValue) {
        resizing = UIViewAutoresizingFlexibleLeftMargin;
    }
    _thumbnailView.autoresizingMask = resizing;
    _downloadBackground.autoresizingMask = resizing;
    _downloadSizeLabel.autoresizingMask = resizing;
    
    [self updateDownloadSize];
    
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    CGFloat messageTextWidth;
    if (@available(iOS 11.0, *)) {
        messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.safeAreaLayoutGuide.layoutFrame.size.width];
    } else {
        messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.frame.size.width];
    }
    
    CGSize textSize = [_nameLabel sizeThatFits:CGSizeMake(messageTextWidth - NAME_LABEL_PADDING, CGFLOAT_MAX)];
    
    CGFloat thumbnailSize = [ChatFileMessageCell thumbnailSizeForMessage:(FileMessage*)self.message];
    
    CGFloat height = ceilf(textSize.height + DOWNLOAD_VIEW_HEIGHT + thumbnailSize + 2*THUMBNAIL_PADDING);
    CGSize size = CGSizeMake(textSize.width + NAME_LABEL_PADDING, height);
    
    [self setBubbleContentSize:size];

    [super layoutSubviews];
    
    CGRect backgroundRect = self.msgBackground.frame;
    
    CALayer *mask = [self bubbleMaskForImageSize:backgroundRect.size];
    _downloadBackground.layer.mask = mask;
    _downloadBackground.layer.masksToBounds = YES;
    
    _downloadBackground.frame = CGRectMake(backgroundRect.origin.x, backgroundRect.origin.y, backgroundRect.size.width, DOWNLOAD_VIEW_HEIGHT);
    
    _downloadSizeLabel.frame = CGRectMake(backgroundRect.origin.x + NAME_LABEL_PADDING/2.0, backgroundRect.origin.y, backgroundRect.size.width - NAME_LABEL_PADDING - 10.0, DOWNLOAD_VIEW_HEIGHT);

    CGFloat yOffset = CGRectGetMaxY(_downloadBackground.frame) + THUMBNAIL_PADDING;
    _thumbnailView.frame = [RectUtil setYPositionOf:_thumbnailView.frame y: yOffset];
    _thumbnailView.frame = [RectUtil rect:_thumbnailView.frame centerHorizontalIn:backgroundRect round:YES];
    _thumbnailView.frame = [RectUtil offsetRect:_thumbnailView.frame byX:backgroundRect.origin.x byY:0.0];
    
    yOffset += _thumbnailView.frame.size.height + THUMBNAIL_PADDING/2.0;

    self.progressBar.frame = CGRectMake(backgroundRect.origin.x + PROGRESSBAR_PADDING/2.0, yOffset, backgroundRect.size.width - PROGRESSBAR_PADDING, self.progressBar.frame.size.height);
    
    yOffset += THUMBNAIL_PADDING;

    if (self.message.isOwn.boolValue) {
        CGFloat resendButtonX = backgroundRect.origin.x - RESEND_BUTTON_WIDTH;
        CGFloat resendButtonHeight;
        CGFloat resendButtonWidth;
        if (resendButtonX < 8.0) {
            self.resendButton.titleLabel.numberOfLines = 2;
            resendButtonWidth = backgroundRect.origin.x - 16.0;
            resendButtonX = 8.0;
            resendButtonHeight = 64.0;
        } else {
            self.resendButton.titleLabel.numberOfLines = 1;
            resendButtonHeight = 32.0;
            resendButtonWidth = RESEND_BUTTON_WIDTH;
        }
        
        self.resendButton.frame = CGRectMake(resendButtonX, _thumbnailView.frame.origin.y + (_thumbnailView.frame.size.height - resendButtonHeight) / 2.0, resendButtonWidth, resendButtonHeight);
    }

    _nameLabel.frame = CGRectMake(0, yOffset, textSize.width, textSize.height);
    _nameLabel.frame = [RectUtil rect:_nameLabel.frame centerHorizontalIn:backgroundRect round:YES];
    _nameLabel.frame = [RectUtil offsetRect:_nameLabel.frame byX:backgroundRect.origin.x byY:0.0];
}

- (void)updateThumbnailImage {
    FileMessage *fileMessage = (FileMessage*) self.message;
    
    if (fileMessage.blobThumbnailId != nil && fileMessage.thumbnail == nil) {
        // load thumbnail
        [self loadThumbnail: fileMessage];
    }
    
    UIImage *thumbnailImage = [FileMessagePreview thumbnailForFileMessage:fileMessage];
    
    CGFloat thumbnailSize = [ChatFileMessageCell thumbnailSizeForMessage:(FileMessage*)self.message];
    _thumbnailView.frame = [RectUtil setSizeOf:_thumbnailView.frame width:thumbnailSize height:thumbnailSize];
    _thumbnailView.frame = [RectUtil rect:_thumbnailView.frame centerIn:self.msgBackground.frame];
    
    _thumbnailView.image = thumbnailImage;
}

- (void)loadThumbnail:(FileMessage *)fileMessage {
    NSURLRequest *request = [BlobUtil urlRequestForBlobId:fileMessage.blobThumbnailId];
    
    PinnedHTTPSURLLoader *thumbnailLoader = [[PinnedHTTPSURLLoader alloc] init];
    [thumbnailLoader startWithURLRequest:request onCompletion:^(NSData *data) {
        /* Decrypt the box */
        NSData *thumbnailData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:[fileMessage encryptionKey] nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
        if (thumbnailData != nil) {
            EntityManager *entityManager = [[EntityManager alloc] init];
            [entityManager performSyncBlockAndSafe:^{
                ImageData *thumbnail = [entityManager.entityCreator imageData];
                thumbnail.data = thumbnailData;
                
                // load image to determine size
                UIImage *thumbnailImage = [UIImage imageWithData:thumbnailData];
                thumbnail.width = [NSNumber numberWithInt:thumbnailImage.size.width];
                thumbnail.height = [NSNumber numberWithInt:thumbnailImage.size.height];
                
                fileMessage.thumbnail = thumbnail;
            }];
            [self setNeedsLayout];
        }
    } onError:^(NSError *error) {
       // do nothing
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == self.message && [keyPath isEqualToString:@"data"]) {
            [self updateDownloadSize];
        }
    });
}

- (void)updateDownloadSize {
    FileMessage *fileMessage = (FileMessage*)self.message;
    if (fileMessage.data != nil) {
        _downloadBackground.hidden = YES;
        _downloadSizeLabel.textColor = [Colors fontNormal];
    } else {
        // blob ID equals nil means media was deleted
        _downloadBackground.hidden = fileMessage.blobId != nil ? NO : YES;
        _downloadSizeLabel.textColor = [UIColor whiteColor];
    }
}

- (void)messageTapped:(id)sender {
    FileMessage *fileMessage = (FileMessage*)self.message;
    
    if (fileMessage.data == nil) {
        /* need to download this file first */
        BlobMessageLoader *loader = [[BlobMessageLoader alloc] init];
        [loader startWithMessage:fileMessage onCompletion:^(BaseMessage *message) {
            [self showDetails];
        } onError:^(NSError *error) {
            if (error.code != kErrorCodeUserCancelled) {
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
            }
        }];
    } else {
        [self showDetails];
    }
}

- (void)showDetails {
    if (self.chatVc.visible == NO) {
        return;
    }
    
    // to prevent keyboard issue when playing audio using UIDocumentInteractionController (IOS-163)
    [self.chatVc.chatBar resignFirstResponder];
    
    FileMessage *fileMessage = (FileMessage*)self.message;
    _fileMessagPreview = [FileMessagePreview fileMessagePreviewFor:fileMessage];
    [_fileMessagPreview showOn:self.chatVc];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(resendMessage:) && self.message.isOwn.boolValue && self.message.sendFailed.boolValue)
        return YES;
    else if (action == @selector(deleteMessage:) && self.message.isOwn.boolValue && !self.message.sent.boolValue && !self.message.sendFailed.boolValue)
        return NO; /* don't allow messages in progress to be deleted */
    else if (action == @selector(copyMessage:))
        return NO;  /* cannot copy files */
    else if (action == @selector(shareMessage:)) {
        if (@available(iOS 13.0, *)) {
            MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
            if ([mdmSetup disableShareMedia] == true) {
                return NO;
            }
        }
        return (((FileMessage*)self.message).data != nil);  /* can only save downloaded files */
    } else if (action == @selector(forwardMessage:))
        if (@available(iOS 13.0, *)) {
            return (((FileMessage*)self.message).data != nil);  /* can only save downloaded files */
        } else {
            return NO;
        }
    else
        return [super canPerformAction:action withSender:sender];
}

- (NSString *)textForQuote {
    FileMessage *fileMessage = (FileMessage*)self.message;
    return fileMessage.caption;
}

- (void)resendMessage:(UIMenuController*)menuController {
    FileMessage *fileMessage = (FileMessage*)self.message;
    FileMessageSender *sender = [[FileMessageSender alloc] init];
    [sender retryMessage:fileMessage];
}

- (BOOL)performPlayActionForAccessibility {
    [self messageTapped:self];
    return YES;
}

- (BOOL)highlightOccurencesOf:(NSString *)pattern {
    NSAttributedString *attributedString = [ChatMessageCell highlightedOccurencesOf:pattern inString:_nameLabel.text];
    if (attributedString) {
        _nameLabel.attributedText = attributedString;
        return YES;
    }
    
    return NO;
}

+ (NSAttributedString*)displayTextForMessage:(BaseMessage*)message {
    FileMessage *fileMessage = (FileMessage*)message;
    NSString *caption = fileMessage.caption;
    NSMutableAttributedString *labelText;
    UIFont *font = [ChatMessageCell textFont];
    if (caption.length > 0) {
        UIFont *captionFont = [font fontWithSize:font.pointSize*0.85];
        labelText = [[NSMutableAttributedString alloc] initWithString:fileMessage.fileName attributes:@{ NSFontAttributeName : font }];
        [labelText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n" attributes:@{ NSFontAttributeName : captionFont }]];
        [labelText appendAttributedString:[[NSAttributedString alloc] initWithString:caption attributes:@{ NSFontAttributeName : captionFont }]];
    } else {
        NSString *name = fileMessage.fileName;
        if (name == nil || name.length == 0) {
            name = @"Unknown";
        }
        labelText = [[NSMutableAttributedString alloc] initWithString:name];
    }
    return labelText;
}

- (NSString *)accessibilityLabelForContent {
    FileMessage *fileMessage = (FileMessage*)self.message;
    
    NSString *type = [UTIConverter localizedDescriptionForMimeType:fileMessage.mimeType];
    NSString *name = fileMessage.fileName;
    NSString *size = [Utils formatDataLength:fileMessage.fileSize.floatValue];
    
    NSString *fileInfo = [NSString stringWithFormat:@"%@. %@. %@", type, name, size];
    
    NSString *caption = fileMessage.caption;
    
    if (caption.length > 0) {
        return [NSString stringWithFormat:@"%@. %@", fileInfo, caption];
    } else {
        return fileInfo;
    }
}

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (!self.editing) {
        CGPoint convertedPoint = [_thumbnailView convertPoint:point fromView:self.chatVc.chatContent];
        FileMessage *fileMessage = (FileMessage*)self.message;
        if ([_thumbnailView pointInside:convertedPoint withEvent:nil] && fileMessage.data != nil) {
            if (fileMessage.data.data != nil) {
                UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
                    return  [self.chatVc.headerView getPhotoBrowserAtMessage:self.message forPeeking:YES];
                } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
                    return nil;
                }];
                return conf;
            } else {
                return [super getContextMenu:indexPath point:point];
            }
        }
    }
    return [super getContextMenu:indexPath point:point];
}

@end
