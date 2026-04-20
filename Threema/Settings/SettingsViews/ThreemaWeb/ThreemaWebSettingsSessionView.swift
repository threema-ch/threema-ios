import SwiftUI
import ThreemaMacros

struct ThreemaWebSettingsSessionView: View {
    let session: WebClientSessionEntity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                leadingIcon
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionName)
                        .foregroundStyle(.primary)
                        .font(.body)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 0) {
                        if let last = session.lastConnection {
                            Text("\(#localize("webClientSession_lastUse")): \(DateFormatter.shortStyleDateTime(last))")
                        }
                        Text(savedString)
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(2)
                }

                Spacer(minLength: 8)

                if session.active?.boolValue == true {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .imageScale(.large)
                        .font(.title2)
                        .accessibilityHidden(true)
                }
                else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let assetName = mappedBrowserAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        else if isDesktopName {
            Image(systemName: "desktopcomputer")
                .resizable()
                .scaledToFit()
        }
        else if session.isConnecting {
            ProgressView().progressViewStyle(.circular)
        }
        else {
            Image(systemName: "exclamationmark.circle.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
        }
    }
    
    private var sessionName: String {
        if let name = session.name, !name.isEmpty {
            name
        }
        else {
            #localize("webClientSession_unnamed")
        }
    }

    private var savedString: String {
        session.permanent.boolValue ? #localize("webClientSession_saved")
            : #localize("webClientSession_notSaved")
    }

    private var mappedBrowserAssetName: String? {
        switch (session.browserName ?? "").lowercased() {
        case "chrome": "Chrome"
        case "safari": "Safari"
        case "firefox": "FireFox"
        case "edge": "Edge"
        case "opera": "Opera"
        default: nil
        }
    }

    private var isDesktopName: Bool {
        switch session.browserName ?? "" {
        case "macosThreemaDesktop", "win32ThreemaDesktop", "linuxThreemaDesktop":
            true
        default:
            false
        }
    }
}
