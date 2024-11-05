//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2024 Threema GmbH
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

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

@interface AppTestDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppTestDelegate
@end

int main(int argc, char *argv[])
{    
    __strong Class appDelegate;
    
#ifdef DEBUG
    if (argc > 1 && [[NSString stringWithUTF8String:argv[1]] isEqualToString:@"-isRunningForTests"]) {
        appDelegate = [AppTestDelegate class];
    } else {
        appDelegate = [AppDelegate class];
    }
#else
    appDelegate = [AppDelegate class];
#endif

    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(appDelegate));
    }
}
