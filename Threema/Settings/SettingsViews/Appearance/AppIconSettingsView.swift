import CocoaLumberjackSwift
import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct AppIconSettingsView: View {
    @State var currentlySelected = UIApplication.shared.alternateIconName
    
    var body: some View {
        
        List {
            Section {
                ForEach(AppIcon.defaultIcon, id: \.self) { icon in
                    AppIconMenuItem(icon: icon, currentlySelected: $currentlySelected)
                }
            }
            header: {
                Text(#localize("settings_appicon_default_header"))
            }
            
            Section {
                ForEach(AppIcon.baseIcons, id: \.self) { icon in
                    AppIconMenuItem(icon: icon, currentlySelected: $currentlySelected)
                }
            } header: {
                Text(String.localizedStringWithFormat(
                    #localize("settings_appicon_legacy_header"),
                    TargetManager.localizedAppName
                ))
            }
            
            Section {
                ForEach(AppIcon.specialIcons, id: \.self) { icon in
                    AppIconMenuItem(icon: icon, currentlySelected: $currentlySelected)
                }
            } header: {
                Text(#localize("settings_appicon_special_header"))
            }
            .navigationTitle(
                Text(#localize("settings_appearance_hide_app_icon"))
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppIconSettingsView()
        }
    }
}

struct AppIconMenuItem: View {
    
    var icon: AppIcon
    @Binding var currentlySelected: String?
    
    var body: some View {
        HStack {
            Image(uiImage: icon.preview)
                .resizable()
                .scaledToFit()
                .frame(width: 75, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .padding(.trailing)
            
            VStack(alignment: .leading) {
                Text(icon.displayTitle)
                Text(icon.displayInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if icon.iconName == currentlySelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .imageScale(.large)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            setIcon(icon: icon)
        }
    }
    
    private func setIcon(icon: AppIcon) {
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(icon.iconName)
                currentlySelected = icon.iconName
            }
            catch {
                DDLogError(
                    "Error setting alternate icon: \(icon.iconName ?? "default"). Desc: \(error.localizedDescription)"
                )
            }
        }
    }
}
