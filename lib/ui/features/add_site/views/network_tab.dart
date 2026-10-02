import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2a`, Network tab. `blockedCount` has no live source in this task's
/// interface (no engine seam is in scope here), so its copy uses the spec's own
/// example value rather than inventing a parameter nothing feeds yet.
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

  static final _label = T.sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleRow(
          title: 'Route through proxy',
          subtitle: 'This site only',
          value: proxyEnabled,
          onChanged: onProxyEnabledChanged,
          switchKey: const Key('proxy-enabled'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _modeChip('SOCKS5', ProxyMode.socks5)),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('HTTP', ProxyMode.http)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOST', style: _label),
                  const SizedBox(height: 7),
                  _field(hostController),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PORT', style: _label),
                  const SizedBox(height: 7),
                  _field(portController),
                ],
              ),
            ),
          ],
        ),
        // Proxy-auth spec §1: only while the proxy is on.
        if (proxyEnabled) ...[
          const SizedBox(height: 18),
          _toggleRow(
            title: 'Separate login per site',
            subtitle: 'Tor gives this site its own circuit',
            value: loginPerSite,
            onChanged: onLoginPerSiteChanged,
            switchKey: const Key('proxy-login-per-site'),
          ),
          if (!loginPerSite) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('USERNAME', style: _label),
                      const SizedBox(height: 7),
                      _field(userController, key: const Key('proxy-user'), loginField: true),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PASSWORD', style: _label),
                      const SizedBox(height: 7),
                      _field(passwordController,
                          key: const Key('proxy-password'), loginField: true, obscure: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 18),
        _toggleRow(
          title: 'Block WebRTC',
          subtitle: 'Prevents real IP leaking past the proxy',
          value: blockWebRtc,
          onChanged: onBlockWebRtcChanged,
        ),
        const SizedBox(height: 14),
        _toggleRow(
          title: 'Block trackers and ads',
          subtitle: 'Local filter lists · 42 rules matched today',
          value: blockTrackers,
          onChanged: onBlockTrackersChanged,
        ),
      ],
    );
  }

  /// [loginField]: at most 255 characters (ruling 9), no autocorrect or
  /// suggestions. [obscure] masks it, with no reveal control (spec §1).
  Widget _field(TextEditingController controller,
          {Key? key, bool loginField = false, bool obscure = false}) =>
      Container(
        key: key,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line09),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: !loginField,
          enableSuggestions: !loginField,
          inputFormatters: loginField ? [LengthLimitingTextInputFormatter(255)] : null,
          style: mono(size: 13, color: C.textSecondary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      );

  Widget _modeChip(String label, ProxyMode mode) {
    final selected = proxyMode == mode;
    return GestureDetector(
      onTap: () => onProxyModeChanged(mode),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.selected : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? C.line10 : C.line07),
        ),
        child: Text(label,
            style: ui(size: 12, weight: 500, color: selected ? C.textPrimary : C.tabInactive)),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Key? switchKey,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ui(size: 14, color: C.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: ui(size: 11, color: C.textFaint)),
            ],
          ),
        ),
        _switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _switch({Key? key, required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      key: key,
      onTap: () => onChanged(!value),
      child: Container(
        width: 44,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? C.jade : C.trackOff,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? C.bg : C.knobOff,
          ),
        ),
      ),
    );
  }
}
