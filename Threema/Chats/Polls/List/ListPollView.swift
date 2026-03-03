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

struct ListPollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: ListPollViewModel
    
    private var onDisappear: (() -> Void)?
    
    init(conversation: ConversationEntity, onDisappear: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ListPollViewModel(conversationID: conversation.objectID))
        self.onDisappear = onDisappear
    }
    
    var body: some View {
        NavigationView {
            List {
                if !viewModel.openPollIDs.isEmpty {
                    Section(viewModel.openBallotsTitle) {
                        openSection
                    }
                }
                if !viewModel.closedPollIDs.isEmpty {
                    Section(viewModel.closedBallotsTitle) {
                        closedSection
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.doneTitle) {
                        dismiss()
                    }
                    .accessibilityIdentifier("ListPollViewDoneButton")
                }
            }
            .sheet(item: $viewModel.selectedPoll) {
                Task {
                    await viewModel.load()
                }
            } content: { poll in
                if poll.isClosed {
                    ResultPollView(pollID: poll.id)
                }
                else {
                    VotePollView(pollID: poll.id)
                }
            }
            .onAppear {
                Task {
                    await viewModel.load()
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationViewStyle(.stack)
            .loadingOverlay(viewModel.isLoading)
            .onDisappear {
                onDisappear?()
            }
        }
    }
    
    @ViewBuilder
    var openSection: some View {
        ForEach($viewModel.openPollIDs) { $pollID in
            if let poll = viewModel.load(for: pollID) {
                rowForPoll(poll)
            }
        }
    }
    
    @ViewBuilder
    var closedSection: some View {
        ForEach($viewModel.closedPollIDs) { $pollID in
            if let poll = viewModel.load(for: pollID) {
                rowForPoll(poll)
            }
        }
    }
    
    @ViewBuilder
    private func rowForPoll(_ poll: Poll) -> some View {
        PollRowView(title: poll.title, creator: poll.creator?.label, created: poll.created) {
            viewModel.selectPoll(poll)
        }
    }
}
