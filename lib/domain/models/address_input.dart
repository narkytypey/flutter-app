import '../idn.dart';

/// What the address field's text means (spec
/// `2026-09-28-browser-chrome-design.md` §4.1). Pure Dart.
sealed class AddressInput {
  const AddressInput();
}

/// Nothing but whitespace.
class AddressEmpty extends AddressInput {
  const AddressEmpty();
}

/// An `http` or `https` address, ready to load.
class AddressUrl extends AddressInput {
  const AddressUrl(this.url);

  final Uri url;
}

/// Words for the search engine. [query] is the input, trimmed.
class AddressSearch extends AddressInput {
  const AddressSearch(this.query);

  final String query;
}

final _whitespace = RegExp(r'\s');
final _explicitWeb = RegExp(r'^https?://', caseSensitive: false);

/// `host.tld` (last label two or more letters), `localhost` or an IPv4
/// literal; then an optional `:port`; then an optional path, query or
/// fragment. Labels are letters, digits and hyphens only, so no scheme or
/// userinfo ever matches. Letters may be any script's (user's ruling,
/// 2026-10-02): such a host is loaded in its punycode form ([hostToAscii]).
final _bareAddress = RegExp(
  r'^(localhost|(?:\d{1,3}\.){3}\d{1,3}|(?:[\p{L}\p{M}\p{N}](?:[\p{L}\p{M}\p{N}-]{0,61}[\p{L}\p{M}\p{N}])?\.)+[\p{L}\p{M}]{2,63})'
  r'(?::(\d{1,5}))?'
  r'([/?#].*)?$',
  caseSensitive: false,
  unicode: true,
);

/// An explicit address split into scheme, authority and the rest.
final _explicitParts = RegExp(r'^(https?://)([^/?#]*)(.*)$', caseSensitive: false, dotAll: true);

final _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

AddressInput parseAddressInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const AddressEmpty();
  if (_whitespace.hasMatch(text)) return AddressSearch(text);

  if (_explicitWeb.hasMatch(text)) {
    final ascii = _withAsciiHost(text);
    final url = ascii == null ? null : Uri.tryParse(ascii);
    return url != null && url.host.isNotEmpty ? AddressUrl(url) : AddressSearch(text);
  }

  final match = _bareAddress.firstMatch(text);
  if (match != null && _validHost(match.group(1)!) && _validPort(match.group(2))) {
    final host = hostToAscii(match.group(1)!);
    // Always https. A failed load is shown as failed; nothing retries over
    // http behind the user's back.
    final url = host == null ? null : Uri.tryParse('https://$host${text.substring(match.group(1)!.length)}');
    if (url != null && url.host.isNotEmpty) return AddressUrl(url);
  }

  // Every other scheme — javascript:, file:, intent:, about:, … — lands here
  // with everything else that is not an address: searched for, never loaded.
  return AddressSearch(text);
}

/// [text], an explicit address, with a Unicode host replaced by its punycode,
/// since `Uri` would percent-encode it instead. Null when it has no ASCII
/// form. An IPv6 literal or an ASCII host is left as typed.
String? _withAsciiHost(String text) {
  final parts = _explicitParts.firstMatch(text)!;
  final authority = parts.group(2)!;
  final at = authority.lastIndexOf('@');
  final hostPort = authority.substring(at + 1);
  if (hostPort.startsWith('[')) return text;
  final colon = hostPort.indexOf(':');
  final host = colon < 0 ? hostPort : hostPort.substring(0, colon);
  if (host.runes.every((c) => c < 0x80)) return text;
  final ascii = hostToAscii(host);
  if (ascii == null) return null;
  return '${parts.group(1)}${authority.substring(0, at + 1)}$ascii'
      '${hostPort.substring(host.length)}${parts.group(3)}';
}

bool _validHost(String host) {
  final octets = _ipv4.firstMatch(host);
  if (octets == null) return true;
  for (var i = 1; i <= 4; i++) {
    if (int.parse(octets.group(i)!) > 255) return false;
  }
  return true;
}

bool _validPort(String? port) => port == null || int.parse(port) <= 65535;
