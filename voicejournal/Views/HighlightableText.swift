//
//  HighlightableText.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI

/// A text view that can highlight a specific range of text
struct HighlightableText: View {
    // MARK: - Properties
    
    /// The full text to display
    let text: String
    
    /// The range of text to highlight (nil for no highlight)
    var highlightRange: NSRange?
    
    /// The color to use for highlighting
    var highlightColor: Color = .yellow.opacity(0.5)
    
    /// The text color
    var textColor: Color = .primary
    
    /// The font to use
    var font: Font = .body
    
    // MARK: - Body
    
    var body: some View {
        if let highlightRange = highlightRange, highlightRange.location != NSNotFound {
            textWithHighlight
        } else {
            Text(text)
                .font(font)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Text view with highlighted section
    private var textWithHighlight: some View {
        let nsText = text as NSString
        
        // Ensure the highlight range is valid
        let validRange = validateRange(highlightRange ?? NSRange(location: 0, length: 0))
        
        // Split the text into three parts: before highlight, highlight, and after highlight
        let beforeHighlight = nsText.substring(with: NSRange(location: 0, length: validRange.location))
        let highlightText = nsText.substring(with: validRange)
        let afterHighlightLocation = validRange.location + validRange.length
        let afterHighlightLength = nsText.length - afterHighlightLocation
        let afterHighlight = afterHighlightLength > 0 ? nsText.substring(with: NSRange(location: afterHighlightLocation, length: afterHighlightLength)) : ""
        
        return VStack(alignment: .leading, spacing: 0) {
            Text(beforeHighlight + highlightText + afterHighlight)
                .font(font)
                .foregroundColor(textColor)
                .background(
                    GeometryReader { geometry in
                        // Calculate the position and size of the highlight
                        let beforeHighlightWidth = beforeHighlight.size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body)]).width
                        let highlightWidth = highlightText.size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body)]).width
                        
                        // Create the highlight rectangle
                        highlightColor
                            .frame(width: highlightWidth, height: geometry.size.height)
                            .position(x: beforeHighlightWidth + highlightWidth / 2, y: geometry.size.height / 2)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Validate the highlight range to ensure it's within the text bounds
    private func validateRange(_ range: NSRange) -> NSRange {
        let nsText = text as NSString
        
        // If the range is invalid or out of bounds, return an empty range
        if range.location == NSNotFound || range.location >= nsText.length {
            return NSRange(location: 0, length: 0)
        }
        
        // Ensure the range doesn't extend beyond the text length
        let maxLength = nsText.length - range.location
        let validLength = min(range.length, maxLength)
        
        return NSRange(location: range.location, length: validLength)
    }
}

// MARK: - Alternative Implementation for Complex Text Layouts

/// A text view that can highlight a specific range of text using AttributedString
struct AttributedHighlightableText: View {
    // MARK: - Properties
    
    /// The full text to display
    let text: String
    
    /// The range of text to highlight (nil for no highlight)
    var highlightRange: NSRange?
    
    /// The color to use for highlighting
    var highlightColor: Color = .yellow.opacity(0.5)
    
    /// The text color
    var textColor: Color = .primary
    
    /// The font to use
    var font: Font = .body
    
    // MARK: - Body
    
    var body: some View {
        Text(attributedString)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - Computed Properties
    
    /// Create an attributed string with the highlight
    private var attributedString: AttributedString {
        var attributedString = AttributedString(text)
        
        // Apply base attributes to the entire string
        attributedString.font = font
        attributedString.foregroundColor = textColor
        
        // Apply highlight if range is valid
        if let highlightRange = highlightRange, highlightRange.location != NSNotFound {
            // Validate the range
            let nsText = text as NSString
            if highlightRange.location < nsText.length {
                let maxLength = nsText.length - highlightRange.location
                let validLength = min(highlightRange.length, maxLength)
                
                if validLength > 0 {
                    // Convert NSRange to Range<String.Index>
                    if let range = Range(NSRange(location: highlightRange.location, length: validLength), in: text) {
                        attributedString[range].backgroundColor = highlightColor
                    }
                }
            }
        }
        
        return attributedString
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HighlightableText(
            text: "This is a sample text with a highlighted section in the middle.",
            highlightRange: NSRange(location: 18, length: 11)
        )
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        
        AttributedHighlightableText(
            text: "This is another sample text with a highlighted section using AttributedString.",
            highlightRange: NSRange(location: 16, length: 12)
        )
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        
        HighlightableText(
            text: "This text has no highlighting applied.",
            highlightRange: nil
        )
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    .padding()
}
