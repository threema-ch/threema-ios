//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

import Foundation

protocol Enqueuable {
    associatedtype Element
    mutating func enqueue(_ element: Element)
    func peek() -> Element?
    mutating func dequeue() -> Element?
    mutating func removeAll()
}

struct Queue<T>: Enqueuable {
    typealias Element = T
    
    fileprivate var elements = [Element]()
    
    mutating func enqueue(_ element: Element) {
        elements.append(element)
    }
    
    func peek() -> Element? {
        elements.first
    }
    
    mutating func dequeue() -> Element? {
        guard elements.isEmpty == false else {
            return nil
        }
        return elements.removeFirst()
    }
    
    mutating func removeAll() {
        elements.removeAll()
    }
}

// MARK: - CustomStringConvertible

extension Queue: CustomStringConvertible {
    var description: String {
        "\(elements)"
    }
}

extension Queue {
    var list: [Element] {
        elements
    }
}
