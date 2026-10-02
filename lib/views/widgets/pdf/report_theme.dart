import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/calender_event_model.dart';

/// Visual language of the exported evidence report: a light, document-style
/// layout — muted grey-navy text, thin rules, light grey cards and small
/// letter-spaced section labels, with the brand purple used sparingly.
class ReportPalette {
  static const PdfColor ink = PdfColor.fromInt(0xFF1E2A3B);
  static const PdfColor body = PdfColor.fromInt(0xFF3B4656);
  static const PdfColor muted = PdfColor.fromInt(0xFF6B7484);
  static const PdfColor faint = PdfColor.fromInt(0xFF9AA2AF);
  static const PdfColor rule = PdfColor.fromInt(0xFFE2E5EA);
  static const PdfColor card = PdfColor.fromInt(0xFFF5F6F8);
  static const PdfColor decor = PdfColor.fromInt(0xFFF0F1F4);
  static final PdfColor accent = PdfColor.fromInt(AppColors.primary.toARGB32());

  // Provenance notes on evidence photos.
  static const PdfColor libraryNote = PdfColor.fromInt(0xFFA35D00);
  static const PdfColor cameraNote = PdfColor.fromInt(0xFF1E7A46);

  /// Background / foreground of the small record-type pill.
  static (PdfColor, PdfColor) pill(EventType type) {
    switch (type) {
      case EventType.custody:
        return (const PdfColor.fromInt(0xFFEFE8F6), accent);
      case EventType.payment:
        return (const PdfColor.fromInt(0xFFE7F4EC), const PdfColor.fromInt(0xFF1E7A46));
      case EventType.dispute:
        return (const PdfColor.fromInt(0xFFFDF1E1), const PdfColor.fromInt(0xFFA35D00));
      case EventType.nonCompliance:
        return (const PdfColor.fromInt(0xFFFBE9E9), const PdfColor.fromInt(0xFFB42318));
      case EventType.reminder:
        return (card, muted);
    }
  }

  static String hex(PdfColor c) {
    final v = c.toInt() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }
}

/// The three weights the report uses.
class ReportFonts {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;

  const ReportFonts(this.regular, this.medium, this.semiBold);

  /// Jost (the app font) in static weights. The bundled `assets/fonts/Jost.ttf`
  /// is a variable font, which the pdf package can only render at its default
  /// instance — so weights come from the printing package's font cache. When
  /// they can't be fetched (offline, first run) the report uses the bundled
  /// Jost at that one weight; Helvetica is the last resort, since it lacks
  /// the "–", "—" and "·" the report prints and would show boxes.
  static Future<ReportFonts> load() async {
    try {
      final fonts = await Future.wait([
        PdfGoogleFonts.jostRegular(),
        PdfGoogleFonts.jostMedium(),
        PdfGoogleFonts.jostSemiBold(),
      ]).timeout(const Duration(seconds: 12));
      return ReportFonts(fonts[0], fonts[1], fonts[2]);
    } catch (_) {
      try {
        final jost = pw.Font.ttf(await rootBundle.load('assets/fonts/Jost.ttf'));
        return ReportFonts(jost, jost, jost);
      } catch (_) {
        return ReportFonts(pw.Font.helvetica(), pw.Font.helvetica(), pw.Font.helveticaBold());
      }
    }
  }

  pw.ThemeData get theme => pw.ThemeData.withFont(base: regular, bold: semiBold);
}

/// Outline icons (Feather-style, 24×24 stroke paths) drawn as SVG so the
/// report needs no icon font.
class ReportIcons {
  static const String calendar =
      '<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/>'
      '<line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>';
  static const String moon = '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>';
  static const String card = '<rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/>';
  static const String message = '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>';
  static const String alert =
      '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>'
      '<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>';
  static const String flag =
      '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/>';
  static const String users =
      '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>'
      '<path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>';
  static const String user = '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>';
  static const String dollar =
      '<circle cx="12" cy="12" r="10"/><path d="M15.5 8.5h-5a2 2 0 1 0 0 4h3a2 2 0 1 1 0 4h-5"/>'
      '<line x1="12" y1="6" x2="12" y2="18"/>';
  static const String info =
      '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>';
  static const String briefcase =
      '<rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>';

  static pw.Widget icon(String body, {double size = 14, PdfColor? color, double stroke = 1.6}) {
    final c = ReportPalette.hex(color ?? ReportPalette.muted);
    return pw.SvgImage(
      width: size,
      height: size,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
          '<g fill="none" stroke="$c" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">'
          '$body</g></svg>',
    );
  }

  /// The ClearCase "C" mark: a thick open ring.
  static pw.Widget logo({double size = 18, PdfColor? color, double stroke = 4.2}) {
    final c = ReportPalette.hex(color ?? ReportPalette.accent);
    return pw.SvgImage(
      width: size,
      height: size,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
          '<path d="M18.01 5.99 A8.5 8.5 0 1 0 18.01 18.01" fill="none" stroke="$c" '
          'stroke-width="$stroke" stroke-linecap="round"/></svg>',
    );
  }
}
