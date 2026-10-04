import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/address_input.dart';
import '../../../../domain/models/monogram_suggestion.dart';
import '../../../../domain/models/proxy_route.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/onion.dart';

/// [typed] as a site's address, read as the address bar reads it
/// ([parseAddressInput]): an `http` or `https` address, a bare host given
/// `https://`, a Unicode host in punycode. Null for anything else (another
/// scheme, words, nothing), which the engine would never load.
String? siteAddress(String typed) => switch (parseAddressInput(typed)) {
      AddressUrl(:final url) => url.toString(),
      _ => null,
    };

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
  String proxyUser = '',
  String proxyPassword = '',
  bool proxyLoginPerSite = false,
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
  // Ruling 8, in one place (ProxyRoute.fromForm): a typed login is kept only
  // while the proxy is on, per-site login is off and a user was typed.
  final formRoute = ProxyRoute.fromForm(
    mode: proxyMode,
    host: proxyHost,
    port: proxyPort,
    user: proxyUser,
    password: proxyPassword,
    loginPerSite: proxyLoginPerSite,
  );
  // Dashboard spec §6: a blank name saves as the address's host, as typed,
  // and takes that host's monogram, as a throwaway saved as a site does
  // (`buildThrowaway`).
  final blank = name.trim().isEmpty;
  final host = Uri.parse(url).host;
  // Built-in Tor spec §5.3, plan D7: an onion address is never saved on Direct.
  final route =
      formRoute.mode == ProxyMode.direct && isOnionHost(host) ? ProxyRoute.tor : formRoute;
  return Site(
    id: initial?.id ?? newProfileId(),
    workspaceId: workspaceId,
    name: blank ? host : name,
    monogram: blank ? suggestMonogram(host) : monogram,
    url: url,
    profileId: initial?.profileId ?? newProfileId(),
    cookiePolicy: cookiePolicy,
    proxyMode: route.mode,
    proxyHost: route.host,
    proxyPort: route.port,
    proxyUser: route.user,
    proxyPassword: route.password,
    proxyLoginPerSite: route.loginPerSite,
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
    // The form has no level control: saving keeps the site's own, or none
    // (privacy-controls spec §2.1).
    securityLevel: initial?.securityLevel,
  );
}
