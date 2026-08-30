import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import '../views/workspace_menu.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => Stack(
        children: [
          DashboardBody(
            view: view,
            onWorkspaceTap: () => setState(() => _menuOpen = !_menuOpen),
            // The screens behind these callbacks arrive in later plans.
            onAddSite: () {},
            onSearch: () {},
            onOpenSite: (siteId) {
              ref.read(openSiteIdsProvider.notifier).update((ids) => {...ids, siteId});
              ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
              ref.invalidate(dashboardProvider);
            },
            onSiteMenu: (_) {},
          ),
          if (_menuOpen) _menu(),
        ],
      ),
    );
  }

  Widget _menu() {
    final options = ref.watch(workspaceOptionsProvider);
    return SafeArea(
      child: Padding(
        // Sits directly under the 47px-tall workspace bar.
        padding: const EdgeInsets.only(top: 47),
        child: Align(
          alignment: Alignment.topCenter,
          child: options.maybeWhen(
            data: (options) => WorkspaceMenu(
              options: options,
              onPick: (id) {
                ref.read(activeWorkspaceIdProvider.notifier).state = id;
                setState(() => _menuOpen = false);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
