import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/calender_event_model.dart';
import 'export_filter.dart';

class PDFGenerator {
  static final PdfColor primaryColor = PdfColor.fromInt(0xFF4A148C);

  static Future<void> generateReport({
    required String caseName,
    required ExportOptions options,
    required List<CalendarEvent> allEvents,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.jostRegular();
    final fontBold = await PdfGoogleFonts.jostBold();

    final filteredEvents = allEvents.where((event) {
      bool isManual = !event.id.startsWith('rule_');

      bool sectionEnabled = false;
      if (event.type == EventType.custody && options.reportSections["Custody"] == true) sectionEnabled = true;
      if (event.type == EventType.payment && options.reportSections["Payments"] == true) sectionEnabled = true;
      if (event.type == EventType.dispute && options.reportSections["Disputes"] == true) sectionEnabled = true;
      if (event.type == EventType.nonCompliance && options.reportSections["Non-Compliance"] == true) sectionEnabled = true;

      bool matchesDate = true;
      DateTime eventDay = DateTime(event.date.year, event.date.month, event.date.day);
      if (options.startDate != null && eventDay.isBefore(options.startDate!)) matchesDate = false;
      if (options.endDate != null && eventDay.isAfter(options.endDate!)) matchesDate = false;

      return isManual && sectionEnabled && matchesDate;
    }).toList();

    filteredEvents.sort((a, b) => a.date.compareTo(b.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          _buildHeader(caseName, options, fontBold),
          pw.SizedBox(height: 15),
          _buildTable(filteredEvents, fontBold),
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

  static pw.Widget _buildTable(List<CalendarEvent> events, pw.Font bold) {
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
            _buildDetailedRow(e, bold),
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
  static pw.Widget _buildDetailedRow(CalendarEvent e, pw.Font bold) {
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
        ],
      ),
    );
  }


}