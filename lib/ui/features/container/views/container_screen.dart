import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import 'container_top_bar.dart';
import 'container_toolbar.dart';
import 'switcher_sheet.dart';

/// Spec `2b` — the isolated container itself: top bar, page content, and the
/// floating toolbar whose centre pill opens the quick switcher (`2c`).
class ContainerScreen extends StatelessWidget {
  const ContainerScreen({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.openCount,
    required this.body,
    required this.entries,
    required this.workspaceName,
    required this.onBack,
    required this.onReload,
    required this.onPanic,
    required this.onCloseSession,
    required this.onCloseAllAndWipe,
    required this.onReaderMode,
    required this.onFilters,
    required this.onMenu,
    required this.onMore,
  });

  final String host;
  final String routeLabel;
  final bool live;
  final int openCount;

  /// The page itself. Plan 3 renders this as a native WebView platform view;
  /// this screen only owns the chrome around it.
  final Widget body;

  final List<SwitcherEntry> entries;
  final String workspaceName;

  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onPanic;
  final void Function(String siteId) onCloseSession;
  final VoidCallback onCloseAllAndWipe;
  final VoidCallback onReaderMode;
  final VoidCallback onFilters;
  final VoidCallback onMenu;
  final VoidCallback onMore;

  void _openSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => SwitcherSheet(
        entries: entries,
        workspaceName: workspaceName,
        onCloseSession: onCloseSession,
        onCloseAllAndWipe: onCloseAllAndWipe,
        onPanic: onPanic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            ContainerTopBar(
              host: host,
              routeLabel: routeLabel,
              live: live,
              onBack: onBack,
              onReload: onReload,
              onPanic: onPanic,
            ),
            Expanded(child: body),
            ContainerToolbar(
              openCount: openCount,
              onReaderMode: onReaderMode,
              onFilters: onFilters,
              onMenu: onMenu,
              onMore: onMore,
              onOpenSwitcher: () => _openSwitcher(context),
            ),
          ],
        ),
      ),
    );
  }
}
