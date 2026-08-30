/// Whether a site's cookies survive closing it.
enum CookiePolicy { keep, wipeOnExit }

/// How a site's traffic is routed. The design's rule (turn 8) is that a site
/// set to a proxy never silently falls back to [direct].
enum ProxyMode { direct, socks5, http }

/// Spec `2a`, USER AGENT. Three presets and no free-text field, because a
/// unique UA string is itself a fingerprint.
enum UserAgentMode { android, desktop, minimal }

class Site {
  const Site({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.monogram,
    required this.url,
    required this.profileId,
    this.blockWebRtc = true,
    this.blockTrackers = true,
    this.antiFingerprinting = true,
    this.allowCamera = false,
    this.allowMicrophone = false,
    this.allowLocation = false,
    this.allowClipboard = false,
    this.userAgentMode = UserAgentMode.android,
    this.forceDark = true,
    this.openInReader = false,
    this.pageZoom = 100,
    this.customCss = '',
    this.customJs = '',
    this.cookiePolicy = CookiePolicy.keep,
    this.proxyMode = ProxyMode.direct,
    this.proxyHost,
    this.proxyPort,
    this.requirePin = false,
    this.showInDecoy = false,
    this.lastVisitedAt,
    this.sortIndex = 0,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String monogram;
  final String url;

  /// Names this site's WebView profile. Opaque, random, stored — never derived
  /// from [url] or [name]. See Global Constraints.
  final String profileId;

  final bool blockWebRtc;
  final bool blockTrackers;
  final bool antiFingerprinting;
  final bool allowCamera;
  final bool allowMicrophone;
  final bool allowLocation;
  final bool allowClipboard;
  final UserAgentMode userAgentMode;
  final bool forceDark;
  final bool openInReader;

  /// Percent. Spec `2a` shows `110%`; the slider spans 50–200.
  final int pageZoom;

  final String customCss;
  final String customJs;
  final CookiePolicy cookiePolicy;
  final ProxyMode proxyMode;
  final String? proxyHost;
  final int? proxyPort;
  final bool requirePin;
  final bool showInDecoy;
  final DateTime? lastVisitedAt;
  final int sortIndex;

  /// The bare host shown in the dashboard's meta line — `forum.example.com`
  /// from `https://forum.example.com/threads`.
  String get host => Uri.tryParse(url)?.host ?? url;

  Site copyWith({
    String? name,
    String? monogram,
    String? url,
    String? profileId,
    bool? blockWebRtc,
    bool? blockTrackers,
    bool? antiFingerprinting,
    bool? allowCamera,
    bool? allowMicrophone,
    bool? allowLocation,
    bool? allowClipboard,
    UserAgentMode? userAgentMode,
    bool? forceDark,
    bool? openInReader,
    int? pageZoom,
    String? customCss,
    String? customJs,
    CookiePolicy? cookiePolicy,
    ProxyMode? proxyMode,
    String? proxyHost,
    int? proxyPort,
    bool? requirePin,
    bool? showInDecoy,
    DateTime? lastVisitedAt,
    int? sortIndex,
  }) {
    return Site(
      id: id,
      workspaceId: workspaceId,
      name: name ?? this.name,
      monogram: monogram ?? this.monogram,
      url: url ?? this.url,
      profileId: profileId ?? this.profileId,
      blockWebRtc: blockWebRtc ?? this.blockWebRtc,
      blockTrackers: blockTrackers ?? this.blockTrackers,
      antiFingerprinting: antiFingerprinting ?? this.antiFingerprinting,
      allowCamera: allowCamera ?? this.allowCamera,
      allowMicrophone: allowMicrophone ?? this.allowMicrophone,
      allowLocation: allowLocation ?? this.allowLocation,
      allowClipboard: allowClipboard ?? this.allowClipboard,
      userAgentMode: userAgentMode ?? this.userAgentMode,
      forceDark: forceDark ?? this.forceDark,
      openInReader: openInReader ?? this.openInReader,
      pageZoom: pageZoom ?? this.pageZoom,
      customCss: customCss ?? this.customCss,
      customJs: customJs ?? this.customJs,
      cookiePolicy: cookiePolicy ?? this.cookiePolicy,
      proxyMode: proxyMode ?? this.proxyMode,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      requirePin: requirePin ?? this.requirePin,
      showInDecoy: showInDecoy ?? this.showInDecoy,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  /// Identity-only equality: two [Site]s are equal iff their ids are equal.
  /// This is deliberate — [Site] is an entity with a stable id. As a
  /// consequence, after [touch] updates [lastVisitedAt], the new [Site]
  /// compares equal to the old one. A [Set<Site>], [List.contains],
  /// [Iterable.distinct], or a Riverpod `select` returning a [Site] will not
  /// observe the change. Use identity (`identical`) or compare [lastVisitedAt]
  /// directly if update reactivity is needed.
  @override
  bool operator ==(Object other) => other is Site && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
