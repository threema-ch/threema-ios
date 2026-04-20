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
    
    /// Remove all elements that match the provided predicate
    /// - Parameter clause: Predicate checked for each element
    /// - Returns: Removed elements. An empty array if none was removed
    mutating func removeAll(where clause: (Element) -> Bool) -> [Element] {
        var removeIndexSet = IndexSet()
        var removedElements = [Element]()
        
        for (index, element) in elements.enumerated() {
            guard clause(element) else {
                continue
            }
        
            let (inserted, _) = removeIndexSet.insert(index)
            assert(inserted, "Never insert duplicate indexes")
            
            removedElements.append(element)
        }
        
        elements.remove(atOffsets: removeIndexSet)
        
        return removedElements
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
