import Foundation
import UIKit

struct ScanDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var pageCount: Int
    var pdfRelativePath: String
    var thumbnailRelativePath: String?

    var pdfURL: URL { ScanStore.shared.baseDirectory.appendingPathComponent(pdfRelativePath) }
    var thumbnailURL: URL? {
        guard let path = thumbnailRelativePath else { return nil }
        return ScanStore.shared.baseDirectory.appendingPathComponent(path)
    }
}

final class ScanStore: ObservableObject {
    static let shared = ScanStore()

    @Published private(set) var documents: [ScanDocument] = []

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "ScanStore.ioQueue", qos: .utility)

    var baseDirectory: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let root = urls[0].appendingPathComponent("Scans", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private var metadataURL: URL { baseDirectory.appendingPathComponent("metadata.json") }

    private init() {
        loadMetadata()
    }

    func refresh() {
        loadMetadata()
    }

    func addDocument(title: String?, processedImages: [UIImage], pdfData: Data, imageQuality: Int) throws -> ScanDocument {
        let id = UUID()
        let createdAt = Date()
        let folder = baseDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let pdfURL = folder.appendingPathComponent("document.pdf")
        try pdfData.write(to: pdfURL, options: .atomic)

        let compression = CGFloat(min(max(imageQuality, 60), 95)) / 100.0
        var thumbnailPath: String?
        for (index, image) in processedImages.enumerated() {
            let pageURL = folder.appendingPathComponent("page_\(index + 1).jpg")
            guard let jpeg = image.jpegData(compressionQuality: compression) else { continue }
            try jpeg.write(to: pageURL, options: .atomic)
            if index == 0 {
                thumbnailPath = "\(id.uuidString)/page_1.jpg"
            }
        }

        let document = ScanDocument(
            id: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            title: title?.isEmpty == false ? title! : defaultTitle(for: createdAt),
            pageCount: processedImages.count,
            pdfRelativePath: "\(id.uuidString)/document.pdf",
            thumbnailRelativePath: thumbnailPath
        )

        DispatchQueue.main.async {
            self.documents.insert(document, at: 0)
            self.saveAllMetadata()
        }
        return document
    }

    func delete(_ document: ScanDocument) {
        ioQueue.async {
            let folder = self.baseDirectory.appendingPathComponent(document.id.uuidString, isDirectory: true)
            try? self.fileManager.removeItem(at: folder)
            DispatchQueue.main.async {
                self.documents.removeAll { $0.id == document.id }
                self.saveAllMetadata()
            }
        }
    }

    private func defaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "Scan_\(formatter.string(from: date))"
    }

    private func loadMetadata() {
        ioQueue.async {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: self.metadataURL),
               let all = try? decoder.decode([ScanDocument].self, from: data) {
                let sorted = all.sorted { $0.createdAt > $1.createdAt }
                DispatchQueue.main.async {
                    self.documents = sorted
                }
            } else {
                DispatchQueue.main.async {
                    self.documents = []
                }
            }
        }
    }

    private func saveAllMetadata() {
        let snapshot = documents
        ioQueue.async { [weak self] in
            guard let self else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: self.metadataURL, options: .atomic)
        }
    }

}

