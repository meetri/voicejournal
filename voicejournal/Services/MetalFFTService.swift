//
//  MetalFFTService.swift
//  voicejournal
//
//  Created on 5/4/2025.
//

import Foundation
import Metal
import Accelerate

/// A service that performs Fast Fourier Transform using Metal for GPU acceleration
class MetalFFTService {
    // MARK: - Properties
    
    /// The Metal device
    private let device: MTLDevice
    
    /// The command queue
    private let commandQueue: MTLCommandQueue
    
    /// The Metal compute pipeline for bit reversal
    private let bitReversalPipeline: MTLComputePipelineState
    
    /// The Metal compute pipeline for butterfly operations
    private let butterflyPipeline: MTLComputePipelineState
    
    /// The Metal compute pipeline for computing magnitudes
    private let magnitudePipeline: MTLComputePipelineState
    
    /// The size of the FFT (must be a power of 2)
    private let fftSize: UInt32
    
    /// The number of stages in the FFT (log2 of fftSize)
    private let numStages: UInt32
    
    /// The buffer for the input data
    private var inputBuffer: MTLBuffer
    
    /// The buffer for the output data
    private var outputBuffer: MTLBuffer
    
    /// The temporary buffer for the FFT computation
    private var tempBuffer: MTLBuffer
    
    /// The buffer for the magnitude results
    private var magnitudeBuffer: MTLBuffer
    
    // MARK: - Initialization
    
    /// Initializes the Metal FFT service with the specified FFT size
    /// - Parameter fftSize: The size of the FFT (must be a power of 2)
    init?(fftSize: UInt32) {
        // Ensure FFT size is a power of 2
        let log2Size = log2(Double(fftSize))
        guard log2Size == floor(log2Size) else {
            print("FFT size must be a power of 2")
            return nil
        }
        
        // Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        self.device = device
        self.fftSize = fftSize
        self.numStages = UInt32(log2(Double(fftSize)))
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue
        
        // Load Metal library
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            print("Failed to load Metal library")
            return nil
        }
        
        // Create compute pipelines
        guard let bitReversalFunction = defaultLibrary.makeFunction(name: "bitReversal"),
              let butterflyFunction = defaultLibrary.makeFunction(name: "butterflyOperation"),
              let magnitudeFunction = defaultLibrary.makeFunction(name: "computeMagnitudes") else {
            print("Failed to load Metal functions")
            return nil
        }
        
        do {
            self.bitReversalPipeline = try device.makeComputePipelineState(function: bitReversalFunction)
            self.butterflyPipeline = try device.makeComputePipelineState(function: butterflyFunction)
            self.magnitudePipeline = try device.makeComputePipelineState(function: magnitudeFunction)
        } catch {
            print("Failed to create compute pipelines: \(error)")
            return nil
        }
        
        // Create buffers
        let complexBufferSize = MemoryLayout<SIMD2<Float>>.stride * Int(fftSize)
        let magnitudeBufferSize = MemoryLayout<Float>.stride * Int(fftSize)
        
        guard let inputBuffer = device.makeBuffer(length: complexBufferSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: complexBufferSize, options: .storageModeShared),
              let tempBuffer = device.makeBuffer(length: complexBufferSize, options: .storageModeShared),
              let magnitudeBuffer = device.makeBuffer(length: magnitudeBufferSize, options: .storageModeShared) else {
            print("Failed to create Metal buffers")
            return nil
        }
        
        self.inputBuffer = inputBuffer
        self.outputBuffer = outputBuffer
        self.tempBuffer = tempBuffer
        self.magnitudeBuffer = magnitudeBuffer
    }
    
    // MARK: - Public Methods
    
    /// Performs FFT on the provided audio samples and returns the magnitude spectrum
    /// - Parameter samples: The audio samples to analyze
    /// - Returns: An array of magnitude values, or nil if the FFT failed
    func performFFT(samples: [Float]) -> [Float]? {
        // Ensure we have enough samples
        guard samples.count >= Int(fftSize) else {
            print("Not enough samples for FFT")
            return nil
        }
        
        // Convert samples to complex format (real part only)
        var complexSamples = [SIMD2<Float>](repeating: SIMD2<Float>(0, 0), count: Int(fftSize))
        for i in 0..<Int(fftSize) {
            complexSamples[i].x = samples[i]
        }
        
        // Copy samples to input buffer
        let inputPointer = inputBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: Int(fftSize))
        for i in 0..<Int(fftSize) {
            inputPointer[i] = complexSamples[i]
        }
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer")
            return nil
        }
        
        // Perform bit reversal
        performBitReversal(commandBuffer: commandBuffer)
        
        // Perform butterfly operations
        for stage in 0..<numStages {
            performButterflyOperation(commandBuffer: commandBuffer, stage: stage)
        }
        
        // Compute magnitudes
        computeMagnitudes(commandBuffer: commandBuffer)
        
        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Copy magnitude results
        let magnitudePointer = magnitudeBuffer.contents().bindMemory(to: Float.self, capacity: Int(fftSize))
        var results = [Float](repeating: 0, count: Int(fftSize))
        for i in 0..<Int(fftSize) {
            results[i] = magnitudePointer[i]
        }
        
        // For FFT, we only need the first half (as the second half is redundant)
        return Array(results[0..<Int(fftSize/2)])
    }
    
    // MARK: - Private Methods
    
    /// Performs the bit reversal step of the FFT
    private func performBitReversal(commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create compute command encoder for bit reversal")
            return
        }
        
        encoder.setComputePipelineState(bitReversalPipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBytes([fftSize], length: MemoryLayout<UInt32>.stride, index: 2)
        
        let threadsPerThreadgroup = min(bitReversalPipeline.maxTotalThreadsPerThreadgroup, Int(fftSize))
        let threadgroupsPerGrid = (Int(fftSize) + threadsPerThreadgroup - 1) / threadsPerThreadgroup
        
        encoder.dispatchThreadgroups(MTLSize(width: threadgroupsPerGrid, height: 1, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1))
        
        encoder.endEncoding()
    }
    
    /// Performs a butterfly operation stage of the FFT
    private func performButterflyOperation(commandBuffer: MTLCommandBuffer, stage: UInt32) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create compute command encoder for butterfly operation")
            return
        }
        
        encoder.setComputePipelineState(butterflyPipeline)
        
        let inputForStage = (stage % 2 == 0) ? outputBuffer : tempBuffer
        let outputForStage = (stage % 2 == 0) ? tempBuffer : outputBuffer
        
        encoder.setBuffer(inputForStage, offset: 0, index: 0)
        encoder.setBuffer(outputForStage, offset: 0, index: 1)
        encoder.setBytes([stage], length: MemoryLayout<UInt32>.stride, index: 2)
        encoder.setBytes([fftSize], length: MemoryLayout<UInt32>.stride, index: 3)
        
        let butterfliesPerStage = fftSize / 2
        let threadsPerThreadgroup = min(butterflyPipeline.maxTotalThreadsPerThreadgroup, Int(butterfliesPerStage))
        let threadgroupsPerGrid = (Int(butterfliesPerStage) + threadsPerThreadgroup - 1) / threadsPerThreadgroup
        
        encoder.dispatchThreadgroups(MTLSize(width: threadgroupsPerGrid, height: 1, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1))
        
        encoder.endEncoding()
    }
    
    /// Computes magnitudes from the complex FFT result
    private func computeMagnitudes(commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create compute command encoder for magnitude computation")
            return
        }
        
        encoder.setComputePipelineState(magnitudePipeline)
        
        // If number of stages is odd, the result is in tempBuffer, otherwise it's in outputBuffer
        let resultBuffer = (numStages % 2 == 0) ? outputBuffer : tempBuffer
        
        encoder.setBuffer(resultBuffer, offset: 0, index: 0)
        encoder.setBuffer(magnitudeBuffer, offset: 0, index: 1)
        encoder.setBytes([fftSize], length: MemoryLayout<UInt32>.stride, index: 2)
        
        let threadsPerThreadgroup = min(magnitudePipeline.maxTotalThreadsPerThreadgroup, Int(fftSize))
        let threadgroupsPerGrid = (Int(fftSize) + threadsPerThreadgroup - 1) / threadsPerThreadgroup
        
        encoder.dispatchThreadgroups(MTLSize(width: threadgroupsPerGrid, height: 1, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1))
        
        encoder.endEncoding()
    }
}