import SwiftUI
import ThreemaMacros

struct DeviceJoinSuccessView: View {
    
    @Binding var showWizard: Bool

    var body: some View {
        VStack {
            GeometryReader { geometryProxy in
                ScrollView {
                    VStack {
                        Spacer()

                        Image("PartyPopper")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(50)
                            .accessibilityHidden(true)
                        
                        DeviceJoinHeaderView(
                            title: #localize("multi_device_join_linked_successfully_title"),
                            description: String.localizedStringWithFormat(
                                #localize("multi_device_join_linked_successfully_info"),
                                TargetManager.appName
                            )
                        )
                        
                        Spacer()
                        Spacer()
                    }
                    .padding(24)
                    .frame(minHeight: geometryProxy.size.height)
                }
            }
            
            Spacer()
            
            // So far there is not exact button that matches the one used by system apps
            ThreemaButton(
                title: #localize("continue"),
                style: .borderedProminent,
                size: .fullWidth
            ) {
                showWizard = false
            }
            .padding([.horizontal, .bottom], 24)
        }
        .navigationBarBackButtonHidden()
    }
}

struct DeviceJoinSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeviceJoinSuccessView(showWizard: .constant(true))
        }
    }
}
