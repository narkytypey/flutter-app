import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/services/blocked_tally_recorder.dart';
import '../../container/view_models/providers.dart' show containerEngineProvider;
import 'providers.dart' show siteRepositoryProvider;

/// Looks a site up in whichever vault is open. Watches the repository, so a
/// change of vault rebuilds [BlockedTallyController] and starts its count
/// again. Overridden in tests to fake lookup without a real database.
final siteLookupProvider = Provider<Future<Site?> Function(String)>((ref) {
  final sites = ref.watch(siteRepositoryProvider);
  return sites.byId;
});

/// Spec `5c`'s Today log, fed from the engine's live sessions. Each session
/// carries running per-category counts; this keeps the last counts it saw per
/// site and records only the increase, so the tally is never double-counted.
///
/// A session is counted only when its site exists in the open vault. The
/// engine is process-wide, so a session belonging to the other vault can
/// still be running — counting it would be an aggregate across both vaults.
class BlockedTallyController extends Notifier<BlockedTally> {
  late BlockedTallyRecorder _recorder;
  final _lastCounts = <String, Map<BlockedCategory, int>>{};

  /// Emissions are handled one at a time. The site lookup is async, and two
  /// emissions handled together would both read the same last counts.
  Future<void> _queue = Future.value();

  /// Bumped on every rebuild — that is, on every change of vault. Work queued
  /// under an earlier one belongs to the vault that was open then, and is
  /// dropped rather than recorded into this one's tally.
  int _generation = 0;

  @override
  BlockedTally build() {
    _recorder = BlockedTallyRecorder();
    _lastCounts.clear();
    final generation = ++_generation;
    final lookup = ref.watch(siteLookupProvider);
    ref.listen(_sessionsStreamProvider, (_, next) {
      next.whenData((sessions) {
        _queue = _queue.then((_) => _onSessions(sessions, lookup, generation));
      });
    });
    return _recorder.snapshot();
  }

  Future<void> _onSessions(
    List<ContainerSession> sessions,
    Future<Site?> Function(String) lookup,
    int generation,
  ) async {
    for (final session in sessions) {
      if (generation != _generation) return;
      final previous = _lastCounts[session.siteId] ?? const {};
      final deltas = <BlockedCategory, int>{};
      for (final category in BlockedCategory.values) {
        final delta = (session.categoryCounts[category] ?? 0) - (previous[category] ?? 0);
        if (delta > 0) deltas[category] = delta;
      }
      _lastCounts[session.siteId] = session.categoryCounts;
      if (deltas.isEmpty) continue;

      final site = await lookup(session.siteId);
      if (generation != _generation) return;
      if (site == null) continue;
      deltas.forEach(_recorder.recordCategory);
      _recorder.recordSite(
        siteId: site.id,
        monogram: site.monogram,
        name: site.name,
        count: deltas.values.fold(0, (a, b) => a + b),
      );
    }
    state = _recorder.snapshot();
  }
}

final _sessionsStreamProvider = StreamProvider<List<ContainerSession>>(
  (ref) => ref.watch(containerEngineProvider).sessions(),
);

final blockedTallyProvider =
    NotifierProvider<BlockedTallyController, BlockedTally>(BlockedTallyController.new);
