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

import Foundation
import SwiftUI

struct WizardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 20.0) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? UIScreen.main.bounds.width - 200.0 : .infinity)
        .padding(.all, 10.0)
    }
}

struct WizardOpacityGroupBoxStyle: GroupBoxStyle {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 40.0) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalSizeClass == .compact ? 20.0 : 40.0)
        .padding(.vertical, 40.0)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.gray.opacity(0.2))
        )
    }
}

extension GroupBoxStyle where Self == WizardGroupBoxStyle {
    static var wizard: Self {
        .init()
    }
}

extension GroupBoxStyle where Self == WizardOpacityGroupBoxStyle {
    static var wizardOpacity: Self {
        .init()
    }
}
