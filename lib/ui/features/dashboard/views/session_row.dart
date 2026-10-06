import 'package:flutter/material.dart';

import '../../../core/host_text.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/status_rail.dart';
import '../view_models/dashboard_view.dart';

/// One site on the dashboard, a row inside the list's [Group] (restyle v2
/// §8 `1b`): at least 72 dp, the jade light at the monogram's corner while
/// the site is open and nothing there when it is idle, the meta line's host
/// in Plex Mono and never cut short.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final SessionEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// The meta line, `host · descriptor`, with the host set as a value. The
  /// plain text (and so what is read and matched) is [SessionEntry.meta]
  /// unchanged.
  static TextSpan metaSpan(String meta) {
    const separator = ' · ';
    final at = meta.indexOf(separator);
    if (at <= 0) return TextSpan(text: meta, style: T.meta);
    return TextSpan(
      style: T.meta,
      children: [
        hostSpan(meta.substring(0, at), style: T.metaValue),
        TextSpan(text: meta.substring(at)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = entry.live;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Monogram(entry.monogram, open: live),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: live
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: C.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: StatusRail(live: live, showIdle: false),
                              ),
                            )
                          : StatusRail(live: live, showIdle: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: live ? T.rowTitle : T.rowTitleIdle),
                    const SizedBox(height: 2),
                    Text.rich(metaSpan(entry.meta), softWrap: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(entry.age, style: T.meta),
            ],
          ),
        ),
      ),
    );
  }
}
