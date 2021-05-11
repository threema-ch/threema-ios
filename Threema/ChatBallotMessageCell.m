//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "ChatBallotMessageCell.h"
#import "BallotMessage.h"
#import "UserSettings.h"
#import "Ballot.h"
#import "RectUtil.h"
#import "BallotDispatcher.h"
#import "ModalNavigationController.h"
#import "UIImage+ColoredImage.h"

#define ICON_IMAGE @"ActionBallot"

@implementation ChatBallotMessageCell {
    UILabel *headerLabel;
    UILabel *nameLabel;
    UIImageView *icon;
}

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {

    CGSize sizeConstrains = CGSizeMake([ChatMessageCell maxContentWidthForTableWidth:tableWidth] - 25, CGFLOAT_MAX);

    NSString *header = [ChatBallotMessageCell headerForMessage:message];
    UIFont *headerFont = [ChatBallotMessageCell headerFont];
    
    CGSize headerSize = [header boundingRectWithSize:sizeConstrains options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : headerFont} context:nil].size;
    
    headerSize.height = ceilf(headerSize.height);

    NSString *text = [ChatBallotMessageCell displayTextForMessage:message];
    UIFont *textFont = [ChatMessageCell textFont];    
    CGSize size = [text boundingRectWithSize:sizeConstrains options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : textFont} context:nil].size;
    
    size.height = ceilf(size.height);
    
    return MAX(size.height + headerSize.height, 34.0f);
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:ICON_IMAGE]];
        icon.frame = CGRectMake(0.0, 0.0, 20.0, 20.0);
        [self.contentView addSubview:icon];

        headerLabel = [[UILabel alloc] init];
        headerLabel.clearsContextBeforeDrawing = NO;
        headerLabel.backgroundColor = [UIColor clearColor];
        headerLabel.numberOfLines = 1;
        headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
        headerLabel.font = [ChatBallotMessageCell headerFont];

        [self.contentView addSubview:headerLabel];

        nameLabel = [[UILabel alloc] init];
        nameLabel.clearsContextBeforeDrawing = NO;
        nameLabel.backgroundColor = [UIColor clearColor];
        nameLabel.numberOfLines = 0;
        nameLabel.lineBreakMode = NSLineBreakByWordWrapping;
        nameLabel.font = [ChatMessageCell textFont];
        [self.contentView addSubview:nameLabel];
        
        UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapped:)];
        gestureRecognizer.delegate = self;
        self.msgBackground.userInteractionEnabled = YES;
        [self.msgBackground addGestureRecognizer:gestureRecognizer];
        
        self.accessibilityIdentifier = @"ballot_matrix_cell";
    }
    return self;
}

- (void)setupColors {
    [super setupColors];
    
    icon.image = [UIImage imageNamed:ICON_IMAGE inColor:[Colors fontNormal]];
    icon.accessibilityLabel = @"ballot_matrix_image";


    headerLabel.textColor = [Colors fontNormal];
    nameLabel.textColor = [Colors fontNormal];
}

- (void)dealloc {
    @try {
        [self.message removeObserver:self forKeyPath:@"ballot.modifyDate"];
    }
    @catch(NSException *e) {}
}

- (void)layoutSubviews {
    CGFloat messageTextWidth;
    if (@available(iOS 11.0, *)) {
        messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.safeAreaLayoutGuide.layoutFrame.size.width];
    } else {
        messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.frame.size.width];
    }
    CGSize textSize = [nameLabel.text boundingRectWithSize:CGSizeMake(messageTextWidth - 25, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : [ChatMessageCell textFont]} context:nil].size;
    CGSize headerSize = [headerLabel.text boundingRectWithSize:CGSizeMake(messageTextWidth - 25, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : [ChatMessageCell textFont]} context:nil].size;
    
    CGFloat width = ceilf(MAX(textSize.width, headerSize.width));
    CGFloat height = ceilf(textSize.height + headerSize.height);
    CGSize size = CGSizeMake(width + 25, MAX(34.0f, height));

    [self setBubbleContentSize:size];
    
    [super layoutSubviews];
    
    CGFloat headerY = 7.0;
    
    CGFloat textY = 7.0 + floorf(headerSize.height);
    
    CGFloat xOffsetText;
    CGFloat xOffsetIcon;
    if (self.message.isOwn.boolValue) {
        xOffsetText = self.contentView.frame.size.width - width - 20;
        xOffsetIcon = self.contentView.frame.size.width - width - 48;
    } else {
        xOffsetText = 46 + self.contentLeftOffset;
        xOffsetIcon = 18 + self.contentLeftOffset;
    }
    
    nameLabel.frame = CGRectMake(xOffsetText, textY, floorf(textSize.width+1), floorf(textSize.height+1));
    headerLabel.frame = CGRectMake(xOffsetText, headerY, floorf(headerSize.width+1), floorf(headerSize.height+1));
    
    icon.frame = [RectUtil setXPositionOf:icon.frame x:xOffsetIcon];
    icon.frame = [RectUtil rect:icon.frame centerVerticalIn:self.contentView.frame];
}

- (NSString *)accessibilityLabelForContent {
    return [NSString stringWithFormat:@"%@, %@", [ChatBallotMessageCell headerForMessage:self.message], [ChatBallotMessageCell displayTextForMessage:self.message]];
}

- (void)setMessage:(BaseMessage *)newMessage {
    @try {
        [self.message removeObserver:self forKeyPath:@"ballot.modifyDate"];
    }
    @catch(NSException *e) {}

    [super setMessage:newMessage];

    if (!self.chatVc.isOpenWithForceTouch) {
        [self.message addObserver:self forKeyPath:@"ballot.modifyDate" options:0 context:nil];
    }

    [self updateView];
}

- (void)updateView {
    if (self.message.isOwn.boolValue) {
        nameLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        icon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else {
        nameLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        icon.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    [self setNeedsLayout];
    
    nameLabel.text = [ChatBallotMessageCell displayTextForMessage:self.message];
    headerLabel.text = [ChatBallotMessageCell headerForMessage:self.message];
}

- (void)messageTapped:(id)sender {
    [self.chatVc ballotMessageTapped:(BallotMessage*)self.message];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copyMessage:) || action == @selector(shareMessage:)) {
        return NO;
    } else if (action == @selector(forwardMessage:)) {
        return NO;
    } else if (action == @selector(speakMessage:)) {
        return YES;
    }
    else {
        return [super canPerformAction:action withSender:sender];
    }
}

- (void)copyMessage:(UIMenuController *)menuController {
}

- (void)shareMessage:(UIMenuController *)menuController {
}

- (void)forwardMessage:(UIMenuController *)menuController {
}

- (void)speakMessage:(UIMenuController *)menuController {
    [super speakMessage:menuController];
    
    NSString *speakText = [NSString stringWithFormat:@"%@, %@", [ChatBallotMessageCell headerForMessage:self.message], [ChatBallotMessageCell displayTextForMessage:self.message]];;
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:speakText];
    [self.chatVc.speechSynthesizer speakUtterance:utterance];
}


- (void)deleteMessage:(UIMenuController*)menuController {
    if (self.message.isOwn.boolValue && !self.message.sent.boolValue && !self.message.sendFailed.boolValue)
        return;
    else
        [super deleteMessage:menuController];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == self.message) {
            [UIView animateWithDuration:0.5 animations:^{
                [self updateView];
            }];
        }
    });
}

- (BOOL)highlightOccurencesOf:(NSString *)pattern {
    NSAttributedString *attributedString = [ChatMessageCell highlightedOccurencesOf:pattern inString:nameLabel.text];
    if (attributedString) {
        nameLabel.attributedText = attributedString;
        return YES;
    }
    
    return NO;
}

+ (NSString*)displayTextForMessage:(BaseMessage*)message {
    return ((BallotMessage*)message).ballot.title;
}

+ (NSString*)headerForMessage:(BaseMessage*)message {
    BallotMessage *ballotMessage = (BallotMessage*)message;
    
    NSString *key;
    if (ballotMessage.isClosed) {
        key = @"ballot_closed_cell_title";
    } else {
        key = @"ballot_new_cell_title";
    }
    
    NSString *title = NSLocalizedStringFromTable(key, @"Ballot", nil);
    
    Ballot *ballot = ballotMessage.ballot;
    if (ballot.isClosed) {
        return title;
    } else {
        if (ballot.isIntermediate || ballot.isOwn) {
            NSInteger countParticipants = ballot.participantCount;
            NSInteger countVotes = ballot.numberOfReceivedVotes;
            
            return [NSString stringWithFormat:@"%@ %li/%li", title, (long)countVotes, (long)countParticipants];
        } else {
            return title;
        }
    }
}

+ (UIFont *)headerFont {
    CGFloat fontSize = roundf([UserSettings sharedUserSettings].chatFontSize * 0.9);
    return [UIFont italicSystemFontOfSize: fontSize];
}

- (UIViewController *)previewViewController {
    BallotMessage *ballotMessage = (BallotMessage*)self.message;
    
    UIViewController *viewController = [BallotDispatcher viewControllerForBallot:ballotMessage.ballot];
    ModalNavigationController *modalNav = [[ModalNavigationController alloc] initWithRootViewController:viewController];
    modalNav.showDoneButton = YES;

    return modalNav;
}

- (BOOL)performPlayActionForAccessibility {
    [self messageTapped:self];
    return YES;
}

@end
