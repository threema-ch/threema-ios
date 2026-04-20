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
                                .onChange(of: choice.date) {
                                    choice.text = DateFormatter.getDayMonthAndYear(choice.date)
                                }
                        }
                        .moveDisabled(choice.text.isEmpty)
                        .deleteDisabled(choice.text.isEmpty)
                    }
                    .onMove(perform: relocate)
                    .onDelete(perform: delete)
                    .onChange(of: focus) {
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
                                .foregroundStyle(Color(.labelInverted))
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
                    CancelButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SendButton {
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
