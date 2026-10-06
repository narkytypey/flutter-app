import 'package:flutter/material.dart';

import '../../../../domain/models/route_failure_copy.dart';
import '../../../core/host_text.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/centered_scroll.dart';
import '../../../core/widgets/pill_button.dart';

/// Spec `8b` — no silent fallback, the risky option spelled out. This is the
/// screen the interceptor's refusal (Plan 3) surfaces to: a route that could
/// not be established, never a page that quietly loaded unproxied.
class ProxyUnreachableScreen extends StatelessWidget {
  const ProxyUnreachableScreen({
    super.key,
    required this.host,
    required this.siteName,
    required this.failure,
    required this.tunnelDescriptor,
    required this.lastWorkedLabel,
    required this.onTryAgain,
    required this.onChangeProxySettings,
    this.onOpenWithoutTunnel,
  });

  final String host;
  final String siteName;
  final RouteFailure failure;
  final String tunnelDescriptor;
  final String lastWorkedLabel;
  final VoidCallback onTryAgain;
  final VoidCallback onChangeProxySettings;
  /// Null when the site cannot go direct (built-in Tor spec §5.6): the button is not shown.
  final VoidCallback? onOpenWithoutTunnel;

  @override
  Widget build(BuildContext context) {
    // Null for `misconfigured` — see `proxyFailureDetail`. The headline then
    // stands alone rather than carrying invented copy.
    final detail = proxyFailureDetail(
      failure,
      siteName: siteName,
      tunnelDescriptor: tunnelDescriptor,
    );

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            TunnelHeader(host: host),
            Expanded(
              child: CenteredScroll(
                padding: const EdgeInsets.symmetric(horizontal: S.s6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: C.danger.withValues(alpha: 0.3)),
                      ),
                      child: const AppIcon(AppGlyph.refused, size: 20, color: C.danger),
                    ),
                    const SizedBox(height: S.s4),
                    Text(proxyFailureHeadline(failure), style: T.sheetTitle),
                    if (detail != null) ...[
                      const SizedBox(height: S.s3),
                      Text(detail, style: T.bodyMuted),
                    ],
                    const SizedBox(height: S.s5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: S.s4, vertical: S.s3),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(R.input),
                        border: Border.all(color: C.line),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(label: 'Tunnel', value: tunnelDescriptor),
                          const SizedBox(height: S.s2),
                          _InfoRow(label: 'Last worked', value: lastWorkedLabel),
                        ],
                      ),
                    ),
                    const SizedBox(height: S.s6),
                    PillButton(label: 'Try again', tone: PillTone.primary, onTap: onTryAgain),
                    const SizedBox(height: S.s2),
                    PillButton(label: 'Change proxy settings', onTap: onChangeProxySettings),
                    // The risky choice is text, set apart (restyle v2 §5,
                    // §8): it must not carry a button's weight beside the
                    // safe ones.
                    if (onOpenWithoutTunnel case final openDirect?) ...[
                      const SizedBox(height: S.s6),
                      PillButton(
                        label: 'Open without the tunnel',
                        sublabel: 'This site will see your real IP',
                        tone: PillTone.dangerText,
                        onTap: openDirect,
                      ),
                    ],
                    const SizedBox(height: S.s5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site pill in a danger tint, shared by `8b` and `8c`: both show a
/// tunnel that is not currently working. Its marks are decoration, as the
/// canvas draws them. The host wraps after its dots and the pill grows; it is
/// never cut short (restyle v2 §1.6).
class TunnelHeader extends StatelessWidget {
  const TunnelHeader({super.key, required this.host, this.rule = true});

  final String host;

  /// The rule under the header (`8b`); `8c`'s banner sits right under it.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: S.s1, vertical: S.s2),
      decoration: rule
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: C.line)))
          : null,
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: AppIcon(AppGlyph.back, size: 18)),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: S.s2),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: C.danger.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: S.s2),
                  Expanded(child: HostText(host, style: T.address)),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: AppIcon(AppGlyph.reload, size: 16)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.sub.copyWith(color: C.textFaint)),
        const SizedBox(width: S.s3),
        // The tunnel names a host: it wraps after its dots, never cut short.
        Flexible(
          child: HostText(
            value,
            textAlign: TextAlign.end,
            style: T.sub.copyWith(color: C.textPrimary),
          ),
        ),
      ],
    );
  }
}
