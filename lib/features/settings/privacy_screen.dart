import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sections = [
      (l10n.privacyLocalTitle, l10n.privacyLocalBody),
      (l10n.privacyAccessibilityTitle, l10n.privacyAccessibilityBody),
      (l10n.privacyUsageTitle, l10n.privacyUsageBody),
      (l10n.privacyNoNetworkTitle, l10n.privacyNoNetworkBody),
      (l10n.privacyDeleteTitle, l10n.privacyDeleteBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, body) in sections) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
