import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/utils/child_names.dart';
import '../../core/utils/custody_span.dart';
import '../../core/utils/evidence_source.dart';
import '../../core/utils/timeframe.dart';
import '../../models/calender_event_model.dart';
import '../../models/case_model.dart';
import 'export_filter.dart';
import 'file_type_icon.dart';
import 'pdf/report_theme.dart';

/// Builds the "Family Law — Evidence & Event Record" PDF.
///
/// Layout: a cover page, then a MultiPage document with a running header
/// (logo, case, reporting period) and footer (page X of Y):
///   1. Executive Summary — case overview counts, children, financial record,
///      and every included child's details (DOB, school, address).
///   2. Detailed Records — chronological table of every record.
///   3. Event Details — one card per record (E001, E002 … in date order).
///   4. Evidence Index — records that carry attachments.
///   5. Recording Notes — what the document is (and isn't).
///   6. Evidence Attachments — image grid plus linked documents.
class PDFGenerator {
  /// Builds the report and opens the system print/share sheet.
  ///
  /// [onProgress] receives 0.0–1.0 plus a short stage description so the
  /// export sheet can show a percentage — photo downloads and page layout can
  /// take long enough to look like a freeze otherwise.
  static Future<void> generateReport({
    required String caseName,
    required String caseId,
    required ExportOptions options,
    required List<CalendarEvent> allEvents,
    CaseModel? caseModel,
    ReportProgressCallback? onProgress,
  }) async {
    // Reports a stage, then lets a frame paint before the next (possibly
    // synchronous) chunk of work. Capped so a backgrounded app — which
    // produces no frames — can't stall generation.
    Future<void> stage(double progress, String message) async {
      onProgress?.call(progress, message);
      await Future.any([SchedulerBinding.instance.endOfFrame, Future<void>.delayed(const Duration(milliseconds: 100))]);
    }

    await stage(0.02, "Preparing report…");
    final fonts = await ReportFonts.load();

    await stage(0.08, "Loading case details…");
    final preparedFor = await _fetchPreparedFor();

    // The selected period (Australian financial year by default) or the manual
    // custom range. A multi-day custody entry is included when any of its days
    // fall inside the period.
    final window = options.window;
    bool matchesDate(CalendarEvent event) {
      if (event.type == EventType.custody) {
        return window.overlaps(event.span.start, event.span.end);
      }
      return window.contains(event.date);
    }

    bool sectionEnabled(CalendarEvent event) {
      switch (event.type) {
        case EventType.custody:
          return options.reportSections["Custody"] == true;
        case EventType.payment:
          return options.reportSections["Payments"] == true;
        case EventType.dispute:
          return options.reportSections["Disputes"] == true;
        case EventType.nonCompliance:
          return options.reportSections["Non-Compliance"] == true;
        case EventType.reminder:
          return false;
      }
    }

    // Every record in the report: in range, for the selected children (an
    // untagged dispute / non-compliance record applies to every child, so it
    // shows under any child filter), and of a type ticked under "Include in
    // Report". De-duplicated defensively — multi-day custody entries are
    // filed under each day they cover in the calendar.
    final seen = <String>{};
    final events =
        allEvents
            .where(
              (e) =>
                  !e.isScheduledRule &&
                  seen.add(_eventKey(e)) &&
                  matchesDate(e) &&
                  matchesChildFilter(e.childIds, options.childIds) &&
                  sectionEnabled(e),
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.date.compareTo(b.date);
            return byDate != 0 ? byDate : a.type.index.compareTo(b.type.index);
          });

    // Only the children actually included in this report (per the export
    // filter). An empty filter means every child in the case.
    final reportChildren = (caseModel?.children ?? const <ChildModel>[])
        .where((c) => options.childIds.isEmpty || options.childIds.contains(c.id))
        .toList();

    // Pre-fetch image attachments before building pages — MultiPage.build is
    // synchronous, so image bytes must be resolved up front. This is usually
    // the slowest step, so it owns most of the progress bar (10–75%).
    await stage(0.10, "Collecting attachments…");
    final attachments = await _collectAttachments(
      events,
      onImage: (done, total) => onProgress?.call(0.10 + 0.65 * (done / total), "Adding photos ($done of $total)…"),
    );

    final report = _ReportLayout(
      fonts: fonts,
      options: options,
      caseModel: caseModel,
      caseNumber: caseName.trim().isNotEmpty ? caseName.trim() : (caseModel?.caseNumber ?? '').trim(),
      events: events,
      children: reportChildren,
      attachments: attachments,
      window: window,
      preparedName: preparedFor.name,
      preparedEmail: preparedFor.email,
      generatedAt: DateTime.now(),
    );

    // addPage lays the whole document out synchronously.
    await stage(0.78, "Laying out pages…");
    final pdf = pw.Document(title: "ClearCase Evidence & Event Record", author: preparedFor.name, creator: "ClearCase");
    report.addTo(pdf);

    // Save once, up front, so the progress bar covers it. Event-loop
    // balancing keeps the UI responsive while pages are painted; the byte
    // serialisation itself runs in a background isolate.
    await stage(0.88, "Finalising PDF…");
    final bytes = await pdf.save(enableEventLoopBalancing: true);

    await stage(1.0, "Opening report…");
    await Printing.layoutPdf(
      name: 'ClearCase_Court_Report',
      onLayout: (format) async => bytes,
      // The report is fixed A4 and already rendered. With dynamic layout the
      // iOS plugin (printing 5.14.x) asks Flutter for the document from
      // UIKit's page-count callback, which runs off the main thread —
      // "net.nfet.printing sent a message ... on a non-platform thread".
      // Non-dynamic asks once, from the platform thread.
      dynamicLayout: false,
    );
  }

  /// Lays the report out from already-filtered [events] with built-in fonts
  /// and no attachments — no Firebase, network or share sheet — so a test
  /// can render it and the pages can be checked by eye.
  @visibleForTesting
  static pw.Document buildPreviewDocument({
    required ExportOptions options,
    required List<CalendarEvent> events,
    required CaseModel caseModel,
    ReportFonts? fonts,
    DateTime? generatedAt,
  }) {
    final pdf = pw.Document();
    _ReportLayout(
      fonts: fonts ?? ReportFonts(pw.Font.helvetica(), pw.Font.helvetica(), pw.Font.helveticaBold()),
      options: options,
      caseModel: caseModel,
      caseNumber: caseModel.caseNumber,
      events: events,
      children: caseModel.children,
      attachments: const {},
      window: options.window,
      preparedName: "Sample Parent",
      preparedEmail: "parent@example.com",
      generatedAt: generatedAt ?? DateTime.now(),
    ).addTo(pdf);
    return pdf;
  }

  static String _eventKey(CalendarEvent e) => "${e.type.name}:${e.id}";

  // "Prepared for" = the signed-in account holder. Prefers the profile's
  // first/last name and email in Firestore; falls back to Firebase Auth.
  static Future<({String name, String email})> _fetchPreparedFor() async {
    final user = FirebaseAuth.instance.currentUser;
    String name = '';
    String email = '';

    if (user != null) {
      try {
        final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
        final doc = await firestore.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          final fn = (data['firstName'] ?? '').toString().trim();
          final ln = (data['lastName'] ?? '').toString().trim();
          name = "$fn $ln".trim();
          email = (data['email'] ?? '').toString().trim();
        }
      } catch (_) {
        // Falls back to whatever Auth provides.
      }
    }

    if (name.isEmpty) name = (user?.displayName ?? '').trim();
    if (email.isEmpty) email = (user?.email ?? '').trim();
    return (name: name.isEmpty ? '—' : name, email: email);
  }

  // --- Attachments ---

  // Bounds on embedded images so a photo-heavy report can't exhaust memory or
  // produce an unusable multi-hundred-MB PDF. Images beyond the cap, and any
  // that fail to load, render as a tappable link instead.
  static const int _maxEmbeddedImages = 50;
  static const int _imageMaxWidth = 1280;
  // Photos downloaded in parallel — enough to hide per-request latency
  // without flooding a mobile connection.
  static const int _downloadConcurrency = 4;

  /// Resolves every record's attachments up front, keyed by [_eventKey].
  /// Image bytes are downloaded so photos can render as thumbnails; documents
  /// are kept as link targets. [onImage] is called as each embedded photo
  /// finishes (done, total).
  static Future<Map<String, List<_Attachment>>> _collectAttachments(
    List<CalendarEvent> events, {
    void Function(int done, int total)? onImage,
  }) async {
    // Pass 1: decide which images get embedded (first _maxEmbeddedImages, in
    // report order) so downloads can then run in parallel.
    final map = <String, List<_Attachment>>{};
    final toEmbed = <_Attachment>[];
    int skippedForCap = 0;
    for (final e in events) {
      if (e.attachmentUrls.isEmpty) continue;
      final list = <_Attachment>[];
      for (final url in e.attachmentUrls) {
        final attachment = _Attachment(
          url: url,
          fileName: _fileNameFromUrl(url),
          isImage: isImageExtension(extensionFromUrl(url)),
          source: evidenceSourceOf(url),
        );
        if (attachment.isImage) {
          if (toEmbed.length < _maxEmbeddedImages) {
            toEmbed.add(attachment);
          } else {
            skippedForCap++;
          }
        }
        list.add(attachment);
      }
      map[_eventKey(e)] = list;
    }

    // Pass 2: download + downscale. null image -> link fallback.
    int next = 0;
    int done = 0;
    Future<void> worker() async {
      while (next < toEmbed.length) {
        final attachment = toEmbed[next++];
        attachment.image = await _downscaledNetworkImage(attachment.url, maxWidth: _imageMaxWidth);
        onImage?.call(++done, toEmbed.length);
      }
    }

    await Future.wait(List.generate(_downloadConcurrency, (_) => worker()));

    if (skippedForCap > 0) {
      debugPrint(
        'PDF export: embedded $_maxEmbeddedImages image(s); $skippedForCap more shown as links to bound memory/file size.',
      );
    }
    return map;
  }

  /// Downloads [url] and returns a PDF image downscaled to at most [maxWidth]
  /// pixels wide. Resizing bounds the decoded buffer — the real driver of
  /// out-of-memory crashes when many large photos are embedded. Returns null
  /// on any failure so the caller renders a link.
  ///
  /// Re-encodes to JPEG on a native thread: the pdf package embeds JPEG bytes
  /// as-is, whereas PNG is fully decoded in Dart on the UI isolate while the
  /// document is painted — the main cause of the report appearing to freeze.
  static Future<pw.ImageProvider?> _downscaledNetworkImage(String url, {required int maxWidth}) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);

      try {
        final jpeg = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: maxWidth,
          minHeight: maxWidth,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (jpeg.isNotEmpty) return pw.MemoryImage(jpeg);
      } catch (_) {
        // Fall through to the engine codec below.
      }

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
      final frame = await codec.getNextFrame();
      final pngData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (pngData == null) return null;
      return pw.MemoryImage(pngData.buffer.asUint8List());
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  // Firebase Storage URLs keep the original file name in their encoded path:
  // ".../o/users%2F<uid>%2F...%2Freceipt.pdf?alt=media&token=...".
  static String _fileNameFromUrl(String url) {
    try {
      var path = url.split('?').first;
      path = Uri.decodeComponent(path);
      final segment = path.split('/').last.trim();
      return segment.isNotEmpty ? segment : 'attachment';
    } catch (_) {
      return 'attachment';
    }
  }
}

/// One attachment of a record. [image] is non-null only for photos that
/// downloaded successfully; otherwise the file is shown as a link.
class _Attachment {
  final String url;
  final String fileName;
  final bool isImage;
  // Captured in-app (stamped) vs. picked from the device library.
  final EvidenceSource source;
  // Filled in by _collectAttachments once the download finishes.
  pw.ImageProvider? image;

  _Attachment({required this.url, required this.fileName, required this.isImage, this.source = EvidenceSource.unknown});
}

/// Builds every page of the report from the already-filtered data.
///
/// Overflow rules (MultiPage can't split a single widget taller than a page):
/// tables are split by row, long free text is clipped in tables and split
/// into page-breakable chunks in event cards, and grids are emitted one row
/// per widget.
class _ReportLayout {
  final ReportFonts fonts;
  final ExportOptions options;
  final CaseModel? caseModel;
  final String caseNumber;
  final List<CalendarEvent> events;
  final List<ChildModel> children;
  final Map<String, List<_Attachment>> attachments;
  final TimeWindow window;
  final String preparedName;
  final String preparedEmail;
  final DateTime generatedAt;

  /// E001, E002 … in chronological order, keyed by event key.
  late final Map<String, String> refs = {
    for (var i = 0; i < events.length; i++) PDFGenerator._eventKey(events[i]): "E${(i + 1).toString().padLeft(3, '0')}",
  };

  _ReportLayout({
    required this.fonts,
    required this.options,
    required this.caseModel,
    required this.caseNumber,
    required this.events,
    required this.children,
    required this.attachments,
    required this.window,
    required this.preparedName,
    required this.preparedEmail,
    required this.generatedAt,
  });

  static final _numDate = DateFormat('dd/MM/yyyy');
  static final _shortDate = DateFormat('dd MMM yyyy');
  static final _longDate = DateFormat('d MMMM yyyy');
  static final _time = DateFormat('h:mm a');

  // Content width of an A4 page with the MultiPage margins below.
  static const double _hMargin = 44;

  bool _enabled(String section) => options.reportSections[section] == true;

  String get _caseLabel => caseNumber.isEmpty ? "Case report" : "Case $caseNumber";

  /// "01 Jul 2026 – 16 Sep 2026". Open-ended presets run to today; an
  /// all-time report starts at the earliest record.
  late final String periodLabel = () {
    DateTime? start = window.start;
    if (start == null && events.isNotEmpty) start = dateOnly(events.first.date);
    final end = window.end ?? dateOnly(generatedAt);
    if (start == null) return "All records to ${_shortDate.format(end)}";
    return "${_shortDate.format(start)} – ${_shortDate.format(end)}";
  }();

  /// The preset's name ("Current FY (FY 2026–27)"), or "Custom range".
  String get _periodName {
    if (options.startDate != null || options.endDate != null) return ExportOptions.customRange;
    return Timeframe.label(options.timePeriod ?? Timeframe.allTime);
  }

  List<_Attachment> _attachmentsOf(CalendarEvent e) => attachments[PDFGenerator._eventKey(e)] ?? const [];

  String _refOf(CalendarEvent e) => refs[PDFGenerator._eventKey(e)] ?? '';

  // --- Styles ---

  pw.TextStyle _style({
    double size = 9,
    PdfColor color = ReportPalette.body,
    pw.Font? font,
    double? letterSpacing,
    double? lineSpacing,
  }) => pw.TextStyle(
    font: font ?? fonts.regular,
    fontSize: _scaledSize(size),
    color: color,
    letterSpacing: letterSpacing,
    lineSpacing: lineSpacing,
  );

  /// Sizes in this file are written at the mockup's scale, which prints too
  /// small to read comfortably. Body and label text (under 12pt) is enlarged
  /// by a quarter — 9pt body → ~11pt, 7pt labels → ~9pt — and headings a
  /// little; the large cover title stays as drawn.
  static double _scaledSize(double size) {
    if (size < 12) return size * 1.25;
    if (size < 20) return size * 1.15;
    return size;
  }

  pw.Widget _label(String text, {PdfColor color = ReportPalette.muted, double size = 7}) => pw.Text(
    text.toUpperCase(),
    style: _style(size: size, color: color, font: fonts.semiBold, letterSpacing: 1.1),
  );

  pw.Widget _rule({double vertical = 0}) => pw.Container(
    margin: pw.EdgeInsets.symmetric(vertical: vertical),
    height: 0.6,
    color: ReportPalette.rule,
  );

  pw.BoxDecoration get _cardDecoration =>
      pw.BoxDecoration(color: ReportPalette.card, borderRadius: pw.BorderRadius.circular(6));

  pw.Widget _pill(String text, PdfColor background, PdfColor foreground) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
    decoration: pw.BoxDecoration(color: background, borderRadius: pw.BorderRadius.circular(3)),
    child: pw.Text(
      text,
      style: _style(size: 6.5, color: foreground, font: fonts.semiBold, letterSpacing: 0.7),
    ),
  );

  pw.Widget _typePill(EventType type) {
    final (bg, fg) = ReportPalette.pill(type);
    return _pill(_typeName(type).toUpperCase(), bg, fg);
  }

  pw.Widget _wordmark({double logoSize = 16, double textSize = 12}) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      ReportIcons.logo(size: logoSize),
      pw.SizedBox(width: logoSize * 0.35),
      pw.Text(
        "ClearCase",
        style: _style(size: textSize, color: ReportPalette.ink, font: fonts.semiBold),
      ),
    ],
  );

  // --- Text helpers ---

  static String _clip(String text, int max) {
    final t = text.trim();
    return t.length <= max ? t : "${t.substring(0, max).trimRight()}…";
  }

  static String _orDash(String? value) => (value ?? "").trim().isEmpty ? "—" : value!.trim();

  static String _money(double value) => "\$${NumberFormat('#,##0.00').format(value)}";

  static String _typeName(EventType type) {
    switch (type) {
      case EventType.custody:
        return "Custody";
      case EventType.payment:
        return "Payment";
      case EventType.dispute:
        return "Dispute";
      case EventType.nonCompliance:
        return "Non-compliance";
      case EventType.reminder:
        return "Reminder";
    }
  }

  /// Which child(ren) a record belongs to. Untagged disputes / non-compliance
  /// are legacy whole-case records and read "All children".
  String _childLabel(CalendarEvent e) {
    if (e.childIds.isEmpty) {
      if (e.childNames.isNotEmpty) return e.childNames.join(", ");
      return e.type == EventType.dispute || e.type == EventType.nonCompliance ? allChildrenLabel : "Not specified";
    }
    final names = childNamesFor(e.childIds, caseModel);
    if (names.isNotEmpty) return names.join(", ");
    if (e.childNames.isNotEmpty) return e.childNames.join(", ");
    return childTagLabel(e.childIds, caseModel);
  }

  String _childFieldLabel(CalendarEvent e) => e.childIds.length == 1 ? "Child" : "Children";

  String _dateLabel(CalendarEvent e) {
    if (e.type == EventType.custody && e.span.isMultiDay) {
      return "${_numDate.format(e.span.start)} – ${_numDate.format(e.span.end)}";
    }
    return _numDate.format(e.date);
  }

  String? _timeRange(CalendarEvent e) {
    if (e.startTime == null && e.endTime == null) return null;
    final s = e.startTime != null ? _time.format(e.startTime!) : "—";
    final t = e.endTime != null ? _time.format(e.endTime!) : "—";
    return "$s – $t";
  }

  /// Custody period: "9:00 AM – 5:00 PM" for a single day, or
  /// "04/07/2026 9:00 AM – 06/07/2026 5:00 PM" across several.
  String _custodyPeriod(CalendarEvent e) {
    if (!e.span.isMultiDay) return _timeRange(e) ?? "${_numDate.format(e.date)} (all day)";
    final start = "${_numDate.format(e.span.start)}${e.startTime != null ? ' ${_time.format(e.startTime!)}' : ''}";
    final end = "${_numDate.format(e.span.end)}${e.endTime != null ? ' ${_time.format(e.endTime!)}' : ''}";
    return "$start – $end";
  }

  bool _isReceived(CalendarEvent e) => e.transactionType == 'PaymentReceived' || e.isReceived;

  /// Short multi-line summary for the Detailed Records table. Each line is
  /// clipped so a table row can never outgrow a page.
  String _summary(CalendarEvent e) {
    final lines = <String>[];
    void add(String? s) {
      if (s != null && s.trim().isNotEmpty) lines.add(_clip(s.replaceAll('\n', ' '), 90));
    }

    switch (e.type) {
      case EventType.custody:
        if (e.span.isMultiDay) add("${formatDaySpan(e.span.start, e.span.end)} · ${nightsLabel(e.span.nights)}");
        add(_timeRange(e));
        add(e.location);
        if (lines.isEmpty) add(e.description);
        break;
      case EventType.payment:
        add("${_money(e.amount ?? 0)} ${_isReceived(e) ? 'received' : 'paid'}");
        add(e.title == 'Payment' ? null : e.title);
        add(e.description);
        break;
      case EventType.dispute:
        add(e.category);
        add(e.description);
        break;
      case EventType.nonCompliance:
        add(e.title);
        if ((e.severity ?? '').trim().isNotEmpty) add("(${e.severity!.trim()})");
        add(e.party);
        break;
      case EventType.reminder:
        add(e.title);
        break;
    }
    return lines.isEmpty ? "—" : lines.take(4).join("\n");
  }

  // ===========================================================================
  // Document assembly
  // ===========================================================================

  void addTo(pw.Document pdf) {
    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, theme: fonts.theme),
        build: _buildCover,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(_hMargin, 28, _hMargin, 24),
          theme: fonts.theme,
        ),
        // Photo-heavy reports run long; the default cap is 20 pages.
        maxPages: 5000,
        header: _buildPageHeader,
        footer: _buildPageFooter,
        // Sections run on one after another; a new page starts only when
        // the current one is full.
        build: (context) => [
          ..._executiveSummary(),
          _sectionGap,
          ..._detailedRecords(),
          _sectionGap,
          ..._eventDetails(),
          _sectionGap,
          ..._evidenceIndex(),
          _sectionGap,
          ..._recordingNotes(),
          _sectionGap,
          ..._evidenceAttachments(),
        ],
      ),
    );
  }

  // --- Running header / footer (every page but the cover) ---

  pw.Widget _buildPageHeader(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: ReportPalette.rule, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _wordmark(),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _caseLabel,
                style: _style(size: 7.5, color: ReportPalette.ink, font: fonts.medium),
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(periodLabel, style: _style(size: 7, color: ReportPalette.muted)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: ReportPalette.rule, width: 0.6)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: _style(size: 7, color: ReportPalette.muted),
          ),
          pw.Spacer(),
          pw.Text("ClearCase · $_caseLabel", style: _style(size: 7, color: ReportPalette.muted)),
        ],
      ),
    );
  }

  pw.Widget get _sectionGap => pw.SizedBox(height: 30);

  // pw.Column (and so a Container holding one) splits across pages in this
  // pdf version, so anything that must stay whole is wrapped in Inseparable.
  pw.Widget _together(List<pw.Widget> children) => pw.Inseparable(
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: children),
  );

  /// Keeps [list]'s first widget (a heading or label) on the same page as the
  /// one after it, so a heading never sits alone at the foot of a page.
  List<pw.Widget> _keepFirstWithNext(List<pw.Widget> list) {
    if (list.length < 2) return list;
    return [_together([list[0], list[1]]), ...list.skip(2)];
  }

  /// A titled table whose heading stays with the header row and first few
  /// rows. The remaining rows continue in a second, borderless-top table, so
  /// they still break across pages row by row.
  List<pw.Widget> _headedTable(
    pw.Widget heading,
    Map<int, pw.TableColumnWidth> widths,
    List<String> headers,
    List<pw.TableRow> rows,
  ) {
    const lead = 3;
    pw.Table table(List<pw.TableRow> children) =>
        pw.Table(border: _tableBorder, columnWidths: widths, children: children);
    return [
      _together([heading, table([_tableHeader(headers), ...rows.take(lead)])]),
      if (rows.length > lead) table(rows.skip(lead).toList()),
    ];
  }

  pw.Widget _sectionHeading(int number, String title, [String? subtitle]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 24,
                child: pw.Text(
                  "$number.",
                  style: _style(size: 14, color: ReportPalette.ink, font: fonts.semiBold),
                ),
              ),
              pw.Text(
                title,
                style: _style(size: 14, color: ReportPalette.ink, font: fonts.semiBold),
              ),
            ],
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(subtitle, style: _style(size: 8.5, color: ReportPalette.muted)),
          ],
        ],
      ),
    );
  }

  pw.Widget _emptyState(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 14),
    decoration: _cardDecoration,
    child: pw.Text(text, style: _style(size: 9, color: ReportPalette.muted)),
  );

  // ===========================================================================
  // Cover
  // ===========================================================================

  pw.Widget _buildCover(pw.Context context) {
    final childNames = children.map((c) => c.name.trim()).where((n) => n.isNotEmpty).toList();
    final legalRep = (caseModel?.legalRep ?? '').trim();

    // Every block here is short and bounded (names/email are capped by
    // maxLines): a single-page Column silently drops whatever doesn't fit.
    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        // Large faint decorative "C", bleeding off the right edge.
        pw.Positioned(
          right: -95,
          bottom: 70,
          child: ReportIcons.logo(size: 330, color: ReportPalette.decor, stroke: 3.4),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(52, 46, 52, 36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _wordmark(logoSize: 26, textSize: 20),
                  pw.Spacer(),
                  pw.Text(
                    "SAFER CHILDREN,\nSTRONGER TOMORROWS.",
                    textAlign: pw.TextAlign.right,
                    style: _style(
                      size: 6.5,
                      color: ReportPalette.muted,
                      font: fonts.medium,
                      letterSpacing: 1.2,
                      lineSpacing: 2,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              _rule(),
              pw.SizedBox(height: 56),
              pw.Text(
                "Family Law",
                style: _style(size: 27, color: ReportPalette.ink, font: fonts.medium),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "Evidence & Event Record",
                style: _style(size: 27, color: ReportPalette.ink, font: fonts.medium),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                caseNumber.isEmpty ? "CASE REPORT" : "CASE ${caseNumber.toUpperCase()}",
                maxLines: 2,
                style: _style(size: 13, color: ReportPalette.ink, font: fonts.semiBold, letterSpacing: 2.6),
              ),
              pw.SizedBox(height: 28),
              pw.Text("Reporting period", style: _style(size: 8.5, color: ReportPalette.muted)),
              pw.SizedBox(height: 4),
              pw.Text(
                periodLabel,
                style: _style(size: 10.5, color: ReportPalette.ink, font: fonts.semiBold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(_periodName, style: _style(size: 8, color: ReportPalette.faint)),
              pw.SizedBox(height: 40),
              _coverBlock(
                ReportIcons.users,
                "Children",
                pw.Text(
                  childNames.isEmpty ? "—" : childNames.join("  ·  "),
                  maxLines: 3,
                  style: _style(size: 11.5, color: ReportPalette.ink, font: fonts.semiBold),
                ),
              ),
              pw.SizedBox(height: 22),
              _coverBlock(
                ReportIcons.user,
                "Prepared for",
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(preparedName, maxLines: 2, style: _style(size: 10, color: ReportPalette.ink)),
                    if (preparedEmail.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(preparedEmail, maxLines: 1, style: _style(size: 9, color: ReportPalette.muted)),
                    ],
                  ],
                ),
              ),
              if (legalRep.isNotEmpty) ...[
                pw.SizedBox(height: 22),
                _coverBlock(
                  ReportIcons.briefcase,
                  "Legal representative",
                  pw.Text(_clip(legalRep, 120), maxLines: 2, style: _style(size: 10, color: ReportPalette.ink)),
                ),
              ],
              pw.Spacer(),
              pw.Row(
                children: [
                  pw.Text(
                    "Generated: ${_longDate.format(generatedAt)}",
                    style: _style(size: 7.5, color: ReportPalette.muted),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    "Page ${context.pageNumber} of ${context.pagesCount}",
                    style: _style(size: 7.5, color: ReportPalette.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _coverBlock(String icon, String label, pw.Widget content) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ReportIcons.icon(icon, size: 17, color: ReportPalette.body),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: _label(label)),
              pw.SizedBox(height: 9),
              content,
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. Executive Summary
  // ===========================================================================

  List<pw.Widget> _executiveSummary() {
    final custody = events.where((e) => e.type == EventType.custody).toList();
    final payments = events.where((e) => e.type == EventType.payment).toList();
    final disputes = events.where((e) => e.type == EventType.dispute).toList();
    final nonCompliance = events.where((e) => e.type == EventType.nonCompliance).toList();
    final flagged = events.where((e) => e.isFlagged).toList();
    final custodyTotals = CustodyTotals.from(custody.map((e) => e.span), window);

    int flaggedOf(EventType t) => flagged.where((e) => e.type == t).length;
    int disputesIn(String category) => disputes.where((e) => e.category == category).length;

    final rows = <pw.Widget>[];
    void addRow(String icon, String label, int count, {String? detail}) {
      if (rows.isNotEmpty) rows.add(_rule());
      rows.add(_overviewRow(icon, label, "$count", detail: detail));
    }

    if (_enabled("Custody")) {
      addRow(ReportIcons.calendar, "Custody events", custodyTotals.entries);
      addRow(ReportIcons.moon, "Nights recorded", custodyTotals.nights);
    }
    if (_enabled("Payments")) addRow(ReportIcons.card, "Payment records", payments.length);
    if (_enabled("Disputes")) {
      addRow(
        ReportIcons.message,
        "Dispute records",
        disputes.length,
        detail: disputes.isEmpty
            ? null
            : "Communication ${disputesIn('Communication')} · Transfer issues ${disputesIn('Transfer Issues')} · "
                  "Payment disputes ${disputesIn('Payment Disputes')}",
      );
    }
    if (_enabled("Non-Compliance")) addRow(ReportIcons.alert, "Non-compliance records", nonCompliance.length);
    if (_enabled("Flagged Events")) {
      addRow(
        ReportIcons.flag,
        "Flagged events",
        flagged.length,
        detail: flagged.isEmpty
            ? null
            : "Custody ${flaggedOf(EventType.custody)} · Payments ${flaggedOf(EventType.payment)} · "
                  "Disputes ${flaggedOf(EventType.dispute)} · Non-compliance ${flaggedOf(EventType.nonCompliance)}",
      );
    }

    final overview = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: _cardDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _label("Case overview"),
          pw.SizedBox(height: 6),
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              child: pw.Text(
                "No record types were selected for this report.",
                style: _style(color: ReportPalette.muted),
              ),
            )
          else
            ...rows,
        ],
      ),
    );

    final childrenCard = _childrenCard(custody);
    final financialCard = _enabled("Payments") ? _financialCard(payments) : null;

    // Side by side (equal height) while the children list is short; stacked
    // otherwise so the pair can never outgrow a page.
    final pair = financialCard != null && children.length <= 6
        ? pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FixedColumnWidth(12), 2: pw.FlexColumnWidth()},
            children: [
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.full,
                children: [childrenCard, pw.SizedBox(), financialCard],
              ),
            ],
          )
        : null;

    return [
      _together([_sectionHeading(1, "Executive Summary"), overview]),
      pw.SizedBox(height: 12),
      if (pair != null)
        pair
      else ...[
        childrenCard,
        if (financialCard != null) ...[pw.SizedBox(height: 12), financialCard],
      ],
      pw.SizedBox(height: 22),
      ..._childDetails(),
    ];
  }

  pw.Widget _overviewRow(String icon, String label, String value, {String? detail}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          ReportIcons.icon(icon, size: 14, color: ReportPalette.body),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: _style(size: 9, color: ReportPalette.body)),
                if (detail != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(detail, style: _style(size: 7, color: ReportPalette.faint)),
                ],
              ],
            ),
          ),
          pw.Text(
            value,
            style: _style(size: 11, color: ReportPalette.ink, font: fonts.semiBold),
          ),
        ],
      ),
    );
  }

  pw.Widget _cardTitle(String icon, String label) => pw.Row(
    children: [
      ReportIcons.icon(icon, size: 13, color: ReportPalette.body),
      pw.SizedBox(width: 8),
      _label(label),
    ],
  );

  pw.Widget _childrenCard(List<CalendarEvent> custody) {
    pw.Widget entry(ChildModel child) {
      final count = events.where((e) => matchesChildFilter(e.childIds, [child.id])).length;
      final totals = CustodyTotals.from(custody.where((e) => e.childIds.contains(child.id)).map((e) => e.span), window);
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _clip(child.name, 60),
              style: _style(size: 10, color: ReportPalette.ink, font: fonts.semiBold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              count == 1 ? "1 recorded event" : "$count recorded events",
              style: _style(size: 8.5, color: ReportPalette.muted),
            ),
            if (_enabled("Custody")) ...[
              pw.SizedBox(height: 1.5),
              pw.Text(
                "${nightsLabel(totals.nights)} · ${totals.entries == 1 ? '1 custody entry' : '${totals.entries} custody entries'}",
                style: _style(size: 7.5, color: ReportPalette.faint),
              ),
            ],
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cardTitle(ReportIcons.users, "Children"),
          if (children.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text("—", style: _style(color: ReportPalette.muted)),
            )
          else
            ...children.map(entry),
        ],
      ),
    );
  }

  pw.Widget _financialCard(List<CalendarEvent> payments) {
    double received = 0, paid = 0, compulsory = 0, additional = 0;
    for (final p in payments) {
      final amount = p.amount ?? 0;
      if (_isReceived(p)) {
        received += amount;
      } else {
        paid += amount;
      }
      if (p.paymentCategory == 'Compulsory') {
        compulsory += amount;
      } else {
        additional += amount;
      }
    }

    pw.Widget line(String label, double value, {bool total = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: _style(
                size: total ? 9 : 8.5,
                color: total ? ReportPalette.ink : ReportPalette.body,
                font: total ? fonts.semiBold : fonts.regular,
              ),
            ),
          ),
          pw.Text(
            _money(value),
            style: _style(size: total ? 10.5 : 9, color: ReportPalette.ink, font: fonts.semiBold),
          ),
        ],
      ),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cardTitle(ReportIcons.dollar, "Financial record"),
          pw.SizedBox(height: 10),
          line("Payments received", received),
          line("Payments paid", paid),
          line("Compulsory payments", compulsory),
          line("Additional payments", additional),
          _rule(vertical: 6),
          // Matches the in-app Insights total (paid + received).
          line("Total payment value", paid + received, total: true),
        ],
      ),
    );
  }

  /// Date of birth, school and address for every child in the report — one
  /// small card each, so any number of children flows across pages.
  List<pw.Widget> _childDetails() {
    if (children.isEmpty) return const [];

    pw.Widget field(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _label(label, size: 6.5, color: ReportPalette.faint),
        pw.SizedBox(height: 3),
        pw.Text(value, style: _style(size: 8.5, color: ReportPalette.body)),
      ],
    );

    return _keepFirstWithNext([
      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8), child: _label("Child details")),
      for (final child in children)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: _cardDecoration,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(
                  _clip(child.name, 60),
                  style: _style(size: 10, color: ReportPalette.ink, font: fonts.semiBold),
                ),
              ),
              pw.SizedBox(width: 96, child: field("Date of birth", _numDate.format(child.dob))),
              pw.SizedBox(width: 10),
              pw.Expanded(flex: 2, child: field("School", _clip(_orDash(child.school), 200))),
              pw.SizedBox(width: 10),
              pw.Expanded(flex: 3, child: field("Address", _clip(_orDash(child.address), 300))),
            ],
          ),
        ),
    ]);
  }

  // ===========================================================================
  // 2. Detailed Records
  // ===========================================================================

  pw.Widget _tableCell(String text, {pw.Font? font, PdfColor color = ReportPalette.body, double size = 8}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: pw.Text(
          text,
          style: _style(size: size, color: color, font: font, lineSpacing: 1.5),
        ),
      );

  pw.TableRow _tableHeader(List<String> titles) => pw.TableRow(
    repeat: true,
    decoration: const pw.BoxDecoration(color: ReportPalette.card),
    children: titles.map((t) => _tableCell(t, font: fonts.semiBold, color: ReportPalette.ink, size: 7.5)).toList(),
  );

  static const _tableBorder = pw.TableBorder(
    horizontalInside: pw.BorderSide(color: ReportPalette.rule, width: 0.6),
    bottom: pw.BorderSide(color: ReportPalette.rule, width: 0.6),
  );

  List<pw.Widget> _detailedRecords() {
    final heading = _sectionHeading(2, "Detailed Records", "A chronological record of events entered into ClearCase.");
    if (events.isEmpty) return [_together([heading, _emptyState("No records match the selected filters.")])];

    return _headedTable(
      heading,
      const {
        0: pw.FixedColumnWidth(78),
        1: pw.FixedColumnWidth(88),
        2: pw.FixedColumnWidth(90),
        3: pw.FlexColumnWidth(),
      },
      ["Date", "Type", "Child/Children", "Summary"],
      [
          for (final e in events)
            pw.TableRow(
              children: [
                _tableCell(
                  e.type == EventType.custody && e.span.isMultiDay
                      ? "${_numDate.format(e.span.start)} –\n${_numDate.format(e.span.end)}"
                      : _numDate.format(e.date),
                ),
                _tableCell(_typeName(e.type)),
                _tableCell(_clip(_childLabel(e), 60)),
                _tableCell(_summary(e)),
              ],
            ),
      ],
    );
  }

  // ===========================================================================
  // 3. Event Details
  // ===========================================================================

  // Values longer than this are split into page-breakable chunks.
  static const int _chunkSize = 900;
  // A card whose text fits within this budget is laid out as one unbreakable
  // block (moved whole to the next page rather than split).
  static const int _compactBudget = 1500;

  List<(String, String)> _detailRows(CalendarEvent e) {
    final attachmentCount = _attachmentsOf(e).length;
    switch (e.type) {
      case EventType.custody:
        return [
          (_childFieldLabel(e), _childLabel(e)),
          ("Period", _custodyPeriod(e)),
          ("Location", _orDash(e.location)),
          ("Nights", "${e.span.nights}"),
          ("Notes", _orDash(e.description)),
          ("Attachments", "$attachmentCount"),
        ];
      case EventType.payment:
        return [
          (_childFieldLabel(e), _childLabel(e)),
          ("Type", _orDash(e.title)),
          ("Category", e.paymentCategory ?? 'General'),
          ("Transaction", _isReceived(e) ? 'Payment Received' : 'Payment Paid'),
          ("Status", e.isReceived ? 'Received Successfully' : 'Paid Successfully'),
          ("Method", _orDash(e.paymentMethod)),
          ("Amount", _money(e.amount ?? 0)),
          ("Notes", _orDash(e.description)),
          ("Attachments", "$attachmentCount"),
        ];
      case EventType.dispute:
        final issue = e.title.trim();
        return [
          (_childFieldLabel(e), _childLabel(e)),
          ("Category", e.category ?? 'Unspecified'),
          if (issue.isNotEmpty && issue != 'Dispute' && issue != e.category) ("Issue", issue),
          ("Involved Party", _orDash(e.party)),
          ("Description", _orDash(e.description)),
          ("Attachments", "$attachmentCount"),
        ];
      case EventType.nonCompliance:
        return [
          (_childFieldLabel(e), _childLabel(e)),
          ("Type", _orDash(e.title)),
          ("Severity", _orDash(e.severity)),
          ("Party Responsible", _orDash(e.party)),
          ("Evidence", _orDash(e.proof)),
          ("Description", _orDash(e.description)),
          ("Attachments", "$attachmentCount"),
        ];
      case EventType.reminder:
        return [("Title", e.title)];
    }
  }

  List<pw.Widget> _eventDetails() {
    final heading = _sectionHeading(
      3,
      "Event Details",
      "Each event includes the information recorded by the user at the time.",
    );
    if (events.isEmpty) return [_together([heading, _emptyState("No records match the selected filters.")])];

    final widgets = <pw.Widget>[];
    for (var i = 0; i < events.length; i++) {
      final pieces = _eventCard(events[i]);
      // Keep the section heading with the first card (or its first slice).
      if (i == 0) {
        widgets.addAll(_keepFirstWithNext([heading, ...pieces]));
      } else {
        widgets.addAll(pieces);
      }
      widgets.add(pw.SizedBox(height: 12));
    }
    return widgets;
  }

  pw.Widget _eventTitle(CalendarEvent e) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 48,
          child: pw.Text(
            _refOf(e),
            style: _style(size: 9.5, color: ReportPalette.ink, font: fonts.semiBold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            "${_dateLabel(e)}  –  ${_typeName(e.type).toUpperCase()}",
            style: _style(size: 8.5, color: ReportPalette.ink, font: fonts.semiBold, letterSpacing: 0.4),
          ),
        ),
        if (e.isFlagged && _enabled("Flagged Events")) ...[
          _pill("FLAGGED", const PdfColor.fromInt(0xFFFBE9E9), const PdfColor.fromInt(0xFFB42318)),
          pw.SizedBox(width: 5),
        ],
        _typePill(e.type),
      ],
    ),
  );

  pw.Widget _detailRow(String label, String value, {bool showLabel = true}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 118,
          child: showLabel ? pw.Text(label, style: _style(size: 8, color: ReportPalette.muted)) : pw.SizedBox(),
        ),
        pw.Expanded(
          child: pw.Text(value, style: _style(size: 8.5, color: ReportPalette.body, lineSpacing: 1.5)),
        ),
      ],
    ),
  );

  /// One event card. Usually a single unbreakable block; when a free-text
  /// value is very long the card is emitted as a run of seamless grey slices
  /// (title + short rows, text chunks, evidence) that MultiPage can break
  /// between, so no slice can outgrow a page.
  List<pw.Widget> _eventCard(CalendarEvent e) {
    final rows = _detailRows(e);
    final files = _attachmentsOf(e);
    final evidence = files.isEmpty ? null : _evidenceBlock(e, files);

    final totalCost = rows.fold<int>(0, (acc, r) => acc + _cost(r.$2));
    final longest = rows.fold<int>(0, (m, r) => _cost(r.$2) > m ? _cost(r.$2) : m);

    if (totalCost <= _compactBudget && longest <= _chunkSize) {
      return [
        _together([pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: _cardDecoration,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [_eventTitle(e), ...rows.map((r) => _detailRow(r.$1, r.$2)), ?evidence],
          ),
        )]),
      ];
    }

    // Sliced card: rows (and chunks of long values) are packed into slices of
    // at most ~_chunkSize text cost each.
    final slices = <List<pw.Widget>>[
      [_eventTitle(e)],
    ];
    var sliceCost = 0;
    for (final (label, value) in rows) {
      final chunks = _chunks(value, _chunkSize);
      for (var c = 0; c < chunks.length; c++) {
        final cost = _cost(chunks[c]);
        if (sliceCost + cost > _chunkSize && slices.last.isNotEmpty) {
          slices.add([]);
          sliceCost = 0;
        }
        slices.last.add(_detailRow(label, chunks[c], showLabel: c == 0));
        sliceCost += cost;
      }
    }
    if (evidence != null) slices.last.add(evidence);

    const r = pw.Radius.circular(6);
    return [
      for (var i = 0; i < slices.length; i++)
        _together([pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.fromLTRB(16, i == 0 ? 12 : 0, 16, i == slices.length - 1 ? 12 : 0),
          decoration: pw.BoxDecoration(
            color: ReportPalette.card,
            borderRadius: pw.BorderRadius.only(
              topLeft: i == 0 ? r : pw.Radius.zero,
              topRight: i == 0 ? r : pw.Radius.zero,
              bottomLeft: i == slices.length - 1 ? r : pw.Radius.zero,
              bottomRight: i == slices.length - 1 ? r : pw.Radius.zero,
            ),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: slices[i]),
        )]),
    ];
  }

  // Rough vertical "cost" of a value in characters: a line break costs about
  // a full line of text, so many short lines can't sneak past the budgets.
  static const int _lineCost = 80;

  static int _cost(String text) => text.length + _lineCost * '\n'.allMatches(text).length;

  /// Splits [text] into pieces of at most ~[size] cost, breaking between
  /// lines where possible and otherwise at word boundaries.
  static List<String> _chunks(String text, int size) {
    final out = <String>[];
    final buffer = <String>[];
    var cost = 0;
    void flush() {
      if (buffer.isEmpty) return;
      out.add(buffer.join('\n'));
      buffer.clear();
      cost = 0;
    }

    for (var line in text.trim().split('\n')) {
      while (line.length > size) {
        flush();
        var cut = line.lastIndexOf(' ', size);
        if (cut < size ~/ 2) cut = size;
        out.add(line.substring(0, cut).trimRight());
        line = line.substring(cut).trimLeft();
      }
      final lineCost = line.length + _lineCost;
      if (cost + lineCost > size) flush();
      buffer.add(line);
      cost += lineCost;
    }
    flush();
    return out.isEmpty ? [''] : out;
  }

  /// Thumbnails + "Evidence: N images", provenance notes and document links.
  pw.Widget _evidenceBlock(CalendarEvent e, List<_Attachment> files) {
    final images = files.where((a) => a.isImage).toList();
    final docs = files.where((a) => !a.isImage).toList();
    final thumbs = images.where((a) => a.image != null).take(3).toList();
    final hasLibrary = images.any((a) => a.source == EvidenceSource.library);
    final hasCamera = images.any((a) => a.source == EvidenceSource.camera);

    final summary = [
      if (images.isNotEmpty) images.length == 1 ? "1 image" : "${images.length} images",
      if (docs.isNotEmpty) docs.length == 1 ? "1 document" : "${docs.length} documents",
    ].join(", ");

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              for (final a in thumbs) ...[
                pw.UrlLink(
                  destination: a.url,
                  child: pw.Container(
                    width: 52,
                    height: 52,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(4),
                      image: pw.DecorationImage(image: a.image!, fit: pw.BoxFit.cover),
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
              ],
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Evidence: $summary",
                      style: _style(size: 8.5, color: ReportPalette.body, font: fonts.medium),
                    ),
                    if (images.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Full-size images: section 6, ref ${_refOf(e)}.",
                        style: _style(size: 7, color: ReportPalette.faint),
                      ),
                    ],
                    if (hasCamera) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(cameraPhotoNotice, style: _style(size: 7, color: ReportPalette.cameraNote)),
                    ],
                    if (hasLibrary) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(libraryPhotoNotice, style: _style(size: 7, color: ReportPalette.libraryNote)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          for (final d in docs.take(5))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.UrlLink(
                destination: d.url,
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: "${fileTypeFromExtension(extensionFromUrl(d.url)).label}  ",
                        style: _style(size: 7, color: ReportPalette.accent, font: fonts.semiBold),
                      ),
                      pw.TextSpan(
                        text: _clip(d.fileName, 80),
                        style: _style(
                          size: 7.5,
                          color: PdfColors.blue700,
                        ).copyWith(decoration: pw.TextDecoration.underline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (docs.length > 5)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                "and ${docs.length - 5} more — see section 6.",
                style: _style(size: 7, color: ReportPalette.faint),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. Evidence Index
  // ===========================================================================

  String _indexDescription(CalendarEvent e) {
    switch (e.type) {
      case EventType.custody:
        return _childLabel(e);
      case EventType.payment:
        return e.title == 'Payment' ? (e.paymentCategory ?? 'Payment') : e.title;
      case EventType.dispute:
        return e.category ?? e.title;
      case EventType.nonCompliance:
        return e.title;
      case EventType.reminder:
        return e.title;
    }
  }

  String _sourceBreakdown(List<_Attachment> files) {
    final camera = files.where((a) => a.isImage && a.source == EvidenceSource.camera).length;
    final library = files.where((a) => a.isImage && a.source == EvidenceSource.library).length;
    final otherImages = files.where((a) => a.isImage && a.source == EvidenceSource.unknown).length;
    final docs = files.where((a) => !a.isImage).length;
    return [
      if (camera > 0) "$camera in-app photo${camera == 1 ? '' : 's'}",
      if (library > 0) "$library library photo${library == 1 ? '' : 's'}",
      if (otherImages > 0) "$otherImages image${otherImages == 1 ? '' : 's'}",
      if (docs > 0) "$docs document${docs == 1 ? '' : 's'}",
    ].join(" · ");
  }

  List<pw.Widget> _evidenceIndex() {
    final heading = _sectionHeading(4, "Evidence Index", "A list of all attachments included in this report.");
    final withFiles = events.where((e) => _attachmentsOf(e).isNotEmpty).toList();
    if (withFiles.isEmpty) return [_together([heading, _emptyState("No attachments are included in this report.")])];

    return _headedTable(
      heading,
      const {
        0: pw.FixedColumnWidth(48),
        1: pw.FixedColumnWidth(80),
        2: pw.FixedColumnWidth(92),
        3: pw.FlexColumnWidth(),
        4: pw.FixedColumnWidth(76),
      },
      ["Ref", "Date", "Event Type", "Description", "Attachments"],
      [
          for (final e in withFiles)
            pw.TableRow(
              children: [
                _tableCell(_refOf(e), font: fonts.semiBold, color: ReportPalette.ink),
                _tableCell(_shortDate.format(e.date)),
                _tableCell(_typeName(e.type)),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_clip(_indexDescription(e), 80), style: _style(size: 8)),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        _sourceBreakdown(_attachmentsOf(e)),
                        style: _style(size: 6.5, color: ReportPalette.faint),
                      ),
                    ],
                  ),
                ),
                _tableCell("${_attachmentsOf(e).length}"),
              ],
            ),
      ],
    );
  }

  // ===========================================================================
  // 5. Recording Notes
  // ===========================================================================

  List<pw.Widget> _recordingNotes() {
    final paragraph = pw.Text(
      "This document presents a chronological record of information entered into ClearCase by "
      "the user. ClearCase does not independently verify the accuracy of those records, determine "
      "whether an event constitutes non-compliance or a contravention, or express a legal opinion.",
      style: _style(size: 8.5, color: ReportPalette.body, lineSpacing: 3),
    );

    final provenance = pw.Text(
      "Photo evidence is labelled by source. Photos taken in the app are stamped with the capture "
      "time and location. Photos uploaded from the device library are marked as such: their "
      "location/geotag and original timestamp cannot be verified in the same way.",
      style: _style(size: 8.5, color: ReportPalette.body, lineSpacing: 3),
    );

    final callout = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ReportIcons.icon(ReportIcons.info, size: 15, color: ReportPalette.body),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Important Information",
                  style: _style(size: 9, color: ReportPalette.ink, font: fonts.semiBold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "This report is for the purpose of providing an organised record of events and evidence. "
                  "It is not a substitute for legal advice and should not be relied upon as a legal determination.",
                  style: _style(size: 8.5, color: ReportPalette.body, lineSpacing: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Short enough to always keep whole, heading included.
    return [
      _together([
        _sectionHeading(5, "Recording Notes"),
        paragraph,
        pw.SizedBox(height: 8),
        provenance,
        pw.SizedBox(height: 14),
        callout,
      ]),
    ];
  }

  // ===========================================================================
  // 6. Evidence Attachments
  // ===========================================================================

  String _sourceLabel(EvidenceSource source) {
    switch (source) {
      case EvidenceSource.camera:
        return "Taken in app";
      case EvidenceSource.library:
        return "From photo library";
      case EvidenceSource.unknown:
        return "";
    }
  }

  List<pw.Widget> _evidenceAttachments() {
    final heading = _sectionHeading(
      6,
      "Evidence Attachments",
      "All attached images are listed below in the order they appear in the report.",
    );

    final images = <(CalendarEvent, _Attachment)>[];
    final docs = <(CalendarEvent, _Attachment)>[];
    for (final e in events) {
      for (final a in _attachmentsOf(e)) {
        (a.isImage ? images : docs).add((e, a));
      }
    }

    final widgets = <pw.Widget>[heading];
    if (images.isEmpty && docs.isEmpty) {
      widgets.add(_emptyState("No attachments are included in this report."));
      return _keepFirstWithNext(widgets);
    }
    if (images.isEmpty) {
      widgets.add(_emptyState("No image attachments are included in this report."));
    }

    // One Row per three images, so the grid breaks cleanly between rows.
    for (var i = 0; i < images.length; i += 3) {
      final row = images.sublist(i, i + 3 > images.length ? images.length : i + 3);
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) pw.SizedBox(width: 12),
                pw.Expanded(child: c < row.length ? _gridCell(row[c].$1, row[c].$2) : pw.SizedBox()),
              ],
            ],
          ),
        ),
      );
    }

    if (docs.isNotEmpty) {
      widgets.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 6, bottom: 8), child: _label("Documents")));
      for (final (e, a) in docs) {
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: ReportPalette.rule, width: 0.6)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 50,
                  child: pw.Text(
                    _refOf(e),
                    style: _style(size: 8, color: ReportPalette.ink, font: fonts.semiBold),
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "${_clip(a.fileName, 90)}  ·  ${_typeName(e.type)} (${_shortDate.format(e.date)})",
                        style: _style(size: 8, color: ReportPalette.body),
                      ),
                      pw.SizedBox(height: 2),
                      // Printed in full so it can be copied into a browser even
                      // where the PDF viewer doesn't open links.
                      pw.UrlLink(
                        destination: a.url,
                        child: pw.Text(
                          _clip(a.url, 600),
                          style: _style(
                            size: 6.5,
                            color: PdfColors.blue700,
                          ).copyWith(decoration: pw.TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return _keepFirstWithNext(widgets);
  }

  pw.Widget _gridCell(CalendarEvent e, _Attachment a) {
    final source = _sourceLabel(a.source);
    final pw.Widget picture = a.image != null
        ? pw.Container(
            height: 112,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(4),
              image: pw.DecorationImage(image: a.image!, fit: pw.BoxFit.cover),
            ),
          )
        : pw.Container(
            height: 112,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: ReportPalette.card, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(
              "Image not embedded —\ntap to open",
              textAlign: pw.TextAlign.center,
              style: _style(size: 7.5, color: ReportPalette.muted),
            ),
          );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.UrlLink(destination: a.url, child: picture),
        pw.SizedBox(height: 5),
        pw.Text(
          _refOf(e),
          style: _style(size: 8, color: ReportPalette.ink, font: fonts.semiBold),
        ),
        pw.Text(_typeName(e.type), style: _style(size: 7.5, color: ReportPalette.body)),
        pw.Text("(${_shortDate.format(e.date)})", style: _style(size: 7.5, color: ReportPalette.muted)),
        if (source.isNotEmpty)
          pw.Text(
            source,
            style: _style(
              size: 6.5,
              color: a.source == EvidenceSource.library ? ReportPalette.libraryNote : ReportPalette.cameraNote,
            ),
          ),
      ],
    );
  }
}
