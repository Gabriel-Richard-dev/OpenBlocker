import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supported_apps.dart';
import '../../core/widgets/common.dart';
import '../../data/models/platform_models.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';

/// Lets the user choose one installed app. Falls back to typing a package name
/// when the list is not available (e.g. on unsupported platforms).
Future<InstalledApp?> pickApp(BuildContext context) {
  return showModalBottomSheet<InstalledApp>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _AppPickerSheet(),
  );
}

class _AppPickerSheet extends ConsumerStatefulWidget {
  const _AppPickerSheet();

  @override
  ConsumerState<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends ConsumerState<_AppPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final apps = ref.watch(installedAppsProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.searchApps,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: apps.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _ManualEntry(query: _query.text),
              data: (list) {
                if (list.isEmpty) return _ManualEntry(query: _query.text);
                final query = _query.text.trim().toLowerCase();
                final filtered = [
                  for (final app in list)
                    if (query.isEmpty ||
                        app.label.toLowerCase().contains(query) ||
                        app.packageName.toLowerCase().contains(query))
                      app,
                ];
                // Distracting apps first, then alphabetical.
                filtered.sort((a, b) {
                  final da = KnownApps.isDistracting(a.packageName) ? 0 : 1;
                  final db = KnownApps.isDistracting(b.packageName) ? 0 : 1;
                  if (da != db) return da - db;
                  return a.label.toLowerCase().compareTo(b.label.toLowerCase());
                });
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.noAppsFound,
                    message: l10n.noAppsFoundMessage,
                  );
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final known = KnownApps.byPackage(app.packageName);
                    return ListTile(
                      leading: AppIconAvatar(packageName: app.packageName),
                      title: Text(app.label),
                      subtitle: Text(app.packageName),
                      trailing: known != null && known.supportsSelectiveFeed
                          ? Pill(l10n.feedSupportedBadge)
                          : null,
                      onTap: () => Navigator.pop(context, app),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntry extends StatefulWidget {
  const _ManualEntry({required this.query});

  final String query;

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  late final _package = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _package.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.appListUnavailable),
        const SizedBox(height: 16),
        TextField(
          controller: _package,
          decoration: InputDecoration(
            labelText: l10n.packageNameLabel,
            hintText: 'com.example.app',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final packageName = _package.text.trim();
            if (packageName.isEmpty) return;
            final known = KnownApps.byPackage(packageName);
            Navigator.pop(
              context,
              InstalledApp(
                packageName: packageName,
                label: known?.label ?? packageName,
              ),
            );
          },
          child: Text(l10n.actionUse),
        ),
        const SizedBox(height: 24),
        Text(l10n.knownApps, style: Theme.of(context).textTheme.titleSmall),
        for (final app in KnownApps.all)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(app.label),
            subtitle: Text(app.packageName),
            onTap: () => Navigator.pop(
              context,
              InstalledApp(packageName: app.packageName, label: app.label),
            ),
          ),
      ],
    );
  }
}
