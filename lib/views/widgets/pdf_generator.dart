import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/calender_event_model.dart';
import '../../models/case_model.dart';
import 'export_filter.dart';
import 'file_type_icon.dart';

class PDFGenerator {
  static final PdfColor primaryColor = PdfColor.fromInt(0xFF4A148C);

  static Future<void> generateReport({
    required String caseName,
    required String caseId,
    required ExportOptions options,
    required List<CalendarEvent> allEvents,
    CaseModel? caseModel,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.jostRegular();
    final fontBold = await PdfGoogleFonts.jostBold();

    // Parent / guardian = the logged-in account holder.
    final parent = await _fetchParentDetails();

    bool matchesDate(CalendarEvent event) {
      final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
      if (options.startDate != null && eventDay.isBefore(options.startDate!)) return false;
      if (options.endDate != null && eventDay.isAfter(options.endDate!)) return false;
      return true;
    }

    // A record matches the child filter when it belongs to one of the selected
    // children. Case-level records (disputes / non-compliance) carry no child
    // ids, so they're always included.
    bool matchesChild(CalendarEvent event) {
      if (options.childIds.isEmpty) return true;
      if (event.childIds.isEmpty) return true;
      return event.childIds.any((id) => options.childIds.contains(id));
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

    // Stats cover everything in range for the selected children (all sections),
    // so each summary block reflects the full picture the way the in-app
    // Insights screen does. The table below is additionally narrowed by the
    // "Include in Report" section toggles.
    final statsEvents = allEvents
        .where((e) => !e.id.startsWith('rule_') && matchesDate(e) && matchesChild(e))
        .toList();

    final tableEvents = statsEvents.where(sectionEnabled).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final stats = _ReportStats.fromEvents(statsEvents);

    // Custody compliance mirrors the in-app Insights screen exactly, so it is
    // computed from the scheduled-rule calendar + custody records (the same
    // inputs InsightProvider uses) rather than from the report's event list.
    final custody = options.reportSections["Custody"] == true
        ? await _calcCustodyCompliance(caseId)
        : null;

    // Pre-fetch image attachments before building pages — MultiPage.build is
    // synchronous, so image bytes must be resolved up front. Attachments are
    // rendered inline beneath each record (keyed by record id).
    final attachments = await _collectAttachments(tableEvents);

    final summaryWidgets = _buildSummary(stats, custody, options, fontBold);

    // Page 1: cover sheet with all the key case information.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => _buildCoverPage(
          caseName: caseName,
          caseModel: caseModel,
          options: options,
          parentName: parent['name']!,
          parentEmail: parent['email']!,
          font: font,
          bold: fontBold,
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          _buildHeader(caseName, options, fontBold),
          pw.SizedBox(height: 15),
          ...summaryWidgets,
          // Page 1 holds the Insights summary; the detailed records start on
          // the next page.
          if (summaryWidgets.isNotEmpty) pw.NewPage(),
          pw.Text("DETAILED RECORDS", style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryColor)),
          pw.SizedBox(height: 8),
          _buildTable(tableEvents, fontBold, attachments),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'ClearCase_Court_Report',
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.Widget _buildHeader(String caseName, ExportOptions options, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("CASE RECORDS - CLEARCASE", style: pw.TextStyle(fontSize: 22, font: bold, color: primaryColor)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Case No: $caseName", style: pw.TextStyle(font: bold, fontSize: 12)),
            pw.Text("Generated: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Divider(thickness: 1.5, color: primaryColor),
      ],
    );
  }

  // --- Cover sheet (Page 1) ---
  //
  // Holds all the key case information up front: child name(s) & DOB, case
  // number, legal representative, parent/guardian, the period the report
  // covers, and the date it was generated.
  static pw.Widget _buildCoverPage({
    required String caseName,
    required CaseModel? caseModel,
    required ExportOptions options,
    required String parentName,
    required String parentEmail,
    required pw.Font font,
    required pw.Font bold,
  }) {
    // Only the children actually included in this report (per the export filter).
    final children = (caseModel?.children ?? [])
        .where((c) => options.childIds.isEmpty || options.childIds.contains(c.id))
        .toList();

    final String childNames =
        children.isEmpty ? "—" : children.map((c) => c.name).join(", ");
    final String dobs = children.isEmpty
        ? "—"
        : children.map((c) => DateFormat('dd/MM/yyyy').format(c.dob)).join("\n");

    final String legalRep =
        (caseModel?.legalRep ?? "").trim().isEmpty ? "—" : caseModel!.legalRep.trim();

    final String guardian = parentEmail == "—"
        ? parentName
        : "$parentName\n$parentEmail";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 40),
        pw.Text("EVIDENCE REPORT",
            style: pw.TextStyle(font: bold, fontSize: 30, color: primaryColor)),
        pw.SizedBox(height: 6),
        pw.Text("ClearCase — Custody & Compliance Record",
            style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
        pw.SizedBox(height: 20),
        pw.Divider(thickness: 2, color: primaryColor),
        pw.SizedBox(height: 30),

        // Key case information block.
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF7F2FB),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: primaryColor, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("CASE INFORMATION",
                  style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 14),
              _coverInfoRow(children.length > 1 ? "Child Names" : "Child Name", childNames, bold),
              _coverInfoRow("Case Number", caseName, bold),
              _coverInfoRow("Date of Birth", dobs, bold),
              _coverInfoRow("Legal Representative", legalRep, bold),
              _coverInfoRow("Parent / Guardian", guardian, bold),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Report metadata block.
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF7F2FB),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: primaryColor, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("REPORT DETAILS",
                  style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 14),
              _coverInfoRow("Report Period Covered", _reportPeriod(options), bold),
              _coverInfoRow("Report Generated On",
                  DateFormat('dd/MM/yyyy  hh:mm a').format(DateTime.now()), bold),
            ],
          ),
        ),

        pw.Spacer(),
        pw.Center(
          child: pw.Text(
            "Generated by ClearCase. This document is intended for legal and court reference.",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  static pw.Widget _coverInfoRow(String label, String value, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 170,
            child: pw.Text(label,
                style: pw.TextStyle(font: bold, fontSize: 11, color: primaryColor)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // Human-readable description of the time span the report covers.
  static String _reportPeriod(ExportOptions options) {
    final start = options.startDate;
    final end = options.endDate;
    final fmt = DateFormat('dd/MM/yyyy');
    if (start != null && end != null) return "${fmt.format(start)} - ${fmt.format(end)}";
    if (start != null) return "From ${fmt.format(start)}";
    if (end != null) return "Up to ${fmt.format(end)}";
    return options.timePeriod ?? "All Time";
  }

  // Parent / guardian = the signed-in account holder. Prefers the Auth
  // display name; falls back to the Firestore user document's first/last name.
  static Future<Map<String, String>> _fetchParentDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    String name = (user?.displayName ?? '').trim();
    String email = (user?.email ?? '').trim();

    if (name.isEmpty && user != null) {
      try {
        final firestore =
            FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
        final doc = await firestore.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          final fn = (data['firstName'] ?? '').toString().trim();
          final ln = (data['lastName'] ?? '').toString().trim();
          name = "$fn $ln".trim();
          if (email.isEmpty) email = (data['email'] ?? '').toString().trim();
        }
      } catch (_) {
        // Falls back to whatever Auth provided (possibly empty).
      }
    }

    return {
      'name': name.isEmpty ? '—' : name,
      'email': email.isEmpty ? '—' : email,
    };
  }

  // --- Insights summary (mirrors the in-app Insights screen) ---
  static List<pw.Widget> _buildSummary(
    _ReportStats s,
    _CustodyCompliance? custody,
    ExportOptions options,
    pw.Font bold,
  ) {
    final blocks = <pw.Widget>[];

    void add(pw.Widget block) {
      blocks.add(block);
      blocks.add(pw.SizedBox(height: 10));
    }

    if (options.reportSections["Custody"] == true && custody != null) {
      add(_summaryCard(
        "Custody Compliance",
        bold,
        stats: [
          _Stat("${custody.fulfilled}", "Custody Days (fulfilled)"),
          _Stat("${custody.justified}", "With Justification"),
          _Stat("${custody.missed}", "Missed Days (No Just.)"),
        ],
        totalLabel: "Overall Compliance",
        totalValue: "${custody.rate.toStringAsFixed(1)}%",
      ));
    }

    if (options.reportSections["Payments"] == true) {
      add(_summaryCard(
        "Payment Tracking",
        bold,
        stats: [
          _Stat("\$${s.paid.toStringAsFixed(2)}", "Payments Paid"),
          _Stat("\$${s.received.toStringAsFixed(2)}", "Payments Received"),
          _Stat("\$${s.compulsory.toStringAsFixed(2)}", "Compulsory"),
          _Stat("\$${s.additional.toStringAsFixed(2)}", "Additional"),
        ],
        totalLabel: "Total Payment",
        totalValue: "\$${s.totalPayments.toStringAsFixed(2)}",
      ));
    }

    if (options.reportSections["Disputes"] == true) {
      add(_summaryCard(
        "Disputes Log",
        bold,
        stats: [
          _Stat("${s.disputeCommunication}", "Communication"),
          _Stat("${s.disputeTransfer}", "Transfer Issues"),
          _Stat("${s.disputePayment}", "Payment Disputes"),
        ],
        totalLabel: "Total Disputes",
        totalValue: "${s.disputeTotal}",
      ));
    }

    if (options.reportSections["Non-Compliance"] == true) {
      add(_summaryCard(
        "Non Compliance",
        bold,
        stats: [
          _Stat("${s.nonComplianceTotal}", "Total Issues"),
        ],
      ));
    }

    if (options.reportSections["Flagged Events"] == true) {
      add(_summaryCard(
        "Flagged Events",
        bold,
        stats: [
          _Stat("${s.flaggedCustody}", "Custody"),
          _Stat("${s.flaggedPayments}", "Payments"),
          _Stat("${s.flaggedDisputes}", "Disputes"),
          _Stat("${s.flaggedNonCompliance}", "Non Compliance"),
        ],
        totalLabel: "Total Flagged",
        totalValue: "${s.flaggedTotal}",
      ));
    }

    if (blocks.isNotEmpty) {
      blocks.insert(0, pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text("INSIGHTS SUMMARY", style: pw.TextStyle(font: bold, fontSize: 14, color: primaryColor)),
      ));
    }
    return blocks;
  }

  static pw.Widget _summaryCard(
    String title,
    pw.Font bold, {
    required List<_Stat> stats,
    String? totalLabel,
    String? totalValue,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF7F2FB),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: primaryColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 12, color: primaryColor)),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 16,
            runSpacing: 8,
            children: stats.map((st) => pw.SizedBox(
              width: 110,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(st.value, style: pw.TextStyle(font: bold, fontSize: 14)),
                  pw.SizedBox(height: 2),
                  pw.Text(st.label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            )).toList(),
          ),
          if (totalLabel != null && totalValue != null) ...[
            pw.Divider(height: 18, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(totalLabel, style: pw.TextStyle(font: bold, fontSize: 11)),
                pw.Text(totalValue, style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildTable(
    List<CalendarEvent> events,
    pw.Font bold,
    Map<String, List<_Attachment>> attachments,
  ) {
    if (events.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        alignment: pw.Alignment.center,
        child: pw.Text("No records match the selected filters.",
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(85), // தேதிக்காக போதுமான இடம்
        1: const pw.FixedColumnWidth(95),
        2: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            _cell("Date", bold, textColor: PdfColors.white),
            _cell("Record Type", bold, textColor: PdfColors.white),
            _cell("Detailed & Information", bold, textColor: PdfColors.white),
          ],
        ),
        ...events.map((e) => pw.TableRow(
          children: [
            // Date cell - Alignment சேர்க்கப்பட்டுள்ளது
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.centerLeft, // செங்குத்தாக நடுவில் வர உதவும்
              child: pw.Text(
                DateFormat('dd/MM/yyyy').format(e.date),
                style: const pw.TextStyle(fontSize: 10),
                softWrap: false,
              ),
            ),
            // Type cell
            _cell(e.type == EventType.nonCompliance ? "NON-COMPLIANCE" : e.type.name.toUpperCase(), bold),
            // Details cell
            _buildDetailedRow(e, bold, attachments[e.id] ?? const []),
          ],
        )),
      ],
    );
  }

   static pw.Widget _cell(String text, pw.Font? font, {PdfColor textColor = PdfColors.black}) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: textColor,
          )
      ),
    );
  }
  static pw.Widget _buildDetailedRow(CalendarEvent e, pw.Font bold, List<_Attachment> attachments) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (e.type == EventType.payment) ...[
            pw.Text("Type: ${e.title}", style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.Text("Category: ${e.paymentCategory ?? 'General'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Transaction: ${e.status == 'PaymentReceived' ? 'Payment Received' : 'Payment Paid'}",
                style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(
              "Status: ${e.isReceived ? 'Received Successfully' : 'Paid Successfully'}",
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
            pw.Text("Method: ${e.paymentMethod ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Amount: \$${e.amount?.toStringAsFixed(2) ?? '0.00'}",
                style: pw.TextStyle(font: bold, fontSize: 11)),
            if (e.description != null)
              pw.Text("Notes: ${e.description}", style: const pw.TextStyle(fontSize: 10)),
          ],

          if (e.type == EventType.dispute) ...[
            pw.Text("Issue: ${e.title}", style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.Text("Category: ${e.category ?? 'Unspecified'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Involved Party: ${e.party ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Description: ${e.description ?? ''}", style: const pw.TextStyle(fontSize: 10)),
          ],

          if (e.type == EventType.nonCompliance) ...[
            pw.Text("Non-Compliance Type: ${e.title}", style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.red900)),
            pw.Text("Severity: ${e.severity ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Party Responsible: ${e.party ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Proof: ${e.proof ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Description: ${e.description ?? ''}", style: const pw.TextStyle(fontSize: 10)),
          ],

          if (e.type == EventType.custody) ...[
            pw.Text("Custody Event: ${e.title}", style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.Text("Schedule: ${e.isScheduled ? "Scheduled" : "Manual"}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Fulfillment: ${e.isFulfilled ? "Completed" : "Not Completed"}", style: pw.TextStyle(fontSize: 10, font: bold)),
            if (e.location != null) pw.Text("Location: ${e.location}", style: const pw.TextStyle(fontSize: 10)),
            if (e.description != null) pw.Text("Notes: ${e.description}", style: const pw.TextStyle(fontSize: 10)),
          ],

          // Attachments rendered inline: image thumbnails for photos, a file
          // label for documents, plus the full URL printed as clickable,
          // copyable text so the file can be opened/downloaded in a browser
          // even if the PDF reader doesn't hand links off externally.
          if (attachments.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text("Attachments:", style: pw.TextStyle(font: bold, fontSize: 9, color: primaryColor)),
            pw.SizedBox(height: 4),
            ...attachments.map((a) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: _attachmentEntry(a, bold),
            )),
          ],
        ],
      ),
    );
  }

  static pw.Widget _attachmentEntry(_Attachment a, pw.Font bold) {
    final info = fileTypeFromExtension(extensionFromUrl(a.url));
    final String tag = a.isImage ? "IMAGE" : info.label;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Photos render as a thumbnail; tapping it opens the full image.
        if (a.isImage && a.image != null) ...[
          pw.UrlLink(
            destination: a.url,
            child: pw.Container(
              width: 90,
              height: 90,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                image: pw.DecorationImage(image: a.image!, fit: pw.BoxFit.cover),
              ),
            ),
          ),
          pw.SizedBox(height: 3),
        ],
        // The full URL as wrapping, clickable text — works in any viewer and
        // can be copied into Chrome if the in-app click opens a blank page.
        pw.UrlLink(
          destination: a.url,
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: "[$tag] ",
                  style: pw.TextStyle(font: bold, fontSize: 8, color: primaryColor),
                ),
                pw.TextSpan(
                  text: a.url,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blue700,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Inline attachments ---

  // Resolves every record's attachments up front. Image bytes are downloaded
  // so photos can render as thumbnails; documents are kept as link targets.
  static Future<Map<String, List<_Attachment>>> _collectAttachments(List<CalendarEvent> events) async {
    final map = <String, List<_Attachment>>{};
    for (final e in events) {
      if (e.attachmentUrls.isEmpty) continue;
      final list = <_Attachment>[];
      for (final url in e.attachmentUrls) {
        final ext = extensionFromUrl(url);
        final fileName = _fileNameFromUrl(url);
        if (isImageExtension(ext)) {
          pw.ImageProvider? image;
          try {
            image = await networkImage(url);
          } catch (_) {
            image = null; // Falls back to a link chip below.
          }
          list.add(_Attachment(url: url, fileName: fileName, isImage: true, image: image));
        } else {
          list.add(_Attachment(url: url, fileName: fileName, isImage: false));
        }
      }
      map[e.id] = list;
    }
    return map;
  }

  // --- Custody compliance (identical to InsightProvider.calculateCustodyCompliance) ---
  //
  // Builds the set of scheduled custody days from every scheduled rule
  // (start -> end, or start -> today when the rule has no end date), then walks
  // the scheduled custody records: a record on a scheduled day counts as
  // "fulfilled" when isFulfilled is true and "justified" otherwise. Days with
  // no matching record are "missed". Compliance % = (fulfilled + justified) /
  // total scheduled days. Kept byte-for-byte with the Insights screen so the
  // report and the app always show the same numbers.
  static Future<_CustodyCompliance> _calcCustodyCompliance(String caseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || caseId.isEmpty) return const _CustodyCompliance(0, 0, 0, 0);

    final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final caseRef = firestore.collection('users').doc(user.uid).collection('cases').doc(caseId);

      final rulesSnap = await caseRef.collection('scheduledRules').get();
      if (rulesSnap.docs.isEmpty) return const _CustodyCompliance(0, 0, 0, 0);

      final Set<String> scheduledDates = {};
      for (final doc in rulesSnap.docs) {
        final data = doc.data();
        if (data['startDate'] == null) continue;
        final start = DateTime.parse(data['startDate']);
        final end = data['endDate'] != null ? DateTime.parse(data['endDate']) : null;
        final calcEnd = (end != null && end.isBefore(today)) ? end : today;

        for (var date = DateTime(start.year, start.month, start.day);
            !date.isAfter(calcEnd);
            date = date.add(const Duration(days: 1))) {
          scheduledDates.add(DateFormat('yyyy-MM-dd').format(date));
        }
      }

      final recordsSnap = await caseRef.collection('custodyRecords').get();
      int fulfilled = 0;
      int justified = 0;

      for (final doc in recordsSnap.docs) {
        final data = doc.data();
        if (!(data['isScheduled'] ?? false)) continue;
        final ts = data['startDate'];
        if (ts is! Timestamp) continue;
        final dateKey = DateFormat('yyyy-MM-dd').format(ts.toDate());
        if (scheduledDates.contains(dateKey)) {
          if (data['isFulfilled'] ?? false) {
            fulfilled++;
          } else {
            justified++;
          }
        }
      }

      final missed = (scheduledDates.length - (fulfilled + justified)).clamp(0, 999999);
      final rate = scheduledDates.isNotEmpty
          ? ((fulfilled + justified) / scheduledDates.length) * 100
          : 0.0;

      return _CustodyCompliance(fulfilled, justified, missed, rate.toDouble());
    } catch (e) {
      return const _CustodyCompliance(0, 0, 0, 0);
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

/// A single value/label stat shown inside a summary card.
class _Stat {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
}

/// Custody compliance figures, matching the Insights "Custody Compliance" card.
class _CustodyCompliance {
  final int fulfilled;
  final int justified;
  final int missed;
  final double rate;
  const _CustodyCompliance(this.fulfilled, this.justified, this.missed, this.rate);
}

/// Aggregated insights over the filtered (child + date) event set. Mirrors the
/// in-app Insights screen cards so the report and the app agree.
///
/// Custody compliance % / "justified" vs "missed" depends on the scheduled-rule
/// calendar, which isn't part of the exported event data, so custody is
/// summarised by fulfilled / not-fulfilled record counts instead.
class _ReportStats {
  // Payments
  final double paid;
  final double received;
  final double compulsory;
  final double additional;
  // Disputes
  final int disputeCommunication;
  final int disputeTransfer;
  final int disputePayment;
  final int disputeTotal;
  // Non-compliance
  final int nonComplianceTotal;
  // Flagged
  final int flaggedCustody;
  final int flaggedPayments;
  final int flaggedDisputes;
  final int flaggedNonCompliance;

  _ReportStats({
    required this.paid,
    required this.received,
    required this.compulsory,
    required this.additional,
    required this.disputeCommunication,
    required this.disputeTransfer,
    required this.disputePayment,
    required this.disputeTotal,
    required this.nonComplianceTotal,
    required this.flaggedCustody,
    required this.flaggedPayments,
    required this.flaggedDisputes,
    required this.flaggedNonCompliance,
  });

  // Matches InsightProvider.totalPayments (paid + received only).
  double get totalPayments => paid + received;
  int get flaggedTotal => flaggedCustody + flaggedPayments + flaggedDisputes + flaggedNonCompliance;

  factory _ReportStats.fromEvents(List<CalendarEvent> events) {
    double paid = 0, received = 0, compulsory = 0, additional = 0;
    int comm = 0, transfer = 0, payDispute = 0, disputeTotal = 0;
    int nonComplianceTotal = 0;
    int flaggedCustody = 0, flaggedPayments = 0, flaggedDisputes = 0, flaggedNonCompliance = 0;

    for (final e in events) {
      switch (e.type) {
        case EventType.custody:
          if (e.isFlagged) flaggedCustody++;
          break;
        case EventType.payment:
          final amount = e.amount ?? 0;
          final isReceived = e.transactionType == 'PaymentReceived' || e.isReceived;
          if (isReceived) {
            received += amount;
          } else {
            paid += amount;
          }
          if (e.paymentCategory == 'Compulsory') {
            compulsory += amount;
          } else {
            additional += amount;
          }
          if (e.isFlagged) flaggedPayments++;
          break;
        case EventType.dispute:
          disputeTotal++;
          if (e.category == 'Communication') {
            comm++;
          } else if (e.category == 'Transfer Issues') {
            transfer++;
          } else if (e.category == 'Payment Disputes') {
            payDispute++;
          }
          if (e.isFlagged) flaggedDisputes++;
          break;
        case EventType.nonCompliance:
          nonComplianceTotal++;
          if (e.isFlagged) flaggedNonCompliance++;
          break;
        case EventType.reminder:
          break;
      }
    }

    return _ReportStats(
      paid: paid,
      received: received,
      compulsory: compulsory,
      additional: additional,
      disputeCommunication: comm,
      disputeTransfer: transfer,
      disputePayment: payDispute,
      disputeTotal: disputeTotal,
      nonComplianceTotal: nonComplianceTotal,
      flaggedCustody: flaggedCustody,
      flaggedPayments: flaggedPayments,
      flaggedDisputes: flaggedDisputes,
      flaggedNonCompliance: flaggedNonCompliance,
    );
  }
}

/// One attachment rendered inline under its record. [image] is non-null only
/// for photos that downloaded successfully; otherwise the file is shown as a
/// clickable link chip. [url] is the destination opened in the browser.
class _Attachment {
  final String url;
  final String fileName;
  final bool isImage;
  final pw.ImageProvider? image;

  _Attachment({required this.url, required this.fileName, required this.isImage, this.image});
}
