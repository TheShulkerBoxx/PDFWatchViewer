# PDFWatchViewer

An iOS and Apple Watch app for viewing PDFs on your Apple Watch.

## Features

- **iOS App**: Upload and manage multiple PDF documents
- **Apple Watch App**: View PDFs with zoom and pan support
  - Digital Crown zoom (1x to 5x)
  - Single finger pan/drag navigation
  - Page navigation

## Architecture

PDFs are rendered to images on the iOS device (since PDFKit is not available on watchOS) and transferred to the Apple Watch via WatchConnectivity.

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+

## Building

```bash
# Generate project (if needed)
ruby create_project.rb

# Build iOS app (includes Watch app)
xcodebuild -scheme "PDFWatchViewer" -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

## Project Structure

```
PDFWatchViewer/
├── PDFWatchViewer/           # iOS app sources
│   ├── PDFWatchViewerApp.swift
│   ├── ContentView.swift
│   ├── PDFDocumentManager.swift
│   └── WatchConnectivityManager.swift
├── PDFWatchViewer Watch App/ # watchOS app sources
│   ├── PDFWatchViewerApp.swift
│   ├── ContentView.swift
│   ├── PDFViewerView.swift
│   └── WatchConnectivityManager.swift
└── create_project.rb         # Xcode project generator
```
