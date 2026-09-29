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
/// fragment. Labels are letters, digits and hyphens only, so no scheme,
/// userinfo or Unicode host ever matches.
final _bareAddress = RegExp(
  r'^(localhost|(?:\d{1,3}\.){3}\d{1,3}|(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63})'
  r'(?::(\d{1,5}))?'
  r'([/?#].*)?$',
  caseSensitive: false,
);

final _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

AddressInput parseAddressInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const AddressEmpty();
  if (_whitespace.hasMatch(text)) return AddressSearch(text);

  if (_explicitWeb.hasMatch(text)) {
    final url = Uri.tryParse(text);
    return url != null && url.host.isNotEmpty ? AddressUrl(url) : AddressSearch(text);
  }

  final match = _bareAddress.firstMatch(text);
  if (match != null && _validHost(match.group(1)!) && _validPort(match.group(2))) {
    // Always https. A failed load is shown as failed; nothing retries over
    // http behind the user's back.
    final url = Uri.tryParse('https://$text');
    if (url != null && url.host.isNotEmpty) return AddressUrl(url);
  }

  // Every other scheme — javascript:, file:, intent:, about:, … — lands here
  // with everything else that is not an address: searched for, never loaded.
  return AddressSearch(text);
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
