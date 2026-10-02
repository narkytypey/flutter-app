/// What a container's page is doing, as the chrome shows it (spec §3.1–3.3).
/// Runtime only, like every session value.
class NavigationState {
  const NavigationState({
    required this.siteId,
    required this.pageId,
    required this.url,
    this.title = '',
    this.canGoBack = false,
    this.canGoForward = false,
    this.loading = false,
    this.progress = 0,
  });

  final String siteId;

  /// The page it is about (tabs spec §3.1).
  final String pageId;
  final String url;
  final String title;
  final bool canGoBack;
  final bool canGoForward;
  final bool loading;

  /// 0–100; the load line's fill while [loading].
  final int progress;

  /// The pill's text. Empty when [url] has none (`about:blank`); the chrome
  /// then falls back to the saved site's host.
  String get host => Uri.tryParse(url)?.host ?? '';
}
