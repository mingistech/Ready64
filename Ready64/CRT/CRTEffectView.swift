// Copyright (c) 2013-2021 Filippo Scognamiglio (cool-retro-term algorithms)
// Copyright (c) 2026 Brandon Thompson (Ready64 AppKit / Metal host)
//
// GPL-3.0-or-later — see LICENSE and NOTICE.

import AppKit
import MetalKit

/// Full-screen Metal CRT post-process overlay (cool-retro-term effect scaling).
final class CRTEffectView: MTKView {
    private struct Uniforms {
        var time: Float
        var screenCurvature: Float
        var rgbShift: Float
        var bloom: Float
        var staticNoise: Float
        var jitter: Float
        var jitterDisplacement: SIMD2<Float>
        var glowingLine: Float
        var flickering: Float
        var horizontalSync: Float
        var horizontalSyncStrength: Float
        var burnIn: Float
        var burnInLastUpdate: Float
        var burnInTime: Float
        var ambientLight: Float
        var frameShininess: Float
        var frameSize: Float
        var virtualResolution: SIMD2<Float>
        var noiseScale: SIMD2<Float>
        var contrast: Float
        var saturation: Float
    }

    private struct BurnInUniforms {
        var burnInLastUpdate: Float
        var burnInTime: Float
        var prevLastUpdate: Float
    }

    private struct BlurUniforms {
        var texelSize: SIMD2<Float>
        var direction: SIMD2<Float>
        var radius: Float
    }

    weak var sourceView: NSView?
    var parameters = CRTEffectParameters.default {
        didSet { syncPauseState() }
    }

    var effectActive = true {
        didSet { syncPauseState() }
    }

    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var burnInPipelineState: MTLRenderPipelineState?
    private var bloomPreparePipelineState: MTLRenderPipelineState?
    private var bloomBlurPipelineState: MTLRenderPipelineState?
    private var noiseTexture: MTLTexture?
    private var linearSampler: MTLSamplerState?
    private var noiseSampler: MTLSamplerState?
    private var burnInTextureA: MTLTexture?
    private var burnInTextureB: MTLTexture?
    private var burnInUseA = true
    private var bloomTextureA: MTLTexture?
    private var bloomTextureB: MTLTexture?
    private var startTime = CACurrentMediaTime()
    private var burnInLastUpdate: Float = 0
    private var burnInPrevUpdate: Float = 0

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 30
        autoResizeDrawable = true
        layer?.isOpaque = true

        guard let device else { return }
        commandQueue = device.makeCommandQueue()
        buildPipelines(device: device)
        buildSamplers(device: device)
        noiseTexture = Self.loadNoiseTexture(device: device)
        syncPauseState()
    }

    private func syncPauseState() {
        let on = parameters.isActive && effectActive
        isHidden = !on
        isPaused = !on
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        render()
    }

    private func buildPipelines(device: MTLDevice) {
        guard let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "crt_vertex")
        else { return }

        func makePipeline(fragment: String, format: MTLPixelFormat = .bgra8Unorm) -> MTLRenderPipelineState? {
            guard let frag = library.makeFunction(name: fragment) else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = frag
            descriptor.colorAttachments[0].pixelFormat = format
            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        pipelineState = makePipeline(fragment: "crt_fragment")
        burnInPipelineState = makePipeline(fragment: "burn_in_fragment")
        bloomPreparePipelineState = makePipeline(fragment: "bloom_prepare_fragment")
        bloomBlurPipelineState = makePipeline(fragment: "bloom_blur_fragment")
    }

    private func buildSamplers(device: MTLDevice) {
        let linear = MTLSamplerDescriptor()
        linear.minFilter = .linear
        linear.magFilter = .linear
        linear.sAddressMode = .clampToEdge
        linear.tAddressMode = .clampToEdge
        linearSampler = device.makeSamplerState(descriptor: linear)

        let noise = MTLSamplerDescriptor()
        noise.minFilter = .linear
        noise.magFilter = .linear
        noise.sAddressMode = .repeat
        noise.tAddressMode = .repeat
        noiseSampler = device.makeSamplerState(descriptor: noise)
    }

    private static func loadNoiseTexture(device: MTLDevice) -> MTLTexture? {
        let candidates = [
            Bundle.main.url(forResource: "allNoise512", withExtension: "png"),
            Bundle.main.url(forResource: "allNoise512", withExtension: "png", subdirectory: "ThirdParty/cool-retro-term/images")
        ].compactMap { $0 }

        guard let url = candidates.first,
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return makeFallbackNoiseTexture(device: device)
        }

        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(cgImage: cgImage, options: [
            .SRGB: false,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)
        ])
    }

    private static func makeFallbackNoiseTexture(device: MTLDevice) -> MTLTexture? {
        let size = 256
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let n = UInt8.random(in: 0...255)
            bytes[i * 4] = n
            bytes[i * 4 + 1] = UInt8.random(in: 0...255)
            bytes[i * 4 + 2] = UInt8.random(in: 0...255)
            bytes[i * 4 + 3] = n
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false
        )
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: bytes, bytesPerRow: size * 4)
        return texture
    }

    private func makeRenderTarget(width: Int, height: Int, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private func ensureBurnInTextures(width: Int, height: Int, device: MTLDevice) {
        if let a = burnInTextureA, a.width == width, a.height == height { return }
        burnInTextureA = makeRenderTarget(width: width, height: height, device: device)
        burnInTextureB = makeRenderTarget(width: width, height: height, device: device)
        burnInUseA = true
        burnInLastUpdate = 0
        burnInPrevUpdate = 0
    }

    private func ensureBloomTextures(sourceWidth: Int, sourceHeight: Int, device: MTLDevice) {
        let quality = CGFloat(CRTEffectParameters.bloomQuality)
        let width = max(Int((CGFloat(sourceWidth) * quality).rounded()), 1)
        let height = max(Int((CGFloat(sourceHeight) * quality).rounded()), 1)
        if let a = bloomTextureA, a.width == width, a.height == height { return }
        bloomTextureA = makeRenderTarget(width: width, height: height, device: device)
        bloomTextureB = makeRenderTarget(width: width, height: height, device: device)
    }

    private func encodeFullScreen(
        commandBuffer: MTLCommandBuffer,
        pipeline: MTLRenderPipelineState,
        destination: MTLTexture,
        clearAlpha: Double = 0,
        configure: (MTLRenderCommandEncoder) -> Void
    ) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = destination
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, clearAlpha)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        configure(encoder)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func render() {
        guard parameters.isActive,
              effectActive,
              let sourceView,
              let drawable = currentDrawable,
              let pipelineState,
              let commandQueue,
              let noiseTexture,
              let linearSampler,
              let noiseSampler,
              let device,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        guard let sourceTexture = captureSourceTexture(from: sourceView, device: device) else {
            return
        }

        let time = Float(CACurrentMediaTime() - startTime)
        let width = Float(max(bounds.width, 1))
        let height = Float(max(bounds.height, 1))

        // Burn-in feedback pass
        var burnInSampleTexture: MTLTexture? = burnInUseA ? burnInTextureA : burnInTextureB
        if parameters.burnIn > 0, let burnInPipelineState {
            ensureBurnInTextures(width: sourceTexture.width, height: sourceTexture.height, device: device)
            let prev = burnInUseA ? burnInTextureA : burnInTextureB
            let next = burnInUseA ? burnInTextureB : burnInTextureA
            if let prev, let next {
                burnInPrevUpdate = burnInLastUpdate
                burnInLastUpdate = time

                encodeFullScreen(commandBuffer: commandBuffer, pipeline: burnInPipelineState, destination: next) { encoder in
                    var burnUniforms = BurnInUniforms(
                        burnInLastUpdate: self.burnInLastUpdate,
                        burnInTime: self.parameters.burnInFadeTime,
                        prevLastUpdate: self.burnInPrevUpdate
                    )
                    encoder.setFragmentBytes(&burnUniforms, length: MemoryLayout<BurnInUniforms>.stride, index: 0)
                    encoder.setFragmentTexture(sourceTexture, index: 0)
                    encoder.setFragmentTexture(prev, index: 1)
                    encoder.setFragmentSamplerState(linearSampler, index: 0)
                }
                burnInUseA.toggle()
                burnInSampleTexture = next
            }
        }

        // Bloom: downsample + FastBlur-style separable Gaussian (cool-retro-term TerminalContainer.qml)
        var bloomSampleTexture: MTLTexture = sourceTexture
        let needsBloom = parameters.bloom > 0 || parameters.frameShininess > 0
        if needsBloom,
           let bloomPreparePipelineState,
           let bloomBlurPipelineState {
            ensureBloomTextures(sourceWidth: sourceTexture.width, sourceHeight: sourceTexture.height, device: device)
            if let bloomA = bloomTextureA, let bloomB = bloomTextureB {
                // 1) Prepare / downsample into bloomA
                encodeFullScreen(commandBuffer: commandBuffer, pipeline: bloomPreparePipelineState, destination: bloomA) { encoder in
                    encoder.setFragmentTexture(sourceTexture, index: 0)
                    encoder.setFragmentSamplerState(linearSampler, index: 0)
                }

                let texel = SIMD2<Float>(1.0 / Float(bloomA.width), 1.0 / Float(bloomA.height))
                let radius = CRTEffectParameters.bloomBlurRadius

                // 2) Horizontal blur → bloomB
                encodeFullScreen(commandBuffer: commandBuffer, pipeline: bloomBlurPipelineState, destination: bloomB) { encoder in
                    var blur = BlurUniforms(
                        texelSize: texel,
                        direction: SIMD2<Float>(1, 0),
                        radius: radius
                    )
                    encoder.setFragmentBytes(&blur, length: MemoryLayout<BlurUniforms>.stride, index: 0)
                    encoder.setFragmentTexture(bloomA, index: 0)
                    encoder.setFragmentSamplerState(linearSampler, index: 0)
                }

                // 3) Vertical blur → bloomA (final bloomSource)
                encodeFullScreen(commandBuffer: commandBuffer, pipeline: bloomBlurPipelineState, destination: bloomA) { encoder in
                    var blur = BlurUniforms(
                        texelSize: texel,
                        direction: SIMD2<Float>(0, 1),
                        radius: radius
                    )
                    encoder.setFragmentBytes(&blur, length: MemoryLayout<BlurUniforms>.stride, index: 0)
                    encoder.setFragmentTexture(bloomB, index: 0)
                    encoder.setFragmentSamplerState(linearSampler, index: 0)
                }

                bloomSampleTexture = bloomA
            }
        }

        let descriptor = currentRenderPassDescriptor ?? MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = clearColor

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        let virtualResolution = SIMD2<Float>(width, height)

        var uniforms = Uniforms(
            time: time,
            screenCurvature: 0,

            rgbShift: parameters.scaledRgbShift(width: width),
            bloom: parameters.scaledBloom,
            staticNoise: parameters.staticNoise,
            jitter: parameters.jitter,
            jitterDisplacement: parameters.jitterDisplacement(),
            glowingLine: parameters.scaledGlowingLine,
            flickering: parameters.flickering,
            horizontalSync: parameters.horizontalSync,
            horizontalSyncStrength: parameters.horizontalSyncStrength,
            burnIn: parameters.burnIn,
            burnInLastUpdate: burnInLastUpdate,
            burnInTime: parameters.burnInFadeTime,
            ambientLight: parameters.scaledAmbientLight,
            frameShininess: parameters.scaledFrameShininess,
            frameSize: 0,
            virtualResolution: virtualResolution,
            noiseScale: SIMD2<Float>(
                (width * 0.75) / 512.0,
                (height * 0.75) / 512.0
            ),
            contrast: parameters.contrast,
            saturation: parameters.saturation
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentTexture(noiseTexture, index: 1)
        encoder.setFragmentTexture(burnInSampleTexture ?? sourceTexture, index: 2)
        encoder.setFragmentTexture(bloomSampleTexture, index: 3)
        encoder.setFragmentSamplerState(linearSampler, index: 0)
        encoder.setFragmentSamplerState(noiseSampler, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func captureSourceTexture(from view: NSView, device: MTLDevice) -> MTLTexture? {
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return nil }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let cgImage = rep.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: width * 4
        )
        return texture
    }
}
