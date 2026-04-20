import SwiftUI

struct VariableRoundedCornerRectangle: Shape {
    var radius: CGFloat
    var cornerToLeaveSquare: UIRectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var corners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        corners.remove(cornerToLeaveSquare)
        
        let roundedRectPath = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        
        path.addPath(Path(roundedRectPath.cgPath))
        return path
    }
}
