import 'package:flutter/material.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2a`, Network tab. `blockedCount` has no live source in this task's
/// interface (no engine seam is in scope here — see Plan 1's `leakCountProvider`
/// for the same kind of not-yet-wired number), so its copy uses the spec's own
/// example value rather than inventing a parameter nothing feeds yet.
class NetworkTab extends StatelessWidget {
  const NetworkTab({
    super.key,
    required this.proxyEnabled,
    required this.onProxyEnabledChanged,
    required this.proxyMode,
    required this.onProxyModeChanged,
    required this.hostController,
    required this.portController,
    required this.blockWebRtc,
    required this.onBlockWebRtcChanged,
    required this.blockTrackers,
    required this.onBlockTrackersChanged,
  });

  final bool proxyEnabled;
  final ValueChanged<bool> onProxyEnabledChanged;
  final ProxyMode proxyMode;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool blockWebRtc;
  final ValueChanged<bool> onBlockWebRtcChanged;
  final bool blockTrackers;
  final ValueChanged<bool> onBlockTrackersChanged;

  static const _label = TextStyle(
    fontFamily: 'Figtree',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: C.textFaint,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleRow(
          title: 'Route through proxy',
          subtitle: 'This site only',
          value: proxyEnabled,
          onChanged: onProxyEnabledChanged,
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
                  const Text('HOST', style: _label),
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
                  const Text('PORT', style: _label),
                  const SizedBox(height: 7),
                  _field(portController),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _toggleRow(
          title: 'Block WebRTC',
          subtitle: 'Prevents real IP leaking past the proxy',
          value: blockWebRtc,
          onChanged: onBlockWebRtcChanged,
        ),
        const SizedBox(height: 14),
        _toggleRow(
          title: 'Block trackers and ads',
          subtitle: 'Local filter lists · 42 rules matched today',
          value: blockTrackers,
          onChanged: onBlockTrackersChanged,
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line09),
        ),
        child: TextField(
          controller: controller,
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

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ui(size: 14, color: C.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: ui(size: 11, color: C.textFaint)),
            ],
          ),
        ),
        _switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _switch({required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 44,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? C.jade : C.trackOff,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? C.bg : C.knobOff,
          ),
        ),
      ),
    );
  }
}
