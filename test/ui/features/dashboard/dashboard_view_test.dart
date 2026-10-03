import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 3, 12);

Site _site(String id, {Duration? ago}) => Site(
      id: id, workspaceId: 'w', name: id, monogram: 'Xx', url: 'https://$id.example',
      profileId: 'p-$id', lastVisitedAt: ago == null ? null : _now.subtract(ago),
    );

const _personal =
    Workspace(id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

void main() {
  test('open sites first, then the rest; each most recent first, never-visited last (§4.3)', () {
    final view = DashboardView.from(
      workspace: _personal,
      sites: [
        _site('idle-old', ago: const Duration(days: 3)),
        _site('never'),
        _site('open-old', ago: const Duration(hours: 2)),
        _site('idle-new', ago: const Duration(minutes: 5)),
        _site('open-new', ago: const Duration(minutes: 1)),
        _site('open-never'),
      ],
      openSiteIds: const {'open-old', 'open-new', 'open-never'},
      now: _now,
    );

    expect(view.rows.map((r) => r.siteId),
        ['open-new', 'open-old', 'open-never', 'idle-new', 'idle-old', 'never']);
    expect(view.rows.map((r) => r.live), [true, true, true, false, false, false]);
  });

  test('ties keep the order the vault gave', () {
    final view = DashboardView.from(
      workspace: _personal,
      sites: [_site('c'), _site('a'), _site('b')],
      openSiteIds: const {},
      now: _now,
    );
    expect(view.rows.map((r) => r.siteId), ['c', 'a', 'b']);
  });

  test('it names the viewed workspace and its storage rule', () {
    final keep = DashboardView.from(
        workspace: _personal, sites: const [], openSiteIds: const {}, now: _now);
    expect(keep.workspaceId, 'w');
    expect(keep.wipesOnExit, isFalse);
    expect(keep.isEmpty, isTrue);

    final wipe = DashboardView.from(
      workspace: const Workspace(
          id: 'e', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
      sites: const [],
      openSiteIds: const {},
      now: _now,
    );
    expect(wipe.wipesOnExit, isTrue);
  });

  test('a vault with no workspaces has none viewed', () {
    expect(DashboardView.empty.workspaceId, isNull);
    expect(DashboardView.empty.isEmpty, isTrue);
  });
}
