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

import Foundation
import os

// MARK: - Lock Protocol for abstraction

protocol AtomicLocking: Sendable {
    func lockNow()
    func unlockNow()
}

// MARK: - Lock wrapper for modern Swift concurrency

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class UnfairLockWrapper: AtomicLocking, @unchecked Sendable {
    private let unfairLock: UnsafeMutablePointer<os_unfair_lock>
    
    init() {
        self.unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        unfairLock.deallocate()
    }
    
    @inline(__always)
    func lockNow() {
        os_unfair_lock_lock(unfairLock)
    }
    
    @inline(__always)
    func unlockNow() {
        os_unfair_lock_unlock(unfairLock)
    }
}

// MARK: - Single Unified Atomic Wrapper with Optimized Locking

@propertyWrapper
public final class Atomic<Value>: @unchecked Sendable {
    private let lock: AtomicLocking
    private var value: Value
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
        self.lock = UnfairLockWrapper()
    }
    
    public var wrappedValue: Value {
        get { withLock { value } }
        set { withLock { value = newValue } }
    }
    
    // Dynamic projected value based on type
    public var projectedValue: AtomicProxy<Value> {
        AtomicProxy(atomic: self)
    }
    
    @inline(__always)
    private func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock.lockNow()
        defer { lock.unlockNow() }
        return try body()
    }
    
    fileprivate func mutate<R>(_ transform: (inout Value) throws -> R) rethrows -> R {
        try withLock { try transform(&value) }
    }
}

// MARK: - Universal Proxy that adapts to type

public struct AtomicProxy<Value>: @unchecked Sendable {
    private let atomic: Atomic<Value>
    
    init(atomic: Atomic<Value>) {
        self.atomic = atomic
    }
    
    // Callable for any custom mutations
    @discardableResult
    public func callAsFunction<R>(_ transform: (inout Value) throws -> R) rethrows -> R {
        try atomic.mutate(transform)
    }
}

// MARK: - Array-specific extensions

extension AtomicProxy where Value: RangeReplaceableCollection {
    public func append(_ element: Value.Element) {
        atomic.mutate { $0.append(element) }
    }
    
    public func append(contentsOf elements: some Sequence<Value.Element>) {
        atomic.mutate { $0.append(contentsOf: elements) }
    }
    
    public func removeAll() {
        atomic.mutate { $0.removeAll() }
    }
    
    public func removeAll(where shouldRemove: (Value.Element) -> Bool) {
        atomic.mutate { $0.removeAll(where: shouldRemove) }
    }
}

extension AtomicProxy where Value: RangeReplaceableCollection & BidirectionalCollection {
    @discardableResult
    public func removeLast() -> Value.Element? {
        atomic.mutate { $0.isEmpty ? nil : $0.removeLast() }
    }
}

extension AtomicProxy where Value: RangeReplaceableCollection, Value.Index == Int {
    @discardableResult
    public func remove(at index: Int) -> Value.Element? {
        atomic.mutate {
            guard index < $0.count else {
                return nil
            }
            return $0.remove(at: index)
        }
    }
}

// MARK: - Set-specific extensions

extension AtomicProxy where Value: SetAlgebra {
    @discardableResult
    public func insert(_ member: Value.Element) -> (inserted: Bool, memberAfterInsert: Value.Element) {
        atomic.mutate { $0.insert(member) }
    }
    
    @discardableResult
    public func remove(_ member: Value.Element) -> Value.Element? {
        atomic.mutate { $0.remove(member) }
    }
    
    public func formUnion(_ other: Value) {
        atomic.mutate { $0.formUnion(other) }
    }
    
    public func formIntersection(_ other: Value) {
        atomic.mutate { $0.formIntersection(other) }
    }
}

// MARK: - Dictionary-specific extensions

extension AtomicProxy {
    // Method-based dictionary operations
    public func setValue<K, V>(_ value: V?, forKey key: K) where Value == [K: V] {
        atomic.mutate { $0[key] = value }
    }
    
    public func removeValue<K, V>(forKey key: K) where Value == [K: V] {
        atomic.mutate { _ = $0.removeValue(forKey: key) }
    }
    
    public func merge<K, V>(_ other: [K: V], uniquingKeysWith combine: (V, V) -> V) where Value == [K: V] {
        atomic.mutate { $0.merge(other, uniquingKeysWith: combine) }
    }
    
    // Read-only subscript for getting values
    public subscript<K, V>(key: K) -> V? where Value == [K: V] {
        atomic.wrappedValue[key]
    }
    
    // Alternative: Use a custom setter syntax with function call
    public func set<K, V>(_ key: K, _ value: V?) where Value == [K: V] {
        atomic.mutate { $0[key] = value }
    }
    
    public func removeAll<K, V>() where Value == [K: V] {
        atomic.mutate { $0.removeAll() }
    }
}

// MARK: - Numeric extensions

extension AtomicProxy where Value: AdditiveArithmetic {
    @discardableResult
    public func increment(by amount: Value = 1) -> Value where Value: ExpressibleByIntegerLiteral {
        atomic.mutate {
            $0 += amount
            return $0
        }
    }
    
    @discardableResult
    public func decrement(by amount: Value = 1) -> Value where Value: ExpressibleByIntegerLiteral {
        atomic.mutate {
            $0 -= amount
            return $0
        }
    }
    
    // Operators as methods
    public static func += (lhs: AtomicProxy, rhs: Value) {
        lhs.atomic.mutate { $0 += rhs }
    }
    
    public static func -= (lhs: AtomicProxy, rhs: Value) {
        lhs.atomic.mutate { $0 -= rhs }
    }
}

extension AtomicProxy where Value: Numeric {
    public static func *= (lhs: AtomicProxy, rhs: Value) {
        lhs.atomic.mutate { $0 *= rhs }
    }
}

// MARK: - Bool extensions

extension AtomicProxy where Value == Bool {
    public func toggle() {
        atomic.mutate { $0.toggle() }
    }
    
    public func set(_ value: Bool) {
        atomic.mutate { $0 = value }
    }
    
    @discardableResult
    public func setTrue() -> Bool {
        atomic.mutate {
            let wasTrue = $0
            $0 = true
            return wasTrue
        }
    }
    
    @discardableResult
    public func setFalse() -> Bool {
        atomic.mutate {
            let wasTrue = $0
            $0 = false
            return wasTrue
        }
    }
    
    @discardableResult
    public func getAndSet(_ value: Bool) -> Bool {
        atomic.mutate {
            let oldValue = $0
            $0 = value
            return oldValue
        }
    }
    
    // Conditional operations
    public func setTrueIf(_ condition: Bool) {
        if condition {
            atomic.mutate { $0 = true }
        }
    }
    
    public func setFalseIf(_ condition: Bool) {
        if condition {
            atomic.mutate { $0 = false }
        }
    }
}

// MARK: - String extensions

extension AtomicProxy where Value == String {
    public func append(_ string: String) {
        atomic.mutate { $0.append(string) }
    }
    
    public func append(contentsOf string: some StringProtocol) {
        atomic.mutate { $0.append(contentsOf: string) }
    }
    
    public func removeAll() {
        atomic.mutate { $0.removeAll() }
    }
}

// MARK: - Optional extensions

extension AtomicProxy where Value: ExpressibleByNilLiteral {
    public func setNil() {
        atomic.mutate { $0 = nil }
    }
}

extension AtomicProxy {
    // Generic getter for computed properties
    public func get<T>(_ keyPath: KeyPath<Value, T>) -> T {
        atomic.wrappedValue[keyPath: keyPath]
    }
    
    // Generic setter for writable properties
    public func set<T>(_ keyPath: WritableKeyPath<Value, T>, to value: T) {
        atomic.mutate { $0[keyPath: keyPath] = value }
    }
}
