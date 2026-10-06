import 'package:flutter/material.dart';

import '../../../../domain/models/permissions.dart';
import '../../../core/host_text.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `6a` — a site asks for hardware.
///
/// "Keep blocked" is the sheet's single jade action (restyle v2 §8, §12 Q6,
/// as the canvas draws it): keeping hardware blocked is the affirmative,
/// privacy-preserving choice. The two allows are neutral. Colour only: the
/// words, their order and what each does are as built.
class PermissionRequestSheet extends StatelessWidget {
  const PermissionRequestSheet({
    super.key,
    required this.host,
    required this.kind,
    required this.onDecision,
  });

  final String host;
  final PermissionKind kind;
  final ValueChanged<PermissionDecision> onDecision;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        // The host wraps after its dots, never cut short (restyle v2 §1.6).
        Text.rich(
          TextSpan(children: [hostSpan(host), TextSpan(text: ' wants ${kind.phrase}')]),
          style: T.sheetTitle,
        ),
        const SizedBox(height: S.s2),
        Text(
          'It is blocked right now. Allowing it applies to this site only, '
          'inside this container.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: S.s4),
        PillButton(
          label: 'Allow once',
          onTap: () => onDecision(PermissionDecision.allowOnce),
        ),
        const SizedBox(height: S.s2),
        PillButton(
          label: 'Allow while this site is open',
          onTap: () => onDecision(PermissionDecision.allowWhileOpen),
        ),
        const SizedBox(height: S.s2),
        PillButton(
          label: 'Keep blocked',
          tone: PillTone.primary,
          onTap: () => onDecision(PermissionDecision.keepBlocked),
        ),
      ],
    );
  }
}
