import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/route_failure_copy.dart';
import '../../../../domain/models/site.dart';
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_screen.dart';
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
  const ContainerRoute({super.key, required this.site});

  final Site site;

  @override
  ConsumerState<ContainerRoute> createState() => _ContainerRouteState();
}

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  bool _opened = false;
  bool _refusalHandled = false;
  bool _tunnelDropped = false;
  StreamSubscription<PendingPermissionRequest>? _permissionSub;
  StreamSubscription<HeldDownloadEvent>? _downloadSub;
  StreamSubscription<TunnelDroppedEvent>? _tunnelSub;

  String get _host => Uri.tryParse(widget.site.url)?.host ?? widget.site.url;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(containerEngineProvider);
    _permissionSub = engine
        .permissionRequests()
        .where((r) => r.siteId == widget.site.id)
        .listen(_showPermissionSheet);
    _downloadSub = engine
        .downloads()
        .where((d) => d.siteId == widget.site.id)
        .listen(_showDownloadSheet);
    _tunnelSub = engine
        .tunnelDropped()
        .where((t) => t.siteId == widget.site.id)
        .listen((_) => setState(() => _tunnelDropped = true));
    _open();
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    await ref.read(containerEngineProvider).open(widget.site);
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _downloadSub?.cancel();
    _tunnelSub?.cancel();
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HeldDownloadSheet(
        download: event.download,
        onDecision: (_) => Navigator.pop(context),
      ),
    );
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
        if (session == null || session.phase == SessionPhase.opening) {
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
            onCloseSession: (siteId) async {
              await engine.close(siteId);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            onCloseAllAndWipe: () async {
              await engine.close(widget.site.id);
              await engine.wipe(widget.site.profileId);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            onReaderMode: _openReader,
            onFilters: () {},
            onMenu: () {},
            onMore: () {},
          ),
          if (_tunnelDropped)
            TunnelDroppedScreen(
              host: _host,
              droppedAgoLabel: 'just now',
              onReconnect: () => setState(() => _tunnelDropped = false),
              onCloseAndWipe: () async {
                await engine.close(widget.site.id);
                await engine.wipe(widget.site.profileId);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
        ]);
      },
    );
  }
}
