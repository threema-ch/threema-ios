//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

import Combine
import Foundation

// RelayState was copied from CombineX (https://github.com/cx-org/CombineX) by Quentin Jin. It is licensed under the MIT
// License.
//
//
// MIT License
//
// Copyright (c) 2019 Quentin Jin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

enum CombineXRelayState {
    
    case waiting
    
    case relaying(Subscription)
    
    case completed
}

extension CombineXRelayState {
    
    var isWaiting: Bool {
        switch self {
        case .waiting: true
        default: false
        }
    }
    
    var isRelaying: Bool {
        switch self {
        case .relaying: true
        default: false
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .completed: true
        default: false
        }
    }
    
    var subscription: Subscription? {
        switch self {
        case let .relaying(s): s
        default: nil
        }
    }
}

extension CombineXRelayState {
    
    mutating func relay(_ subscription: Subscription) -> Bool {
        guard isWaiting else {
            return false
        }
        self = .relaying(subscription)
        return true
    }
    
    mutating func complete() -> Subscription? {
        defer {
            self = .completed
        }
        return subscription
    }
}
