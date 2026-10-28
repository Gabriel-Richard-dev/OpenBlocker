/// Registry of apps OpenBlock knows about.
///
/// Feed targets must match an adapter in
/// `android/.../accessibility/adapters/`. See docs/supported-apps.md for what
/// each adapter detects and how it was tested.
library;

enum AppCategory { social, video, messaging, other }

enum SupportLevel {
  /// Implemented and verified on real devices listed in docs/tested-devices.md.
  verified,

  /// Implemented but not yet verified on enough real devices.
  experimental,
}

class FeedTarget {
  const FeedTarget({
    required this.id,
    required this.packageName,
    required this.level,
  });

  /// Stable identifier shared with the native adapters, e.g. `youtube.shorts`.
  final String id;
  final String packageName;
  final SupportLevel level;
}

class KnownApp {
  const KnownApp({
    required this.packageName,
    required this.label,
    required this.category,
    this.feedTargets = const [],
  });

  final String packageName;
  final String label;
  final AppCategory category;
  final List<FeedTarget> feedTargets;

  bool get supportsSelectiveFeed => feedTargets.isNotEmpty;
}

abstract final class FeedTargets {
  static const youtubeShorts = FeedTarget(
    id: 'youtube.shorts',
    packageName: 'com.google.android.youtube',
    level: SupportLevel.experimental,
  );

  static const instagramReels = FeedTarget(
    id: 'instagram.reels',
    packageName: 'com.instagram.android',
    level: SupportLevel.experimental,
  );

  static const all = [youtubeShorts, instagramReels];

  static FeedTarget? byId(String id) {
    for (final target in all) {
      if (target.id == id) return target;
    }
    return null;
  }
}

abstract final class KnownApps {
  static const youtube = KnownApp(
    packageName: 'com.google.android.youtube',
    label: 'YouTube',
    category: AppCategory.video,
    feedTargets: [FeedTargets.youtubeShorts],
  );

  static const instagram = KnownApp(
    packageName: 'com.instagram.android',
    label: 'Instagram',
    category: AppCategory.social,
    feedTargets: [FeedTargets.instagramReels],
  );

  static const tiktok = KnownApp(
    packageName: 'com.zhiliaoapp.musically',
    label: 'TikTok',
    category: AppCategory.video,
  );

  static const tiktokAsia = KnownApp(
    packageName: 'com.ss.android.ugc.trill',
    label: 'TikTok',
    category: AppCategory.video,
  );

  static const all = [
    youtube,
    instagram,
    tiktok,
    tiktokAsia,
    KnownApp(
      packageName: 'com.facebook.katana',
      label: 'Facebook',
      category: AppCategory.social,
    ),
    KnownApp(
      packageName: 'com.twitter.android',
      label: 'X',
      category: AppCategory.social,
    ),
    KnownApp(
      packageName: 'com.reddit.frontpage',
      label: 'Reddit',
      category: AppCategory.social,
    ),
    KnownApp(
      packageName: 'com.snapchat.android',
      label: 'Snapchat',
      category: AppCategory.social,
    ),
    KnownApp(
      packageName: 'com.pinterest',
      label: 'Pinterest',
      category: AppCategory.social,
    ),
    KnownApp(
      packageName: 'com.zhiliaoapp.musically.go',
      label: 'TikTok Lite',
      category: AppCategory.video,
    ),
    KnownApp(
      packageName: 'com.kwai.video',
      label: 'Kwai',
      category: AppCategory.video,
    ),
    KnownApp(
      packageName: 'com.instagram.barcelona',
      label: 'Threads',
      category: AppCategory.social,
    ),
    KnownApp(
      packageName: 'xyz.blueskyweb.app',
      label: 'Bluesky',
      category: AppCategory.social,
    ),
  ];

  static KnownApp? byPackage(String packageName) {
    for (final app in all) {
      if (app.packageName == packageName) return app;
    }
    return null;
  }

  static List<FeedTarget> feedTargetsFor(String packageName) =>
      byPackage(packageName)?.feedTargets ?? const [];

  static bool isDistracting(String packageName) {
    final category = byPackage(packageName)?.category;
    return category == AppCategory.social || category == AppCategory.video;
  }
}
