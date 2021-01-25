//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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

#import <Contacts/Contacts.h>
#import "ChatViewHeader.h"
#import "Contact.h"
#import "ImageData.h"
#import "MWPhotoBrowser.h"
#import "ImageMessage.h"
#import "NibUtil.h"
#import "ChatViewController.h"
#import "EntityManager.h"
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
#import "Utils.h"
#import "ImageUtils.h"
#import "Threema-Swift.h"

#define CONVERSATION_KEYPATHS @[@"contact.verificationLevel", @"contact.cnContactId", @"contact.imageData", @"messages", @"displayName", @"groupImage"]

@interface ChatViewHeader () <MWPhotoBrowserDelegate, MWVideoDelegate, MWFileDelegate, ChatViewSearchHeaderDelegate, MaterialShowcaseDelegate>

@property NSArray *mediaMessages;
@property MWPhotoBrowser *photoBrowser;

@property NSMutableArray *callNumbers;
@property NSUInteger deletePhotoIndex;

@property UIScrollView *groupImagesView;

@property EntityManager *entityManager;

@property NSMutableSet *photoSelection;

@property ChatViewSearchHeader *searchView;

@property UIVisualEffectView *effectView;

@property FileMessagePreview *fileMessagPreview;

@property MaterialShowcase *showCase;

@end

@implementation ChatViewHeader

- (void)awakeFromNib {
    [self fixLinePosition:self.horizontalDividerLine1];
    [self fixLinePosition:self.horizontalDividerLine2];
    [self setupButtons];
    
    _callButton.accessibilityLabel = NSLocalizedString(@"call", nil);
    
    _entityManager = [[EntityManager alloc] init];
    _searchButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"search"];
    _notificationsSettingsButton.accessibilityLabel = NSLocalizedString(@"pushSetting_title", @"");
    
    _threemaTypeIcon.image = [Utils threemaTypeIcon];
    
    [self setupColors];

    [super awakeFromNib];
}

- (void)setupColors {
    _callButton.tintColor = [Colors main];
    _mediaButton.tintColor = [Colors main];
    _ballotsButton.tintColor = [Colors main];
    
    UIImage *image = [UIImage imageNamed:@"Search" inColor:[Colors main]];
    [_searchButton setImage:image forState:UIControlStateNormal];
    
    PushSetting *pushSetting = [PushSetting findPushSettingForConversation:_conversation];
    UIImage *pushSettingIcon = [UIImage imageNamed:@"Bell"];
    if (pushSetting) {
        pushSettingIcon = [pushSetting imageForPushSetting];
    }
    [_notificationsSettingsButton setImage:[pushSettingIcon imageWithTint:[Colors main]] forState:UIControlStateNormal];
    
    UIImage *phoneImage = [ImageUtils imageWithImage:[UIImage imageNamed:@"ThreemaPhone" inColor:[Colors main]] scaledToSize:CGSizeMake(30, 30)];
    [_callButton setImage:phoneImage forState:UIControlStateNormal];
    _callButton.imageView.contentMode = UIViewContentModeCenter;
    _callButton.enabled = [UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1;

    _verticalDividerLine1.backgroundColor = [Colors hairline];
    _verticalDividerLine2.backgroundColor = [Colors hairline];
    _verticalDividerLine3.backgroundColor = [Colors hairline];
    _horizontalDividerLine1.backgroundColor = [Colors hairline];
    _horizontalDividerLine2.backgroundColor = [Colors hairline];
    
    if (@available(iOS 11.0, *)) {
        _avatarButton.accessibilityIgnoresInvertColors = true;
    }
    
    [self addBlur];
}

- (void)refresh {
    [self setupColors];
    [self setup];
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
    
    if (_conversation.isGroup == true) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:_conversation];
        _notificationsSettingsButton.enabled = group.isSelfMember;
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
    
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            blurStyle = UIBlurEffectStyleDark;
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            break;
    }
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    _effectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    
    _effectView.frame = self.bounds;
    _effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    self.wrapperView.backgroundColor = [UIColor clearColor];
    
    [_effectView.contentView addSubview:self.wrapperView];
    [self addSubview:_effectView];
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
    
    [_mediaButton setTitle:NSLocalizedString(@"media_overview", nil) forState:UIControlStateNormal];
    [_ballotsButton setTitle:NSLocalizedStringFromTable(@"ballots", @"Ballot", nil) forState:UIControlStateNormal];
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
    
    _groupImagesView.accessibilityLabel = [_conversation sortedMemberNames];
    _groupImagesView.accessibilityTraits = UIAccessibilityTraitButton;
    _groupImagesView.isAccessibilityElement = YES;
    if (@available(iOS 11.0, *)) {
        _groupImagesView.accessibilityIgnoresInvertColors = true;
    }

    //otherwise containing scrollview does not get this event
    _groupImagesView.scrollsToTop = NO;
    
    UITapGestureRecognizer *photoTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showContactDetails)];
    [_groupImagesView addGestureRecognizer:photoTapGesture];
    
    _groupImagesView.accessibilityIdentifier = @"GroupImageView";

    [_mainView addSubview:_groupImagesView];
    
    _threemaTypeIcon.hidden = YES;
    
    [self setNeedsLayout];
}

- (UIView *)makeContactImagesForGroup {
    CGFloat width = _avatarButton.bounds.size.width;
    
    CGFloat margin = 6.0f;
    NSInteger memberCount = [_conversation.members count];
    CGFloat height = _mainView.bounds.size.height;
    CGFloat totalWidth = memberCount * width + (memberCount + 1) * margin;
    
    CGRect containerRect = CGRectMake(0.0, 0.0, totalWidth, height);
    UIView *imageContainer = [[UIView alloc] initWithFrame: containerRect];
    
    CGRect imageRect = CGRectMake(margin, 0.0, width, width);
    imageRect = [RectUtil rect:imageRect centerVerticalIn:imageContainer.frame];
        
    for (Contact *contact in _conversation.sortedMembers) {
        if (contact.state.intValue == kStateInvalid)
            continue;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
        imageView.image = [[AvatarMaker sharedAvatarMaker] avatarForContact:contact size:width masked:YES];
        [imageContainer addSubview: imageView];
        
        if (![Utils hideThreemaTypeIconForContact:contact]) {
            UIImageView *littleThreemaTypeIcon = [[UIImageView alloc] initWithImage:[Utils threemaTypeIcon]];
            littleThreemaTypeIcon.frame = CGRectMake(imageRect.origin.x - 3.0, (imageRect.origin.y + imageRect.size.height) - (imageRect.size.width / 2.5) - 1.0, imageRect.size.width / 2.5, imageRect.size.height / 2.5);
            [imageContainer addSubview:littleThreemaTypeIcon];
        }
        
        imageRect = [RectUtil offsetRect:imageRect byX:width + margin byY:0.0];
    }

    return imageContainer;
}

- (void)setupForIndividual {
    [_verificationLevel setImage:[_conversation.contact verificationLevelImage] forState:UIControlStateNormal];
    _verificationLevel.hidden = NO;
    _verificationLevel.accessibilityLabel = [_conversation.contact verificationLevelAccessibilityLabel];

    [_avatarButton setImage:[[AvatarMaker sharedAvatarMaker] avatarForContact:_conversation.contact size:_avatarButton.frame.size.width masked:YES] forState:UIControlStateNormal];
    
    _avatarButton.accessibilityLabel = nil;
    
    if (_conversation != nil) {
        if (_conversation.contact != nil) {
            if (_conversation.contact.displayName != nil) {
                _avatarButton.accessibilityLabel = _conversation.contact.displayName;
            }
        }
    }
    
    _callButton.alpha = 1.0;
    _callButton.enabled = [UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1;
    
    _threemaTypeIcon.hidden = [Utils hideThreemaTypeIconForContact:_conversation.contact];
}

- (void)setConversation:(Conversation *)newConversation {
    if (_conversation != newConversation) {
        [self removeObservers];
        
        _conversation = newConversation;
        [self setup];
    
        [self addObservers];
    }
}

- (void)addObservers {
    for (NSString *keyPath in CONVERSATION_KEYPATHS) {
        [_conversation addObserver:self forKeyPath:keyPath options:0 context:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessageReceived:) name:@"ThreemaNewMessageReceived" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avatarChanged:) name:kNotificationIdentityAvatarChanged object:nil];
    
    // Listen for connection status changes so we can enable/disable the call button
    [[ServerConnector sharedServerConnector] addObserver:self forKeyPath:@"connectionState" options:0 context:nil];
}

- (void)removeObservers {
    for (NSString *keyPath in CONVERSATION_KEYPATHS) {
        [_conversation removeObserver:self forKeyPath:keyPath];
    }
    @try {
        [[ServerConnector sharedServerConnector] removeObserver:self forKeyPath:@"connectionState"];
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
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
        _callButton.enabled = YES;
    } else {
        _callButton.enabled = [UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1 && [ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn;
    }
}

- (NSUInteger)mediaSelectionCount {
    return _photoSelection.count;
}

- (NSSet *)mediaPhotoSelection {
    return _photoSelection;
}

- (void)startVoipCall:(BOOL)withVideo {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
        VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:withVideo ? ActionCallWithVideo : ActionCall contact:self.conversation.contact callId:nil completion:nil];
        [[VoIPCallStateManager shared] processUserAction:action];
    } else {
        if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
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
                _showCase.secondaryText = [BundleUtil localizedStringForKey:@"call_threema_video_in_chat_info_description"];
                _showCase.backgroundPromptColor = [Colors main];
                _showCase.backgroundPromptColorAlpha = 0.93;
                _showCase.primaryTextSize = 24.0;
                _showCase.secondaryTextSize = 18.0;
                _showCase.primaryTextColor = [Colors white];
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
    
    [_chatViewController.navigationController pushViewController:viewController animated:YES];
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
        [_chatViewController performSegueWithIdentifier:@"ShowGroupInfo" sender:_chatViewController];
    } else {
        [_chatViewController performSegueWithIdentifier:@"ShowContact" sender:_chatViewController];
    }
}

- (void)prepareMediaMessages {
    NSArray *imageMessages = [_entityManager.entityFetcher imageMessagesForConversation: _conversation];
    NSArray *videoMessages = [_entityManager.entityFetcher videoMessagesForConversation: _conversation];
    NSArray *fileMessages = [_entityManager.entityFetcher fileMessagesForConversation: _conversation];

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
        if (@available(iOS 13.0, *)) {
            return _photoBrowser;
        }
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == _conversation) {
            [self setup];
        }
        if (object == [ServerConnector sharedServerConnector] && [keyPath isEqualToString:@"connectionState"]) {
            [self checkEnableCallButtons];
        }
    });
}

- (void)newMessageReceived:(NSNotification*)notification {
    [self setup];
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
        
        if ([message isKindOfClass:[VideoMessage class]]) {
            MediaBrowserVideo *video = [MediaBrowserVideo videoWithThumbnail: ((VideoMessage *)message).thumbnail.uiImage];
            video.delegate = self;
            video.sourceReference = (VideoMessage *)message;
            video.caption = [DateFormatter shortStyleDateTime:message.remoteSentDate];
            media = video;
        } else if ([message isKindOfClass:[ImageMessage class]]) {
            MediaBrowserPhoto *photo = [MediaBrowserPhoto photoWithImageMessage:(ImageMessage*)message thumbnail:thumbnail];
            photo.caption = [DateFormatter shortStyleDateTime:message.remoteSentDate];
            media = photo;
        } else if ([message isKindOfClass:[FileMessage class]]) {
            MediaBrowserFile *file;
            file = [MediaBrowserFile fileWithFileMessage:(FileMessage *)message thumbnail:thumbnail];
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
        deleteButtonTitle = NSLocalizedString(@"delete_video", nil);
    } else if ([media isKindOfClass:[MediaBrowserPhoto class]]) {
        deleteButtonTitle = NSLocalizedString(@"delete_photo", nil);
    } else if ([media isKindOfClass:[MediaBrowserFile class]]) {
        deleteButtonTitle = NSLocalizedString(@"delete_file", nil);
    }
    
    UIAlertController *deletePhotoActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [deletePhotoActionSheet addAction:[UIAlertAction actionWithTitle:deleteButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [_entityManager performSyncBlockAndSafe:^{
            ImageMessage *imageMessage = _mediaMessages[_deletePhotoIndex];
            imageMessage.conversation = nil;
            [[_entityManager entityDestroyer] deleteObjectWithObject:imageMessage];
            
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
    
    [deletePhotoActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
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
                ImageMessage *imageMessage = _mediaMessages[[index integerValue]];
                imageMessage.conversation = nil;
                [[_entityManager entityDestroyer] deleteObjectWithObject:imageMessage];
            }];
            
            [_chatViewController updateConversationLastMessage];
        }];
    } else {
        _chatViewController.deleteMediaTotal = (int)[self numberOfPhotosInPhotoBrowser:photoBrowser];
        [_entityManager performSyncBlockAndSafe:^{
            for (int i = 0; i < [self numberOfPhotosInPhotoBrowser:photoBrowser]; i++ ) {
                ImageMessage *imageMessage = _mediaMessages[i];
                imageMessage.conversation = nil;
                [[_entityManager entityDestroyer] deleteObjectWithObject:imageMessage];
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
    
    if ([_mediaMessages[index] isKindOfClass:[FileMessage class]]) {
        FileMessage *fileMessage = _mediaMessages[index];
        if (fileMessage.data != nil) {
            item = [photoBrowser photoAtIndex:index];
        }
    }
    else if ([_mediaMessages[index] isKindOfClass:[ImageMessage class]]) {
        ImageMessage *imageMessage = _mediaMessages[index];
        if (imageMessage.image != nil) {
            item = [photoBrowser photoAtIndex:index];
        }
    }
    else if ([_mediaMessages[index] isKindOfClass:[VideoMessage class]]) {
        VideoMessage *videoMessage = _mediaMessages[index];
        if (videoMessage.video != nil) {
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
    VideoMessage *message = (VideoMessage *)video.sourceReference;
    if (message) {
        [_chatViewController videoMessageTapped:message];
    }
}

#pragma mark - MWFileDelegate

- (void)showFile:(FileMessage *)fileMessage {
    if (fileMessage) {
        _fileMessagPreview = [FileMessagePreview fileMessagePreviewFor:fileMessage];
        [_fileMessagPreview showOn:_photoBrowser];
    }
}

- (void)playFileVideo:(FileMessage *)fileMessage {
    if (fileMessage) {
        [_chatViewController fileVideoMessageTapped:fileMessage];
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
        [self setup];
    }
}

- (BOOL)needsUpdateAvatarsForNotification:(NSNotification *)notification {
    if (_conversation.isGroup) {
        for (Contact *contact in _conversation.members) {
            if ([contact.identity isEqualToString:notification.object]) {
                return YES;
            }
        }
        
        return NO;
    } else {
        return [_conversation.contact.identity isEqualToString:notification.object];
    }
}

@end
