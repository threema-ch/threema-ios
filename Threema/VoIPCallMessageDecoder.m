//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2020 Threema GmbH
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

#import "VoIPCallMessageDecoder.h"
#import <WebRTC/RTCSessionDescription.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation VoIPCallMessageDecoder

#pragma mark - Public functions

+ (instancetype)messageDecoder {
    VoIPCallMessageDecoder *decoder = [[VoIPCallMessageDecoder alloc] init];
        
    return decoder;
}

- (VoIPCallOfferMessage *)decodeVoIPCallOfferFromBox:(BoxVoIPCallOfferMessage *)boxMessage {
    return [self decodeVoIPCallOfferMessage:boxMessage];
}

- (VoIPCallAnswerMessage *)decodeVoIPCallAnswerFromBox:(BoxVoIPCallAnswerMessage *)boxMessage {
    return [self decodeVoIPCallAnswerMessage:boxMessage];
}

- (VoIPCallHangupMessage *)decodeVoIPCallHangupFromBox:(BoxVoIPCallHangupMessage *)boxMessage contact:(Contact *)contact {
    return [self decodeVoIPCallHangupMessage:boxMessage contact:contact];
}

- (VoIPCallRingingMessage *)decodeVoIPCallRingingFromBox:(BoxVoIPCallRingingMessage *)boxMessage contact:(Contact *)contact {
    return [self decodeVoIPCallRingingMessage:boxMessage contact:contact];
}


- (VoIPCallIceCandidatesMessage *)decodeVoIPCallIceCandidatesFromBox:(BoxVoIPCallIceCandidatesMessage *)boxMessage {
    return [self decodeVoIPCallIceCandidates:boxMessage];
}


#pragma mark - Private functions

- (VoIPCallOfferMessage *)decodeVoIPCallOfferMessage:(AbstractMessage *)boxMessage {
    
    NSData *jsonData;
    if ([boxMessage isKindOfClass:[BoxVoIPCallOfferMessage class]]) {
        jsonData = ((BoxVoIPCallAnswerMessage *)boxMessage).jsonData;
    } else {
        DDLogError(@"VoIP call decode: invalid message type");
        return nil;
    }
    
    VoIPCallOfferMessage *message = [self parseJsonVoIPCallOfferMessage:jsonData];
    return message;
}


- (VoIPCallAnswerMessage *)decodeVoIPCallAnswerMessage:(AbstractMessage *)boxMessage {
    
    NSData *jsonData;
    if ([boxMessage isKindOfClass:[BoxVoIPCallAnswerMessage class]]) {
        jsonData = ((BoxVoIPCallAnswerMessage *)boxMessage).jsonData;
    } else {
        DDLogError(@"VoIP call decode: invalid message type");
        return nil;
    }
    
    VoIPCallAnswerMessage *message = [self parseJsonVoIPCallAnswerMessage:jsonData];
    return message;
}

- (VoIPCallHangupMessage *)decodeVoIPCallHangupMessage:(AbstractMessage *)boxMessage contact:(Contact *)contact {
    
    NSData *jsonData;
    if ([boxMessage isKindOfClass:[BoxVoIPCallHangupMessage class]]) {
        jsonData = ((BoxVoIPCallHangupMessage *)boxMessage).jsonData;
    } else {
        DDLogError(@"VoIP call decode: invalid message type");
        return nil;
    }
    
    VoIPCallHangupMessage *message = [self parseJsonVoIPCallHangupMessage:jsonData contact:contact];
    return message;
}

- (VoIPCallRingingMessage *)decodeVoIPCallRingingMessage:(AbstractMessage *)boxMessage contact:(Contact *)contact {
    
    NSData *jsonData;
    if ([boxMessage isKindOfClass:[BoxVoIPCallRingingMessage class]]) {
        jsonData = ((BoxVoIPCallRingingMessage *)boxMessage).jsonData;
    } else {
        DDLogError(@"VoIP call decode: invalid message type");
        return nil;
    }
    
    VoIPCallRingingMessage *message = [self parseJsonVoIPCallRingingMessage:jsonData contact:contact];
    return message;
}

- (VoIPCallIceCandidatesMessage *)decodeVoIPCallIceCandidates:(AbstractMessage *)boxMessage {
    NSData *jsonData;
    if ([boxMessage isKindOfClass:[BoxVoIPCallIceCandidatesMessage class]]) {
        jsonData = ((BoxVoIPCallIceCandidatesMessage *)boxMessage).jsonData;
    } else {
        DDLogError(@"VoIP call decode: invalid message type");
        return nil;
    }
    
    VoIPCallIceCandidatesMessage *message = [self parseJsonVoIPCallIceCandidatesMessage:jsonData];
    return message;
}

- (VoIPCallAnswerMessage *)parseJsonVoIPCallAnswerMessage:(NSData *)jsonData {
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        DDLogError(@"Error parsing ballot json data %@, %@", error, [error userInfo]);
        return nil;
    }
    
    VoIPCallAnswerMessage *message = [VoIPCallAnswerMessage answerFromJSONDictionary:json];
    return message;
}

- (VoIPCallHangupMessage *)parseJsonVoIPCallHangupMessage:(NSData *)jsonData contact:(Contact *)contact {
    if (jsonData.bytes == 0) {
        return [VoIPCallHangupMessage hangupFromJSONDictionary:nil contact:contact];
    }
    
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        DDLogError(@"Error parsing ballot json data %@, %@", error, [error userInfo]);
        return nil;
    }
    
    VoIPCallHangupMessage *message = [VoIPCallHangupMessage hangupFromJSONDictionary:json contact:contact];
    return message;
}

- (VoIPCallRingingMessage *)parseJsonVoIPCallRingingMessage:(NSData *)jsonData contact:(Contact *)contact {
    if (jsonData.bytes == 0) {
        return [VoIPCallRingingMessage ringingFromJSONDictionary:nil contact:contact];
    }
    
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        DDLogError(@"Error parsing ballot json data %@, %@", error, [error userInfo]);
        return nil;
    }
    
    VoIPCallRingingMessage *message = [VoIPCallRingingMessage ringingFromJSONDictionary:json contact:contact];
    return message;
}

- (VoIPCallOfferMessage *)parseJsonVoIPCallOfferMessage:(NSData *)jsonData {
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        DDLogError(@"Error parsing ballot json data %@, %@", error, [error userInfo]);
        return nil;
    }
    
    VoIPCallOfferMessage *message = [VoIPCallOfferMessage offerFromJSONDictionary:json];
    return message;
}

- (VoIPCallIceCandidatesMessage *)parseJsonVoIPCallIceCandidatesMessage:(NSData *)jsonData {
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        DDLogError(@"Error parsing ballot json data %@, %@", error, [error userInfo]);
        return nil;
    }
    
    VoIPCallIceCandidatesMessage *message = [VoIPCallIceCandidatesMessage iceCandidatesWithDictionary:json];
    return message;
}

@end
