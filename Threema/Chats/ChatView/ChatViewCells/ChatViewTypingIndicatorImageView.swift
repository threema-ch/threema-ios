//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

/// Animated image showing the dots
class ChatViewTypingIndicatorImageView: UIImageView {
    private typealias Config = ChatViewConfiguration.TypingIndicator.Animation
    
    // MARK: - Properties
    
    /// Rectangle in which the animated circles should be drawn.
    var drawFrame: CGRect? {
        didSet {
            guard drawFrame != oldValue else {
                return
            }
            
            guard let drawFrame else {
                return
            }
            
            guard drawFrame.width > 0.0, drawFrame.height > 0.0 else {
                return
            }
            
            Task {
                image = await updateImage(for: drawFrame)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private lazy var animationColors: [UIColor] = {
        var grays = [UIColor]()
        
        let min = Config.minimumWhiteValue
        let max = Config.maximumWhiteValue
        let diff = max - min
        
        for i in 0..<(Int(Config.totalFrames) + 1) {
            let val = min + diff * Double(i) / Config.totalFrames
            let color = UIColor(white: val, alpha: 1.0)
            grays.append(color)
        }
        
        let rev: [UIColor] = grays.reversed()
        let midArray = [UIColor](repeating: rev[0], count: Int(Config.totalFrames) + 1)
        
        return grays + midArray + rev
    }()
    
    // MARK: - Lifecycle
    
    init() {
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Update Functions
    
    func updateColors() {
        Task {
            guard let drawFrame else {
                return
            }
            
            guard drawFrame.width > 0, drawFrame.height > 0 else {
                return
            }
            /// This is required to run on the main actor which in turn means that this task will also run on the main
            /// actor which limits its usefulness.
            image = await updateImage(for: drawFrame)
        }
    }
    
    // MARK: - Private Helper Functions
    
    private func updateImage(for frame: CGRect) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var animationFrames = [UIImage?]()
            for i in 0..<animationColors.count {
                animationFrames.append(typingIndicatorImage(forAnimationFrame: i, in: frame))
            }
            let image = UIImage.animatedImage(
                with: animationFrames.compactMap { $0 },
                duration: Config.animationDuration
            )
            continuation.resume(returning: image)
        }
    }
    
    private func typingIndicatorImage(forAnimationFrame animationFrame: Int = 0, in frame: CGRect) -> UIImage? {
        let index1 = (animationFrame + Config.offset1).quotientAndRemainder(dividingBy: animationColors.count).remainder
        let index2 = (animationFrame + Config.offset2).quotientAndRemainder(dividingBy: animationColors.count).remainder
        let index3 = (animationFrame + Config.offset3).quotientAndRemainder(dividingBy: animationColors.count).remainder
        
        return drawTypingIndicatorImage(
            leftColor: animationColors[index1],
            middleColor: animationColors[index2],
            rightColor: animationColors[index3],
            frame: frame
        )
    }
    
    private func drawTypingIndicatorImage(
        leftColor: UIColor,
        middleColor: UIColor,
        rightColor: UIColor,
        frame: CGRect
    ) -> UIImage? {
        guard frame.width > 0, frame.height > 0 else {
            assertionFailure()
            return nil
        }
        let imageRenderer = UIGraphicsImageRenderer(size: frame.size)
        
        return imageRenderer.image(actions: { context in
            drawTypingIndicator(
                frame: frame,
                context: context,
                leftBubbleColor: leftColor,
                middleBubbleColor: middleColor,
                rightBubbleColor: rightColor
            )
        })
    }
    
    private func drawTypingIndicator(
        frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 32, height: 8),
        context: UIGraphicsImageRendererContext,
        leftBubbleColor: UIColor,
        middleBubbleColor: UIColor,
        rightBubbleColor: UIColor
    ) {
        // Resize to Target Frame
        let resizedFrame: CGRect = StyleKit.ResizingBehavior.aspectFit.apply(
            rect: CGRect(x: 0, y: 0, width: 32, height: 8),
            target: targetFrame
        )
        context.cgContext.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
        context.cgContext.scaleBy(x: resizedFrame.width / 32, y: resizedFrame.height / 8)
        
        // Typing Animated Circles
        // Oval 5 Drawing
        let oval5Path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 8, height: 8))
        leftBubbleColor.setFill()
        oval5Path.fill()
        
        // Oval 6 Drawing
        let oval6Path = UIBezierPath(ovalIn: CGRect(x: 12, y: 0, width: 8, height: 8))
        middleBubbleColor.setFill()
        oval6Path.fill()
        
        // Oval 7 Drawing
        let oval7Path = UIBezierPath(ovalIn: CGRect(x: 24, y: 0, width: 8, height: 8))
        rightBubbleColor.setFill()
        oval7Path.fill()
    }
}
