import SwiftUI

struct DeviceJoinHeaderView: View {
    
    let title: String
    let description: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .bold()
                .padding(.bottom)
                .accessibilityAddTraits(.isHeader)
            
            Text(.init(description))
                .padding(.bottom)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct DeviceJoinHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceJoinHeaderView(title: "Hello World", description: "Tap this thing below to execute some action.")
    }
}
