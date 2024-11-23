import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @StateObject private var pdfManager = PDFDocumentManager()
    @State private var showingDocumentPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var sendToWatchAfterPicking = true

    var body: some View {
        NavigationStack {
            VStack {
                if pdfManager.documents.isEmpty {
                    ContentUnavailableView(
                        "No PDFs",
                        systemImage: "doc.text",
                        description: Text("Tap the + button to add PDF documents")
                    )
                } else {
                    List {
                        ForEach(pdfManager.documents) { document in
                            PDFDocumentRow(document: document) {
                                sendToWatch(document)
                            }
                        }
                        .onDelete(perform: deleteDocuments)
                    }
                }
            }
            .navigationTitle("PDF Viewer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingDocumentPicker = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !pdfManager.documents.isEmpty {
                        Button("Send All") {
                            sendAllToWatch()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(pdfManager: pdfManager, sendToWatch: sendToWatchAfterPicking) { newDocuments in
                    if sendToWatchAfterPicking && !newDocuments.isEmpty {
                        sendDocumentsToWatch(newDocuments)
                    }
                }
            }
            .alert("Status", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if connectivityManager.isTransferring {
                    TransferProgressView(
                        progress: connectivityManager.transferProgress,
                        status: connectivityManager.transferStatus
                    )
                }
            }
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            pdfManager.removeDocument(at: index)
        }
    }

    private func sendToWatch(_ document: PDFDocumentItem) {
        connectivityManager.sendPDF(document) { success in
            DispatchQueue.main.async {
                alertMessage = success ? "PDF sent to Watch!" : "Failed to send PDF"
                showingAlert = true
            }
        }
    }

    private func sendAllToWatch() {
        connectivityManager.sendAllPDFs(pdfManager.documents) { success in
            DispatchQueue.main.async {
                alertMessage = success ? "All PDFs sent to Watch!" : "Failed to send some PDFs"
                showingAlert = true
            }
        }
    }

    private func sendDocumentsToWatch(_ documents: [PDFDocumentItem]) {
        connectivityManager.sendAllPDFs(documents) { success in
            DispatchQueue.main.async {
                let count = documents.count
                if success {
                    alertMessage = count == 1 ? "PDF sent to Watch!" : "\(count) PDFs sent to Watch!"
                } else {
                    alertMessage = "Failed to send some PDFs"
                }
                showingAlert = true
            }
        }
    }
}

struct PDFDocumentRow: View {
    let document: PDFDocumentItem
    let onSend: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.red)
                .font(.title2)

            VStack(alignment: .leading) {
                Text(document.name)
                    .font(.headline)
                Text("\(document.pageCount) pages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onSend) {
                Image(systemName: "applewatch")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct TransferProgressView: View {
    let progress: Double
    let status: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text(status.isEmpty ? "Sending to Watch..." : status)
                .font(.headline)

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let pdfManager: PDFDocumentManager
    let sendToWatch: Bool
    let onDocumentsPicked: ([PDFDocumentItem]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(pdfManager: pdfManager, onDocumentsPicked: onDocumentsPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let pdfManager: PDFDocumentManager
        let onDocumentsPicked: ([PDFDocumentItem]) -> Void

        init(pdfManager: PDFDocumentManager, onDocumentsPicked: @escaping ([PDFDocumentItem]) -> Void) {
            self.pdfManager = pdfManager
            self.onDocumentsPicked = onDocumentsPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var addedDocuments: [PDFDocumentItem] = []
            for url in urls {
                if let doc = pdfManager.addDocument(from: url) {
                    addedDocuments.append(doc)
                }
            }
            onDocumentsPicked(addedDocuments)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
