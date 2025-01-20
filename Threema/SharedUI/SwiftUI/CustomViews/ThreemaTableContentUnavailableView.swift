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

/// A view that displays a placeholder when table content is unavailable.
///
/// This view supports both iOS 17+ using the new `ContentUnavailableView` and older versions using a custom `View`
/// which looks exactly the same.
struct ThreemaTableContentUnavailableView: View {
    let configuration: Configuration

    var body: some View {
        if #available(iOS 17, *) {
            ContentUnavailableView(label: {
                Label(configuration.title, systemImage: configuration.systemImage)
            }, description: {
                Text(configuration.description)
            }, actions: {
                ForEach(configuration.actions) { action in
                    if configuration.actions.first?.title == action.title {
                        Button(action: action.block) {
                            Text(action.title)
                                .padding(6)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    else {
                        Button(action: action.block) {
                            Text(action.title)
                                .padding(6)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            })
        }
        else {
            VStack(alignment: .center) {
                header
                Text(configuration.description)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                ForEach(configuration.actions) { action in
                    if configuration.actions.first?.title == action.title {
                        button(for: action)
                            .buttonStyle(.borderedProminent)
                    }
                    else {
                        button(for: action)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
    }
    
    private var header: some View {
        VStack {
            Image(systemName: configuration.systemImage)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 55, height: 55)
            Text(configuration.title)
                .font(.title2)
                .bold()
        }
        .padding()
    }
    
    private func button(for action: Action) -> some View {
        Button(action: action.block) {
            Text(action.title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20.0))
    }
}

extension ThreemaTableContentUnavailableView {
    struct Configuration {
        let title: String
        let systemImage: String
        let description: String
        let actions: [Action]
    }
    
    struct Action: Identifiable, Equatable {
        static func == (
            lhs: ThreemaTableContentUnavailableView.Action,
            rhs: ThreemaTableContentUnavailableView.Action
        ) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: UUID { UUID() }
        let title: String
        let block: () -> Void
    }
}

extension UITableView {
    /// Sets up a content unavailable view with the specified configuration.
    ///
    /// - Parameter configuration: The configuration for the unavailable content view.
    /// - Returns: A tuple containing show and hide closures for the content unavailable view.
    func setupContentUnavailableView(
        configuration: ThreemaTableContentUnavailableView
            .Configuration
    ) -> (() -> Void, () -> Void) {
        let contentUnavailableView =
            UIHostingController(rootView: ThreemaTableContentUnavailableView(configuration: configuration)).view
        let show = { [weak self] in
            guard let self else {
                return
            }
            backgroundView = contentUnavailableView
        }
        
        let hide = { [weak self] in
            guard let self else {
                return
            }
            backgroundView = nil
        }
        return (show: show, hide: hide)
    }
}

#Preview {
    ThreemaTableContentUnavailableView(
        configuration:
        .init(
            title: "No Mail",
            systemImage: "tray.fill",
            description: "New mails you receive will appear here.",
            actions: [.init(title: "Refresh", block: { })]
        )
    )
}
