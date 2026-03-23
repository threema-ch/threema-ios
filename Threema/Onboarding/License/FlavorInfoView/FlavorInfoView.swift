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

struct FlavorInfoView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var dismiss: () -> Void
    
    private enum Constant {
        static let spacing = 40.0
        static let padding = 24.0
        static let maxWidthRegular = 800.0
        static let topPaddingCompact = 0.0
        static let topPaddingRegular = 40.0
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    FlavorInfoBusinessAppView(dismiss: dismiss)
                        .padding(.bottom, Constant.spacing)
                    
                    FlavorInfoPrivateAppView()
                    
                    Spacer(minLength: Constant.spacing)
                    
                    Text(ThreemaUtility.appAndBuildVersionPretty)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .copyLabel(value: ThreemaUtility.appAndBuildVersion)
                }
                .padding(Constant.padding)
                .apply {
                    if horizontalSizeClass == .compact {
                        $0.padding(.top, Constant.topPaddingCompact)
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    else {
                        $0.padding(.top, Constant.topPaddingRegular)
                            .frame(maxWidth: Constant.maxWidthRegular, minHeight: proxy.size.height)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxWidth: .infinity)
            .background(.black)
            .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - BusinessAppView

#Preview {
    FlavorInfoView {
        // do nothing
    }
}
