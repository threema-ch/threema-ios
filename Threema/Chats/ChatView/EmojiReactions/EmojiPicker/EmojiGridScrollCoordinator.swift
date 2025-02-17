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
import ThreemaFramework

protocol EmojiPickerDelegate {
    /// Called when an emoji section is selected.
    /// - Parameter section: The section of the emoji category that was selected.
    func didSelectEmojiSection(_ section: EmojiCategory.Section)
    
    /// Called before an emoji section is selected.
    /// - Parameter section: The section of the emoji category that will be selected.
    func willSelectEmojiSection(_ section: EmojiCategory.Section)
    
    /// Called when the emoji picker scrolls to a new section.
    /// - Parameter currentScrollPositionSection: The current section visible in the scroll view.
    func didScroll(_ currentScrollPositionSection: EmojiCategory.Section)
}

enum EmojiSectionToolbar {
    typealias config = ChatViewConfiguration.EmojiReactions.Picker

    static let preferenceID = "scrollGridSection"

    class ScrollGridCoordinator: ObservableObject {
        @Published var selectedToolbarSection: EmojiCategory.Section? = .recent
        @Published var nextSectionScrollState: EmojiCategory.Section?
        @Published var canManualScroll = false
    }
    
    struct BaseModifier: ViewModifier {
        @StateObject var model: ScrollGridCoordinator = .init()
        @Binding var toolbarVisible: Bool
        
        func body(content: Content) -> some View {
            ZStack(alignment: .bottom) {
                content
                    .onPreferenceChange(TrackedFrame.Key.self, perform: { frames in
                        if let scrollGridSection = frames.filter({ $0.id == EmojiSectionToolbar.preferenceID }).first {
                            let midY = Int(scrollGridSection.frame.midY)
                            guard let section = scrollGridSection.data as? EmojiCategory.Section else {
                                return
                            }
                            Task {
                                if midY < Int(UIScreen.main.bounds.height / 2) + 50, midY > 100 {
                                    model.didScroll(section)
                                }
                            }
                        }
                    })
                    .environmentObject(model)
            }
            .safeAreaInset(edge: .bottom, content: {
                EmojiToolBar()
                    .offset(y: toolbarVisible ? 0 : config.yOffsetOnDismissal)
                    .frame(height: config.toolbarHeight)
                    .onChange(of: model.selectedToolbarSection, perform: { _ in
                        Task { @MainActor in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    })
                    .environmentObject(model)
            })
        }
    }
    
    struct ScrollBarCoordinatorModifier: ViewModifier {
        @EnvironmentObject var model: ScrollGridCoordinator
        
        func body(content: Content) -> some View {
            ScrollViewReader { proxy in
                content
                    .simultaneousGesture(DragGesture(coordinateSpace: .global).onChanged { _ in
                        model.canManualScroll = true
                    }, including: .all)
                    .onChange(of: model.nextSectionScrollState) { section in
                        if let section {
                            proxy.scrollTo(section.id, anchor: .top)
                            model.didSelectEmojiSection(section)
                        }
                    }
            }
        }
    }
    
    struct ScrollBarTrackModifier: ViewModifier {
        let section: EmojiCategory.Section
        func body(content: Content) -> some View {
            content
                .trackPreference(EmojiSectionToolbar.preferenceID, data: section)
        }
    }
}

// MARK: - EmojiSectionToolbar.ScrollGridCoordinator + EmojiPickerDelegate

extension EmojiSectionToolbar.ScrollGridCoordinator: EmojiPickerDelegate {
    @MainActor func didScroll(_ currentScrollPositionSection: EmojiCategory.Section) {
        if canManualScroll {
            withAnimation {
                selectedToolbarSection = currentScrollPositionSection
            }
        }
    }
    
    func willSelectEmojiSection(_ section: EmojiCategory.Section) {
        canManualScroll = false
        withAnimation {
            selectedToolbarSection = section
        }
        
        nextSectionScrollState = section
    }
    
    func didSelectEmojiSection(_ section: EmojiCategory.Section) {
        nextSectionScrollState = nil
    }
}

// MARK: - EmojiSectionToolbar.EmojiToolBar

extension EmojiSectionToolbar {
    struct EmojiToolBar: View {
        @EnvironmentObject var scrollCoordinator: ScrollGridCoordinator
        
        var body: some View {
            toolbar { frame in
                ZStack {
                    sectionHighlightBackground(in: frame)
                    sections(in: frame)
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
        
        private func sectionHighlightBackground(in frame: CGRect) -> some View {
            HStack(spacing: 0) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(
                        width: frame.width / CGFloat(EmojiPicker.sections.count),
                        height: frame.height - config.itemHeightMargin
                    )
                    .blendMode(.multiply)
                    .offset(x: offset(
                        for: scrollCoordinator.selectedToolbarSection ?? .recent,
                        width: frame.width
                    ))
                Spacer()
            }
            .frame(
                width: frame.width,
                height: frame.height
            )
        }
        
        private func sections(in frame: CGRect) -> some View {
            HStack(spacing: 0) {
                ForEach(EmojiPicker.sections) { section in
                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .frame(
                                width: frame.width / CGFloat(EmojiPicker.sections.count),
                                height: frame.height - config.itemHeightMargin
                            )
                        Button {
                            scrollCoordinator.willSelectEmojiSection(section)
                        } label: {
                            Image(systemName: section.icon)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        
        private func toolbar(@ViewBuilder _ content: @escaping (CGRect) -> some View) -> some View {
            VStack(alignment: .center) {
                HStack(spacing: 0) {
                    GeometryReader { localProxy in
                        content(localProxy.frame(in: .global))
                            .highPriorityGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if let section = section(
                                            at: value.location.x,
                                            width: localProxy.frame(in: .local).width
                                        ) {
                                            withAnimation { scrollCoordinator.selectedToolbarSection = section }
                                            scrollCoordinator.willSelectEmojiSection(section)
                                        }
                                    },
                                including: .all
                            )
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, config.horizontalPadding)
            .background(.ultraThinMaterial)
        }
        
        private func section(at offset: CGFloat, width: CGFloat) -> EmojiCategory.Section? {
            let sectionWidth = width / CGFloat(EmojiPicker.sections.count)
            if offset < width,
               let index = (0..<EmojiPicker.sections.count)
               .first(where: { offset >= CGFloat($0) * sectionWidth && offset < CGFloat($0 + 1) * sectionWidth }) {
                if index >= EmojiPicker.sections.count {
                    return EmojiPicker.sections[index - 1]
                }
                else {
                    return EmojiPicker.sections[index]
                }
            }
            else {
                return scrollCoordinator.selectedToolbarSection
            }
        }

        private func offset(for section: EmojiCategory.Section, width: CGFloat) -> CGFloat {
            let sectionWidth = width / CGFloat(EmojiPicker.sections.count)
            return CGFloat(EmojiPicker.sections.firstIndex(of: section) ?? 0) * sectionWidth
        }
    }
}

extension View {
    /// Tracks the current section of the emoji toolbar.
    /// - Parameter section: The section of the emoji category.
    public func trackSection(_ section: EmojiCategory.Section) -> some View {
        modifier(EmojiSectionToolbar.ScrollBarTrackModifier(section: section))
    }
    
    /// Provides a coordinator for the emoji toolbar's scroll bar.
    public func scrollBarCoordinator() -> some View {
        modifier(EmojiSectionToolbar.ScrollBarCoordinatorModifier())
    }
    
    /// Configures the visibility of the emoji toolbar and attaches it to the emoji picker.
    /// - Parameter section: The section of the emoji category that will be selected.
    public func emojiToolbar(isVisible toolbarVisible: Binding<Bool>) -> some View {
        modifier(EmojiSectionToolbar.BaseModifier(toolbarVisible: toolbarVisible))
    }
}

#Preview(body: {
    VStack {
        Color.gray
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .emojiToolbar(isVisible: .constant(true))
})
