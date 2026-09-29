import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/container_engine.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/route_failure_copy.dart';
import '../../../../domain/models/route_decision.dart' show refusalMessage;
import '../../../../domain/models/site.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../dashboard/view_models/providers.dart'
    show closeSite, siteRepositoryProvider, workspacesProvider;
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_screen.dart';
import '../../in_page/views/site_sheet.dart';
import '../../in_page/views/tunnel_dropped_screen.dart';
import '../view_models/providers.dart';
import 'container_screen.dart';
import 'container_web_view.dart';
import 'opening_screen.dart';
import 'switcher_sheet.dart';

/// One push per site tap. Owns the `opening -> live -> refused` lifecycle
/// against [ContainerEngine] internally, rather than issuing a second
/// navigation event when the session finishes connecting — see this plan's
/// design spec §2 for why a `pushReplacement` was rejected.
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

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;
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
  StreamSubscription<PendingPermissionRequest>? _permissionSub;
  StreamSubscription<HeldDownloadEvent>? _downloadSub;
  StreamSubscription<DownloadResult>? _downloadResultSub;
  StreamSubscription<TunnelDroppedEvent>? _tunnelSub;
  final _myDownloadRequestIds = <String>{};

  /// The site as last saved from this route. Starts as [ContainerRoute.site]
  /// and moves on with every change made from the site sheet, so a second
  /// change is saved on top of the first rather than over it. The open
  /// session itself keeps running under the settings it was opened with —
  /// the engine has no call to re-apply them to a live view, so a change
  /// takes effect the next time this site is opened.
  late Site _site = widget.site;

  String get _host => Uri.tryParse(widget.site.url)?.host ?? widget.site.url;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(containerEngineProvider);
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
    _open();
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    // Read before opening, and a failure here stops the open: a site is
    // never opened without the lists and scripts its vault says it gets.
    final initialUrl = widget.initialUrl;
    final site = initialUrl == null ? widget.site : widget.site.copyWith(url: initialUrl);
    final extras = await ref.read(engineExtrasBuilderProvider)(site);
    if (!mounted) return;
    try {
      await _engine.open(site, extras: extras, throwaway: widget.throwaway);
    } finally {
      if (mounted) setState(() => _openReturned = true);
    }
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _downloadSub?.cancel();
    _downloadResultSub?.cancel();
    _tunnelSub?.cancel();
    // A throwaway never reopens. Closing its session disposes its page view
    // if Flutter has not already, and ContainerView.dispose wipes a
    // wipe-on-exit profile — popped, or torn down by a lock or panic.
    if (widget.throwaway) unawaited(_engine.close(widget.site.id));
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
          ref.read(containerEngineProvider).resolvePermission(request.requestId, decision);
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
          ref.read(containerEngineProvider).resolveDownload(event.requestId, decision);
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

    final engine = ref.read(containerEngineProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> save(Site updated) async {
            setState(() => _site = updated);
            setSheetState(() {});
            await ref.read(siteRepositoryProvider).upsert(updated);
          }

          final host = Uri.tryParse(_site.url)?.host ?? _site.url;
          return SiteSheet(
            monogram: _site.monogram,
            name: _site.name,
            subtitle: workspaceName == null ? host : '$host · $workspaceName',
            proxyDescriptor: _proxyDescriptor(_site),
            cookiesDescriptor: switch (_site.cookiePolicy) {
              CookiePolicy.keep => 'Keep for this site',
              CookiePolicy.wipeOnExit => 'Wipe on exit',
            },
            blockedCount: blockedCount,
            forceDark: _site.forceDark,
            desktopView: _site.userAgentMode == UserAgentMode.desktop,
            onEdit: () {
              Navigator.pop(sheetContext);
              _editSite();
            },
            onForceDarkChanged: (value) => save(_site.copyWith(forceDark: value)),
            // The switch is binary, so turning it off lands on `android` — a
            // site that was `minimal` loses that once desktop view is flipped.
            onDesktopViewChanged: (value) => save(_site.copyWith(
              userAgentMode: value ? UserAgentMode.desktop : UserAgentMode.android,
            )),
            onCloseAndWipe: () async {
              Navigator.pop(sheetContext);
              closeSite(ref, widget.site.id);
              await engine.close(widget.site.id);
              await engine.wipe(widget.site.profileId);
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
          setState(() => _site = updated);
          Navigator.pop(context);
        },
      ),
    ));
  }

  Future<void> _openReader() async {
    final article = await ref.read(containerEngineProvider).extractArticle(widget.site.id);
    if (article == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        article: article,
        onClose: () => Navigator.pop(context),
        onTextSize: () {},
        onTheme: () {},
      ),
    ));
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

        final engine = ref.read(containerEngineProvider);
        return Stack(children: [
          ContainerScreen(
            host: _host,
            routeLabel: widget.site.proxyMode.name.toUpperCase(),
            live: session.phase == SessionPhase.live,
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
            onBack: () => Navigator.pop(context),
            onReload: () => engine.reload(widget.site.id),
            onPanic: () => panic(ref),
            // The switcher has already closed itself by now. Only closing
            // this route's own site leaves it with nothing to show.
            onCloseSession: (siteId) async {
              closeSite(ref, siteId);
              await engine.close(siteId);
              if (siteId != widget.site.id || !context.mounted) return;
              Navigator.pop(context);
            },
            onCloseAllAndWipe: () async {
              closeSite(ref, widget.site.id);
              await engine.close(widget.site.id);
              await engine.wipe(widget.site.profileId);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            onReaderMode: _openReader,
            onFilters: () {},
            onMenu: () => _showSiteSheet(session.blockedCount),
            onMore: () {},
          ),
          if (_tunnelDropped)
            TunnelDroppedScreen(
              host: _host,
              droppedAgoLabel: 'just now',
              onReconnect: () => setState(() => _tunnelDropped = false),
              onCloseAndWipe: () async {
                closeSite(ref, widget.site.id);
                await engine.close(widget.site.id);
                await engine.wipe(widget.site.profileId);
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
