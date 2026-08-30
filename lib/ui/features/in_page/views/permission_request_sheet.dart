import 'package:flutter/material.dart';

import '../../../../domain/models/permissions.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `6a` — a site asks for hardware.
///
/// "Allow once" is the sheet's single jade action. The other two are neutral,
/// which is the design saying that keeping it blocked is not a failure state.
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
        Text('$host wants ${kind.phrase}',
            style: ui(size: 17, weight: 600, letterSpacing: -0.17)),
        const SizedBox(height: 8),
        Text(
          'It is blocked right now. Allowing it applies to this site only, '
          'inside this container.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Allow once',
          tone: PillTone.primary,
          onTap: () => onDecision(PermissionDecision.allowOnce),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'Allow while this site is open',
          onTap: () => onDecision(PermissionDecision.allowWhileOpen),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'Keep blocked',
          onTap: () => onDecision(PermissionDecision.keepBlocked),
        ),
      ],
    );
  }
}
