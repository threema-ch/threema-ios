//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

struct DarwinNotificationName: Equatable, Hashable {
    private let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    fileprivate var cfNotificationName: CFNotificationName {
        CFNotificationName(rawValue as CFString)
    }
}

/// Post and receive Darwin Notifications.
final class DarwinNotificationCenter {

    static var shared = DarwinNotificationCenter()

    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    private var handlers: [DarwinNotificationName: (DarwinNotificationName) -> Void]?

    private let handlersQueue = DispatchQueue(label: "ch.threema.DarwinNotificationCenter.handlersQueue")

    private init() {
        // no-op
    }

    deinit {
        guard let handlers, !handlers.isEmpty else {
            return
        }

        for name in handlers.keys {
            removeObserver(name: name)
        }
    }

    func addObserver(name: DarwinNotificationName, handler: @escaping (DarwinNotificationName) -> Void) {
        removeObserver(name: name)

        handlersQueue.sync {
            if handlers == nil {
                handlers = [:]
            }
            handlers?[name] = handler

            addObserver(name.cfNotificationName)
        }
    }

    func removeObserver(name: DarwinNotificationName) {
        handlersQueue.sync {
            guard var handlers, handlers.keys.contains(name) else {
                return
            }
            handlers.removeValue(forKey: name)

            removeObserver(name.cfNotificationName)
        }
    }

    func post(_ name: DarwinNotificationName) {
        CFNotificationCenterPostNotification(notificationCenter, name.cfNotificationName, nil, nil, true)
    }

    private func addObserver(_ name: CFNotificationName) {
        let callback: CFNotificationCallback = { _, observer, notificationName, _, _ in
            guard let observer, let notificationName else {
                DDLogWarn("[Darwin] Received notification name is nil")
                return
            }

            // Extract pointer to `self` from void pointer:
            let mySelf = Unmanaged<DarwinNotificationCenter>.fromOpaque(observer).takeUnretainedValue()

            let darwinNotificationName = DarwinNotificationName(notificationName.rawValue as String)
            mySelf.notificationCallbackHandler(darwinNotificationName)
        }

        // Void pointer to `self`:
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(notificationCenter, observer, callback, name.rawValue, nil, .coalesce)
    }

    private func removeObserver(_ name: CFNotificationName) {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(notificationCenter, observer, name, nil)
    }

    private func notificationCallbackHandler(_ name: DarwinNotificationName) {
        handlersQueue.sync {
            self.handlers?[name]?(name)
        }
    }
}
