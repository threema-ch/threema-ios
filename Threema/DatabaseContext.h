//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface DatabaseContext : NSObject

/**
 Main context, it's static
 */
@property (strong, nonatomic) NSManagedObjectContext *main;

/**
 Working context, could be private or main context
 */
@property (strong, nonatomic) NSManagedObjectContext *current;

- (instancetype)init NS_UNAVAILABLE;

/**
 Database contexts for persistent coordinator. Importent: use current context (could be main or private context).
 
 @param persistentCoordinator   see DatabaseManager
 @param forBackgroundProcess    YES means it will be create a private context
 */
- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator forBackgroundProcess:(BOOL)forBackgroundProcess;

@end

