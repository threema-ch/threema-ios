import SwiftUI

struct BulletText: View {
    let string: String
    let showIcon: Bool
    
    init(string: String, showIcon: Bool = false) {
        self.string = string
        self.showIcon = showIcon
    }
    
    var body: some View {
        Label {
            Text(verbatim: "· \(string)")
        } icon: {
            if showIcon {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
            }
        }
        .labelStyle(TrailingLabelStyle())
    }
}

struct BulletText_Previews: PreviewProvider {
    static var previews: some View {
        BulletText(string: "Text")
    }
}
