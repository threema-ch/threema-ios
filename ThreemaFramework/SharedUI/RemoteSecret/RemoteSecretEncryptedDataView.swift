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
import ThreemaMacros

public struct RemoteSecretEncryptedDataView: View {
    
    public init() { }
    
    public var body: some View {
        VStack {
            Spacer()
        
            Text(#localize("rs_view_title_encrypted_data"))
                .font(.title)
                .bold()
                .padding(.bottom, 2)
            Text(#localize("rs_view_description_encrypted_data"))
            
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .ignoresSafeArea(.all, edges: [.top, .horizontal])
    }
}
