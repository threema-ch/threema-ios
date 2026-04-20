import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension NSArray {
    @objc func chunked(into size: Int) -> NSArray {
        let arr = Array(self)
        return NSArray(array: arr.chunked(into: size))
    }
}
