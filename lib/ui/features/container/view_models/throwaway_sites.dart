import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/site.dart';
import '../../shell/view_models/session_controller.dart' show SessionOpen, sessionProvider;

/// The throwaway containers open in this vault (browser-chrome spec §5.1):
/// in memory only, never written to the vault until the user saves one.
///
/// [build] watches which database is open, so the list is rebuilt empty on
/// every transition out of `SessionOpen` — a `9b` or `9c` lock, panic — and
/// again on the next unlock. A throwaway from one vault can never be seen
/// from the other. A new `SessionOpen` on the same database (re-wrapping the
/// biometric key) keeps it.
class ThrowawaySites extends Notifier<List<Site>> {
  @override
  List<Site> build() {
    ref.watch(sessionProvider
        .select((session) => session is SessionOpen ? session.database : null));
    return const [];
  }

  void add(Site site) => state = [...state, site];

  void remove(String siteId) => state = [
        for (final site in state)
          if (site.id != siteId) site,
      ];
}

final throwawaySitesProvider =
    NotifierProvider<ThrowawaySites, List<Site>>(ThrowawaySites.new);
