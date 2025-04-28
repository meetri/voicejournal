//
//  TranscriptionSegment.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation

/// Represents a segment of transcribed text with timing information
struct TranscriptionSegment: Codable {
    /// The text content of this segment
    let text: String
    
    /// The start time of this segment in seconds
    let startTime: TimeInterval
    
    /// The end time of this segment in seconds
    let endTime: TimeInterval
    
    /// The range of this segment in the full transcription text
    var textRange: NSRange {
        get {
            return _textRange ?? NSRange(location: 0, length: 0)
        }
        set {
            _textRange = newValue
        }
    }
    
    /// Private storage for textRange (needed because NSRange isn't directly Codable)
    private var _textRange: NSRange?
    
    enum CodingKeys: String, CodingKey {
        case text
        case startTime
        case endTime
        case location
        case length
    }
    
    init(text: String, startTime: TimeInterval, endTime: TimeInterval, range: NSRange) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self._textRange = range
    }
    
    // Custom encoding to handle NSRange
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(_textRange?.location ?? 0, forKey: .location)
        try container.encode(_textRange?.length ?? 0, forKey: .length)
    }
    
    // Custom decoding to handle NSRange
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        
        let location = try container.decode(Int.self, forKey: .location)
        let length = try container.decode(Int.self, forKey: .length)
        _textRange = NSRange(location: location, length: length)
    }
}
