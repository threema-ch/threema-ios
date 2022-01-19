//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import "TestUtil.h"
#import "ServerConnector.h"

@implementation TestUtil

+ (void)switchToTestServer {
    ServerConnector *serverConnector = [ServerConnector sharedServerConnector];
    [serverConnector disconnectWait];
    
    NSArray *ports = @[[NSNumber numberWithInt: 1984]];
    [serverConnector setServerPorts: ports];
    [serverConnector connect];
}

+ (NSURL *)urlToTestResource:(NSString *)filename extension:(NSString *)ending {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle URLForResource: filename withExtension: ending];
}

+ (NSData *)dataFromTestFile:(NSString *)filename extension:(NSString *)ending {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [testBundle URLForResource: filename withExtension: ending];
    
    NSError *error;
    NSString *stringData = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error: &error];
    
    //strip newlines
    NSString *jsonstring = [stringData stringByReplacingOccurrencesOfString:@"\n" withString:@""];

    return [jsonstring dataUsingEncoding: NSUTF8StringEncoding];
}

+ (NSString *)jsonDataToString:(NSData *)data {
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return stringData;
}

@end
