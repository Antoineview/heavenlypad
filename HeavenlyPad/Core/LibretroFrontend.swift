import Foundation
import CLibretro

// Global references for C callbacks
private var globalFrontend: LibretroFrontend? = nil
private var sharedEmulator: Emulator? = nil

// C callbacks
private func envCallback(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    return globalFrontend?.handleEnvironment(cmd: cmd, data: data) ?? false
}

private func videoCallback(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
    globalFrontend?.handleVideoRefresh(data: data, width: width, height: height, pitch: pitch)
}

private func audioCallback(left: Int16, right: Int16) {
    if let ringBuffer = sharedEmulator?.audioEngine.ringBuffer {
        ringBuffer.push(Float(left) / 32768.0)
        ringBuffer.push(Float(right) / 32768.0)
    }
}

private func audioBatchCallback(data: UnsafePointer<Int16>?, frames: Int) -> Int {
    guard let data = data, let ringBuffer = sharedEmulator?.audioEngine.ringBuffer else { return 0 }
    for i in 0..<frames {
        let left = data[i * 2]
        let right = data[i * 2 + 1]
        ringBuffer.push(Float(left) / 32768.0)
        ringBuffer.push(Float(right) / 32768.0)
    }
    return frames
}

private func inputPollCallback() {
}

private func inputStateCallback(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
    return globalFrontend?.handleInputState(port: port, device: device, index: index, id: id) ?? 0
}

public final class LibretroFrontend {
    private var handle: UnsafeMutableRawPointer?
    private var isGameLoaded = false
    
    typealias retro_init_t = @convention(c) () -> Void
    typealias retro_deinit_t = @convention(c) () -> Void
    typealias retro_api_version_t = @convention(c) () -> UInt32
    typealias retro_get_system_info_t = @convention(c) (UnsafeMutablePointer<retro_system_info>) -> Void
    typealias retro_get_system_av_info_t = @convention(c) (UnsafeMutablePointer<retro_system_av_info>) -> Void
    typealias retro_set_environment_t = @convention(c) (@convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool) -> Void
    typealias retro_set_video_refresh_t = @convention(c) (@convention(c) (UnsafeRawPointer?, UInt32, UInt32, Int) -> Void) -> Void
    typealias retro_set_audio_sample_t = @convention(c) (@convention(c) (Int16, Int16) -> Void) -> Void
    typealias retro_set_audio_sample_batch_t = @convention(c) (@convention(c) (UnsafePointer<Int16>?, Int) -> Int) -> Void
    typealias retro_set_input_poll_t = @convention(c) (@convention(c) () -> Void) -> Void
    typealias retro_set_input_state_t = @convention(c) (@convention(c) (UInt32, UInt32, UInt32, UInt32) -> Int16) -> Void
    typealias retro_load_game_t = @convention(c) (UnsafePointer<retro_game_info>) -> Bool
    typealias retro_unload_game_t = @convention(c) () -> Void
    typealias retro_run_t = @convention(c) () -> Void
    
    var retro_init: retro_init_t!
    var retro_deinit: retro_deinit_t!
    var retro_api_version: retro_api_version_t!
    var retro_get_system_info: retro_get_system_info_t!
    var retro_get_system_av_info: retro_get_system_av_info_t!
    var retro_set_environment: retro_set_environment_t!
    var retro_set_video_refresh: retro_set_video_refresh_t!
    var retro_set_audio_sample: retro_set_audio_sample_t!
    var retro_set_audio_sample_batch: retro_set_audio_sample_batch_t!
    var retro_set_input_poll: retro_set_input_poll_t!
    var retro_set_input_state: retro_set_input_state_t!
    var retro_load_game: retro_load_game_t!
    var retro_unload_game: retro_unload_game_t!
    var retro_run: retro_run_t!
    
    unowned var emulator: Emulator
    
    init(emulator: Emulator) {
        self.emulator = emulator
        globalFrontend = self
        sharedEmulator = emulator
        loadCore()
    }
    
    deinit {
        close()
    }

    func close() {
        guard let handle else { return }
        if isGameLoaded {
            retro_unload_game()
            isGameLoaded = false
        }
        retro_deinit()
        dlclose(handle)
        self.handle = nil
        if globalFrontend === self {
            globalFrontend = nil
            sharedEmulator = nil
        }
    }
    
    private func loadCore() {
        guard let dylibURL = Bundle.main.privateFrameworksURL?.appendingPathComponent("melonds_libretro.dylib") else {
            fatalError("Could not find the app's Frameworks directory")
        }
        let dylibPath = dylibURL.path
        
        handle = dlopen(dylibPath, RTLD_NOW | RTLD_LOCAL)
        guard let handle = handle else {
            if let err = dlerror() {
                fatalError("Failed to load core: \(String(cString: err))")
            }
            fatalError("Failed to load core")
        }
        
        func bind<T>(_ symbol: String) -> T {
            guard let sym = dlsym(handle, symbol) else {
                fatalError("Failed to bind symbol: \(symbol)")
            }
            return unsafeBitCast(sym, to: T.self)
        }
        
        retro_init = bind("retro_init")
        retro_deinit = bind("retro_deinit")
        retro_api_version = bind("retro_api_version")
        retro_get_system_info = bind("retro_get_system_info")
        retro_get_system_av_info = bind("retro_get_system_av_info")
        retro_set_environment = bind("retro_set_environment")
        retro_set_video_refresh = bind("retro_set_video_refresh")
        retro_set_audio_sample = bind("retro_set_audio_sample")
        retro_set_audio_sample_batch = bind("retro_set_audio_sample_batch")
        retro_set_input_poll = bind("retro_set_input_poll")
        retro_set_input_state = bind("retro_set_input_state")
        retro_load_game = bind("retro_load_game")
        retro_unload_game = bind("retro_unload_game")
        retro_run = bind("retro_run")
        
        retro_set_environment(envCallback)
        retro_set_video_refresh(videoCallback)
        retro_set_audio_sample(audioCallback)
        retro_set_audio_sample_batch(audioBatchCallback)
        retro_set_input_poll(inputPollCallback)
        retro_set_input_state(inputStateCallback)
        
        retro_init()
    }
    
    func load(romURL: URL) throws {
        let path = romURL.path
        let pathString = strdup(path)
        defer { free(pathString) }
        
        let data = try Data(contentsOf: romURL)
        var info = retro_game_info()
        info.path = UnsafePointer(pathString)
        
        try data.withUnsafeBytes { buffer in
            info.data = buffer.baseAddress
            info.size = data.count
            info.meta = nil
            
            if !retro_load_game(&info) {
                fatalError("Failed to load game")
            }
            isGameLoaded = true
        }
    }
    
    func runFrame() {
        retro_run()
    }
    
    // Callbacks implementation
    fileprivate func handleEnvironment(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
        switch cmd {
        case UInt32(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY), UInt32(RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY):
            if let data = data {
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                if let docDir = paths.first {
                    let saveDir = docDir.appendingPathComponent("HeavenlyPad_Saves")
                    try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true, attributes: nil)
                    let ptr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                    ptr.pointee = UnsafePointer(strdup(saveDir.path))
                }
            }
            return true
        case UInt32(RETRO_ENVIRONMENT_GET_VARIABLE):
            if let data = data {
                let v = data.assumingMemoryBound(to: retro_variable.self)
                if let keyPtr = v.pointee.key {
                    let key = String(cString: keyPtr)
                    if key == "melonds_boot_directly" {
                        v.pointee.value = UnsafePointer(strdup("true"))
                        return true
                    } else if key == "melonds_touch_mode" {
                        v.pointee.value = UnsafePointer(strdup("Touch"))
                        return true
                    }
                }
            }
            return false
            
        case UInt32(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT):
            if let data = data {
                let format = data.assumingMemoryBound(to: UInt32.self)
                // Set to RETRO_PIXEL_FORMAT_XRGB8888 (1)
                format.pointee = 1
            }
            return true
        default:
            return false
        }
    }
    
    fileprivate func handleVideoRefresh(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
        guard let data = data else { return }
        
        let src = data.assumingMemoryBound(to: UInt32.self)
        let pitchWords = pitch / 4
        
        // Expected total height 384, top 192 for engine A, bottom 192 for engine B
        let actualHeight = min(Int(height), 384)
        let actualWidth = min(Int(width), 256)
        
        for y in 0..<192 {
            if y < actualHeight {
                let srcRowA = src.advanced(by: y * pitchWords)
                let destOffset = y * 256
                for x in 0..<actualWidth {
                    emulator.gpu.engineA.framebuffer[destOffset + x] = srcRowA[x] | 0xFF000000
                }
            }
        }
        
        if actualHeight > 192 {
            for y in 0..<192 {
                let ySource = y + 192
                if ySource < actualHeight {
                    let srcRowB = src.advanced(by: ySource * pitchWords)
                    let destOffset = y * 256
                    for x in 0..<actualWidth {
                        emulator.gpu.engineB.framebuffer[destOffset + x] = srcRowB[x] | 0xFF000000
                    }
                }
            }
        }
    }
    
    fileprivate func handleInputState(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
        if device == 6 {
            switch id {
            case 2: // PRESSED
                return emulator.touchscreen.isPressed ? 1 : 0
            case 0: // X
                if emulator.touchscreen.isPressed {
                    let x = Double(emulator.touchscreen.screenX)
                    return Int16((x / 255.0) * 65534.0 - 32767.0)
                }
                return 0
            case 1: // Y
                if emulator.touchscreen.isPressed {
                    let y = Double(emulator.touchscreen.screenY)
                    return Int16((y / 191.0) * 32767.0)
                }
                return 0
            default:
                return 0
            }
        }
        
        // Print other devices being polled (throttle to avoid spam)
        if Int.random(in: 0..<100) == 0 {
            print("Poll port: \(port), device: \(device), id: \(id)")
        }
        return 0
    }
}
