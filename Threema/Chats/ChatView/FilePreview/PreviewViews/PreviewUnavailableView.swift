import SwiftUI
import ThreemaMacros

struct PreviewUnavailableView: View {
    let viewModel: PreviewUnavailableViewModel

    var body: some View {
        ContentUnavailableView {
            Label(viewModel.fileName ?? "", systemImage: viewModel.thumbnailSymbolName)
        } description: {
            Text(viewModel.fileSizeText ?? "")
        } actions: {
            if viewModel.isShareable {
                Button {
                    viewModel.shareFile()
                } label: {
                    Label(viewModel.shareButtonName, systemImage: "square.and.arrow.up")
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
