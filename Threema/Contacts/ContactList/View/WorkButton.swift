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

#if THREEMA_WORK || THREEMA_ONPREM
    import SwiftUI
    import ThreemaFramework
    import ThreemaMacros

    struct WorkButton: View {
        @State var isTurnedOn = false {
            didSet { didToggle(isTurnedOn) }
        }
        
        var didToggle: (_ isTurnedOn: Bool) -> Void
    
        var body: some View {
            Button {
                isTurnedOn.toggle()
            } label: {
                Image("threema.case.\(isTurnedOn ? "circle.fill" : "fill.circle")")
                    .imageScale(.large)
            }
            .accessibilityLabel(#localize("segmentcontrol_work_contacts"))
        }
    }

    typealias WorkButtonView = UIHostingController<WorkButton>

    extension WorkButtonView {
        convenience init(_ didToggle: @escaping (Bool) -> Void) {
            self.init(rootView: WorkButton(didToggle: didToggle))
            view.backgroundColor = .clear
        }
    }

    #Preview {
        WorkButton(isTurnedOn: false, didToggle: { _ in })
    }
#endif
