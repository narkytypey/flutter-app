import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import 'form_input.dart';
import 'form_segment.dart';
import 'form_toggle_row.dart';

/// A route's fields (dashboard spec §7): the proxy switch, SOCKS5/HTTP/Tor, HOST,
/// PORT, and Plan 14's login; with Tor, one line in their place (built-in Tor
/// spec §6). `2a`'s Network tab and the Default route screen
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

  static TextStyle get _label => T.sectionLabel;

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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _modeChip('SOCKS5', ProxyMode.socks5)),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('HTTP', ProxyMode.http)),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('Tor', ProxyMode.tor)),
          ],
        ),
        const SizedBox(height: 20),
        // Built-in Tor spec §6: Tor has no address and no typed login.
        if (proxyMode == ProxyMode.tor)
          Text(
            'Through the Tor network. Each site gets its own circuit.',
            style: T.sub,
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOST', style: _label),
                    const SizedBox(height: 8),
                    _field(hostController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PORT', style: _label),
                    const SizedBox(height: 8),
                    _field(portController),
                  ],
                ),
              ),
            ],
          ),
          // Proxy-auth spec §1: only while the proxy is on.
          if (proxyEnabled) ...[
            const SizedBox(height: 12),
            FormToggleRow(
              title: 'Separate login per site',
              subtitle: 'Tor gives this site its own circuit',
              value: loginPerSite,
              onChanged: onLoginPerSiteChanged,
              switchKey: const Key('proxy-login-per-site'),
            ),
            if (!loginPerSite) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('USERNAME', style: _label),
                        const SizedBox(height: 8),
                        _field(userController, key: const Key('proxy-user'), loginField: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PASSWORD', style: _label),
                        const SizedBox(height: 8),
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
      ],
    );
  }

  /// [loginField]: at most 255 characters (ruling 9), no autocorrect or
  /// suggestions. [obscure] masks it, with no reveal control (spec §1).
  Widget _field(TextEditingController controller,
          {Key? key, bool loginField = false, bool obscure = false}) =>
      FormInput(
        key: key,
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: !loginField,
          enableSuggestions: !loginField,
          inputFormatters: loginField ? [LengthLimitingTextInputFormatter(255)] : null,
          style: T.value.copyWith(color: C.textPrimary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      );

  Widget _modeChip(String label, ProxyMode mode) => FormSegment(
        label: label,
        selected: proxyMode == mode,
        onTap: () => onProxyModeChanged(mode),
      );
}
