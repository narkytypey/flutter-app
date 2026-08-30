import 'package:sqflite/sqflite.dart';

import '../../domain/models/site.dart';
import '../../domain/models/workspace.dart';

/// Which of the two stores is open.
///
/// The vaults are peers. Neither is named for its role on disk, because a file
/// called `decoy.db` leaks precisely what the decoy exists to hide — and under
/// the coerced-unlock threat model the attacker is looking at the device.
enum Vault { a, b }

String vaultFileName(Vault vault) => switch (vault) {
      Vault.a => 'store-1.db',
      Vault.b => 'store-2.db',
    };

/// One vault's store. Nothing here leaves the device.
///
/// [open] takes a path and an optional factory so tests can run in-memory on
/// the host, and so Plan 2 can open each vault through a factory keyed from
/// the data key that vault's PIN unwrapped. Two vaults means two live
/// [AppDatabase] instances with two different keys — never one store with a
/// visibility flag over it.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const schemaVersion = 1;

  static Future<AppDatabase> open({
    required String path,
    DatabaseFactory? factory,
  }) async {
    final open = factory?.openDatabase ?? databaseFactory.openDatabase;
    final db = await open(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE workspaces (
              id            TEXT PRIMARY KEY,
              name          TEXT    NOT NULL,
              marker_index  INTEGER NOT NULL,
              storage_rule  TEXT    NOT NULL,
              require_pin   INTEGER NOT NULL DEFAULT 0,
              show_in_decoy INTEGER NOT NULL DEFAULT 0,
              sort_index    INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE sites (
              id              TEXT PRIMARY KEY,
              workspace_id    TEXT    NOT NULL
                                REFERENCES workspaces(id) ON DELETE CASCADE,
              name            TEXT    NOT NULL,
              monogram        TEXT    NOT NULL,
              url             TEXT    NOT NULL,
              cookie_policy   TEXT    NOT NULL,
              proxy_mode      TEXT    NOT NULL,
              proxy_host      TEXT,
              proxy_port      INTEGER,
              require_pin     INTEGER NOT NULL DEFAULT 0,
              -- Provisioning only: "copy this row into the other vault when
              -- the decoy is set up". It is never read as a runtime filter,
              -- and rows in the decoy's own store do not use it.
              show_in_decoy   INTEGER NOT NULL DEFAULT 0,
              last_visited_at INTEGER,
              sort_index      INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_sites_workspace ON sites(workspace_id)');
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}

/// Inserts the workspaces and sites the design shows, so the dashboard has
/// something real to render on a fresh install. Does nothing if any workspace
/// already exists.
Future<void> seedIfEmpty(AppDatabase database) async {
  final existing = Sqflite.firstIntValue(
      await database.db.rawQuery('SELECT COUNT(*) FROM workspaces'));
  if (existing != null && existing > 0) return;

  final now = DateTime.now();
  DateTime ago(Duration d) => now.subtract(d);

  const workspaces = [
    Workspace(
        id: 'ws-personal', name: 'Personal', markerIndex: 0,
        storageRule: StorageRule.keep, sortIndex: 0),
    Workspace(
        id: 'ws-work', name: 'Work', markerIndex: 1,
        storageRule: StorageRule.keep, sortIndex: 1),
    Workspace(
        id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4,
        storageRule: StorageRule.wipeOnExit, sortIndex: 2),
  ];

  // Monograms are the design's hand-picked values, not suggestMonogram output.
  final sites = <Site>[
    Site(
        id: 'st-notes', workspaceId: 'ws-personal', name: 'Notes',
        monogram: 'Nt', url: 'https://notes.example.org',
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        lastVisitedAt: ago(const Duration(seconds: 20)), sortIndex: 0),
    Site(
        id: 'st-webmail', workspaceId: 'ws-personal', name: 'Webmail',
        monogram: 'Wm', url: 'https://mail.example.net',
        lastVisitedAt: ago(const Duration(minutes: 14)), sortIndex: 1),
    Site(
        id: 'st-forum', workspaceId: 'ws-personal', name: 'Forum',
        monogram: 'Fr', url: 'https://forum.example.com',
        cookiePolicy: CookiePolicy.wipeOnExit,
        lastVisitedAt: ago(const Duration(hours: 2)), sortIndex: 2),
    Site(
        id: 'st-reader', workspaceId: 'ws-personal', name: 'Reader',
        monogram: 'Rd', url: 'https://read.example.io',
        lastVisitedAt: ago(const Duration(days: 1)), sortIndex: 3),
    Site(
        id: 'st-bank', workspaceId: 'ws-personal', name: 'Bank',
        monogram: 'Bk', url: 'https://bank.example.com', requirePin: true,
        lastVisitedAt: ago(const Duration(days: 3)), sortIndex: 4),
    Site(
        id: 'st-market', workspaceId: 'ws-personal', name: 'Marketplace',
        monogram: 'Mk', url: 'https://shop.example.com',
        lastVisitedAt: ago(const Duration(days: 5)), sortIndex: 5),
    Site(
        id: 'st-wiki', workspaceId: 'ws-work', name: 'Wiki',
        monogram: 'Wk', url: 'https://wiki.internal',
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        lastVisitedAt: ago(const Duration(minutes: 3)), sortIndex: 0),
    Site(
        id: 'st-tickets', workspaceId: 'ws-work', name: 'Tickets',
        monogram: 'Tk', url: 'https://tickets.internal',
        lastVisitedAt: ago(const Duration(hours: 1)), sortIndex: 1),
  ];

  await database.db.transaction((txn) async {
    for (final w in workspaces) {
      await txn.insert('workspaces', workspaceToRow(w));
    }
    for (final s in sites) {
      await txn.insert('sites', siteToRow(s));
    }
  });
}

// ---------------------------------------------------------------- mapping --

Map<String, Object?> workspaceToRow(Workspace w) => {
      'id': w.id,
      'name': w.name,
      'marker_index': w.markerIndex,
      'storage_rule': w.storageRule.name,
      'require_pin': w.requirePin ? 1 : 0,
      'show_in_decoy': w.showInDecoy ? 1 : 0,
      'sort_index': w.sortIndex,
    };

Workspace workspaceFromRow(Map<String, Object?> r) => Workspace(
      id: r['id']! as String,
      name: r['name']! as String,
      markerIndex: r['marker_index']! as int,
      storageRule: StorageRule.values.byName(r['storage_rule']! as String),
      requirePin: (r['require_pin']! as int) == 1,
      showInDecoy: (r['show_in_decoy']! as int) == 1,
      sortIndex: r['sort_index']! as int,
    );

Map<String, Object?> siteToRow(Site s) => {
      'id': s.id,
      'workspace_id': s.workspaceId,
      'name': s.name,
      'monogram': s.monogram,
      'url': s.url,
      'cookie_policy': s.cookiePolicy.name,
      'proxy_mode': s.proxyMode.name,
      'proxy_host': s.proxyHost,
      'proxy_port': s.proxyPort,
      'require_pin': s.requirePin ? 1 : 0,
      'show_in_decoy': s.showInDecoy ? 1 : 0,
      'last_visited_at': s.lastVisitedAt?.millisecondsSinceEpoch,
      'sort_index': s.sortIndex,
    };

Site siteFromRow(Map<String, Object?> r) {
  final visited = r['last_visited_at'] as int?;
  return Site(
    id: r['id']! as String,
    workspaceId: r['workspace_id']! as String,
    name: r['name']! as String,
    monogram: r['monogram']! as String,
    url: r['url']! as String,
    cookiePolicy: CookiePolicy.values.byName(r['cookie_policy']! as String),
    proxyMode: ProxyMode.values.byName(r['proxy_mode']! as String),
    proxyHost: r['proxy_host'] as String?,
    proxyPort: r['proxy_port'] as int?,
    requirePin: (r['require_pin']! as int) == 1,
    showInDecoy: (r['show_in_decoy']! as int) == 1,
    lastVisitedAt:
        visited == null ? null : DateTime.fromMillisecondsSinceEpoch(visited, isUtc: true),
    sortIndex: r['sort_index']! as int,
  );
}
