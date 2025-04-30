//
//  TagFilterView.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData

/// A view for selecting tags to filter journal entries
struct TagFilterView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedTags: Set<Tag>
    @Binding var filterMode: TagFilterMode
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var allTags: FetchedResults<Tag>
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter mode selector
                Picker("Filter Mode", selection: $filterMode) {
                    Text("Has All").tag(TagFilterMode.all)
                    Text("Has Any").tag(TagFilterMode.any)
                    Text("Exclude").tag(TagFilterMode.exclude)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tag selection list
                List {
                    ForEach(allTags) { tag in
                        Button(action: {
                            toggleTag(tag)
                        }) {
                            HStack {
                                // Tag color and icon
                                if let iconName = tag.iconName, !iconName.isEmpty {
                                    Image(systemName: iconName)
                                        .foregroundColor(tag.swiftUIColor)
                                } else {
                                    Circle()
                                        .fill(tag.swiftUIColor)
                                        .frame(width: 12, height: 12)
                                }
                                
                                Text(tag.name ?? "Unnamed Tag")
                                
                                Spacer()
                                
                                // Checkmark if selected
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Selected tags summary
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Selected Tags:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(selectedTags), id: \.self) { tag in
                                    HStack {
                                        if let iconName = tag.iconName, !iconName.isEmpty {
                                            Image(systemName: iconName)
                                                .font(.caption)
                                        }
                                        Text(tag.name ?? "")
                                            .font(.caption)
                                        
                                        Button(action: {
                                            selectedTags.remove(tag)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tag.swiftUIColor.opacity(0.2))
                                    .foregroundColor(tag.swiftUIColor)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.bottom)
                        
                        Button("Clear All") {
                            selectedTags.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle("Filter by Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create some sample tags for the preview
    let tag1 = Tag(context: context)
    tag1.name = "Work"
    tag1.color = "#FF5733"
    tag1.iconName = "briefcase"
    
    let tag2 = Tag(context: context)
    tag2.name = "Personal"
    tag2.color = "#33FF57"
    tag2.iconName = "person"
    
    let tag3 = Tag(context: context)
    tag3.name = "Health"
    tag3.color = "#3357FF"
    tag3.iconName = "heart"
    
    return TagFilterView(
        selectedTags: .constant(Set([tag1])),
        filterMode: .constant(.any)
    )
    .environment(\.managedObjectContext, context)
}
