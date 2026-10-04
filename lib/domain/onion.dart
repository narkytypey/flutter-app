/// Whether [host] is an onion service's name (built-in Tor spec §5.3): it can
/// be reached only through Tor, so it never goes direct or to DNS. Letter
/// case and one trailing dot change nothing.
bool isOnionHost(String host) {
  final lower = host.toLowerCase();
  final name = lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
  return name == 'onion' || name.endsWith('.onion');
}
