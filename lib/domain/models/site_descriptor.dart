import 'site.dart';

/// The second half of a dashboard row's meta line — `forum.example.com ·
/// ephemeral`. One descriptor wins; the order below is the order the design's
/// Personal workspace shows (spec `1b`).
///
/// Note: the spec's `Scratch tab` mock row reads `wipes on exit` where this
/// rule yields `ephemeral`. That is an inconsistency in the mock data, not two
/// different states, and it is resolved here in favour of the rule.
String siteDescriptor(Site site) {
  if (site.requirePin) return 'pin required';
  if (site.cookiePolicy == CookiePolicy.wipeOnExit) return 'ephemeral';
  return switch (site.proxyMode) {
    ProxyMode.socks5 => 'socks5',
    ProxyMode.http => 'http',
    ProxyMode.direct => 'direct',
  };
}
