//
//  EncryptedTagIndicator.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import SwiftUI

/// A view modifier that adds a lock icon to indicate encrypted tags
struct EncryptedTagModifier: ViewModifier {
    /// Whether the tag is encrypted
    let isEncrypted: Bool
    
    /// The color of the tag
    let tagColor: Color
    
    /// The tag object, used to check for global access
    let tag: Tag?
    
    init(isEncrypted: Bool, tagColor: Color, tag: Tag? = nil) {
        self.isEncrypted = isEncrypted
        self.tagColor = tagColor
        self.tag = tag
    }
    
    func body(content: Content) -> some View {
        if isEncrypted {
            ZStack(alignment: .topTrailing) {
                content
                
                // Lock indicator - show open lock if tag has global access
                let hasAccess = tag?.hasGlobalAccess ?? false
                Image(systemName: hasAccess ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(hasAccess ? Color.green : tagColor)
                    )
                    .offset(x: 3, y: -3)
            }
        } else {
            content
        }
    }
}

/// An enhanced tag view with encryption indicator
struct EnhancedEncryptedTagView: View {
    let tag: Tag
    var onTagTapped: ((Tag) -> Void)? = nil
    
    var body: some View {
        Button {
            onTagTapped?(tag)
        } label: {
            HStack(spacing: 6) {
                // Display icon if available, otherwise color circle
                if let iconName = tag.iconName, !iconName.isEmpty {
                    Image(systemName: iconName)
                        .font(.caption)
                        .foregroundColor(tag.swiftUIColor)
                } else {
                    Circle()
                        .fill(tag.swiftUIColor)
                        .frame(width: 8, height: 8)
                }
                
                Text(tag.name ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                
                // Show access indicator if encrypted tag has global access
                if tag.isEncrypted && tag.hasGlobalAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tag.swiftUIColor.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(tag.swiftUIColor.opacity(0.3), lineWidth: 1)
            )
            .modifier(EncryptedTagModifier(isEncrypted: tag.isEncrypted, tagColor: tag.swiftUIColor, tag: tag))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension View {
    /// Add an encryption indicator to a view
    func encryptedTagIndicator(isEncrypted: Bool, color: Color, tag: Tag? = nil) -> some View {
        self.modifier(EncryptedTagModifier(isEncrypted: isEncrypted, tagColor: color, tag: tag))
    }
}

#Preview("Encrypted Tags", traits: .sizeThatFitsLayout) {
    let context = PersistenceController.preview.container.viewContext
    
    // Create the tags outside of the view builder
    let regularTag = Tag(context: context)
    regularTag.name = "Regular Tag"
    regularTag.color = "#3357FF"
    regularTag.isEncrypted = false
    
    let encryptedTag = Tag(context: context)
    encryptedTag.name = "Encrypted Tag"
    encryptedTag.color = "#FF5733"
    encryptedTag.isEncrypted = true
    
    let iconTag = Tag(context: context)
    iconTag.name = "Secret Notes"
    iconTag.color = "#33FF57"
    iconTag.iconName = "lock.shield"
    iconTag.isEncrypted = true
    
    return VStack(spacing: 20) {
        EnhancedEncryptedTagView(tag: regularTag)
        EnhancedEncryptedTagView(tag: encryptedTag)
        EnhancedEncryptedTagView(tag: iconTag)
    }
    .padding()
}