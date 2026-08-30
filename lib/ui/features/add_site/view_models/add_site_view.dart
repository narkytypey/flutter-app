import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/site.dart';

/// Assembles the final [Site] the form describes. A new site gets a fresh
/// id and profile id (both from [newProfileId] — Task 1 defines no separate
/// site-id generator, and an opaque random id serves identically well here);
/// editing preserves [initial]'s id and profile id, since a site's WebView
/// profile must never change under it.
Site buildSite({
  required Site? initial,
  required String url,
  required String name,
  required String monogram,
  required String workspaceId,
  required CookiePolicy cookiePolicy,
  required ProxyMode proxyMode,
  String? proxyHost,
  int? proxyPort,
  required bool blockWebRtc,
  required bool blockTrackers,
  required bool antiFingerprinting,
  required bool allowCamera,
  required bool allowMicrophone,
  required bool allowLocation,
  required bool allowClipboard,
  required bool requirePin,
  required bool showInDecoy,
  required UserAgentMode userAgentMode,
  required bool forceDark,
  required bool openInReader,
  required int pageZoom,
  required String customCss,
  required String customJs,
}) {
  return Site(
    id: initial?.id ?? newProfileId(),
    workspaceId: workspaceId,
    name: name,
    monogram: monogram,
    url: url,
    profileId: initial?.profileId ?? newProfileId(),
    cookiePolicy: cookiePolicy,
    proxyMode: proxyMode,
    proxyHost: proxyHost,
    proxyPort: proxyPort,
    blockWebRtc: blockWebRtc,
    blockTrackers: blockTrackers,
    antiFingerprinting: antiFingerprinting,
    allowCamera: allowCamera,
    allowMicrophone: allowMicrophone,
    allowLocation: allowLocation,
    allowClipboard: allowClipboard,
    requirePin: requirePin,
    showInDecoy: showInDecoy,
    userAgentMode: userAgentMode,
    forceDark: forceDark,
    openInReader: openInReader,
    pageZoom: pageZoom,
    customCss: customCss,
    customJs: customJs,
    lastVisitedAt: initial?.lastVisitedAt,
    sortIndex: initial?.sortIndex ?? 0,
  );
}
