import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct WorkReferralView: View {
    
    private let shareText: String = {
        let urlString = ThreemaURLProvider.workReferralInviteURL
        let text = #localize("work_referral_share_text")
        return text + " " + urlString.absoluteString
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(#localize("work_referral_view_main_title"))
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.leading)
                
                // Image
                
                GroupBox {
                    Image(systemName: "gift")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity)
                        .frame(height: 175)
                        .foregroundStyle(.white)
                }
                .backgroundStyle(
                    UIColor.primaryColorWork
                        .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).color
                )
                
                // How it works
                VStack(alignment: .leading, spacing: 16) {
                    Text(#localize("work_referral_view_section_info_title"))
                        .font(.headline)
                        .bold()
                   
                    GroupBox {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "person.badge.plus")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(#localize("work_referral_view_section_info_referral_title"))
                                    .font(.headline)
                                Text(#localize("work_referral_view_section_info_referral_text"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)

                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(#localize("work_referral_view_section_info_rec_title"))
                                    .font(.headline)
                                Text(#localize("work_referral_view_section_info_rec_text"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)

                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "checkmark.shield")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(#localize("work_referral_view_section_info_confirmation_title"))
                                    .font(.headline)
                                Text(#localize("work_referral_view_section_info_confirmation_text"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Reward
                VStack(alignment: .leading, spacing: 16) {
                    Text(#localize("work_referral_view_section_reward_title"))
                        .font(.headline)
                        .bold()
                    
                    GroupBox {
                        VStack(spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "gift")
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(#localize("work_referral_view_section_bonus_title"))
                                        .font(.headline)
                                    Text(#localize("work_referral_view_section_bonus_message"))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Buttons
                VStack(spacing: 16) {
                    ShareLink(item: shareText) {
                        Text(#localize("work_referral_view_share_button_title"))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Colors.textProminentButton.color)
                            .padding()
                            .frame(maxWidth: 400)
                            .background(UIColor.primaryColorWork.color)
                            .cornerRadius(12)
                    }
                    
                    NavigationLink {
                        uiViewController(SettingsWebViewViewController(
                            url: ThreemaURLProvider.workReferralToSURL,
                            title: #localize("work_referral_view_share_terms_title"),
                            allowsContentJavaScript: true
                        ))
                    } label: {
                        Text(#localize("work_referral_view_share_terms_title"))
                    }
                    .foregroundColor(UIColor.primaryColorWork.color)
                }
            }
            .frame(maxWidth: .infinity)
            .safeAreaPadding()
        }
        .background(.background.secondary)
    }
}

#Preview {
    NavigationView {
        WorkReferralView()
    }
}
