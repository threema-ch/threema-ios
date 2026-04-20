import SwiftUI

struct ButtonNavigation<Label: View>: View {
    @ScaledMetric var dynamicSpacing: CGFloat = 15

    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                ZStack {
                    label().padding(.trailing, dynamicSpacing)
                    NavigationLink(destination: EmptyView()) {
                        EmptyView()
                    }
                }
            }
            .tint(Color.primary)
        }
    }
}

#if DEBUG

    #Preview {
        List {
            Section {
                ButtonNavigation {
                    // no-op
                } label: {
                    HStack {
                        Text(verbatim: "Label")
                        Spacer()
                    }
                }

                ButtonNavigation {
                    // no-op
                } label: {
                    HStack {
                        Text(verbatim: "Label")
                        Spacer()
                        Text(verbatim: "Value")
                            .foregroundStyle(.secondary)
                    }
                }

                ButtonNavigation {
                    // no-op
                } label: {
                    HStack {
                        Text(verbatim: "Label")
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

#endif
