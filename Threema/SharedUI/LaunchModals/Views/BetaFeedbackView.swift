//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

struct BetaFeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - View

    var body: some View {
        VStack {
            Text(BundleUtil.localizedString(forKey: "testflight_feedback_title"))
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                .padding()
            
            Text(BundleUtil.localizedString(forKey: "testflight_feedback_description"))
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.bottom, 50)
            
            Image(uiImage: resolveImage())
                .resizable()
                .scaledToFit()
                .border(Color(uiColor: Colors.textLight))
            
            Spacer()

            Button {
                dismiss()
            } label: {
                Text(BundleUtil.localizedString(forKey: "continue"))
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 20)
        }
        .padding()
        
        .onDisappear {
            AppGroup.userDefaults().set(true, forKey: Constants.showedTestFlightFeedbackViewKey)
            
            // TODO: (IOS-3251) Remove
            LaunchModalManager.shared.checkLaunchModals()
        }
    }
    
    // MARK: - Private Functions

    private func resolveImage() -> UIImage {
        let type = colorScheme == .dark ? "dark" : "light"
        
        guard let image = BundleUtil.imageNamed("Feedback_\(type)") else {
            return UIImage(systemName: "questionmark.square.dashed")!
        }
        
        return image
    }
}

struct BetaFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        BetaFeedbackView()
            .tint(UIColor.primary.color)
    }
}
