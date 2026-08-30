import 'package:flutter/material.dart';

import '../../../../domain/models/held_download.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `7c` — says what a held download is and where it would land.
///
/// "Discard" is this sheet's jade action, not "Keep" or "Save" — in an app
/// whose whole premise is that data does not leave the container, throwing
/// the file away is the affirmative, privacy-preserving choice. This is not
/// a mistake carried over from a generic "primary button" convention; the
/// spec draws it filled jade on purpose.
class HeldDownloadSheet extends StatelessWidget {
  const HeldDownloadSheet({super.key, required this.download, required this.onDecision});

  final HeldDownload download;
  final ValueChanged<DownloadDecision> onDecision;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        Text('Download held', style: ui(size: 17, weight: 600, letterSpacing: -0.17)),
        const SizedBox(height: 8),
        Text(
          'Files leave the container when they are saved. This one would go to '
          'your device storage where other apps can read it.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.line08),
          ),
          child: Row(
            children: [
              // Plan 1's Monogram, parameterised — its open branch is already
              // `C.monogramOpen` on `C.monogramText` at weight 600, which is
              // exactly what the spec draws for this badge.
              Monogram(download.kindLabel, size: 38, radius: 10, fontSize: 11),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(download.fileName, style: ui(size: 13.5, color: C.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      '${formatBytes(download.sizeBytes)} · from ${download.sourceHost}',
                      style: ui(size: 11.5, color: C.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Keep inside this container',
          onTap: () => onDecision(DownloadDecision.keepInContainer),
        ),
        const SizedBox(height: 9),
        PillButton(
          label: 'Save to device storage',
          onTap: () => onDecision(DownloadDecision.saveToDevice),
        ),
        const SizedBox(height: 9),
        PillButton(
          label: 'Discard',
          tone: PillTone.primary,
          onTap: () => onDecision(DownloadDecision.discard),
        ),
      ],
    );
  }
}
