import 'route_decision.dart';

export 'route_decision.dart' show RouteFailure;

/// Screen `8b` draws only [RouteFailure.proxyUnreachable]; its headline is
/// pinned verbatim from the spec card. The other kinds reuse Plan 3's
/// `refusalMessage()` — written, by its own doc comment, for exactly this
/// screen. Extending the spec's one drawn case to the four kinds Plan 3
/// defined is this plan's call, not the spec's; see Known gaps.
String proxyFailureHeadline(RouteFailure failure) {
  if (failure == RouteFailure.proxyUnreachable) return 'Proxy did not answer';
  return refusalMessage(failure);
}

/// The explanatory sentence under the headline, or `null` when the spec gives
/// us nothing to say.
///
/// Only [RouteFailure.proxyUnreachable] is drawn, so only its wording is
/// pinned. [RouteFailure.proxyRefused], [RouteFailure.upstreamTimeout] and
/// [RouteFailure.tlsFailure] share a generic first half: all three describe a
/// tunnel that exists and did not work, so naming it is accurate.
///
/// [RouteFailure.misconfigured] returns `null`. Its headline is "This site
/// has no proxy configured", and the generic sentence would say the site "is
/// set to go through" a tunnel — denying a proxy exists and naming one in
/// consecutive sentences. The spec draws no copy for that state (a grep of
/// the canvas file finds none), and a string that is not in the spec is a
/// design question rather than something to invent here, so the screen shows
/// the headline alone.
///
/// The cost is real and is recorded in this plan's Known gaps: the closing
/// reassurance — no request left your device — is the sentence a user most
/// wants on a failure screen, and `misconfigured` is the one kind that now
/// does not get it.
///
/// [RouteFailure.unsupported] has its own sentence, approved with its headline
/// in the P2 spec (§3.3): nothing is wrong with the tunnel, so the generic
/// sentence would mislead, and the remedy is on the phone.
String? proxyFailureDetail(
  RouteFailure failure, {
  required String siteName,
  required String tunnelDescriptor,
}) {
  if (failure == RouteFailure.misconfigured) return null;
  // Built-in Tor spec §7, approved word for word: Tor is not a tunnel that
  // "did not complete the connection"; it never reached its network.
  if (failure == RouteFailure.torFailed) {
    return '$siteName is set to go through Tor, which could not reach the Tor network. '
        'The page was not loaded, so no request left your device.';
  }
  if (failure == RouteFailure.unsupported) {
    return 'Update Android System WebView to open proxied sites.';
  }

  final cause = failure == RouteFailure.proxyUnreachable
      ? '$siteName is set to go through $tunnelDescriptor and nothing is listening there.'
      : '$siteName is set to go through $tunnelDescriptor, which did not complete the connection.';
  return '$cause The page was not loaded, so no request left your device.';
}
