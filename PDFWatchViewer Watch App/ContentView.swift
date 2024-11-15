import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            Group {
                if connectivityManager.documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No PDFs")
                            .font(.headline)
                        Text("Send PDFs from iPhone")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List(connectivityManager.documents) { document in
                        NavigationLink(destination: PDFViewerView(document: document)) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text(document.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text("\(document.pageCount) pages")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("PDFs")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
