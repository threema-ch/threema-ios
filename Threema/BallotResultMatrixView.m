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

#import "BallotResultMatrixView.h"
#import "Conversation.h"
#import "Contact.h"
#import "BallotChoice.h"
#import "BallotResult.h"
#import "RectUtil.h"
#import "MyIdentityStore.h"
#import "BallotMatrixLabelView.h"
#import "BallotResultMatrixCell.h"
#import "SlaveScrollView.h"
#import "ScrollViewContent.h"
#import "PopoverView.h"
#import "AvatarMaker.h"
#import "BundleUtil.h"

#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)

#define LABEL_RADIANS -0.9

#define X_PADDING 8.0f
#define TOP_PADDING 0.0f
#define BOTTOM_PADDING 8.0f
#define MATRIX_PADDING 0.0f

#define BORDER_WIDTH 1.0
#define BORDER_COLOR [Colors background]

#define GRID_HEIGHT 36.0f
#define GRID_WIDTH 34.0f
#define TOTALS_WIDTH 36.0f
#define LABEL_LENGTH_CONTACT 100.0f
#define CONTACT_Y_OFFSET_CORRECTION -10.0f
#define CONTACT_FONT_SIZE 14.0f
#define CHOICE_FONT_SIZE 14.0f
#define CONTACT_AVATAR_PADDING 2.0f
#define CONTACT_AVATAR_SIZE GRID_WIDTH

#define HIGHEST_VOTE_COLOR [Colors ballotHighestVote]

#define ROW_COLOR_LIGHT [Colors ballotRowLight]
#define ROW_COLOR_DARKER [Colors ballotRowDark]

@interface BallotResultMatrixView () <PopoverViewDelegate>

@property NSInteger numChoices;
@property NSInteger numParticipants;
@property NSMutableArray *participantIds;
@property NSMutableArray *participantNames;
@property NSMutableArray *participantAvatars;

@property (nonatomic) CGRect matrixRect;

@property CGFloat gridHeight;
@property CGFloat gridWidth;
@property CGFloat totalsWidth;
@property CGFloat labelAngleRadians;
@property CGFloat minChoiceLabelLength;
@property CGFloat contactLabelLength;
@property CGFloat contactLabelHeight;

@property SlaveScrollView *choicesView;
@property SlaveScrollView *contactsView;
@property SlaveScrollView *matrixView;
@property SlaveScrollView *totalsView;
@property UIView *totalsHeaderView;

@property CGPoint beginTouchPoint;
@property CGPoint endTouchPoint;

@property NSMutableArray *highestVotes;

@property PopoverView *popoverView;

@property UIPanGestureRecognizer *panGesture;

@end

@implementation BallotResultMatrixView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _labelAngleRadians = LABEL_RADIANS;
        _gridWidth = GRID_WIDTH;
        _gridHeight = GRID_HEIGHT;
        
        CGFloat minSideLength = fminf(CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
        _minChoiceLabelLength = minSideLength/3.0;
        _contactLabelHeight = GRID_WIDTH;
        _contactLabelLength = LABEL_LENGTH_CONTACT;
        _totalsWidth = TOTALS_WIDTH;
        
        _endTouchPoint = CGPointMake(0.0, 0.0);
        
        _highestVotes = [NSMutableArray array];
        self.userInteractionEnabled = YES;
        
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [self addGestureRecognizer:_panGesture];

        self.backgroundColor = [Colors background];
    }
    return self;
}

- (void)adaptLayoutToSize:(CGSize)size {
    [_popoverView dismiss];
    _popoverView = nil;

    _matrixRect = [self matrixRectForSize:size];
    
    _choicesView.frame = [self choicesRectForSize:size];
    
    CGRect newContactsRect = [self contactsRectForSize:size];
    if (CGSizeEqualToSize(newContactsRect.size, _contactsView.frame.size) == NO) {
        ScrollViewContent *matrixContent = [self makeMatrixView];
        [_matrixView setContent: matrixContent];
        ScrollViewContent *contactsContent = [self makeContactsViewForSize:size];
        [_contactsView setContent: contactsContent];
        
        [self updateLineColors];
        [self markHighestVotes];
        [self setNeedsLayout];
    }
    
    _contactsView.frame = newContactsRect;
    _matrixView.frame = _matrixRect;
    _totalsView.frame = [self totalsRectForSize:size];
}

- (void)adaptToInterfaceRotation {
    [self adaptLayoutToSize:self.frame.size];
}

- (void)adaptToSize:(CGSize)size {
    [self adaptLayoutToSize:size];
}

- (void)setBallot:(Ballot *)ballot {
    _ballot = ballot;
    
    [self updateParticipants];
    
    _numChoices = [_ballot.choicesSortedByOrder count];
    _numParticipants = [_participantIds count];

    [self drawDataForSize:self.frame.size];
}

- (CGRect)matrixRectForSize:(CGSize)size {
    CGFloat offsetLeft = X_PADDING + MATRIX_PADDING + [self choicesWidthForSize:size] + _totalsWidth;
    CGFloat offsetRight = X_PADDING;
    CGFloat width = size.width - offsetLeft - offsetRight;
    
    CGFloat contactsHeight = [self contactsHeightForSize:size];
    CGFloat height = size.height - TOP_PADDING - BOTTOM_PADDING - contactsHeight;
    
    return CGRectMake(offsetLeft, TOP_PADDING + contactsHeight, width, height);
}

- (CGRect)choicesRectForSize:(CGSize)size {
    CGFloat contactsHeight = [self contactsHeightForSize:size];
    CGFloat y = TOP_PADDING + contactsHeight;
    CGFloat height = size.height - TOP_PADDING - BOTTOM_PADDING - contactsHeight;

    return CGRectMake(X_PADDING, y, [self choicesWidthForSize:size], height);
}

- (CGRect)contactsRectForSize:(CGSize)size {
    return CGRectMake(_matrixRect.origin.x, TOP_PADDING, _matrixRect.size.width, [self contactsHeightForSize:size]);
}

- (CGRect)totalsRectForSize:(CGSize)size {
    return CGRectMake(X_PADDING + [self choicesWidthForSize:size], TOP_PADDING + [self contactsHeightForSize:size], _totalsWidth, _matrixRect.size.height);
}

- (CGFloat)sin {
    CGFloat absRad = ABS(_labelAngleRadians);
    return sinf(absRad);
}

- (CGFloat)cos {
    CGFloat absRad = ABS(_labelAngleRadians);
    return cosf(absRad);
}

- (CGFloat)choicesWidthForSize:(CGSize)size {
    CGFloat width = size.width - 2*X_PADDING - _totalsWidth - MATRIX_PADDING - [self contactsTotalWidth];
    
    // minimum choice length
    return fmaxf(width, _minChoiceLabelLength);
}

- (CGFloat)contactsHeightForSize:(CGSize)size {
    if (SYSTEM_IS_IPAD || size.height > size.width) {
        return _contactLabelLength * [self sin] + _contactLabelHeight * [self cos] + CONTACT_AVATAR_SIZE;
    } else {
        return CONTACT_AVATAR_SIZE;
    }
}

- (CGFloat)contactsWidth {
    if (SYSTEM_IS_IPAD || UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        return _contactLabelLength * [self cos] + _contactLabelHeight * [self sin];
    } else {
        return CONTACT_AVATAR_SIZE;
    }
}

- (CGFloat)contactsTotalWidth {
    return (_numParticipants - 1) * _gridWidth + [self contactsWidth];
}

- (void)drawDataForSize:(CGSize)size {
    _matrixRect = [self matrixRectForSize:size];
    
    ScrollViewContent *choicesContent = [self makeChoicesViewForSize:size];
    _choicesView = [[SlaveScrollView alloc] initWithFrame: [self choicesRectForSize:size]];
    _choicesView.horizontalScrollingEnabled = NO;
    [_choicesView.panGestureRecognizer requireGestureRecognizerToFail: _panGesture];
    [_choicesView setContent: choicesContent];
    [self addSubview:_choicesView];

    ScrollViewContent *contactsContent = [self makeContactsViewForSize:size];
    _contactsView = [[SlaveScrollView alloc] initWithFrame: [self contactsRectForSize:size]];
    [_contactsView.panGestureRecognizer requireGestureRecognizerToFail: _panGesture];
    [_contactsView setContent: contactsContent];
    [self addSubview:_contactsView];

    ScrollViewContent *matrixContent = [self makeMatrixView];
    _matrixView = [[SlaveScrollView alloc] initWithFrame: _matrixRect];
    [_matrixView.panGestureRecognizer requireGestureRecognizerToFail: _panGesture];
    [_matrixView setContent: matrixContent];
    [self addSubview:_matrixView];

    CGRect totalsRect = [self totalsRectForSize:size];
    ScrollViewContent *totalsContent = [self makeResultTotalsView];
    _totalsView = [[SlaveScrollView alloc] initWithFrame: totalsRect];
    [_totalsView.panGestureRecognizer requireGestureRecognizerToFail: _panGesture];
    [_totalsView setContent: totalsContent];
    [self addSubview:_totalsView];
    
    [self updateLineColors];
    
    [self markHighestVotes];
    
    [self setNeedsLayout];
}

- (void)updateLineColors {
    UIColor *color;
    for (NSInteger i = 0; i < _numChoices; i++) {
        if (i % 2 == 0) {
            color = ROW_COLOR_LIGHT;
        } else {
            color = ROW_COLOR_DARKER;
        }

        [_choicesView setColor:color forRowAt:i];
        [_totalsView setColor:color forRowAt:i];
        [_matrixView setColor:color forRowAt:i];
    }
}

- (void)markHighestVotes {
    for (NSNumber *indexNumber in _highestVotes) {
        NSInteger idx = indexNumber.integerValue;
        [_choicesView setColor:HIGHEST_VOTE_COLOR forRowAt:idx];
        [_totalsView setColor:HIGHEST_VOTE_COLOR forRowAt:idx];
        [_matrixView setColor:HIGHEST_VOTE_COLOR forRowAt:idx];
        
        if ([Colors getTheme] == ColorThemeLight || [Colors getTheme] == ColorThemeLightWork) {
            [_choicesView setTextColor:[Colors fontInverted] forRowAt:idx];
            [_totalsView setTextColor:[Colors fontInverted] forRowAt:idx];
             [_matrixView setTextColor:[Colors fontInverted] forRowAt:idx];
        }
    }
}

- (ScrollViewContent *)makeContactsViewForSize:(CGSize)size {
    CGFloat height = [self contactsHeightForSize:size];
    BOOL showLabel = height > CONTACT_AVATAR_SIZE;

    CGRect contactRect;
    CGFloat yOffsetAvatar;
    CGFloat totalWidth;
    if (showLabel) {
        contactRect = [self contactsLabelRectForSize:size];
        totalWidth = [self contactsTotalWidth];
        yOffsetAvatar = height - CONTACT_AVATAR_SIZE;
    } else {
        contactRect = CGRectMake(0.0, 0.0, CONTACT_AVATAR_SIZE, CONTACT_AVATAR_SIZE);
        totalWidth = _participantNames.count * CONTACT_AVATAR_SIZE;
        yOffsetAvatar = 0.0;
    }
    
    CGRect totalRect = CGRectMake(0.0, 0.0, totalWidth, height);
    ScrollViewContent *contactView = [[ScrollViewContent alloc] initWithFrame:totalRect];
    
    for (int i = 0; i < _participantNames.count; i++) {
        if (showLabel) {
            NSString *participant = _participantNames[i];
            
            contactRect = [RectUtil offsetRect:contactRect byX:_gridWidth byY:0.0];
            CGRect labelRect = [RectUtil offsetRect:contactRect byX:0 byY:-CONTACT_AVATAR_SIZE];
            BallotMatrixLabelView *contactLabel = [self rotatedLabelAt:labelRect withText:participant];
            contactLabel.font = [UIFont systemFontOfSize: CONTACT_FONT_SIZE];
            
            [contactView addSubview: contactLabel];
        }
        
        UIImage *avatar = _participantAvatars[i];
        UIImageView *contactAvatar = [[UIImageView alloc] initWithImage:avatar];
        CGRect avatarRect = CGRectMake(i*GRID_WIDTH, yOffsetAvatar, CONTACT_AVATAR_SIZE, CONTACT_AVATAR_SIZE);
        avatarRect = CGRectInset(avatarRect, CONTACT_AVATAR_PADDING, CONTACT_AVATAR_PADDING);
        contactAvatar.frame = avatarRect;
        contactAvatar.tag = i;
        [contactView addSubview: contactAvatar];

        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [contactAvatar addGestureRecognizer:tapGesture];
        contactAvatar.userInteractionEnabled = YES;
    }
    
    return contactView;
}

- (CGRect)contactsLabelRectForSize:(CGSize)size {
    CGFloat height = [self contactsHeightForSize:size];
    CGFloat width = [self contactsWidth];
    
    CGFloat rotationXOffset = (width - _contactLabelLength)/2.0 - _contactLabelHeight * [self sin] + CONTACT_Y_OFFSET_CORRECTION;
    CGFloat rotationYOffset = (height - _contactLabelHeight + CONTACT_AVATAR_SIZE)/2.0;

    return CGRectMake(rotationXOffset, rotationYOffset, _contactLabelLength, _contactLabelHeight);
}

- (BallotMatrixLabelView *)rotatedLabelAt:(CGRect)rect withText:(NSString*)string {
    CGFloat sin = [self sin];
    CGFloat yLabelOffset = rect.size.height - rect.size.height * sin;

    BallotMatrixLabelView *label = [BallotMatrixLabelView labelForString:string at:rect];
    [label offsetAndResizeHeight: yLabelOffset];
    label.transform = CGAffineTransformMakeRotation(_labelAngleRadians);
    
    return label;
}

- (ScrollViewContent *)makeChoicesViewForSize:(CGSize)size {
    CGFloat totalHeight = _numChoices * _gridHeight;
    CGRect totalRect = CGRectMake(0.0, 0.0, _minChoiceLabelLength, totalHeight);
    ScrollViewContent *choiceView = [[ScrollViewContent alloc] initWithFrame:totalRect];
    
    // create views & get max width
    CGFloat yOffset = 0.0;
    CGFloat maxWidth = 0.0;
    NSMutableArray *labelViews = [NSMutableArray array];
    for (BallotChoice *choice in _ballot.choicesSortedByOrder) {
        CGRect contactRect = CGRectMake(0.0, yOffset, _minChoiceLabelLength, _gridHeight);
        BallotMatrixLabelView *choiceLabel = [BallotMatrixLabelView labelForString:choice.name at:contactRect];
        
        choiceLabel.accessibilityValue = [self accessibilityValueForChoice:choice];
        choiceLabel.isAccessibilityElement = YES;
        
        choiceLabel.font = [UIFont systemFontOfSize: CHOICE_FONT_SIZE];
        choiceLabel.borderWidth = BORDER_WIDTH;
        choiceLabel.borderColor = BORDER_COLOR;
        choiceLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [choiceLabel sizeToFit];
        
        [labelViews addObject: choiceLabel];
        yOffset += _gridHeight;
        
        maxWidth = fmaxf(maxWidth, CGRectGetWidth(choiceLabel.frame));
        
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [choiceLabel addGestureRecognizer:tapGesture];
    }

    if (maxWidth < [self choicesWidthForSize:size]) {
        maxWidth = [self choicesWidthForSize:size];
        choiceView.frame = [RectUtil setWidthOf:choiceView.frame width:maxWidth];
    }
    
    choiceView.minWidth = maxWidth;
    
    // resize and insert
    for (BallotMatrixLabelView *label in labelViews) {
        label.frame = [RectUtil setWidthOf:label.frame width:maxWidth];
        
        [choiceView addSubview: label];
    }
    
    return choiceView;
}

- (NSString *)accessibilityValueForChoice:(BallotChoice *)choice {
    NSMutableString *participants = [NSMutableString string];
    
    for (NSString *identity in choice.participantIdsForResultsTrue) {
        NSInteger index = [_participantIds indexOfObject:identity];
        if (index != NSNotFound) {
            if (participants.length > 0) {
                [participants appendString:@", "];
            }

            [participants appendString:_participantNames[index]];
        }
    }

    NSString *votesCountFormat = NSLocalizedStringFromTable(@"ballot_votes_count", @"Ballot", nil);
    NSString *votesCount = [NSString stringWithFormat:votesCountFormat, [NSString stringWithFormat: @"%li", (long)[choice totalCountOfResultsTrue]]];

    // use commas to create a pause for voice over
    return [NSString stringWithFormat:@"%@, %@, %@", choice.name, votesCount, participants];
}

- (ScrollViewContent *)makeResultTotalsView {
    
    CGFloat height = _numChoices * _gridHeight;

    CGRect rect = CGRectMake(0.0, 0.0, _totalsWidth, height);
    ScrollViewContent *resultTotalsView = [[ScrollViewContent alloc] initWithFrame:rect];
    resultTotalsView.layer.borderWidth = 0.5;
    resultTotalsView.layer.borderColor = BORDER_COLOR.CGColor;

    CGFloat xOffset = 0.0;
    CGFloat yOffset = 0.0;
    
    NSInteger index = 0;
    NSInteger maxCount = 0;
    for (BallotChoice *choice in _ballot.choicesSortedByOrder) {
        NSInteger count = [choice totalCountOfResultsTrue];
        
        if (count > 0) {
            if (count == maxCount) {
                [_highestVotes addObject: [NSNumber numberWithInteger:index]];
            } else if (count > maxCount) {
                maxCount = count;
                [_highestVotes removeAllObjects];
                [_highestVotes addObject:[NSNumber numberWithInteger:index]];
            }
        }
        
        CGRect rect = CGRectMake(xOffset, yOffset, _totalsWidth, _gridHeight);
        rect = [RectUtil rect:rect centerHorizontalIn:resultTotalsView.bounds];
        
        NSString *text = [NSString stringWithFormat:@"%li", (long)count];
        BallotMatrixLabelView *label = [BallotMatrixLabelView labelForString:text at:rect];
        label.maxWidth = _totalsWidth;
        label.textAlignment = NSTextAlignmentRight;
        label.borderWidth = BORDER_WIDTH;
        label.borderColor = BORDER_COLOR;
        
        [resultTotalsView addSubview:label];
        
        yOffset += _gridHeight;
        index++;
    }
    
    return resultTotalsView;
}

- (ScrollViewContent *)makeMatrixView {
    CGFloat totalHeight = _numChoices * _gridHeight;
    CGFloat rowWidth = _numParticipants * _gridWidth;
    CGFloat totalWidth = [self contactsTotalWidth];

    CGRect rect = CGRectMake(0.0, 0.0, totalWidth, totalHeight);
    ScrollViewContent *matrixView = [[ScrollViewContent alloc] initWithFrame:rect];
    
    CGFloat xOffset = 0.0;
    CGFloat yOffset = 0.0;
    
    for (BallotChoice *choice in _ballot.choicesSortedByOrder) {
        CGRect rowRect = CGRectMake(0.0, yOffset, rowWidth, _gridHeight);
        UIView *rowView = [[UIView alloc] initWithFrame: rowRect];
        
        for (NSString *participantId in _participantIds) {
            CGRect rect = CGRectMake(xOffset, 0.0, _gridWidth, _gridHeight);
            BallotResultMatrixCell *result = [[BallotResultMatrixCell alloc] initWithFrame:rect];
            [result updateResultForChoice:choice andParticipant:participantId];
            result.borderWidth = BORDER_WIDTH;
            result.borderColor = BORDER_COLOR;


            [rowView addSubview:result];
            
            xOffset += _gridWidth;
        }
 
        [matrixView addSubview:rowView];

        yOffset += _gridHeight;
        xOffset = 0.0;
    }
    
    return matrixView;
}

- (void)updateParticipants {
    _participantIds = [NSMutableArray array];
    _participantNames = [NSMutableArray array];
    _participantAvatars = [NSMutableArray array];

    NSString *myIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
    [_participantIds addObject:myIdentity];
    [_participantNames addObject:[BundleUtil localizedStringForKey:@"me"]];
    
    NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
    UIImage *image = [UIImage imageWithData:profilePicture[@"ProfilePicture"]];
    if (image) {
        [_participantAvatars addObject:[[AvatarMaker sharedAvatarMaker] maskedProfilePicture:image size:CONTACT_AVATAR_SIZE-2*CONTACT_AVATAR_PADDING]];
    } else {
        [_participantAvatars addObject:[[AvatarMaker sharedAvatarMaker] avatarForContact:nil size:CONTACT_AVATAR_SIZE-2*CONTACT_AVATAR_PADDING masked:YES]];
    }
        
    for (Contact *contact in _ballot.participants) {
        [_participantIds addObject:contact.identity];
        [_participantNames addObject:contact.displayName];
        [_participantAvatars addObject:[[AvatarMaker sharedAvatarMaker] avatarForContact:contact size:CONTACT_AVATAR_SIZE-2*CONTACT_AVATAR_PADDING masked:YES]];
    }
}

#pragma mark - touch handling

- (void)pan:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint position = [gestureRecognizer locationInView:self];
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            _beginTouchPoint = position;
            break;
            
        case UIGestureRecognizerStateChanged:
            [self panChangedTo:position];
            break;
            
        case UIGestureRecognizerStateEnded:
            _endTouchPoint = _matrixView.position;
            break;
            
        default:
            break;
    }
}

- (void)panChangedTo:(CGPoint)position
{
    CGPoint diffWithOffset = [self positionDiffFor:position];
    
    [self updateSlaveViewsToPosition:diffWithOffset];
}

- (void)updateSlaveViewsToPosition:(CGPoint)position {
    [_choicesView setPosition:position];
    [_totalsView setPosition:position];

    CGPoint matrixPos = [_matrixView setPosition:position];
    [_contactsView setPosition:matrixPos];
}

- (CGPoint)positionDiffFor:(CGPoint)position {
    CGPoint positionDiff = [self diffFromPoint:_beginTouchPoint toPoint:position];
    CGPoint diffWithOffset = [self addPoint:_endTouchPoint toPoint:positionDiff];
    
    return diffWithOffset;
}

- (CGPoint)diffFromPoint:(CGPoint)fromPoint toPoint:(CGPoint)toPoint {
    CGFloat x = fromPoint.x - toPoint.x;
    CGFloat y = fromPoint.y - toPoint.y;
    return CGPointMake(x, y);
}

- (CGPoint)addPoint:(CGPoint)point toPoint:(CGPoint)toPoint {
    CGFloat x = toPoint.x + point.x;
    CGFloat y = toPoint.y + point.y;
    return CGPointMake(x, y);
}

#pragma mark - UITapGestureRecognizer

- (void)handleTap:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        if ([sender.view isKindOfClass:[BallotMatrixLabelView class]]) {
            BallotMatrixLabelView *label = (BallotMatrixLabelView *)sender.view;
            
            CGPoint point = [self convertPoint:label.bounds.origin fromView:label];
            _popoverView = [PopoverView showPopoverAtPoint:point inView:self withTitle:nil withText:label.text delegate:self];
        } else if ([sender.view isKindOfClass:[UIImageView class]]) {
            UIImageView *avatarView = (UIImageView *)sender.view;
            
            NSInteger index = [self indexForAvatarImage:avatarView.image];
            if (index >= 0) {
                CGPoint point = [self convertPoint:avatarView.bounds.origin fromView:avatarView];
                point.x += avatarView.bounds.size.width/2.0;
                NSString *name = [_participantNames objectAtIndex:avatarView.tag];
                _popoverView = [PopoverView showPopoverAtPoint:point inView:self withTitle:nil withText:name delegate:self];
            }
        }
    }
}

- (NSInteger)indexForAvatarImage:(UIImage *)image {
    for (NSInteger i=0; i<[_participantAvatars count]; i++) {
        UIImage *avatar = [_participantAvatars objectAtIndex:i];
        if (image == avatar) {
            return i;
        }
    }
    
    return -1;
}

- (void)viewControllerWillDisappear {
    [_popoverView dismiss:false];
    _popoverView = nil;
}

#pragma mark - Popover delegate

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    _popoverView = nil;
}

@end
