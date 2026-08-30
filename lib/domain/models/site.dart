/// Whether a site's cookies survive closing it.
enum CookiePolicy { keep, wipeOnExit }

/// How a site's traffic is routed. The design's rule (turn 8) is that a site
/// set to a proxy never silently falls back to [direct].
enum ProxyMode { direct, socks5, http }

class Site {
  const Site({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.monogram,
    required this.url,
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
