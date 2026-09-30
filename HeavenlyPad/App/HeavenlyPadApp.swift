// HeavenlyPad/App/HeavenlyPadApp.swift
import SwiftUI
import AppKit

final class HeavenlyPadAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct HeavenlyPadApp: App {
    @NSApplicationDelegateAdaptor(HeavenlyPadAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("HeavenlyPad") {
            ContentView()
        }
        .defaultSize(width: 768, height: 512)
    }
}
