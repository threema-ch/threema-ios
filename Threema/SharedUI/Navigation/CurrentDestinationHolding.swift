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

protocol CurrentDestinationHolding<CurrentDestination>: AnyObject {
    associatedtype CurrentDestination
    
    var currentDestination: CurrentDestination? { get set }
    
    func resetCurrentDestination()
}

extension CurrentDestinationHolding {
    func resetCurrentDestination() {
        currentDestination = nil
    }
    
    func eraseToAnyDestinationHolder() -> AnyCurrentDestinationHolder<CurrentDestination> {
        AnyCurrentDestinationHolder(self)
    }
}

final class AnyCurrentDestinationHolder<Destination>: CurrentDestinationHolding {
    typealias CurrentDestination = Destination
    
    private let box: any CurrentDestinationHolding<Destination>
    
    var currentDestination: Destination? {
        get { box.currentDestination }
        set { box.currentDestination = newValue }
    }
    
    init<T: CurrentDestinationHolding>(_ holder: T) where T.CurrentDestination == Destination {
        self.box = WeakCurrentDestinationHolderBox(holder)
    }
    
    func resetCurrentDestination() {
        box.resetCurrentDestination()
    }
}

private final class WeakCurrentDestinationHolderBox<
    T: CurrentDestinationHolding
>: CurrentDestinationHolding {
    typealias Destination = T.CurrentDestination
    
    var currentDestination: T.CurrentDestination? {
        get {
            holder?.currentDestination
        }
        set {
            holder?.currentDestination = newValue
        }
    }
    
    weak var holder: T?
    
    init(_ holder: T) {
        self.holder = holder
    }
    
    func resetCurrentDestination() {
        holder?.resetCurrentDestination()
    }
}
