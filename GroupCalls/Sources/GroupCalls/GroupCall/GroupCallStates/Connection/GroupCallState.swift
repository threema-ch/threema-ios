import Foundation

protocol GroupCallState: Sendable {
    func next() async throws -> GroupCallState?
}
