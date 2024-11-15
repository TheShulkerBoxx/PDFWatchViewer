import SwiftUI
import WatchKit

struct PDFViewerView: View {
    let document: WatchPDFDocument
    @State private var currentPage = 0
    @State private var zoomScale: Double = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var pageImage: UIImage?
    @State private var isLoading = true
    @FocusState private var isFocused: Bool

    private let minZoom: Double = 1.0
    private let maxZoom: Double = 5.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if isLoading {
                    ProgressView()
                } else if let image = pageImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .offset(offset)
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    guard zoomScale > 1.0 else { return }
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = constrainOffset(newOffset, in: geometry.size)
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .focusable(true)
                        .focused($isFocused)
                        .digitalCrownRotation(
                            $zoomScale,
                            from: minZoom,
                            through: maxZoom,
                            by: 0.1,
                            sensitivity: .low,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                        .onChange(of: zoomScale) { oldValue, newValue in
                            if newValue <= minZoom {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            } else {
                                offset = constrainOffset(offset, in: geometry.size)
                                lastOffset = offset
                            }
                        }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("\(currentPage + 1)/\(document.pageCount)")
                    .font(.caption2)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage == 0)

                Spacer()

                Button(action: nextPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage >= document.pageCount - 1)
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isFocused = true
            loadPage()
        }
        .onChange(of: currentPage) { _, _ in
            loadPage()
        }
    }

    private func loadPage() {
        isLoading = true
        zoomScale = 1.0
        offset = .zero
        lastOffset = .zero

        // Load pre-rendered image from file
        let pageImageURL = document.pageImageURL(for: currentPage)

        DispatchQueue.global(qos: .userInitiated).async {
            var loadedImage: UIImage? = nil

            if FileManager.default.fileExists(atPath: pageImageURL.path) {
                if let data = try? Data(contentsOf: pageImageURL) {
                    loadedImage = UIImage(data: data)
                }
            }

            DispatchQueue.main.async {
                self.pageImage = loadedImage
                self.isLoading = false
            }
        }
    }

    private func nextPage() {
        if currentPage < document.pageCount - 1 {
            currentPage += 1
        }
    }

    private func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }

    private func constrainOffset(_ proposedOffset: CGSize, in viewSize: CGSize) -> CGSize {
        guard zoomScale > 1.0 else {
            return .zero
        }

        let scaledWidth = viewSize.width * zoomScale
        let scaledHeight = viewSize.height * zoomScale
        let extraWidth = (scaledWidth - viewSize.width) / 2
        let extraHeight = (scaledHeight - viewSize.height) / 2

        let constrainedWidth = max(-extraWidth, min(extraWidth, proposedOffset.width))
        let constrainedHeight = max(-extraHeight, min(extraHeight, proposedOffset.height))

        return CGSize(width: constrainedWidth, height: constrainedHeight)
    }
}
