import SwiftUI

struct NotificationTypeView: View {
    @Binding var selectedType: NotificationType
    @Binding var showPreview: Bool
    
    let notificationType: NotificationType
    let inApp: Bool

    private let cornerRadius = 20.0
    private let padding = 16.0
    
    var body: some View {
        VStack {
            NotificationTypeTitleView(selectedType: $selectedType, notificationType: notificationType)
                .padding(.bottom, 10)
            
            NotificationTypeNotificationView(
                showPreview: $showPreview, notificationType: notificationType,
                cornerRadius: cornerRadius - (padding / 2), inApp: inApp
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                selectedType = notificationType
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct NotificationTypeView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationTypeView(
            selectedType: .constant(.restrictive),
            showPreview: .constant(true),
            notificationType: .restrictive,
            inApp: false
        )
        .background(.red)
        .frame(maxHeight: 200)
    }
}

struct NotificationTypeTitleView: View {
    @Binding var selectedType: NotificationType
    
    let notificationType: NotificationType

    var body: some View {
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(notificationType.previewTitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(notificationType.previewDescription))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            if selectedType == notificationType {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.large)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
            }
            else {
                Image(systemName: "circle")
                    .imageScale(.large)
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
    }
}

// MARK: - NotificationTypeNotificationView

struct NotificationTypeNotificationView: View {
    @Binding var showPreview: Bool
    let notificationType: NotificationType
    let cornerRadius: Double
    let inApp: Bool

    @ViewBuilder var notificationImageView: some View {
        switch notificationType {
        case .restrictive, .balanced:
            Image(uiImage: AppIcon.default.preview)
                .resizable()
                .scaledToFit()
                .opacity(0.4)
                .cornerRadius(12)
                .frame(maxWidth: 44)
            
        case .complete:
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .opacity(0.4)
                    .cornerRadius(12)
                    .frame(maxWidth: 44)
                if !inApp {
                    Image(uiImage: AppIcon.default.preview)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(4)
                        .frame(width: 16)
                        .offset(x: 2, y: 2)
                }
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            notificationImageView
        
            VStack(alignment: .leading, spacing: 2) {
                Text(notificationType.previewSenderName)
                    .font(.headline)
                Text(
                    showPreview ? notificationType
                        .previewMessageTextWithPreviewOn : notificationType.previewMessageTextWithPreviewOff
                )
                .font(.callout)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2]))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
    }
}
