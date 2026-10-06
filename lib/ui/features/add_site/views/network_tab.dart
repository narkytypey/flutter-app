import 'package:flutter/material.dart';

import '../../../../domain/models/route_display.dart';
import '../../../../domain/models/site.dart';
import 'form_toggle_row.dart';
import 'route_fields.dart';

/// Spec `2a`, Network tab.
class NetworkTab extends StatelessWidget {
  const NetworkTab({
    super.key,
    required this.proxyEnabled,
    required this.onProxyEnabledChanged,
    required this.proxyMode,
    required this.onProxyModeChanged,
    required this.hostController,
    required this.portController,
    required this.loginPerSite,
    required this.onLoginPerSiteChanged,
    required this.userController,
    required this.passwordController,
    required this.blockWebRtc,
    required this.onBlockWebRtcChanged,
    required this.blockTrackers,
    required this.onBlockTrackersChanged,
    this.rulesMatchedToday,
  });

  final bool proxyEnabled;
  final ValueChanged<bool> onProxyEnabledChanged;
  final ProxyMode proxyMode;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool loginPerSite;
  final ValueChanged<bool> onLoginPerSiteChanged;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final bool blockWebRtc;
  final ValueChanged<bool> onBlockWebRtcChanged;
  final bool blockTrackers;
  final ValueChanged<bool> onBlockTrackersChanged;

  /// The site's filter-list blocks since the app started, from Today's
  /// in-memory tally; null for a new site, whose subtitle then has no count
  /// (user's ruling 2026-10-05: the canvas's 42 was an example).
  final int? rulesMatchedToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RouteFields(
          proxyEnabled: proxyEnabled,
          onProxyEnabledChanged: onProxyEnabledChanged,
          proxySubtitle: 'This site only',
          proxyMode: proxyMode,
          onProxyModeChanged: onProxyModeChanged,
          hostController: hostController,
          portController: portController,
          loginPerSite: loginPerSite,
          onLoginPerSiteChanged: onLoginPerSiteChanged,
          userController: userController,
          passwordController: passwordController,
        ),
        const SizedBox(height: 12),
        FormToggleRow(
          title: 'Block WebRTC',
          subtitle: 'Prevents real IP leaking past the proxy',
          // Built-in Tor spec §5.4: always on for Tor, and inert.
          value: blockWebRtc || (proxyEnabled && webRtcLocked(proxyMode)),
          onChanged: proxyEnabled && webRtcLocked(proxyMode) ? null : onBlockWebRtcChanged,
        ),
        FormToggleRow(
          title: 'Block trackers and ads',
          subtitle: switch (rulesMatchedToday) {
            null => 'Local filter lists',
            1 => 'Local filter lists · 1 rule matched today',
            final n => 'Local filter lists · $n rules matched today',
          },
          value: blockTrackers,
          onChanged: onBlockTrackersChanged,
        ),
      ],
    );
  }
}
