//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

#import <XCTest/XCTest.h>
#import "AudioTrackAnalyzer.h"

#define TEST_FILE @"audioAnalyzerTest"
#define TEST_FILE_EXTENSION @"m4a"


@interface AudioTrackAnalyzerTests : XCTestCase

@end

@implementation AudioTrackAnalyzerTests

/// Should handle nil file
- (void)testNilFile {
    NSURL *file;
    
    AudioTrackAnalyzer *analyzer = [AudioTrackAnalyzer audioTrackAnalyzerFor: file];
    
    NSTimeInterval duration = [analyzer getDuration];
    XCTAssert(duration == 0.0);
    
    NSArray *result = [analyzer reduceAudioToDecibelLevels: 20];
    XCTAssert([result count] == 0);
}

/// Should handle test file
- (void)testAudioFile {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSURL *file = [testBundle URLForResource:TEST_FILE withExtension:TEST_FILE_EXTENSION];

    AudioTrackAnalyzer *analyzer = [AudioTrackAnalyzer audioTrackAnalyzerFor: file];
    
    NSTimeInterval duration = [analyzer getDuration];
    XCTAssert(duration < 3.85 + 0.01);
    XCTAssert(duration > 3.85 - 0.01);

    NSArray *result = [analyzer reduceAudioToDecibelLevels: 100];
    // for some odd reason we do are not able to get all audio data from the given audio file
    XCTAssert([result count] <  100 + 3);
    XCTAssert([result count] > 100 - 3);
}

@end
