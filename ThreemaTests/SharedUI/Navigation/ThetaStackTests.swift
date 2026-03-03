//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import Testing
import Threema
import UIKit

@Suite("ThetaStack Tests")
@MainActor
struct ThetaStackTests {
    
    // MARK: - Basic Storage and Retrieval Tests
    
    @Test("Store and restore empty stack")
    func storeAndRestoreEmptyStack() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.contacts
        let emptyStack: [UIViewController] = []
        
        thetaStack.store(stack: emptyStack, for: tabIdentifier)
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        
        #expect(retrievedStack.isEmpty)
        #expect(retrievedStack.isEmpty)
    }
    
    @Test("Store and restore single view controller")
    func storeAndRestoreSingleViewController() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.contacts
        let viewController = UIViewController()
        let stack = [viewController]
        
        thetaStack.store(stack: stack, for: tabIdentifier)
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        
        #expect(retrievedStack.count == 1)
        #expect(retrievedStack[0] === viewController)
    }
    
    @Test("Store and restore multiple view controllers")
    func storeAndRestoreMultipleViewControllers() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.conversations
        let viewController1 = UIViewController()
        let viewController2 = UIViewController()
        let viewController3 = UIViewController()
        let stack = [viewController1, viewController2, viewController3]
        
        thetaStack.store(stack: stack, for: tabIdentifier)
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        
        #expect(retrievedStack.count == 3)
        #expect(retrievedStack[0] === viewController1)
        #expect(retrievedStack[1] === viewController2)
        #expect(retrievedStack[2] === viewController3)
    }
    
    // MARK: - Multiple Index Tests
    
    @Test("Store different stacks for different indices")
    func storeDifferentStacksForDifferentIndices() {
        let thetaStack = ThetaStack()
        let tab1 = ThreemaTabBarController.TabBarItem.contacts
        let tab2 = ThreemaTabBarController.TabBarItem.conversations
        let tab3 = ThreemaTabBarController.TabBarItem.profile
        
        let stack1 = [UIViewController()]
        let stack2 = [UIViewController(), UIViewController()]
        let stack3 = [UIViewController(), UIViewController(), UIViewController()]
        
        thetaStack.store(stack: stack1, for: tab1)
        thetaStack.store(stack: stack2, for: tab2)
        thetaStack.store(stack: stack3, for: tab3)
        
        let retrievedStack1 = thetaStack.restore(for: tab1)
        let retrievedStack2 = thetaStack.restore(for: tab2)
        let retrievedStack3 = thetaStack.restore(for: tab3)
        
        #expect(retrievedStack1.count == 1)
        #expect(retrievedStack2.count == 2)
        #expect(retrievedStack3.count == 3)
        
        #expect(retrievedStack1[0] === stack1[0])
        #expect(retrievedStack2[0] === stack2[0])
        #expect(retrievedStack2[1] === stack2[1])
    }
    
    @Test("Independent storage for different indices")
    func independentStorageForDifferentIndices() {
        let thetaStack = ThetaStack()
        let tab1 = ThreemaTabBarController.TabBarItem.contacts
        let tab2 = ThreemaTabBarController.TabBarItem.conversations
        let viewController1 = UIViewController()
        let viewController2 = UIViewController()
        
        thetaStack.store(stack: [viewController1], for: tab1)
        thetaStack.store(stack: [viewController2], for: tab2)
        
        let retrievedStack1 = thetaStack.restore(for: tab1)
        let retrievedStack2 = thetaStack.restore(for: tab2)
        
        #expect(retrievedStack1[0] !== retrievedStack2[0])
        #expect(retrievedStack1[0] === viewController1)
        #expect(retrievedStack2[0] === viewController2)
    }
    
    // MARK: - Overwrite Tests
    
    @Test("Overwrite existing stack")
    func overwriteExistingStack() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.contacts
        let originalStack = [UIViewController(), UIViewController()]
        let newStack = [UIViewController()]
        
        thetaStack.store(stack: originalStack, for: tabIdentifier)
        thetaStack.store(stack: newStack, for: tabIdentifier)
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        
        #expect(retrievedStack.count == 1)
        #expect(retrievedStack[0] === newStack[0])
    }
    
    @Test("Overwrite with empty stack")
    func overwriteWithEmptyStack() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.contacts
        let originalStack = [UIViewController(), UIViewController()]
        let emptyStack: [UIViewController] = []
        
        thetaStack.store(stack: originalStack, for: tabIdentifier)
        thetaStack.store(stack: emptyStack, for: tabIdentifier)
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        
        #expect(retrievedStack.isEmpty)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("View controller retention")
    func viewControllerRetention() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.contacts
        var viewController: UIViewController? = UIViewController()
        weak var weakReference = viewController
        
        thetaStack.store(stack: [viewController!], for: tabIdentifier)
        viewController = nil // Release our strong reference
        
        #expect(weakReference != nil) // View controller should be retained by ThetaStack
        
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        #expect(retrievedStack.count == 1)
        #expect(weakReference != nil) // View controller should still be retained
    }
    
    @Test("View controller release after overwrite")
    func viewControllerReleaseAfterOverwrite() {
        let thetaStack = ThetaStack()
        let tabIdentifier = ThreemaTabBarController.TabBarItem.contacts
        var originalViewController: UIViewController? = UIViewController()
        weak var weakReference = originalViewController
        let newViewController = UIViewController()
        
        thetaStack.store(stack: [originalViewController!], for: tabIdentifier)
        originalViewController = nil // Release our strong reference
        
        #expect(weakReference != nil) // Original view controller should be retained by ThetaStack
        
        // Overwrite with new stack
        thetaStack.store(stack: [newViewController], for: tabIdentifier)
        
        #expect(weakReference == nil) // Original view controller should be released after overwrite
        
        let retrievedStack = thetaStack.restore(for: tabIdentifier)
        #expect(retrievedStack.count == 1)
        #expect(retrievedStack[0] === newViewController)
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test("Tab bar controller scenario")
    func ThreemaTabBarControllerScenario() {
        let thetaStack = ThetaStack()
        let tab1 = ThreemaTabBarController.TabBarItem.contacts
        let tab2 = ThreemaTabBarController.TabBarItem.profile
        let tab3 = ThreemaTabBarController.TabBarItem.settings
        
        // Tab 1: Contacts -> Profile
        let contactsVC = UIViewController()
        let profileVC = UIViewController()
        let tab1Stack = [contactsVC, profileVC]
        
        // Tab 2: Settings only
        let settingsVC = UIViewController()
        let tab2Stack = [settingsVC]
        
        // Tab 3: Empty (no navigation)
        let tab3Stack: [UIViewController] = []
        
        thetaStack.store(stack: tab1Stack, for: tab1)
        thetaStack.store(stack: tab2Stack, for: tab2)
        thetaStack.store(stack: tab3Stack, for: tab3)
        
        let retrievedTab1 = thetaStack.restore(for: tab1)
        let retrievedTab2 = thetaStack.restore(for: tab2)
        let retrievedTab3 = thetaStack.restore(for: tab3)
        
        #expect(retrievedTab1.count == 2)
        #expect(retrievedTab2.count == 1)
        #expect(retrievedTab3.isEmpty)
        
        #expect(retrievedTab1[0] === contactsVC)
        #expect(retrievedTab1[1] === profileVC)
        #expect(retrievedTab2[0] === settingsVC)
    }
    
    @Test("Split view controller scenario")
    func splitViewControllerScenario() {
        // Simulate split view with detail navigation
        let thetaStack = ThetaStack()
        let detailTab = ThreemaTabBarController.TabBarItem.contacts
        
        // Detail navigation: List -> Detail -> Edit
        let listVC = UIViewController()
        let detailVC = UIViewController()
        let editVC = UIViewController()
        let detailStack = [listVC, detailVC, editVC]
        
        thetaStack.store(stack: detailStack, for: detailTab)
        
        // Simulate collapse - store current state
        let storedStack = thetaStack.restore(for: detailTab)
        
        // Clear for compact mode
        thetaStack.store(stack: [], for: detailTab)
        
        // Simulate expand - restore state
        thetaStack.store(stack: storedStack, for: detailTab)
        
        let finalStack = thetaStack.restore(for: detailTab)
        
        #expect(finalStack.count == 3)
        #expect(finalStack[0] === listVC)
        #expect(finalStack[1] === detailVC)
        #expect(finalStack[2] === editVC)
    }
}
