import Foundation
import PDFKit

struct PDFDocumentItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let pageCount: Int
    let fileName: String

    var fileURL: URL {
        PDFDocumentManager.documentsDirectory.appendingPathComponent(fileName)
    }
}

class PDFDocumentManager: ObservableObject {
    @Published var documents: [PDFDocumentItem] = []

    static let documentsDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let pdfsDirectory = paths[0].appendingPathComponent("PDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: pdfsDirectory, withIntermediateDirectories: true)
        return pdfsDirectory
    }()

    private let metadataURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("pdf_metadata.json")
    }()

    init() {
        loadDocuments()
    }

    func addDocument(from url: URL) {
        guard let pdfDocument = PDFDocument(url: url) else { return }

        let fileName = "\(UUID().uuidString).pdf"
        let destinationURL = Self.documentsDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)

            let item = PDFDocumentItem(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                pageCount: pdfDocument.pageCount,
                fileName: fileName
            )

            DispatchQueue.main.async {
                self.documents.append(item)
                self.saveDocuments()
            }
        } catch {
            print("Error copying PDF: \(error)")
        }
    }

    func removeDocument(at index: Int) {
        let document = documents[index]
        try? FileManager.default.removeItem(at: document.fileURL)
        documents.remove(at: index)
        saveDocuments()
    }

    private func saveDocuments() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: metadataURL)
        } catch {
            print("Error saving documents: \(error)")
        }
    }

    private func loadDocuments() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }

        do {
            let data = try Data(contentsOf: metadataURL)
            documents = try JSONDecoder().decode([PDFDocumentItem].self, from: data)

            // Clean up any documents whose files no longer exist
            documents = documents.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        } catch {
            print("Error loading documents: \(error)")
        }
    }
}
