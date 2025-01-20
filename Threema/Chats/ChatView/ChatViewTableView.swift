//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

protocol ChatViewTableViewDelegate: AnyObject {
    func willMove(toWindow newWindow: UIWindow?)
    
    var willMoveToNonNilWindow: Bool { get set }
}

class ChatViewTableView: DebugTableView {
    /// This is the actual contentOffset that super is set to
    private var internalContentOffset: CGPoint = .zero
    
    weak var chatViewDelegate: ChatViewTableViewDelegate?
    
    /// See `contentOffset` for how this is used
    /// If you forget to unlock this you won't be able to scroll and new messages won't show up.
    /// Make sure you are sure that this is always unlocked.
    /// May only be used from the main thread and only if `overrideDefaultTableViewBehavior` is enabled
    var lockContentOffset = false {
        didSet {
            assert(Thread.isMainThread)
        }
    }
    
    /// We override `contentOffset` and allow users to lock the value to something specific
    /// This is used to make sure that `UITableView` internals don't set the `contentOffset` to something weird
    /// before we didn't run `didApplySnapshot(delegateScrollCompletion:)` and updates
    // This lead to crashes in iOS17 Beta 5
//    override var contentOffset: CGPoint {
//        set {
//            super.contentOffset = newValue
//        }
//        get {
//            super.contentOffset
//        }
//    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        chatViewDelegate?.willMoveToNonNilWindow = false
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        
        DDLogVerbose("\(#function) \(String(describing: newWindow))")
        
        /// Part of the workaround for the passcode lock screen.
        /// Chat view controller receives the correct willEnterForeground callback but isn't actually in the foreground
        /// because it is hidden by the pass code lock. The pass code lock works essentially by replacing the main
        /// window with itself. This sets view.window to nil in chat view controller.
        /// We use this to determine whether chat view controller is actually visible and if not, delay jumping to the
        /// unread message line until we are visible i.e. have a non-nil window again.
        /// Additionally we do not mark messages as read when passcode lock is hiding the chat view.
        
        chatViewDelegate?.willMoveToNonNilWindow = newWindow != nil
            
        chatViewDelegate?.willMove(toWindow: window)
    }
}
