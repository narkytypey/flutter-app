import 'dart:convert';

import 'site.dart';

/// A route as a site holds it (mode, host, port and Plan 14's login), kept
/// apart from any site: the vault's default route (dashboard spec §7), which a
/// throwaway opened from the dashboard runs on and a new site's form starts
/// from.
class ProxyRoute {
  const ProxyRoute({
    this.mode = ProxyMode.direct,
    this.host,
    this.port,
    this.user,
    this.password,
    this.loginPerSite = false,
  });

  /// The default route until one is chosen.
  static const direct = ProxyRoute();

  /// What a stored route that cannot be read becomes: a proxy with no
  /// address, which every open refuses (`8b`). Never [direct]: it may have
  /// been a proxy, and nothing falls back to direct.
  static const unreadable = ProxyRoute(mode: ProxyMode.socks5);

  /// The route a form describes, with ruling 8 applied: a typed login is kept
  /// only while the proxy is on, per-site login is off and a user was typed.
  /// A direct route keeps no address and no login. Nothing is trimmed.
  factory ProxyRoute.fromForm({
    required ProxyMode mode,
    String? host,
    int? port,
    String user = '',
    String password = '',
    bool loginPerSite = false,
  }) {
    if (mode == ProxyMode.direct) return direct;
    final typed = !loginPerSite && user.isNotEmpty;
    return ProxyRoute(
      mode: mode,
      host: host,
      port: port,
      user: typed ? user : null,
      password: typed ? password : null,
      loginPerSite: loginPerSite,
    );
  }

  /// [site]'s own route, as saved.
  factory ProxyRoute.of(Site site) => ProxyRoute(
        mode: site.proxyMode,
        host: site.proxyHost,
        port: site.proxyPort,
        user: site.proxyUser,
        password: site.proxyPassword,
        loginPerSite: site.proxyLoginPerSite,
      );

  final ProxyMode mode;
  final String? host;
  final int? port;
  final String? user;
  final String? password;
  final bool loginPerSite;

  /// Settings' row value (spec §8): `Direct`, or `SOCKS5 · 127.0.0.1:9050`.
  /// A proxy with no address reads as its mode alone.
  String get label {
    if (mode == ProxyMode.direct) return 'Direct';
    final name = mode.name.toUpperCase();
    return host == null || port == null ? name : '$name · $host:$port';
  }

  /// `app_settings.default_route`'s value, in the encrypted vault.
  String toStored() => jsonEncode({
        'mode': mode.name,
        'host': host,
        'port': port,
        'user': user,
        'password': password,
        'loginPerSite': loginPerSite,
      });

  /// Reads [toStored]'s value. Nothing stored is [direct]. Anything that
  /// cannot be read is [unreadable].
  static ProxyRoute fromStored(String? stored) {
    if (stored == null) return direct;
    try {
      final data = jsonDecode(stored) as Map<String, Object?>;
      final mode = ProxyMode.values.firstWhere((m) => m.name == data['mode']);
      return ProxyRoute(
        mode: mode,
        host: data['host'] as String?,
        port: data['port'] as int?,
        user: data['user'] as String?,
        password: data['password'] as String?,
        loginPerSite: data['loginPerSite'] as bool? ?? false,
      );
    } on Object {
      return unreadable;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ProxyRoute &&
      other.mode == mode &&
      other.host == host &&
      other.port == port &&
      other.user == user &&
      other.password == password &&
      other.loginPerSite == loginPerSite;

  @override
  int get hashCode => Object.hash(mode, host, port, user, password, loginPerSite);
}
