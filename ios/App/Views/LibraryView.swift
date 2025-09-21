import SwiftUI
import UIKit

struct LibraryView: View {
    @ObservedObject private var store = ScanStore.shared
    @State private var selectedDocument: ScanDocument?
    @State private var presentShare = false

    var body: some View {
        NavigationView {
            Group {
                if store.documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No saved scans yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(store.documents) { document in
                            Button {
                                selectedDocument = document
                                presentShare = true
                            } label: {
                                HStack(spacing: 12) {
                                    thumbnail(for: document)
                                        .frame(width: 60, height: 80)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(dateString(document.createdAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Pages: \(document.pageCount)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.delete(document)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Library")
            .sheet(isPresented: $presentShare, onDismiss: { selectedDocument = nil }) {
                if let doc = selectedDocument, let data = try? Data(contentsOf: doc.pdfURL) {
                    ActivityView(activityItems: [TemporaryFileData(data: data, suggestedName: doc.title + ".pdf")])
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func thumbnail(for document: ScanDocument) -> some View {
        Group {
            if let thumbURL = document.thumbnailURL, let data = try? Data(contentsOf: thumbURL), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.1)
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
    }
}

