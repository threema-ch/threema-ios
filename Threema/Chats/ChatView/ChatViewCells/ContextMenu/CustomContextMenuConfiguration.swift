import Foundation

enum CustomContextMenuConfiguration {
    enum Layout {
        static let verticalSpacing = 12.0
        static let leadingTrailingInset = 8.0
    }
    
    enum Animation {
        static let transformUp = CGAffineTransform(scaleX: 1.1, y: 1.1)
        static let transformDown = CGAffineTransform(scaleX: 0.9, y: 0.9)
        static let duration: TimeInterval = 0.4
        static let delay: TimeInterval = 0.0
    }
    
    enum SnapshotView {
        static let shadowRadius: CGFloat =
            if #available(iOS 26.0, *) {
                30.0
            }
            else {
                12.0
            }

        static let shadowOffset = CGSize(width: 0, height: 4)
        static let shadowColor = UIColor.black
        static let shadowOpacity: Float = 0.3
    }
}
