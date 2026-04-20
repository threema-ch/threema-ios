import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct WorkReferralCellView: View {
    
    let imageWidth: CGFloat = 100
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text(#localize("work_referral_cell_title"))
                    .font(.title3.bold())
                
                HStack {
                    Text(#localize("work_referral_cell_message"))
                    Spacer(minLength: imageWidth * 0.6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            
            Image(systemName: "gift")
                .resizable()
                .frame(width: imageWidth, height: imageWidth)
                .foregroundStyle(UIColor(red: 0, green: 0.329, blue: 0.627, alpha: 1).color)
                .offset(x: 48, y: 7)
        }
    }
}

#Preview {
    NavigationView {
        List {
            Section {
                NavigationLink {
                    EmptyView()
                } label: {
                    WorkReferralCellView()
                }
                .listRowBackground(
                    UIColor.primaryColorWork
                        .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).color
                )
            }
        }
    }
}
