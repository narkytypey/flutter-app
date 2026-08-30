import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2a`, Privacy tab. Every hardware permission defaults off; the two
/// shields default on. `showInDecoy` writes `Site.showInDecoy`, a
/// provisioning flag read only when a decoy vault is set up — never a
/// runtime filter (Plan 1's Global Constraints).
class PrivacyTab extends StatelessWidget {
  const PrivacyTab({
    super.key,
    required this.allowCamera,
    required this.onAllowCameraChanged,
    required this.allowMicrophone,
    required this.onAllowMicrophoneChanged,
    required this.allowLocation,
    required this.onAllowLocationChanged,
    required this.allowClipboard,
    required this.onAllowClipboardChanged,
    required this.antiFingerprinting,
    required this.onAntiFingerprintingChanged,
    required this.requirePin,
    required this.onRequirePinChanged,
    required this.showInDecoy,
    required this.onShowInDecoyChanged,
  });

  final bool allowCamera;
  final ValueChanged<bool> onAllowCameraChanged;
  final bool allowMicrophone;
  final ValueChanged<bool> onAllowMicrophoneChanged;
  final bool allowLocation;
  final ValueChanged<bool> onAllowLocationChanged;
  final bool allowClipboard;
  final ValueChanged<bool> onAllowClipboardChanged;
  final bool antiFingerprinting;
  final ValueChanged<bool> onAntiFingerprintingChanged;
  final bool requirePin;
  final ValueChanged<bool> onRequirePinChanged;
  final bool showInDecoy;
  final ValueChanged<bool> onShowInDecoyChanged;

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
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('HARDWARE · ALL OFF BY DEFAULT', style: _label),
        ),
        _bareRow('Camera', allowCamera, onAllowCameraChanged),
        _bareRow('Microphone', allowMicrophone, onAllowMicrophoneChanged),
        _bareRow('Location', allowLocation, onAllowLocationChanged),
        _bareRow('Clipboard', allowClipboard, onAllowClipboardChanged),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 22, 0, 12),
          child: Text('SHIELDS', style: _label),
        ),
        _detailedRow(
          title: 'Anti-fingerprinting',
          subtitle: 'Noise for canvas, WebGL and audio readouts',
          value: antiFingerprinting,
          onChanged: onAntiFingerprintingChanged,
        ),
        _detailedRow(
          title: 'Ask for PIN before opening',
          subtitle: 'Biometric accepted',
          value: requirePin,
          onChanged: onRequirePinChanged,
        ),
        _detailedRow(
          title: 'Show in decoy vault',
          subtitle: 'Visible when the second PIN is used',
          value: showInDecoy,
          onChanged: onShowInDecoyChanged,
        ),
      ],
    );
  }

  Widget _bareRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line06))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: ui(size: 14, color: C.textPrimary)),
          _switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _detailedRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line06))),
      child: Row(
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
      ),
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
