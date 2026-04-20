import SwiftUI

struct PositionedInCoordinateSpace: ViewModifier {
    let targetPosition: CGPoint
    let coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            // Get the frame of the named coordinate space in global coordinates
            let targetFrame = geometry.frame(in: coordinateSpace)
            // Get the frame of the parent container in global coordinates
            let parentFrame = geometry.frame(in: .global)
            
            // Adjust for the difference between the target and parent frames
            let adjustedPosition = CGPoint(
                x: targetPosition.x - parentFrame.minX + targetFrame.minX,
                y: targetPosition.y - parentFrame.minY + targetFrame.minY
            )

            content
                .position(adjustedPosition)
        }
    }
}

extension View {
    func position(in coordinateSpace: CoordinateSpace, at point: CGPoint) -> some View {
        modifier(PositionedInCoordinateSpace(targetPosition: point, coordinateSpace: coordinateSpace))
    }
}
