// MyApp.swift
import SwiftUI

@main
struct home: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreen {
                    // Handle the button action to proceed to the main content
                    withAnimation {
                        showSplash = false
                    }
                }
            } else {
                ContentView() // Your main content view
            }
        }
    }
}
