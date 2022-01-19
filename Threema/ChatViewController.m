//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

@import SafariServices;
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>
#import "ChatViewController.h"
#import "AppDelegate.h"
#import "ChatBar.h"
#import "ChatDefines.h"
#import "MessageSender.h"
#import "ContactDetailsViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ProtocolDefines.h"
#import "UserSettings.h"
#import "VideoMessageLoader.h"
#import "PreviewImageViewController.h"
#import "LocationViewController.h"
#import "MessageDetailsViewController.h"
#import "ImageMessageLoader.h"
#import "GroupDetailsViewController.h"
#import "PlayRecordAudioViewController.h"
#import "NonFirstResponderActionSheet.h"
#import "EntityManager.h"
#import "BallotDispatcher.h"
#import "RectUtil.h"
#import "MessageFetcher.h"
#import "PermissionChecker.h"
#import "StatusNavigationBar.h"
#import "ModalPresenter.h"
#import "BundleUtil.h"
#import "DocumentPicker.h"
#import "Utils.h"
#import "ChatMessageCell.h"
#import "ModalNavigationController.h"
#import "LicenseStore.h"
#import "FeatureMask.h"
#import "MessageDraftStore.h"
#import "MWPhotoBrowser.h"
#import "AppGroup.h"
#import "VoIPHelper.h"
#import "NotificationManager.h"
#import "NSString+Hex.h"
#import "NibUtil.h"
#import <MBProgressHUD/MBProgressHUD.h>

#import "ChatDeleteAction.h"
#import "SendMediaAction.h"
#import "SendLocationAction.h"

#import "ChatTableDataSource.h"
#import "BallotResultViewController.h"
#import "BallotVoteViewController.h"

#import "QuoteParser.h"

#import "FeatureMask.h"

#import "ThemedNavigationController.h"

#import "Threema-Swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface ChatViewController () <UIViewControllerPreviewingDelegate, PPAssetsActionHelperDelegate, GroupDetailsViewControllerDelegate, AVSpeechSynthesizerDelegate>

@property ChatTableDataSource *tableDataSource;
@property UIImageView *backgroundView;
@property BOOL isDirty;

@property NSMutableArray *imageMessageObserverList;
@property NSMutableArray *locationMessageObserverList;

@property UILabel *titleLabel;

@end

@implementation ChatViewController {
    BOOL visible;
    BOOL shouldScrollDown;
    UIView *containerView;
    UIView *chatBarWrapper;
    CGFloat wrapperBottomPadding;
    NSMutableArray *readReceiptQueue;
    BOOL inhibitScrollBottom;
    BOOL haveNewMessages;
    BOOL typingIndicatorSent;
    UIButton *scrollDownButton;
    
    LocationMessage* locationToShow;
    
    int numberOfPages;
    
    BaseMessage *detailsMessage;
    
    NSURL *tmpAudioVideoUrl;
    NSIndexPath *lastIndexPathBeforeRotation;
    UIInterfaceOrientation lastInterfaceOrientation;
    NSString *prevAudioCategory;
    AVPlayerViewController *player;
    
    NSString *initialMessageText;
    
    BOOL ignoreNextTap;
    
    MessageFetcher *messageFetcher;
    
    PlayRecordAudioViewController *audioRecorder;
    
    CGFloat lastKeyboardHeight;
    
    BOOL isScrollingToTop;
    BOOL isScrollingToUnreadMessages;
    BOOL isNewMessageReceivedInActiveChat;
    BOOL isFirstAppearance;
    CGPoint lastScrollOffset;
    
    EntityManager *entityManager;
    
    ChatViewControllerAction *currentAction;
    
    NSInteger currentOffset;
    BOOL forceTouching;
    
    NSIndexPath *selectedAudioMessage;
    
    PPAssetsActionHelper *assetActionHelper;
    
    CGRect lastKeyboardEndFrame;
    NSTimeInterval lastAnimationDuration;
    UIViewAnimationCurve lastAnimationCurve;
    
    BOOL _cancelShowQuotedMessage;
    
    UITapGestureRecognizer *tapGestureRecognizer;
    
    int _deleteMediaCount;
    
    /// When was the table fully reloaded last time?
    NSDate *lastFullConversationUpdate;
    
    BOOL _assetActionHelperWillPresent;
}

@synthesize sentMessageSound;
@synthesize chatContent;
@synthesize chatBar;
@synthesize headerView;
@synthesize conversation;
@synthesize imageDataToSend;
@synthesize deleteMediaTotal;
@synthesize showHeader;
@synthesize speechSynthesizer;
@synthesize prevAudioCategory;

#pragma mark NSObject

- (void)dealloc {
    for (ImageMessage *message in _imageMessageObserverList) {
        [message removeObserver:self forKeyPath:@"thumbnail"];
    }
    [_imageMessageObserverList removeAllObjects];
    
    for (LocationMessage *message in _locationMessageObserverList) {
        [message removeObserver:self forKeyPath:@"reverseGeocodingResult"];
    }
    [_locationMessageObserverList removeAllObjects];
    
    if (sentMessageSound) {
        AudioServicesDisposeSystemSoundID(sentMessageSound);
    }
    
    [self removeConversationObservers];
    
    chatContent.delegate = nil;
    chatContent.dataSource = nil;
    chatBar.delegate = nil;
    
    _tableDataSource = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        readReceiptQueue = [NSMutableArray array];
        
        entityManager = [[EntityManager alloc] init];
        
        _imageMessageObserverList = [NSMutableArray new];
        _locationMessageObserverList = [NSMutableArray new];
        
        _isOpenWithForceTouch = NO;
        _assetActionHelperWillPresent = false;
    }
    return self;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)setSearching:(BOOL)searching {
    _searching = searching;
    _tableDataSource.searching = searching;
    
    CGFloat barHeight = 0.0;
    if (_searching) {
        chatBarWrapper.hidden = YES;
    } else {
        barHeight = chatBarWrapper.frame.size.height;
        chatBarWrapper.hidden = NO;
    }
    
    chatContent.frame = [RectUtil setHeightOf:chatContent.frame height: containerView.frame.size.height - barHeight - [self tabBarHeight]];
}

- (void)setSearchPattern:(NSString *)searchPattern {
    _searchPattern = searchPattern;
    _tableDataSource.searchPattern = searchPattern;
}

- (NSIndexPath *)indexPathForMessage:(BaseMessage *)message {
    return [_tableDataSource indexPathForMessage:message];
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    return [_tableDataSource objectForIndexPath:indexPath];
}

- (BOOL)hasAlpha : (UIImage*) img {
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(img.CGImage);
    return (
            alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast
            );
}

#pragma mark UIViewController

- (void)viewWillLayoutSubviews {
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.view.frame.size.width > self.view.frame.size.height) {
        orientation = UIInterfaceOrientationLandscapeLeft;
    }
    
    [self updateConversationClearContent:NO];
    
    [self updateBackgroundForOrientation:orientation duration:0.0];
}


- (void)viewDidLayoutSubviews {
    CGFloat top;
    if (@available(iOS 11.0, *)) {
        top = self.view.safeAreaLayoutGuide.layoutFrame.origin.y;
    } else {
        top = self.topLayoutGuide.length;
    }
    if (showHeader) {
        headerView.frame = [RectUtil setYPositionOf:headerView.frame y:top];
    }
    
    // self.topLayoutGuide is only available after view was added -> make sure offset is set
    [self updateChatContentInset];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UserSettings sharedUserSettings] checkWallpaper];
    
    self.navigationController.interactivePopGestureRecognizer.enabled  = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    
    speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
    speechSynthesizer.delegate = self;
    
    /* Load sounds */
    NSString *sendPath = [BundleUtil pathForResource:@"sent_message" ofType:@"caf"];
    CFURLRef baseURL = (__bridge CFURLRef)[NSURL fileURLWithPath:sendPath];
    AudioServicesCreateSystemSoundID(baseURL, &sentMessageSound);
    
    self.navigationController.tabBarItem.image = [UIImage imageNamed:@"TabBar-Chats"];
    self.navigationController.tabBarItem.selectedImage = [UIImage imageNamed:@"TabBar-Chats"];
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.view.backgroundColor = [Colors backgroundChat]; // shown during rotation
    
    if (@available(iOS 11.0, *)) {
        containerView = [[UIView alloc] initWithFrame:self.view.safeAreaLayoutGuide.layoutFrame];
    } else {
        containerView = [[UIView alloc] initWithFrame:self.view.frame];
    }
    
    containerView.backgroundColor = [UIColor clearColor];
    containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:containerView];
    
    // Calculate initial height based on font size (ugly hack)
    float fontSize = [UserSettings sharedUserSettings].chatFontSize;
    float initialChatBarHeight = kChatBarHeight1;
    if (fontSize >= 36)
        initialChatBarHeight = 64.0;
    else if (fontSize >= 30)
        initialChatBarHeight = 57.0;
    else if (fontSize >= 28)
        initialChatBarHeight = 55.0;
    else if (fontSize >= 24)
        initialChatBarHeight = 50.0;
    else if (fontSize >= 20)
        initialChatBarHeight = 45.0;
    
    CGFloat initialChatBarWrapperPadding = 0.0f;
    if ([AppDelegate hasBottomSafeAreaInsets] && !SYSTEM_IS_IPAD) {
        initialChatBarWrapperPadding += kIphoneXChatBarBottomPadding;
        wrapperBottomPadding = kIphoneXChatBarBottomPadding;
    }
    
    // Create chatContent
    CGFloat chatContentHeight = containerView.frame.size.height - initialChatBarHeight - [self tabBarHeight] - initialChatBarWrapperPadding;
    CGRect chatContectRect = CGRectMake(0.0f, 0.0f, containerView.frame.size.width, chatContentHeight);
    chatContent = [[UITableView alloc] initWithFrame:chatContectRect];
    chatContent.clearsContextBeforeDrawing = NO;
    chatContent.backgroundColor = [UIColor clearColor];
    chatContent.separatorStyle = UITableViewCellSeparatorStyleNone;
    chatContent.separatorColor = [UIColor clearColor];
    chatContent.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    chatContent.allowsSelection = NO;
    chatContent.allowsSelectionDuringEditing = YES;
    chatContent.allowsMultipleSelectionDuringEditing = YES;
    [chatContent registerNib:[UINib nibWithNibName:@"UnreadMessageLineCell" bundle:nil] forCellReuseIdentifier:@"UnreadMessageLineCell"];
    
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(chatContentTapped:)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.delaysTouchesEnded = false;
    tapGestureRecognizer.cancelsTouchesInView = false;
    [chatContent addGestureRecognizer:tapGestureRecognizer];
    [containerView addSubview:chatContent];
    
    [self setupHeaderView];
    
    chatContent.tableHeaderView = self.chatContentHeader;
    [self updateChatContentInset];
    
    CGRect chatBarWrapperRect = CGRectMake(0.0f, chatContentHeight, containerView.frame.size.width, initialChatBarHeight + initialChatBarWrapperPadding);
    chatBarWrapper = [[UIView alloc] initWithFrame:chatBarWrapperRect];
    chatBarWrapper.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    
    CGRect chatBarRect = CGRectMake(0.0f, 0.0f, chatBarWrapperRect.size.width, initialChatBarHeight);
    
    chatBar = [[ChatBar alloc] initWithFrame: chatBarRect];
    chatBar.delegate = self;
    chatBar.canSendAudio = [PlayRecordAudioViewController canRecordAudio];
    if (conversation.isGroup == true) {
        [chatBar setupMentions:conversation.sortedMembers];
    }
    
    /* Put chat bar in a wrapper so we can adjust the bottom offset for iPhone X */
    [chatBarWrapper addSubview:chatBar];
    [containerView addSubview:chatBarWrapper];
    [containerView sendSubviewToBack:chatBarWrapper];
    
    [self setupNavigationBar];
    
    /* Scroll down button */
    scrollDownButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [scrollDownButton setAccessibilityLabel:NSLocalizedString(@"scoll_down_text", @"")];
    [scrollDownButton addTarget:self action:@selector(scrollDownButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:scrollDownButton];
    
    isFirstAppearance = YES;
    [self updateContactDisplay];
    
    lastInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    [self registerForPreviewingWithDelegate:self sourceView:self.view];
    
    [self setupColors];
    
    self.deleteMediaTotal = 0;
    _deleteMediaCount = 0;
}

- (void)setupHeaderView {
    headerView = (ChatViewHeader *)[NibUtil loadViewFromNibWithName:@"ChatViewHeader"];
    headerView.chatViewController = self;
    headerView.hidden = YES;
    headerView.delegate = self;
    [self.view addSubview: headerView];
}

- (void)setupNavigationBar {
    self.navigationItem.rightBarButtonItems = @[self.editButtonItem];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    _titleLabel.frame = CGRectMake(0, 0, 40, 28);
    UITapGestureRecognizer *titleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleTapped:)];
    [_titleLabel addGestureRecognizer:titleTapRecognizer];
    _titleLabel.userInteractionEnabled = YES;
    _titleLabel.text = conversation.displayName;
    _titleLabel.accessibilityIdentifier = @"TapHeaderView";
    
    self.navigationItem.titleView = _titleLabel;
}

- (void)setupColors {
    _titleLabel.textColor = [Colors fontNormal];
    
    self.loadEarlierMessages.titleLabel.font = [UIFont systemFontOfSize:17.0];
    
    self.loadEarlierMessages.backgroundColor = [[Colors backgroundBaseColor] colorWithAlphaComponent:0.3];
    self.loadEarlierMessages.layer.cornerRadius = 4.0;
    
    [self.loadEarlierMessages setTitleColor:[Colors fontLink] forState:UIControlStateNormal];
    [self.loadEarlierMessages setTitleColor:[Colors fontLight] forState:UIControlStateHighlighted];
    
    [self.navigationController.view setBackgroundColor:[Colors backgroundDark]];
    chatBarWrapper.backgroundColor = [Colors chatBarBackground];
    [self.view setBackgroundColor:[Colors backgroundChat]];
    
    // Set scroll down button image
    [scrollDownButton setImage:StyleKit.scrollDownButtonIcon forState:UIControlStateNormal];
}

- (void)refresh {
    [self setupBackground];
    [self setupColors];
    
    [headerView refresh];
    
    [chatBar refresh];
    
    [self.chatContent reloadData];
    
    self.navigationController.navigationBar.topItem.leftBarButtonItem.title = @"Back";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; // below: work around for [chatContent flashScrollIndicators]
    
    _tableDataSource.openTableView = YES;
    
    DDLogVerbose(@"viewWillAppear, composing = %d", self.composing);
    
    [self registerForNotifications];
    
    [self updateConversationIfNeeded];
    
    [chatContent performSelector:@selector(flashScrollIndicators) withObject:nil afterDelay:0.0];
    
    /* update typing indicator on last cell */
    if ([_tableDataSource hasData]) {
        NSIndexPath *pathToLastCell = [_tableDataSource indexPathForLastCell];
        [self updateTypingIndicatorAtIndexPath:pathToLastCell];
    }
    
    if (initialMessageText) {
        chatBar.text = initialMessageText;
        initialMessageText = nil;
    }
    
    /* remove temporary audio/video file? */
    if (tmpAudioVideoUrl != nil) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:tmpAudioVideoUrl error:&error];
        DDLogVerbose(@"Removing temporary audio/video file %@: %@", tmpAudioVideoUrl, error);
        tmpAudioVideoUrl = nil;
    }
    
    if (player != nil) {
        player = nil;
    }
    
    /* was there a rotation while we were hidden? */
    if ([[UIApplication sharedApplication] statusBarOrientation] != lastInterfaceOrientation) {
        [self updateTableForRotationToInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
        dispatch_async(dispatch_get_main_queue(), ^{
            /* Workaround as chatContent.frame won't be updated yet when we reposition the button below */
            [self repositionScrollDownButton];
        });
    }
    
    [self repositionScrollDownButton];
    [self updateScrollDownButtonAnimated:NO];
    
    /* send notification (e.g. for hiding toasts that apply to this conversation) */
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaConversationOpened" object:conversation userInfo:nil];
    
    [self registerCustomMenuItems];
    isFirstAppearance = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showProfilePictureChanged:) name:kNotificationShowProfilePictureChanged object:nil];
    
    /* Load draft, if any */
    NSString *draft = [MessageDraftStore loadDraftForConversation:self.conversation];
    if (draft.length != 0 && chatBar.text.length == 0) {
        [chatBar updateMentionsFromDraft:draft];
        //        chatBar.text = mentionsString;
        if ([self canBecomeFirstResponder]) {
            [chatBar becomeFirstResponder];
        }
    }
    
    /* correct the width of the headerView */
    if (@available(iOS 11.0, *)) {
        headerView.frame = CGRectMake(headerView.frame.origin.x, headerView.frame.origin.y, self.view.safeAreaLayoutGuide.layoutFrame.size.width, headerView.frame.size.height);
    } else {
        headerView.frame = CGRectMake(headerView.frame.origin.x, headerView.frame.origin.y, self.view.frame.size.width, headerView.frame.size.height);
    }
    
    // Remove unread line if unread count is 0
    if (conversation.unreadMessageCount.integerValue == 0) {
        [self removeUnreadLine:NO];
    }
    
    [headerView refresh];
    
    if (!_backgroundView) {
        [self setupBackground];
    }
    
    if (headerView.hidden) {
        [self hideHeaderWithDuration:0.3];
    } else {
        [self showHeaderWithDuration:0.3 completion:nil];
    }
    
    [self setupNavigationBar];
    [self setupColors];
    
    [self loadImagesIfNeeded];
    
    if (SYSTEM_IS_IPAD == true) {
        [_delegate pushSettingChanged:self.conversation];
    }
    
    [chatBar setupMentions:conversation.sortedMembers];
}

- (void)registerForNotifications {
    // Listen for keyboard.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputModeDidChange:) name:UITextInputCurrentInputModeDidChangeNotification object:nil];
    
    // Listen for resign active notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillHide:) name:UIMenuControllerWillHideMenuNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:) name:UIMenuControllerDidHideMenuNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDirtyObjects:) name:kNotificationDBRefreshedDirtyObject object:nil];
}

- (void)showKeyboardConditionally {
    if (self.composing) {
        if ([self canBecomeFirstResponder]) {
            [chatBar becomeFirstResponder];
        }
    }
}

- (void)hideKeyboardTemporarily:(BOOL)temporarily {
    if (self.composing) {
        // can only be set to NO
        self.composing = temporarily;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [chatBar resignFirstResponder];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    DDLogVerbose(@"viewDidAppear");
    
    [self resetUnreadMessageCount];
    ((StatusNavigationBar*)self.navigationController.navigationBar).ignoreSetItems = NO;
    
    [self scrollToUnreadMessage:animated];
    
    [self showKeyboardConditionally];
    
    visible = YES;
    
    [self processReadReceiptQueue];
    
    // free up memory in case we came back from photo browser
    [headerView cleanupMedia];
    
    /* send pending image */
    if (imageDataToSend != nil) {
        [self chatBar:chatBar didSendImageData:imageDataToSend];
        imageDataToSend = nil;
    }
    
    /* restore audio category? */
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (prevAudioCategory != nil && state == CallStateIdle) {
        [[AVAudioSession sharedInstance] setCategory:prevAudioCategory error:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        });
        prevAudioCategory = nil;
    }
    [headerView showThreemaVideoCallInfo];
}

- (void)viewWillDisappear:(BOOL)animated {
    DDLogVerbose(@"viewWillDisappear, composing = %d", self.composing);
        
    /* Send stop typing indicator now, as it may be too late once we've deleted the conversation below */
    [chatBar stopTyping];
    
    if([speechSynthesizer isSpeaking]) {
        [speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@""];
        [speechSynthesizer speakUtterance:utterance];
        [speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
    
    /* Save draft in case we get killed */
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if ([[chatBar.text stringByTrimmingCharactersInSet: set] length] > 0) {
        [MessageDraftStore saveDraft:[chatBar formattedMentionText] forConversation:self.conversation];
    } else {
        [MessageDraftStore saveDraft:@"" forConversation:self.conversation];
    }
    
    lastInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    lastIndexPathBeforeRotation = [[self.chatContent indexPathsForVisibleRows] lastObject];
    
    // When the app is closed in this screen and has passlock enabled this gehts called while opening
    // the locked app. But we want to keep the unread line until unlock. (IOS-1463)
    if ([KKPasscodeLock sharedLock].isPasscodeRequired) {
        if (![AppDelegate sharedAppDelegate].isAppLocked && [AppDelegate sharedAppDelegate].isLockscreenDismissed) {
            [self removeUnreadLine:YES];
        }
    } else {
        [self removeUnreadLine:YES];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDirtyObjects:) name:kNotificationDBRefreshedDirtyObject object:nil];
    
    _tableDataSource.openTableView = NO;
        
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    DDLogVerbose(@"viewDidDisappear");
    visible = NO;
    
    /* Are we going back to ConversationsViewController, or to another view (e.g. contact details)? */
    if (self.navigationController.viewControllers == nil) {
        /* If our Conversation is still empty (no messages) and not a group conversation, delete it */
        if (conversation.messages.count == 0 && conversation.groupId == nil) {
            [entityManager performSyncBlockAndSafe:^{
                [[entityManager entityDestroyer] deleteObjectWithObject:conversation];
            }];
        }
    }
    
    [super viewDidDisappear:animated];
}

- (void)resignActive:(NSNotification*)notification {
    /* stop typing as the user is leaving the app */
    [chatBar stopTyping];
    
    /* Save draft in case we get killed */
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if ([[chatBar.text stringByTrimmingCharactersInSet: set] length] > 0) {
        [MessageDraftStore saveDraft:[chatBar formattedMentionText] forConversation:self.conversation];
    } else {
        [MessageDraftStore saveDraft:@"" forConversation:self.conversation];
    }
    
    /* Remove unread line in active chat */
    [self removeUnreadLine:YES];
}

- (void)didBecomeActive:(NSNotification*)notification {
    [self updateConversationIfNeeded];
    [self resetUnreadMessageCount];
    [self processReadReceiptQueue];
    
    /* scroll the newest message if there is one */
    [self scrollToUnreadMessage:YES];
    
    [chatBar resetKeyboardType:NO];
    
    [self loadImagesIfNeeded];
}

- (void)removeUnreadLine:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [_tableDataSource getUnreadLineIndexPath];
        if (indexPath) {
            
            BOOL removed = [_tableDataSource removeUnreadLine];
            if (removed) {
                [chatContent beginUpdates];
                if (animated) {
                    [chatContent deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                } else {
                    [chatContent deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                }
                [chatContent endUpdates];
            }
            
        }
    });
}

- (void)scrollToUnreadMessage:(BOOL)animated {
    /* scroll the newest message if there is one */
    NSIndexPath *indexPath = [_tableDataSource getUnreadLineIndexPath];
    if (indexPath) {
        @try {
            isScrollingToUnreadMessages = YES;
            NSIndexPath *unreadLineIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
            [chatContent scrollToRowAtIndexPath:unreadLineIndexPath atScrollPosition:UITableViewScrollPositionTop animated:animated];
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, [chatContent cellForRowAtIndexPath:indexPath]);
        }
        @catch (NSException *exception) {
            ;//ignore
        }
        
        [self updateScrollDownButtonAnimated:NO];
    }
}

- (void)showContentAfterForceTouch {
    _isOpenWithForceTouch = NO;
    chatBarWrapper.hidden = NO;
    
    chatContent.frame = CGRectMake(chatContent.frame.origin.x, chatContent.frame.origin.y, chatContent.frame.size.width, chatBarWrapper.frame.origin.y);
}

- (void)updateLayoutAfterCall {
    if (@available(iOS 11.0, *)) {
        _backgroundView.frame = self.view.safeAreaLayoutGuide.layoutFrame;
    } else {
        _backgroundView.frame = self.view.frame;
    }
    
    if (headerView.hidden) {
        [self hideHeaderWithDuration:0.3];
    } else {
        headerView.hidden = YES;
        [self showHeaderWithDuration:0.3 completion:nil];
    }
}

- (void)openPushSettings {
    [self performSegueWithIdentifier:@"ShowPushSetting" sender:nil];
}

- (void)loadImagesIfNeeded {
    // check if there are messages with not loaded images
    NSArray *lastMessages = [messageFetcher last20Messages];
    for (BaseMessage *message in lastMessages) {
        if ([message isKindOfClass:[ImageMessage class]]) {
            ImageMessage *imageMessage = (ImageMessage *)message;
            if (imageMessage.image == nil) {
                /* Start loading image */
                ImageMessageLoader *loader = [[ImageMessageLoader alloc] init];
                
                [loader startWithMessage:imageMessage onCompletion:^(BaseMessage *message) {
                } onError:^(NSError *error) {
                    DDLogError(@"Image message blob load failed with error: %@", error);
                }];
            }
        } else if ([message isKindOfClass:[FileMessage class]]) {
            FileMessage *fileMessage = (FileMessage *) message;
            if ([fileMessage renderFileImageMessage] && (![fileMessage thumbnailDownloaded] || ![fileMessage dataDownloaded])) {
                BlobMessageLoader *loader = [[BlobMessageLoader alloc] init];
                [loader startWithMessage:fileMessage onCompletion:^(BaseMessage *message) {
                    DDLogInfo(@"File message blob load completed");
                } onError:^(NSError *error) {
                    DDLogError(@"File message blob load failed with error: %@", error);
                }];
            }
        }
    }
}

- (void)setCurrentAction:(ChatViewControllerAction *)newAction {
    currentAction = newAction;
}


#pragma mark - notification observer

- (void)refreshDirtyObjects:(NSNotification*)notification {
    NSManagedObjectID *objectID = [notification.userInfo objectForKey:kKeyObjectID];
    if (objectID && [objectID isEqual:self.conversation.objectID]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateConversation];
        });
    }
}

- (void)menuWillHide:(NSNotification*)notification {
    DDLogVerbose(@"menuWillHide");
    ignoreNextTap = YES;
}

- (void)menuDidHide:(NSNotification*)notification {
    DDLogVerbose(@"menuDidHide");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ignoreNextTap = NO;
    });
    [self registerCustomMenuItems];
}

- (void)registerCustomMenuItems {
    UIMenuItem *menuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"scan_qr", nil) action:@selector(scanQrCode:)];
    [[UIMenuController sharedMenuController] setMenuItems:[NSArray arrayWithObject:menuItem]];
}

- (void)scanQrCode:(id)sender {
    /* dummy to avoid compiler warning */
}

- (void)scrollDownButtonPressed:(id)sender {
    [self scrollToBottomAnimated:YES];
}

- (void)repositionScrollDownButton {
    // Icon should be cached and quadratic
    CGFloat buttonSize = StyleKit.scrollDownButtonIcon.size.height / UIScreen.mainScreen.scale;
    CGFloat padding = 8;
    
    CGFloat chatWidth = self.chatContent.frame.size.width;
    if (@available(iOS 11.0, *)) {
        // Adhere safe area insets on X-devices
        chatWidth -= self.view.safeAreaInsets.right;
    }
    
    scrollDownButton.frame = CGRectMake((chatWidth - (buttonSize + padding)),
                                        (self.chatContent.frame.origin.y + self.chatContent.frame.size.height) - (buttonSize + padding),
                                        buttonSize, buttonSize);
}

- (void)updateScrollDownButtonAnimated:(BOOL)animated {
    CGFloat targetAlpha;
    
    if ([self isScrolledAtBottom]) {
        targetAlpha = 0;
        haveNewMessages = NO;
    } else
        targetAlpha = kScrollButtonAlpha;
    
    if (scrollDownButton.alpha == targetAlpha)
        return;
    
    if (animated) {
        [UIView animateWithDuration:0.5f animations:^{
            scrollDownButton.alpha = targetAlpha;
        }];
    } else {
        scrollDownButton.alpha = targetAlpha;
    }
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    lastIndexPathBeforeRotation = [[self.chatContent indexPathsForVisibleRows] lastObject];
    
    // override assumed table width for heightForRowAtIndexPath during rotation to get a smooth animation
    _tableDataSource.rotationOverrideTableWidth = self.chatContent.frame.size.width;
    
    _tableDataSource.rotationOverrideTableWidth = 0;
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        [self updateTableForRotationToInterfaceOrientation:orientation];
        [self repositionScrollDownButton];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
        if (lastIndexPathBeforeRotation != nil) {
            @try {
                [self.chatContent scrollToRowAtIndexPath:lastIndexPathBeforeRotation atScrollPosition:UITableViewScrollPositionBottom animated:NO];
            } @catch (NSException *exception) {}
        }
        
        [self updateScrollDownButtonAnimated:YES];
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)setupBackground {
    UIImage *bgImage = nil;
    if ([UserSettings sharedUserSettings].wallpaper) {
        bgImage = [UserSettings sharedUserSettings].wallpaper;
    } else {
        if (![LicenseStore requiresLicenseKey]) {
            UIImage *chatBackground = [BundleUtil imageNamed:@"ChatBackground"];
            bgImage = [chatBackground drawImageWithTintColor:[Colors chatBackgroundLines]];
        }
    }
    
    if (_backgroundView) {
        [_backgroundView removeFromSuperview];
    }
    
    if (bgImage != nil) {
        if (@available(iOS 11.0, *)) {
            _backgroundView = [[UIImageView alloc] initWithFrame:self.view.safeAreaLayoutGuide.layoutFrame];
        } else {
            _backgroundView = [[UIImageView alloc] initWithFrame:self.view.frame];
        }
        _backgroundView.contentMode = UIViewContentModeScaleAspectFill;
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backgroundView.clipsToBounds = YES;
        
        if ([UserSettings sharedUserSettings].wallpaper) {
            _backgroundView.backgroundColor = [UIColor clearColor];
            _backgroundView.image = bgImage;
        } else {
            _backgroundView.backgroundColor = [[UIColor alloc] initWithPatternImage:bgImage];
            _backgroundView.image = nil;
        }
        
        [containerView addSubview:_backgroundView];
        [containerView sendSubviewToBack:_backgroundView];
    }
}

- (void)updateBackgroundForOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    if (_backgroundView == nil) {
        [self setupBackground];
    }
    
    if ([UserSettings sharedUserSettings].wallpaper || _backgroundView == nil) {
        // do not rotate for custom wallpapers
        return;
    }
    
    CGFloat rotation;
    if (toInterfaceOrientation==UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation== UIInterfaceOrientationLandscapeRight) {
        rotation = M_PI/2;
    } else {
        rotation = 0;
    }
    
    [UIView animateWithDuration:duration animations:^{
        _backgroundView.transform = CGAffineTransformMakeRotation(rotation);
        _backgroundView.frame = self.view.frame;
    }];
    
}

- (void)updateTableForRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    [self checkShouldShowHeader];
    
    [self.chatContent beginUpdates];
    [self updateChatContentInset];
    [self.chatContent endUpdates];
    
    if (lastIndexPathBeforeRotation != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                [self.chatContent scrollToRowAtIndexPath:lastIndexPathBeforeRotation atScrollPosition:UITableViewScrollPositionBottom animated:NO];
            } @catch (NSException *exception) {}
        });
    }
    
    if (_searching == NO) {
        [chatBar resizeChatInput];
    }
}

- (void)moveContainerViewForKeyboardFrame:(CGRect)keyboardFrameInView willHide:(BOOL)willHide {
    CGRect containerViewFrame = containerView.frame;
    CGFloat keyboardHeight = willHide ? 0.0f : keyboardFrameInView.size.height - [self tabBarHeight];
    
    if (SYSTEM_IS_IPAD && !willHide) {
        // iPad with external keyboard needs special treatment, as it will be shown as a collapsed bar with
        // some buttons, but the height is still the same. Therefore we need to calculate the height from
        // the y offset of the keyboard frame and the screen height
        keyboardHeight = self.view.frame.size.height - keyboardFrameInView.origin.y - [self tabBarHeight];
    }
    
    if ([AppDelegate hasBottomSafeAreaInsets]) {
        if (willHide && !SYSTEM_IS_IPAD) {
            // Must add padding to chat bar wrapper for iPhone X
            wrapperBottomPadding = kIphoneXChatBarBottomPadding;
        } else {
            wrapperBottomPadding = 0;
        }
        [self chatBar:chatBar didChangeHeight:chatBar.frame.size.height];
    }
    
    if(keyboardHeight < 0.0f) {
        keyboardHeight = 0.0f;
    }
    
    containerViewFrame.origin.y = -keyboardHeight;
    containerView.frame = containerViewFrame;
    
    lastKeyboardHeight = keyboardHeight;
    
    [self updateChatContentInset];
    
    if (willHide == NO) {
        [self checkShouldShowHeader];
    }
}

- (void)removeConversationObservers {
    @try {
        [conversation removeObserver:self forKeyPath:@"messages"];
        [conversation removeObserver:self forKeyPath:@"unreadMessageCount"];
        [conversation removeObserver:self forKeyPath:@"typing"];
        [conversation removeObserver:self forKeyPath:@"displayName"];
        [conversation removeObserver:self forKeyPath:@"groupId"];
        [conversation removeObserver:self forKeyPath:@"members"];
    } @catch (NSException * __unused exception) {}
    
    [conversation.members enumerateObjectsUsingBlock:^(Contact *contact, BOOL * _Nonnull stop) {
        @try {
            [contact removeObserver:self forKeyPath:@"displayName"];
        }
        @catch (NSException * __unused exception) {}
    }];
}

- (void)addConversationObservers {
    @try {
        /* observe this conversation in case new messages are added to it while we're open */
        [conversation addObserver:self forKeyPath:@"messages" options:NSKeyValueObservingOptionNew context:nil];
        [conversation addObserver:self forKeyPath:@"unreadMessageCount" options:0 context:nil];
        [conversation addObserver:self forKeyPath:@"typing" options:0 context:nil];
        [conversation addObserver:self forKeyPath:@"displayName" options:0 context:nil];
        [conversation addObserver:self forKeyPath:@"groupId" options:0 context:nil];
        [conversation addObserver:self forKeyPath:@"members" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    } @catch (NSException * __unused exception) {}
    
    [conversation.members enumerateObjectsUsingBlock:^(Contact *contact, BOOL * _Nonnull stop) {
        @try {
            [contact addObserver:self forKeyPath:@"displayName" options:0 context:nil];
        }
        @catch (NSException * __unused exception) {}
    }];
}

- (CGFloat)topOffsetForVisibleContent {
    CGFloat topOffset;
    if (@available(iOS 11.0, *)) {
        topOffset = self.view.safeAreaLayoutGuide.layoutFrame.origin.y;
    } else {
        topOffset = self.topLayoutGuide.length;
    }
    return topOffset;
}

- (CGFloat)topOffsetForVisibleChatContent {
    CGFloat topOffset = [self topOffsetForVisibleContent];
    
    if (showHeader) {
        topOffset += [headerView getHeight];
    }
    
    return topOffset;
}

- (void)updateContactDisplay {
    [self updateConversation];
}

- (void)setConversation:(Conversation *)newConversation {
    if (conversation == newConversation)
        return;
    
    [self removeConversationObservers];
    conversation = newConversation;
    
    [self addConversationObservers];
    
    numberOfPages = 1;
    
    shouldScrollDown = YES;
    _isDirty = YES;
    
    messageFetcher = [MessageFetcher messageFetcherFor:conversation withEntityFetcher:entityManager.entityFetcher];
    
    currentOffset = -1;
}

- (NSInteger)messageOffset {
    return currentOffset;
}

- (void)cleanCellHeightCache {
    [_tableDataSource cleanCellHeightCache];
}

// Update conversation if last update was not today
// This is needed to update the realtive table view headers
- (void)updateConversationIfNeeded {
    if (lastFullConversationUpdate != nil) {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        if (![calendar isDateInToday:lastFullConversationUpdate]) {
            [self updateConversation];
        }
    }
}

- (void)resetLastFullConversationUpdate {
    lastFullConversationUpdate = [NSDate date];
}

- (void)updateConversation {
    _isDirty = YES;
    [self updateConversationClearContent:YES];
}

- (void)updateConversationClearContent:(BOOL)clearContent {
    if (conversation == nil || self.isViewLoaded == NO || _isDirty == NO) {
        return;
    }
    
    _isDirty = NO;
    if (self.editing == YES) {
        self.editing = NO;
    }
    
    [self updateConversationLastMessage];
    
    headerView.conversation = conversation;
    [self setupNavigationBar];
    [self setupColors];
    
    NSInteger newOffset;
    NSInteger numberOfMessagesToLoad;
    ChatTableDataSource *previousDataSource;
    if (clearContent == NO && currentOffset != -1) {
        previousDataSource = _tableDataSource;
        newOffset = currentOffset - LOAD_MESSAGES_PER_PAGE;
        if (newOffset < 0) {
            newOffset = 0;
        }
        numberOfMessagesToLoad = currentOffset - newOffset;
    } else {
        int messagesAtStart = MESSAGES_AT_START;
        if ([conversation.unreadMessageCount intValue] > messagesAtStart - 5) {
            messagesAtStart = [conversation.unreadMessageCount intValue] + 5;
        }
        NSInteger numberOfMessages = messagesAtStart;
        if (numberOfPages > 1)
            numberOfMessages += (numberOfPages - 1) * LOAD_MESSAGES_PER_PAGE;
        newOffset = messageFetcher.count - numberOfMessages;
        numberOfMessagesToLoad = numberOfMessages;
        if (newOffset < 0) {
            newOffset = 0;
            numberOfMessagesToLoad = messageFetcher.count;
        }
    }
    
    ChatTableDataSource *tmpDatasource = [[ChatTableDataSource alloc] init];
    tmpDatasource.chatVC = self;
    tmpDatasource.backgroundColor = [Colors background];
    
    self.chatContent.dataSource = tmpDatasource;
    self.chatContent.delegate = tmpDatasource;
    
    BOOL didHideHeader = NO;
    if (newOffset == 0) {
        if (!self.chatContentHeader.hidden) {
            self.chatContent.tableHeaderView = nil;
            self.chatContentHeader.hidden = YES;
            didHideHeader = YES;
        }
    } else {
        if (self.chatContentHeader.hidden) {
            self.chatContent.tableHeaderView = self.headerView;
            self.chatContentHeader.hidden = NO;
        }
    }
    
    NSArray *pagedMessages = [messageFetcher messagesAtOffset:newOffset count:numberOfMessagesToLoad];
    currentOffset = newOffset;
    
    for (int i = 0; i < [pagedMessages count]; i++) {
        BaseMessage *curMessage = [pagedMessages objectAtIndex:i];
        [tmpDatasource addMessage:curMessage newSections:nil newRows:nil visible:visible];
        
        if (!curMessage.isOwn.boolValue && !curMessage.read.boolValue) {
            [readReceiptQueue addObject:curMessage];
        }
    }
    
    [self processReadReceiptQueue];
    
    CGFloat contentOffsetFromBottom = self.chatContent.contentOffset.y + self.chatContent.frame.size.height - self.chatContent.contentSize.height;
    
    if (previousDataSource) {
        [tmpDatasource addObjectsFrom:previousDataSource];
        tmpDatasource.searching = previousDataSource.searching;
        tmpDatasource.searchPattern = previousDataSource.searchPattern;
    }
    
    _tableDataSource = tmpDatasource;
    [self.chatContent reloadData];
    [self.chatContent layoutIfNeeded];
    [chatBar setupMentions:conversation.sortedMembers];
    
    CGFloat newContentOffset = contentOffsetFromBottom - self.chatContent.frame.size.height + self.chatContent.contentSize.height;
    
    if (newContentOffset < -self.chatContent.contentInset.top) {
        newContentOffset = -self.chatContent.contentInset.top;
    }
    
    if (didHideHeader) {
        newContentOffset -= 40;
    }
    
    self.chatContent.contentOffset = CGPointMake(0, newContentOffset);
    
    if (shouldScrollDown) {
        shouldScrollDown = NO;
        NSIndexPath *indexPath = [_tableDataSource getUnreadLineIndexPath];
        if (indexPath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self scrollToUnreadMessage:YES];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self scrollToBottomAnimated:NO];
            });
        }
    }
    
    // Full reload
    if (clearContent == YES) {
        [_tableDataSource refreshSectionHeadersInTableView:chatContent];
        [self resetLastFullConversationUpdate];
    }
}

- (void)updateConversationLastMessage {
    BaseMessage *message = [messageFetcher lastMessage];
    if ([message isKindOfClass:[SystemMessage class]]) {
        SystemMessage *systemMessage = (SystemMessage *)message;
        switch ([systemMessage.type intValue]) {
            case kSystemMessageCallMissed:
            case kSystemMessageCallRejected:
            case kSystemMessageCallRejectedBusy:
            case kSystemMessageCallRejectedTimeout:
            case kSystemMessageCallEnded:
            case kSystemMessageCallRejectedDisabled:
            case kSystemMessageCallRejectedUnknown:
                // call messages should add as last message, all other types should not
                break;
            default:
                return;
        }
    }
    conversation.lastMessage = [messageFetcher lastMessage];
}

- (void)presentActivityViewController:(UIActivityViewController *)viewControllerToPresent animated:(BOOL)flag fromView:(UIView *)view {
    /* hide keyboard before showing UIActivityViewController to keep keyboard from popping up and down
     repeatedly, and to prevent missed keyboard event that gets sent after viewDidDisappear but
     before viewWillAppear */
    [self hideKeyboardTemporarily:YES];
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    [defaults setDouble:[Utils systemUptime] forKey:@"UIActivityViewControllerOpenTime"];
    [defaults synchronize];
    
    [viewControllerToPresent setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
    }];
    
    
    CGRect rect = [self.view convertRect:view.frame fromView:view.superview];
    [ModalPresenter present:viewControllerToPresent on:self fromRect:rect inView:self.view];
}

- (void)titleTapped:(UITapGestureRecognizer*)sender {
    [self toggleHeader];
}

- (CGFloat)tabBarHeight {
    if (SYSTEM_IS_IPAD) {
        return self.tabBarController.tabBar.frame.size.height;
    } else {
        return 0.0;
    }
}

#pragma mark - key value observer

- (void)observeUpdatesForMessage:(BaseMessage *)message {
    /* workaround for image messages: if this image hasn't been loaded yet, we must observe it
     and refresh the cell when the image becomes available (height changes). This cannot be done
     in ChatImageMessageCell due to race condition issues */
    if ([message isKindOfClass:[ImageMessage class]]) {
        ImageMessage *imageMessage = (ImageMessage*)message;
        if (imageMessage.thumbnail == nil) {
            
            [imageMessage addObserver:self forKeyPath:@"thumbnail" options:0 context:nil];
            [_imageMessageObserverList addObject:imageMessage];
        }
    } else if ([message isKindOfClass:[FileMessage class]]) {
        FileMessage *fileMessage = (FileMessage*)message;
        if (fileMessage.data == nil) {
            [fileMessage addObserver:self forKeyPath:@"thumbnail" options:0 context:nil];
            [_imageMessageObserverList addObject:fileMessage];
        }
    } else if ([message isKindOfClass:[LocationMessage class]]) {
        LocationMessage *locationMessage = (LocationMessage*)message;
        if (locationMessage.poiName == nil && locationMessage.reverseGeocodingResult == nil) {
            [locationMessage addObserver:self forKeyPath:@"reverseGeocodingResult" options:0 context:nil];
            [_locationMessageObserverList addObject:locationMessage];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    //DDLogVerbose(@"observeValueForKeyPath:%@ ofObject:%@ change:%@", keyPath, object, change);
    // objects in the change dictionary can get lost between here and the dispatch block -> copy
    NSDictionary *changeCopy = [change copy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == conversation) {
            if ([keyPath isEqualToString:@"messages"]) {
                switch ([(NSNumber*)[changeCopy objectForKey:NSKeyValueChangeKindKey] intValue]) {
                    case NSKeyValueChangeInsertion: {
                        NSArray *newMessages = (NSArray*)[changeCopy objectForKey:NSKeyValueChangeNewKey];
                        [self insertMessages: newMessages];
                        break;
                    }
                    case NSKeyValueChangeRemoval: {
                        if (deleteMediaTotal > 0) {
                            _deleteMediaCount++;
                            if (deleteMediaTotal == _deleteMediaCount) {
                                deleteMediaTotal = 0;
                                _deleteMediaCount = 0;
                                [self updateConversation];
                            }
                        }
                        break;
                    }
                }
            } else if ([keyPath isEqualToString:@"unreadMessageCount"]) {
                if (visible) {
                    [self resetUnreadMessageCount];
                }
            } else if ([keyPath isEqualToString:@"typing"]) {
                /* update typing indicator */
                if ([_tableDataSource hasData]) {
                    NSIndexPath *pathToLastCell = [_tableDataSource indexPathForLastCell];
                    [self updateTypingIndicatorAtIndexPath:pathToLastCell];
                }
            } else if ([keyPath isEqualToString:@"displayName"]) {
                [self updateContactDisplay];
            } else if ([keyPath isEqualToString:@"groupId"]) {
                if (conversation.groupId == nil) {
                    [self.navigationController dismissViewControllerAnimated:YES completion:^{
                        [self.navigationController popToRootViewControllerAnimated:true];
                    }];
                }
            } else if ([keyPath isEqualToString:@"members"]) {
                
                NSSet *oldMembers = changeCopy[NSKeyValueChangeOldKey];
                NSSet *newMembers = changeCopy[NSKeyValueChangeNewKey];
                [self updateMembersObserver:oldMembers newMembers:newMembers];
            }
            
        } else if ([object isKindOfClass:[ImageMessage class]] && [keyPath isEqualToString:@"thumbnail"]) {
            [self updateObject:object];
        } else if ([object isKindOfClass:[LocationMessage class]] && [keyPath isEqualToString:@"reverseGeocodingResult"]) {
            [self updateObject:object];
        } else if ([object isKindOfClass:[FileMessage class]] && [keyPath isEqualToString:@"thumbnail"]) {
            [self updateObject:object];
        } else if ([object isKindOfClass:[Contact class]] && [keyPath isEqualToString:@"displayName"]) {
            [self updateConversation];
        }
    });
}

- (void)updateObject:(id)object {
    /* find cell in cell map and call table view update */
    NSIndexPath *indexPath = [_tableDataSource indexPathForMessage:object];
    if (indexPath) {
        [_tableDataSource removeObjectFromCellHeightCache:indexPath];
        [self.chatContent reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.chatContent scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)insertMessages:(NSArray *)newMessages {
    if (newMessages != nil) {
        [self updateConversationIfNeeded];
        
        BOOL isScrolledAtBottom = [self isScrolledAtBottom];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            /* this simply assumes that the inserted message is newer than any existing
             messages, and so can be added at the end of the list */
            NSIndexPath *prevLastIndexPath = [_tableDataSource indexPathForLastCell];
            
            NSMutableIndexSet *newSections = [NSMutableIndexSet new];
            NSMutableArray *newRows = [[NSMutableArray alloc] initWithCapacity:newMessages.count*2];
            BOOL newSentMessages = NO;
            BOOL newReceivedMessages = NO;
            
            [self.chatContent beginUpdates];
            
            for (BaseMessage *message in newMessages) {
                /* check if we have already added this message – this can happen as KVO sometimes
                 sends an NSKeyValueChangeInsertion event for the same messages twice on iOS 8 */
                NSIndexPath *indexPathForMessage = [_tableDataSource indexPathForMessage:message];
                if (indexPathForMessage != nil) {
                    [self.chatContent endUpdates];
                    if (indexPathForMessage == prevLastIndexPath) {
                        if (newSentMessages || isScrolledAtBottom) {
                            inhibitScrollBottom = YES;
                            isNewMessageReceivedInActiveChat = YES;
                            [self performSelector:@selector(scrollToBottomScheduled) withObject:nil afterDelay:0.2f];
                        } else if (newReceivedMessages) {
                            haveNewMessages = YES;
                            [self updateScrollDownButtonAnimated:YES];
                        }
                    }
                    return;
                }
                
                [_tableDataSource addMessage:message newSections:newSections newRows:newRows visible:visible];
                
                if (!message.isOwn.boolValue && !message.read.boolValue) { // not read, so queue read receipt for sending the next time we appear
                    [readReceiptQueue addObject:message];
                    newReceivedMessages = YES;
                }
                
                if (message.isOwn.boolValue)
                    newSentMessages = YES;
            }
            
            if (newSections.count > 0) {
                [chatContent insertSections:newSections withRowAnimation:UITableViewRowAnimationNone];
            }
            
            if (newRows.count > 0) {
                [chatContent insertRowsAtIndexPaths:newRows withRowAnimation:UITableViewRowAnimationNone];
            }
            
            [self.chatContent endUpdates];
            
            /* must update/remove the typing indicator on the previously last row */
            if (prevLastIndexPath != nil)
                [self updateTypingIndicatorAtIndexPath:prevLastIndexPath];
            
            if (newSentMessages || isScrolledAtBottom) {
                inhibitScrollBottom = YES;
                isNewMessageReceivedInActiveChat = YES;
                [self performSelector:@selector(scrollToBottomScheduled) withObject:nil afterDelay:0.2f];
            } else if (newReceivedMessages) {
                haveNewMessages = YES;
                [self updateScrollDownButtonAnimated:YES];
            }
            
            if (visible) {
                [self processReadReceiptQueue];
            }
        });
    }
}

- (void)resetUnreadMessageCount {
    if (![AppDelegate sharedAppDelegate].active)
        return;
    
    if ([conversation.unreadMessageCount intValue] != 0) {
        /* mark conversation as read */
        [entityManager performSyncBlockAndSafe:^{
            conversation.unreadMessageCount = [NSNumber numberWithInt:0];
        }];
    }
    [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
}

- (void)processReadReceiptQueue {
    if (conversation.groupId != nil) {
        /* no read receipts for groups, but we have to set the read field in database for new message line */
        /* fix for update from 2.8.0 to new version --> set all messages to read if first message of group is not read */
        id firstMessage = [_tableDataSource objectForIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if ([firstMessage isKindOfClass:[BaseMessage class]]) {
            if (!((BaseMessage *)firstMessage).read.boolValue) {
                // add all visible messages to readReceiptQueue
                NSArray *visibleMessages = [messageFetcher messagesAtOffset:currentOffset count:(messageFetcher.count - currentOffset)];
                
                for (int i = 0; i < [visibleMessages count]; i++) {
                    BaseMessage *curMessage = [visibleMessages objectAtIndex:i];
                    [readReceiptQueue addObject:curMessage];
                }
                
            }
        }
        
        NSMutableArray *tmpReadReceiptQueue = [NSMutableArray arrayWithArray:readReceiptQueue];
        
        [entityManager performAsyncBlockAndSafe:^{
            for (BaseMessage *message in tmpReadReceiptQueue) {
                @try {
                    message.read = [NSNumber numberWithBool:YES];
                    message.readDate = [NSDate date];
                }
                @catch (NSException *exception) {
                    // intended to catch NSObjectInaccessibleException, which may happen
                    // if the message has been deleted in the meantime
                    DDLogError(@"Exception while marking message as read: %@", exception);
                }
            }
        }];
        [readReceiptQueue removeAllObjects];
        return;
    }
    
    /* do not send read receipts while app is in the background */
    if (![AppDelegate sharedAppDelegate].active)
        return;
    
    if (readReceiptQueue.count > 0) {
        NSMutableArray *tmpReadReceiptQueue = [NSMutableArray arrayWithArray:readReceiptQueue];
        [MessageSender sendReadReceiptForMessages:tmpReadReceiptQueue toIdentity:conversation.contact.identity async:YES quickReply:NO];
        
        [entityManager performAsyncBlockAndSafe:^{
            for (BaseMessage *message in tmpReadReceiptQueue) {
                @try {
                    message.read = [NSNumber numberWithBool:YES];
                    message.readDate = [NSDate date];
                }
                @catch (NSException *exception) {
                    // intended to catch NSObjectInaccessibleException, which may happen
                    // if the message has been deleted in the meantime
                    DDLogError(@"Exception while marking message as read: %@", exception);
                }
            }
        }];
        
        [readReceiptQueue removeAllObjects];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowContact"]) {
        ContactDetailsViewController *detailsView = (ContactDetailsViewController*)segue.destinationViewController;
        if ([sender isKindOfClass:[Contact class]]) {
            detailsView.contact = (Contact *)sender;
        } else {
            detailsView.contact = conversation.contact;
        }
    } else if ([segue.identifier isEqualToString:@"ShowLocation"]) {
        LocationViewController *locationView = (LocationViewController*)segue.destinationViewController;
        locationView.locationMessage = locationToShow;
    } else if ([segue.identifier isEqualToString:@"ShowDetails"]) {
        MessageDetailsViewController *detailsView = (MessageDetailsViewController*)segue.destinationViewController;
        detailsView.message = detailsMessage;
    } else if ([segue.identifier isEqualToString:@"ShowGroupInfo"]) {
        GroupDetailsViewController *detailsView = (GroupDetailsViewController*)segue.destinationViewController;
        detailsView.delegate = self;
        detailsView.group = [GroupProxy groupProxyForConversation:conversation];
    } else if ([segue.identifier isEqualToString:@"ShowPushSetting"]) {
        NotificationSettingViewController *settingsView = (NotificationSettingViewController*)segue.destinationViewController;
        if (conversation.isGroup) {
            settingsView.identity = [NSString stringWithHexData:conversation.groupId];
            settingsView.isGroup = YES;
            settingsView.conversation = conversation;
        } else {
            settingsView.identity = conversation.contact.identity;
            settingsView.isGroup = NO;
            settingsView.conversation = conversation;
        }
    }
}

- (void)cancelAction:(id)sender {
    self.editing = NO;
}

- (void)deleteAction:(id)sender {
    
    NSString *actionTitle;
    NSUInteger numSelected = [[self.chatContent indexPathsForSelectedRows] count];
    if (numSelected == 0) {
        /* clear all */
        actionTitle = NSLocalizedString(@"messages_delete_all_confirm", nil);
    } else {
        actionTitle = NSLocalizedString(@"messages_delete_selected_confirm", nil);
    }
    
    UIAlertController *deleteActionSheet = [UIAlertController alertControllerWithTitle:actionTitle message:nil preferredStyle:UIAlertControllerStyleAlert];
    [deleteActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [_tableDataSource cleanCellHeightCache];
        ChatDeleteAction *deleteAction = [ChatDeleteAction actionForChatViewController:self];
        deleteAction.entityManager = entityManager;
        currentAction = deleteAction;
        [deleteAction executeAction];
    }]];
    [deleteActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    deleteActionSheet.popoverPresentationController.sourceView = self.view;
    [self presentViewController:deleteActionSheet animated:YES completion:nil];
}

- (IBAction)loadEarlierMessagesAction:(id)sender {
    numberOfPages++;
    _isDirty = YES;
    [self updateConversationClearContent:NO];
}

- (void)scrollToBottomScheduled {
    inhibitScrollBottom = NO;
    [self scrollToBottomAnimated:YES];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (inhibitScrollBottom || (chatContent.contentSize.height - chatContent.contentOffset.y - chatContent.frame.size.height) < 0)
        return;
    
    NSIndexPath *bottomRow = [_tableDataSource indexPathForLastCell];
    if (bottomRow) {
        [self checkShouldShowHeader];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                
                [chatContent scrollToRowAtIndexPath:bottomRow atScrollPosition:UITableViewScrollPositionBottom animated:animated];
                [self repositionScrollDownButton];
                [self updateScrollDownButtonAnimated:NO];
                
            }
            @catch (NSException *exception) {
                ;//ignore
            }
        });
    }
}

- (BOOL)isScrolledAtBottom {
    return ((chatContent.contentSize.height - chatContent.contentOffset.y - chatContent.frame.size.height) < 25);
}

- (NSString *)messageText {
    if (chatBar != nil) {
        return chatBar.text;
    } else {
        return initialMessageText;
    }
}

- (void)setMessageText:(NSString *)messageText {
    if (chatBar != nil) {
        [self showKeyboardConditionally];
        
        chatBar.text = messageText;
    } else {
        initialMessageText = messageText;
    }
}

- (void)setImageDataToSend:(NSData *)newImageToSend {
    imageDataToSend = newImageToSend;
    
    /* if we're currently visible, trigger send as there will be no viewDidAppear */
    if (visible) {
        [self chatBar:chatBar didSendImageData:imageDataToSend];
        imageDataToSend = nil;
    }
}

- (void)chatContentTapped:(UITapGestureRecognizer*)sender {
    DDLogVerbose(@"chatContentTapped, ignoreNextTap = %d, sender = %@", ignoreNextTap, sender);
    
    if (ignoreNextTap) {
        ignoreNextTap = NO;
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideKeyboardTemporarily:NO];
    });
}

- (void)messageBackgroundTapped:(BaseMessage *)message {
    DDLogVerbose(@"messageBackgroundTapped");
    
    if (ignoreNextTap)
        return;
    
    [self hideKeyboardTemporarily:NO];
}

- (void)startRecordingAudio {
    [PlayRecordAudioViewController requestMicrophoneAccessOnCompletion:^{
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, audioRecorder);
        selectedAudioMessage = [_tableDataSource indexPathForLastCell];
        audioRecorder = [PlayRecordAudioViewController playRecordAudioViewControllerIn: self];
        audioRecorder.delegate = self;
        selectedAudioMessage = nil;
        [audioRecorder startRecordingForConversation: conversation];
    }];
}

- (void)createBallot {
    [BallotDispatcher showBallotCreateViewControllerForConversation:conversation onNavigationController:self.navigationController];
}

- (void)sendFile {
    DocumentPicker *documentPicker = [DocumentPicker documentPickerForViewController:self conversation:self.conversation];
    documentPicker.popoverSourceRect = [self.view convertRect:self.chatBar.addButton.frame fromView:self.chatBar];
    [documentPicker show];
}

- (void)playAudioMessage:(AudioMessage*)message {
    /* write audio to temp. file */
    [self createTmpAVFileFrom:message];
    
    if (tmpAudioVideoUrl) {
        [self hideKeyboardTemporarily:YES];
        
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, audioRecorder);
        selectedAudioMessage = [_tableDataSource indexPathForMessage:message];
        audioRecorder = [PlayRecordAudioViewController playRecordAudioViewControllerIn: self];
        audioRecorder.delegate = self;
        [audioRecorder startPlaying: tmpAudioVideoUrl];
    }
}

- (void)playFileAudioMessage:(FileMessage*)message {
    /* write audio to temp. file */
    [self createTmpAVFileFrom:message];
    
    if (tmpAudioVideoUrl) {
        [self hideKeyboardTemporarily:YES];
        
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, audioRecorder);
        selectedAudioMessage = [_tableDataSource indexPathForMessage:message];
        audioRecorder = [PlayRecordAudioViewController playRecordAudioViewControllerIn: self];
        audioRecorder.delegate = self;
        [audioRecorder startPlaying: tmpAudioVideoUrl];
    }
}



- (void)updateTypingIndicatorAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell *cell = [self.chatContent cellForRowAtIndexPath:indexPath];
    if (cell != nil && [cell isKindOfClass:[ChatMessageCell class]]) {
        ChatMessageCell *chatMessageCell = (ChatMessageCell*)cell;
        
        NSIndexPath *currentLastIndexPath = [_tableDataSource indexPathForLastCell];
        if (conversation.typing.boolValue && [indexPath isEqual:currentLastIndexPath]) {
            chatMessageCell.typing = YES;
        } else {
            chatMessageCell.typing = NO;
        }
    }
}

- (void)updateChatContentInset {
    float statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    if (@available(iOS 11.0, *)) {
        chatContent.contentInset = UIEdgeInsetsMake(lastKeyboardHeight + [self topOffsetForVisibleChatContent] - self.navigationController.navigationBar.frame.size.height - statusBarHeight, 0, 0, 0);
        chatContent.scrollIndicatorInsets = UIEdgeInsetsMake(lastKeyboardHeight + [self topOffsetForVisibleChatContent]  - self.navigationController.navigationBar.frame.size.height - statusBarHeight, 0, 0, 0);
    } else {
        chatContent.contentInset = UIEdgeInsetsMake(lastKeyboardHeight + [self topOffsetForVisibleChatContent], 0, 0, 0);
        chatContent.scrollIndicatorInsets = UIEdgeInsetsMake(lastKeyboardHeight + [self topOffsetForVisibleChatContent], 0, 0, 0);
    }
}


# pragma mark - Keyboard Notifications

- (void)keyboardWillShow:(NSNotification *)notification {
    DDLogVerbose(@"keyboardWillShow");
    forceTouching = NO;
    [self processKeyboardNotification:notification willHide:NO];
    
    self.composing = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    DDLogVerbose(@"keyboardWillHide");
    [self processKeyboardNotification:notification willHide:YES];
    
    [_tableDataSource refreshSectionHeadersInTableView:self.chatContent];
}

- (void)processKeyboardNotification:(NSNotification*)notification willHide:(BOOL)willHide {
    if (notification == nil) {
        CGRect newKeyboardEndFrame = lastKeyboardEndFrame;
        if (lastKeyboardHeight == 162 && [UIScreen mainScreen].bounds.size.height == 320.0) {
            newKeyboardEndFrame.size.height = lastKeyboardEndFrame.size.height;
        }
        else if (lastKeyboardHeight == 162 || lastKeyboardHeight == 216) {
            newKeyboardEndFrame.size.height = lastKeyboardEndFrame.size.height + 32.0;
        }
        else {
            newKeyboardEndFrame.size.height = lastKeyboardEndFrame.size.height + 42.0;
        }
        
        [UIView animateWithDuration:lastAnimationDuration delay:0 options:(lastAnimationCurve << 16 | UIViewAnimationOptionBeginFromCurrentState) animations:^{
            [self moveContainerViewForKeyboardFrame:newKeyboardEndFrame willHide:willHide];
        } completion:^(BOOL finished) {}];
    } else {
        CGRect keyboardEndFrame;
        [notification.userInfo[UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
        
        CGSize keyboardSize = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
        
        DDLogVerbose(@"keyboardEndFrame: %@", NSStringFromCGRect(keyboardEndFrame));
        DDLogVerbose(@"Keyboardsize height: %f", keyboardSize.height);
        
        NSNumber *durationValue = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
        NSTimeInterval animationDuration = durationValue.doubleValue;
        
        NSNumber *curveValue = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        UIViewAnimationCurve animationCurve = curveValue.intValue;
        
        lastKeyboardEndFrame = keyboardEndFrame;
        lastAnimationDuration = animationDuration;
        lastAnimationCurve = animationCurve;
        
        if (visible) {
            [UIView animateWithDuration:animationDuration delay:0 options:(animationCurve << 16 | UIViewAnimationOptionBeginFromCurrentState) animations:^{
                [self moveContainerViewForKeyboardFrame:keyboardEndFrame willHide:willHide];
            } completion:^(BOOL finished) {}];
        } else {
            [self moveContainerViewForKeyboardFrame:keyboardEndFrame willHide:willHide];
        }
    }
}

- (void)inputModeDidChange:(NSNotification *)notification {
    // iPhone X fix
    if (@available(iOS 11.0, *)) {
        if([[UITextInputMode currentInputMode].primaryLanguage isEqualToString:@"emoji"]) {
            if (SYSTEM_IS_IPHONE_X && (lastKeyboardHeight == 291 || lastKeyboardHeight == 171)) { // iPhone X
                [self processKeyboardNotification:nil willHide:NO];
            } else if (lastKeyboardHeight == 226) { // Portrait iPhone 5.5'
                [self processKeyboardNotification:nil willHide:NO];
            } else if (lastKeyboardHeight == 216) { // Portrait iPhone 4' iPhone 4.7'
                [self processKeyboardNotification:nil willHide:NO];
            } else if (lastKeyboardHeight == 162) { // Landscape iPhone 5.5' iPhone 4.7' iPhone 4'
                [self processKeyboardNotification:nil willHide:NO];
            } else if (SYSTEM_IS_IPAD == YES && lastKeyboardHeight == 304) { // iPad
                [self processKeyboardNotification:nil willHide:NO];
            } else if (SYSTEM_IS_IPAD == YES && (lastKeyboardHeight == 279 || lastKeyboardHeight == 374)) { // iPad Pro 12.9
                [self processKeyboardNotification:nil willHide:NO];
            }
        }
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    DDLogVerbose(@"setEditing");
    [super setEditing:editing animated:animated];
    [chatContent setEditing:editing animated:animated];
    
    tapGestureRecognizer.enabled = !editing;
    
    chatContent.separatorStyle = editing ?
    UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    
    if (editing) {
        UIBarButtonItem *deleteButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"delete_all", nil) style:UIBarButtonItemStylePlain target:self action:@selector(deleteAction:)];
        deleteButton.tintColor = [UIColor redColor];
        self.navigationItem.leftBarButtonItem = deleteButton;
        self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction:)]];
        
        self.loadEarlierMessages.hidden = YES;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItems = @[self.editButtonItem];
        
        self.loadEarlierMessages.hidden = NO;
    }
    
    if (editing) {
        [self checkShouldShowHeader];
        [self hideKeyboardTemporarily:NO];
    }
}

#pragma mark - ChatBarDelegate

- (void)chatBar:(ChatBar *)curChatBar didChangeHeight:(CGFloat)height {
    BOOL wasScrolledAtBottom = [self isScrolledAtBottom];
    
    CGRect chatContentFrame = chatContent.frame;
    chatContentFrame.size.height = containerView.frame.size.height - height - [self tabBarHeight] - wrapperBottomPadding;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.1f];
    chatContent.frame = chatContentFrame;
    chatBarWrapper.frame = CGRectMake(chatBarWrapper.frame.origin.x, chatContentFrame.size.height, containerView.frame.size.width, height + wrapperBottomPadding);
    chatBar.frame = CGRectMake(0, 0, chatBarWrapper.frame.size.width, height);
    [self repositionScrollDownButton];
    [UIView commitAnimations];
    
    if (wasScrolledAtBottom)
        [self scrollToBottomAnimated:YES];
}

- (void)chatBar:(ChatBar *)curChatBar didSendText:(NSString *)text {
    if (text.length == 0 && curChatBar.canSendAudio) {
        if (![[PermissionChecker permissionCheckerPresentingAlarmsOn:self] canSendIn:conversation entityManager:nil]) {
            return;
        }
        
        /* microphone button pressed */
        [self hideKeyboardTemporarily:YES];
        [self startRecordingAudio];
        return;
    }
    
    NSString *trimmedMessage = nil;
    NSData *quoteMessageId = nil;
    NSString *remainingBody = nil;
    NSString *quotedText = nil;
    quoteMessageId = [QuoteParser parseQuoteV2FromMessage:text remainingBody:&remainingBody];
    
    if (quoteMessageId || quotedText) {
        remainingBody = [remainingBody stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    trimmedMessage = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Don't send blank messages.
    if (quoteMessageId || quotedText) {
        if (remainingBody == nil || remainingBody.length == 0 || [remainingBody isEqualToString:@"\ufffc"]) {
            [chatBar clearChatInput];
            return;
        }
    } else {
        if (trimmedMessage == nil || trimmedMessage.length == 0 || [trimmedMessage isEqualToString:@"\ufffc"]) {
            [chatBar clearChatInput];
            return;
        }
    }
    
    if (![[PermissionChecker permissionCheckerPresentingAlarmsOn:self] canSendIn:conversation entityManager:nil]) {
        return;
    }
    
    NSArray *trimmedMessages = [Utils getTrimmedMessages:trimmedMessage];
    
    [chatBar checkEnableSendButton];
    
    if (!trimmedMessages) {
        [MessageSender sendMessage:trimmedMessage inConversation:conversation async:YES quickReply:NO requestId:nil onCompletion:^(TextMessage *message, Conversation *conv) {
            [MessageDraftStore deleteDraftForConversation:self.conversation];
        }];
    } else {
        [trimmedMessages enumerateObjectsUsingBlock:^(NSString *separatedTrimmedMessage, NSUInteger idx, BOOL * _Nonnull stop) {
            [MessageSender sendMessage:separatedTrimmedMessage inConversation:conversation async:YES quickReply:NO requestId:nil onCompletion:^(TextMessage *message, Conversation *conv) {
                if (idx == trimmedMessages.count - 1) {
                    [MessageDraftStore deleteDraftForConversation:self.conversation];
                }
            }];
        }];
    }
    [chatBar clearChatInput];
    
    if ([UserSettings sharedUserSettings].inAppSounds) {
        AudioServicesPlaySystemSound(sentMessageSound);
    }
}

- (void)chatBar:(ChatBar *)chatBar didSendImageData:(NSData *)image {
    [self sendImageData:image];
    [self.chatBar resetKeyboardType:true];
}

- (void)chatBar:(ChatBar *)chatBar didPasteImageData:(NSData *)image {
    [self hideKeyboardTemporarily:YES];
    [self handlePastedImage:image];
}

- (void)chatBar:(ChatBar*)chatBar didPasteItems:(NSArray*)items {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideKeyboardTemporarily:YES];
        [MBProgressHUD showHUDAddedTo:self.view animated:true];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ItemLoader *itemLoader = [[ItemLoader alloc] initWithForceLoadFileURLItem:true];
        for (NSItemProvider *itemProvider in items) {
            NSString *baseType = [ItemLoader getBaseUTIType:itemProvider];
            NSString *secondType = [ItemLoader getSecondUTIType:itemProvider];
            [itemLoader addItemWithItemProvider:itemProvider type:baseType secondType:secondType];
        }
        NSArray *loadedItems = [itemLoader syncLoadContentItems];
        if (loadedItems.count == 0) {
            [self showPasteError];
        } else {
            [self showPastedItemPreview:loadedItems];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:true];
        });
    });
}

- (void)showPastedItemPreview:(NSArray *) loadedItems {
    dispatch_async(dispatch_get_main_queue(), ^{
        SendMediaAction *sendMediaAction = [SendMediaAction actionForChatViewController:self];
        [sendMediaAction showPreviewForAssets:loadedItems];
    });
}

- (void)showPasteError {
    NSString *title = [BundleUtil localizedStringForKey:@"pasteErrorMessageTitle"];
    NSString *message = [BundleUtil localizedStringForKey:@"pasteErrorMessageMessage"];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:title message:message actionOk:nil];
    });
}

- (void)handlePastedImage:(NSData *)data {
    SendMediaAction *sendMediaAction = [SendMediaAction actionForChatViewController:self];
    
    NSString *filename = [FileUtility getTemporaryFileName];
    NSString *extension = [UTIConverter preferedFileExtensionForMimeType:[UTIConverter mimeTypeFromUTI:(__bridge NSString *)[ImageURLSenderItemCreator getUTIFor:data]]];
    NSURL *tempDir = [[NSFileManager defaultManager] temporaryDirectory];
    NSURL *fileURl = [[tempDir URLByAppendingPathComponent:filename] URLByAppendingPathExtension:extension];
    
    if (!fileURl) {
        [self showPasteFailureAlert];
        return;
    }
    
    bool success = [data writeToURL:fileURl atomically:false];
    
    if (!success) {
        [self showPasteFailureAlert];
        return;
    }
    
    [sendMediaAction showPreviewForAssets:@[fileURl]];
}

- (void)showPasteFailureAlert {
    NSString *title = [BundleUtil localizedStringForKey:@"paste_create_file_failure_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"paste_create_file_failure_message"];
    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:title message:message actionOk:nil];
}

- (void)chatBarWillStartTyping:(ChatBar *)chatBar {
    if ([UserSettings sharedUserSettings].sendTypingIndicator == true) {
        if (typingIndicatorSent)
            return;
        if (conversation.groupId == nil && [[PermissionChecker permissionCheckerPresentingAlarmsOn:self] canSendIn:conversation entityManager:nil])
            [MessageSender sendTypingIndicatorMessage:YES toIdentity:conversation.contact.identity];
        typingIndicatorSent = YES;
    }
}

- (void)chatBarDidStopTyping:(ChatBar *)theChatBar {
    if ([UserSettings sharedUserSettings].sendTypingIndicator == true) {
        if (!typingIndicatorSent)
            return;
        if (conversation.groupId == nil)
            [MessageSender sendTypingIndicatorMessage:NO toIdentity:conversation.contact.identity];
        typingIndicatorSent = NO;
        
        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        if ([[chatBar.text stringByTrimmingCharactersInSet: set] length] > 0) {
            [MessageDraftStore saveDraft:[chatBar formattedMentionText] forConversation:self.conversation];
        } else {
            [MessageDraftStore saveDraft:@"" forConversation:self.conversation];
        }
    }
}

- (void)chatBarDidPushAddButton:(ChatBar *)_chatBar {
    
    if (![[PermissionChecker permissionCheckerPresentingAlarmsOn:self] canSendIn:conversation entityManager:nil]) {
        return;
    }
    
    if (SYSTEM_IS_IPAD == true) {
        [_delegate cancelSwipeGestureFromConversations];
    }
    
    CGRect rect = [self.view convertRect:chatBar.addButton.frame fromView:_chatBar];
    [self showAddActionAlertControllerFrom:rect inView:self.view];
}

- (void)showAddActionAlertControllerFrom:(CGRect)rect inView:(UIView *)view {
    if (_assetActionHelperWillPresent) {
        return;
    }
    _assetActionHelperWillPresent = true;
    [self hideKeyboardTemporarily:YES];
    
    if (assetActionHelper == nil) {
        assetActionHelper = [[PPAssetsActionHelper alloc] init];
        assetActionHelper.delegate = self;
    }
    PPAssetsActionController *assetActionController = [assetActionHelper buildAction];
    if ([[UserSettings sharedUserSettings] showGalleryPreview]) {
        [[UserSettings sharedUserSettings] setOpenPlusIconInChat:YES];
    }
    [self presentViewController:assetActionController animated:YES completion:^{
        _assetActionHelperWillPresent = false;
        if ([[UserSettings sharedUserSettings] showGalleryPreview]) {
            [[UserSettings sharedUserSettings] setOpenPlusIconInChat:NO];
        }
    }];
}

- (UIInterfaceOrientation)interfaceOrientationForChatBar:(ChatBar *)chatBar {
    return [[UIApplication sharedApplication] statusBarOrientation];
}

- (BOOL)canBecomeFirstResponder {
    return ![self.presentedViewController isKindOfClass:[CallViewController class]] && self.presentedViewController == nil;
}

- (void)chatBarTapped:(ChatBar *)chatBar {
    if (SYSTEM_IS_IPAD == true) {
        [_delegate cancelSwipeGestureFromConversations];
    }
}

- (void)chatBarDidAddQuote {
    if (_searching) {
        [headerView cancelSearch];
    }
}

- (UIView *)chatContainterView {
    return self.view;
}

#pragma mark - Chat message cell delegate

- (void)imageMessageTapped:(ImageMessage *)message {
    [self hideKeyboardTemporarily:YES];
    
    UIViewController *vc = [headerView getPhotoBrowserAtMessage:message forPeeking:NO];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)fileImageMessageTapped:(FileMessage *)message {
    [self hideKeyboardTemporarily:true];
    
    if (!message.renderStickerFileMessage) {
        UIViewController *vc = [headerView getPhotoBrowserAtMessage:message forPeeking:NO];
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        [self presentViewController:vc animated:YES completion:nil];
    }
}

- (void)fileVideoMessageTapped:(FileMessage *)message {
    if (message.data == nil) {
        /* need to download this video first */
        BlobMessageLoader *loader = [[BlobMessageLoader alloc] init];
        [loader startWithMessage:message onCompletion:^(BaseMessage<BlobData> *loadedMessage) {
            if (visible) {
                [self playFileVideoMessage:message];
            }
        } onError:^(NSError *error) {
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }];
    } else {
        /* can show/play this video right now */
        [self playFileVideoMessage:message];
    }
}

- (void)fileAudioMessageTapped:(FileMessage *)message {
    if (message.data == nil) {
        [PlayRecordAudioViewController activateProximityMonitoring];
        /* need to download this audio first */
        BlobMessageLoader *loader = [[BlobMessageLoader alloc] init];
        [loader startWithMessage:message onCompletion:^(BaseMessage *loadedMessage) {
            if (visible) {
                [self playFileAudioMessage:message];
            }
        } onError:^(NSError *error) {
            [PlayRecordAudioViewController deactivateProximityMonitoring];
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }];
    } else {
        /* can show/play this audio right now */
        [self playFileAudioMessage:message];
    }
}

- (void)locationMessageTapped:(LocationMessage *)message {
    [self hideKeyboardTemporarily:YES];
    
    locationToShow = message;
    [self performSegueWithIdentifier:@"ShowLocation" sender:self];
}

- (void)videoMessageTapped:(VideoMessage*)message {
    if (message.video == nil) {
        /* need to download this video first */
        VideoMessageLoader *loader = [[VideoMessageLoader alloc] init];
        [loader startWithMessage:message onCompletion:^(BaseMessage<BlobData> *loadedMessage) {
            if (visible) {
                [self playVideoMessage:message];
            }
        } onError:^(NSError *error) {
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }];
    } else {
        /* can show/play this video right now */
        [self playVideoMessage:message];
    }
}

- (void)startPlayer {
    [self hideKeyboardTemporarily:YES];
    
    AppDelegate *appDelegate = [AppDelegate sharedAppDelegate];
    
    /* ignore mute switch */
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (state == CallStateIdle) {
        prevAudioCategory = [[AVAudioSession sharedInstance] category];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
    AVPlayer *p = [AVPlayer playerWithURL:tmpAudioVideoUrl];
    player = [AVPlayerViewController new];
    player.player = p;
    if (self.isViewLoaded && self.view.window) {
        //self is visible
        [self presentViewController:player animated:YES completion:^{
            [player.player play];
            if (state != CallStateIdle) {
                [[VoIPCallStateManager shared] activateRTCAudio];
            }
        }];
    } else {
        [appDelegate.window.rootViewController.presentedViewController presentViewController:player animated:YES completion:^{
            [player.player play];
        }];
    }
}

- (void)createTmpAVFileFrom:(id<BlobData>)message {
    NSURL *tmpDirUrl = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    tmpAudioVideoUrl = [[tmpDirUrl URLByAppendingPathComponent:@"av"] URLByAppendingPathExtension: MEDIA_EXTENSION_VIDEO];
    DDLogInfo(@"fileURL: %@", [tmpAudioVideoUrl path]);
    
    NSData *data = [message blobGetData];
    if (![data writeToURL:tmpAudioVideoUrl atomically:NO]) {
        DDLogWarn(@"Writing audio/video data to temporary file failed");
        return;
    }
}

- (void)playVideoMessage:(VideoMessage*)message {
    /* write video to temp. file */
    [self createTmpAVFileFrom:message];
    
    if (tmpAudioVideoUrl) {
        [self startPlayer];
    }
}

- (void)playFileVideoMessage:(FileMessage *)message {
    /* write video to temp. file */
    [self createTmpAVFileFrom:message];
    
    if (tmpAudioVideoUrl) {
        [self startPlayer];
    }
}

- (void)showMessageDetails:(BaseMessage *)message {
    detailsMessage = message;
    [self performSegueWithIdentifier:@"ShowDetails" sender:self];
}

- (void)audioMessageTapped:(AudioMessage*)message {
    if (message.audio == nil) {
        [PlayRecordAudioViewController activateProximityMonitoring];
        /* need to download this audio first */
        BlobMessageLoader *loader = [[BlobMessageLoader alloc] init];
        [loader startWithMessage:message onCompletion:^(BaseMessage *loadedMessage) {
            if (visible) {
                [self playAudioMessage:message];
            }
        } onError:^(NSError *error) {
            [PlayRecordAudioViewController deactivateProximityMonitoring];
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }];
    } else {
        /* can show/play this audio right now */
        [self playAudioMessage:message];
    }
}

- (void)ballotMessageTapped:(BallotMessage*)message {
    [self hideKeyboardTemporarily:YES];
    
    [BallotDispatcher showViewControllerForBallot:message.ballot onNavigationController:self.navigationController];
}

- (void)mentionTapped:(id)mentionObject {
    [self hideKeyboardTemporarily:NO];
    if ([mentionObject isKindOfClass:[Contact class]]) {
        [self performSegueWithIdentifier:@"ShowContact" sender:(Contact *)mentionObject];
    } else {
        [self performSegueWithIdentifier:@"ShowMeContact" sender:(Contact *)mentionObject];
    }
}

- (void)showQuotedMessage:(BaseMessage *)message {
    _cancelShowQuotedMessage = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __block NSIndexPath *indexPath = nil;
        while (_cancelShowQuotedMessage == NO) {
            indexPath = [self indexPathForMessage:message];
            
            if (indexPath) {
                // found message
                break;
            } else {
                NSInteger offset = [self messageOffset];
                
                if (offset > 0) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self addLoadEarlierMessagesHUD];
                        
                        [self loadEarlierMessagesAction:nil];
                        
                        if (_cancelShowQuotedMessage) {
                            return;
                        }
                        
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
                        [self.chatContent scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                    });
                } else {
                    break;
                }
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (indexPath) {
                // safety check if indexPath is still valid
                if ([self isValidIndexPath:indexPath] == NO) {
                    return;
                }
                
                [self.chatContent scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
                
                __block ChatMessageCell *currentCell = (ChatMessageCell *)[self.chatContent cellForRowAtIndexPath:indexPath];
                
                // Deselect all currently selected cells
                for (ChatMessageCell *visibleCell in self.chatContent.visibleCells) {
                    if ([visibleCell respondsToSelector:@selector(setBubbleHighlighted:)]) {
                        [visibleCell setBubbleHighlighted:NO];
                    }
                }
                
                CGFloat delayMs;
                if (currentCell) {
                    delayMs = 100.0;
                } else {
                    // cell not visible yet
                    delayMs = 400.0;
                }
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayMs * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    currentCell = (ChatMessageCell *)[self.chatContent cellForRowAtIndexPath:indexPath];
                    [currentCell setBubbleHighlighted:YES];
                    
                    if (UIAccessibilityIsVoiceOverRunning()) {
                        NSString *text = currentCell.accessibilityLabel;
                        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
                    }
                });
            }
        });
    });
}

- (BOOL)isValidIndexPath:(NSIndexPath *)indexPath {
    NSInteger sectionCount = [self.chatContent.dataSource numberOfSectionsInTableView:self.chatContent];
    if (indexPath.section >= sectionCount) {
        return NO;
    }
    
    NSInteger rowCount = [self.chatContent.dataSource tableView:self.chatContent numberOfRowsInSection:indexPath.section];
    if (indexPath.row >= rowCount) {
        return NO;
    }
    
    return YES;
}

- (void)addLoadEarlierMessagesHUD {    
    if ([MBProgressHUD HUDForView:self.view] != nil) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = [BundleUtil localizedStringForKey:@"load_earlier_messages"];
    [hud.button setTitle:NSLocalizedString(@"cancel", nil) forState:UIControlStateNormal];
    [hud.button addTarget:self action:@selector(cancelShowQuotedMessage) forControlEvents:UIControlEventTouchUpInside];
}

- (void)cancelShowQuotedMessage {
    _cancelShowQuotedMessage = YES;
}

#pragma mark - Preview image delegate

- (void)previewImageControllerDidChooseToSend:(PreviewImageViewController *)previewController imageData:(NSData *)image {
    [self sendImageData:image];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)previewImageControllerDidChooseToSend:(PreviewImageViewController *)previewController gif:(NSData *)gifData {
    [self previewImageControllerDidChooseToSend:previewController imageData:gifData];
}

- (void)previewImageControllerDidChooseToCancel:(PreviewImageViewController *)previewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sendImageData:(NSData *)imageData {
    if (imageData == nil)
        return;
    
    ImageURLSenderItemCreator *imageSender = [[ImageURLSenderItemCreator alloc] init];
    
    CFStringRef uti = [ImageURLSenderItemCreator getUTIFor:imageData];
    if (uti == nil) {
        uti = kUTTypeJPEG;
    }
    URLSenderItem *item = [imageSender senderItemFrom:imageData uti:(__bridge NSString *)uti];
    
    FileMessageSender *sender = [[FileMessageSender alloc] init];
    [sender sendItem:item inConversation:conversation];
}


#pragma mark - scroll view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (visible) {
        [self updateScrollDownButtonAnimated:YES];
        
        CGFloat yDiff = scrollView.contentOffset.y - lastScrollOffset.y;
        if (yDiff > 32.0 && lastScrollOffset.y != 0.0) {
            if (scrollView.isDragging) {
                [self hideHeaderWithDuration:0.2];
                lastScrollOffset = scrollView.contentOffset;
            }
        }
    }
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    lastScrollOffset = scrollView.contentOffset;
    
    if (self.searching) {
        [headerView resignFirstResponder];
    }
}

-(void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    
    if (velocity.y == 0.0) {
        return;
    }
    
    BOOL velocityTriggerUp = velocity.y < -0.8;
    BOOL velocityTriggerDown = velocity.y > 0.0;
    
    CGFloat topOffset = [self topOffsetForVisibleContent];
    
    BOOL offsetTrigger = targetContentOffset->y <= -topOffset;
    
    // scrollViewWillEndDragging velocity is points/milliseconds
    CGFloat duration = fabs(scrollView.contentOffset.y - targetContentOffset->y)/fabs(velocity.y*1000);
    duration = fminf(duration, 0.8);
    duration = fmaxf(duration, 0.2);
    
    if (velocityTriggerUp) {
        [self showHeaderWithDuration:duration completion:nil];
    } else if (offsetTrigger && velocity.y < 0.0) {
        [self showHeaderWithDuration:duration completion:nil];
    } else if (velocityTriggerDown) {
        [self hideHeaderWithDuration:duration];
    }
}

-(BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    isScrollingToTop = YES;
    [self hideKeyboardTemporarily:NO];
    
    if ([self checkShouldShowHeader]) {
        CGFloat yOffset = scrollView.contentOffset.y - [headerView getHeight];
        
        UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, yOffset);
        } completion:^(BOOL finished) {
            isScrollingToTop = NO;
        }];
    };
    
    return YES;
}


#pragma mark - header view show/hide

- (void)showHeaderWithDuration:(CGFloat)duration completion:(void (^ __nullable)(BOOL finished))completion {
    
    CGFloat targetOffset = [self topOffsetForVisibleContent];
    CGRect targetRect = [RectUtil setYPositionOf:headerView.frame y:targetOffset];
    
    if (headerView.hidden == NO && CGRectEqualToRect(targetRect, headerView.frame)) {
        return;
    }
    
    if ([self shouldShowHeader] == NO) {
        return;
    }
    
    CGFloat headerHeight = [headerView getHeight];
    headerView.frame = [RectUtil setYPositionOf:headerView.frame y: -headerHeight];
    headerView.hidden = NO;
    showHeader = YES;
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        headerView.frame = targetRect;
        [self updateChatContentInset];
    } completion:^(BOOL finished) {
        headerView.hidden = NO;
        if (completion != nil) {
            completion(YES);
        }
    }];
}

- (void)hideHeaderWithDuration:(CGFloat)duration {
    CGFloat headerHeight = [headerView getHeight];
    CGRect targetRect = [RectUtil setYPositionOf:headerView.frame y: -headerHeight];
    if (headerView.hidden == YES && CGRectEqualToRect(targetRect, headerView.frame)) {
        return;
    }
    
    if ([self shouldShowHeader]) {
        return;
    }
    
    showHeader = NO;
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        headerView.frame = targetRect;
    } completion:^(BOOL finished) {
        [self updateChatContentInset];
        headerView.hidden = YES;
    }];
}

- (BOOL)shouldShowHeader {
    if (_isOpenWithForceTouch) {
        chatBarWrapper.hidden = YES;
        if (@available(iOS 13.0, *)) {
            if ([self chatContentSmallerThanVisibleArea]) {
                chatContent.frame = CGRectMake(chatContent.frame.origin.x, chatContent.frame.origin.y, chatContent.frame.size.width, [self unvisibleChatHeight]);
            } else {
                chatContent.frame = CGRectMake(chatContent.frame.origin.x, CGRectGetHeight(chatContent.frame) - [self unvisibleChatHeight], chatContent.frame.size.width, [self unvisibleChatHeight]);
            }
        } else {
            if ([self chatContentSmallerThanVisibleArea]) {
                chatContent.frame = CGRectMake(chatContent.frame.origin.x, chatContent.frame.origin.y, chatContent.frame.size.width, [self unvisibleChatHeight]);
            } else {
                chatContent.frame = CGRectMake(chatContent.frame.origin.x, chatContent.frame.origin.y - CGRectGetHeight(headerView.frame), chatContent.frame.size.width, [self unvisibleChatHeight] + CGRectGetHeight(headerView.frame));
            }
        }
        return NO;
    }
    else if (_searching) {
        // always show when searching
        return YES;
    } else if (SYSTEM_IS_IPAD == NO && UIDeviceOrientationIsLandscape((UIDeviceOrientation)[[UIApplication sharedApplication] statusBarOrientation])) {
        //hide for landscape - only on iPhone
        return NO;
    } else if (lastKeyboardHeight > 0.0 && !isScrollingToTop) {
        //hide if not enough space
        return NO;
    } else if ([self chatContentSmallerThanVisibleArea]) {
        // show if area not filled with chat content
        return YES;
    } else if (self.editing) {
        // hide when editing
        return NO;
    } else if (isFirstAppearance) {
        // initially hidden
        return NO;
    } else if (isScrollingToTop) {
        // keep when scrolling to top
        return YES;
    } else if (shouldScrollDown) {
        // don't show header when initially scrolling down
        return NO;
    } else if (isScrollingToUnreadMessages) {
        // don't show header when scrolling to first unread messages
        isScrollingToUnreadMessages = NO;
        return NO;
    } else if (isNewMessageReceivedInActiveChat) {
        // don't show header if receive new message in a active chat
        isNewMessageReceivedInActiveChat = NO;
        return NO;
    }
    
    // otherwise toggle
    return headerView.hidden;
}

- (BOOL)checkShouldShowHeader {
    if ([self shouldShowHeader]) {
        [self showHeaderWithDuration:0.3 completion:nil];
        return YES;
    } else {
        [self hideHeaderWithDuration:0.3];
        return NO;
    }
}

- (void)toggleHeader {
    if (headerView.hidden) {
        [self hideKeyboardTemporarily:NO];
        [self showHeaderWithDuration:0.3 completion:nil];
    } else {
        [self hideHeaderWithDuration:0.3];
    }
}

- (BOOL)visible {
    return visible;
}

- (CGFloat)visibleChatHeight {
    return CGRectGetHeight(self.chatContent.frame) - chatContent.contentInset.top;
}

- (CGFloat)unvisibleChatHeight {
    return CGRectGetHeight(self.chatContent.frame) + chatBarWrapper.frame.size.height;
}

- (BOOL)chatContentSmallerThanVisibleArea {
    CGFloat heightOfVisibleChatView = [self visibleChatHeight] - CGRectGetHeight(headerView.frame);
    return heightOfVisibleChatView - chatContent.contentSize.height >= 0.0;
}

#pragma mark - ChatViewHeaderDelegate

-(void)didChangeHeightTo:(CGFloat)newHeight {
    [self updateChatContentInset];
}


#pragma mark - GroupDetailsViewControllerDelegate

- (void)presentGroupDetails:(GroupDetailsViewController *)groupDetailsViewController onCompletion:(GroupDetailsCompletionBlock)onCompletion {
    // not used
}

- (void)updateMembersObserver:(NSSet *)oldMembers newMembers:(NSSet *)newMembers {
    if (oldMembers != nil && oldMembers != (id)[NSNull null]) {
        [oldMembers enumerateObjectsUsingBlock:^(Contact *contact, BOOL * _Nonnull stop) {
            @try {
                [contact removeObserver:self forKeyPath:@"displayName"];
            }
            @catch (NSException * __unused exception) {}
        }];
    }
    if (newMembers != nil && newMembers != (id)[NSNull null]) {
        [newMembers enumerateObjectsUsingBlock:^(Contact *contact, BOOL * _Nonnull stop) {
            @try {
                [contact addObserver:self forKeyPath:@"displayName" options:0 context:nil];
            }
            @catch (NSException * __unused exception) {}
        }];
    }
}


# pragma mark - preview actions

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    NSMutableArray *previewActions = [NSMutableArray array];
    
    if (_delegate == nil) {
        return previewActions;
    }
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSString *actionTitle = NSLocalizedString(@"take_photo_or_video", nil);
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:actionTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            
            [_delegate presentChatViewController:self onCompletion:^(ChatViewController *chatViewController) {
                SendMediaAction *sendMediaAction = [SendMediaAction actionForChatViewController:chatViewController];
                sendMediaAction.mediaPickerType = MediaPickerTakePhoto;
                
                currentAction = sendMediaAction;
                [sendMediaAction executeAction];
            }];
        }];
        
        [previewActions addObject:shareAction];
    }
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        NSString *actionTitle = NSLocalizedString(@"choose_existing", nil);
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:actionTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            
            [_delegate presentChatViewController:self onCompletion:^(ChatViewController *chatViewController) {
                
                SendMediaAction *sendMediaAction = [SendMediaAction actionForChatViewController:chatViewController];
                sendMediaAction.mediaPickerType = MediaPickerChooseExisting;
                
                currentAction = sendMediaAction;
                [sendMediaAction executeAction];
            }];
        }];
        
        [previewActions addObject:shareAction];
    }
    
    if ([CLLocationManager locationServicesEnabled]) {
        NSString *actionTitle = NSLocalizedString(@"share_location", nil);
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:actionTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            
            [_delegate presentChatViewController:self onCompletion:^(ChatViewController *chatViewController) {
                SendLocationAction *sendLocationAction = [SendLocationAction actionForChatViewController:chatViewController];
                currentAction = sendLocationAction;
                [sendLocationAction executeAction];
            }];
        }];
        
        [previewActions addObject:shareAction];
    }
    
    if ([PlayRecordAudioViewController canRecordAudio]) {
        NSString *actionTitle = NSLocalizedString(@"record_audio", nil);
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:actionTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            
            [_delegate presentChatViewController:self onCompletion:^(ChatViewController *chatViewController) {
                [chatViewController startRecordingAudio];
            }];
        }];
        
        [previewActions addObject:shareAction];
    }
    
    NSString *actionTitle = NSLocalizedStringFromTable(@"ballot_create", @"Ballot", nil);
    UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:actionTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        
        [_delegate presentChatViewController:self onCompletion:^(ChatViewController *chatViewController) {
            
            [chatViewController createBallot];
        }];
    }];
    
    [previewActions addObject:shareAction];
    
    actionTitle = NSLocalizedString(@"share_file", nil);
    shareAction = [UIPreviewAction actionWithTitle:actionTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        
        [_delegate presentChatViewController:self onCompletion:^(ChatViewController *chatViewController) {
            [chatViewController sendFile];
        }];
    }];
    
    [previewActions addObject:shareAction];
    
    return previewActions;
}

#pragma mark - UIViewControllerPreviewingDelegate

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    
    if ([viewControllerToCommit isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)viewControllerToCommit;
        navigationController.navigationBar.hidden = NO;
        
        if ([navigationController.topViewController isKindOfClass:[MWPhotoBrowser class]]) {
            ((MWPhotoBrowser*)navigationController.topViewController).peeking = NO;
        }
        
        [self presentViewController:viewControllerToCommit animated:YES completion:nil];
    }
    else if ([viewControllerToCommit isKindOfClass:[ThreemaSafariViewController class]]) {
        [self.navigationController presentViewController:viewControllerToCommit animated:false completion:^{
            [viewControllerToCommit dismissViewControllerAnimated:false completion:^{
                [[UIApplication sharedApplication] openURL:((ThreemaSafariViewController *)viewControllerToCommit).url options:@{} completionHandler:nil];
            }];
        }];
        
    } else {
        [self.navigationController pushViewController:viewControllerToCommit animated:YES];
    }
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    
    UIView *view = [self.view hitTest:location withEvent:nil];
    
    ChatMessageCell *cell = (ChatMessageCell *)[Utils view:view getSuperviewOfKind:[ChatMessageCell class]];
    if (cell) {
        forceTouching = YES;
        UIViewController *previewController = [cell previewViewController];
        
        if ([[cell previewViewControllerFor:previewingContext viewControllerForLocation:location] isKindOfClass:[ThreemaSafariViewController class]]) {
            previewController = [cell previewViewControllerFor:previewingContext viewControllerForLocation:location];
            if (!previewController || UIAccessibilityIsVoiceOverRunning()) {
                return nil;
            }
            _Bool legalURL = [IDNSafetyHelper isLegalURLWithUrl:((ThreemaSafariViewController *)previewController).url];
            if (!legalURL) {
                return nil;
            }
        }
        else {
            if ([previewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navigationController = (UINavigationController *)previewController;
                navigationController.navigationBar.hidden = YES;
            }
        }
        
        previewingContext.sourceRect = [self.view convertRect:cell.frame fromView:self.chatContent];
        
        return previewController;
    }
    
    return nil;
}

#pragma mark - Audio player/recorder delegate

- (void)audioPlayerDidHide {
    UITableViewCell *selectedCell = [self.chatContent cellForRowAtIndexPath:selectedAudioMessage];
    
    if (selectedCell) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, selectedCell);
    } else {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    }
    audioRecorder = nil;
    selectedAudioMessage = nil;
}

#pragma mark - Notifications

- (void)showProfilePictureChanged:(NSNotification*)notification {
    [headerView refresh];
}

#pragma mark - PPAssetsActionHelperDelegate

- (void)assetsActionHelperDidCancel:(PPAssetsActionHelper *)picker {
    // do nothing
}

- (void)assetsActionHelper:(PPAssetsActionHelper *)picker didFinishPicking:(NSArray *)assets {
    
}

- (void)assetActionHelperDidSelectOwnOption:(PPAssetsActionHelper *)picker  didFinishPicking:(NSArray *)assets {
    [self dismissViewControllerAnimated:YES completion:nil];
    SendMediaAction *action = [SendMediaAction actionForChatViewController:self];
    [action sendAssets:assets asFile:false withCaptions:nil];
}

- (void)assetsActionHelperDidSelectOwnSnapButton:(PPAssetsActionHelper *)picker didFinishPicking:(NSArray *)assets {
    [self dismissViewControllerAnimated:YES completion:nil];
    if (assets && assets.count) {
        SendMediaAction *action = [SendMediaAction actionForChatViewController:self];
        [action showPreviewForAssets:assets];
    } else {
        SendMediaAction *action = [SendMediaAction actionForChatViewController:self];
        action.mediaPickerType = MediaPickerChooseExisting;
        
        currentAction = action;
        [action executeAction];
    }
}

- (void)assetsActionHelperDidSelectLiveCameraCell:(PPAssetsActionHelper *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
    SendMediaAction *action = [SendMediaAction actionForChatViewController:self];
    action.mediaPickerType = MediaPickerTakePhoto;
    
    currentAction = action;
    [action executeAction];
}

- (void)assetsActionHelperDidSelectLocation:(PPAssetsActionHelper *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
    SendLocationAction *action = [SendLocationAction actionForChatViewController:self];
    currentAction = action;
    [action executeAction];
}

- (void)assetsActionHelperDidSelectRecordAudio:(PPAssetsActionHelper *)picker {
    [self dismissViewControllerAnimated:YES completion:^{
        [self hideKeyboardTemporarily:YES];
        [self startRecordingAudio];
    }];
}

- (void)assetsActionHelperDidSelectCreateBallot:(PPAssetsActionHelper *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self createBallot];
}

- (void)assetsActionHelperDidSelectShareFile:(PPAssetsActionHelper *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self sendFile];
}

#pragma mark - Voip

- (void)startVoipCall:(BOOL)withVideo {
    [self hideHeaderWithDuration:0.0];
    [FeatureMask checkFeatureMask:FEATURE_MASK_VOIP forContacts:[NSSet setWithObjects:self.conversation.contact, nil] onCompletion:^(NSArray *unsupportedContacts) {
        if (unsupportedContacts.count == 0) {
            VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:withVideo ? ActionCallWithVideo : ActionCall contact:conversation.contact callId:nil completion:nil];
            [[VoIPCallStateManager shared] processUserAction:action];
        } else {
            [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"call_voip_not_supported_title", nil) message:NSLocalizedString(@"call_voip_not_supported_text", nil) actionOk:nil];
        }
    }];
}

#pragma mark AVSpeechUtteranceDelegate

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    [[AVAudioSession sharedInstance] setCategory:prevAudioCategory error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didPauseSpeechUtterance:(AVSpeechUtterance *)utterance {
    [[AVAudioSession sharedInstance] setCategory:prevAudioCategory error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didContinueSpeechUtterance:(AVSpeechUtterance *)utterance {
    prevAudioCategory = [AVAudioSession sharedInstance].category;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback  error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
    [[AVAudioSession sharedInstance] setCategory:prevAudioCategory error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}


@end
