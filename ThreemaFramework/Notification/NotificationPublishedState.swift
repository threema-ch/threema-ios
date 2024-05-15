//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

@propertyWrapper
public class NotificationPublishedState<Value> {
    
    private var cancellables = Set<AnyCancellable>()
    private var subject = CurrentValueSubject<Value?, Never>(nil)

    public var wrappedValue: AnyNotificationPublisher<Value> {
        subject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public init(_ name: Notification.Name, on scheduler: some Scheduler = RunLoop.main)
        where Value == NotificationCenter.Publisher.Output {
        NotificationCenter.default.publisher(for: name)
            .receive(on: scheduler)
            .sink { [weak self] in
                self?.subject.send($0)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
}
