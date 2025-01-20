//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2025 Threema GmbH
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

#import "SenderItemManager.h"
#import "URLSenderItem.h"
#import "UTIConverter.h"
#import "Conversation.h"
#import "BundleUtil.h"
#import "MessageSender.h"
#import "TextMessage.h"
#import "DatabaseManager.h"
#import "MediaConverter.h"
#import "FileMessageSender.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface IntermediateItem : NSObject

@property NSItemProvider *itemProvider;
@property NSString *type;
@property NSString *secondType;
@property NSString *caption;

@end

@implementation IntermediateItem


@end

@interface SenderItemManager () <UploadProgressDelegate>

@property NSSet *recipientConversations;
@property NSMutableSet *itemsToSend;
@property NSString *textToSend;

@property NSInteger sentItemCount;
@property NSInteger totalSendCount;

@property NSMutableArray *correlationIDs;

@property dispatch_semaphore_t loadItemsSema;

@end

@implementation SenderItemManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _itemsToSend = [NSMutableSet set];
        _containsFileItem = NO;
        _shouldCancel = NO;
        _sendAsFile = false;
        _loadItemsSema = dispatch_semaphore_create(0);
    }
    return self;
}

- (NSUInteger)itemCount {
    NSUInteger count = _itemsToSend.count;
    if (_textToSend.length > 0 && ![self canSendCaptions]) {
        count++;
    }
    
    return count;
}

- (BOOL)isFileItem:(IntermediateItem *)item {
    if ([UTIConverter type:item.type conformsTo:UTTYPE_AUDIO]) {
        return NO;
    } else if ([UTIConverter type:item.type conformsTo:UTTYPE_PLAIN_TEXT]) {
        return NO;
    } else if ([UTIConverter type:item.type conformsTo:UTTYPE_URL]) {
        return NO;
    }
    
    return YES;
}


- (void)addItem:(NSItemProvider *)itemProvider forType:(NSString *)type secondType:(NSString *)secondType {
    IntermediateItem *item = [IntermediateItem new];
    item.itemProvider = itemProvider;
    item.type = type;
    item.secondType = secondType;
    
    [_itemsToSend addObject:item];
    
    if ([self isFileItem:item]) {
        _containsFileItem = YES;
    }
    
}

- (void)addText:(NSString *)text {
    _textToSend = text;
}

- (void)sendItemsTo:(NSSet *)conversations {
    _recipientConversations = conversations;
    NSInteger count = [conversations count] * self.itemCount;
    _totalSendCount = count;
    _sentItemCount = 0;

    _correlationIDs = [[NSMutableArray alloc] initWithCapacity:conversations.count];
    
    for (int i = 0; i < conversations.count; i++) {
        _correlationIDs[i] = [ImageURLSenderItemCreator createCorrelationID];
    }
    
    if (_textToSend.length > 0) {
        if ([self canSendCaptions]) {
            IntermediateItem *anyItem = [_itemsToSend anyObject];
            anyItem.caption = _textToSend;
        } else {
            for (Conversation *conversation in _recipientConversations) {
                if (_shouldCancel) {
                    return;
                }
                
                [self sendItem:_textToSend toConversation:conversation correlationID:nil];
            }
        }
    }

    dispatch_queue_t dispatchQueue = dispatch_queue_create("ch.threema.LoadItemsForShareExtension", NULL);
    dispatch_async(dispatchQueue, ^{
        for (IntermediateItem *intermediateItem in _itemsToSend) {
            [self loadAndSendItem:intermediateItem];
        }
    });
}

- (void)loadAndSendItem:(IntermediateItem *)intermediateItem {
    NSString *type = intermediateItem.type;
    if ([type isEqualToString:@"com.apple.live-photo"]) {
        type = intermediateItem.secondType;
    }
    if ([type isEqualToString:@"com.apple.avfoundation.urlasset"]) {
            type = intermediateItem.secondType;
    }
    
    [intermediateItem.itemProvider loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError *error) {
        if (error == nil && _shouldCancel == NO) {
            id senderItem = [self loadSenderItem:item ofType:intermediateItem.type secondType:intermediateItem.secondType];
            if (senderItem == nil) {
                return;
            }
            if (intermediateItem.caption && [senderItem isKindOfClass:[URLSenderItem class]]) {
                ((URLSenderItem*)senderItem).caption = intermediateItem.caption;
            }
            
            NSArray *recipients = [_recipientConversations allObjects];
            for (int i = 0; i < _recipientConversations.count; i++) {
                if (_shouldCancel) {
                    return;
                }
                [self sendItem:senderItem toConversation:recipients[i] correlationID:_correlationIDs[i]];
            }
        }
    }];
    dispatch_semaphore_wait(_loadItemsSema, DISPATCH_TIME_FOREVER);
}

- (BOOL)canSendCaptionInline {
    if (_itemsToSend.count == 1) {
        IntermediateItem *anyItem = [_itemsToSend anyObject];
        if ([UTIConverter type:anyItem.type conformsTo:UTTYPE_GIF_IMAGE]) {
            return NO;
        }
        if ([UTIConverter type:anyItem.type conformsTo:UTTYPE_IMAGE]) {
            // Only one image, so we can send the text as an inline caption
            return YES;
        }
    }
    return NO;
}

- (BOOL)canSendCaptions {
    if (_itemsToSend.count == 1) {
        return [self canSendCaptionInline];
    }
    return false;
}

- (id)loadSenderItem:item ofType:(NSString *)type secondType:(NSString *)secondType {
    if ([item isKindOfClass:[NSURL class]]) {
        if (secondType != nil) {
            return [self prepareUrlItem:item forType:secondType];
        }
        return [self prepareUrlItem:item forType:type];
    } else if ([item isKindOfClass:[NSData class]]) {
        return [self prepareDataItem:item forType:type];
    } else if ([item isKindOfClass:[NSString class]]) {
        return item;
    } else if ([item isKindOfClass:[UIImage class]]) {
        return [self prepareImageItem:item forType:type];
    }
    else {
        NSString *title = NSLocalizedString(@"error_message_no_items_title", nil);
        NSString *message = NSLocalizedString(@"error_message_no_items_message", nil);
        [_delegate showAlertWithTitle:title message:message];
        
        return nil;
    }
}

- (void)sendItem:(id)senderItem toConversation:(Conversation *)conversation correlationID:(NSString *)correlationID {
    if ([senderItem isKindOfClass:[URLSenderItem class]]) {
        FileMessageSender *sender = [[FileMessageSender alloc] init];
        [sender sendItem:senderItem inConversation:conversation requestId:nil correlationId:correlationID];
        sender.uploadProgressDelegate = self;
    } else  if ([senderItem isKindOfClass:[NSString class]]) {
        NSString *message = (NSString *)senderItem;
        if (message && message.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate setProgress:[NSNumber numberWithFloat:0.1] forItem:[self progressItemKey:message conversation:conversation]];
                [MessageSender sendMessage:message inConversation:conversation quickReply:NO requestId:nil onCompletion:^(BaseMessage *message) {
                    if ([message isKindOfClass:[TextMessage class]]) {
                        TextMessage *textMsg = (TextMessage *)message;
                        
                        [_delegate finishedItem:[self progressItemKey:textMsg.text conversation:textMsg.conversation]];
                        
                        [[DatabaseManager dbManager] addDirtyObject:textMsg.conversation];
                        [[DatabaseManager dbManager] addDirtyObject:textMsg.conversation.lastMessage];
                        
                        _sentItemCount++;
                        [self checkIsFinished];
                    }
                }];
            });
        }
        else {
            // increment sent count for unknown types
            [_delegate finishedItem:[self progressItemKey:message conversation:conversation]];
            _sentItemCount++;
            [self checkIsFinished];
        }
    }
    else {
        NSString *title = NSLocalizedString(@"error_message_no_items_title", nil);
        NSString *message = NSLocalizedString(@"error_message_no_items_message", nil);
        [_delegate showAlertWithTitle:title message:message];
        
        // increment sent count for unknown types
        _sentItemCount++;
        [self checkIsFinished];
    }
}

- (void)awaitAckForMessageId:(NSData *)messageId {
    EntityManager *entityManager = [[EntityManager alloc] init];
    BaseMessage *message = [entityManager.entityFetcher ownMessageWithId:messageId];
    
    [message addObserver:self forKeyPath:@"sent" options:0 context:nil];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass:[TextMessage class]]) {
        TextMessage *message = (TextMessage *)object;
        
        [_delegate finishedItem:[self progressItemKey:message.text conversation:message.conversation]];
        
        [message removeObserver:self forKeyPath:@"sent"];
        
        [[DatabaseManager dbManager] addDirtyObject:message.conversation];
        [[DatabaseManager dbManager] addDirtyObject:message.conversation.lastMessage];
        
        dispatch_semaphore_signal(_loadItemsSema);
        
        _sentItemCount++;
        [self checkIsFinished];
    }
}

- (id)progressItemKey:(id)item conversation:(Conversation *)conversation {
    NSInteger hash = [item hash] + [conversation hash];
    return [NSNumber numberWithInteger: hash];
}

- (NSString *)renderHtmlToText:(NSString *)htmlString {
    NSString *editedHtmlString = [htmlString stringByReplacingOccurrencesOfString:@"\n" withString:@"\</br>"];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithData:[editedHtmlString dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)} documentAttributes:nil error:nil];
    
    if (attributedString != nil) {
        return [attributedString string];
    }
    
    return htmlString;
}

- (URLSenderItem *)prepareImageItem:(id<NSSecureCoding>)item forType:(NSString *)type {
    UIImage *image = (UIImage *)item;
    ImageURLSenderItemCreator *creator = [[ImageURLSenderItemCreator alloc] initWith:@"large" forceSize:false];
    return [creator senderItemFromImage:image];
}

- (URLSenderItem *)prepareDataItem:(id<NSSecureCoding>)item forType:(NSString *)type {
    NSData *data = (NSData *)item;
    NSString *uti = [UTIConverter utiFromMimeType:type];
    if ([UTIConverter conformsToImageType:uti]) {
        ImageURLSenderItemCreator *creator = [[ImageURLSenderItemCreator alloc] init];
        return [creator senderItemFrom:data uti:uti];
    } else if ([UTIConverter conformsToMovieType:uti]) {
        VideoURLSenderItemCreator *creator = [[VideoURLSenderItemCreator alloc] init];
        NSURL *url = [VideoURLSenderItemCreator writeToTemporaryDirectoryWithData:data];
        if (url == nil) {
            DDLogError(@"Could not create URLSenderItem from media asset");
            return nil;
        }
        return [creator senderItemFrom:url];
    }
    return [URLSenderItem itemWithData:data fileName:nil type:type renderType:@0 sendAsFile:_sendAsFile];
}

- (id)prepareUrlItem:(id<NSSecureCoding>)item forType:(NSString *)type {
    NSURL *url = (NSURL *)item;
    
    if (url == nil) {
        return false;
    }
    
    if ([url.scheme isEqualToString:@"file"]) {
        URLSenderItem *senderItem = [URLSenderItemCreator getSenderItemFor:url maxSize:@"large"];
        
        if ([self checkFileConstraints:senderItem]) {
            return senderItem;
        }
    } else {
        return url.absoluteString;
    }
    
    return nil;
}

- (BOOL)checkFileConstraints:(URLSenderItem *)senderItem {
    NSString *errorTitle;
    NSString *errorMessage;
    
    if ([UTIConverter type:senderItem.type conformsTo:UTTYPE_MOVIE]) {
        if ([MediaConverter isVideoDurationValidAtUrl:senderItem.url] == NO) {
            errorTitle = [BundleUtil localizedStringForKey:@"video_too_long_title"];
            errorMessage = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"video_too_long_message"], [MediaConverter videoMaxDurationAtCurrentQuality]];
        }
    } else {
        NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:senderItem.url.path error:nil];
        if ([fileDictionary fileSize] > kMaxFileSize) {
            errorTitle = [BundleUtil localizedStringForKey:@"error_constraints_failed"];
            errorMessage = [FileMessageSender messageForError:UploadErrorFileTooBig];
        }
    }
    
    if (errorMessage) {
        // cancel everything in case of error
        _shouldCancel = YES;
        
        [_delegate showAlertWithTitle:errorTitle message:errorMessage];
        
        return NO;
    }
    
    return YES;
}

- (void)checkIsFinished {
    if (_sentItemCount == _totalSendCount) {
        // delay finish slightly since DB safe of ack might not have finished yet
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [_delegate setFinished];
        });
    }
}

#pragma mark - UploadProgressDelegate

- (BOOL)blobMessageSenderUploadShouldCancel:(BlobMessageSender *)blobMessageSender {
    return _shouldCancel;
}

- (void)blobMessageSender:(BlobMessageSender *)blobMessageSender uploadProgress:(NSNumber *)progress forMessage:(BaseMessage *)message {
    [_delegate setProgress:progress forItem:message.id];
}

- (void)blobMessageSender:(BlobMessageSender *)blobMessageSender uploadSucceededForMessage:(BaseMessage *)message {
    dispatch_semaphore_signal(_loadItemsSema);
    _sentItemCount++;
    [_delegate finishedItem:message.id];
    
    [[DatabaseManager dbManager] addDirtyObject:message.conversation];
    [[DatabaseManager dbManager] addDirtyObject:message];
    
    [self checkIsFinished];
}

- (void)blobMessageSender:(BlobMessageSender *)blobMessageSender uploadFailedForMessage:(BaseMessage *)message error:(UploadError)error {
    dispatch_semaphore_signal(_loadItemsSema);
    _sentItemCount++;
    
    NSString *errorTitle = [BundleUtil localizedStringForKey:@"error_sending_failed"];
    NSString *errorMessage = [FileMessageSender messageForError:error];
    [_delegate showAlertWithTitle:errorTitle message:errorMessage];
    
    if (error == UploadErrorSendFailed) {
        [[DatabaseManager dbManager] addDirtyObject:message.conversation];
        [[DatabaseManager dbManager] addDirtyObject:message];
    }
}

@end
