import Foundation
import SwiftUI
import ThreemaMacros

struct StorageManagementChatExportView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject var viewModel: ChatExportViewModel
    
    @State private var share = false
    @State private var usedMemory = 0.0 {
        didSet {
            peakMemory = max(peakMemory, usedMemory)
        }
    }

    @State var peakMemory = 0.0
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // MARK: - Subviews
    
    private var readyView: some View {
        VStack {
            Image(systemName: "square.and.arrow.up")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundStyle(Color.accentColor)
                .padding()
                .padding(.top)

            Text(viewModel.readyTitle)
                .font(.title)
                .bold()
                .padding(.bottom)
            
            Text(viewModel.readyDescription)
                .font(.body)
                .multilineTextAlignment(.center)
        }
    }
    
    private var zippingView: some View {
        VStack {
            Text(viewModel.zippingText)
                .font(.headline.bold())
                .padding(.bottom, 15)
            
            if #available(iOS 18.0, *) {
                Image(systemName: "ellipsis")
                    .imageScale(.large)
                    .symbolEffect(.breathe)
                    .font(.body)
                    .padding(.bottom)
            }
            else {
                Image(systemName: "ellipsis")
                    .imageScale(.large)
                    .font(.body)
                    .padding(.bottom)
            }
        }
    }
    
    private var progressView: some View {
        CircularProgressView(progress: $viewModel.progress)
            .padding(.horizontal, 50)
            .padding(.vertical, 25)
    }
    
    // MARK: - Body
   
    var body: some View {
        VStack {
            Spacer()
            
            switch viewModel.viewState {
            case .ready:
                readyView
                Spacer()
                Spacer()
                ThreemaButton(title: viewModel.exportButtonTitle, style: .borderedProminent, size: .fullWidth) {
                    DispatchQueue.global().async {
                        viewModel.export()
                    }
                }
                    
            case .exporting:
                progressView
                    .id(1)
                Spacer()
                ConversationProgressView(viewModel: viewModel)
                TimerView(viewModel: viewModel)
                    .id(2)
                MemoryView(viewModel: viewModel, usedMemory: $usedMemory)
                Spacer()
                        
            case .zipping:
                progressView
                    .id(1)
                Spacer()
                zippingView
                TimerView(viewModel: viewModel)
                    .id(2)
                MemoryView(viewModel: viewModel, usedMemory: $usedMemory)
                
                Spacer()

            case let .error(text):
                ErrorView(viewModel: viewModel, text: text)
                Spacer()
                Spacer()
                ThreemaButton(title: viewModel.exportButtonTitle, style: .borderedProminent, size: .fullWidth) {
                    DispatchQueue.global().async {
                        viewModel.export()
                    }
                }
                    
            case .done:
                DoneView(viewModel: viewModel, peakMemory: $peakMemory)
                Spacer()
                Spacer()
                if viewModel.url != nil {
                    ThreemaButton(title: viewModel.shareButtonTitle, style: .borderedProminent, size: .fullWidth) {
                        share = true
                    }
                }
            }
                
            ThreemaButton(
                title: viewModel.viewState.cancelButtonTitle,
                style: .bordered,
                size: .fullWidth
            ) {
                viewModel.dismiss()
                dismiss()
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $share) {
            ShareSheet(items: [viewModel.url as Any])
        }
        .onReceive(timer) { _ in
            if let usage = reportMemoryUsage() {
                usedMemory = usage
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.dismiss()
        }
    }
    
    private func reportMemoryUsage() -> Double? {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
            
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
            
        if result == KERN_SUCCESS {
            // phys_footprint is the actual memory being charged to your app
            let usedBytes = Double(taskInfo.phys_footprint)
            return usedBytes / 1024 / 1024 // Convert to MB
        }
        else {
            return 0.0
        }
    }
    
    private struct MemoryView: View {
        @ObservedObject var viewModel: ChatExportViewModel
        @Binding var usedMemory: Double

        var body: some View {
            Text(viewModel.memoryLabel)
                .font(.headline)
                
            Text(verbatim: "\(String(format: "%.2f", usedMemory)) MB")
                .font(.body)
        }
    }
    
    private struct TimerView: View {
        @ObservedObject var viewModel: ChatExportViewModel

        var body: some View {
            if let startDate = viewModel.startDate {
                Text(viewModel.timerLabel)
                    .font(.headline.bold())

                Text(startDate, style: .timer)
                    .font(.body)
                    .padding(.bottom)
            }
        }
    }
    
    private struct ConversationProgressView: View {
        @ObservedObject var viewModel: ChatExportViewModel
        
        var body: some View {
            if let name = viewModel.displayNameOfCurrentConversation {
                Text(
                    verbatim:
                    "\(viewModel.conversationText) \(viewModel.indexOfCurrentConversation)/\(viewModel.totalConversationCount):"
                )
                .font(.monospacedDigit(.headline.bold())())
                
                Text(name)
                    .font(.body)
                    .padding(.bottom)
            }
        }
    }
    
    private struct ErrorView: View {
        @ObservedObject var viewModel: ChatExportViewModel
        var text: String
        
        var body: some View {
            VStack {
                Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(Color.accentColor)
                    .padding()
                    .padding(.top)
                
                Text(viewModel.errorTitle)
                    .font(.title)
                    .bold()
                    .padding(.bottom)
                
                Text(viewModel.errorDescription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private struct DoneView: View {
        @ObservedObject var viewModel: ChatExportViewModel
        @Binding var peakMemory: Double
        
        var body: some View {
            VStack {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundStyle(Color.accentColor)
                    .padding()
                    .padding(.top)
                
                Text(viewModel.doneTitle)
                    .font(.title)
                    .bold()
                    .padding(.bottom)
                
                Text(viewModel.doneMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)

                if let startDate = viewModel.startDate, let endDate = viewModel.endDate {
                    HStack {
                        Text(viewModel.durationLabel)
                            .font(.subheadline)
                        Text(timerInterval: startDate...endDate, countsDown: false)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    if let size = viewModel.exportSize {
                        HStack {
                            Text(viewModel.exportSizeLabel)
                                .font(.subheadline)
                            Text("\(String(format: "%.2f", size)) MB")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(viewModel.peakMemoryLabel)
                            .font(.subheadline)
                        Text("\(String(format: "%.2f", peakMemory)) MB")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CircularProgressView: View {
    @Binding var progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.accentColor.opacity(0.3),
                    lineWidth: 10
                )
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut, value: progress)
            
            Text(verbatim: "\(Int(progress * 100))%")
                .font(.title)
                .bold(true)
                .foregroundColor(.accentColor)
        }
        .frame(height: 200)
        .padding(.top)
    }
}

// We use the workaround to be able to use a `ThreemaButton` above
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
