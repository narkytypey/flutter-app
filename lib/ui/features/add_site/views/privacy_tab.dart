import 'package:flutter/material.dart';

import '../../../core/typography.dart';
import '../../../core/widgets/group.dart';
import 'form_toggle_row.dart';

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

  static final _label = T.sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('HARDWARE · ALL OFF BY DEFAULT', style: _label),
        ),
        Group(
          children: [
            FormToggleRow(title: 'Camera', value: allowCamera, onChanged: onAllowCameraChanged),
            FormToggleRow(
                title: 'Microphone', value: allowMicrophone, onChanged: onAllowMicrophoneChanged),
            FormToggleRow(title: 'Location', value: allowLocation, onChanged: onAllowLocationChanged),
            FormToggleRow(
                title: 'Clipboard', value: allowClipboard, onChanged: onAllowClipboardChanged),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text('SHIELDS', style: _label),
        ),
        Group(
          children: [
            FormToggleRow(
              title: 'Anti-fingerprinting',
              subtitle: 'Noise for canvas, WebGL and audio readouts',
              value: antiFingerprinting,
              onChanged: onAntiFingerprintingChanged,
            ),
            FormToggleRow(
              title: 'Ask for PIN before opening',
              subtitle: 'Biometric accepted',
              value: requirePin,
              onChanged: onRequirePinChanged,
            ),
            FormToggleRow(
              title: 'Show in decoy vault',
              subtitle: 'Visible when the second PIN is used',
              value: showInDecoy,
              onChanged: onShowInDecoyChanged,
            ),
          ],
        ),
      ],
    );
  }
}
