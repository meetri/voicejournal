//
//  TagManagementView.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData

struct TagManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch all tags, sorted by name
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    @State private var showingAddTagSheet = false
    @State private var tagToEdit: Tag? = nil
    @State private var showingDeleteConfirmation: Tag? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tags) { tag in
                    tagRow(tag)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = tag
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                tagToEdit = tag
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contentShape(Rectangle()) // Make the whole row tappable for context menu
                        .contextMenu {
                            Button {
                                tagToEdit = tag
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                showingDeleteConfirmation = tag
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: deleteTags) // Alternative delete method
            }
            .navigationTitle("Manage Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTagSheet = true
                    } label: {
                        Label("Add Tag", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTagSheet) {
                // Present TagEditorView for adding a new tag
                TagEditorView(tagToEdit: nil)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $tagToEdit) { tag in
                // Present TagEditorView for editing an existing tag
                TagEditorView(tagToEdit: tag)
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert("Delete Tag", isPresented: Binding(
                get: { showingDeleteConfirmation != nil },
                set: { if !$0 { showingDeleteConfirmation = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let tagToDelete = showingDeleteConfirmation {
                        deleteTag(tagToDelete)
                    }
                }
            } message: {
                Text("Are you sure you want to delete the tag \"\(showingDeleteConfirmation?.name ?? "")\"? This will remove the tag from all associated entries.")
            }
            .overlay {
                if tags.isEmpty {
                    Text("No tags created yet.")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack {
            Circle()
                .fill(tag.swiftUIColor)
                .frame(width: 12, height: 12)
            
            Text(tag.name ?? "Unnamed Tag")
            
            Spacer()
            
            // Display count of entries associated with the tag
            if let entries = tag.entries {
                Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Methods
    
    private func deleteTags(offsets: IndexSet) {
        withAnimation {
            offsets.map { tags[$0] }.forEach(deleteTag)
        }
    }
    
    private func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            // Error occurred
            // Handle the error appropriately
        }
    }
}

// MARK: - Tag Editor View

struct TagEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let tagToEdit: Tag? // If nil, we are adding a new tag
    
    @State private var tagName: String = ""
    @State private var tagColorHex: String = Tag.generateRandomHexColor() // Start with a random color
    @State private var selectedColor: Color = .blue // Default SwiftUI color
    @State private var selectedIconName: String? = nil // State for the icon name
    
    private var isEditing: Bool { tagToEdit != nil }
    private var title: String { isEditing ? "Edit Tag" : "Add New Tag" }
    
    // Predefined color palette
    private let colorPalette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .gray
    ]
    
    init(tagToEdit: Tag?) {
        self.tagToEdit = tagToEdit
        // Initialize state based on whether we are editing or adding
        _tagName = State(initialValue: tagToEdit?.name ?? "")
        _tagColorHex = State(initialValue: tagToEdit?.color ?? Tag.generateRandomHexColor())
        _selectedColor = State(initialValue: Color(hex: tagToEdit?.color ?? Tag.generateRandomHexColor()))
        _selectedIconName = State(initialValue: tagToEdit?.iconName) // Initialize icon name
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tag Name") {
                    TextField("Enter tag name", text: $tagName)
                }
                
                Section("Tag Color") {
                    ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                    
                    // Display the hex value (optional)
                    Text("Hex: \(selectedColor.toHex() ?? "N/A")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Predefined color palette
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(colorPalette, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.2), lineWidth: selectedColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section("Tag Icon (Optional)") {
                    HStack {
                        TextField("Enter SF Symbol name", text: $selectedIconName.bound)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Spacer()
                        
                        // Display the selected icon if valid
                        if let iconName = selectedIconName, !iconName.isEmpty {
                            Image(systemName: iconName)
                                .foregroundColor(selectedColor) // Use tag color for icon
                                .font(.title2)
                        } else {
                            Image(systemName: "tag") // Default icon
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                    }
                    // Simple way to provide some common suggestions
                    Text("Examples: heart.fill, star, book, pencil, mic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTag()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedColor) { _, newColor in
                // Update hex state when color picker changes
                tagColorHex = newColor.toHex() ?? tagColorHex
            }
        }
    }
    
    // MARK: - Methods
    
    private func saveTag() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return } // Should be disabled by button state, but good practice
        
        let tag: Tag
        if let existingTag = tagToEdit {
            tag = existingTag
        } else {
            // Check if tag with this name already exists (case-insensitive) before creating
            let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name ==[cd] %@", trimmedName)
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                if let duplicateTag = results.first, duplicateTag != tagToEdit {
                    // Handle duplicate tag name error (e.g., show an alert)
                    // Error occurred
                    // Optionally show an alert to the user here
                    return
                }
            } catch {
                // Error occurred
                // Proceed with caution or show error
            }
            
            tag = Tag(context: viewContext)
            tag.createdAt = Date()
        }
        
        tag.name = trimmedName
        tag.color = selectedColor.toHex() ?? Tag.generateRandomHexColor() // Use selected color's hex
        tag.iconName = selectedIconName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true ? nil : selectedIconName?.trimmingCharacters(in: .whitespacesAndNewlines) // Save icon name, nil if empty
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Error occurred
            // Handle save error (e.g., show an alert)
        }
    }
}

// MARK: - Binding Helper for Optional String

// Helper to bind TextField to Optional<String>
extension Binding where Value == Optional<String> {
    var bound: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}


// MARK: - Color Extension for Hex Conversion

// Add this extension if not already present globally
extension Color {
    func toHex() -> String? {
        guard let cgColor = self.cgColor else { return nil }
        let components = cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0
        
        let hexString = String(
            format: "#%02lX%02lX%02lX",
            lround(Double(r * 255)),
            lround(Double(g * 255)),
            lround(Double(b * 255))
        )
        return hexString
    }
}


// MARK: - Preview

#Preview {
    TagManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Tag Editor - Add") {
    TagEditorView(tagToEdit: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Tag Editor - Edit") {
    let context = PersistenceController.preview.container.viewContext
    let tag = Tag(context: context)
    tag.name = "Preview Tag"
    tag.color = "#FF5733"
    tag.createdAt = Date()
    
    return TagEditorView(tagToEdit: tag)
        .environment(\.managedObjectContext, context)
}
