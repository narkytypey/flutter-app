import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/proxy_route.dart';
import '../../../../domain/models/site.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../add_site/views/route_fields.dart';
import '../view_models/providers.dart';

/// Dashboard spec §7: the vault's default route, edited with `2a`'s own route
/// fields. Leaving the screen, by its back icon or system back, reports the
/// route as set ([onDone]), with ruling 8 applied (plan D5: no Save button).
/// It is reported on every change as well as on leaving: a lock tears the
/// screen down without popping it, which would otherwise drop the edits.
class DefaultRouteScreen extends StatefulWidget {
  const DefaultRouteScreen({super.key, required this.initial, required this.onDone});

  final ProxyRoute initial;
  final ValueChanged<ProxyRoute> onDone;

  @override
  State<DefaultRouteScreen> createState() => _DefaultRouteScreenState();
}

class _DefaultRouteScreenState extends State<DefaultRouteScreen> {
  // A new site's form starts from 127.0.0.1:9050 when it has no address;
  // this screen does the same, so the two read alike.
  late final _host = TextEditingController(text: widget.initial.host ?? '127.0.0.1');
  late final _port = TextEditingController(text: (widget.initial.port ?? 9050).toString());
  late final _user = TextEditingController(text: widget.initial.user ?? '');
  late final _password = TextEditingController(text: widget.initial.password ?? '');
  late bool _enabled = widget.initial.mode != ProxyMode.direct;
  late ProxyMode _mode =
      widget.initial.mode == ProxyMode.http ? ProxyMode.http : ProxyMode.socks5;
  late bool _perSite = widget.initial.loginPerSite;

  @override
  void initState() {
    super.initState();
    for (final c in [_host, _port, _user, _password]) {
      c.addListener(_report);
    }
  }

  void _report() => widget.onDone(_route());

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  ProxyRoute _route() => ProxyRoute.fromForm(
        mode: _enabled ? _mode : ProxyMode.direct,
        host: _host.text,
        port: int.tryParse(_port.text),
        user: _user.text,
        password: _password.text,
        loginPerSite: _perSite,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onDone(_route());
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    IconTap(
                      glyph: AppGlyph.back,
                      label: 'Back',
                      onTap: () => Navigator.maybePop(context),
                      size: 20,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 10),
                    Text('Default route', style: T.screenTitle),
                  ],
                ),
              ),
              const Divider(height: 1, color: C.line06),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    RouteFields(
                      proxyEnabled: _enabled,
                      onProxyEnabledChanged: (v) {
                        setState(() => _enabled = v);
                        _report();
                      },
                      proxyMode: _mode,
                      onProxyModeChanged: (v) {
                        setState(() => _mode = v);
                        _report();
                      },
                      hostController: _host,
                      portController: _port,
                      loginPerSite: _perSite,
                      onLoginPerSiteChanged: (v) {
                        setState(() => _perSite = v);
                        _report();
                      },
                      userController: _user,
                      passwordController: _password,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [DefaultRouteScreen] against the open vault: Settings ▸ BROWSING's
/// `Default route` row. Changing it touches no saved site and no open
/// container (spec §7).
class DefaultRouteRoute extends ConsumerWidget {
  const DefaultRouteRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = ref.watch(defaultRouteProvider).valueOrNull;
    if (initial == null) return const Scaffold(backgroundColor: C.bg);
    final settings = ref.read(settingsControllerProvider);
    return DefaultRouteScreen(initial: initial, onDone: settings.setDefaultRoute);
  }
}
