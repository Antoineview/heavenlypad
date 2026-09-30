import Foundation
import MetalKit

public final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    
    private let textureA: MTLTexture
    private let textureB: MTLTexture
    
    private let vertexData: [Float] = [
        // x, y, u, v
        // Left screen (Engine A, rotated 90 degrees CCW)
        // Mac Bottom-Left (-1, -1) -> DS Top-Left (0, 0)
        -1.0, -1.0,  0.0, 0.0,
        // Mac Top-Left (-1, 1) -> DS Top-Right (1, 0)
        -1.0,  1.0,  1.0, 0.0,
        // Mac Bottom-Right (0, -1) -> DS Bottom-Left (0, 1)
         0.0, -1.0,  0.0, 1.0,
        // Mac Top-Right (0, 1) -> DS Bottom-Right (1, 1)
         0.0,  1.0,  1.0, 1.0,
        
        // Right screen (Engine B, rotated 90 degrees CCW)
         0.0, -1.0,  0.0, 0.0,
         0.0,  1.0,  1.0, 0.0,
         1.0, -1.0,  0.0, 1.0,
         1.0,  1.0,  1.0, 1.0,
    ]
    
    private let vertexBuffer: MTLBuffer
    
    public init?(mtkView: MTKView) {
        guard let device = mtkView.device else { return nil }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        // Inline Shaders
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position;
            float2 texCoord;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertexShader(const device float4* vertexArray [[buffer(0)]],
                                      uint vertexID [[vertex_id]]) {
            VertexOut out;
            out.position = float4(vertexArray[vertexID].xy, 0.0, 1.0);
            out.texCoord = vertexArray[vertexID].zw;
            return out;
        }

        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                       texture2d<float> texture [[texture(0)]]) {
            constexpr sampler textureSampler (mag_filter::nearest,
                                              min_filter::nearest);
            return texture.sample(textureSampler, in.texCoord);
        }
        """
        
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("Failed to compile shaders: \\(error)")
            return nil
        }
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
        }
        
        // Create textures for the two screens (256x192)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                         width: 256,
                                                                         height: 192,
                                                                         mipmapped: false)
        guard let texA = device.makeTexture(descriptor: textureDescriptor),
              let texB = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        self.textureA = texA
        self.textureB = texB
        
        guard let vBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: []) else { return nil }
        self.vertexBuffer = vBuffer
        
        super.init()
    }
    
    public func updateTextures(engineA: UnsafePointer<UInt32>, engineB: UnsafePointer<UInt32>) {
        let region = MTLRegionMake2D(0, 0, 256, 192)
        let bytesPerRow = 256 * 4
        
        textureA.replace(region: region, mipmapLevel: 0, withBytes: engineA, bytesPerRow: bytesPerRow)
        textureB.replace(region: region, mipmapLevel: 0, withBytes: engineB, bytesPerRow: bytesPerRow)
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Draw Left Screen (Engine A)
        renderEncoder.setFragmentTexture(textureA, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        // Draw Right Screen (Engine B)
        renderEncoder.setFragmentTexture(textureB, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 4, vertexCount: 4)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
