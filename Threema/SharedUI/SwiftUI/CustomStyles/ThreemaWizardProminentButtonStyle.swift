//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

extension ButtonStyle where Self == ThreemaWizardProminentButtonStyle {
    static var threemaWizardProminentButtonStyle: ThreemaWizardProminentButtonStyle { .init() }
}

struct ThreemaWizardProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8.0) {
            Image(systemName: "arrow.forward")
                .imageScale(.medium)
            configuration.label
                .font(.headline)
                .textCase(.uppercase)
        }
        .padding(EdgeInsets(top: 12.0, leading: 16.0, bottom: 12.0, trailing: 16.0))
        .background(Color.accentColor)
        .foregroundStyle(Colors.textProminentButtonWizard.color)
        .clipShape(Capsule(style: .continuous))
        .accessibilityElement()
    }
}
