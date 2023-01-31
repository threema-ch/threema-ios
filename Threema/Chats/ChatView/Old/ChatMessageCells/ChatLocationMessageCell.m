//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "ChatLocationMessageCell.h"
#import "LocationMessage.h"
#import "Old_ChatViewController.h"
#import "ChatDefines.h"
#import "UserSettings.h"
#import "UIImage+ColoredImage.h"
#import "ActivityUtil.h"
#import "BundleUtil.h"
#import "Threema-Swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation ChatLocationMessageCell {
    UIImageView *pinView;
    UILabel *geocodeLabel;
    UIActivityIndicatorView *activityIndicator;
}

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {
    LocationMessage *locationMessage = (LocationMessage*)message;
    NSString *text = [ChatLocationMessageCell displayTextForLocationMessage:locationMessage];
    
    CGSize size = [text boundingRectWithSize:CGSizeMake([ChatMessageCell maxContentWidthForTableWidth:tableWidth isGroup:locationMessage.conversation.isGroup] - 25, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : [ChatMessageCell textFont]} context:nil].size;
    size.height = ceilf(size.height);
    
    return MAX(size.height, 34.0f);
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        pinView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CurrentLocation"]];
        pinView.frame = CGRectMake(0, 0, 15, 15);
        [self.contentView addSubview:pinView];
        
        geocodeLabel = [[UILabel alloc] init];
        geocodeLabel.clearsContextBeforeDrawing = NO;
        geocodeLabel.backgroundColor = [UIColor clearColor];
        geocodeLabel.numberOfLines = 0;
        geocodeLabel.lineBreakMode = NSLineBreakByWordWrapping;
        geocodeLabel.font = [ChatMessageCell textFont];
        geocodeLabel.contentMode = UIViewContentModeScaleToFill;
        [self.contentView addSubview:geocodeLabel];
        
        activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:Colors.objcActivityIndicatorViewStyle];
        [self.contentView addSubview:activityIndicator];
        
        UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(locationMessageTapped:)];
        gestureRecognizer.delegate = self;
        self.msgBackground.userInteractionEnabled = YES;
        [self.msgBackground addGestureRecognizer:gestureRecognizer];
    }
    return self;
}

- (void)updateColors {
    [super updateColors];
    
    pinView.image = [UIImage imageNamed:@"CurrentLocation" inColor:Colors.textLight];
}

- (void)setMessage:(BaseMessage *)newMessage {
    [super setMessage:newMessage];
    [self updateView];
}

- (void)layoutSubviews {
    CGFloat messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.safeAreaLayoutGuide.layoutFrame.size.width isGroup:self.message.conversation.isGroup];
    CGSize textSize = [geocodeLabel.text boundingRectWithSize:CGSizeMake(messageTextWidth - 25, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : [ChatMessageCell textFont]} context:nil].size;
    
    textSize.width = ceilf(textSize.width);
    textSize.height = ceilf(textSize.height);
    [self setBubbleContentSize:CGSizeMake(textSize.width + 25, MAX(34.0f, textSize.height))];
    
    [super layoutSubviews];
    
    CGFloat textY = 7;
    if (textSize.height < 34.0)
        textY += (34.0 - textSize.height) / 2;
    
    if (self.message.isOwn.boolValue) {
        geocodeLabel.frame = CGRectMake(self.contentView.frame.size.width - textSize.width - 20, textY, floor(textSize.width+1), floor(textSize.height+1));
        activityIndicator.frame = CGRectMake(self.contentView.frame.size.width - textSize.width - 25 - 22, (geocodeLabel.frame.origin.y + geocodeLabel.frame.size.height/2) - 10, 20, 20);
        pinView.frame = CGRectMake(self.contentView.frame.size.width - textSize.width - 46, (geocodeLabel.frame.origin.y + geocodeLabel.frame.size.height/2) - pinView.frame.size.height/2, pinView.frame.size.width, pinView.frame.size.height);
    } else {
        geocodeLabel.frame = CGRectMake(46 + self.contentLeftOffset, textY, floor(textSize.width+1), floor(textSize.height+1));
        activityIndicator.frame = CGRectMake(19 + self.contentLeftOffset, (geocodeLabel.frame.origin.y + geocodeLabel.frame.size.height/2) - 10, 20, 20);
        pinView.frame = CGRectMake(23 + self.contentLeftOffset, (geocodeLabel.frame.origin.y + geocodeLabel.frame.size.height/2) - pinView.frame.size.height/2, pinView.frame.size.width, pinView.frame.size.height);
    }
}

- (NSString *)accessibilityLabelForContent {
    return geocodeLabel.text;
}

- (void)updateView {
    LocationMessage *locationMessage = (LocationMessage*)self.message;
    
    NSString *displayText = [ChatLocationMessageCell displayTextForLocationMessage:locationMessage];
    
    [activityIndicator stopAnimating];
    pinView.hidden = NO;
    geocodeLabel.text = displayText;
    
    if (self.message.isOwn.boolValue) {
        geocodeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        pinView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else {
        geocodeLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        pinView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    [self setNeedsLayout];
}

- (void)locationMessageTapped:(id)sender {
    DDLogInfo(@"locationMessageTapped");
    [self.chatVc locationMessageTapped:(LocationMessage*)self.message];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(speakMessage:)) {
        return YES;
    } else {
        return [super canPerformAction:action withSender:sender];
    }
}

- (void)copyMessage:(UIMenuController *)menuController {
    LocationMessage *locationMessage = (LocationMessage*)self.message;
    NSString *mapsUrl = [NSString stringWithFormat:@"http://maps.apple.com/maps?ll=%f,%f", locationMessage.latitude.doubleValue, locationMessage.longitude.doubleValue];
    [[UIPasteboard generalPasteboard] setURL:[NSURL URLWithString:mapsUrl]];
}

- (void)speakMessage:(UIMenuController *)menuController {
    LocationMessage *locationMessage = (LocationMessage*)self.message;
    NSString *displayText = [ChatLocationMessageCell displayTextForLocationMessage:locationMessage];
    [[[SpeechSynthesizerManger alloc] init] speak:displayText];
}


- (void)shareMessage:(UIMenuController *)menuController {
    LocationMessage *locationMessage = (LocationMessage*)self.message;
    NSString *mapsUrl = [NSString stringWithFormat:@"http://maps.apple.com/maps?ll=%f,%f", locationMessage.latitude.doubleValue, locationMessage.longitude.doubleValue];
    
    UIActivityViewController* activityView = [ActivityUtil activityViewControllerWithActivityItems:@[mapsUrl] applicationActivities:nil];
    [self.chatVc presentActivityViewController:activityView animated:YES fromView:self];
}

+ (NSString*)displayTextForLocationMessage:(LocationMessage*)locationMessage {
    
    if (locationMessage.poiName) {
        if(locationMessage.poiAddress) {
            return [locationMessage.poiName stringByAppendingString:[@"\n" stringByAppendingString:locationMessage.poiAddress]];
        }
        return locationMessage.poiName;
    }
    else if (locationMessage.poiAddress) {
        return locationMessage.poiAddress;
    }
    else if (locationMessage.reverseGeocodingResult) {
        return locationMessage.reverseGeocodingResult;
    }
    else {
        return locationMessage.previewText;
    }
}

- (BOOL)performPlayActionForAccessibility {
    [self locationMessageTapped:self];
    return YES;
}

- (NSString *)textForQuote {
    return geocodeLabel.text;
}

- (void)resendMessage:(UIMenuController*)menuController {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        LocationMessage *locationMessage = [[entityManager entityFetcher] existingObjectWithID:self.message.objectID];
        locationMessage.id = [[NaClCrypto sharedCrypto] randomBytes:kMessageIdLen];
    }];
    
    LocationMessage *locationMessage = (LocationMessage*)self.message;
    [MessageSender sendBaseMessage:locationMessage];
}

@end
