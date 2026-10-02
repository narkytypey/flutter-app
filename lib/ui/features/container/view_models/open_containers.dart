import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/container_engine.dart';
import '../../../../data/services/site_wipe.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/held_download.dart' show DownloadDecision;
import '../../../../domain/models/navigation_state.dart';
import '../../../../domain/models/open_container.dart';
import '../../../../domain/models/open_page.dart';
import '../../../../domain/models/permissions.dart' show PermissionDecision;
import '../../../../domain/models/route_decision.dart' show RouteFailure;
import '../../../../domain/models/site.dart';
import '../../../../domain/tabs.dart';
import '../../dashboard/view_models/providers.dart' show siteRepositoryProvider;
import '../../shell/view_models/session_controller.dart' show SessionOpen, sessionProvider;
import 'providers.dart' show containerEngineProvider, engineExtrasBuilderProvider;

const _keep = Object();

/// The registry's clock; tests replace it.
final tabsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class OpenContainersState {
  const OpenContainersState({
    this.containers = const [],
    this.viewedSiteId,
    this.navigation = const {},
  });

  /// Opening order.
  final List<OpenContainer> containers;

  /// The container on screen; null while the dashboard shows.
  final String? viewedSiteId;

  /// Each open page's last `navigation` event, by page id.
  final Map<String, NavigationState> navigation;

  OpenContainer? byId(String siteId) {
    for (final c in containers) {
      if (c.siteId == siteId) return c;
    }
    return null;
  }

  OpenContainer? get viewed => viewedSiteId == null ? null : byId(viewedSiteId!);

  Iterable<OpenContainer> get listed => containers.where((c) => c.listed);

  /// `N OPEN`, `2c`'s header, `9b` (tabs spec §5.4).
  int get openCount => listed.length;

  /// Every listed container, saved and throwaway.
  Set<String> get openSiteIds => {for (final c in listed) c.siteId};

  /// Throwaways counted under [workspaceId] — their opener's (§5.4).
  int throwawaysIn(String workspaceId) =>
      listed.where((c) => c.throwaway && c.site.workspaceId == workspaceId).length;

  OpenContainersState copyWith({
    List<OpenContainer>? containers,
    Object? viewedSiteId = _keep,
    Map<String, NavigationState>? navigation,
  }) =>
      OpenContainersState(
        containers: containers ?? this.containers,
        viewedSiteId: identical(viewedSiteId, _keep) ? this.viewedSiteId : viewedSiteId as String?,
        navigation: navigation ?? this.navigation,
      );
}

final openContainersProvider =
    NotifierProvider<OpenContainers, OpenContainersState>(OpenContainers.new);

/// The registry's [OpenContainersState.openCount], mirrored for
/// `SessionController`'s `9b` count (tabs spec §5.4). It cannot read the
/// registry itself: the registry watches `sessionProvider`, and Riverpod
/// refuses a read from a provider that the read one depends on.
final openContainerCountProvider = Provider<OpenContainerCount>((ref) => OpenContainerCount());

class OpenContainerCount {
  /// Every listed container, throwaways included; 0 before the registry is
  /// first built and after every reset.
  int value = 0;
}

/// Every open container of the open vault, in memory only (tabs spec §4.1):
/// its pages, the viewed page, its lifecycle, its waiting asks and each
/// page's navigation. Nothing here is ever written to disk.
class OpenContainers extends Notifier<OpenContainersState> {
  late ContainerEngine _engine;

  /// Sites whose refusal is being recorded: once per open.
  final _refusing = <String>{};

  /// Each site's latest [_open], so an open overtaken by a newer one for the
  /// same site (a reopen, or a fresh view after a drop) does nothing when it
  /// returns. Native `register` has already torn its pages down (tabs plan,
  /// Deviation 4).
  final _opens = <String, Object>{};

  DateTime _now() => ref.read(tabsClockProvider)();

  @override
  OpenContainersState build() {
    // Rebuilt empty on every transition out of SessionOpen (tabs spec §4.1).
    final database =
        ref.watch(sessionProvider.select((s) => s is SessionOpen ? s.database : null));
    final engine = ref.watch(containerEngineProvider);
    _engine = engine;
    _refusing.clear();
    // `9b`'s count, mirrored for SessionController (see the provider).
    final count = ref.read(openContainerCountProvider)..value = 0;
    listenSelf((_, next) => count.value = next.openCount);
    final subscriptions = <StreamSubscription<Object?>>[
      engine.sessions().listen(_onSessions),
      engine.pageOpened().listen(_onPageOpened),
      engine.navigation().listen(_onNavigation),
      engine.permissionRequests().listen((r) => _wait(r.siteId, WaitingPermission(r.pageId, r),
          orElse: () => engine.resolvePermission(r.requestId, PermissionDecision.keepBlocked))),
      engine.downloads().listen((d) => _wait(d.siteId, WaitingDownload(d.pageId, d),
          orElse: () => engine.resolveDownload(d.requestId, DownloadDecision.discard))),
      engine.tunnelDropped()
          .listen((t) => _update(t.siteId, (c) => c.copyWith(tunnelDropped: true))),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
      // Emptied now, not at the lazy rebuild: a lock must not count what
      // the last one closed.
      count.value = 0;
      // Pages no longer die with the widget tree (tabs spec §5.8). Only a
      // build made while a vault was open sends it: reading the registry
      // while locked rebuilds it, and the next unlock disposes that build,
      // which is a transition into SessionOpen, not out of it.
      if (database != null) unawaited(engine.closeAll());
    });
    return const OpenContainersState();
  }

  /// Opening a site from the dashboard, search or the address bar (tabs spec
  /// §4.2, §5.5). Registers synchronously, so the host route has something to
  /// show at once, then returns the open.
  ///
  /// An open container is shown, with nothing reloaded and no second `open`;
  /// with [initialUrl], its last viewed page loads it. A refused saved site's
  /// leftover entry is dropped and the site opened fresh.
  Future<void> view(
    Site site, {
    String? initialUrl,
    bool throwaway = false,
    String? openerSiteId,
  }) {
    final existing = state.byId(site.id);
    if (existing != null && existing.listed) {
      _show(site.id);
      final pageId = existing.viewedPageId;
      if (initialUrl != null && pageId != null) return _engine.loadUrl(pageId, initialUrl);
      return Future.value();
    }
    if (existing != null) _drop(site.id);
    final now = _now();
    final previous = state.viewedSiteId;
    state = state.copyWith(
      containers: [
        for (final c in state.containers)
          c.siteId == previous ? c.copyWith(lastViewedAt: now) : c,
        OpenContainer(
          site: site,
          opened: site,
          lastViewedAt: now,
          throwaway: throwaway,
          openerSiteId: openerSiteId,
          initialUrl: initialUrl,
        ),
      ],
      viewedSiteId: site.id,
    );
    return _open(site.id);
  }

  /// `2c`'s page row (tabs spec §5.1), and back to an opener page (§5.3):
  /// show [siteId] with [pageId] in front.
  void viewPage(String siteId, String pageId) {
    _show(siteId);
    _update(siteId,
        (c) => c.copyWith(viewOrder: [pageId, ...c.viewOrder.where((id) => id != pageId)]));
  }

  /// Leaving for the dashboard (tabs spec §4.2). Every container stays open.
  void showDashboard() {
    final viewed = state.viewedSiteId;
    if (viewed == null) return;
    final now = _now();
    _update(viewed, (c) => c.copyWith(lastViewedAt: now));
    state = state.copyWith(viewedSiteId: null);
  }

  /// `2c`'s × on a page (tabs spec §5.1). A container's last page closes the
  /// container (§5.8a).
  Future<void> closePage(String siteId, String pageId) async {
    final container = state.byId(siteId);
    if (container == null) return;
    final others = container.pages.where((page) => page.pageId != pageId);
    if (others.isEmpty) return close(siteId);
    _update(
      siteId,
      (c) => c.copyWith(
        pages: [for (final page in c.pages) if (page.pageId != pageId) page],
        viewOrder: [for (final id in c.viewOrder) if (id != pageId) id],
        waiting: [for (final ask in c.waiting) if (ask.pageId != pageId) ask],
      ),
    );
    state = state.copyWith(
      navigation: {
        for (final entry in state.navigation.entries)
          if (entry.key != pageId) entry.key: entry.value,
      },
    );
    await _engine.closePage(pageId);
  }

  /// `2c`'s × on a container, the checklist's Cancel, a throwaway's last
  /// back (tabs spec §5.1, §5.3, §5.8a). [wipe] overrides the session's own
  /// wipe-on-exit; a throwaway is always wiped.
  Future<void> close(String siteId, {bool? wipe}) {
    final container = state.byId(siteId);
    _drop(siteId);
    final throwaway = container?.throwaway ?? false;
    return _engine.close(siteId, wipe: wipe ?? (throwaway ? true : null));
  }

  /// `6c`'s "Close and wipe this session", `8c`'s "Close and wipe" (tabs
  /// spec §5.8a). A saved site keeps its row, with a fresh profile.
  Future<void> closeAndWipe(String siteId) async {
    final container = state.byId(siteId);
    if (container == null) return;
    _drop(siteId);
    if (container.throwaway) {
      await _engine.close(siteId, wipe: true);
      return;
    }
    await wipeSavedSite(
      engine: _engine,
      sites: ref.read(siteRepositoryProvider),
      site: container.site,
    );
  }

  /// `2c`'s "Close all and wipe" (tabs spec §5.8a), in opening order.
  Future<void> closeAllAndWipe() async {
    for (final container in [...state.containers]) {
      await closeAndWipe(container.siteId);
    }
  }

  /// `8b`'s three ways out, and §5.7's reopen of the viewed container: [site]
  /// opened again in place, as a fresh open. [withoutTunnel] is "Open without
  /// the tunnel", this visit only, so the saved [OpenContainer.site] is left
  /// as it is. [atStoredAddress] forgets the typed first address. Native
  /// `register` tears the old pages down (tabs plan, Deviation 4).
  Future<void> reopen(
    String siteId,
    Site site, {
    bool withoutTunnel = false,
    bool atStoredAddress = false,
  }) {
    if (state.byId(siteId) == null) return Future.value();
    _update(
      siteId,
      (c) => c.copyWith(
        opened: site,
        site: withoutTunnel ? c.site : site,
        withoutTunnel: withoutTunnel,
        refusal: null,
        openReturned: false,
        phase: SessionPhase.opening,
        pages: const [],
        viewOrder: const [],
        waiting: const [],
        tunnelDropped: false,
        workedRecorded: false,
        initialUrl: atStoredAddress ? null : _keep,
      ),
    );
    _dropNavigationOf(siteId);
    return _open(siteId);
  }

  /// A site saved while its container is open (tabs spec §5.7). Only a
  /// change of route or cookie policy closes it: a background container stays
  /// closed, and the viewed one reopens in place at its stored address.
  ///
  /// A saved site whose new policy is wipe on exit is wiped now through
  /// [wipeSavedSite], which rotates its profile (tabs plan, Deviation 3), so
  /// the reopened page never loads on a profile being cleared underneath it.
  ///
  /// Returns the site as it now stands: [after], or [after] with its fresh
  /// profile id.
  Future<Site> siteSaved(Site after) async {
    final container = state.byId(after.id);
    if (container == null || !container.listed) return after;
    if (!routeOrCookiePolicyChanged(container.opened, after)) {
      _update(after.id, (c) => c.copyWith(site: after));
      return after;
    }
    final viewed = state.viewedSiteId == after.id;
    if (viewed) {
      // Not reconciled into a drop: only containers whose open has returned
      // are (see [_onSessions]).
      _update(
        after.id,
        (c) => c.copyWith(site: after, openReturned: false, pages: const [], viewOrder: const []),
      );
    } else {
      _drop(after.id);
    }
    final Site site;
    if (after.cookiePolicy == CookiePolicy.wipeOnExit && !container.throwaway) {
      site = await wipeSavedSite(
        engine: _engine,
        sites: ref.read(siteRepositoryProvider),
        site: after,
      );
    } else {
      await _engine.close(after.id, wipe: false);
      site = after;
    }
    if (viewed) await reopen(after.id, site, atStoredAddress: true);
    return site;
  }

  /// A throwaway saved as a site (browser-chrome spec §5.3, tabs spec §5.7),
  /// after its row is written and `keep` has run. `keep` already aligned the
  /// native wipe flag, so only a route change reopens.
  Future<Site> saveThrowaway(Site site) {
    _update(
      site.id,
      (c) => c.copyWith(
        throwaway: false,
        site: site,
        opened: c.opened.copyWith(cookiePolicy: site.cookiePolicy),
      ),
    );
    return siteSaved(site);
  }

  /// A throwaway's `6c` switches (tabs spec §5.7): they change neither route
  /// nor cookie policy, so nothing closes.
  void updateSite(Site site) => _update(site.id, (c) => c.copyWith(site: site));

  /// The oldest ask waiting for [pageId] (tabs spec §5.6), removed.
  WaitingAsk? takeWaiting(String siteId, String pageId) {
    final container = state.byId(siteId);
    if (container == null) return null;
    WaitingAsk? taken;
    for (final ask in container.waiting) {
      if (ask.pageId == pageId) {
        taken = ask;
        break;
      }
    }
    if (taken == null) return null;
    final found = taken;
    _update(siteId,
        (c) => c.copyWith(waiting: [for (final ask in c.waiting) if (!identical(ask, found)) ask]));
    return found;
  }

  /// The save bar's dismiss, per throwaway (tabs spec §5.9).
  void dismissSaveBar(String siteId) =>
      _update(siteId, (c) => c.copyWith(saveBarDismissed: true));

  /// `8c` shown (tabs spec §5.6).
  void clearTunnelDropped(String siteId) =>
      _update(siteId, (c) => c.copyWith(tunnelDropped: false));

  /// Shows [siteId]; the container leaving the screen and the one coming on
  /// both get "last viewed" now.
  void _show(String siteId) {
    final now = _now();
    final previous = state.viewedSiteId;
    state = state.copyWith(
      containers: [
        for (final c in state.containers)
          c.siteId == siteId || c.siteId == previous ? c.copyWith(lastViewedAt: now) : c,
      ],
      viewedSiteId: siteId,
    );
  }

  Future<void> _open(String siteId) async {
    final token = Object();
    _opens[siteId] = token;
    _refusing.remove(siteId);
    bool superseded() => !identical(_opens[siteId], token);

    final first = state.byId(siteId);
    if (first == null) return;
    // Read before opening, and a failure here stops the open: a site is never
    // opened without the lists and scripts its vault says it gets.
    final extras = await ref.read(engineExtrasBuilderProvider)(first.opened);
    if (superseded()) return;
    final container = state.byId(siteId);
    if (container == null) return;
    final engine = _engine;
    final session = await engine.open(
      container.opened,
      extras: extras,
      throwaway: container.throwaway,
      initialUrl: container.initialUrl,
    );
    if (superseded()) return;
    if (state.byId(siteId) == null) {
      // Dropped while the open ran: a session nobody holds must not stay open.
      await engine.close(siteId, wipe: container.throwaway ? true : null);
      return;
    }
    _update(
      siteId,
      (c) => c.copyWith(
        openReturned: true,
        pages: session.pages,
        viewOrder: [if (session.pages.isNotEmpty) session.pages.first.pageId],
        phase: session.phase,
      ),
    );
    _applySession(session);
  }

  /// Every session list: how closes made elsewhere arrive — `removeSavedSite`,
  /// the row-menu wipe, deleting a workspace, a page's `window.close()` on a
  /// last page, panic. Only containers whose own open has returned are
  /// reconciled; one with a refusal keeps its `8b`.
  void _onSessions(List<ContainerSession> sessions) {
    final bySite = {for (final session in sessions) session.siteId: session};
    for (final container in [...state.containers]) {
      if (!container.openReturned) continue;
      final session = bySite[container.siteId];
      if (session == null) {
        if (container.refusal == null && !_refusing.contains(container.siteId)) {
          _drop(container.siteId);
        }
        continue;
      }
      _applySession(session);
    }
  }

  void _applySession(ContainerSession session) {
    final siteId = session.siteId;
    final container = state.byId(siteId);
    if (container == null || !container.openReturned) return;
    final ids = {for (final page in session.pages) page.pageId};
    _update(
      siteId,
      (c) => c.copyWith(
        pages: session.pages,
        viewOrder: [for (final id in c.viewOrder) if (ids.contains(id)) id],
        waiting: [for (final ask in c.waiting) if (ids.contains(ask.pageId)) ask],
        phase: session.phase,
        blockedCount: session.blockedCount,
      ),
    );
    if (state.navigation.entries.any((e) => e.value.siteId == siteId && !ids.contains(e.key))) {
      state = state.copyWith(navigation: {
        for (final entry in state.navigation.entries)
          if (entry.value.siteId != siteId || ids.contains(entry.key)) entry.key: entry.value,
      });
    }
    switch (session.phase) {
      case SessionPhase.live:
        _recordWorked(siteId);
      case SessionPhase.refused:
        unawaited(_refused(session));
      case SessionPhase.opening:
      case SessionPhase.background:
        break;
    }
  }

  /// A link that asked for a new window: its page comes to the front (tabs
  /// spec §5.2).
  void _onPageOpened(PageOpened event) {
    _update(
      event.siteId,
      (c) => c.copyWith(
        pages: c.page(event.pageId) != null
            ? c.pages
            : [...c.pages, OpenPage(pageId: event.pageId, openerPageId: event.openerPageId)],
        viewOrder: [event.pageId, ...c.viewOrder.where((id) => id != event.pageId)],
      ),
    );
  }

  /// Kept only for a site with a container: nothing else can show it.
  void _onNavigation(NavigationState navigation) {
    final container = state.byId(navigation.siteId);
    if (container == null) return;
    state = state.copyWith(navigation: {...state.navigation, navigation.pageId: navigation});
    // A throwaway's save bar waits for any page's first finished load.
    if (!navigation.loading && !container.loadedOnce) {
      _update(navigation.siteId, (c) => c.copyWith(loadedOnce: true));
    }
  }

  /// An ask waits on its container until its page is viewed (tabs spec
  /// §5.6). With no container, nothing could ever show it, so it is answered
  /// at once.
  void _wait(String siteId, WaitingAsk ask, {required void Function() orElse}) {
    if (state.byId(siteId) == null) {
      orElse();
      return;
    }
    _update(siteId, (c) => c.copyWith(waiting: [...c.waiting, ask]));
  }

  /// Records that this open went live on its route, for `8b`'s "Last
  /// worked": once per open, never for a direct visit. A throwaway has no
  /// row, so only the registry remembers it.
  void _recordWorked(String siteId) {
    final container = state.byId(siteId);
    if (container == null || container.workedRecorded || container.withoutTunnel) return;
    final at = _now();
    _update(siteId, (c) => c.copyWith(workedRecorded: true, workedAt: at));
    if (!container.throwaway) {
      unawaited(ref.read(siteRepositoryProvider).setLastWorked(siteId, at));
    }
  }

  /// A refused open (`8b`). A saved site's dead session is closed; if it is
  /// not on screen it is dropped, since nothing lists it (tabs plan,
  /// Deviation 2). A throwaway's stays, since `8b` can still save it.
  Future<void> _refused(ContainerSession session) async {
    final siteId = session.siteId;
    if (!_refusing.add(siteId)) return;
    final container = state.byId(siteId);
    if (container == null) return;
    final token = _opens[siteId];
    final failure = session.failure ?? RouteFailure.misconfigured;
    final lastWorked = container.throwaway
        ? container.workedAt
        : await ref.read(siteRepositoryProvider).lastWorked(siteId);
    if (!identical(_opens[siteId], token) || state.byId(siteId) == null) return;
    _update(siteId, (c) => c.copyWith(refusal: Refusal(failure: failure, lastWorked: lastWorked)));
    if (container.throwaway) return;
    if (state.viewedSiteId != siteId) _drop(siteId);
    await _engine.close(siteId);
  }

  void _drop(String siteId) {
    state = state.copyWith(
      containers: [for (final c in state.containers) if (c.siteId != siteId) c],
      viewedSiteId: state.viewedSiteId == siteId ? null : _keep,
    );
    _dropNavigationOf(siteId);
  }

  void _dropNavigationOf(String siteId) {
    if (!state.navigation.values.any((n) => n.siteId == siteId)) return;
    state = state.copyWith(navigation: {
      for (final entry in state.navigation.entries)
        if (entry.value.siteId != siteId) entry.key: entry.value,
    });
  }

  void _update(String siteId, OpenContainer Function(OpenContainer) change) {
    if (state.byId(siteId) == null) return;
    state = state.copyWith(containers: [
      for (final c in state.containers) c.siteId == siteId ? change(c) : c,
    ]);
  }
}
