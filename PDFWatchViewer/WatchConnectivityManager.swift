import Foundation
import WatchConnectivity
import PDFKit
import UIKit

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var isTransferring = false
    @Published var transferProgress: Double = 0
    @Published var transferStatus: String = ""

    private var session: WCSession?
    private var pendingTransfers: [WCSessionFileTransfer] = []
    private var totalPages = 0
    private var completedPages = 0

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendPDF(_ document: PDFDocumentItem, completion: @escaping (Bool) -> Void) {
        guard let session = session, session.activationState == .activated else {
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.renderAndSendPDF(document, completion: completion)
        }
    }

    func sendAllPDFs(_ documents: [PDFDocumentItem], completion: @escaping (Bool) -> Void) {
        guard let session = session, session.activationState == .activated else {
            completion(false)
            return
        }

        guard !documents.isEmpty else {
            completion(true)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var allSuccess = true
            let group = DispatchGroup()

            for document in documents {
                group.enter()
                self.renderAndSendPDF(document) { success in
                    if !success {
                        allSuccess = false
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(allSuccess)
            }
        }
    }

    private func renderAndSendPDF(_ document: PDFDocumentItem, completion: @escaping (Bool) -> Void) {
        let fileURL = document.fileURL

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let pdfDocument = PDFDocument(url: fileURL) else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }

        let pageCount = pdfDocument.pageCount

        DispatchQueue.main.async {
            self.isTransferring = true
            self.transferProgress = 0
            self.totalPages = pageCount
            self.completedPages = 0
            self.transferStatus = "Rendering pages..."
        }

        // Create temp directory for this document's pages
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(document.id.uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            DispatchQueue.main.async {
                self.isTransferring = false
                completion(false)
            }
            return
        }

        // Render and send each page
        let group = DispatchGroup()
        var success = true

        for pageIndex in 0..<pageCount {
            group.enter()

            guard let page = pdfDocument.page(at: pageIndex) else {
                success = false
                group.leave()
                continue
            }

            // Render page to image
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // 2x for good quality on watch

            // Target size optimized for watch display (keeping aspect ratio)
            let maxDimension: CGFloat = 400
            let aspectRatio = pageRect.width / pageRect.height
            let targetSize: CGSize
            if aspectRatio > 1 {
                targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }

            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: targetSize))

                context.cgContext.translateBy(x: 0, y: targetSize.height)
                context.cgContext.scaleBy(x: targetSize.width / pageRect.width, y: -targetSize.height / pageRect.height)

                page.draw(with: .mediaBox, to: context.cgContext)
            }

            // Save to temp file
            let pageFileURL = tempDir.appendingPathComponent("page_\(pageIndex).png")

            guard let pngData = image.pngData() else {
                success = false
                group.leave()
                continue
            }

            do {
                try pngData.write(to: pageFileURL)

                // Send to watch
                let metadata: [String: Any] = [
                    "documentId": document.id.uuidString,
                    "documentName": document.name,
                    "pageCount": pageCount,
                    "pageIndex": pageIndex
                ]

                DispatchQueue.main.async {
                    self.transferStatus = "Sending page \(pageIndex + 1)/\(pageCount)..."
                }

                let transfer = WCSession.default.transferFile(pageFileURL, metadata: metadata)
                self.pendingTransfers.append(transfer)

                // Monitor this transfer
                self.monitorTransfer(transfer) {
                    DispatchQueue.main.async {
                        self.completedPages += 1
                        self.transferProgress = Double(self.completedPages) / Double(self.totalPages)
                    }
                    group.leave()
                }
            } catch {
                success = false
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isTransferring = false
            self.transferStatus = success ? "Complete!" : "Failed"

            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)

            completion(success)
        }
    }

    private func monitorTransfer(_ transfer: WCSessionFileTransfer, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            while transfer.isTransferring {
                Thread.sleep(forTimeInterval: 0.1)
            }

            DispatchQueue.main.async {
                if let index = self.pendingTransfers.firstIndex(of: transfer) {
                    self.pendingTransfers.remove(at: index)
                }
                completion()
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
