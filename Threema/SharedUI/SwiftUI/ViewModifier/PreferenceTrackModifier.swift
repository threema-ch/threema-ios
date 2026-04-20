import SwiftUI

struct TrackedFrame: Equatable {
    let id: String
    let frame: CGRect
    let data: Any?
    var proxy: GeometryProxy? = nil

    static func == (lhs: TrackedFrame, rhs: TrackedFrame) -> Bool {
        lhs.id == rhs.id && lhs.frame == rhs.frame
    }
}

// MARK: - TrackedFrame.Key

extension TrackedFrame {
    struct Key: PreferenceKey {
        typealias Value = [TrackedFrame]

        static var defaultValue: [TrackedFrame] = []

        static func reduce(value: inout [TrackedFrame], nextValue: () -> [TrackedFrame]) {
            value.append(contentsOf: nextValue())
        }
    }
}

struct PreferenceTrackModifier: ViewModifier {
    let id: String
    let coordinateSpace: CoordinateSpace?
    let data: Any?
    
    func body(content: Content) -> some View {
        content.background(
            content: {
                GeometryReader { proxy in
                    Color.clear.transformPreference(TrackedFrame.Key.self) {
                        $0.append(
                            .init(
                                id: id,
                                frame: proxy.frame(in: coordinateSpace ?? .global),
                                data: data,
                                proxy: proxy
                            )
                        )
                    }
                }
            }
        )
    }
}

extension View {
    public func trackPreference(
        _ id: String,
        coordinateSpace: CoordinateSpace? = .global,
        data: Any? = nil
    ) -> some View {
        modifier(
            PreferenceTrackModifier(
                id: id,
                coordinateSpace: coordinateSpace,
                data: data
            )
        )
    }
}
