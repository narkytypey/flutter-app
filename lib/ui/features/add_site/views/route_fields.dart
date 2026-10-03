import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import 'form_toggle_row.dart';

/// A route's fields (dashboard spec §7): the proxy switch, SOCKS5/HTTP, HOST,
/// PORT, and Plan 14's login. `2a`'s Network tab and the Default route screen
/// both use it, so the two never differ. [proxySubtitle] is the switch's
/// subtitle: `2a`'s "This site only", none on Default route (plan D2).
class RouteFields extends StatelessWidget {
  const RouteFields({
    super.key,
    required this.proxyEnabled,
    required this.onProxyEnabledChanged,
    this.proxySubtitle,
    required this.proxyMode,
    required this.onProxyModeChanged,
    required this.hostController,
    required this.portController,
    required this.loginPerSite,
    required this.onLoginPerSiteChanged,
    required this.userController,
    required this.passwordController,
  });

  final bool proxyEnabled;
  final ValueChanged<bool> onProxyEnabledChanged;
  final String? proxySubtitle;
  final ProxyMode proxyMode;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool loginPerSite;
  final ValueChanged<bool> onLoginPerSiteChanged;
  final TextEditingController userController;
  final TextEditingController passwordController;

  static final _label = T.sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormToggleRow(
          title: 'Route through proxy',
          subtitle: proxySubtitle,
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
          FormToggleRow(
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
}
