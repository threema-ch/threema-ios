import SwiftUI
import ThreemaFramework

struct ThreemaButtonView: View {
    @State private var animateGradient = false
    @State private var color1: Color = .black
    @State private var color2: Color = .red
    @State private var color3: Color = .yellow
   
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ThreemaButton(title: "Full Bordered Prominent", style: .borderedProminent, size: .fullWidth) { }
                ThreemaButton(title: "Small BP", style: .borderedProminent, size: .small) { }
                ThreemaButton(title: "Disabled", style: .borderedProminent, size: .small) { }.disabled(true)
                
                ThreemaButton(title: "Full Bordered", style: .bordered, size: .fullWidth) { }
                ThreemaButton(title: "Small B", style: .bordered, size: .small) { }
                ThreemaButton(title: "Disabled", style: .bordered, size: .small) { }.disabled(true)
                
                ThreemaButton(title: "Full Borderless", style: .borderless, size: .fullWidth) { }
                ThreemaButton(title: "Small BL", style: .borderless, size: .small) { }
                ThreemaButton(title: "Disabled", style: .borderless, size: .small) { }.disabled(true)
                
                ThreemaButton(title: "Full Plain", style: .plain, size: .fullWidth) { }
                ThreemaButton(title: "Small P", style: .plain, size: .small) { }
                ThreemaButton(title: "Disabled", style: .plain, size: .small) { }.disabled(true)
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(
            LinearGradient(
                stops: [
                    .init(color: color1, location: 0),
                    .init(color: color1, location: 0.25),
                    .init(color: color2, location: 0.45),
                    .init(color: color2, location: 0.55),
                    .init(color: color3, location: 0.75),
                    .init(color: color3, location: 1),
                ],
                startPoint: UnitPoint(x: animateGradient ? 0.5 : -1, y: animateGradient ? 0.5 : -0.5),
                endPoint: UnitPoint(x: animateGradient ? 2 : 0.5, y: animateGradient ? 1.5 : 0.5)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: false)) {
                    animateGradient.toggle()
                }
            }
            .ignoresSafeArea()
        )
    }
}

#Preview {
    ThreemaButtonView()
}
