// HeavenlyPad/App/HeavenlyPadApp.swift
import SwiftUI

@main
struct HeavenlyPadApp: App {
    var body: some Scene {
        WindowGroup("HeavenlyPad") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 768, height: 512)
    }
}
