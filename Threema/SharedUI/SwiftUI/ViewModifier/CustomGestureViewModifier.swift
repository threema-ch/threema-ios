//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import SwiftUI
import UIKit

struct CustomGestureViewModifier: ViewModifier {
    var configuration: LongPressView.CustomLongPressView.Configuration
    
    func body(content: Content) -> some View {
        ZStack {
            content
            LongPressView(configuration: configuration)
        }
    }
}

// MARK: - CustomGestureViewModifier.LongPressView

extension CustomGestureViewModifier {
    struct LongPressView: UIViewRepresentable {
        var configuration: CustomLongPressView.Configuration
        
        func makeUIView(context: Context) -> CustomLongPressView {
            let view = CustomLongPressView()
            view.configuration = configuration
            view.setupGesture()
            view.backgroundColor = .clear
            return view
        }

        func updateUIView(_ uiView: CustomLongPressView, context: Context) { }
    }
}

extension View {
    typealias CustomGestureConfiguration = CustomGestureViewModifier.LongPressView.CustomLongPressView.Configuration
    
    func onLongPress(
        minimumDuration: TimeInterval,
        isEnabled: Bool = true,
        _ onLongPress: @escaping () -> Void,
        onTouchesBegan: CustomGestureConfiguration.TouchesAction? = nil,
        onTouchesEnded: CustomGestureConfiguration.TouchesAction? = nil,
        onTouchesMoved: CustomGestureConfiguration.TouchesAction? = nil
    ) -> some View {
        modifier(
            CustomGestureViewModifier(
                configuration: .init(
                    minimumDuration: minimumDuration,
                    isEnabled: isEnabled,
                    onLongPress: onLongPress,
                    onTouchesBegan: onTouchesBegan,
                    onTouchesEnded: onTouchesEnded,
                    onTouchesMoved: onTouchesMoved
                )
            )
        )
    }
    
    func onLongPress(
        minimumDuration: TimeInterval,
        coordinateSpace: CustomGestureConfiguration.CoordinateSpace = .global,
        isEnabled: Bool = true,
        _ onLongPress: @escaping () -> Void,
        onTouchesBegan: CustomGestureConfiguration.TapAction? = nil,
        onTouchesEnded: CustomGestureConfiguration.TapAction? = nil,
        onTouchesMoved: CustomGestureConfiguration.TapAction? = nil
    ) -> some View {
        modifier(
            CustomGestureViewModifier(
                configuration: .init(
                    minimumDuration: minimumDuration,
                    coordinateSpace: coordinateSpace,
                    isEnabled: isEnabled,
                    onLongPress: onLongPress,
                    onTouchesBegan: onTouchesBegan,
                    onTouchesEnded: onTouchesEnded,
                    onTouchesMoved: onTouchesMoved
                )
            )
        )
    }
}

// MARK: - CustomGestureViewModifier.LongPressView.CustomLongPressView

extension CustomGestureViewModifier.LongPressView {
    class CustomLongPressView: UIView {
        struct Configuration {
            typealias TapAction = (_ location: CGPoint) -> Void
            typealias TouchesAction = (Set<UITouch>, UIEvent?) -> Void
            
            enum CoordinateSpace {
                case global, local
            }
            
            var minimumDuration: TimeInterval
            var coordinateSpace: CoordinateSpace?
            var onLongPress: () -> Void
            var onTouchesBegan: TouchesAction?
            var onTouchesEnded: TouchesAction?
            var onTouchesMoved: TouchesAction?
            var isEnabled: Bool
            weak var target: UIView?
            
            init(
                minimumDuration: TimeInterval,
                isEnabled: Bool,
                onLongPress: @escaping () -> Void,
                onTouchesBegan: TouchesAction? = nil,
                onTouchesEnded: TouchesAction? = nil,
                onTouchesMoved: TouchesAction? = nil
            ) {
                self.minimumDuration = minimumDuration
                self.coordinateSpace = nil
                self.isEnabled = isEnabled
                self.onLongPress = onLongPress
                self.onTouchesBegan = onTouchesBegan
                self.onTouchesEnded = onTouchesEnded
                self.onTouchesMoved = onTouchesMoved
            }
            
            init(
                minimumDuration: TimeInterval,
                coordinateSpace: CoordinateSpace,
                isEnabled: Bool,
                onLongPress: @escaping () -> Void,
                onTouchesBegan: TapAction? = nil,
                onTouchesEnded: TapAction? = nil,
                onTouchesMoved: TapAction? = nil
            ) {
                self.minimumDuration = minimumDuration
                self.coordinateSpace = coordinateSpace
                self.isEnabled = isEnabled
                self.onLongPress = onLongPress
                self.onTouchesBegan = actionModifier(coordinateSpace: coordinateSpace, perform: onTouchesBegan)
                self.onTouchesEnded = actionModifier(coordinateSpace: coordinateSpace, perform: onTouchesEnded)
                self.onTouchesMoved = actionModifier(coordinateSpace: coordinateSpace, perform: onTouchesMoved)
            }
            
            private func actionModifier(
                coordinateSpace: CoordinateSpace,
                perform action: TapAction?
            ) -> TouchesAction? {
                guard let action
                else {
                    return nil
                }
                
                return { touches, _ in
                    guard let touch = touches.first else {
                        return
                    }
                    var location: CGPoint? = nil
                    switch coordinateSpace {
                    case .global:
                        if let vc = AppDelegate.shared().currentTopViewController() {
                            location = touch.location(in: vc.view)
                        }
                        
                    case .local:
                        if let target {
                            location = touch.location(in: target)
                        }
                    }
                    
                    if let location {
                        action(location)
                    }
                }
            }
        }
        
        var configuration: Configuration?
        
        init(_ configuration: Configuration) {
            self.configuration = configuration
            super.init(frame: .zero)
            self.configuration?.target = self
        }
        
        func setupGesture() {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            longPressGesture.minimumPressDuration = configuration?.minimumDuration ?? 0.5
            if configuration?.isEnabled ?? false {
                addGestureRecognizer(longPressGesture)
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            configuration?.onTouchesBegan?(touches, event)
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            configuration?.onTouchesEnded?(touches, event)
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesMoved(touches, with: event)
            configuration?.onTouchesMoved?(touches, event)
        }
        
        @objc private func handleLongPress() {
            configuration?.onLongPress()
        }
    }
}
