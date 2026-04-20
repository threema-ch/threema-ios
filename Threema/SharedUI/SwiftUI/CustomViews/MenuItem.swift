import Foundation

protocol MenuItem: Identifiable, Hashable, CaseIterable {
    var label: String { get }
    var icon: ThreemaImageResource { get }
    var enabled: Bool { get }
    var accessibilityLabel: String? { get }
}
