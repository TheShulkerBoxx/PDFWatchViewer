import Foundation
import WatchConnectivity

struct WatchPDFDocument: Identifiable, Codable {
    let id: UUID
    let name: String
    let pageCount: Int
    let folderName: String

    var folderURL: URL {
        WatchConnectivityManager.documentsDirectory.appendingPathComponent(folderName)
    }

    func pageImageURL(for pageIndex: Int) -> URL {
        folderURL.appendingPathComponent("page_\(pageIndex).png")
    }
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var documents: [WatchPDFDocument] = []

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

    private var session: WCSession?

    override init() {
        super.init()

        loadDocuments()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
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
            documents = try JSONDecoder().decode([WatchPDFDocument].self, from: data)

            // Clean up any documents whose folders no longer exist
            documents = documents.filter { FileManager.default.fileExists(atPath: $0.folderURL.path) }
            saveDocuments()
        } catch {
            print("Error loading documents: \(error)")
        }
    }

    private func handleReceivedFile(url: URL, metadata: [String: Any]) {
        guard let documentIdString = metadata["documentId"] as? String,
              let documentId = UUID(uuidString: documentIdString),
              let documentName = metadata["documentName"] as? String,
              let pageCount = metadata["pageCount"] as? Int,
              let pageIndex = metadata["pageIndex"] as? Int else {
            print("Invalid metadata")
            return
        }

        let folderName = documentId.uuidString
        let folderURL = Self.documentsDirectory.appendingPathComponent(folderName)

        do {
            // Create folder if needed
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // Copy page image
            let destinationURL = folderURL.appendingPathComponent("page_\(pageIndex).png")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)

            DispatchQueue.main.async {
                // Check if document already exists
                if let existingIndex = self.documents.firstIndex(where: { $0.id == documentId }) {
                    // Update existing document if page count changed
                    if self.documents[existingIndex].pageCount != pageCount {
                        self.documents[existingIndex] = WatchPDFDocument(
                            id: documentId,
                            name: documentName,
                            pageCount: pageCount,
                            folderName: folderName
                        )
                    }
                } else {
                    // Add new document
                    let document = WatchPDFDocument(
                        id: documentId,
                        name: documentName,
                        pageCount: pageCount,
                        folderName: folderName
                    )
                    self.documents.append(document)
                }
                self.saveDocuments()
            }
        } catch {
            print("Error saving page image: \(error)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activated: \(activationState.rawValue)")
        if let error = error {
            print("Session activation error: \(error)")
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = file.metadata else {
            print("Received file without metadata")
            return
        }

        handleReceivedFile(url: file.fileURL, metadata: metadata)
    }
}
