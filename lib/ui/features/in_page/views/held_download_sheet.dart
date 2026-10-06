import 'package:flutter/material.dart';

import '../../../../domain/models/held_download.dart';
import '../../../core/host_text.dart';
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
        Text('Download held', style: T.sheetTitle),
        const SizedBox(height: S.s2),
        Text(
          'Files leave the container when they are saved. This one would go to '
          'your device storage where other apps can read it.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: S.s4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(R.input),
            border: Border.all(color: C.line),
          ),
          child: Row(
            children: [
              // Plan 1's Monogram, parameterised: its open branch is the
              // raised tone with text-1 at weight 600.
              Monogram(download.kindLabel, size: 40, radius: R.monogram, fontSize: 13),
              const SizedBox(width: S.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(download.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: T.body),
                    const SizedBox(height: 2),
                    // The host wraps after its dots, never cut short
                    // (restyle v2 §1.6). The spec has no copy for an unknown
                    // size, so the size is left out rather than shown as
                    // "0 B".
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: switch (download.sizeBytes) {
                            final size? => '${formatBytes(size)} · from ',
                            null => 'from ',
                          },
                        ),
                        hostSpan(download.sourceHost),
                      ]),
                      style: T.meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: S.s4),
        PillButton(
          label: 'Keep inside this container',
          onTap: () => onDecision(DownloadDecision.keepInContainer),
        ),
        const SizedBox(height: S.s2),
        PillButton(
          label: 'Save to device storage',
          onTap: () => onDecision(DownloadDecision.saveToDevice),
        ),
        const SizedBox(height: S.s2),
        PillButton(
          label: 'Discard',
          tone: PillTone.primary,
          onTap: () => onDecision(DownloadDecision.discard),
        ),
      ],
    );
  }
}
