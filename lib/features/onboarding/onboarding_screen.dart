import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../settings/permissions_screen.dart';
import '../settings/settings_controller.dart';

/// First-run explanation of what OpenBlock does, which permissions it needs,
/// what it can observe and how to turn it off.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _pageCount = 5;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = _index == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) => setState(() => _index = index),
                children: [
                  _InfoPage(
                    icon: Icons.self_improvement_rounded,
                    title: l10n.onboardingWelcomeTitle,
                    body: l10n.onboardingWelcomeBody,
                  ),
                  _InfoPage(
                    icon: Icons.verified_user_outlined,
                    title: l10n.onboardingPermissionsTitle,
                    body: l10n.onboardingPermissionsBody,
                  ),
                  _InfoPage(
                    icon: Icons.visibility_outlined,
                    title: l10n.onboardingDataTitle,
                    body: l10n.onboardingDataBody,
                  ),
                  _InfoPage(
                    icon: Icons.power_settings_new_rounded,
                    title: l10n.onboardingControlTitle,
                    body: l10n.onboardingControlBody,
                  ),
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        l10n.onboardingSetupTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.onboardingSetupBody),
                      const SizedBox(height: 16),
                      const PermissionPanel(),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: () => _go(_index - 1),
                      child: Text(l10n.actionBack),
                    )
                  else
                    const SizedBox(width: 64),
                  Expanded(
                    child: Semantics(
                      label: l10n.onboardingStep(_index + 1, _pageCount),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pageCount; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _index ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('onboardingNext'),
                    onPressed: last
                        ? ref.read(settingsProvider.notifier).completeOnboarding
                        : () => _go(_index + 1),
                    child: Text(last ? l10n.onboardingFinish : l10n.actionNext),
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

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(icon, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 16),
        Text(body, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
