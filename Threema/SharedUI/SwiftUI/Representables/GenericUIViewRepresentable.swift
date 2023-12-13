//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import ThreemaFramework

extension UIView {
    struct WrapperView<V: UIView>: UIViewRepresentable {
        typealias CreateView = () -> V
        
        private let makeUIView: CreateView
        
        init(makeUIView: @escaping CreateView) {
            self.makeUIView = makeUIView
        }
        
        func makeUIView(context: Context) -> V {
            makeUIView()
        }
        
        func updateUIView(_ uiView: V, context: Context) { }
    }
    
    struct SelfSizingWrappedView: View {
        @State private var targetSize: CGSize = .zero
        
        let content: () -> UIView

        var body: some View {
            ZStack {
                Color.clear
                    .readSize {
                        targetSize = $0
                    }
                
                sizedView
            }
        }
        
        private var sizedView: some View {
            let viewContent = content()
            viewContent.layoutIfNeeded()
            let size = viewContent.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            return viewContent
                .wrappedView
                .frame(
                    width: size.width,
                    height: size.height
                )
        }
    }
    
    var selfSizingWrappedView: some View {
        SelfSizingWrappedView { self }
    }
    
    var wrappedView: some View {
        WrapperView { self }
    }
}
