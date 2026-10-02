import 'dart:io';

import 'package:clearcase/core/utils/timeframe.dart';
import 'package:clearcase/models/calender_event_model.dart';
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/views/widgets/export_filter.dart';
import 'package:clearcase/views/widgets/pdf/report_theme.dart';
import 'package:clearcase/views/widgets/pdf_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

// Lays out a sample report end to end, so a layout overflow (which the pdf
// package throws on) fails here instead of on a user's phone. Set
// PDF_PREVIEW_OUT to a file path to also write the PDF for a visual check.
void main() {
  final caseModel = CaseModel(
    userId: 'u',
    caseNumber: '12345',
    legalRep: 'Sam',
    createdAt: DateTime(2026, 7, 1),
    children: [
      ChildModel(id: 'j', name: 'john', dob: DateTime(2018, 3, 4), school: 'Springfield Primary', address: '1 Martin Pl, Sydney'),
      ChildModel(id: 't', name: 'test', dob: DateTime(2020, 9, 1)),
    ],
  );

  List<CalendarEvent> sampleEvents() => [
        CalendarEvent(
          id: 'c1',
          title: 'Custody Record',
          date: DateTime(2026, 7, 17),
          type: EventType.custody,
          childIds: const ['j'],
          childNames: const ['john'],
          location: '1 Martin Pl, Sydney, Australia, 2000',
          startTime: DateTime(2026, 7, 17, 9),
          endTime: DateTime(2026, 7, 17, 17),
          isFlagged: true,
        ),
        CalendarEvent(
          id: 'p1',
          title: 'Child Support',
          date: DateTime(2026, 7, 18),
          type: EventType.payment,
          amount: 100,
          childIds: const ['j'],
          childNames: const ['john'],
          paymentCategory: 'Compulsory',
          paymentMethod: 'Bank Transfer',
          transactionType: 'PaymentMade',
        ),
        CalendarEvent(
          id: 'd1',
          title: 'Dispute',
          date: DateTime(2026, 7, 20),
          type: EventType.dispute,
          category: 'Transfer Issues',
          party: 'Mother',
          description: 'Late drop off time, no communication.',
        ),
        CalendarEvent(
          id: 'n1',
          title: 'Missed Visit',
          date: DateTime(2026, 8, 2),
          type: EventType.nonCompliance,
          childIds: const ['j', 't'],
          childNames: const ['john', 'test'],
          severity: 'Serious',
          party: 'Father',
          proof: 'Text messages from that afternoon.',
          description: 'Did not arrive for the scheduled visit.',
        ),
      ];

  test('report lays out without overflow', () async {
    final pdf = PDFGenerator.buildPreviewDocument(
      options: ExportOptions(
        childIds: const [],
        timePeriod: Timeframe.allTime,
        reportSections: const {
          "Custody": true,
          "Payments": true,
          "Disputes": true,
          "Non-Compliance": true,
          "Flagged Events": true,
        },
      ),
      events: sampleEvents(),
      caseModel: caseModel,
      // The bundled font, so the preview shows the real glyphs offline.
      fonts: () {
        final jost = pw.Font.ttf(File('assets/fonts/Jost.ttf').readAsBytesSync().buffer.asByteData());
        return ReportFonts(jost, jost, jost);
      }(),
      generatedAt: DateTime(2026, 10, 2),
    );
    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);

    final out = Platform.environment['PDF_PREVIEW_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
