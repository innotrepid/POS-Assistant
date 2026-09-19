import 'package:flutter/material.dart';

/// Severity for operator-facing risk dialogs.
enum SafetyLevel { info, caution, critical }

/// Returns true if the operator confirms (proceed).
Future<bool> showSafetyWarning(
  BuildContext context, {
  required String title,
  required String whatHappened,
  required String whyItMatters,
  String? affected,
  String proceedLabel = 'Proceed anyway',
  String cancelLabel = 'Cancel',
  SafetyLevel level = SafetyLevel.caution,
}) async {
  final color = switch (level) {
    SafetyLevel.info => Colors.blueGrey,
    SafetyLevel.caution => Colors.orange,
    SafetyLevel.critical => Colors.red,
  };

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(whatHappened, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(whyItMatters),
              if (affected != null) ...[
                const SizedBox(height: 8),
                Text(affected, style: TextStyle(color: color)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(context, true),
            child: Text(proceedLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}

Future<bool> showSaleConfirmation(
  BuildContext context, {
  required List<String> lines,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Confirm sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(line),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
  return result == true;
}
