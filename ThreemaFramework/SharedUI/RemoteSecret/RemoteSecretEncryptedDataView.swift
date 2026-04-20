import Foundation
import SwiftUI
import ThreemaMacros

public struct RemoteSecretEncryptedDataView: View {
    
    public init() { }
    
    public var body: some View {
        VStack {
            Spacer()
        
            Text(#localize("rs_view_title_encrypted_data"))
                .font(.title)
                .bold()
                .padding(.bottom, 2)
            Text(#localize("rs_view_description_encrypted_data"))
            
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .ignoresSafeArea(.all, edges: [.top, .horizontal])
    }
}
