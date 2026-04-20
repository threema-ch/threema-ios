import SwiftUI

struct ProfilePictureDebugView: View {
    
    var body: some View {
        ScrollView {
            HStack(spacing: 0) {
                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "DD"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.systemBackground.color)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)

                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "0D"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.groupTableViewBackground.color)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
                
                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "SP"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.systemBackground.color)
                .environment(\.colorScheme, .dark)
                .preferredColorScheme(.dark)
                
                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "VW"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.groupTableViewBackground.color)
                .environment(\.colorScheme, .dark)
                .preferredColorScheme(.dark)
            }
            HStack {
                VStack {
                    Text(verbatim: "Directory Contact")
                    Image(uiImage: ProfilePictureGenerator.generateImage(for: .directoryContact, color: .black))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())

                    Text(verbatim: "Distribution List")
                    Image(uiImage: ProfilePictureGenerator.generateImage(for: .distributionList, color: .black))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())

                    Text(verbatim: "Gateway")
                    Image(uiImage: ProfilePictureGenerator.generateImage(for: .gateway, color: .black))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())

                    Text(verbatim: "Group")
                    Image(uiImage: ProfilePictureGenerator.generateImage(for: .group, color: .black))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())

                    Text(verbatim: "Me")
                    Image(uiImage: ProfilePictureGenerator.generateImage(for: .me, color: .black))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())

                    Text(verbatim: "Note Group")
                    Image(uiImage: ProfilePictureGenerator.generateImage(for: .noteGroup, color: .black))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                }
                .padding()
                .background(UIColor.systemBackground.color)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
            }
        }
        .navigationTitle(Text(verbatim: "New Profile Picture"))
    }
}

#Preview {
    ProfilePictureDebugView()
}
