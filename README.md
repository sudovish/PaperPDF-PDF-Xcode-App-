# Paper PDF - iOS PDF Toolkit

Paper PDF is an iOS SwiftUI app for scanning, importing, editing, merging, splitting, compressing, previewing, and exporting PDF documents. It was built as a practical document utility for people who need common PDF workflows directly on an iPhone without relying on a server-side document processor.

This repository is intended as a portfolio-facing source project. It highlights SwiftUI app structure, PDFKit document manipulation, VisionKit scanning, Photos/File imports, local persistence, UIKit bridging, async document processing, and an ad-supported export flow.

## What The App Does

Paper PDF brings several everyday PDF tools into one mobile app:

- Scan paper documents into multi-page PDFs using the iPhone camera.
- Convert one or more images from Photos or Files into a PDF.
- Merge multiple PDFs into one output file.
- Reorder or remove pages before merging.
- Split or extract selected pages from an existing PDF.
- Mark up PDFs with pen, highlight, and eraser tools.
- Compress PDFs with multiple quality presets.
- Preview PDFs inside the app with PDFKit.
- Share or export generated PDFs through native iOS sheets.
- Keep a local recent-documents library with pinning.
- Store documents offline in app support storage.

## Tech Stack

- Swift
- SwiftUI
- PDFKit
- VisionKit
- PhotosUI
- UIKit bridges through `UIViewRepresentable` and `UIViewControllerRepresentable`
- StoreKit-ready purchase service surface
- Google Mobile Ads SDK integration
- Xcode project target: `Paper PDF`
- Bundle identifier: `com.cortex.paperpdf`
- Deployment target in the project file: iOS 17.6

## App Architecture

The codebase is organized around a small SwiftUI app shell, shared app state, service classes, and tool-specific views.

```text
PaperPDF/
  App/
    PaperPDFApp.swift
    AppCoordinator.swift
  Models/
    DocumentItem.swift
    ToolType.swift
  Services/
    AdMobService.swift
    PDFService.swift
    PurchaseService.swift
    ScanService.swift
    StorageService.swift
  ViewModels/
    AppViewModel.swift
  Views/
    HomeView.swift
    PDFPreviewView.swift
    RootTabView.swift
    SettingsView.swift
    ToolsView.swift
    UIKit/PDFKitRepresentedView.swift
  Resources/
    Info.plist
    Assets.xcassets/
PaperPDF.xcodeproj/
Scripts/
```

## Main App Entry

`PaperPDFApp.swift` is the SwiftUI entry point. It creates a shared `AppViewModel`, injects it into the view hierarchy, loads initial local data when the app starts, and handles incoming file URLs from share/open-in workflows.

This is the app's top-level lifecycle hub:

- Creates the root `RootTabView`.
- Provides shared state with `.environmentObject(appViewModel)`.
- Loads saved documents and settings with `loadInitialData()`.
- Handles external document URLs with `onOpenURL`.

## Shared State And Workflow Control

`AppViewModel.swift` is the central state object for the app. It owns the document list, selected tab, selected preview document, loading/error states, pending tool navigation, and service instances.

Key responsibilities:

- Load saved documents from local storage.
- Import PDFs and images from Files/share sheet URLs.
- Convert imported images into PDFs.
- Save generated PDFs back into the local document library.
- Maintain sorted/pinned recent documents.
- Persist document metadata.
- Store default export-folder preference.
- Present interstitial ads before export actions.
- Coordinate scan, merge, split, markup, compress, share, and export flows.

The view model uses detached tasks for heavier document operations so the UI stays responsive while PDFs are read, written, converted, or counted.

## PDF Processing Service

`PDFService.swift` contains the core PDF logic built on PDFKit and UIKit rendering APIs.

It supports:

- Counting PDF pages from `Data` or `URL`.
- Rendering first-page thumbnails.
- Creating a PDF from an array of `UIImage` pages.
- Merging multiple PDFs.
- Merging selected page ranges and reordered pages.
- Extracting selected pages into a new PDF.
- Compressing a PDF by rendering each page to an image and rebuilding the document.

The compression system has three presets:

- `High`: better visual quality, less size reduction.
- `Balanced`: default middle-ground preset.
- `Small`: stronger size reduction with more quality tradeoff.

Compression is local-only. It re-renders PDF pages at a preset scale, JPEG-compresses them, and draws the compressed images back into a fresh PDF.

## Local Storage

`StorageService.swift` keeps the app offline-first.

It stores generated/imported PDF files under the app support directory:

```text
Application Support/Paper PDF/Documents/
```

It also maintains a `metadata.json` file containing each document's:

- UUID
- display file name
- relative storage path
- creation date
- page count
- file size
- pinned state

The service includes a legacy migration path from an older `PDFToolkit` storage folder into the newer `Paper PDF` folder, which keeps existing user data available after the app rename.

## Home Screen

`HomeView.swift` is the main launch experience. It shows:

- The Paper PDF title.
- A grid of PDF tools.
- Recent documents.
- Pinned-document indicators.
- Document metadata such as page count, size, and creation date.
- A loading overlay during processing.

The tool cards route users into the individual workflows: Scan, Image Convert, Merge, Split/Extract, Markup, and Compress.

## Tools Screen And Tool Workflows

Most of the document tools live in `ToolsView.swift`. It contains the SwiftUI workflows and UIKit wrappers for the PDF operations.

### Scan

The Scan flow uses VisionKit's document scanner on real iPhones. The simulator shows a fallback message because the camera-based scanner is unavailable there.

Scan workflow:

1. Launch the document scanner.
2. Receive one or more page images.
3. Convert images into a PDF with `PDFService.makePDF(from:)`.
4. Save the generated PDF into local storage.
5. Let the user preview, share, export, merge, mark up, or split the result.

### Image Convert

The Image Convert tool lets the user select images from Photos or Files and turn them into a multi-page PDF.

It uses:

- `PhotosPicker` for Photos library images.
- `fileImporter` for Files app image selection.
- async loading to preserve selected image order.
- `PDFService.makePDF(from:)` for PDF generation.

After conversion, the generated document can be previewed, shared, or saved to Files.

### Merge

The Merge tool combines multiple PDF files into one output PDF.

It supports:

- Multi-select PDF picking.
- Duplicate filtering.
- PDF page-count loading.
- Reordering selected files.
- Removing files from the merge set.
- Opening a file-specific page editor.
- Reordering or removing pages inside each input PDF before merge.
- Progress updates while merging.

The actual merge uses `PDFService.mergePDFs(sources:)`, which accepts `MergePDFSource` values containing a URL plus an optional page order.

### Split / Extract

The Split / Extract tool lets the user select a PDF, view page thumbnails, choose specific pages, and save those pages into a new PDF.

It uses PDFKit thumbnails for the page grid and `PDFService.extractPages(from:selectedPageIndices:)` for the output document.

### Markup

The Markup tool lets users draw directly over a PDF.

It includes:

- Recent document selection.
- Files-based PDF picking.
- A full-screen PDF editor.
- Pen, highlight, and eraser modes.
- Color selection.
- Stroke thickness selection.
- PDFKit annotation creation.

The editor uses a custom UIKit container with a `PDFView` and a transparent gesture overlay. User gestures are translated into PDF page coordinates and committed as PDF annotations.

### Compress

The Compress tool reduces file size using `PDFService.compressPDF(at:preset:)`.

Users can select a PDF from Files or recent documents, choose a compression preset, run compression, then preview, share, or export the compressed copy.

## Preview And Export

`PDFPreviewView.swift` displays a selected PDF using PDFKit and provides toolbar actions for sharing or exporting.

The UIKit bridge pieces are:

- `PDFKitRepresentedView`: wraps `PDFView` for SwiftUI.
- `ActivityView`: wraps `UIActivityViewController` for sharing.
- `FilesExportView`: wraps `UIDocumentPickerViewController` for saving a copy to Files.

## Settings

`SettingsView.swift` contains app preferences and rollout notes.

Current settings include:

- Default export folder picker.
- Ads explanation.
- Privacy explanation.
- Temporary rollout notes for free tools and disabled paid features.

The folder picker stores a bookmark in `UserDefaults` so the chosen export location can be remembered.

## Monetization And Ads

The app currently uses a temporary free-access model.

`PurchaseService.swift` keeps the old purchase-service surface intact, but `isProUnlocked` is currently always true and purchase/restore actions return a temporary-disabled message. This preserves the architecture for a future StoreKit flow without forcing broad UI refactors.

`AdMobService.swift` initializes Google Mobile Ads and preloads an interstitial ad. The app presents an ad only when the user taps final export/share actions, keeping editing workflows uninterrupted.

## Privacy Model

The core PDF tools are offline-first:

- PDFs are stored locally on device.
- Core document operations run locally.
- No account is required for scanning, importing, merging, splitting, markup, compression, preview, or export.
- Google AdMob is initialized for the export interstitial flow.

## How To Run

1. Clone the repository.
2. Open `PaperPDF.xcodeproj` in Xcode.
3. Select the `Paper PDF` target.
4. Choose an iPhone simulator or connected iPhone.
5. Build and run.

Scanning requires a real iPhone camera. The iOS Simulator can still be used for importing, previewing, merging, splitting, marking up, and compressing PDFs.

Command-line simulator build:

```bash
xcodebuild \
  -project PaperPDF.xcodeproj \
  -target "Paper PDF" \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## Portfolio Notes

This project demonstrates:

- SwiftUI state-driven UI architecture.
- Integrating UIKit/PDFKit components into SwiftUI.
- Working with security-scoped file URLs.
- Local persistence and metadata management.
- Async document processing for responsive UI.
- PDF page manipulation with PDFKit.
- Custom gesture overlays for PDF annotation.
- Native iOS sharing and Files export flows.
- App Store-style support for privacy, ads, purchases, and document type registration.

## Repository Status

This repository was created to make the Paper PDF app source visible from the GitHub profile for portfolio and employer review.
