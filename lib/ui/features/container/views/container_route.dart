import 'dart:async';

import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../data/services/container_engine.dart';
import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/find_result.dart';
import '../../../../domain/models/held_download.dart' show DownloadDecision;
import '../../../../domain/models/monogram_suggestion.dart';
import '../../../../domain/models/route_display.dart';
import '../../../../domain/models/open_container.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/relative_age.dart';
import '../../../../domain/models/route_decision.dart' show refusalMessage;
import '../../../../domain/models/permissions.dart' show PermissionDecision;
import '../../../../domain/models/permissions_in_use.dart';
import '../../../../domain/models/proxy_route.dart';
import '../../../../domain/models/search_engine.dart';
import '../../../../domain/models/security_level.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/throwaway.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../domain/tabs.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../dashboard/view_models/blocked_tally_controller.dart' show blockedTallyProvider;
import '../../dashboard/view_models/providers.dart'
    show openSite, siteRepositoryProvider, workspacesProvider;
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_route.dart';
import '../../in_page/views/site_sheet.dart';
import '../../in_page/views/tunnel_dropped_screen.dart';
import '../../report/views/today_route.dart';
import '../../scripts/views/scripts_route.dart';
import '../../search/view_models/providers.dart' show allSitesProvider, sitesChangedIn;
import '../../settings/view_models/providers.dart'
    show searchEngineProvider, vaultSecurityLevelProvider;
import '../../settings/views/security_level_picker.dart';
import '../../settings/views/settings_route.dart';
import '../../workspaces/views/workspaces_route.dart';
import '../view_models/open_containers.dart';
import '../view_models/providers.dart';
import 'container_screen.dart';
import 'container_web_view.dart';
import 'new_identity_sheet.dart';
import 'opening_screen.dart';

/// The host route on the open vault's navigator, while it is up.
final _hostRouteProvider = Provider<_HostRoute>((ref) => _HostRoute());

class _HostRoute {
  Route<Object?>? route;
}

/// Shows [site]'s container (tabs spec §4.2): every opener — a dashboard row,
/// a search result, the address bar — comes through here. The registry is
/// told first, synchronously; then the one host route is shown: popped back
/// to if it is on the stack, pushed over the dashboard if not. Anything above
/// it goes. Never the root navigator.
///
/// An open container is shown as it is, on its last viewed page, with no
/// second `open`; with [initialUrl] that page loads it (§5.5). A [throwaway]
/// records [openerSiteId], the container it was typed in, for back (§5.3).
void showContainer(
  BuildContext context,
  WidgetRef ref,
  Site site, {
  String? initialUrl,
  bool throwaway = false,
  String? openerSiteId,
}) {
  unawaited(ref.read(openContainersProvider.notifier).view(site,
      initialUrl: initialUrl, throwaway: throwaway, openerSiteId: openerSiteId));
  final host = ref.read(_hostRouteProvider).route;
  final navigator = Navigator.of(context);
  if (host != null && host.isActive) {
    navigator.popUntil((route) => route == host);
  } else {
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const ContainerRoute()));
  }
}

/// The one container host route (tabs spec §4.2), directly above the
/// dashboard on the open vault's navigator. It has no site of its own: it
/// shows whichever container and page `openContainersProvider` says is
/// viewed, with `8a`, `8b` and `8c` for that container. Switching container
/// or page swaps what it shows, with no push or pop.
///
/// The `opening -> live -> refused` lifecycle lives in the registry, not
/// here, so it survives this route going away while the container stays
/// open. Only a container being closed removes this route by itself; leaving
/// for the dashboard pops it explicitly.
class ContainerRoute extends ConsumerStatefulWidget {
  const ContainerRoute({super.key});

  @override
  ConsumerState<ContainerRoute> createState() => _ContainerRouteState();
}

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;
  late final _HostRoute _hostRoute;

  /// The scope's container, for work that can finish after this route is
  /// gone: a close removes it while the wipe is still writing the row.
  late final ProviderContainer _providers;
  Route<Object?>? _ownRoute;

  /// The viewed page's count for what the find bar holds; null until it
  /// reports.
  FindResult? _findResult;
  StreamSubscription<DownloadResult>? _downloadResultSub;
  StreamSubscription<FindResult>? _findSub;
  final _myDownloadRequestIds = <String>{};

  /// A waiting ask's sheet is open (tabs spec §5.6): one at a time.
  bool _askShowing = false;
  bool _askCheckScheduled = false;

  OpenContainers get _registry => _providers.read(openContainersProvider.notifier);
  OpenContainersState get _state => _providers.read(openContainersProvider);

  @override
  void initState() {
    super.initState();
    _engine = ref.read(containerEngineProvider);
    _hostRoute = ref.read(_hostRouteProvider);
    _providers = ProviderScope.containerOf(context, listen: false);
    _downloadResultSub = _engine
        .downloadResults()
        .where((r) => _myDownloadRequestIds.contains(r.requestId))
        .listen(_showDownloadResult);
    _findSub = _engine.findResults().listen((result) {
      if (!mounted || result.pageId != _state.viewed?.viewedPageId) return;
      setState(() => _findResult = result);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _ownRoute) {
      _ownRoute = route;
      _hostRoute.route = route;
    }
  }

  @override
  void dispose() {
    if (_hostRoute.route == _ownRoute) _hostRoute.route = null;
    _downloadResultSub?.cancel();
    _findSub?.cancel();
    super.dispose();
  }

  /// Every change of the registry, while this route is up.
  void _onRegistryChanged(OpenContainersState? previous, OpenContainersState next) {
    // Only a closed container removes this route by itself (tabs plan, Task
    // 7 Step 4): closed from 2c, 6c, 8c, the checklist, a throwaway's last
    // back, or anywhere else, including a screen above this one.
    // `showDashboard` keeps the container, and its callers pop explicitly.
    final was = previous?.viewedSiteId;
    if (was != null && next.viewedSiteId == null && next.byId(was) == null) _removeSelf();

    // A find count belongs to the page it was found in.
    if (previous?.viewed?.viewedPageId != next.viewed?.viewedPageId && _findResult != null) {
      setState(() => _findResult = null);
    }
  }

  /// After this frame, unless something was viewed again meanwhile.
  void _removeSelf() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = _ownRoute;
      if (!mounted || route == null || !route.isActive) return;
      if (_state.viewedSiteId != null) return;
      Navigator.of(context).removeRoute(route);
    });
  }

  /// Tabs spec §5.6: an ask waits on its container until its page is viewed,
  /// then shows, one at a time, oldest first — and only while this route is
  /// on top, so it never lands over Settings, a form or another sheet.
  void _scheduleAskCheck() {
    if (_askCheckScheduled || _askShowing) return;
    _askCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askCheckScheduled = false;
      _showWaitingAsk();
    });
  }

  void _showWaitingAsk() {
    if (!mounted || _askShowing || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final viewed = _state.viewed;
    final pageId = viewed?.viewedPageId;
    if (viewed == null || pageId == null || !viewed.openReturned || viewed.refusal != null) {
      return;
    }
    final ask = _registry.takeWaiting(viewed.siteId, pageId);
    if (ask == null) return;
    _askShowing = true;
    final shown = switch (ask) {
      WaitingPermission(:final request) => _showPermissionSheet(request),
      WaitingDownload(:final event) => _showDownloadSheet(event),
    };
    shown.whenComplete(() {
      _askShowing = false;
      if (mounted) _scheduleAskCheck();
    });
  }

  /// A sheet that leaves without a decision (back, a drag down, or its route
  /// going) is answered "keep blocked", so the native ask never hangs.
  Future<void> _showPermissionSheet(PendingPermissionRequest request) async {
    final engine = _engine;
    var decided = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      // Kept below the status bar on a short screen or in landscape.
      useSafeArea: true,
      builder: (sheetContext) => PermissionRequestSheet(
        host: request.host,
        kind: request.kind,
        onDecision: (decision) {
          if (decided) return;
          decided = true;
          Navigator.pop(sheetContext);
          engine.resolvePermission(request.requestId, decision);
        },
      ),
    );
    if (!decided) {
      decided = true;
      engine.resolvePermission(request.requestId, PermissionDecision.keepBlocked);
    }
  }

  /// A sheet dismissed without a decision discards the held download, so it
  /// is never left waiting natively.
  Future<void> _showDownloadSheet(HeldDownloadEvent event) async {
    final engine = _engine;
    _myDownloadRequestIds.add(event.requestId);
    var decided = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Kept below the status bar on a short screen or in landscape.
      useSafeArea: true,
      builder: (sheetContext) => HeldDownloadSheet(
        download: event.download,
        onDecision: (decision) {
          if (decided) return;
          decided = true;
          Navigator.pop(sheetContext);
          engine.resolveDownload(event.requestId, decision);
        },
      ),
    );
    if (!decided) {
      decided = true;
      engine.resolveDownload(event.requestId, DownloadDecision.discard);
    }
  }

  /// Shown only while this route is up, as before tabs.
  void _showDownloadResult(DownloadResult result) {
    if (!mounted) return;
    final message = switch (result.outcome) {
      DownloadOutcome.saved => 'Saved to Downloads',
      DownloadOutcome.kept => 'Kept in this container',
      DownloadOutcome.failed => result.reason != null
          ? refusalMessage(result.reason!)
          : 'Download failed',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// `6c`, the per-site shield panel (privacy-controls spec §3). It reads
  /// the container from the registry each time it builds, so its counts and
  /// grants are live. Every switch, and the level, applies at once (spec
  /// §2.4): a saved site's change is written, a throwaway's is kept only in
  /// the registry (browser-chrome spec §5.1), then the container reopens in
  /// place at the page it shows. The sheet closes first, since its session
  /// is about to be replaced.
  Future<void> _showSiteSheet() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final start = _state.viewed;
    if (start == null) return;
    final registry = _registry;
    final engine = _engine;
    final sites = ref.read(siteRepositoryProvider);
    final siteId = start.siteId;
    String? workspaceName;
    for (final workspace in workspaces) {
      if (workspace.id == start.site.workspaceId) workspaceName = workspace.name;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // `6c` scrolls, and may be taller than the default 9/16 of the screen.
      isScrollControlled: true,
      // Kept below the status bar on a short screen or in landscape.
      useSafeArea: true,
      builder: (sheetContext) => Consumer(
        builder: (_, ref, __) {
          final now = ref.watch(openContainersProvider).byId(siteId);
          // The container went while the sheet was up.
          if (now == null) return const SizedBox.shrink();
          final vaultDefault =
              ref.watch(vaultSecurityLevelProvider).valueOrNull ?? SecurityLevel.standard;
          final throwaway = now.throwaway;
          final site = now.site;

          // Every switch applies at once (privacy-controls spec §2.4): the
          // row is written, a throwaway only in the registry, then the
          // container reopens in place. This replaces tabs spec §5.7's "the
          // 6c switches never close anything".
          Future<void> save(Site updated) async {
            Navigator.pop(sheetContext);
            if (!throwaway) {
              await sites.upsert(updated);
              sitesChangedIn(_providers);
            }
            await registry.reopenInPlace(updated);
          }

          final host = site.host;
          return SiteSheet(
            monogram: site.monogram,
            name: site.name,
            // A throwaway belongs to no workspace until it is saved.
            subtitle: throwaway || workspaceName == null ? host : '$host · $workspaceName',
            proxyDescriptor: proxyDescriptor(site),
            cookiesDescriptor: switch (site.cookiePolicy) {
              CookiePolicy.keep => 'Keep for this site',
              CookiePolicy.wipeOnExit => 'Wipe on exit',
            },
            blockedCount: now.blockedCount,
            forceDark: site.forceDark,
            desktopView: site.userAgentMode == UserAgentMode.desktop,
            // Editing a throwaway means saving it.
            onEdit: () {
              Navigator.pop(sheetContext);
              if (throwaway) {
                _saveAsSite();
              } else {
                _editSite();
              }
            },
            onProxy: () {
              Navigator.pop(sheetContext);
              if (throwaway) {
                // A throwaway has no form of its own: as `8b`'s, it is saved
                // as a site.
                _changeProxySettings();
              } else {
                _changeRoute();
              }
            },
            onForceDarkChanged: (value) => save(site.copyWith(forceDark: value)),
            // The switch is binary, so turning it off lands on `android` — a
            // site that was `minimal` loses that once desktop view is flipped.
            onDesktopViewChanged: (value) => save(site.copyWith(
              userAgentMode: value ? UserAgentMode.desktop : UserAgentMode.android,
            )),
            // The container goes, so this route goes with it.
            onCloseAndWipe: () {
              Navigator.pop(sheetContext);
              unawaited(_closeAndWipe(siteId));
            },
            securityLevelValue: securityLevelValue(site, vaultDefault),
            onSecurityLevel: () {
              Navigator.pop(sheetContext);
              _pickSecurityLevel(siteId);
            },
            categoryCounts: now.categoryCounts,
            blockWebRtc: site.blockWebRtc || webRtcLocked(site.proxyMode),
            blockTrackers: site.blockTrackers,
            antiFingerprinting: site.antiFingerprinting,
            // Built-in Tor spec §5.4: always on for Tor, and inert.
            onBlockWebRtcChanged: webRtcLocked(site.proxyMode)
                ? null
                : (v) => save(site.copyWith(blockWebRtc: v)),
            onBlockTrackersChanged: (v) => save(site.copyWith(blockTrackers: v)),
            onAntiFingerprintingChanged: (v) => save(site.copyWith(antiFingerprinting: v)),
            permissions: permissionsInUse(site, now.grants),
            // Reloads every page of the container natively; the new session
            // list takes the row away.
            onRevoke: (kind) => engine.revokeGrant(siteId, kind),
          );
        },
      ),
    );
  }

  /// The site picker (privacy-controls spec §2.3), from `6c` and ☰:
  /// `Default` follows the vault default. A new choice is written (a
  /// throwaway's only in the registry) and the container reopens in place
  /// (§2.4).
  Future<void> _pickSecurityLevel(String siteId) async {
    final container = _state.byId(siteId);
    if (container == null) return;
    final vaultDefault = await ref.read(vaultSecurityLevelProvider.future);
    if (!mounted) return;
    final registry = _registry;
    final sites = ref.read(siteRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SecurityLevelPicker.site(
        current: container.site.securityLevel,
        vaultDefault: vaultDefault,
        onPick: (level) async {
          Navigator.pop(sheetContext);
          if (level == container.site.securityLevel) return;
          final updated = container.site.withSecurityLevel(level);
          if (!container.throwaway) {
            await sites.upsert(updated);
            sitesChangedIn(_providers);
          }
          await registry.reopenInPlace(updated);
        },
      ),
    );
  }

  /// `8c`'s Reconnect: the overlay goes, and the page shown reloads (user's
  /// ruling 2026-10-05), so it does not stay on what the dropped tunnel left
  /// it showing, such as Chromium's error page.
  ///
  /// On a Tor site it restarts Tor (user's ruling 2026-10-09): only an open
  /// starts Tor, and a Tor that died under the page does not come back for a
  /// reload, so the container reopens in place, unwiped, at the page shown,
  /// through `8a`'s "Connecting to Tor".
  void _reconnect(String siteId) {
    _registry.clearTunnelDropped(siteId);
    final container = _state.byId(siteId);
    if (container == null) return;
    if (_routeSite(container).proxyMode == ProxyMode.tor) {
      unawaited(_registry.reopenInPlace(container.site));
      return;
    }
    final pageId = container.viewedPageId;
    if (pageId != null) unawaited(_engine.reload(pageId));
  }

  /// `6c`'s Proxy row on a saved site (user's ruling 2026-10-05): the site's
  /// form, on its Network tab. A new route reopens the container in place at
  /// the page it shows, on that route and unwiped, as `6c`'s switches do. A
  /// changed cookie policy goes through [OpenContainers.siteSaved] as Edit's
  /// does, since moving to wipe on exit rotates the profile; anything else
  /// waits for the next open.
  Future<void> _changeRoute() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final viewed = _state.viewed;
    if (viewed == null || viewed.throwaway) return;
    final registry = _registry;
    final sites = ref.read(siteRepositoryProvider);
    final before = viewed.opened;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (formContext) => AddSiteScreen(
        initial: viewed.site,
        workspaces: workspaces,
        initialTab: 1,
        rulesMatchedToday: ref.read(blockedTallyProvider).rulesMatched(viewed.siteId),
        onSave: (updated) async {
          await sites.upsert(updated);
          sitesChangedIn(_providers);
          if (formContext.mounted) Navigator.pop(formContext);
          if (updated.cookiePolicy == before.cookiePolicy &&
              ProxyRoute.of(updated) != ProxyRoute.of(before)) {
            await registry.reopenInPlace(updated);
          } else {
            await registry.siteSaved(updated);
          }
        },
      ),
    ));
  }

  /// `8b`'s "Change proxy settings": the site's form, on its Network tab.
  /// Saving writes the site — or saves a throwaway as one, as Edit does — and
  /// opens it again in place, as saved. Leaving the form without saving comes
  /// back to `8b`.
  Future<void> _changeProxySettings() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final viewed = _state.viewed;
    if (viewed == null) return;
    final registry = _registry;
    final sites = ref.read(siteRepositoryProvider);
    final siteId = viewed.siteId;
    final throwaway = viewed.throwaway;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (formContext) => AddSiteScreen(
        initial: throwaway ? _throwawayAsSite(viewed) : viewed.site,
        workspaces: workspaces,
        initialTab: 1,
        savesAsNew: throwaway,
        rulesMatchedToday:
            throwaway ? null : ref.read(blockedTallyProvider).rulesMatched(siteId),
        onSave: (updated) async {
          var reopened = false;
          if (throwaway) {
            // `saveThrowaway` → `siteSaved` reopens a saved throwaway itself
            // when it is still listed as a site (no refusal) and its route
            // changed, maybe on a rotated profile: a second reopen here would
            // replace that open. Mirrors that decision, so it opens once.
            final now = _state.byId(siteId);
            reopened = now != null &&
                now.refusal == null &&
                routeOrCookiePolicyChanged(
                    now.opened.copyWith(cookiePolicy: updated.cookiePolicy), updated);
            await _keepAsSite(updated);
          } else {
            await sites.upsert(updated);
            sitesChangedIn(_providers);
          }
          if (formContext.mounted) Navigator.pop(formContext);
          if (!reopened) await registry.reopen(siteId, updated);
        },
      ),
    ));
  }

  /// `6c`'s Edit. Saved, a change of route or cookie policy closes the
  /// container and the viewed one reopens in place (tabs spec §5.7); any
  /// other change waits for the next open.
  Future<void> _editSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final viewed = _state.viewed;
    if (viewed == null) return;
    final registry = _registry;
    final sites = ref.read(siteRepositoryProvider);
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (formContext) => AddSiteScreen(
        initial: viewed.site,
        workspaces: workspaces,
        rulesMatchedToday: ref.read(blockedTallyProvider).rulesMatched(viewed.siteId),
        onSave: (updated) async {
          await sites.upsert(updated);
          await registry.siteSaved(updated);
          sitesChangedIn(_providers);
          if (formContext.mounted) Navigator.pop(formContext);
        },
      ),
    ));
  }

  /// Spec §5.3. The form opens on the throwaway as it is now — the page it is
  /// showing, cookies kept — and keeps its id and profile id, so the saved
  /// site is this same container. The row is written first, then the native
  /// profile is kept: without `keep`, closing the container would wipe the
  /// login just saved. Picking "Wipe on exit" in the form skips `keep`. A
  /// route changed in the form reopens it in place (tabs spec §5.7); anything
  /// else applies the next time the site opens.
  Future<void> _saveAsSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final viewed = _state.viewed;
    if (viewed == null) return;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (formContext) => AddSiteScreen(
        initial: _throwawayAsSite(viewed),
        workspaces: workspaces,
        savesAsNew: true,
        onSave: (site) async {
          await _keepAsSite(site);
          if (formContext.mounted) Navigator.pop(formContext);
        },
      ),
    ));
  }

  /// What the form for saving this throwaway opens on: the page it is
  /// showing, cookies kept.
  Site _throwawayAsSite(OpenContainer viewed) {
    final pageId = viewed.viewedPageId;
    final url = (pageId == null ? null : _state.navigation[pageId]?.url) ?? _openedUrl(viewed);
    // A throwaway that has moved to another site is saved as that site, not
    // under the name of the address it started at.
    final host = Uri.tryParse(url)?.host ?? '';
    final site = viewed.site;
    final moved = host.isNotEmpty &&
        normalizeHost(host) != normalizeHost(Uri.tryParse(site.url)?.host ?? '');
    return site.copyWith(
      url: url,
      name: moved ? host : site.name,
      monogram: moved ? suggestMonogram(host) : site.monogram,
      cookiePolicy: CookiePolicy.keep,
    );
  }

  /// A throwaway saved as [site]: the row first, then its profile kept, then
  /// the registry told it is a site now.
  Future<void> _keepAsSite(Site site) async {
    final registry = _registry;
    await _providers.read(siteRepositoryProvider).upsert(site);
    if (site.cookiePolicy != CookiePolicy.wipeOnExit) await _engine.keep(site.id);
    await registry.saveThrowaway(site);
    sitesChangedIn(_providers);
  }

  /// `6c`'s "Close and wipe this session" and `8c`'s "Close and wipe": the
  /// container is closed and its data destroyed. A saved site keeps its row
  /// under a fresh profile (`wipeSavedSite`); a throwaway, whose profile is
  /// journaled from before it exists, is closed with its wipe. The container
  /// goes, so the registry's change removes this route.
  Future<void> _closeAndWipe(String siteId) async {
    await _registry.closeAndWipe(siteId);
    sitesChangedIn(_providers);
  }

  /// ☰'s New identity (privacy-controls spec §4), after its confirm sheet.
  /// It runs after the menu has closed itself. Cancel does nothing.
  Future<void> _newIdentity() async {
    final viewed = _state.viewed;
    if (viewed == null) return;
    final registry = _registry;
    if (!await confirmNewIdentity(context)) return;
    await registry.newIdentity(viewed.siteId);
    sitesChangedIn(_providers);
  }

  Future<void> _openReader(String pageId) async {
    final article = await _engine.extractArticle(pageId);
    if (article == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (readerContext) => ReaderRoute(
        article: article,
        onClose: () => Navigator.pop(readerContext),
      ),
    ));
  }

  /// Find in page (spec §6.5). The count shown is dropped until the page
  /// reports the new text's, so it is never the old text's.
  void _find(String pageId, String query) {
    setState(() => _findResult = null);
    if (query.isEmpty) {
      _engine.clearFind(pageId);
    } else {
      _engine.find(pageId, query);
    }
  }

  void _clearFind(String pageId) {
    setState(() => _findResult = null);
    _engine.clearFind(pageId);
  }

  /// Spec §3.3: the page's own address, through Flutter's clipboard. The
  /// site's `allowClipboard` governs page scripts, not this user action.
  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  /// A ☰ shortcut (spec §6.4), pushed on the open vault's navigator above
  /// this container.
  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// To the dashboard (tabs spec §4.2): every container stays open, its pages
  /// paused. This route is popped here, since the registry keeps the
  /// container.
  void _toDashboard() {
    _registry.showDashboard();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// System back with no history in the page (tabs spec §5.3).
  void _leave() {
    final state = _state;
    final viewed = state.viewed;
    final pageId = viewed?.viewedPageId;
    if (viewed == null || pageId == null) return;
    final others = {
      for (final c in state.listed)
        if (c.siteId != viewed.siteId) c.siteId: c.lastViewedAt,
    };
    switch (backTarget(canGoBack: false, container: viewed, pageId: pageId, others: others)) {
      case BackInPage():
        unawaited(_engine.goBack(pageId));
      case ClosePageToOpener(:final openerPageId):
        unawaited(_registry.closePage(viewed.siteId, pageId));
        _registry.viewPage(viewed.siteId, openerPageId);
      case LeaveToDashboard():
        _toDashboard();
      case ViewContainer(:final siteId):
        _viewContainer(siteId);
      case CloseThrowawayToDashboard():
        // The container goes, so the registry's change removes this route.
        unawaited(_registry.close(viewed.siteId));
    }
  }

  /// An open container, on its last viewed page: nothing reloads.
  void _viewContainer(String siteId) {
    final container = _state.byId(siteId);
    if (container != null) unawaited(_registry.view(container.site));
  }

  /// The ☰ header's mono line (spec §6.4): `host · Workspace`, or the host
  /// alone for a throwaway, which belongs to no workspace until saved.
  String _menuSubtitle(OpenContainer viewed, List<Workspace> workspaces) {
    final host = viewed.site.host;
    if (viewed.throwaway) return host;
    final name = _workspaceName(workspaces, viewed.site.workspaceId);
    return name == null ? host : '$host · $name';
  }

  /// The site whose route this container stands for, which a throwaway typed
  /// here inherits: the site as opened, or, on a direct visit, as saved — the
  /// user chose to go without the tunnel for this site only.
  Site _routeSite(OpenContainer viewed) => viewed.withoutTunnel ? viewed.site : viewed.opened;

  /// Spec §5.2 and tabs spec §5.5: where a typed address or search opens.
  /// This container's own host loads in the viewed page. A saved site's
  /// container is shown — switched to, if it is open, loading the address in
  /// its last viewed page — and its stored address never changes. Anything
  /// else opens a throwaway whose opener container is this one.
  ///
  /// [suggested] was decided from the address bar's copy of the vault's
  /// sites, which can be out of date. So it is decided again here against the
  /// vault as it is now, and a saved site opens with its current route and
  /// profile: never one removed since, nor the profile a wipe rotated away.
  Future<void> _openDestination(Destination suggested) async {
    final saved = await ref.read(siteRepositoryProvider).all();
    if (!mounted) return;
    final viewed = _state.viewed;
    if (viewed == null) return;
    final destination = destinationFor(suggested.url, current: _routeSite(viewed), saved: saved);
    switch (destination) {
      case ThisContainer(:final url):
        final pageId = viewed.viewedPageId;
        if (pageId != null) await _engine.loadUrl(pageId, url.toString());
      case SavedSiteContainer(:final site, :final url):
        // As the dashboard and search open a site: the visit recorded. Its
        // stored address is not touched.
        openSite(ref, site.id);
        showContainer(context, ref, site, initialUrl: url.toString());
      case final Throwaway target:
        final throwaway = buildThrowaway(
          destination: target,
          workspaceId: _routeSite(viewed).workspaceId,
          newId: newProfileId,
        );
        showContainer(context, ref, throwaway, throwaway: true, openerSiteId: viewed.siteId);
    }
  }

  /// `8b`'s three ways out: the site opened again in place, as a fresh open.
  void _reopen(OpenContainer viewed, Site site, {bool withoutTunnel = false}) {
    unawaited(_registry.reopen(viewed.siteId, site, withoutTunnel: withoutTunnel));
  }

  /// A refused open: spec `8b`, shown in place of the container. A saved
  /// site's dead session is closed by the registry, and a refused saved
  /// container is not listed, so its green rail goes (tabs spec §5.6). A
  /// throwaway's stays until it is closed, since `8b` can still save it as a
  /// site.
  Widget _refusalScreen(OpenContainer viewed, Refusal refusal) {
    final opened = viewed.opened;
    return ProxyUnreachableScreen(
      host: opened.host,
      siteName: opened.name,
      failure: refusal.failure,
      tunnelDescriptor: tunnelDescriptor(opened),
      lastWorkedLabel: lastWorkedLabel(DateTime.now(), refusal.lastWorked),
      // Through the tunnel again, as the site is saved now.
      onTryAgain: () => _reopen(viewed, viewed.site),
      onChangeProxySettings: _changeProxySettings,
      // Built-in Tor spec §5.6: an onion address cannot go direct.
      onOpenWithoutTunnel: canOpenWithoutTunnel(opened)
          ? () => _reopen(viewed, viewed.site.withoutProxy(), withoutTunnel: true)
          : null,
    );
  }

  /// The checklist's Cancel: the container is closed (a throwaway wiped),
  /// and the registry's change removes this route.
  void _cancelOpening(OpenContainer viewed) {
    unawaited(_registry.close(viewed.siteId));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(openContainersProvider);
    ref.listen<OpenContainersState>(openContainersProvider, _onRegistryChanged);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];
    final blockedToday = ref.watch(blockedTallyProvider.select((tally) => tally.total));
    // What typed text is matched against (spec §4.4): this vault's sites and
    // search engine, watched from the start so the first keystroke has them.
    final saved = ref.watch(allSitesProvider).valueOrNull ?? const <Site>[];
    final searchEngine =
        ref.watch(searchEngineProvider).valueOrNull ?? SearchEngine.duckDuckGo;
    // Built-in Tor spec §7: `8a` shows Tor's own percentage while it starts.
    final torPercent = ref.watch(torProgressProvider).valueOrNull;

    final viewed = state.viewed;
    if (viewed == null) return const SizedBox.shrink();
    final siteId = viewed.siteId;
    final opened = viewed.opened;
    final refusal = viewed.refusal;
    if (refusal != null) return _refusalScreen(viewed, refusal);

    // Until this container's own `open` returns, any session the site has
    // natively is a previous visit's, registered with the settings it had
    // then: no page view is built for it (Plan 12's `_openReturned` rule). A
    // routable open always returns its first page; a refused one has none
    // while its `8b` is being decided.
    final pageId = viewed.viewedPageId;
    if (!viewed.openReturned || pageId == null) {
      return OpeningBody(
        host: opened.host,
        steps: openStepsFor(opened, torPercent: torPercent, applied: viewed.openReturned),
        progress: 0.6,
        onCancel: () => _cancelOpening(viewed),
      );
    }
    _scheduleAskCheck();

    final navigation = state.navigation[pageId];
    final pageHost = navigation?.host ?? '';
    final openedUrl = _openedUrl(viewed);
    final neighbours = swipeNeighbours(state.containers, siteId);
    final level = effectiveLevel(
      viewed.site,
      ref.watch(vaultSecurityLevelProvider).valueOrNull ?? SecurityLevel.standard,
    );
    final previous = neighbours.previous;
    final next = neighbours.next;
    // The pill draws this as a shape, and names it beside the route (user's
    // ruling 2026-10-08).
    final caseKind = viewed.throwaway
        ? CaseKind.throwaway
        : opened.cookiePolicy == CookiePolicy.wipeOnExit
            ? CaseKind.wipe
            : CaseKind.keep;
    return Stack(children: [
      ContainerScreen(
        // Dashboard spec §9: switched in place, as a tap on a `2c` row is.
        onPreviousContainer: previous == null ? null : () => _viewContainer(previous),
        onNextContainer: next == null ? null : () => _viewContainer(next),
        // The page's host once it reports one; the site's before that, and
        // whenever the page has none (`about:blank`, a failed load).
        host: pageHost.isEmpty ? opened.host : pageHost,
        // There is no DIRECT label (spec §4.4).
        routeLabel: topBarRouteLabel(opened.proxyMode, caseKind),
        live: viewed.phase == SessionPhase.live,
        navigation: navigation,
        openCount: state.openCount,
        // Keyed by its page: another page is another platform view, which
        // only detaches one WebView and attaches the other.
        body: PageView(key: ValueKey(pageId), pageId: pageId),
        entries: switcherEntries(
          containers: state.containers,
          viewedSiteId: siteId,
          navigation: state.navigation,
          now: ref.read(tabsClockProvider)(),
        ),
        // `SwitcherSheet` puts it in capitals.
        workspaceName: viewed.throwaway
            ? ''
            : _workspaceName(workspaces, viewed.site.workspaceId) ?? '',
        siteMonogram: viewed.site.monogram,
        siteName: viewed.site.name,
        siteSubtitle: _menuSubtitle(viewed, workspaces),
        blockedToday: blockedToday,
        // Display only: the level the engine runs at is resolved at open.
        securityLevelMeta: level.meta,
        // Restyle v2 §8 `2b`: the pill's case and shield, from what the
        // container already holds.
        caseKind: caseKind,
        tor: opened.proxyMode == ProxyMode.tor,
        securityLevel: level,
        findResult: _findResult,
        showSaveBar: viewed.throwaway && viewed.loadedOnce && !viewed.saveBarDismissed,
        address: navigation?.url ?? openedUrl,
        // `current` is the site this container was opened for: its host is
        // "this container", its route the one a throwaway inherits.
        suggest: (text) => suggestionsFor(
          text: text,
          current: _routeSite(viewed),
          saved: saved,
          workspaces: workspaces,
          engine: searchEngine,
        ),
        onOpen: _openDestination,
        onBack: () => _engine.goBack(pageId),
        onLeave: _leave,
        onForward: () => _engine.goForward(pageId),
        onStop: () => _engine.stop(pageId),
        onReload: () => _engine.reload(pageId),
        onPanic: () => panic(ref),
        onSiteDetails: _showSiteSheet,
        onReader: () => _openReader(pageId),
        onCopyLink: () => _copyLink(navigation?.url ?? openedUrl),
        onToday: () => _push(const TodayRoute()),
        onScripts: () => _push(const ScriptsRoute()),
        onWorkspaces: () => _push(const WorkspacesRoute()),
        onSettings: () => _push(const SettingsRoute()),
        // Tabs spec §4.2: to the dashboard, closing nothing on the way.
        onAllSites: _toDashboard,
        onSecurityLevel: () => _pickSecurityLevel(siteId),
        onNewIdentity: _newIdentity,
        onFind: (query) => _find(pageId, query),
        onFindNext: (forward) => _engine.findNext(pageId, forward: forward),
        onClearFind: () => _clearFind(pageId),
        onSaveAsSite: _saveAsSite,
        onDismissSaveBar: () => _registry.dismissSaveBar(siteId),
        // The switcher has already closed itself by now (tabs spec §5.1).
        onViewContainer: _viewContainer,
        onViewPage: (container, page) => _registry.viewPage(container, page),
        onClosePage: (container, page) => unawaited(_registry.closePage(container, page)),
        // Closing the viewed container lands on the dashboard: the
        // registry's change removes this route.
        onCloseSession: (container) => unawaited(_registry.close(container)),
        onCloseAllAndWipe: () async {
          await _registry.closeAllAndWipe();
          sitesChangedIn(_providers);
        },
      ),
      if (viewed.tunnelDropped)
        TunnelDroppedScreen(
          host: opened.host,
          droppedAgoLabel: 'just now',
          onReconnect: () => _reconnect(siteId),
          onCloseAndWipe: () => _closeAndWipe(siteId),
        ),
      // The checklist covers the page rather than replacing it. The native
      // page only reports `live` once its first load finishes, and it is only
      // attached once PageView above is built — so the page must be building
      // underneath while this shows. Keeping ContainerScreen at the same
      // position in this Stack is what lets going live remove the overlay
      // without rebuilding the view (a rebuild detaches and reattaches it).
      if (viewed.phase == SessionPhase.opening)
        Positioned.fill(
          child: OpeningBody(
            host: opened.host,
            steps: openStepsFor(opened, torPercent: torPercent, applied: true),
            progress: 0.6,
            onCancel: () => _cancelOpening(viewed),
          ),
        ),
    ]);
  }
}

/// What a container opened: the typed address, or the stored one.
String _openedUrl(OpenContainer container) => container.initialUrl ?? container.opened.url;

String? _workspaceName(List<Workspace> workspaces, String workspaceId) {
  for (final workspace in workspaces) {
    if (workspace.id == workspaceId) return workspace.name;
  }
  return null;
}
