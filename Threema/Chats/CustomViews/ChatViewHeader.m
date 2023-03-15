//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "VoIPHelper.h"
#import <Contacts/Contacts.h>
#import "ChatViewHeader.h"
#import "ContactEntity.h"
#import "ImageData.h"
#import "MWPhotoBrowser.h"
#import "ImageMessageEntity.h"
#import "NibUtil.h"
#import "Old_ChatViewController.h"
#import "RectUtil.h"
#import "BallotListTableViewController.h"
#import "AvatarMaker.h"
#import "HairlineView.h"
#import "VideoCaptionView.h"
#import "FileCaptionView.h"
#import "PhotoCaptionView.h"
#import "MediaBrowserPhoto.h"
#import "MediaBrowserVideo.h"
#import "MediaBrowserFile.h"
#import "StatusNavigationBar.h"
#import "UIDefines.h"
#import "ChatViewSearchHeader.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"
#import "FileMessagePreview.h"
#import "PreviewActionNavigationController.h"
#import "FeatureMask.h"
#import "ServerConnector.h"
#import "UserSettings.h"
#import "ThreemaUtilityObjC.h"
#import "ImageUtils.h"
#import "Threema-Swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif


#define CONVERSATION_KEYPATHS @[@"contact.verificationLevel", @"contact.cnContactId", @"contact.imageData", @"messages", @"displayName", @"groupImage"]

@interface ChatViewHeader () <MWPhotoBrowserDelegate, MWVideoDelegate, MWFileDelegate, ChatViewSearchHeaderDelegate, MaterialShowcaseDelegate, ConnectionStateDelegate>

@property Group *group;

@property NSArray *mediaMessages;
@property MWPhotoBrowser *photoBrowser;

@property NSMutableArray *callNumbers;
@property NSUInteger deletePhotoIndex;

@property UIScrollView *groupImagesView;

@property EntityManager *entityManager;

@property NSMutableSet *photoSelection;

@property ChatViewSearchHeader *searchView;

@property UIVisualEffectView *effectView;

@property FileMessagePreview *fileMessagePreview;

@property MaterialShowcase *showCase;

@property NSTimer *setupTimer;

@end

@implementation ChatViewHeader

- (void)awakeFromNib {
    [self fixLinePosition:self.horizontalDividerLine1];
    [self fixLinePosition:self.horizontalDividerLine2];
    [self setupButtons];

    _callButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"call"];
    
    _entityManager = [[EntityManager alloc] init];
    _searchButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"search"];
    _notificationsSettingsButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"doNotDisturb_title"];
    
    _threemaTypeIcon.image = [ThreemaUtilityObjC threemaTypeIcon];
    
    [self updateColors];

    [super awakeFromNib];
}

- (void)updateColors {
    UIImage *image = [UIImage imageNamed:@"Search" inColor:UIColor.primary];
    [_searchButton setImage:image forState:UIControlStateNormal];
    
    PushSetting *pushSetting = [PushSetting pushSettingForConversation:_conversation];
    UIImage *pushSettingIcon = [pushSetting imageForPushSetting];
    [_notificationsSettingsButton setImage:[pushSettingIcon imageWithTint:UIColor.primary] forState:UIControlStateNormal];
    
    UIImage *origPhoneImage = [UIImage imageNamed:@"ThreemaPhone" inColor:UIColor.primary];
    UIImage *phoneImage = [ImageUtils imageWithImage:origPhoneImage scaledToSize:CGSizeMake(30, 30)];
    
    _callButton.imageView.contentMode = UIViewContentModeCenter;
    _callButton.enabled = [UserSettings sharedUserSettings].enableThreemaCall;
    [_callButton setImage:phoneImage forState:UIControlStateNormal];
    
    _verticalDividerLine1.backgroundColor = Colors.hairLine;
    _verticalDividerLine2.backgroundColor = Colors.hairLine;
    _verticalDividerLine3.backgroundColor = Colors.hairLine;
    _horizontalDividerLine1.backgroundColor = Colors.hairLine;
    _horizontalDividerLine2.backgroundColor = Colors.hairLine;
    
    _avatarButton.accessibilityIgnoresInvertColors = true;
    
    [self addBlur];
    
    [_searchView updateColors];
}

- (void)refresh {
    [self updateColors];
    [self setupWithTimer];
}

- (void)cancelSearch {
    [_searchView cancelAction:self];
}

- (void)dealloc {
    [self removeObservers];
}

- (void)layoutSubviews {
    CGFloat currentHeight = CGRectGetHeight(self.frame);
    CGFloat height = [self getHeight];
    self.frame = [RectUtil setHeightOf:self.frame height:height];
    
    if (_chatViewController.searching == NO) {
        _mainView.hidden = NO;
        _horizontalDividerLine1.hidden = NO;
        
        [self layoutButtons];
    } else {
        _mainView.hidden = YES;
        _optionalButtonsView.hidden = YES;
        _horizontalDividerLine1.hidden = YES;
    }
    
    if (currentHeight != height && _delegate != nil) {
        [_delegate didChangeHeightTo:height];
    }
    
    _searchView.frame = [RectUtil setWidthOf:_searchView.frame width:self.frame.size.width];
}

- (void)layoutButtons {
    if ([self showOptionalButtons] == NO) {
        _optionalButtonsView.hidden = YES;
    } else {
        _optionalButtonsView.hidden = NO;
        
        CGFloat x = CGRectGetMaxX(_notificationsSettingsButton.frame);
        CGFloat buttonsTotalWidth = CGRectGetWidth(_optionalButtonsView.frame) - _searchButton.frame.size.width - _notificationsSettingsButton.frame.size.width;
        if (_mediaButton.hidden) {
            _ballotsButton.frame = [RectUtil setWidthOf:_ballotsButton.frame width:buttonsTotalWidth];
            _ballotsButton.frame = [RectUtil setXPositionOf:_mediaButton.frame x:x];
        } else if (_ballotsButton.hidden) {
            _mediaButton.frame = [RectUtil setWidthOf:_mediaButton.frame width:buttonsTotalWidth];
            _mediaButton.frame = [RectUtil setXPositionOf:_mediaButton.frame x:x];
        } else {
            CGFloat buttonWidth = round(buttonsTotalWidth/2.0);
            _mediaButton.frame = [RectUtil setWidthOf:_mediaButton.frame width:buttonWidth];
            _mediaButton.frame = [RectUtil setXPositionOf:_mediaButton.frame x:x];
            
            _ballotsButton.frame = [RectUtil setWidthOf:_ballotsButton.frame width:buttonWidth];
                        
            CGFloat ballotButtonOffset = CGRectGetMaxX(_mediaButton.frame);
            _ballotsButton.frame = [RectUtil setPositionOf:_ballotsButton.frame x: ballotButtonOffset y: _ballotsButton.frame.origin.y];
            
            CGFloat verticalDividerLine3Offset = CGRectGetMaxX(_mediaButton.frame);
            _verticalDividerLine3.frame = [RectUtil setPositionOf:_verticalDividerLine3.frame x: verticalDividerLine3Offset y: _verticalDividerLine3.frame.origin.y];
        }
        _verticalDividerLine3.hidden = _ballotsButton.hidden || _mediaButton.hidden;
        
        CGFloat ballotTextRightEdge = CGRectGetMaxX([_ballotsButton titleRectForContentRect:_ballotsButton.frame]);
        CGFloat badgeXOffset = fminf(ballotTextRightEdge, CGRectGetMaxX(_ballotsButton.frame) - CGRectGetWidth(_ballotBadge.frame));
        if (_mediaButton.hidden == true) {
            badgeXOffset = badgeXOffset + (_ballotBadge.frame.size.width/2);
        }
        _ballotBadge.frame = [RectUtil setXPositionOf:_ballotBadge.frame x:badgeXOffset];
    }
    
    if (_group != nil) {
        _notificationsSettingsButton.enabled = _group.isSelfMember;
    } else {
        _notificationsSettingsButton.enabled = true;
    }
}

- (BOOL)resignFirstResponder {
    return [_searchView resignFirstResponder];
}

- (BOOL)showOptionalButtons {
    return YES;
}

- (CGFloat)getHeight {
    if (_searchView) {
        return _searchView.frame.size.height;
    } else if ([self showOptionalButtons]) {
        return CGRectGetMaxY(_optionalButtonsView.frame);
    } else {
        return CGRectGetHeight(_mainView.frame);
    }
}

- (void)fixLinePosition:(UIView*)view {
    CGRect frame = view.frame;
    frame.origin.y -= 0.5;
    view.frame = frame;
}

- (void)addBlur {
    if (_effectView) {
        [_effectView removeFromSuperview];
        _effectView = nil;
    }
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:Colors.objcBlurEffectStyle];
    _effectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    
    _effectView.frame = self.bounds;
    _effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    self.wrapperView.backgroundColor = [UIColor clearColor];
    
    [_effectView.contentView addSubview:self.wrapperView];
    [self addSubview:_effectView];
}

- (void)setupWithTimer {
    [_setupTimer invalidate];
    _setupTimer = [NSTimer timerWithTimeInterval:0.4 target:self selector:@selector(setup) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_setupTimer forMode:NSDefaultRunLoopMode];
}

- (void)setup {
    if (_conversation.groupId != nil) {
        [self setupForGroup];
    } else {
        [self setupForIndividual];
    }
    
    [self updateBallotButton];
    [self updateMediaButton];
    [self checkEnableCallButtons];
}

- (void)setupButtons {
    [_avatarButton addTarget:self action:@selector(showContactDetails) forControlEvents:UIControlEventTouchUpInside];

    [_verificationLevel addTarget:self action:@selector(showContactDetails) forControlEvents:UIControlEventTouchUpInside];
    
    [_mediaButton setTitle:[BundleUtil localizedStringForKey:@"media_overview"] forState:UIControlStateNormal];
    [_ballotsButton setTitle:[BundleUtil localizedStringForKey:@"ballots"] forState:UIControlStateNormal];
}

- (void)updateMediaButton {
    NSInteger numMedia = [_entityManager.entityFetcher countMediaMessagesForConversation:_conversation];
    _mediaButton.hidden = numMedia < 1;

    [self setNeedsLayout];
}

- (void)updateBallotButton {
    NSInteger numBallots = [_entityManager.entityFetcher countBallotsForConversation:_conversation];
    if (numBallots > 0) {
        NSInteger numOpenBallots = [_entityManager.entityFetcher countOpenBallotsForConversation:_conversation];
        if (numOpenBallots > 0) {
            _ballotBadge.value = numOpenBallots;
            _ballotBadge.hidden = NO;
        } else {
            _ballotBadge.hidden = YES;
        }
        
        _ballotsButton.hidden = NO;
    } else {
        _ballotBadge.hidden = YES;
        _ballotsButton.hidden = YES;
    }
    
    [self setNeedsLayout];
}

- (void)setupForGroup {
    _verificationLevel.hidden = YES;
    _callButton.hidden = YES;
    _avatarButton.hidden = YES;
    
    if (_groupImagesView) {
        [_groupImagesView removeFromSuperview];
    }
    
    UIView *imageContainer = [self makeContactImagesForGroup];
    
    _groupImagesView = [[UIScrollView alloc] initWithFrame: _mainView.bounds];
    _groupImagesView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_groupImagesView addSubview: imageContainer];
    _groupImagesView.contentSize = imageContainer.bounds.size;

    [_entityManager performBlockAndWait:^{
        _groupImagesView.accessibilityLabel = _group.membersList;
    }];
    _groupImagesView.accessibilityTraits = UIAccessibilityTraitButton;
    _groupImagesView.isAccessibilityElement = YES;
    _groupImagesView.accessibilityIgnoresInvertColors = true;

    //otherwise containing scrollview does not get this event
    _groupImagesView.scrollsToTop = NO;
    
    UITapGestureRecognizer *photoTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showContactDetails)];
    [_groupImagesView addGestureRecognizer:photoTapGesture];
    
    _groupImagesView.accessibilityIdentifier = @"GroupImageView";

    [_mainView addSubview:_groupImagesView];
    
    _threemaTypeIcon.hidden = YES;
    
    [self setNeedsLayout];
}

/// This function is full of weird workarounds and hacks to not trip the core data concurrency debugger. We'll leave it like this until the full refactor is completed.
- (UIView *)makeContactImagesForGroup {
    CGFloat width = _avatarButton.bounds.size.width;
    
    CGFloat margin = 6.0f;
    NSInteger memberCount = [_conversation.members count];
    CGFloat height = _mainView.bounds.size.height;
    CGFloat totalWidth = memberCount * width + (memberCount + 1) * margin;
    
    CGRect containerRect = CGRectMake(0.0, 0.0, totalWidth, height);
    UIView *imageContainer = [[UIView alloc] initWithFrame: containerRect];
    
    __block CGRect imageRect = CGRectMake(margin, 0.0, width, width);
    imageRect = [RectUtil rect:imageRect centerVerticalIn:imageContainer.frame];
    
    EntityManager *backgroundEntityManager = [[EntityManager alloc] initWithChildContextForBackgroundProcess:true];
    EntityManager *mainThreadEntityManager = [[EntityManager alloc] initWithChildContextForBackgroundProcess:false];
    
    [backgroundEntityManager performBlock:^{
        for (NSString *identity in _group.allMemberIdentities) {
            ContactEntity *contact = [[backgroundEntityManager entityFetcher] contactForId:identity];
            if (contact == nil) {
                continue;
            }
            if (contact.state.intValue == kStateInvalid) {
                continue;
            }
            
            [[AvatarMaker sharedAvatarMaker] avatarForContactEntity:contact size:width masked:YES onCompletion:^(UIImage *avatarImage, NSString *identity) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ContactEntity *mContact = [[mainThreadEntityManager entityFetcher] contactForId:identity];
                    if (mContact != nil) {
                        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
                        imageView.image = avatarImage;
                        [imageContainer addSubview: imageView];
                        
                        if (![ThreemaUtilityObjC hideThreemaTypeIconForContact:mContact]) {
                            UIImageView *littleThreemaTypeIcon = [[UIImageView alloc] initWithImage:[ThreemaUtilityObjC threemaTypeIcon]];
                            littleThreemaTypeIcon.frame = CGRectMake(imageRect.origin.x - 3.0, (imageRect.origin.y + imageRect.size.height) - (imageRect.size.width / 2.5) - 1.0, imageRect.size.width / 2.5, imageRect.size.height / 2.5);
                            [imageContainer addSubview:littleThreemaTypeIcon];
                        }
                        imageRect = [RectUtil offsetRect:imageRect byX:width + margin byY:0.0];
                    }
                    
                });
            }];
        }}];
    
    return imageContainer;
}

- (void)setupForIndividual {
    [_verificationLevel setImage:[_conversation.contact verificationLevelImage] forState:UIControlStateNormal];
    _verificationLevel.hidden = NO;
    _verificationLevel.accessibilityLabel = [_conversation.contact verificationLevelAccessibilityLabel];

    [_avatarButton setImage:[[AvatarMaker sharedAvatarMaker] avatarForContactEntity:_conversation.contact size:_avatarButton.frame.size.width masked:YES] forState:UIControlStateNormal];
    
    _avatarButton.accessibilityLabel = nil;
    
    if (_conversation != nil) {
        if (_conversation.contact != nil) {
            if (_conversation.contact.displayName != nil) {
                _avatarButton.accessibilityLabel = _conversation.contact.displayName;
            }
        }
    }
    
    _callButton.alpha = 1.0;
    _callButton.enabled = [UserSettings sharedUserSettings].enableThreemaCall;
    
    _threemaTypeIcon.hidden = [ThreemaUtilityObjC hideThreemaTypeIconForContact:_conversation.contact];
}

- (void)setConversation:(Conversation *)newConversation {
    if (_conversation != newConversation) {
        [self removeObservers];
        
        _conversation = newConversation;
        
        if (_conversation.isGroup) {
            GroupManager *groupManager = [[GroupManager alloc] init];
            _group = [groupManager getGroupWithConversation:_conversation];
        }
        
        [self setupWithTimer];
    
        [self addObservers];
    }
}

- (void)addObservers {
    for (NSString *keyPath in CONVERSATION_KEYPATHS) {
        [_conversation addObserver:self forKeyPath:keyPath options:0 context:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessageReceived:) name:IncomingMessageManager.inAppNotificationNewMessage object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avatarChanged:) name:kNotificationIdentityAvatarChanged object:nil];
    
    // Listen for connection status changes so we can enable/disable the call button
    [[ServerConnector sharedServerConnector] registerConnectionStateDelegate:self];
}

- (void)removeObservers {
    for (NSString *keyPath in CONVERSATION_KEYPATHS) {
        [_conversation removeObserver:self forKeyPath:keyPath];
    }
    @try {
        [[ServerConnector sharedServerConnector] unregisterConnectionStateDelegate:self];
    } @catch(id anException) {
        // ServerConnector observer does not exist
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)cleanupMedia {
    _mediaMessages = nil;
    _photoBrowser = nil;
}

- (void)checkEnableCallButtons {
    if (ProcessInfoHelper.isRunningForScreenshots)  {
        _callButton.enabled = YES;
    } else {
        _callButton.enabled = [UserSettings sharedUserSettings].enableThreemaCall && [ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn && [VoIPHelper shared].isCallActiveInBackground == NO;
    }
}

- (NSUInteger)mediaSelectionCount {
    return _photoSelection.count;
}

- (NSSet *)mediaPhotoSelection {
    return _photoSelection;
}

- (void)startVoipCall:(BOOL)withVideo {
    if (ProcessInfoHelper.isRunningForScreenshots)  {
        VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:withVideo ? ActionCallWithVideo : ActionCall contactIdentity:self.conversation.contact.identity callID:nil completion:nil];
        [[VoIPCallStateManager shared] processUserAction:action];
    } else {
        if ([UserSettings sharedUserSettings].enableThreemaCall) {
            [_chatViewController startVoipCall:withVideo];
        }
    }
}

- (void)showThreemaVideoCallInfo {
    if (_conversation.isGroup == false) {
        if ([UserSettings sharedUserSettings].videoCallInChatInfoShown == false && [UserSettings sharedUserSettings].enableVideoCall && self.conversation.contact.isVideoCallAvailable) {
            if (_showCase == nil) {
                _showCase = [[MaterialShowcase alloc] init];
                [_showCase setTargetViewWithView:_callButton];
                _showCase.primaryText = [BundleUtil localizedStringForKey:@"call_threema_video_in_chat_info_title"];
                _showCase.secondaryText = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"call_threema_video_in_chat_info_description"], [ThreemaAppObjc currentName]];
                _showCase.backgroundPromptColor = UIColor.primary;
                _showCase.backgroundPromptColorAlpha = 0.93;
                _showCase.primaryTextSize = 24.0;
                _showCase.secondaryTextSize = 18.0;
                _showCase.primaryTextColor = Colors.textMaterialShowcase;
                _showCase.delegate = self;
            }
            
            if (!_chatViewController.showHeader) {
                [_chatViewController showHeaderWithDuration:0.3 completion:^(BOOL finished) {
                    [_showCase showWithAnimated:true hasShadow:true hasSkipButton:false completion:nil];
                }];
            } else {
                [_showCase showWithAnimated:true hasShadow:true hasSkipButton:false completion:nil];
            }
        }
    }
}

#pragma mark - actions

- (IBAction)callAction:(id)sender {
    [self startVoipCall:false];
}

- (IBAction)videoCallAction:(id)sender {
     [self startVoipCall:true];
}

- (IBAction)mediaAction:(id)sender {
    [self showPhotoBrowser];
}

- (IBAction)ballotAction:(id)sender {
    UIViewController *viewController = [BallotListTableViewController ballotListViewControllerForConversation: _conversation];
    
    [self _presentBallotViewControllerModally:viewController];
}

// Just a helper for `ballotAction:` because we want the same for iOS 13 and up and
// all iPads
- (void)_presentBallotViewControllerModally:(UIViewController *)viewController {
    ThemedNavigationController *themedNavigationController = [[ThemedNavigationController alloc] initWithRootViewController:viewController];
    themedNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [_chatViewController presentViewController:themedNavigationController animated:YES completion:nil];
}

- (IBAction)searchAction:(id)sender {
    [self showSearchView:YES];
}

- (IBAction)notificationsSettingsAction:(id)sender {
    [_chatViewController openPushSettings];
}

- (void)showSearchView:(BOOL)show {
    if (show) {
        _searchView = (ChatViewSearchHeader *)[NibUtil loadViewFromNibWithName:@"ChatViewSearchHeader"];
        _searchView.chatViewController = _chatViewController;
        _searchView.delegate = self;
        [_wrapperView addSubview:_searchView];
        
        [self setNeedsLayout];

        _chatViewController.searching = YES;
        [_searchView becomeFirstResponder];
    } else {
        _chatViewController.searching = NO;
        [_searchView resignFirstResponder];
        [_searchView removeFromSuperview];
        _searchView = nil;
        
        [self setNeedsLayout];
    }
}

- (void)showContactDetails {
    if (_conversation.groupId != nil) {
        [_chatViewController showGroupDetails];
    } else {
        [_chatViewController showSingleDetails];
    }
}

- (void)prepareMediaMessages {
    NSArray *imageMessages = [_entityManager.entityFetcher imageMessagesForConversation: _conversation];
    NSArray *videoMessages = [_entityManager.entityFetcher videoMessagesForConversation: _conversation];
    NSArray *fileMessages = [_entityManager.entityFetcher filesMessagesFilteredForPhotoBrowserForConversation:_conversation];
    
    NSMutableArray *allMediaMessages = [NSMutableArray arrayWithArray:imageMessages];
    [allMediaMessages addObjectsFromArray:videoMessages];
    [allMediaMessages addObjectsFromArray:fileMessages];

    _mediaMessages = [allMediaMessages sortedArrayWithOptions:0 usingComparator:^NSComparisonResult(BaseMessage *msg1, BaseMessage *msg2) {
        return [msg1.date compare:msg2.date];
    }];
}

- (UIViewController *)getPhotoBrowserAtMessage:(BaseMessage*)msg forPeeking:(BOOL)peeking {
    [self prepareMediaMessages];
    
    NSUInteger initialIndex = [_mediaMessages indexOfObject:msg];
    if (initialIndex == NSNotFound) {
        initialIndex = 0;
    }
    
    [self setupPhotoBrowser];
    _photoBrowser.enableSwipeToDismiss = YES;
    _photoBrowser.currentPhotoIndex = initialIndex;
    if (peeking) {
        _photoBrowser.peeking = YES;
        return _photoBrowser;
    }
    
    UINavigationController *navigationController = [[PreviewActionNavigationController alloc] initWithRootViewController:_photoBrowser];
    return navigationController;
}

- (void)showPhotoBrowser {
    [self prepareMediaMessages];
    
    [self setupPhotoBrowser];
    _photoBrowser.startOnGrid = [_mediaMessages count] > 1;
    [_photoBrowser setCurrentPhotoIndex:[_mediaMessages count]];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:_photoBrowser];
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [_chatViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)setupPhotoBrowser {
    _photoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    _photoBrowser.displayDeleteButton = YES;
    
    _photoSelection = [NSMutableSet set];
}

- (NSURL*)makeTelUrlForPhone:(NSString*)phoneNumber {
    return [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", [phoneNumber stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]]];
}


#pragma mark - key value observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass:[Conversation class]]) {
        @try {
            Conversation *conversationObject = (Conversation *)object;
            if (conversationObject.objectID == _conversation.objectID) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setupWithTimer];
                });
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into conversation");
        }
    }
}

- (void)newMessageReceived:(NSNotification*)notification {
    [self setupWithTimer];
}

#pragma mark - ConnectionStateDelegate

- (void)connectionStateChanged:(ConnectionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkEnableCallButtons];
    });
}

#pragma mark - Photo browser delegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return _mediaMessages.count;
}

- (id<MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    return [self mwPhotoAtIndex:index forThumbnail:NO];
}

- (id<MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index {
    id<MWPhoto> photo = [self mwPhotoAtIndex:index forThumbnail:YES];

    [photo loadUnderlyingImageAndNotify];   // ensure the underlying image is set to keep loading indicator from appearing

    return photo;
}

- (id<MWPhoto>)mwPhotoAtIndex:(NSUInteger)index forThumbnail:(BOOL)thumbnail {
    id<MWPhoto> media = nil;

    if (index < _mediaMessages.count) {
        BaseMessage *message = _mediaMessages[index];
        
        if ([message isKindOfClass:[VideoMessageEntity class]]) {
            MediaBrowserVideo *video = [MediaBrowserVideo videoWithThumbnail: ((VideoMessageEntity *)message).thumbnail.uiImage];
            video.delegate = self;
            video.sourceReference = (VideoMessageEntity *)message;
            video.caption = [DateFormatter shortStyleDateTime:message.remoteSentDate];
            media = video;
        } else if ([message isKindOfClass:[ImageMessageEntity class]]) {
            MediaBrowserPhoto *photo = [MediaBrowserPhoto photoWithImageMessageEntity:(ImageMessageEntity*)message thumbnail:thumbnail];
            photo.caption = [DateFormatter shortStyleDateTime:message.remoteSentDate];
            media = photo;
        } else if ([message isKindOfClass:[FileMessageEntity class]]) {
            MediaBrowserFile *file;
            file = [MediaBrowserFile fileWithFileMessageEntity:(FileMessageEntity *)message thumbnail:thumbnail];
            file.delegate = self;
            file.caption = [DateFormatter shortStyleDateTime:message.remoteSentDate];
            media = file;
        }
    }
    
    return media;
}

- (MWCaptionView *)photoBrowser:(MWPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index {
    
    id<MWPhoto> media = [photoBrowser photoAtIndex: index];
    if ([media isKindOfClass:[MediaBrowserVideo class]]) {
        VideoCaptionView *videoCaption = [[VideoCaptionView alloc] initWithPhoto:media];
        return videoCaption;
    } else if ([media isKindOfClass:[MediaBrowserPhoto class]]) {
        PhotoCaptionView *photoCaptionView = [[PhotoCaptionView alloc] initWithPhoto:media];
        return photoCaptionView;
    } else if ([media isKindOfClass:[MediaBrowserFile class]]) {
        FileCaptionView *fileCaptionView = [[FileCaptionView alloc] initWithPhoto:media];
        return fileCaptionView;
    } else {
        return nil;
    }
    
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButton:(UIBarButtonItem *)deleteButton pressedForPhotoAtIndex:(NSUInteger)index {
    _deletePhotoIndex = index;
    
    id<MWPhoto> media = [photoBrowser photoAtIndex: index];
    NSString *deleteButtonTitle = nil;
    if ([media isKindOfClass:[MediaBrowserVideo class]]) {
        deleteButtonTitle = [BundleUtil localizedStringForKey:@"delete_video"];
    } else if ([media isKindOfClass:[MediaBrowserPhoto class]]) {
        deleteButtonTitle = [BundleUtil localizedStringForKey:@"delete_photo"];
    } else if ([media isKindOfClass:[MediaBrowserFile class]]) {
        deleteButtonTitle = [BundleUtil localizedStringForKey:@"delete_file"];
    }
    
    UIAlertController *deletePhotoActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [deletePhotoActionSheet addAction:[UIAlertAction actionWithTitle:deleteButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [_entityManager performSyncBlockAndSafe:^{
            ImageMessageEntity *imageMessageEntity = _mediaMessages[_deletePhotoIndex];
            imageMessageEntity.conversation = nil;
            [[_entityManager entityDestroyer] deleteObjectWithObject:imageMessageEntity];
            
            [_chatViewController updateConversationLastMessage];
        }];
        
        [_chatViewController updateConversation];
        
        [self prepareMediaMessages];
        
        if (_mediaMessages.count == 0) {
            [_chatViewController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [_photoBrowser reloadData:true];
        }
    }]];
    
    [deletePhotoActionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:nil]];
    if (SYSTEM_IS_IPAD) {
        deletePhotoActionSheet.popoverPresentationController.barButtonItem = deleteButton;
    }
    [photoBrowser presentViewController:deletePhotoActionSheet animated:YES completion:nil];
}

- (BOOL)photoBrowser:(MWPhotoBrowser *)photoBrowser isPhotoSelectedAtIndex:(NSUInteger)index {
    return [_photoSelection containsObject:[NSNumber numberWithInteger:index]];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index selectedChanged:(BOOL)selected {
    if (selected) {
        [_photoSelection addObject:[NSNumber numberWithInteger:index]];
    } else {
        [_photoSelection removeObject:[NSNumber numberWithInteger:index]];
    }
}

- (void)photoBrowserResetSelection:(MWPhotoBrowser *)photoBrowser {
    [_photoSelection removeAllObjects];
}

- (void)photoBrowserSelectAll:(MWPhotoBrowser *)photoBrowser {
    [_photoSelection removeAllObjects];
    for (int i = 0; i < _mediaMessages.count; i++) {
        [_photoSelection addObject:[NSNumber numberWithInt:i]];
    }
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButton:(UIBarButtonItem *)deleteButton {
    if (_photoSelection.count > 0) {
        _chatViewController.deleteMediaTotal = (int)_photoSelection.count;
        [_entityManager performSyncBlockAndSafe:^{
            [_photoSelection enumerateObjectsUsingBlock:^(NSNumber *index, BOOL * _Nonnull stop) {
                ImageMessageEntity *imageMessageEntity = _mediaMessages[[index integerValue]];
                imageMessageEntity.conversation = nil;
                [[_entityManager entityDestroyer] deleteObjectWithObject:imageMessageEntity];
            }];
            
            [_chatViewController updateConversationLastMessage];
        }];
    } else {
        _chatViewController.deleteMediaTotal = (int)[self numberOfPhotosInPhotoBrowser:photoBrowser];
        [_entityManager performSyncBlockAndSafe:^{
            for (int i = 0; i < [self numberOfPhotosInPhotoBrowser:photoBrowser]; i++ ) {
                ImageMessageEntity *imageMessageEntity = _mediaMessages[i];
                imageMessageEntity.conversation = nil;
                [[_entityManager entityDestroyer] deleteObjectWithObject:imageMessageEntity];
            };
            
            [_chatViewController updateConversationLastMessage];
        }];
    }
    [_chatViewController updateConversation];
    
    [self prepareMediaMessages];
    
    if (_mediaMessages.count == 0) {
        [_chatViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [_photoBrowser finishedDeleteMedia];
    }
    
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index {
    MWPhoto *item;
    
    if ([_mediaMessages[index] isKindOfClass:[FileMessageEntity class]]) {
        FileMessageEntity *fileMessageEntity = _mediaMessages[index];
        if (fileMessageEntity.data != nil) {
            item = [photoBrowser photoAtIndex:index];
        }
    }
    else if ([_mediaMessages[index] isKindOfClass:[ImageMessageEntity class]]) {
        ImageMessageEntity *imageMessageEntity = _mediaMessages[index];
        if (imageMessageEntity.image != nil) {
            item = [photoBrowser photoAtIndex:index];
        }
    }
    else if ([_mediaMessages[index] isKindOfClass:[VideoMessageEntity class]]) {
        VideoMessageEntity *videoMessageEntity = _mediaMessages[index];
        if (videoMessageEntity.video != nil) {
            item = [photoBrowser photoAtIndex:index];
        }
    }
    
    if (item != nil) {
        [photoBrowser shareMedia:item];
    }
    else {
        [photoBrowser showAlert:@"" message:[BundleUtil localizedStringForKey:@"media_file_not_found"]];
    }
}

#pragma mark - MWVideoDelegate

- (void)playVideo:(MediaBrowserVideo *)video {
    VideoMessageEntity *message = (VideoMessageEntity *)video.sourceReference;
    if (message) {
        [_chatViewController videoMessageTapped:message];
    }
}

#pragma mark - MWFileDelegate

- (void)showFile:(FileMessageEntity *)fileMessageEntity {
    if (fileMessageEntity) {
        _fileMessagePreview = [FileMessagePreview fileMessagePreviewFor:fileMessageEntity];
        [_fileMessagePreview showOn:_photoBrowser];
    }
}

- (void)playFileVideo:(FileMessageEntity *)fileMessageEntity {
    if (fileMessageEntity) {
        [_chatViewController fileVideoMessageTapped:fileMessageEntity];
    }
}

- (void)toggleControls {
    [_photoBrowser toggleControls];
}


#pragma mark - ChatViewSearchHeaderDelegate

- (void)didCancelSearch {
    [self showSearchView:NO];
}


#pragma mark - MaterialShowCaseDelegate

- (void)showCaseDidDismissWithShowcase:(MaterialShowcase *)showcase didTapTarget:(BOOL)didTapTarget {
    [[UserSettings sharedUserSettings] setVideoCallInChatInfoShown:true];
}

#pragma mark - Notification

- (void)avatarChanged:(NSNotification*)notification
{
    if (notification.object && [self needsUpdateAvatarsForNotification:notification]) {
        [self setupWithTimer];
    }
}

- (BOOL)needsUpdateAvatarsForNotification:(NSNotification *)notification {
    __block BOOL needsUpdate = NO;
    [_entityManager performBlockAndWait:^{
        if (_conversation.isGroup) {
            for (ContactEntity *contact in _conversation.members) {
                if ([contact.identity isEqualToString:notification.object]) {
                    needsUpdate = YES;
                }
            }
        } else {
            needsUpdate = [_conversation.contact.identity isEqualToString:notification.object];
        }
    }];
    return needsUpdate;
}

@end
