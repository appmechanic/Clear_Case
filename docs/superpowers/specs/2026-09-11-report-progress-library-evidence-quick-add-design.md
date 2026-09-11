# Report progress, photo-library evidence, Quick Add, terminology

Client feedback batch 2 (Sep 2026).

## Report generation progress

`PDFGenerator.generateReport(onProgress:)` reports `(0.0–1.0, stage)`; the
Export sheet swaps its Generate button for a percentage bar and blocks closing
(`PopScope`) until the report opens. Stages: preparing 2% → case details 8% →
photos 10–75% (per photo) → layout 78% → finalising 88% → opening 100%.

What was making it look frozen, and the fixes:

- Photos were converted to **PNG**, which the pdf package decodes in Dart on
  the UI isolate while painting. They're now converted to **JPEG** with
  `flutter_image_compress` (native thread), and JPEG is embedded without
  decoding. The engine-codec PNG path remains as a fallback.
- Photo downloads ran one at a time; now 4 run in parallel.
- `pdf.save()` ran inside `Printing.layoutPdf`'s `onLayout` with no feedback;
  it now runs first with `enableEventLoopBalancing: true` and the bytes are
  handed to `layoutPdf`.
- Each stage waits for a frame (capped at 100 ms, so a backgrounded app can't
  stall) so the bar paints before synchronous layout work.

## Photo-library evidence

The attachment picker has three sources: **Take a photo** (stamped with the
time and location, as before), **Choose from photo library**
(`ImagePicker.pickMultiImage`, new), and **Upload documents or files**
(FilePicker).

The source is recorded in the file name — `..._cc-camera.jpg` /
`..._cc-library.jpg` — which carries through to the Storage download URL.
`evidenceSourceOf(url)` (`lib/core/utils/evidence_source.dart`) reads it back,
so there's no Firestore schema change and it works for every record type.
Images picked via Files are also tagged library. Documents and older uploads
are `unknown` and show no badge. `dispute_provider.dart` renamed files by
index, so it uses `taggedStorageName` to keep the tag.

Where it shows: badges on picker and edit tiles, detail-screen thumbnails, a
notice in the full-screen viewer, an inline notice under the picker, and a
line under each photo in the PDF. `displayNameFromUrl` strips the tag.

## Quick Add

`QuickAddButton` (`lib/views/widgets/quick_add_button.dart`) is a FAB on
Insights (opens the entry-type picker) and on the Custody, Payments, Disputes
and Non-compliance detail screens (opens that form). It lines CalendarProvider
up with the Insights case first, since the forms read the case from there.
Detail screens reload their list afterwards and re-apply their filters and
search.

## Terminology

"Case Number" → "Case Reference Number" in the case setup form, the PDF header
and cover, and the empty-state fallback. The Firestore field stays
`caseNumber`.
