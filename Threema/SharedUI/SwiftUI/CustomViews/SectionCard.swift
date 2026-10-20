import SwiftUI

/// Groups content on an inset card, with an optional header above and footer below it.
///
/// Mirrors a grouped `List` section for screens that are laid out with a `ScrollView` instead of a `List`
struct SectionCard<Content: View, Header: View, Footer: View>: View {
    private let content: Content
    private let header: Header
    private let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        VStack {
            if hasHeader {
                header
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
            }

            content
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground), in: shape)
                .overlay {
                    shape.strokeBorder(Color(.separator), lineWidth: 1)
                }

            if hasFooter {
                footer
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
            }
        }
        .padding(.bottom, 12)
    }

    private var hasHeader: Bool {
        Header.self != EmptyView.self
    }

    private var hasFooter: Bool {
        Footer.self != EmptyView.self
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26)
    }
}

extension SectionCard where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.init(content: content, header: header, footer: { EmptyView() })
    }
}

extension SectionCard where Header == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(content: content, header: { EmptyView() }, footer: footer)
    }
}

extension SectionCard where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, header: { EmptyView() }, footer: { EmptyView() })
    }
}

#if DEBUG
    #Preview {
        ScrollView {
            VStack(spacing: 10) {
                SectionCard {
                    Text(verbatim: "Content")
                } header: {
                    Text(verbatim: "Header and footer")
                } footer: {
                    Text(verbatim: "A footer explaining what the section above does.")
                }

                SectionCard {
                    Text(verbatim: "Content")
                } header: {
                    Text(verbatim: "Header only")
                }

                SectionCard {
                    Text(verbatim: "Content")
                } footer: {
                    Text(verbatim: "Footer only.")
                }

                SectionCard {
                    Toggle(isOn: .constant(true)) {
                        Text(verbatim: "Neither header nor footer")
                    }
                }
            }
            .safeAreaPadding(.horizontal, 20)
        }
        .background(Color.listsBackgroundColor.ignoresSafeArea())
    }
#endif
