import SwiftUI
import DynamicSDKSwift

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var imageScale: CGFloat = 1.2

    var body: some View {
        ZStack {
            Image("Robot")
                .resizable()
                .scaledToFill()
                .scaleEffect(imageScale)
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                        imageScale = 1.0
                    }
                }

            LinearGradient(
                colors: [.clear, .black.opacity(0.8), .black],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Button {
                        do {
                            try DynamicSDK.shared.ui.showAuth()
                        } catch {
                            print("Error showing auth: \(error)")
                        }
                    } label: {
                        Text("Sign in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
