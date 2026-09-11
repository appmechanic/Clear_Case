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
import '../../core/utils/custody_span.dart';
import '../../core/utils/evidence_source.dart';
import '../../core/utils/timeframe.dart';
import '../../models/calender_event_model.dart';
import '../../models/case_model.dart';
import 'export_filter.dart';
import 'file_type_icon.dart';

class PDFGenerator {
  static final PdfColor primaryColor = PdfColor.fromInt(0xFF4A148C);

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
      await Future.any([
        SchedulerBinding.instance.endOfFrame,
        Future<void>.delayed(const Duration(milliseconds: 100)),
      ]);
    }

    await stage(0.02, "Preparing report…");
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.jostRegular();
    final fontBold = await PdfGoogleFonts.jostBold();

    await stage(0.08, "Loading case details…");
    // Parent / guardian = the logged-in account holder.
    final parent = await _fetchParentDetails();

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

    // Only the children actually included in this report (per the export filter).
    final reportChildren = (caseModel?.children ?? const <ChildModel>[])
        .where((c) => options.childIds.isEmpty || options.childIds.contains(c.id))
        .toList();

    // Custody is summarised from what was recorded — nights covered and
    // entries logged in the period — overall and per child. Scheduled rules
    // play no part.
    final custody = options.reportSections["Custody"] == true
        ? _CustodySummary.from(statsEvents, reportChildren, window)
        : null;

    // Pre-fetch image attachments before building pages — MultiPage.build is
    // synchronous, so image bytes must be resolved up front. Attachments are
    // rendered inline beneath each record (keyed by record id). This is
    // usually the slowest step, so it owns most of the progress bar (10–75%).
    await stage(0.10, "Collecting attachments…");
    final attachments = await _collectAttachments(
      tableEvents,
      onImage: (done, total) => onProgress?.call(
        0.10 + 0.65 * (done / total),
        "Adding photos ($done of $total)…",
      ),
    );

    final summaryWidgets = _buildSummary(stats, custody, options, fontBold);
    final allChildren = caseModel?.children ?? const <ChildModel>[];

    // addPage lays the whole document out synchronously.
    await stage(0.78, "Laying out pages…");

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
          _buildTable(tableEvents, fontBold, attachments, allChildren),
        ],
      ),
    );

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

  static pw.Widget _buildHeader(String caseName, ExportOptions options, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("CASE RECORDS - CLEARCASE", style: pw.TextStyle(fontSize: 22, font: bold, color: primaryColor)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Case Reference Number: $caseName", style: pw.TextStyle(font: bold, fontSize: 12)),
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
              _coverInfoRow("Case Reference Number", caseName, bold),
              _coverInfoRow("Legal Representative", legalRep, bold),
              _coverInfoRow("Parent / Guardian", guardian, bold),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Per-child details. One block each so school/address are never
        // ambiguous across siblings.
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
              pw.Text("CHILDREN",
                  style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 14),
              if (children.isEmpty)
                pw.Text("—", style: const pw.TextStyle(fontSize: 11))
              else
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) pw.SizedBox(height: 14),
                  pw.Text(children[i].name,
                      style: pw.TextStyle(font: bold, fontSize: 12)),
                  pw.SizedBox(height: 4),
                  _coverInfoRow("Date of Birth",
                      DateFormat('dd/MM/yyyy').format(children[i].dob), bold),
                  _coverInfoRow("School", _orDash(children[i].school), bold),
                  _coverInfoRow("Address", _orDash(children[i].address), bold),
                ],
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

  // Absent or blank detail renders as an em dash, matching how the cover already
  // represents missing data.
  static String _orDash(String? value) =>
      (value ?? "").trim().isEmpty ? "—" : value!.trim();

  // Human-readable description of the time span the report covers.
  static String _reportPeriod(ExportOptions options) => options.periodDescription;

  // Which child(ren) a record belongs to, by name. Disputes and
  // non-compliance are case-level records with no child ids, so they apply to
  // every child in the case.
  static String _childNamesFor(CalendarEvent e, List<ChildModel> children) {
    final names = <String>[];
    for (final id in e.childIds) {
      final match = children.where((c) => c.id == id);
      if (match.isNotEmpty) names.add(match.first.name.trim());
    }
    if (names.isNotEmpty) return names.join(", ");
    if (e.childNames.isNotEmpty) return e.childNames.join(", ");
    if (e.type == EventType.dispute || e.type == EventType.nonCompliance) return "All children";
    return "Not specified";
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
    _CustodySummary? custody,
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
          _Stat("${custody.overall.nights}", "Total Nights"),
          _Stat("${custody.overall.entries}", "Total Entries"),
        ],
        // Per-child figures so it's clear whose custody time is whose.
        breakdown: [
          for (final row in custody.perChild)
            _Stat(
              "${nightsLabel(row.totals.nights)} · ${row.totals.entries == 1 ? '1 entry' : '${row.totals.entries} entries'}",
              row.childName,
            ),
        ],
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
    List<_Stat> breakdown = const [],
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
          // Label/value rows under the headline stats (e.g. one per child).
          if (breakdown.isNotEmpty) ...[
            pw.Divider(height: 18, color: PdfColors.grey400),
            ...breakdown.map((row) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(row.label, style: pw.TextStyle(font: bold, fontSize: 10)),
                  pw.Text(row.value, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            )),
          ],
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
    List<ChildModel> children,
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
        0: const pw.FixedColumnWidth(78), // Room for a full date
        1: const pw.FixedColumnWidth(82),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            _cell("Date", bold, textColor: PdfColors.white),
            _cell("Record Type", bold, textColor: PdfColors.white),
            _cell("Child", bold, textColor: PdfColors.white),
            _cell("Detailed & Information", bold, textColor: PdfColors.white),
          ],
        ),
        ...events.map((e) => pw.TableRow(
          children: [
            // Date cell — a multi-day custody entry shows first and last day.
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                e.type == EventType.custody && e.span.isMultiDay
                    ? "${DateFormat('dd/MM/yyyy').format(e.span.start)} –\n${DateFormat('dd/MM/yyyy').format(e.span.end)}"
                    : DateFormat('dd/MM/yyyy').format(e.date),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            // Type cell
            _cell(e.type == EventType.nonCompliance ? "NON-COMPLIANCE" : e.type.name.toUpperCase(), bold),
            // Child cell — whose record this is.
            _cell(_childNamesFor(e, children), null),
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
            pw.Text("Custody Entry", style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.Text("Period: ${_custodyPeriod(e)}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Nights: ${e.span.nights}", style: pw.TextStyle(fontSize: 10, font: bold)),
            if ((e.location ?? "").trim().isNotEmpty) pw.Text("Location: ${e.location}", style: const pw.TextStyle(fontSize: 10)),
            if ((e.description ?? "").trim().isNotEmpty) pw.Text("Notes: ${e.description}", style: const pw.TextStyle(fontSize: 10)),
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

  // "29/09/2026 09:00 AM – 05/10/2026 05:00 PM"; dates only when the entry
  // has no handover times.
  static String _custodyPeriod(CalendarEvent e) {
    final date = DateFormat('dd/MM/yyyy');
    final time = DateFormat('hh:mm a');
    final start = "${date.format(e.span.start)}${e.startTime != null ? ' ${time.format(e.startTime!)}' : ''}";
    final end = "${date.format(e.span.end)}${e.endTime != null ? ' ${time.format(e.endTime!)}' : ''}";
    return "$start – $end";
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
        // Provenance, so the reader knows how far the photo's time/place can
        // be relied on.
        if (a.isImage && a.source == EvidenceSource.library)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(libraryPhotoNotice,
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: PdfColors.orange800)),
          ),
        if (a.isImage && a.source == EvidenceSource.camera)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(cameraPhotoNotice,
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.green800)),
          ),
      ],
    );
  }

  // --- Inline attachments ---

  // Resolves every record's attachments up front. Image bytes are downloaded
  // so photos can render as thumbnails; documents are kept as link targets.
  // Bounds on embedded images so a photo-heavy report can't exhaust memory or
  // produce an unusable multi-hundred-MB PDF. Images beyond the cap, and any
  // that fail to load, render as a tappable link chip instead.
  static const int _maxEmbeddedImages = 50;
  static const int _imageMaxWidth = 1280;
  // Photos downloaded in parallel — enough to hide per-request latency
  // without flooding a mobile connection.
  static const int _downloadConcurrency = 4;

  /// [onImage] is called as each embedded photo finishes (done, total).
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
      map[e.id] = list;
    }

    // Pass 2: download + downscale. null image -> link-chip fallback.
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
          'PDF export: embedded $_maxEmbeddedImages image(s); $skippedForCap more shown as links to bound memory/file size.');
    }
    return map;
  }

  /// Downloads [url] and returns a PDF image downscaled to at most [maxWidth]
  /// pixels wide. Resizing bounds the decoded buffer — the real driver of
  /// out-of-memory crashes when many large photos are embedded. Returns null
  /// on any failure so the caller renders a link chip.
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

/// A single value/label stat shown inside a summary card.
class _Stat {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
}

/// Custody figures for the report's "Custody Compliance" card — the same
/// Total Nights / Total Entries the Insights screen shows, plus one row per
/// child included in the report.
class _CustodySummary {
  final CustodyTotals overall;
  final List<({String childName, CustodyTotals totals})> perChild;

  const _CustodySummary(this.overall, this.perChild);

  factory _CustodySummary.from(
    List<CalendarEvent> events,
    List<ChildModel> children,
    TimeWindow window,
  ) {
    final custody = events.where((e) => e.type == EventType.custody).toList();
    return _CustodySummary(
      CustodyTotals.from(custody.map((e) => e.span), window),
      [
        for (final child in children)
          (
            childName: child.name.trim(),
            totals: CustodyTotals.from(
              custody.where((e) => e.childIds.contains(child.id)).map((e) => e.span),
              window,
            ),
          ),
      ],
    );
  }
}

/// Aggregated insights over the filtered (child + date) event set. Mirrors the
/// in-app Insights screen cards so the report and the app agree.
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
  // Captured in-app (stamped) vs. picked from the device library.
  final EvidenceSource source;
  // Filled in by _collectAttachments once the download finishes.
  pw.ImageProvider? image;

  _Attachment({
    required this.url,
    required this.fileName,
    required this.isImage,
    this.source = EvidenceSource.unknown,
  });
}
