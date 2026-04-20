import SwiftUI
import ThreemaFramework

@available(*, deprecated, message: "Do not use anymore. Use stock APIs instead.")
struct SettingsListItemView: View {
    let cellTitle: String
    let accessoryText: String?
    let resource: ThreemaImageResource?
    let width: CGFloat = 28
        
    init(cellTitle: String, accessoryText: String? = nil, image resource: ThreemaImageResource? = nil) {
        self.cellTitle = cellTitle
        self.accessoryText = accessoryText
        self.resource = resource
    }
    
    var body: some View {
        HStack {
            Label {
                Text(cellTitle)
            } icon: {
                if let resource {
                    Image(resource)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .padding(5)
                        .frame(width: width, height: width, alignment: .center)
                        .background(.gray)
                        .cornerRadius(5)
                }
            }
            Spacer()
            if let accessoryText {
                Text(accessoryText)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsListItemView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsListItemView(cellTitle: "Preview Text", accessoryText: nil, image: .systemImage("trash.fill"))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
