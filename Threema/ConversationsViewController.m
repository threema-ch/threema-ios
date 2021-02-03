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

#import "ConversationsViewController.h"
#import "AppDelegate.h"
#import "Conversation.h"
#import "Contact.h"
#import "ConversationCell.h"
#import "ChatViewController.h"
#import "ContactPickerViewController.h"
#import "Utils.h"
#import "NaClCrypto.h"
#import "ProtocolDefines.h"
#import "MyIdentityStore.h"
#import "PortraitNavigationController.h"
#import "EntityManager.h"
#import "ErrorHandler.h"
#import "GroupProxy.h"
#import "ChatViewControllerCache.h"
#import "DatabaseManager.h"
#import "BrandingUtils.h"
#import "MessageDraftStore.h"
#import "MGSwipeTableCell.h"
#import "ChatDefines.h"
#import "MessageSender.h"
#import "UIImage+ColoredImage.h"
#import "ConversationUtils.h"
#import "UserSettings.h"
#import "NotificationManager.h"
#import "LicenseStore.h"
#import "BundleUtil.h"
#import "SendMediaAction.h"
#import "SendLocationAction.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface ConversationsViewController () <NSFetchedResultsControllerDelegate, UIViewControllerPreviewingDelegate, UINavigationControllerDelegate, ChatViewControllerDelegate, MGSwipeTableCellDelegate, ConversationCellDelegate, UIScrollViewDelegate>

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@property id<UINavigationControllerDelegate> prevNavigationControllerDelegate;
@property (copy) ChatViewControllerCompletionBlock chatViewCompletionBlock;

@end

@implementation ConversationsViewController {
    UIBarButtonItem *composeButtonItem;
    NSDate *lastAppearDate;
    
    Conversation *conversationToDelete;
    BOOL isEditing;
    BOOL viewLoadedInBackground;
    
    NSIndexPath *lastSelectedCell;
    
    BOOL canTransitionToLarge;
    BOOL canTransitionToSmall;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressbookSyncronized:) name:kNotificationAddressbookSyncronized object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    // Listen for unread messages count changes so we can update our title
    // and back button
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unreadMessagesCountChanged:) name:@"ThreemaUnreadMessagesCountChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDirtyObjects:) name:kNotificationDBRefreshedDirtyObject object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDraftForCell:) name:kNotificationUpdateDraftForCell object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showProfilePictureChanged:) name:kNotificationShowProfilePictureChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableView:) name:kNotificationBlockedContact object:nil];
    
    self.clearsSelectionOnViewWillAppear = NO;
    
    [self registerForPreviewingWithDelegate:self sourceView:self.view];
    
    [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = [UserSettings sharedUserSettings].largeTitleDisplayMode;
    }
    
    canTransitionToLarge = false;
    canTransitionToSmall = true;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"messages", nil) style: UIBarButtonItemStylePlain target: nil action: nil];
    
    _createMessageBarButtonItem.accessibilityLabel = [BundleUtil localizedStringForKey:@"new_message_accessibility"];

    if (SYSTEM_IS_IPAD == NO) {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    }
    
    if (@available(iOS 11.0, *)) {
        self.tableView.estimatedSectionHeaderHeight = 0;
        self.tableView.estimatedSectionFooterHeight = 0;
    }
    
    self.tableView.estimatedRowHeight = 0.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    // iOS fix where the logo is moved to the right sometimes
    if (self.navigationController.navigationBar.frame.size.height == 44.0 && [LicenseStore requiresLicenseKey]) {
        [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
    }
    else if (self.navigationController.navigationBar.frame.size.height == 44.0 && ![LicenseStore requiresLicenseKey] && self.navigationItem.titleView != nil) {
        [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
    }
    
    
    // make sure conversations was updated
    if (![[AppDelegate sharedAppDelegate] isAppInBackground]) {
        viewLoadedInBackground = false;
    } else {
        viewLoadedInBackground = true;
    }
    
    // remove top space on tableview
    CGRect frame = CGRectZero;
    frame.size.height = CGFLOAT_MIN;
    [self.tableView setTableHeaderView:[[UIView alloc] initWithFrame:frame]];

    [self refreshData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self setEditing:NO animated:NO];
}

- (void)refreshData {
    if (viewLoadedInBackground == false) {
        [_fetchedResultsController performFetch:nil];
        [self.tableView reloadData];
    }
}

- (void)colorThemeChanged:(NSNotification*)notification {
    [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
}

- (void)checkDateAndUpdateTimestamps {
    NSDate *now = [NSDate date];
    if (lastAppearDate != nil && ![Utils isSameDayWithDate1:lastAppearDate date2:now]) {
        DDLogInfo(@"Last appeared on a different date; updating timestamps");
        if (viewLoadedInBackground == false) {
            [self.tableView reloadData];
        }
    }
    lastAppearDate = now;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.fetchedResultsController = nil;
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    [self checkDateAndUpdateTimestamps];
    if (viewLoadedInBackground == true) {
        viewLoadedInBackground = false;
        [self refreshData];
    }
}

- (void)unreadMessagesCountChanged:(NSNotification*)notification {
    
    int unread = ((NSNumber*)[notification.userInfo objectForKey:@"unread"]).intValue;
    
    NSString *backButtonTitle;
    if (unread > 0) {
        backButtonTitle = [NSString stringWithFormat:NSLocalizedString(@"bar_messages_x", nil), unread];
    } else {
        backButtonTitle = NSLocalizedString(@"messages", nil);
    }
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStylePlain target:nil action:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.title = NSLocalizedString(@"messages", nil);
        [[self navigationItem] setBackBarButtonItem:backButton];
    });
}

- (void)didReceiveMemoryWarning {
    DDLogWarn(@"Memory warning, removing cached chat view controllers");
    [ChatViewControllerCache clearCache];
    [super didReceiveMemoryWarning];
}

- (void)addressbookSyncronized:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [ChatViewControllerCache clearCache];
        [self.tableView reloadData];
    });
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (IBAction)newMessage:(id)sender {
    /* have user pick a Contact for the new message/conversation first */
    UINavigationController *contactPickerNavVc = [[self storyboard] instantiateViewControllerWithIdentifier:@"ContactPickerNav"];
    
    [self presentViewController:contactPickerNavVc animated:YES completion:nil];
}

- (void)setSelectionForConversation:(Conversation *)conversation {
    /* fix highlighted cell in our view */
    NSIndexPath *selectedRow = [self.tableView indexPathForSelectedRow];
    NSIndexPath *newRow = [self.fetchedResultsController indexPathForObject:conversation];
    
    DDLogInfo(@"selectedRow: %@, newRow: %@", selectedRow, newRow);
    
    if (![selectedRow isEqual:newRow]) {
        if (selectedRow != nil)
            [self.tableView deselectRowAtIndexPath:selectedRow animated:NO];
        if (newRow != nil)
            [self.tableView selectRowAtIndexPath:newRow animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)displayChat:(ChatViewController *)chatViewController animated:(BOOL)animated {
    [self setSelectionForConversation:chatViewController.conversation];
    if (self.navigationController.topViewController == chatViewController) {
        return;
    }
    
    if ([self.navigationController.viewControllers containsObject:chatViewController]) {
        if (self.navigationController.topViewController.presentedViewController) {
            return;
        }
        [self.navigationController popToViewController:chatViewController animated:animated];
        return;
    }
    
    [self.navigationController popToViewController:self animated:NO];
    [self.navigationController pushViewController:chatViewController animated:animated];
}

- (void)showConversationFor:(Contact*)contact overrideCompose:(BOOL)overrideCompose compose:(BOOL)compose defaultText:(NSString*)defaultText defaultImage:(UIImage *)defaultImage {
    
    UIViewController *topVc = [self.navigationController.viewControllers lastObject];
    if (topVc.presentedViewController != nil && ![topVc.presentedViewController isKindOfClass:[PortraitNavigationController class]])
        return; // modal view present and not passcode lock
    
}

-  (Conversation *)getFirstConversation {
    if ([self hasData]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        
        return [[self fetchedResultsController] objectAtIndexPath:indexPath];
    }
    
    return nil;
}

- (BOOL)hasData {
    if ([self.fetchedResultsController.sections count] > 0) {
        id<NSFetchedResultsSectionInfo> info = self.fetchedResultsController.sections[0];
        if ([info numberOfObjects] > 0) {
            return YES;
        }
    }
    
    return NO;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    
    if (editing) {
        UIBarButtonItem *deleteButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"delete_all", nil) style:UIBarButtonItemStylePlain target:self action:@selector(deleteAllAction:)];
        deleteButton.tintColor = [Colors red];
        composeButtonItem = self.navigationItem.rightBarButtonItem;
        self.navigationItem.rightBarButtonItem = deleteButton;
    } else {
        if (composeButtonItem) {
            self.navigationItem.rightBarButtonItem = composeButtonItem;
        }
    }
    isEditing = editing;
    
    [super setEditing:editing animated:animated];
}

- (void)deleteAllAction:(id)sender {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"conversations_delete_all_confirm", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            NSArray *conversations = [entityManager.entityFetcher allConversations];
            for (Conversation* conversation in conversations) {
                /* do not delete group conversations */
                if (conversation.groupId == nil)
                    [[entityManager entityDestroyer] deleteObjectWithObject:conversation];
            }
        }];
        
        self.editing = NO;
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }]];
    
    if (!self.tabBarController) {
        actionSheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
        actionSheet.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)deleteConversation:(Conversation*)conversation {
    if (conversation == nil)
        return;
    
    if ([conversation isGroup]) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
        [group adminDeleteGroup];
    }
    
    [MessageDraftStore deleteDraftForConversation:conversation];
    
    // Remove cached chat view controller for this conversation to avoid observer overload
    ChatViewController *oldController = [ChatViewControllerCache controllerForConversation:conversation];
    [oldController removeConversationObservers];
    [ChatViewControllerCache clearConversation:conversation];
    
    /* Remove from Core Data */
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        [[entityManager entityDestroyer] deleteObjectWithObject:conversation];
    }];
    
    [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeletedConversation object:nil userInfo:info];
}

- (void)showAlertToDeleteConversation:(Conversation *)conversation cellRect:(CGRect)cellRect {
    /* If this was a group conversation with members, ask for confirmation */
    GroupProxy *groupProxy = nil;
    BOOL isGroup = false;
    if (conversation.groupId != nil && conversation.members.count > 0) {
        groupProxy = [GroupProxy groupProxyForConversation:conversation];
        isGroup = true;
    }
    
    if (isGroup && [groupProxy didLeaveGroup] == false) {
        conversationToDelete = conversation;
        NSString *message;
        if (conversation.contact == nil) {
            message = NSLocalizedString(@"group_admin_delete_confirm", nil);
        } else {
            message = NSLocalizedString(@"group_delete_confirm", nil);
        }
        
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [self deleteConversation:conversationToDelete];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        }]];
                
        if (!self.tabBarController) {
            actionSheet.popoverPresentationController.sourceRect = cellRect;
            actionSheet.popoverPresentationController.sourceView = self.view;
        }
        [self presentViewController:actionSheet animated:YES completion:nil];
    } else {
        conversationToDelete = conversation;
        
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"conversation_delete_confirm", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [self deleteConversation:conversationToDelete];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        }]];
        
        if (!self.tabBarController) {
            actionSheet.popoverPresentationController.sourceRect = cellRect;
            actionSheet.popoverPresentationController.sourceView = self.view;
        }
        [self presentViewController:actionSheet animated:YES completion:nil];
    }
}

- (void)showAlertToLeaveGroup:(Conversation *)conversation cellRect:(CGRect)cellRect {
    /* If this was a group conversation with members, ask for confirmation */
    GroupProxy *groupProxy = nil;
    BOOL isGroup = false;
    if (conversation.groupId != nil) {
        groupProxy = [GroupProxy groupProxyForConversation:conversation];
        isGroup = true;
    }
    
    if (isGroup && [groupProxy isSelfMember] == true) {
        conversationToDelete = conversation;
        NSString *messageTitle = NSLocalizedString(@"leave_group", nil);
        NSString *message;
        if ([groupProxy isOwnGroup]) {
            message = [BundleUtil localizedStringForKey:@"group_admin_delete_confirm"];
        } else {
            message = [BundleUtil localizedStringForKey:@"group_delete_confirm"];
        }
        
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:messageTitle message:message preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"leave", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [groupProxy leaveGroup];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        }]];
                
        if (!self.tabBarController) {
            actionSheet.popoverPresentationController.sourceRect = cellRect;
            actionSheet.popoverPresentationController.sourceView = self.view;
        }
        [self presentViewController:actionSheet animated:YES completion:nil];
    }
}



#pragma mark - notification observer

- (void)refreshDirtyObjects:(NSNotification*)notification {
    NSManagedObjectID *objectID = [notification.userInfo objectForKey:kKeyObjectID];
    if (objectID && [objectID.entity.managedObjectClassName isEqualToString:@"Conversation"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshData];
        });
    }
}

- (void)updateDraftForCell:(NSNotification*)notification {
    ConversationCell *cell = [self.tableView cellForRowAtIndexPath:lastSelectedCell];
    if (cell)
        [cell updateLastMessagePreview];
    lastSelectedCell = self.tableView.indexPathForSelectedRow;
}

- (void)showProfilePictureChanged:(NSNotification*)notification {
    [self refresh];
}

- (void)reloadTableView:(NSNotification *)notification {
    if (viewLoadedInBackground == false) {
        [self.tableView reloadData];
    }
}


#pragma mark - Table view

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    //overwrite since conversation cells have custom UI
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ConversationCell";
    ConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    cell.conversation = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.delegate = self;
    cell.conversationCellDelegate = self;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // MGSwipeTableCell already handles "swipe left" deletion of single conversation cells,
    // so we need to avoid triggering edit mode by swiping two cells left in succession.
    return isEditing;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Conversation *conversation = [self.fetchedResultsController objectAtIndexPath:indexPath];
        CGRect cellRect = [tableView rectForRowAtIndexPath:indexPath];
        [self showAlertToDeleteConversation:conversation cellRect:cellRect];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!lastSelectedCell)
        lastSelectedCell = indexPath;
    
    Conversation *conversation = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return 0.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
    return 0.0;
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){
    UITableViewCell *contextCell = [tableView cellForRowAtIndexPath:indexPath];
    if ([contextCell isKindOfClass:[ConversationCell class]]) {
        ConversationCell *cell = (ConversationCell *)contextCell;
        ChatViewController *chatVc = [ChatViewControllerCache newControllerForConversation:cell.conversation forceTouch:YES];
        UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
            return chatVc;
        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            NSMutableArray *actionArray = [NSMutableArray new];
            
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                NSString *actionTitle = [BundleUtil localizedStringForKey:@"take_photo_or_video"];
                UIImage *actionImage = [[BundleUtil imageNamed:@"ActionCamera"] imageWithTintColor:[Colors fontNormal]];
                UIAction *action = [UIAction actionWithTitle:actionTitle image:actionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    ChatViewController *chatViewController = [ChatViewControllerCache controllerForConversation:chatVc.conversation];
                    [chatViewController showContentAfterForceTouch];
                    [self displayChat:chatViewController animated:YES];
                    SendMediaAction *sendMediaAction = [SendMediaAction actionForChatViewController:chatViewController];
                    sendMediaAction.mediaPickerType = MediaPickerTakePhoto;
                    [chatViewController setCurrentAction:sendMediaAction];
                    [sendMediaAction executeAction];
                }];
                [actionArray addObject:action];
            }
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
                NSString *actionTitle = [BundleUtil localizedStringForKey:@"choose_existing"];
                UIImage *actionImage = [[BundleUtil imageNamed:@"ActionPhoto"] imageWithTintColor:[Colors fontNormal]];
                UIAction *action = [UIAction actionWithTitle:actionTitle image:actionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    ChatViewController *chatViewController = [ChatViewControllerCache controllerForConversation:chatVc.conversation];
                    [chatViewController showContentAfterForceTouch];
                    [self displayChat:chatViewController animated:YES];
                    SendMediaAction *sendMediaAction = [SendMediaAction actionForChatViewController:chatViewController];
                    sendMediaAction.mediaPickerType = MediaPickerChooseExisting;
                    [chatViewController setCurrentAction:sendMediaAction];
                    [sendMediaAction executeAction];
                }];
                [actionArray addObject:action];
            }
            if ([CLLocationManager locationServicesEnabled]) {
                NSString *actionTitle = [BundleUtil localizedStringForKey:@"share_location"];
                UIImage *actionImage = [[BundleUtil imageNamed:@"ActionLocation"] imageWithTintColor:[Colors fontNormal]];
                UIAction *action = [UIAction actionWithTitle:actionTitle image:actionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    ChatViewController *chatViewController = [ChatViewControllerCache controllerForConversation:chatVc.conversation];
                    [chatViewController showContentAfterForceTouch];
                    [self displayChat:chatViewController animated:YES];
                    SendLocationAction *sendLocationAction = [SendLocationAction actionForChatViewController:chatViewController];
                    [chatViewController setCurrentAction:sendLocationAction];
                    [sendLocationAction executeAction];
                }];
                [actionArray addObject:action];
            }
            if ([PlayRecordAudioViewController canRecordAudio]) {
                NSString *actionTitle = [BundleUtil localizedStringForKey:@"record_audio"];
                UIImage *actionImage = [[BundleUtil imageNamed:@"ActionMicrophone"] imageWithTintColor:[Colors fontNormal]];
                UIAction *action = [UIAction actionWithTitle:actionTitle image:actionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    ChatViewController *chatViewController = [ChatViewControllerCache controllerForConversation:chatVc.conversation];
                    [chatViewController showContentAfterForceTouch];
                    [self displayChat:chatViewController animated:YES];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [chatViewController startRecordingAudio];
                    });
                }];
                [actionArray addObject:action];
            }
            
            NSString *ballotActionTitle = NSLocalizedStringFromTable(@"ballot_create", @"Ballot", nil);
            UIImage *ballotActionImage = [[BundleUtil imageNamed:@"ActionBallot"] imageWithTintColor:[Colors fontNormal]];
            UIAction *ballotAction = [UIAction actionWithTitle:ballotActionTitle image:ballotActionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                ChatViewController *chatViewController = [ChatViewControllerCache controllerForConversation:chatVc.conversation];
                [chatViewController showContentAfterForceTouch];
                [self displayChat:chatViewController animated:YES];
                [chatViewController createBallot];
            }];
            [actionArray addObject:ballotAction];
            
            NSString *shareActionTitle = [BundleUtil localizedStringForKey:@"share_file"];
            UIImage *shareActionImage = [[BundleUtil imageNamed:@"ActionFile"] imageWithTintColor:[Colors fontNormal]];
            UIAction *shareAction = [UIAction actionWithTitle:shareActionTitle image:shareActionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                ChatViewController *chatViewController = [ChatViewControllerCache controllerForConversation:chatVc.conversation];
                [chatViewController showContentAfterForceTouch];
                [self displayChat:chatViewController animated:YES];
                [chatViewController sendFile];
            }];
            [actionArray addObject:shareAction];
            
            return [UIMenu menuWithTitle:chatVc.conversation.displayName image:nil identifier:nil options:UIMenuOptionsDisplayInline children:actionArray];
        }];
        return conf;
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  API_AVAILABLE(ios(13.0)){
    ChatViewController *previewVc = (ChatViewController *)animator.previewViewController;
    
    ChatViewController *chatVc = [ChatViewControllerCache controllerForConversation:previewVc.conversation];
    [chatVc showContentAfterForceTouch];
    [animator addCompletion:^{
        [self displayChat:chatVc animated:YES];
    }];
}


#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    _fetchedResultsController = [entityManager.entityFetcher fetchedResultsControllerForConversations];
    _fetchedResultsController.delegate = self;
    
	NSError *error = nil;
	if (![_fetchedResultsController performFetch:&error]) {
	    DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];
	}
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    if (viewLoadedInBackground == false) {
        switch(type) {
            case NSFetchedResultsChangeInsert:
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
                
            case NSFetchedResultsChangeDelete:
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
                
            default:
                break;
        }
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    if (viewLoadedInBackground == false) {
        UITableView *tableView = self.tableView;
        
        switch(type) {
            case NSFetchedResultsChangeInsert:
                [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
                
            case NSFetchedResultsChangeDelete: {
                Conversation *conversation = anObject;
                [ChatViewControllerCache clearConversation:conversation];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
                
            case NSFetchedResultsChangeUpdate: {
                ConversationCell *cell = (ConversationCell*)[tableView cellForRowAtIndexPath:indexPath];
                Conversation *conversation = anObject;
                if ([anObject changedValues].count != 0) {
                    cell.conversation = conversation;
                }
                [cell refreshButtons:YES];
                break;
            }
                
            case NSFetchedResultsChangeMove:
                if ([indexPath isEqual:newIndexPath] == NO) {
                    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                    [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                break;
            default:
                break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

#pragma mark - UIViewControllerPreviewingDelegate

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    if ([viewControllerToCommit isKindOfClass:[ChatViewController class]]) {
        ChatViewController *previewVc = (ChatViewController *)viewControllerToCommit;
        
        ChatViewController *chatVc = [ChatViewControllerCache controllerForConversation:previewVc.conversation];
        [chatVc showContentAfterForceTouch];
        [self displayChat:chatVc animated:YES];
    }
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    
    UIView *view = [self.view hitTest:location withEvent:nil];
    if ([view.superview isKindOfClass:[ConversationCell class]]) {
        ConversationCell *cell = (ConversationCell *)view.superview;
        ChatViewController *chatVc = [ChatViewControllerCache newControllerForConversation:cell.conversation forceTouch:YES];
        chatVc.delegate = self;

        return chatVc;
    }
    
    return nil;
}

#pragma mark - GroupDetailsViewControllerDelegate

- (void)presentChatViewController:(ChatViewController *)chatViewController onCompletion:(ChatViewControllerCompletionBlock)onCompletion {
    
    _prevNavigationControllerDelegate = self.navigationController.delegate;
    self.navigationController.delegate = self;
    
    [chatViewController showContentAfterForceTouch];
    _chatViewCompletionBlock = onCompletion;
    [self displayChat:chatViewController animated:NO];
}

- (void)cancelSwipeGestureFromConversations {
    for (MGSwipeTableCell *cell in self.tableView.visibleCells) {
        if (cell.swipeState != MGSwipeStateNone) {
            [cell hideSwipeAnimated:true];
        }
    }
}

- (void)pushSettingChanged:(Conversation *)conversation {
    NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:conversation];
    if (indexPath != nil) {
        ConversationCell *cell = (ConversationCell*)[self.tableView cellForRowAtIndexPath:indexPath];
        cell.conversation = conversation;
        [cell refreshButtons:YES];
    }
}


#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    if (_chatViewCompletionBlock) {
        if ([viewController isKindOfClass:[ChatViewController class]]) {
            [((ChatViewController *)viewController) showContentAfterForceTouch];
            _chatViewCompletionBlock((ChatViewController *)viewController);
        }
        
        _chatViewCompletionBlock = nil;
    }
    
    
    self.navigationController.delegate = _prevNavigationControllerDelegate;
}

#pragma mark Swipe Delegate

-(BOOL)swipeTableCell:(MGSwipeTableCell*)cell canSwipe:(MGSwipeDirection)direction fromPoint:(CGPoint) point {
    if (UIAccessibilityIsVoiceOverRunning()) {
        return NO;
    }
    return YES;
}

-(NSArray*) swipeTableCell:(MGSwipeTableCell*) cell swipeButtonsForDirection:(MGSwipeDirection)direction swipeSettings:(MGSwipeSettings*) swipeSettings expansionSettings:(MGSwipeExpansionSettings*) expansionSettings {
    swipeSettings.transition = MGSwipeTransitionBorder;
    expansionSettings.buttonIndex = 0;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath != nil) {
        Conversation *conversation =  [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        if (direction == MGSwipeDirectionLeftToRight) {
            return [self swipeLeftToRightForTableCell:cell conversation:conversation swipeSettings:swipeSettings expansionSettings:expansionSettings];
        }
        else {
            return [self swipeRightToLeftForTableCell:cell conversation:conversation swipeSettings:swipeSettings];
        }
    }
    
    return nil;
}

- (NSArray *)swipeLeftToRightForTableCell:(MGSwipeTableCell *)cell conversation:(Conversation *)conversation swipeSettings:(MGSwipeSettings *)swipeSettings expansionSettings:(MGSwipeExpansionSettings *)expansionSettings {
    expansionSettings.fillOnTrigger = NO;
    expansionSettings.threshold = 1.5;
    swipeSettings.enableSwipeBounces = YES;
    __block NSString *buttonTitle;
    __block UIImage *buttonIcon;
    NSMutableArray *buttonArray = [NSMutableArray new];
    
    if (conversation.unreadMessageCount.intValue > 0) {
        NSString *readTitle = NSLocalizedString(@"read", @"");
        
        buttonTitle = NSLocalizedString(@"read", @"");
        buttonIcon = [UIImage imageNamed:@"MessageStatus_read" inColor:[UIColor whiteColor]];
        
        __block MGSwipeButton *read = [MGSwipeButton buttonWithTitle:buttonTitle icon:buttonIcon backgroundColor:[Colors workBlue] padding:10 callback:^BOOL(MGSwipeTableCell *sender) {
            [ConversationUtils unreadConversation:conversation];
            [cell refreshButtons:YES];
            [cell refreshContentView];
            return YES;
        }];
        
        CGRect readFrame = [readTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width/2, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName:read.titleLabel.font } context:nil];
        [read setButtonWidth:readFrame.size.width + 30.0];
        [read centerIconOverText];
        [buttonArray addObject:read];
    }
    
    NSString *markTitle = [conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]] ? NSLocalizedString(@"unpin", nil) : NSLocalizedString(@"pin", nil);
    UIImage *markImage = [conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]] ? [UIImage imageNamed:@"Unpin" inColor:[UIColor whiteColor]] : [UIImage imageNamed:@"Pin" inColor:[UIColor whiteColor]];
    
    __block MGSwipeButton *mark = [MGSwipeButton buttonWithTitle:markTitle icon:markImage backgroundColor:[Colors markTag] padding:10 callback:^BOOL(MGSwipeTableCell *sender) {
        if ([conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]]) {
            [ConversationUtils unmarkConversation:conversation];
        } else {
            [ConversationUtils markConversation:conversation];
        }
        [cell refreshButtons:YES];
        [cell refreshContentView];
        return YES;
    }];
    
    CGRect markFrame = [markTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width/2, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName:mark.titleLabel.font } context:nil];
    [mark setButtonWidth:markFrame.size.width + 30.0];
    [mark centerIconOverText];
    [buttonArray addObject:mark];
    
    return buttonArray;
}

- (NSArray *)swipeRightToLeftForTableCell:(MGSwipeTableCell *)cell conversation:(Conversation *)conversation swipeSettings:(MGSwipeSettings *)swipeSettings {
    swipeSettings.enableSwipeBounces = NO;
    
    MGSwipeButton *delete = [MGSwipeButton buttonWithTitle:NSLocalizedString(@"delete", @"") backgroundColor:[Colors red] padding:20 callback:^BOOL(MGSwipeTableCell *sender) {
        CGRect cellRect = [self.tableView convertRect:cell.frame toView:self.view];
        [self showAlertToDeleteConversation:conversation cellRect:cellRect];
        return NO;
    }];
    [delete centerIconOverText];
    MGSwipeButton *leaveGroup;
    if (conversation.isGroup) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
        if ([group isSelfMember]) {
            NSString *leaveGroupString = [BundleUtil localizedStringForKey:@"leave_group"];
            NSString *strSpace = @" ";

            NSRange range = [leaveGroupString rangeOfString:strSpace];
            if (NSNotFound != range.location) {
                 leaveGroupString = [leaveGroupString stringByReplacingCharactersInRange:range withString:@"\n"];
            }

            leaveGroup = [MGSwipeButton buttonWithTitle:leaveGroupString backgroundColor:[Colors orange] padding:20 callback:^BOOL(MGSwipeTableCell *sender) {
                CGRect cellRect = [self.tableView convertRect:cell.frame toView:self.view];
                [self showAlertToLeaveGroup:conversation cellRect:cellRect];
                return NO;
            }];
            [leaveGroup centerIconOverText];
        }
    }
    if (leaveGroup != nil) {
        return @[leaveGroup, delete];
    } else {
        return @[delete];
    }
}


#pragma mark - ConversationCellDelegate

- (void)voiceOverDeleteConversation:(ConversationCell *)cell {
    CGRect cellRect = [self.tableView convertRect:cell.frame toView:self.view];
    [self showAlertToDeleteConversation:cell.conversation cellRect:cellRect];
}

- (void)voiceOverLeaveGroup:(ConversationCell *)cell {
    CGRect cellRect = [self.tableView convertRect:cell.frame toView:self.view];
    [self showAlertToLeaveGroup:cell.conversation cellRect:cellRect];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (![LicenseStore requiresLicenseKey]) {
        if ([[self.navigationController navigationBar] frame].size.height < 60.0 && self.navigationItem.titleView != nil) {
            self.navigationItem.titleView = nil;
            self.navigationItem.title = NSLocalizedString(@"messages", nil);
        }
        else if ([[self.navigationController navigationBar] frame].size.height >= 59.5 && self.navigationItem.titleView == nil) {
            [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
        }
    }
}

@end
