import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helping_functions.dart';
import 'custom_primary_button.dart';
import 'custom_secondary_button.dart';

/// What a cleaned-up entry is, so the AI knows the context. The values must
/// match CLEAN_UP_RECORD_TYPES in functions/index.js.
class AiCleanUpRecordType {
  static const String custody = 'custody';
  static const String payment = 'payment';
  static const String dispute = 'dispute';
  static const String disputeLog = 'disputeLog';
  static const String nonCompliance = 'nonCompliance';
  static const String evidence = 'evidence';
}

/// "✨ AI Clean Up" pill that sits beside a written-record field's label.
///
/// Sends the text to the `cleanUpRecordText` Cloud Function and shows the
/// original next to the cleaned-up version. The field only changes if the
/// user picks "Use Cleaned Version".
class AiCleanUpButton extends StatelessWidget {
  final TextEditingController controller;
  final String recordType;

  const AiCleanUpButton({super.key, required this.controller, required this.recordType});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _start(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 15, color: AppColors.primary),
              SizedBox(width: 5),
              Text(
                "AI Clean Up",
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    final original = controller.text.trim();
    if (original.isEmpty) {
      showSnackBar(context, "Write your entry first, then use AI Clean Up.");
      return;
    }
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiCleanUpSheet(
        original: original,
        recordType: recordType,
        onUse: (cleaned) {
          controller.text = cleaned;
          controller.selection = TextSelection.collapsed(offset: cleaned.length);
        },
      ),
    );
  }
}

class _AiCleanUpSheet extends StatefulWidget {
  final String original;
  final String recordType;
  final ValueChanged<String> onUse;

  const _AiCleanUpSheet({required this.original, required this.recordType, required this.onUse});

  @override
  State<_AiCleanUpSheet> createState() => _AiCleanUpSheetState();
}

class _AiCleanUpSheetState extends State<_AiCleanUpSheet> {
  String? _cleaned;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _cleaned = null;
      _error = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('cleanUpRecordText', options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
          .call<Map<String, dynamic>>({'text': widget.original, 'recordType': widget.recordType});
      final cleaned = (result.data['cleaned'] as String? ?? '').trim();
      if (!mounted) return;
      setState(() {
        if (cleaned.isEmpty) {
          _error = "AI Clean Up failed. Please try again.";
        } else {
          _cleaned = cleaned;
        }
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint("AI Clean Up error: ${e.code} ${e.message}");
      if (!mounted) return;
      setState(() => _error = e.message ?? "AI Clean Up failed. Please try again.");
    } catch (e) {
      debugPrint("AI Clean Up error: $e");
      if (!mounted) return;
      setState(() => _error = "Couldn't reach AI Clean Up. Check your connection and try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text("AI Clean Up", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Your facts. Professionally presented.",
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.lightGreyColor, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.redColor),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text("Your original entry hasn't been changed.", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 20),
          CustomPrimaryButton(text: "Try Again", onPressed: _run),
          const SizedBox(height: 12),
          CustomSecondaryButton(text: "Close", onPressed: () => Navigator.pop(context)),
        ],
      );
    }

    if (_cleaned == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
            SizedBox(height: 16),
            Text("Polishing your entry…", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      );
    }

    final unchanged = _cleaned == widget.original;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section("Original", widget.original, background: AppColors.lightGreyColor),
                const SizedBox(height: 12),
                _section(
                  "Cleaned Up",
                  _cleaned!,
                  background: AppColors.primaryTint,
                  icon: Icons.auto_awesome,
                ),
                if (unchanged) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Your entry already reads clearly — no changes suggested.",
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "AI Clean Up improves clarity and formatting without adding or changing facts.",
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomPrimaryButton(
          text: "Use Cleaned Version",
          onPressed: () {
            widget.onUse(_cleaned!);
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 12),
        CustomSecondaryButton(text: "Keep Original", onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _section(String label, String text, {required Color background, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 5),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1,
                  color: icon != null ? AppColors.primary : AppColors.darkGreyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
