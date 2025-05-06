//
//  SpectrumAnalyzerView.swift
//  voicejournal
//
//  Created on 5/4/2025.
//

import SwiftUI

/// A view that displays a spectrum analyzer visualization of audio
struct SpectrumAnalyzerView: View {
    // MARK: - Properties
    
    /// The view model for the spectrum analyzer
    @ObservedObject var viewModel: SpectrumViewModel
    
    /// The height of the view
    var height: CGFloat = 120
    
    /// The style of the spectrum display
    var style: SpectrumStyle = .bars
    
    /// Whether to use Metal/Canvas for rendering (more efficient)
    var useHardwareAcceleration: Bool = true
    
    /// Visual amplification factor to scale the bars to fill more of the view height
    var visualAmplification: CGFloat = 2.0
    
    /// State for refresh trigger (used for animation)
    @State private var refreshTrigger = false
    
    // MARK: - Initialization
    
    init(viewModel: SpectrumViewModel, 
         height: CGFloat = 120, 
         style: SpectrumStyle = .bars, 
         useHardwareAcceleration: Bool = true,
         visualAmplification: CGFloat = 2.0) {
        self.viewModel = viewModel
        self.height = height
        self.style = style
        self.useHardwareAcceleration = useHardwareAcceleration
        self.visualAmplification = visualAmplification
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            viewModel.primaryColor.opacity(0.2),
                            lineWidth: 1
                        )
                )
            
            // Spectrum visualization
            Group {
                if useHardwareAcceleration {
                    // Use Canvas for hardware acceleration
                    canvasRenderer
                } else {
                    // Use SwiftUI views
                    swiftUIRenderer
                }
            }
            .padding(8)
            
            // Status indicator when active
            if viewModel.isActive {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: height)
        .onAppear {
            // Start the spectrum analyzer if not already active
            if !viewModel.isActive {
                viewModel.start()
            }
        }
        .onDisappear {
            // Stop the spectrum analyzer when the view disappears
            viewModel.stop()
        }
        // Add a timer to refresh the view for smoother animation
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            if viewModel.isActive {
                refreshTrigger.toggle()
            }
        }
    }
    
    // MARK: - Canvas Renderer (Hardware Accelerated)
    
    /// Renders the spectrum using Canvas for better performance
    private var canvasRenderer: some View {
        Canvas { context, size in
            // Using refreshTrigger to ensure canvas redraws when timer fires
            let _ = refreshTrigger
            
            // Get frequency data
            let frequencyData = viewModel.frequencyData
            let peakData = viewModel.peakFrequencyData
            
            switch style {
            case .bars:
                drawBarsSpectrum(context: context, size: size, frequencyData: frequencyData, peakData: peakData)
            case .line:
                drawLineSpectrum(context: context, size: size, frequencyData: frequencyData, peakData: peakData)
            case .area:
                drawAreaSpectrum(context: context, size: size, frequencyData: frequencyData, peakData: peakData)
            }
        }
    }
    
    /// Draws a bar spectrum visualization
    private func drawBarsSpectrum(
        context: GraphicsContext,
        size: CGSize,
        frequencyData: [Float],
        peakData: [Float]
    ) {
        let barCount = frequencyData.count
        let barSpacing: CGFloat = 2
        let barWidth = (size.width - (barSpacing * CGFloat(barCount - 1))) / CGFloat(barCount)
        
        // Draw each bar
        for i in 0..<barCount {
            if i >= frequencyData.count {
                continue
            }
            
            let level = frequencyData[i]
            
            // Calculate bar height with visual amplification (minimum 2 pixels, maximum size.height)
            let barHeight = min(size.height, max(2, CGFloat(level) * size.height * visualAmplification))
            
            // Calculate bar position (from bottom up)
            let x = CGFloat(i) * (barWidth + barSpacing)
            let y = size.height - barHeight
            
            // Create bar path
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let barPath = Path(roundedRect: barRect, cornerRadius: 2)
            
            // Get color based on viewModel color mode
            let color = viewModel.colorForBin(index: i, count: barCount, value: level)
            
            // Draw bar
            context.fill(barPath, with: .color(color))
            
            // Draw peak if enabled
            if viewModel.showPeakHold && i < peakData.count {
                let peakLevel = peakData[i]
                // Apply same amplification to peak values but ensure they stay in view bounds
                let amplifiedPeakLevel = min(1.0, CGFloat(peakLevel) * visualAmplification)
                let peakY = size.height - amplifiedPeakLevel * size.height
                
                let peakRect = CGRect(x: x, y: peakY - 2, width: barWidth, height: 2)
                let peakPath = Path(roundedRect: peakRect, cornerRadius: 1)
                
                context.fill(peakPath, with: .color(Color.white.opacity(0.7)))
            }
        }
    }
    
    /// Draws a line spectrum visualization
    private func drawLineSpectrum(
        context: GraphicsContext,
        size: CGSize,
        frequencyData: [Float],
        peakData: [Float]
    ) {
        let pointCount = frequencyData.count
        let pointSpacing = size.width / CGFloat(pointCount - 1)
        
        // Create a path for the line
        var linePath = Path()
        var peakPath = Path()
        
        for i in 0..<pointCount {
            if i >= frequencyData.count {
                continue
            }
            
            let level = frequencyData[i]
            let x = CGFloat(i) * pointSpacing
            // Apply amplification but constrain to view bounds
            let amplifiedLevel = min(1.0, CGFloat(level) * visualAmplification)
            let y = size.height - amplifiedLevel * size.height
            
            if i == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
                if viewModel.showPeakHold && i < peakData.count {
                    let amplifiedPeakLevel = min(1.0, CGFloat(peakData[i]) * visualAmplification)
                    peakPath.move(to: CGPoint(x: x, y: size.height - amplifiedPeakLevel * size.height))
                }
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
                if viewModel.showPeakHold && i < peakData.count {
                    let amplifiedPeakLevel = min(1.0, CGFloat(peakData[i]) * visualAmplification)
                    peakPath.addLine(to: CGPoint(x: x, y: size.height - amplifiedPeakLevel * size.height))
                }
            }
        }
        
        // Draw the line with a stroke
        context.stroke(
            linePath,
            with: .linearGradient(
                Gradient(colors: [viewModel.primaryColor, viewModel.secondaryColor]),
                startPoint: CGPoint(x: 0, y: size.height),
                endPoint: CGPoint(x: size.width, y: size.height)
            ),
            lineWidth: 2
        )
        
        // Draw peak line if enabled
        if viewModel.showPeakHold {
            context.stroke(
                peakPath,
                with: .color(Color.white.opacity(0.7)),
                lineWidth: 1
            )
        }
    }
    
    /// Draws an area spectrum visualization
    private func drawAreaSpectrum(
        context: GraphicsContext,
        size: CGSize,
        frequencyData: [Float],
        peakData: [Float]
    ) {
        let pointCount = frequencyData.count
        let pointSpacing = size.width / CGFloat(pointCount - 1)
        
        // Create a path for the area
        var areaPath = Path()
        var peakPath = Path()
        
        // Start at the bottom left
        areaPath.move(to: CGPoint(x: 0, y: size.height))
        
        for i in 0..<pointCount {
            if i >= frequencyData.count {
                continue
            }
            
            let level = frequencyData[i]
            let x = CGFloat(i) * pointSpacing
            // Apply amplification but constrain to view bounds
            let amplifiedLevel = min(1.0, CGFloat(level) * visualAmplification)
            let y = size.height - amplifiedLevel * size.height
            
            areaPath.addLine(to: CGPoint(x: x, y: y))
            
            if viewModel.showPeakHold && i < peakData.count {
                let amplifiedPeakLevel = min(1.0, CGFloat(peakData[i]) * visualAmplification)
                if i == 0 {
                    peakPath.move(to: CGPoint(x: x, y: size.height - amplifiedPeakLevel * size.height))
                } else {
                    peakPath.addLine(to: CGPoint(x: x, y: size.height - amplifiedPeakLevel * size.height))
                }
            }
        }
        
        // Complete the path by going to the bottom right and closing
        areaPath.addLine(to: CGPoint(x: size.width, y: size.height))
        areaPath.closeSubpath()
        
        // Draw the area with a gradient fill
        context.fill(
            areaPath,
            with: .linearGradient(
                Gradient(colors: [viewModel.primaryColor.opacity(0.7), viewModel.secondaryColor.opacity(0.1)]),
                startPoint: CGPoint(x: size.width/2, y: 0),
                endPoint: CGPoint(x: size.width/2, y: size.height)
            )
        )
        
        // Draw peak line if enabled
        if viewModel.showPeakHold {
            context.stroke(
                peakPath,
                with: .color(Color.white.opacity(0.7)),
                lineWidth: 1
            )
        }
    }
    
    // MARK: - SwiftUI Renderer
    
    /// Renders the spectrum using SwiftUI views (less efficient but more flexible)
    private var swiftUIRenderer: some View {
        GeometryReader { geometry in
            ZStack {
                switch style {
                case .bars:
                    barsSpectrumSwiftUI(size: geometry.size)
                case .line:
                    lineSpectrumSwiftUI(size: geometry.size)
                case .area:
                    areaSpectrumSwiftUI(size: geometry.size)
                }
            }
        }
    }
    
    /// Creates a bar spectrum visualization using SwiftUI views
    private func barsSpectrumSwiftUI(size: CGSize) -> some View {
        let barCount = viewModel.frequencyData.count
        let barSpacing: CGFloat = 2
        let barWidth = (size.width - (barSpacing * CGFloat(barCount - 1))) / CGFloat(barCount)
        
        return ZStack {
            // Frequency bars
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    if i < viewModel.frequencyData.count {
                        let level = viewModel.frequencyData[i]
                        let color = viewModel.colorForBin(index: i, count: barCount, value: level)
                        
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: barWidth, height: min(size.height, max(2, CGFloat(level) * size.height * visualAmplification)))
                        }
                    }
                }
            }
            
            // Peak indicators
            if viewModel.showPeakHold {
                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        if i < viewModel.peakFrequencyData.count {
                            let peakLevel = viewModel.peakFrequencyData[i]
                            
                            VStack {
                                // Apply same amplification to peak values
                                let amplifiedPeakLevel = min(1.0, CGFloat(peakLevel) * visualAmplification)
                                Spacer()
                                    .frame(height: size.height - amplifiedPeakLevel * size.height)
                                Rectangle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: barWidth, height: 2)
                                Spacer()
                                    .frame(height: amplifiedPeakLevel * size.height - 2)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Creates a line spectrum visualization using SwiftUI views
    private func lineSpectrumSwiftUI(size: CGSize) -> some View {
        let frequencyData = viewModel.frequencyData
        let peakData = viewModel.peakFrequencyData
        
        return ZStack {
            // Line for frequency data
            Path { path in
                let pointCount = frequencyData.count
                let pointSpacing = size.width / CGFloat(pointCount - 1)
                
                for i in 0..<pointCount {
                    if i >= frequencyData.count {
                        continue
                    }
                    
                    let level = frequencyData[i]
                    let x = CGFloat(i) * pointSpacing
                    let amplifiedLevel = min(1.0, CGFloat(level) * visualAmplification)
                    let y = size.height - amplifiedLevel * size.height
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [viewModel.primaryColor, viewModel.secondaryColor]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
            
            // Line for peak data
            if viewModel.showPeakHold {
                Path { path in
                    let pointCount = peakData.count
                    let pointSpacing = size.width / CGFloat(pointCount - 1)
                    
                    for i in 0..<pointCount {
                        if i >= peakData.count {
                            continue
                        }
                        
                        let level = peakData[i]
                        let x = CGFloat(i) * pointSpacing
                        let amplifiedLevel = min(1.0, CGFloat(level) * visualAmplification)
                        let y = size.height - amplifiedLevel * size.height
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
            }
        }
    }
    
    /// Creates an area spectrum visualization using SwiftUI views
    private func areaSpectrumSwiftUI(size: CGSize) -> some View {
        let frequencyData = viewModel.frequencyData
        let peakData = viewModel.peakFrequencyData
        
        return ZStack {
            // Area for frequency data
            Path { path in
                let pointCount = frequencyData.count
                let pointSpacing = size.width / CGFloat(pointCount - 1)
                
                // Start at the bottom left
                path.move(to: CGPoint(x: 0, y: size.height))
                
                for i in 0..<pointCount {
                    if i >= frequencyData.count {
                        continue
                    }
                    
                    let level = frequencyData[i]
                    let x = CGFloat(i) * pointSpacing
                    let amplifiedLevel = min(1.0, CGFloat(level) * visualAmplification)
                    let y = size.height - amplifiedLevel * size.height
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Complete the path
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [viewModel.primaryColor.opacity(0.7), viewModel.secondaryColor.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Line for peak data
            if viewModel.showPeakHold {
                Path { path in
                    let pointCount = peakData.count
                    let pointSpacing = size.width / CGFloat(pointCount - 1)
                    
                    for i in 0..<pointCount {
                        if i >= peakData.count {
                            continue
                        }
                        
                        let level = peakData[i]
                        let x = CGFloat(i) * pointSpacing
                        let amplifiedLevel = min(1.0, CGFloat(level) * visualAmplification)
                        let y = size.height - amplifiedLevel * size.height
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
            }
        }
    }
}

// MARK: - Spectrum Style Enum

/// The style of the spectrum visualization
enum SpectrumStyle {
    /// Bar-style visualization (like a traditional equalizer)
    case bars
    
    /// Line-style visualization
    case line
    
    /// Area-style visualization (filled area under curve)
    case area
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State private var viewModel = SpectrumViewModel()
        
        var body: some View {
            VStack(spacing: 20) {
                // Bars style with amplification
                SpectrumAnalyzerView(
                    viewModel: viewModel,
                    style: .bars,
                    visualAmplification: 2.0
                )
                .frame(height: 120)
                .padding()
                
                // Line style with amplification
                SpectrumAnalyzerView(
                    viewModel: viewModel,
                    style: .line,
                    visualAmplification: 2.0
                )
                .frame(height: 120)
                .padding()
                
                // Area style with amplification
                SpectrumAnalyzerView(
                    viewModel: viewModel,
                    style: .area,
                    visualAmplification: 2.0
                )
                .frame(height: 120)
                .padding()
            }
            .padding()
            .onAppear {
                // Create mock frequency data for preview
                var mockData = [Float](repeating: 0, count: 64)
                for i in 0..<mockData.count {
                    // Create a sine wave pattern
                    mockData[i] = abs(sin(Float(i) * 0.2)) * 0.8
                }
                
                // Update the view model
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.viewModel.didUpdateFrequencyData(mockData)
                }
            }
        }
    }
    
    return PreviewContainer()
}