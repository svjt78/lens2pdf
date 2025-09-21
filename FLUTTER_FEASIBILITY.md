# Flutter Feasibility Report

This note evaluates which milestones from `IMPLEMENTATION_PLAN.md` can run purely in the Flutter codebase (`mobile_app/*`) and where native iOS integrations remain required.

## Summary
- Flutter can continue to power the user experience, persistence, and export surfaces already present in `mobile_app/`.
- Core iteration deliverables that depend on VisionKit, Core Image, PDFKit, LocalAuthentication, Core Spotlight, EventKit, etc., cannot meet the spec using Flutter-only packages; they still require native bridges.
- Recommended approach: keep Flutter for UX and cross-platform reach, expose native Swift modules through platform channels for the advanced capture/OCR/export stack.

## Iteration 0 — Foundations (`IMPLEMENTATION_PLAN.md:33-44`)
- **Feasible in Flutter:** tab shell, library list, settings persistence, PDF sharing (existing `library_screen.dart` + `settings_service.dart`).
- **Requires native modules:** VisionKit multi-page capture, Core Image preprocessing, PDFKit rendering; Flutter camera/image/pdf plugins offer temporary parity but do not satisfy the VisionKit/quality requirements.

## Iteration 1 — Receipt MVP (`IMPLEMENTATION_PLAN.md:45-57`)
- **Feasible in Flutter:** metadata editing UI, month/tag filters, CSV export, Share profile selectors (extend `library_repository.dart`, `share_service.dart`).
- **Requires native modules:** OCR text layer (OCRKit), ReceiptIntel extraction/auto-naming, ImageFX compact profile; no Flutter package currently matches the geometry-level control expected in the spec.

## Iteration 2 — ID Mode + Vault (`IMPLEMENTATION_PLAN.md:58-70`)
- **Feasible in Flutter:** ID capture screens, settings for automation.
- **Requires native modules:** redaction rasterization, watermarking, Vault protections (Face ID, NSFileProtectionComplete) via Swift; Flutter can only trigger these through channels.

## Iteration 3 — Return Guard, Search, Collections (`IMPLEMENTATION_PLAN.md:71-83`)
- **Feasible in Flutter:** collections UI, batch export, reminder/search interface elements.
- **Requires native modules:** EventKit reminders, Core Spotlight index, duplicate detection leveraging native APIs.

## Iteration 4 — Quality & Accessibility (`IMPLEMENTATION_PLAN.md:84-105`)
- **Feasible in Flutter:** accessibility polish, large-text support, diagnostics screen, general UX tuning.
- **Requires native modules:** capture quality coach heuristics tied to VisionKit/ImageFX, low-level performance tuning of the native pipeline.

## Next Steps
1. Keep delivering Flutter UI/features (library filters, CSV export) that fit within existing Dart services.
2. Define platform channel contracts for VisionKit capture, ImageFX preprocessing, OCRKit text layers, ReceiptIntel extraction, and ShareHub profiles.
3. Wire those Swift modules into the Flutter app incrementally so future iterations satisfy the native-spec acceptance criteria while preserving cross-platform UI.

