import SwiftUI

@main
struct PDFWatchViewer_Watch_AppApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
