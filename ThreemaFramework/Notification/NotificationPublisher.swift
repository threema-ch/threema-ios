//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

public typealias AnyNotificationPublisher<Value> = AnyPublisher<Value, Never>

/// This Wrapper makes it possible to take any notification and observe its publisher for new values.
///
/// There are two main things that happen here:
/// 1. Using a `CurrentValueSubject` to store the value
///     This is needed as a classic publisher might fire before it has any subscribers receiving the published value.
/// 2. Storing the published state via `hasBeenSent` to make sure the the value gets only published once and gets
///     "deleted" after at least one subscriber received it.
///     This is achieved via setting the `hasBeenSent` to false on the publisher and true on the subject. Also we need
///     to map the subject to an Empty Publisher once `hasBeenSent` is set to true.
///     Without this, the subscribers of the subjects publisher would receive a never ending stream of the same value.
@propertyWrapper
public class NotificationPublisher<Value> {
    
    private var hasBeenSent = false
    private var cancellables = Set<AnyCancellable>()
    private var subject = CurrentValueSubject<Value?, Never>(nil)
    
    public var wrappedValue: AnyNotificationPublisher<Value> {
        subject
            .flatMap { [weak self] value -> AnyNotificationPublisher<Value> in
                guard let value, !(self?.hasBeenSent ?? true) else {
                    return Empty<Value, Never>().eraseToAnyPublisher()
                }
                return Just(value).eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.hasBeenSent = true
            })
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public init(_ name: Notification.Name, on scheduler: some Scheduler = RunLoop.main)
        where Value == NotificationCenter.Publisher.Output {
        NotificationCenter.default.publisher(for: name)
            .receive(on: scheduler)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.hasBeenSent = false
            })
            .sink { [weak self] in
                self?.subject.send($0)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
}
