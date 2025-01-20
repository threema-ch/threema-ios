//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import Foundation
import MBProgressHUD
import SwiftUI
import ThreemaFramework
import ThreemaMacros

extension ProfileView {
    struct DynamicHeader<Content: View>: View {
        
        @EnvironmentObject var model: ProfileViewModel
        @EnvironmentObject var navigationBarBranding: ThreemaNavigationBarBranding
        
        let content: () -> Content
        
        private let animation: Animation = .spring().speed(4.4)
        
        // MARK: - States
        
        @State private var orientation = UIDeviceOrientation.unknown
        @State private var containerHeight: CGFloat = ProfileView.fixedHeight
        @State private var manualScale: CGFloat = 0.5
        @State private var originalState: TrackedFrame?
        @State private var originalStateImage: TrackedFrame?
        @State private var alignment: Alignment = .center
        @State private var foregroundLabelColor: Color = .primary
        @State private var labelContainerOffset: CGFloat = 0
        @State private var imageOffset: CGFloat = 0
        @State private var scrollOffset: CGFloat = 0
        @State private var inset: CGFloat = 0
        @State private var labelOffset: CGFloat = fixedHeight / 1.4
        @State private var animationState: AnimationState = .idle
        @State private var enlargedHeight: CGFloat = screenWidth * factor
        @State private var debugCollapsed = true
        @State private var debugHidden = true
        
        @State private var state: ImageState = .normal {
            didSet {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                containerHeight = state == .expanded ? enlargedHeight : fixedHeight
            }
        }
        
        // MARK: - Computed Properties
        
        private var enlargedCellHeight: CGFloat {
            enlargedHeight - (originalState?.frame.minY ?? 0.0)
        }
        
        private var yOffset: CGFloat {
            (originalState?.frame.minY ?? 1.0) / 2
        }
        
        private var blurRadius: CGFloat {
            state == .normal ? (1 - (manualScale - 0.4) / 0.1) * 10 : 0
        }
        
        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
        
        // MARK: - Views
        
        var body: some View {
            GeometryReader { proxy in
                dynamicListContainer { placeHolder in
                    VStack {
                        if #available(iOS 16.0, *) {
                            List {
                                placeHolder(proxy)
                                content()
                            }
                            .scrollIndicators(state != .normal ? .never : .automatic)
                        }
                        else {
                            List {
                                placeHolder(proxy)
                                content()
                            }
                        }
                    }
                }
            }
        }
        
        private func dynamicListContainer(@ViewBuilder _ content: @escaping ((GeometryProxy) -> AnyView) -> some View)
            -> some View {
            ZStack {
                content(placeHolder)
                profileHeaderView
                    
                #if DEBUG
                    if !debugHidden {
                        debugInfo()
                    }
                #endif
            }
            .onPreferenceChange(TrackedFrame.Key.self, perform: processOnPreferenceChange)
            .animation(animation, value: state)
            .environmentObject(model)
            .onRotate(perform: onOrientationChange)
            .onAppear {
                onOrientationChange(UIDevice.current.orientation)
            }
        }
        
        @ViewBuilder
        private var labelView: some View {
            ZStack {
                VStack {
                    GeometryReader { geometry in
                        VStack {
                            Text(model.nickname)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: alignment)
                                .font(.title)
                                .padding(
                                    .top,
                                    model.threemaID.isEmpty ? labelOffset - 5 : labelOffset - 20
                                )
                                .padding(.leading, inset)
                                .foregroundColor(foregroundLabelColor)
                                .accessibilityLabel(
                                    "\(#localize("id_completed_nickname")): \(model.nickname)"
                                )
                            
                            Text(model.threemaID)
                                .frame(maxWidth: .infinity, alignment: alignment)
                                .padding(.leading, inset)
                                .foregroundColor(foregroundLabelColor)
                                .accessibilityLabel(
                                    "\(#localize("my_threema_id")): \(model.publicKey.identity)"
                                )
                            Spacer()
                        }
                        .onChange(of: state) { newValue in
                            let delta = geometry.frame(in: .global).minY - (enlargedHeight / 2)
                            if newValue == .expanded {
                                labelOffset = (enlargedHeight / 2) - delta
                                withAnimation(animation) {
                                    alignment = .leading
                                    inset = 35
                                }
                            }
                            else {
                                if #available(iOS 16.0, *) {
                                    withAnimation(animation) {
                                        alignment = .center
                                        labelOffset = fixedHeight / 1.4
                                        inset = 0
                                    }
                                }
                                else {
                                    alignment = .center
                                    labelOffset = fixedHeight / 1.4
                                    inset = 0
                                }
                            }
                        }
                        .onTapGesture {
                            if ThreemaApp.current != .onPrem {
                                UIPasteboard.general.string = model.publicKey.identity
                                NotificationPresenterWrapper.shared.present(type: .copyIDSuccess)
                            }
                        }
                    }
                    .shadow(color: .gray, radius: state == .expanded ? 6 : 0, x: 0, y: 0)
                    .frame(width: ProfileView.screenWidth)
                }
            }
            .offset(y: labelContainerOffset)
            .animation(nil, value: imageOffset)
        }
        
        @ViewBuilder
        private var profileHeaderView: some View {
            VStack {
                ZStack {
                    imageHeader
                    labelView
                }
                .scaleEffect(x: manualScale + 0.5, y: manualScale + 0.5, anchor: .top)
                Spacer()
            }
            .onChange(of: model.hasProfile) { _ in
                changeState(.normal)
            }
            .onChange(of: imageOffset) { _ in
                if state == .expanded {
                    foregroundLabelColor = .white
                }
                else {
                    foregroundLabelColor = .primary
                    labelContainerOffset = imageOffset
                }
            }
            .onChange(of: scrollOffset) {
                calculateImageOffset($0)
                calculateOffScreenScale()
                toggleNavigationBarTitle()
            }
        }
        
        @ViewBuilder
        private var imageHeader: some View {
            VStack {
                ZStack {
                    VStack {
                        GeometryReader { proxy in
                            Image(uiImage: model.profileImage)
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel(#localize("my_profilepicture"))
                                .transformAnchorPreference(key: TrackedFrame.Key.self, value: .bounds) {
                                    $0.append(TrackedFrame(id: "imageFrame", frame: proxy[$1], data: nil))
                                }
                                .modifier(ScaleRadius(isCircle: state == .normal, rectSize: proxy.size))
                                .frame(
                                    width: state == .expanded ? nil : proxy.size.width,
                                    height: state == .expanded ? nil : proxy.size.width
                                )
                        }
                    }
                    .offset(y: imageOffset)
                }
                .blur(radius: blurRadius)
                .frame(width: ProfileView.screenWidth, height: containerHeight)
                .allowsHitTesting(false)
                Spacer()
            }
        }
        
        // MARK: - Private Functions
        
        private func onOrientationChange(_ orientation: UIDeviceOrientation) {
            self.orientation = orientation
            if orientation.isLandscape {
                if state != .normal {
                    changeState(.normal)
                }
            }
        }
        
        private func placeHolder(_ proxy: GeometryProxy) -> AnyView {
            AnyView(
                Section {
                    Text("")
                        .frame(
                            height: state == .expanded ? ProfileView.fixedHeight * ProfileView.factor : ProfileView
                                .fixedHeight / 1.5
                        )
                }
                .listRowBackground(Color(uiColor: Colors.backgroundGroupedViewController))
                .transformAnchorPreference(key: TrackedFrame.Key.self, value: .bounds) {
                    $0.append(TrackedFrame(id: "topCell", frame: proxy[$1], data: nil))
                }
            )
        }
        
        private func processOnPreferenceChange(_ frames: [TrackedFrame]) {
            guard let topCell = frames.filter({ $0.id == "topCell" }).first,
                  let imageEntry = frames.filter({ $0.id == "imageFrame" }).first else {
                
                animationState = .idle
                if orientation.isLandscape {
                    scrollOffset = -300
                }
                return
            }
            
            if originalState == nil, topCell.frame.minY >= 0 {
                originalState = topCell
            }
            if originalStateImage == nil {
                originalStateImage = imageEntry
            }
            
            guard UIDevice.current.userInterfaceIdiom != .pad else {
                scrollOffset = topCell.frame.minY
                // Disabled for iPads as long as we present the ProfileView modally
                return
            }
            
            guard !(AppDelegate().currentTopViewController().presentingViewController is MainTabBarController) else {
                // Prevent offset changes while another view is being presented
                return
            }

            guard model.hasProfile, let originalStateImage, !orientation.isLandscape else {
                animationState = .idle
                scrollOffset = topCell.frame.minY
                return
            }
            
            switch Int(imageEntry.frame.width) {
            case Int(originalStateImage.frame.width):
                animationState = .idle
            case Int(enlargedHeight):
                animationState = .idleExpanded
            case let width where width > Int(originalStateImage.frame.width) && width < Int(enlargedHeight):
                animationState = .expanding
            default:
                break
            }

            scrollOffset = topCell.frame.minY
            
            if imageOffset > 85, animationState == .idle {
                changeState(.expanded)
            }
            
            if imageOffset == 0, state == .expanded {
                let finalScale = scaleByOffset(topCell.frame.minY)
                            
                manualScale = finalScale < 1 ? 0.5 : finalScale - 0.5
                if finalScale < 1 {
                    changeState(.normal)
                }
            }
        }
        
        private func scaleByOffset(_ offset: CGFloat) -> CGFloat {
            let ref = offset - (originalState?.frame.minY ?? 0.0)
            let newScale = min(max(log10(abs(ref) + 10), 1), 10) / 10
            let dir: CGFloat = ref < 0 ? -1 : 1
            let gap: CGFloat = ref < 0 ? 0.1 : -0.1
            let finalScale = 1 + newScale * dir + gap + 0.05
            return finalScale
        }

        private func changeState(_ state: ImageState) {
            self.state = state
        }
        
        private func calculateImageOffset(_ newValue: CGFloat) {
            if state == .expanded {
                imageOffset = 0
            }
            else {
                if animationState == .expanding {
                    imageOffset = newValue - yOffset
                }
                else {
                    imageOffset = animationState == .idleExpanded ? 0 : newValue - yOffset
                }
            }
        }

        private func toggleNavigationBarTitle() {
            guard let height = originalState?.frame.height, abs(scrollOffset) > height else {
                navigationBarBranding.show()
                return
            }
            navigationBarBranding.hide()
        }
        
        private func calculateOffScreenScale() {
            guard let height = originalStateImage?.frame.height else {
                return
            }
            
            let isScrolling = state == .normal
            if imageOffset < -yOffset, isScrolling {
                let normalizedOffset = abs((imageOffset + yOffset) / (height + yOffset))
                let scale = 0.5 - normalizedOffset * 0.25
                manualScale = scale
            }
            else if imageOffset >= yOffset, isScrolling {
                manualScale = 0.5
            }
        }
        
        // MARK: - Debug View
        
        @ViewBuilder
        private func debugInfo() -> some View {
            var debugInfoStr: String {
                """
                animationState:\(animationState), state: \(state)
                labelContainerOffset:\(String(
                    format: "%.2f",
                    labelContainerOffset
                )),imageOffset:\(String(
                    format: "%.2f",
                    imageOffset
                ))
                scrollOffset:\(String(format: "%.2f", scrollOffset)), labelOffset:\(String(format: "%.2f", labelOffset))
                
                isLandscape:\(orientation.isLandscape), scale:\(manualScale)
                enlargedHeight:\(enlargedHeight), containerHeight:\(containerHeight)
                
                originalState:\(originalState?.frame ?? .zero)
                originalStateImage:\(originalStateImage?.frame ?? .zero)
                """
            }
            
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    VStack {
                        if debugCollapsed {
                            Text(
                                verbatim: "SO:\(String(format: "%.2f", scrollOffset)), LO:\(String(format: "%.2f", labelOffset)), IO:\(String(format: "%.2f", imageOffset))"
                            )
                        }
                        else {
                            Text(verbatim: debugInfoStr)
                        }
                    }
                    .font(.caption)
                    .padding()
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
            }
            .onTapGesture {
                withAnimation {
                    debugCollapsed.toggle()
                }
            }
        }
    }
    
    // MARK: - Constants
    
    private static var fixedHeight: CGFloat {
        screenWidth * 0.8
    }
    
    private static let factor: CGFloat = 1.1

    static var screenWidth: CGFloat {
        let bounds = AppDelegate.shared().currentTopViewController().view.bounds
        return bounds.width > bounds.height ? bounds.height : bounds.width
    }
    
    static var screenHeight: CGFloat {
        let bounds = AppDelegate.shared().currentTopViewController().view.bounds
        return bounds.width > bounds.height ? bounds.width : bounds.height
    }
}
