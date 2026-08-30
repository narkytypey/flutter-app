import 'package:flutter/material.dart';

import '../../../../domain/models/route_failure_copy.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
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
    required this.onOpenWithoutTunnel,
  });

  final String host;
  final String siteName;
  final RouteFailure failure;
  final String tunnelDescriptor;
  final String lastWorkedLabel;
  final VoidCallback onTryAgain;
  final VoidCallback onChangeProxySettings;
  final VoidCallback onOpenWithoutTunnel;

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
            _TunnelHeader(host: host),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
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
                      child: const Text('⛌', style: TextStyle(fontSize: 16, color: C.danger)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      proxyFailureHeadline(failure),
                      style: ui(size: 19, weight: 600, letterSpacing: -0.19),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        detail,
                        style: ui(size: 13.5, height: 1.7, color: C.textMuted),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: C.sheet,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.line08),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(label: 'Tunnel', value: tunnelDescriptor),
                          const SizedBox(height: 7),
                          _InfoRow(label: 'Last worked', value: lastWorkedLabel),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    PillButton(label: 'Try again', tone: PillTone.primary, onTap: onTryAgain),
                    const SizedBox(height: 9),
                    PillButton(label: 'Change proxy settings', onTap: onChangeProxySettings),
                    const SizedBox(height: 9),
                    PillButton(
                      label: 'Open without the tunnel',
                      sublabel: 'This site will see your real IP',
                      tone: PillTone.dangerOutline,
                      onTap: onOpenWithoutTunnel,
                    ),
                    const SizedBox(height: 20),
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

/// The site pill in a danger tint, shared by `8b` and `8c` — both show a
/// tunnel that is not currently working.
class _TunnelHeader extends StatelessWidget {
  const _TunnelHeader({required this.host});

  final String host;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line07))),
      child: Row(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: Center(child: Text('‹', style: TextStyle(fontSize: 16, color: C.icon))),
          ),
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: C.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(host, style: ui(size: 11.5, color: C.textTertiary)),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 32,
            height: 32,
            child: Center(child: Text('⟳', style: TextStyle(fontSize: 14, color: C.icon))),
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
      children: [
        Text(label, style: ui(size: 12, color: C.textFaint)),
        Text(value, style: ui(size: 12, color: C.textSecondary)),
      ],
    );
  }
}
