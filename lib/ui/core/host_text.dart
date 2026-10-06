import 'package:flutter/widgets.dart';

/// Restyle v2 §1.6: a host is never ellipsized. It wraps, and only after a
/// `.`: this puts U+200B ZERO WIDTH SPACE after each dot so a line may break
/// there. For layout only — what a screen reader hears, and what
/// `find.text` matches, is the plain host (see [hostSpan]).
String breakAfterDots(String host) => host.replaceAll('.', '.​');

/// [host] laid out with [breakAfterDots], read and matched as the plain host:
/// a span's `semanticsLabel` is what `toPlainText()` returns.
TextSpan hostSpan(String host, {TextStyle? style}) =>
    TextSpan(text: breakAfterDots(host), semanticsLabel: host, style: style);

/// A host that wraps after its dots and is never cut short.
class HostText extends StatelessWidget {
  const HostText(this.host, {super.key, this.style, this.textAlign});

  final String host;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) =>
      Text.rich(hostSpan(host), style: style, textAlign: textAlign, softWrap: true);
}
