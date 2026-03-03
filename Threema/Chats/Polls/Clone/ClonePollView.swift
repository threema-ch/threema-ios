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

import SwiftUI
import ThreemaMacros

struct ClonePollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = ClonePollViewModel()
    
    var onPollSelected: (Poll) -> Void
    
    var body: some View {
        List {
            ForEach($viewModel.pollIDs) { $pollID in
                if let poll = viewModel.load(for: pollID) {
                    PollRowView(title: poll.title, creator: poll.creator?.label, created: poll.created) {
                        onPollSelected(poll)
                        dismiss()
                    }
                }
            }
        }
        .contentMargins(.top, 5)
        .loadingOverlay(viewModel.isLoading)
        .navigationTitle(#localize("ballot_choose_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }
}
