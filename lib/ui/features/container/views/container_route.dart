import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../data/services/container_engine.dart';
import '../../../../data/services/site_wipe.dart';
import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/find_result.dart';
import '../../../../domain/models/monogram_suggestion.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/route_failure_copy.dart';
import '../../../../domain/models/route_decision.dart' show refusalMessage;
import '../../../../domain/models/search_engine.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/throwaway.dart';
import '../../../../domain/models/workspace.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../dashboard/view_models/providers.dart'
    show
        closeSite,
        leakCountProvider,
        openSite,
        siteRepositoryProvider,
        workspacesProvider;
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_route.dart';
import '../../in_page/views/site_sheet.dart';
import '../../in_page/views/tunnel_dropped_screen.dart';
import '../../report/views/today_route.dart';
import '../../scripts/views/scripts_route.dart';
import '../../search/view_models/providers.dart' show allSitesProvider, sitesChanged;
import '../../settings/view_models/providers.dart' show searchEngineProvider;
import '../../settings/views/settings_route.dart';
import '../../workspaces/views/workspaces_route.dart';
import '../view_models/providers.dart';
import '../view_models/throwaway_sites.dart';
import 'container_screen.dart';
import 'container_web_view.dart';
import 'opening_screen.dart';
import 'switcher_sheet.dart';

/// One push per site tap — and, since browser-chrome spec §5.2, one per
/// saved site or throwaway opened from the address bar, pushed over the
/// container it was typed in, on the open vault's navigator. Owns the
/// `opening -> live -> refused` lifecycle against [ContainerEngine]
/// internally, rather than issuing a second navigation event when the
/// session finishes connecting — see Plan 6's design spec §2 for why a
/// `pushReplacement` was rejected.
class ContainerRoute extends ConsumerStatefulWidget {
  const ContainerRoute({
    super.key,
    required this.site,
    this.initialUrl,
    this.throwaway = false,
  });

  final Site site;

  /// Loaded instead of [site]'s stored address, for this session only — a
  /// saved site opened from the address bar (browser-chrome spec §5.2). The
  /// stored address never changes.
  final String? initialUrl;

  /// Opens [site] as a throwaway (spec §5): journaled natively so a crash
  /// cannot leak its profile, always wiped on exit, and closed when this
  /// route goes. Whoever pushes one adds it to `throwawaySitesProvider` first.
  final bool throwaway;

  @override
  ConsumerState<ContainerRoute> createState() => _ContainerRouteState();
}

/// Each mounted container's own route, by site id: at most one container per
/// site (user's ruling, 2026-10-02). The engine keys sessions by site id, so a
/// second container for a site would take its session over and leave the
/// first acting on nothing. Torn down with the open vault's navigator, since
/// each container removes itself as it is disposed.
final _containerRoutesProvider = Provider<Map<String, Route<Object?>>>((ref) => {});

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;
  late final Map<String, Route<Object?>> _containerRoutes;
  Route<Object?>? _ownRoute;

  /// Whether leaving this route closes its native session: a throwaway's,
  /// until it is saved as a site. Kept here rather than read from
  /// `throwawaySitesProvider`, which whoever pushed this route empties while
  /// this route is still animating out.
  late bool _closeOnDispose = widget.throwaway;

  /// Whether this site is a throwaway right now: on `throwawaySitesProvider`,
  /// read at every build.
  bool _isThrowaway = false;
  bool _opened = false;

  /// Whether this route's own `open` has returned. Until then, any session
  /// the site has is the one a previous visit left open, registered with the
  /// settings it had then — and the native view factory binds to whatever
  /// session exists when the view is created. Building the page view early
  /// would load it under those old settings (a site switched to a proxy went
  /// out direct) and leave this route waiting on a new session that the view
  /// never reports `live` to.
  bool _openReturned = false;
  bool _refusalHandled = false;
  bool _tunnelDropped = false;

  /// Whether the page has finished a load since this route opened. A
  /// throwaway's save bar waits for it (spec §5.3).
  bool _loadedOnce = false;
  bool _saveBarDismissed = false;

  /// The page's count for what the find bar holds; null until it reports.
  FindResult? _findResult;
  StreamSubscription<PendingPermissionRequest>? _permissionSub;
  StreamSubscription<HeldDownloadEvent>? _downloadSub;
  StreamSubscription<DownloadResult>? _downloadResultSub;
  StreamSubscription<TunnelDroppedEvent>? _tunnelSub;
  StreamSubscription<FindResult>? _findSub;
  final _myDownloadRequestIds = <String>{};

  /// The site as last saved from this route. Starts as [ContainerRoute.site]
  /// and moves on with every change made from the site sheet, so a second
  /// change is saved on top of the first rather than over it. The open
  /// session itself keeps running under the settings it was opened with —
  /// the engine has no call to re-apply them to a live view, so a change
  /// takes effect the next time this site is opened.
  late Site _site = widget.site;

  String get _host => Uri.tryParse(widget.site.url)?.host ?? widget.site.url;

  /// What this container opened: the typed address, or the stored one.
  String get _openedUrl => widget.initialUrl ?? widget.site.url;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(containerEngineProvider);
    _containerRoutes = ref.read(_containerRoutesProvider);
    final engine = _engine;
    _permissionSub = engine
        .permissionRequests()
        .where((r) => r.siteId == widget.site.id)
        .listen(_showPermissionSheet);
    _downloadSub = engine
        .downloads()
        .where((d) => d.siteId == widget.site.id)
        .listen(_showDownloadSheet);
    _downloadResultSub = engine
        .downloadResults()
        .where((r) => _myDownloadRequestIds.contains(r.requestId))
        .listen(_showDownloadResult);
    _tunnelSub = engine
        .tunnelDropped()
        .where((t) => t.siteId == widget.site.id)
        .listen((_) => setState(() => _tunnelDropped = true));
    _findSub = engine
        .findResults()
        .where((r) => r.siteId == widget.site.id)
        .listen((result) => setState(() => _findResult = result));
    _open();
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    // Read before opening, and a failure here stops the open: a site is
    // never opened without the lists and scripts its vault says it gets.
    // The session keeps the stored address; a typed one is only the first
    // load, so the site's script scope and prompts never move to it.
    final extras = await ref.read(engineExtrasBuilderProvider)(widget.site);
    if (!mounted) return;
    try {
      await _engine.open(widget.site,
          extras: extras, throwaway: widget.throwaway, initialUrl: widget.initialUrl);
    } finally {
      if (mounted) setState(() => _openReturned = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _ownRoute) {
      _ownRoute = route;
      _containerRoutes[widget.site.id] = route;
    }
  }

  @override
  void dispose() {
    if (_ownRoute != null && _containerRoutes[widget.site.id] == _ownRoute) {
      _containerRoutes.remove(widget.site.id);
    }
    _permissionSub?.cancel();
    _downloadSub?.cancel();
    _downloadResultSub?.cancel();
    _tunnelSub?.cancel();
    _findSub?.cancel();
    // A throwaway never reopens. Closing its session disposes its page view
    // if Flutter has not already, and ContainerView.dispose wipes a
    // wipe-on-exit profile — popped, or torn down by a lock or panic.
    if (_closeOnDispose) unawaited(_engine.close(widget.site.id));
    super.dispose();
  }

  void _showPermissionSheet(PendingPermissionRequest request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => PermissionRequestSheet(
        host: request.host,
        kind: request.kind,
        onDecision: (decision) {
          Navigator.pop(context);
          _engine.resolvePermission(request.requestId, decision);
        },
      ),
    );
  }

  void _showDownloadSheet(HeldDownloadEvent event) {
    _myDownloadRequestIds.add(event.requestId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HeldDownloadSheet(
        download: event.download,
        onDecision: (decision) {
          Navigator.pop(context);
          _engine.resolveDownload(event.requestId, decision);
        },
      ),
    );
  }

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

  Future<void> _showSiteSheet(int blockedCount) async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    String? workspaceName;
    for (final workspace in workspaces) {
      if (workspace.id == _site.workspaceId) workspaceName = workspace.name;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // A throwaway is not written to the vault until it is saved (spec
          // §5.1). Its switches change only this page's record, which nothing
          // reads again: a throwaway never reopens.
          Future<void> save(Site updated) async {
            setState(() => _site = updated);
            setSheetState(() {});
            if (_isThrowaway) return;
            await ref.read(siteRepositoryProvider).upsert(updated);
            if (mounted) sitesChanged(ref);
          }

          final host = _site.host;
          return SiteSheet(
            monogram: _site.monogram,
            name: _site.name,
            // A throwaway belongs to no workspace until it is saved.
            subtitle: _isThrowaway || workspaceName == null ? host : '$host · $workspaceName',
            proxyDescriptor: _proxyDescriptor(_site),
            cookiesDescriptor: switch (_site.cookiePolicy) {
              CookiePolicy.keep => 'Keep for this site',
              CookiePolicy.wipeOnExit => 'Wipe on exit',
            },
            blockedCount: blockedCount,
            forceDark: _site.forceDark,
            desktopView: _site.userAgentMode == UserAgentMode.desktop,
            // Editing a throwaway means saving it.
            onEdit: () {
              Navigator.pop(sheetContext);
              if (_isThrowaway) {
                _saveAsSite();
              } else {
                _editSite();
              }
            },
            onForceDarkChanged: (value) => save(_site.copyWith(forceDark: value)),
            // The switch is binary, so turning it off lands on `android` — a
            // site that was `minimal` loses that once desktop view is flipped.
            onDesktopViewChanged: (value) => save(_site.copyWith(
              userAgentMode: value ? UserAgentMode.desktop : UserAgentMode.android,
            )),
            onCloseAndWipe: () async {
              Navigator.pop(sheetContext);
              await _closeAndWipe();
              if (!mounted) return;
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _editSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddSiteScreen(
        initial: _site,
        workspaces: workspaces,
        onSave: (updated) async {
          await ref.read(siteRepositoryProvider).upsert(updated);
          if (!mounted) return;
          sitesChanged(ref);
          setState(() => _site = updated);
          Navigator.pop(context);
        },
      ),
    ));
  }

  /// Spec §5.3. The form opens on the throwaway as it is now — the page it is
  /// showing, cookies kept — and keeps its id and profile id, so the saved
  /// site is this same container. The row is written first, then the native
  /// profile is kept: without `keep`, closing the page would wipe the login
  /// just saved. Picking "Wipe on exit" in the form skips `keep`. Anything
  /// else changed in the form applies the next time the site opens.
  Future<void> _saveAsSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final navigation = ref.read(navigationForSiteProvider(widget.site.id)).valueOrNull;
    final url = navigation?.url ?? _openedUrl;
    // A throwaway that has moved to another site is saved as that site, not
    // under the name of the address it started at.
    final host = Uri.tryParse(url)?.host ?? '';
    final moved = host.isNotEmpty &&
        normalizeHost(host) != normalizeHost(Uri.tryParse(_site.url)?.host ?? '');
    final initial = _site.copyWith(
      url: url,
      name: moved ? host : _site.name,
      monogram: moved ? suggestMonogram(host) : _site.monogram,
      cookiePolicy: CookiePolicy.keep,
    );
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AddSiteScreen(
        initial: initial,
        workspaces: workspaces,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          if (site.cookiePolicy != CookiePolicy.wipeOnExit) await _engine.keep(site.id);
          if (!mounted) return;
          _closeOnDispose = false;
          ref.read(throwawaySitesProvider.notifier).remove(site.id);
          sitesChanged(ref);
          setState(() => _site = site);
          Navigator.pop(context);
        },
      ),
    ));
  }

  /// `6c`'s "Close and wipe this session", `2c`'s "Close all and wipe" and
  /// `8c`'s "Close and wipe": this site's session is closed and its data
  /// destroyed. A saved site keeps its row under a fresh profile
  /// ([wipeSavedSite]). A throwaway has no row to rotate — its profile is
  /// journaled from before it exists and goes with it — so it is only closed
  /// and wiped.
  Future<void> _closeAndWipe() async {
    closeSite(ref, widget.site.id);
    if (_isThrowaway) {
      await _engine.close(widget.site.id);
      await _engine.wipe(_site.profileId);
      return;
    }
    final sites = ref.read(siteRepositoryProvider);
    _site = await wipeSavedSite(engine: _engine, sites: sites, site: _site);
    if (mounted) sitesChanged(ref);
  }

  Future<void> _openReader() async {
    final article = await _engine.extractArticle(widget.site.id);
    if (article == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderRoute(
        article: article,
        onClose: () => Navigator.pop(context),
      ),
    ));
  }

  /// Find in page (spec §6.5). The count shown is dropped until the page
  /// reports the new text's, so it is never the old text's.
  void _find(String query) {
    setState(() => _findResult = null);
    if (query.isEmpty) {
      _engine.clearFind(widget.site.id);
    } else {
      _engine.find(widget.site.id, query);
    }
  }

  void _clearFind() {
    setState(() => _findResult = null);
    _engine.clearFind(widget.site.id);
  }

  /// Spec §3.3: the page's own address, through Flutter's clipboard. The
  /// site's `allowClipboard` governs page scripts, not this user action.
  Future<void> _copyLink() async {
    final url =
        ref.read(navigationForSiteProvider(widget.site.id)).valueOrNull?.url ?? _openedUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  /// A ☰ shortcut (spec §6.4), pushed on the open vault's navigator above
  /// this container.
  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// The ☰ header's mono line (spec §6.4): `host · Workspace`, or the host
  /// alone for a throwaway, which belongs to no workspace until saved.
  String _menuSubtitle(List<Workspace> workspaces) {
    final host = _site.host;
    if (_isThrowaway) return host;
    for (final workspace in workspaces) {
      if (workspace.id == _site.workspaceId) return '$host · ${workspace.name}';
    }
    return host;
  }

  /// Spec §5.2: where a typed address or search opens. A saved site's
  /// container and a throwaway are pushed over this one, on the open vault's
  /// navigator, so system back comes back here with this page still live.
  /// A saved site whose container is already lower in the stack is returned
  /// to instead, and loads the address there (user's ruling, 2026-10-02).
  ///
  /// [suggested] was decided from the address bar's copy of the vault's
  /// sites, which can be out of date. So it is decided again here against the
  /// vault as it is now, and a saved site opens with its current route and
  /// profile: never one removed since, nor the profile a wipe rotated away.
  Future<void> _openDestination(Destination suggested) async {
    final saved = await ref.read(siteRepositoryProvider).all();
    if (!mounted) return;
    final destination = destinationFor(suggested.url, current: widget.site, saved: saved);
    switch (destination) {
      case ThisContainer(:final url):
        await _engine.loadUrl(widget.site.id, url.toString());
      case SavedSiteContainer(:final site, :final url):
        // As the dashboard and search open a site: marked open, the visit
        // recorded. Its stored address is not touched.
        openSite(ref, site.id);
        final existing = _containerRoutes[site.id];
        if (existing != null) {
          // Every route above it is popped, this one included: a throwaway
          // among them is wiped as when it is left, a saved site's session
          // stays open. [_engine] outlives this state.
          final engine = _engine;
          Navigator.popUntil(context, (route) => route == existing);
          await engine.loadUrl(site.id, url.toString());
          return;
        }
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => ContainerRoute(site: site, initialUrl: url.toString()),
        ));
      case final Throwaway target:
        final throwaway = buildThrowaway(
          destination: target,
          current: widget.site,
          newId: newProfileId,
        );
        ref.read(throwawaySitesProvider.notifier).add(throwaway);
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => ContainerRoute(site: throwaway, throwaway: true),
        ));
        // Popped: its route closed its session, which wiped it. A lock or
        // panic empties the list by itself.
        if (mounted) ref.read(throwawaySitesProvider.notifier).remove(throwaway.id);
    }
  }

  void _handleRefusal(ContainerSession session) {
    if (_refusalHandled) return;
    _refusalHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ProxyUnreachableScreen(
          host: _host,
          siteName: widget.site.name,
          failure: session.failure ?? RouteFailure.misconfigured,
          tunnelDescriptor: widget.site.proxyHost == null
              ? 'no proxy'
              : '${widget.site.proxyMode.name} · ${widget.site.proxyHost}:${widget.site.proxyPort}',
          lastWorkedLabel: 'never on this device',
          onTryAgain: () => Navigator.pop(context),
          onChangeProxySettings: () => Navigator.pop(context),
          onOpenWithoutTunnel: () => Navigator.pop(context),
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionForSiteProvider(widget.site.id));
    _isThrowaway = ref.watch(throwawaySitesProvider).any((site) => site.id == widget.site.id);
    final navigation = ref.watch(navigationForSiteProvider(widget.site.id)).valueOrNull;
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];
    final blockedToday = ref.watch(leakCountProvider);
    // What typed text is matched against (spec §4.4): this vault's sites and
    // search engine, watched from the start so the first keystroke has them.
    final saved = ref.watch(allSitesProvider).valueOrNull ?? const <Site>[];
    final searchEngine =
        ref.watch(searchEngineProvider).valueOrNull ?? SearchEngine.duckDuckGo;
    // Spec §5.3: a throwaway offers the save bar once its first load has
    // finished.
    ref.listen(navigationForSiteProvider(widget.site.id), (_, next) {
      if (!_loadedOnce && next.valueOrNull?.loading == false) {
        setState(() => _loadedOnce = true);
      }
    });

    return sessionAsync.when(
      loading: () => OpeningBody(
        host: _host, steps: openStepsFor(widget.site), progress: 0.2,
        onCancel: () => Navigator.pop(context),
      ),
      error: (_, __) => OpeningBody(
        host: _host, steps: openStepsFor(widget.site), progress: 0,
        onCancel: () => Navigator.pop(context),
      ),
      data: (session) {
        // No session yet means `open` has not registered this site natively,
        // and the platform refuses a view for an unregistered site — so only
        // the checklist here. Once it exists, the page view is built even
        // while `opening` (see the overlay below). A session seen before this
        // route's own `open` returns is a previous visit's; see
        // [_openReturned].
        if (session == null || !_openReturned) {
          return OpeningBody(
            host: _host, steps: openStepsFor(widget.site), progress: 0.6,
            onCancel: () => Navigator.pop(context),
          );
        }
        if (session.phase == SessionPhase.refused) {
          _handleRefusal(session);
          return const SizedBox.shrink();
        }

        final pageHost = navigation?.host ?? '';
        return Stack(children: [
          ContainerScreen(
            // The page's host once it reports one; the site's before that,
            // and whenever the page has none (`about:blank`, a failed load).
            host: pageHost.isEmpty ? _host : pageHost,
            // There is no DIRECT label (spec §4.4).
            routeLabel: widget.site.proxyMode == ProxyMode.direct
                ? ''
                : widget.site.proxyMode.name.toUpperCase(),
            live: session.phase == SessionPhase.live,
            navigation: navigation,
            openCount: 1,
            body: ContainerWebView(siteId: widget.site.id),
            entries: [
              SwitcherEntry(
                siteId: widget.site.id, name: widget.site.name,
                monogram: widget.site.monogram,
                meta: 'viewing now · ${widget.site.proxyMode.name}',
                live: true,
              ),
            ],
            workspaceName: '',
            siteMonogram: _site.monogram,
            siteName: _site.name,
            siteSubtitle: _menuSubtitle(workspaces),
            blockedToday: blockedToday,
            findResult: _findResult,
            showSaveBar: _isThrowaway && _loadedOnce && !_saveBarDismissed,
            address: navigation?.url ?? _openedUrl,
            // `current` is the site this container was opened for: its host
            // is "this container", its route the one a throwaway inherits.
            suggest: (text) => suggestionsFor(
              text: text,
              current: widget.site,
              saved: saved,
              workspaces: workspaces,
              engine: searchEngine,
            ),
            onOpen: _openDestination,
            onBack: () => _engine.goBack(widget.site.id),
            onForward: () => _engine.goForward(widget.site.id),
            onStop: () => _engine.stop(widget.site.id),
            onReload: () => _engine.reload(widget.site.id),
            onPanic: () => panic(ref),
            onSiteDetails: () => _showSiteSheet(session.blockedCount),
            onReader: _openReader,
            onCopyLink: _copyLink,
            onToday: () => _push(const TodayRoute()),
            onScripts: () => _push(const ScriptsRoute()),
            onWorkspaces: () => _push(const WorkspacesRoute()),
            onSettings: () => _push(const SettingsRoute()),
            // Spec §5.2: to the dashboard, the first route, closing every
            // container pushed on the way.
            onAllSites: () => Navigator.popUntil(context, (route) => route.isFirst),
            onFind: _find,
            onFindNext: (forward) => _engine.findNext(widget.site.id, forward: forward),
            onClearFind: _clearFind,
            onSaveAsSite: _saveAsSite,
            onDismissSaveBar: () => setState(() => _saveBarDismissed = true),
            // The switcher has already closed itself by now. Only closing
            // this route's own site leaves it with nothing to show.
            onCloseSession: (siteId) async {
              closeSite(ref, siteId);
              await _engine.close(siteId);
              if (siteId != widget.site.id || !context.mounted) return;
              Navigator.pop(context);
            },
            onCloseAllAndWipe: () async {
              await _closeAndWipe();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          if (_tunnelDropped)
            TunnelDroppedScreen(
              host: _host,
              droppedAgoLabel: 'just now',
              onReconnect: () => setState(() => _tunnelDropped = false),
              onCloseAndWipe: () async {
                await _closeAndWipe();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
          // The checklist covers the page rather than replacing it. The
          // native view only reports `live` once its first load finishes, and
          // it only exists once ContainerWebView above is built — so the page
          // must be building underneath while this shows, or it never
          // arrives. Keeping ContainerScreen at the same position in this
          // Stack is what lets going live remove the overlay without
          // rebuilding the view (a rebuild disposes the native WebView).
          if (session.phase == SessionPhase.opening)
            Positioned.fill(
              child: OpeningBody(
                host: _host, steps: openStepsFor(widget.site), progress: 0.6,
                onCancel: () => Navigator.pop(context),
              ),
            ),
        ]);
      },
    );
  }
}

/// Spec `6c`'s proxy row: `SOCKS5 · 127.0.0.1:9050`.
String _proxyDescriptor(Site site) => switch (site.proxyMode) {
      ProxyMode.direct => 'Direct',
      ProxyMode.socks5 => 'SOCKS5 · ${site.proxyHost}:${site.proxyPort}',
      ProxyMode.http => 'HTTP · ${site.proxyHost}:${site.proxyPort}',
    };
