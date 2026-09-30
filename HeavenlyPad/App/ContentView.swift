// HeavenlyPad/App/ContentView.swift
import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers
import Atomics

struct ContentView: View {
    @State private var emulator = Emulator()
    @AppStorage("hasCompletedTrackpadTutorial") private var hasCompletedTrackpadTutorial = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @State private var visualDelayMs: Double = 0.0
    @State private var isBooted = false
    @State private var importError: String?
    
    private var romPath: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("HeavenlyPad")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        return appSupport.appendingPathComponent("game.nds")
    }
    
    var body: some View {
        Group {
            if isBooted {
                MetalViewRepresentable(emulator: emulator, visualDelayMs: $visualDelayMs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
            } else {
                landingView
            }
        }
        .frame(minWidth: 630, minHeight: 420)
        .toolbar {
            if isBooted {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .help("Display settings")
                    .accessibilityLabel("Display settings")
                    .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                        settingsView
                    }
                }
            }
        }
        .alert("Couldn't open the game", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Please try another .nds file.")
        }
        .sheet(isPresented: $showTutorial) {
            TrackpadTutorialView {
                hasCompletedTrackpadTutorial = true
                showTutorial = false
                bootSavedROMIfAvailable()
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            if hasCompletedTrackpadTutorial {
                bootSavedROMIfAvailable()
            } else {
                showTutorial = true
            }
        }
    }

    private func bootSavedROMIfAvailable() {
        guard !isBooted, FileManager.default.fileExists(atPath: romPath.path) else { return }
        do {
            try emulator.boot(romURL: romPath)
            isBooted = true
        } catch {
            importError = error.localizedDescription
        }
    }

    private var landingView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            HStack(spacing: 9) {
                screenSymbol
                screenSymbol
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            }
            .padding(.bottom, 32)
            .accessibilityHidden(true)

            Text("Open a Nintendo DS game")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.7)

            Text("Choose a .nds file to start playing.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 9)

            Button(action: openROM) {
                Label("Open Game…", systemImage: "folder")
                    .frame(minWidth: 124)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)
            .padding(.top, 28)

            Text("Your game is saved on this Mac for next time.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 13)

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var screenSymbol: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .textBackgroundColor))
            .frame(width: 86, height: 65)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Display")
                .font(.headline)

            HStack {
                Text("Video delay")
                Spacer()
                Text("\(Int(visualDelayMs)) ms")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)

            Slider(value: $visualDelayMs, in: 0...200, step: 10)
                .accessibilityLabel("Video delay")

            Text("Adjust the picture to match Bluetooth audio.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Trackpad tutorial…") {
                showSettings = false
                showTutorial = true
            }

            Divider()

            Label("Click the game to capture the cursor. Press Esc to release it.", systemImage: "cursorarrow")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 300)
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
                importError = error.localizedDescription
            }
        }
    }
}

private struct TrackpadTutorialView: View {
    let onComplete: () -> Void
    @State private var page = 0
    @State private var didFlick = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TRACKPAD GUIDE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(page + 1) of 2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: page == 0 ? "hand.point.up.left" : "hand.draw")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tint)
                .frame(height: 70, alignment: .bottom)
                .accessibilityHidden(true)

            Text(page == 0 ? "Your trackpad is the touch screen" : "Try a flick")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 18)

            if page == 0 {
                Text("Touch the trackpad with one finger to use the stylus. Slide to move it, then lift to release. You don't need to click.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 9)

                Divider().padding(.vertical, 20)

                tutorialRow("Tap", detail: "Touch briefly, then lift your finger.")
                tutorialRow("Focus", detail: "Click the game window once. Press Esc to release the cursor.")
                    .padding(.top, 12)
                tutorialRow("Rotate", detail: "Your movements follow the sideways game screen.")
                    .padding(.top, 12)
            } else {
                Text("Touch the trackpad, swipe quickly in one direction, and lift your finger right away.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 9)

                FlickPracticeView {
                    didFlick = true
                }
                .frame(height: 104)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
                .overlay {
                    Label(didFlick ? "Flick detected" : "Try it on your trackpad", systemImage: didFlick ? "checkmark.circle.fill" : "arrow.up.right")
                        .font(.subheadline)
                        .foregroundStyle(didFlick ? Color.green : Color.secondary)
                        .allowsHitTesting(false)
                }
                .padding(.top, 22)

                Text("Practice is optional. You can return here from Display Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }

            Spacer(minLength: 24)

            HStack {
                if page == 1 {
                    Button("Back") { page = 0 }
                }
                Spacer()
                Button(page == 0 ? "Continue" : "Start Playing") {
                    if page == 0 {
                        page = 1
                    } else {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 460, height: 390)
    }

    private func tutorialRow(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(title)
                .fontWeight(.medium)
                .frame(width: 54, alignment: .leading)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

private struct FlickPracticeView: NSViewRepresentable {
    let onFlick: () -> Void

    func makeNSView(context: Context) -> FlickPracticeNSView {
        let view = FlickPracticeNSView()
        view.onFlick = onFlick
        return view
    }

    func updateNSView(_ nsView: FlickPracticeNSView, context: Context) {
        nsView.onFlick = onFlick
    }
}

private final class FlickPracticeNSView: NSView {
    var onFlick: (() -> Void)?
    private var startPosition: NSPoint?
    private var startTime: TimeInterval = 0
    private var lastPosition: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .began, in: self).first else { return }
        startPosition = touch.normalizedPosition
        lastPosition = touch.normalizedPosition
        startTime = event.timestamp
    }

    override func touchesMoved(with event: NSEvent) {
        if let touch = event.touches(matching: .moved, in: self).first {
            lastPosition = touch.normalizedPosition
        }
    }

    override func touchesEnded(with event: NSEvent) {
        defer { startPosition = nil }
        guard let startPosition else { return }
        let end = event.touches(matching: .ended, in: self).first?.normalizedPosition ?? lastPosition ?? startPosition
        let distance = hypot(end.x - startPosition.x, end.y - startPosition.y)
        if distance > 0.12 && event.timestamp - startTime < 0.75 {
            onFlick?()
        }
    }

    override func touchesCancelled(with event: NSEvent) {
        startPosition = nil
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
        let isRunning = ManagedAtomic(true)
        private let workerFinished = DispatchSemaphore(value: 0)
        private var didStartWorker = false
        var visualDelayMs: Binding<Double>?
        
        struct QueuedFrame {
            let engineA: [UInt32]
            let engineB: [UInt32]
        }
        var frameQueue: [QueuedFrame] = []
        
        func startEmulatorThread() {
            didStartWorker = true
            Thread {
                Thread.current.qualityOfService = .userInteractive
                defer { self.workerFinished.signal() }
                while self.isRunning.load(ordering: .relaxed) {
                    guard let emu = self.emulator else {
                        usleep(1000)
                        continue
                    }
                    
                    let bufferedAudioFrames = emu.audioEngine.ringBuffer.count / 2
                    
                    // Safe latency target: 1024 frames (~30ms latency)
                    if bufferedAudioFrames < 1024 {
                        emu.executeFrame()
                        
                        // Copy framebuffer to queue
                        let frameA = emu.gpu.engineA.framebuffer.withUnsafeBufferPointer { Array($0) }
                        let frameB = emu.gpu.engineB.framebuffer.withUnsafeBufferPointer { Array($0) }
                        
                        // We must protect the array since it's read from the main thread
                        DispatchQueue.main.async {
                            if self.isRunning.load(ordering: .relaxed) {
                                self.frameQueue.append(QueuedFrame(engineA: frameA, engineB: frameB))
                            }
                        }
                    } else {
                        usleep(1000)
                    }
                }
            }.start()
        }

        func stop() {
            guard isRunning.exchange(false, ordering: .acquiringAndReleasing) else { return }
            if let displayLink {
                CVDisplayLinkStop(displayLink)
            }
            if didStartWorker {
                workerFinished.wait()
            }
            frameQueue.removeAll()
            emulator?.shutdown()
            renderer = nil
            mtkView = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = GameMTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        
        if let layer = mtkView.layer as? CAMetalLayer {
            layer.displaySyncEnabled = false
            layer.maximumDrawableCount = 2
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
                    guard coordinator.isRunning.load(ordering: .relaxed) else { return }
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

    static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        nsView.subviews.compactMap { $0 as? TrackpadView }.forEach { $0.unlockCursor() }
        coordinator.stop()
    }
}

// The toolbar is outside the game view, so constrain against the actual Metal
// view rather than the window's larger content rectangle.
private final class GameMTKView: MTKView {
    private var windowObservers: [NSObjectProtocol] = []
    private var sizeAtResizeStart: NSSize?
    private var isCorrectingSize = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        guard let window else { return }

        window.contentAspectRatio = .zero
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willStartLiveResizeNotification, object: window, queue: .main
        ) { [weak self] _ in
            self?.sizeAtResizeStart = self?.bounds.size
        })
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main
        ) { [weak self] _ in
            self?.fitWindowToGame()
            self?.sizeAtResizeStart = nil
        })
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: window, queue: .main
        ) { [weak self, weak window] _ in
            guard let window, !window.inLiveResize else { return }
            DispatchQueue.main.async { self?.fitWindowToGame() }
        })
        DispatchQueue.main.async { [weak self] in self?.fitWindowToGame() }
    }

    deinit {
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func fitWindowToGame() {
        guard let window, !isCorrectingSize, !window.inLiveResize,
              !window.styleMask.contains(.fullScreen) else { return }
        let gameSize = bounds.size
        guard gameSize.width > 0, gameSize.height > 0 else { return }
        let difference = gameSize.width - gameSize.height * 1.5
        guard abs(difference) > 1 else { return }

        var contentSize = window.contentRect(forFrameRect: window.frame).size
        let resizedMostlyHorizontally = sizeAtResizeStart.map {
            abs(gameSize.width - $0.width) > abs(gameSize.height - $0.height) * 1.5
        } ?? false
        if resizedMostlyHorizontally {
            contentSize.height += gameSize.width / 1.5 - gameSize.height
        } else {
            contentSize.width -= difference
        }
        isCorrectingSize = true
        window.setContentSize(contentSize)
        isCorrectingSize = false
    }
}

// Invisible overlay to catch AppKit NSEvents for trackpad
class TrackpadView: NSView {
    let emulator: Emulator
    let digitizer = TrackpadDigitizer()
    var isLocked = false
    private var windowObservers: [NSObjectProtocol] = []
    
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

    override func resignFirstResponder() -> Bool {
        unlockCursor()
        return super.resignFirstResponder()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        guard let window else {
            unlockCursor()
            return
        }
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                self?.unlockCursor()
            }
            windowObservers.append(observer)
        }
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.unlockCursor()
        })
    }

    deinit {
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        unlockCursor()
    }

    func unlockCursor() {
        guard isLocked else { return }
        isLocked = false
        NSCursor.unhide()
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }
    
    func toggleLock() {
        if isLocked {
            unlockCursor()
        } else {
            isLocked = true
            NSCursor.hide()
            CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if !isLocked {
            toggleLock()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            unlockCursor()
        } else {
            super.keyDown(with: event)
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
