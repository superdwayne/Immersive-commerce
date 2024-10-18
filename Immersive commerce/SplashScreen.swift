// SplashScreen.swift
import SwiftUI

struct SplashScreen: View {
    var onGetStarted: () -> Void // Closure to handle button action

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen onboarding image
                Image("OnboardingImage") // Replace with your onboarding image name
                    .resizable()
                    .scaledToFill() // Scale to fill the entire space
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped() // Clip any overflow
                    .edgesIgnoringSafeArea(.all) // Ignore safe area to cover the entire screen

                // Overlay for text and button
                VStack {

                    // Text overlay
                    VStack(spacing: 10) {
                        Text("Your personal curated")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.black) // Set text color to black
                            .multilineTextAlignment(.center)

                        Text("selection awaits")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.black) // Set text color to black
                            .multilineTextAlignment(.center)

                        Text("Don't think, just do it")
                            .font(.headline)
                            .foregroundColor(.black) // Keep this text white
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Proceed button
                    Button(action: {
                        onGetStarted() // Call the closure when the button is tapped
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .foregroundColor(.white) // Set button text color to white
                            .cornerRadius(10)
                    }
                    .padding()
                }
                .padding(.bottom, 50) // Add some padding at the bottom
            }
        }
        .background(Color.white) // Background color for the splash screen
        .edgesIgnoringSafeArea(.all) // Ignore safe area to cover the entire screen
    }
}
