import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../report/views/today_route.dart';
import '../../settings/views/settings_route.dart';
import 'dashboard_tab_bar.dart';
import 'sites_tab.dart';

/// The open vault's first screen (dashboard spec §4): Sites, Today and
/// Settings under a bottom tab bar. The bar belongs to the dashboard only:
/// anything pushed (a container, a form, a screen opened from a tab) covers
/// it.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Not remembered: every unlock builds this screen anew, on Sites (§4.1).
  DashboardTab _tab = DashboardTab.sites;

  @override
  Widget build(BuildContext context) {
    // Plan D4: while the keyboard is up the bar steps aside, so the search
    // field sits on the keyboard.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      // §4.1: back on Today or Settings shows Sites. On Sites it does what it
      // always did.
      canPop: _tab == DashboardTab.sites,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != DashboardTab.sites) setState(() => _tab = DashboardTab.sites);
      },
      // A Material, not a ColoredBox: the tab bar sits outside every tab's
      // Scaffold, and text with no Material above it is drawn in
      // MaterialApp's error style (a yellow double underline).
      child: Material(
        color: C.bg,
        child: Column(
          children: [
            Expanded(
              // The same widget whether or not the keyboard is up, so a tab
              // keeps its state (the search field's text) as it comes and goes.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: !keyboardUp,
                child: switch (_tab) {
                  DashboardTab.sites => const SitesTab(),
                  DashboardTab.today => const TodayRoute(showBack: false),
                  DashboardTab.settings => const SettingsRoute(showBack: false),
                },
              ),
            ),
            if (!keyboardUp)
              DashboardTabBar(current: _tab, onSelect: (tab) => setState(() => _tab = tab)),
          ],
        ),
      ),
    );
  }
}
