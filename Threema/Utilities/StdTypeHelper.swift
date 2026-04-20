import Foundation

extension Double {
    // Create a double from an optional string
    public init?(_ value: String?) {
        guard let value else {
            return nil
        }
        self.init(value)
    }
}

extension String {
    // Extract a character from a string
    // Example: "foo"[1] == "o"
    subscript(i: Int) -> Character {
        self[index(startIndex, offsetBy: i)]
    }
}
