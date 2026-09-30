// HeavenlyPad/App/ContentView.swift
import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    let emulator = Emulator()
    @State private var showSettings = false
    @State private var visualDelayMs: Double = 0.0
    
    @State private var isBooted = false
    
    private var romPath: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("HeavenlyPad")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        return appSupport.appendingPathComponent("game.nds")
    }
    
    var body: some View {
        ZStack {
            if isBooted {
                MetalViewRepresentable(emulator: emulator, visualDelayMs: $visualDelayMs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .padding()
                    Text("Welcome to HeavenlyPad")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.bottom)
                    Button("Select Nintendo DS Rythm Heaven ROM...") {
                        openROM()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
            
            VStack {
                HStack {
                    Spacer()
                    if isBooted {
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white)
                                .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                if showSettings {
                    VStack(alignment: .leading) {
                        Text("Calibration (AirPods Sync)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Delay Video: \(Int(visualDelayMs)) ms")
                            .foregroundColor(.gray)
                        Slider(value: $visualDelayMs, in: 0...200, step: 10) { _ in }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .frame(width: 250)
                    .padding(.trailing, 20)
                }
                Spacer()
                if isBooted {
                    Text("Click window to lock cursor. Press ESC to unlock.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding()
                }
            }
        }
        .onAppear {
            if FileManager.default.fileExists(atPath: romPath.path) {
                do {
                    try emulator.boot(romURL: romPath)
                    isBooted = true
                    print("Auto-booted saved ROM")
                } catch {
                    print("Failed to auto-boot ROM: \(error)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func openROM() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType("public.data")!] // or specify .nds
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                if FileManager.default.fileExists(atPath: romPath.path) {
                    try FileManager.default.removeItem(at: romPath)
                }
                try FileManager.default.copyItem(at: url, to: romPath)
                try emulator.boot(romURL: romPath)
                isBooted = true
                print("Successfully saved and booted ROM: \(url.lastPathComponent)")
            } catch {
                print("Failed to boot ROM: \(error)")
            }
        }
    }
}

struct MetalViewRepresentable: NSViewRepresentable {
    let emulator: Emulator
    @Binding var visualDelayMs: Double
    
    class Coordinator {
        var renderer: MetalRenderer?
        var displayLink: CVDisplayLink?
        var emulator: Emulator?
        var mtkView: MTKView?
        var lastTime: TimeInterval = CACurrentMediaTime()
        var unprocessedTime: TimeInterval = 0.0
        var isRunning = true
        var visualDelayMs: Binding<Double>?
        
        struct QueuedFrame {
            let engineA: [UInt32]
            let engineB: [UInt32]
        }
        var frameQueue: [QueuedFrame] = []
        
        func startEmulatorThread() {
            Thread {
                Thread.current.qualityOfService = .userInteractive
                while self.isRunning {
                    guard let emu = self.emulator else {
                        usleep(1000)
                        continue
                    }
                    
                    let bufferedAudioFrames = emu.audioEngine.ringBuffer.count / 2
                    
                    // Safe latency target: 1024 frames (~30ms latency)
                    if bufferedAudioFrames < 1024 {
                        emu.executeFrame()
                        
                        // Copy framebuffer to queue
                        let frameA = Array(UnsafeBufferPointer(start: emu.gpu.engineA.framebuffer, count: 256 * 192))
                        let frameB = Array(UnsafeBufferPointer(start: emu.gpu.engineB.framebuffer, count: 256 * 192))
                        
                        // We must protect the array since it's read from the main thread
                        DispatchQueue.main.async {
                            self.frameQueue.append(QueuedFrame(engineA: frameA, engineB: frameB))
                        }
                    } else {
                        usleep(1000)
                    }
                }
            }.start()
        }
        
        deinit {
            isRunning = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        
        if let layer = mtkView.layer as? CAMetalLayer {
            layer.displaySyncEnabled = false
            layer.maximumDrawableCount = 2
        }
        
        // Lock window aspect ratio to 3:2 (side-by-side DS screens rotated)
        DispatchQueue.main.async {
            if let window = mtkView.window {
                window.contentAspectRatio = NSSize(width: 384, height: 256)
            }
        }
        
        if let renderer = MetalRenderer(mtkView: mtkView) {
            mtkView.delegate = renderer
            context.coordinator.renderer = renderer
        }
        
        let trackpadView = TrackpadView(emulator: emulator)
        trackpadView.frame = mtkView.bounds
        trackpadView.autoresizingMask = [.width, .height]
        mtkView.addSubview(trackpadView)
        
        CVDisplayLinkCreateWithActiveCGDisplays(&context.coordinator.displayLink)
        if let displayLink = context.coordinator.displayLink {
            let callback: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext in
                let coordinator = Unmanaged<Coordinator>.fromOpaque(displayLinkContext!).takeUnretainedValue()
                
                DispatchQueue.main.async {
                    let delayMs = coordinator.visualDelayMs?.wrappedValue ?? 0.0
                    let targetFrames = Int((delayMs / 1000.0) * 60.0)
                    
                    if coordinator.frameQueue.count > targetFrames {
                        let frame = coordinator.frameQueue.removeFirst()
                        
                        if let renderer = coordinator.renderer {
                            frame.engineA.withUnsafeBufferPointer { ptrA in
                                frame.engineB.withUnsafeBufferPointer { ptrB in
                                    renderer.updateTextures(engineA: ptrA.baseAddress!, engineB: ptrB.baseAddress!)
                                }
                            }
                        }
                        
                        coordinator.mtkView?.draw()
                    }
                }
                
                return kCVReturnSuccess
            }
            
            context.coordinator.emulator = emulator
            context.coordinator.mtkView = mtkView
            context.coordinator.visualDelayMs = _visualDelayMs
            context.coordinator.startEmulatorThread()
            
            CVDisplayLinkSetOutputCallback(displayLink, callback, Unmanaged.passUnretained(context.coordinator).toOpaque())
            CVDisplayLinkStart(displayLink)
        }
        
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
    }
}

// Invisible overlay to catch AppKit NSEvents for trackpad
class TrackpadView: NSView {
    let emulator: Emulator
    let digitizer = TrackpadDigitizer()
    var isLocked = false
    
    init(emulator: Emulator) {
        self.emulator = emulator
        super.init(frame: .zero)
        self.allowedTouchTypes = [.direct, .indirect]
        self.wantsRestingTouches = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    func toggleLock() {
        isLocked.toggle()
        if isLocked {
            NSCursor.hide()
            CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        } else {
            NSCursor.unhide()
            CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if !isLocked {
            toggleLock()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            if isLocked { toggleLock() }
        }
    }
    
    override func touchesBegan(with event: NSEvent) {
        digitizer.processEvent(event, touchscreen: emulator.touchscreen, view: self)
    }
    
    override func touchesMoved(with event: NSEvent) {
        digitizer.processEvent(event, touchscreen: emulator.touchscreen, view: self)
    }
    
    override func touchesEnded(with event: NSEvent) {
        digitizer.processEvent(event, touchscreen: emulator.touchscreen, view: self)
    }
    
    override func touchesCancelled(with event: NSEvent) {
        digitizer.processEvent(event, touchscreen: emulator.touchscreen, view: self)
    }
}
