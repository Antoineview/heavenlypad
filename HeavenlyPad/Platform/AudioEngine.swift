import Foundation
import AudioToolbox

/// Core Audio output engine using a lock-free ring buffer.
public final class AudioEngine {
    private var audioUnit: AudioUnit?
    public let ringBuffer: RingBuffer<Float>
    
    public init(sampleRate: Double = 32768.0) {
        // Buffer of 4096 samples (~60ms) to guarantee no crackling
        self.ringBuffer = RingBuffer<Float>(capacity: 4096)
        setupAudioUnit(sampleRate: sampleRate)
    }
    
    private func setupAudioUnit(sampleRate: Double) {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_DefaultOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        guard let component = AudioComponentFindNext(nil, &desc) else { return }
        AudioComponentInstanceNew(component, &audioUnit)
        guard let audioUnit = audioUnit else { return }
        
        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        
        AudioUnitSetProperty(audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &streamFormat,
                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var callbackStruct = AURenderCallbackStruct(
            inputProc: renderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        
        AudioUnitSetProperty(audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Global,
                             0,
                             &callbackStruct,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        AudioUnitInitialize(audioUnit)
    }
    
    public func start() {
        if let au = audioUnit {
            AudioOutputUnitStart(au)
        }
    }
    
    public func stop() {
        if let au = audioUnit {
            AudioOutputUnitStop(au)
        }
    }
}

private func renderCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let engine = Unmanaged<AudioEngine>.fromOpaque(inRefCon).takeUnretainedValue()
    guard let bufferList = ioData?.pointee,
          let buffer = bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self) else {
        return noErr
    }
    
    let frames = Int(inNumberFrames)
    let channels = 2
    
    for i in 0..<(frames * channels) {
        if let sample = engine.ringBuffer.pop() {
            buffer[i] = sample
        } else {
            buffer[i] = 0.0
        }
    }
    
    return noErr
}
