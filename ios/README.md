# iOS Modules (Iteration 1: Receipt MVP)

This directory contains Swift code scaffolding for the Iteration 1 deliverables defined in IMPLEMENTATION_PLAN.md. The code targets iOS (Swift, iOS 16+) and is organized as core modules that can be integrated into an Xcode app project.

Modules included:
- Core/Models: `Receipt`, `OCRBlock`
- ReceiptIntel: Extraction heuristics (date, totals, vendor, payment), auto-naming
- OCRKit: Vision-based OCR service (protocol + `VisionOCRService` implementation)
- ImageFX: Compact receipt processing profile (downscale + JPEG re-encode placeholder)
- PDFBuilder: PDFKit-based builder with optional text layer (selectable text)
- CSVExporter: Monthly CSV export function
- ShareHub: Share profiles (Standard, Compact)

Notes:
- Some modules use conditional compilation (`#if canImport(UIKit)` / `#if canImport(PDFKit)` / `#if canImport(Vision)`) so the repository remains portable. Real functionality activates on iOS.
- The ImageFX and PDF text-layer implementations are minimal for repo portability; extend them in-app with full VisionKit/Core Image pipelines per SPEC.md.

Suggested next step:
- Create an Xcode project under `ios/App/`, add these Core modules (either as a Swift Package or as sources), and wire the Scan → OCR → Extract → PDF → Share flow.

