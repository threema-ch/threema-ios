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

struct CreatePollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: CreatePollViewModel
    
    @FocusState private var focus: Field?
    
    @State var isEditing = false
    @State var editMode: EditMode = .inactive

    init(conversation: ConversationEntity) {
        _viewModel = StateObject(wrappedValue: CreatePollViewModel(conversationID: conversation.objectID))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Group {
                        TextField(
                            viewModel.titlePlaceholder,
                            text: $viewModel.title,
                            axis: .vertical
                        )
                        .lineLimit(2...Int.max)
                    }
                    .focused($focus, equals: .title)
                    .onSubmit {
                        if !viewModel.choices.isEmpty {
                            focus = .choice(0)
                        }
                        else {
                            focus = nil
                        }
                    }
                } header: {
                    Text(viewModel.titleSectionHeaderTitle)
                }
                
                Section {
                    ForEach(Array($viewModel.choices.enumerated()), id: \.1.id) { index, $choice in
                        HStack {
                            TextField(viewModel.choicePlaceholder, text: $choice.text)
                                .focused($focus, equals: .choice(index))
                                .submitLabel(.next)
                                .onSubmit {
                                    let nextIndex = index + 1
                                    if nextIndex < viewModel.choices.count {
                                        focus = .choice(nextIndex)
                                    }
                                    else {
                                        focus = nil
                                    }
                                }
                           
                            Spacer()
                            
                            Image(systemName: "calendar")
                                .renderingMode(.template)
                                .foregroundColor(.accentColor)
                                .imageScale(.large)
                                .overlay {
                                    GeometryReader { geometry in
                                        DatePicker("", selection: $choice.date, displayedComponents: .date)
                                            .labelsHidden()
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .contentShape(Rectangle())
                                            .colorMultiply(.clear)
                                    }
                                }
                                .onChange(of: choice.date) { date in
                                    choice.text = DateFormatter.getDayMonthAndYear(date)
                                }
                        }
                        .moveDisabled(choice.text.isEmpty)
                        .deleteDisabled(choice.text.isEmpty)
                    }
                    .onMove(perform: relocate)
                    .onDelete(perform: delete)
                    .onChange(of: focus) { _ in
                        for (index, choice) in viewModel.choices.enumerated() {
                            guard choice.text.isEmpty else {
                                continue
                            }
                            viewModel.removeChoice(at: index)
                        }
                    }
                } header: {
                    HStack {
                        Text(viewModel.choicesSectionHeaderTitle)
                        Spacer()
                        Button {
                            withAnimation {
                                isEditing.toggle()
                                editMode = isEditing ? .active : .inactive
                            }
                            
                        } label: {
                            Image(systemName: "arrow.up.and.down.text.horizontal")
                                .accessibilityLabel(viewModel.choicesEditTitle)
                        }
                        .disabled(!viewModel.isEditEnabled)
                    }
                }
                
                Section {
                    Toggle(isOn: $viewModel.allowMultipleSelection) {
                        Text(viewModel.multipleChoiceLabelText)
                    }
                    Toggle(isOn: $viewModel.showIntermediateResult) {
                        Text(viewModel.intermediateResultLabelText)
                    }
                }
                
                Section {
                    NavigationLink(destination: ClonePollView { viewModel.clone($0) }) {
                        Text(viewModel.cloneTitle)
                    }
                } footer: {
                    Text(viewModel.cloneFooterText)
                }
                .disabled(!viewModel.isCloneEnabled)
            }
            .contentMargins(.top, 5)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelText) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.sendText) {
                        sendPoll()
                    }
                    .disabled(!viewModel.isSendEnabled)
                }
            }
            // Force navigation style to stack so it doesn't show as split view on iPadOS 17
            .navigationViewStyle(.stack)
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .loadingOverlay(viewModel.isLoading)
    }
    
    private func relocate(from source: IndexSet, to destination: Int) {
        viewModel.relocate(from: source, to: destination)
    }
    
    func delete(at offsets: IndexSet) {
        guard let index = offsets.first else {
            return
        }
        
        viewModel.deleteChoice(at: index)
    }
    
    private func sendPoll() {
        Task {
            await viewModel.create()
            dismiss()
        }
    }
}

private enum Field: Hashable, Equatable {
    case title
    case choice(Int)
}

private struct ErrorModel {
    let title: String
    let message: String
}
