import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../domain/models/site.dart';
import '../../domain/models/vault.dart';
import '../../domain/models/workspace.dart';

/// 128 bits of entropy, hex-encoded. Used to name WebView profiles.
String newProfileId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Which of the two stores is open.
///
/// The vaults are peers. Neither is named for its role on disk, because a file
/// called `decoy.db` leaks precisely what the decoy exists to hide — and under
/// the coerced-unlock threat model the attacker is looking at the device.
String vaultFileName(VaultId vault) => switch (vault) {
      VaultId.a => 'store-1.db',
      VaultId.b => 'store-2.db',
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

  static const schemaVersion = 2;

  static Future<AppDatabase> open({
    required String path,
    String? password,
    DatabaseFactory? factory,
  }) async {
    final openDb = factory?.openDatabase ?? databaseFactory.openDatabase;
    final db = await openDb(
      path,
      options: SqlCipherOpenDatabaseOptions(
        password: password,
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
              sort_index      INTEGER NOT NULL DEFAULT 0,
              profile_id          TEXT    NOT NULL,
              block_webrtc        INTEGER NOT NULL DEFAULT 1,
              block_trackers      INTEGER NOT NULL DEFAULT 1,
              anti_fingerprinting INTEGER NOT NULL DEFAULT 1,
              allow_camera        INTEGER NOT NULL DEFAULT 0,
              allow_microphone    INTEGER NOT NULL DEFAULT 0,
              allow_location      INTEGER NOT NULL DEFAULT 0,
              allow_clipboard     INTEGER NOT NULL DEFAULT 0,
              user_agent_mode     TEXT    NOT NULL DEFAULT 'android',
              force_dark          INTEGER NOT NULL DEFAULT 1,
              open_in_reader      INTEGER NOT NULL DEFAULT 0,
              page_zoom           INTEGER NOT NULL DEFAULT 100,
              custom_css          TEXT    NOT NULL DEFAULT '',
              custom_js           TEXT    NOT NULL DEFAULT ''
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_sites_workspace ON sites(workspace_id)');
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) {
            const columns = <String, String>{
              'profile_id': "TEXT NOT NULL DEFAULT ''",
              'block_webrtc': 'INTEGER NOT NULL DEFAULT 1',
              'block_trackers': 'INTEGER NOT NULL DEFAULT 1',
              'anti_fingerprinting': 'INTEGER NOT NULL DEFAULT 1',
              'allow_camera': 'INTEGER NOT NULL DEFAULT 0',
              'allow_microphone': 'INTEGER NOT NULL DEFAULT 0',
              'allow_location': 'INTEGER NOT NULL DEFAULT 0',
              'allow_clipboard': 'INTEGER NOT NULL DEFAULT 0',
              'user_agent_mode': "TEXT NOT NULL DEFAULT 'android'",
              'force_dark': 'INTEGER NOT NULL DEFAULT 1',
              'open_in_reader': 'INTEGER NOT NULL DEFAULT 0',
              'page_zoom': 'INTEGER NOT NULL DEFAULT 100',
              'custom_css': "TEXT NOT NULL DEFAULT ''",
              'custom_js': "TEXT NOT NULL DEFAULT ''",
            };
            for (final entry in columns.entries) {
              await db.execute(
                  'ALTER TABLE sites ADD COLUMN ${entry.key} ${entry.value}');
            }
            // A row that predates profiles still needs an opaque one.
            for (final row in await db.query('sites', columns: ['id'])) {
              await db.update('sites', {'profile_id': newProfileId()},
                  where: 'id = ?', whereArgs: [row['id']]);
            }
          }
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
        profileId: newProfileId(),
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        lastVisitedAt: ago(const Duration(seconds: 20)), sortIndex: 0),
    Site(
        id: 'st-webmail', workspaceId: 'ws-personal', name: 'Webmail',
        monogram: 'Wm', url: 'https://mail.example.net',
        profileId: newProfileId(),
        lastVisitedAt: ago(const Duration(minutes: 14)), sortIndex: 1),
    Site(
        id: 'st-forum', workspaceId: 'ws-personal', name: 'Forum',
        monogram: 'Fr', url: 'https://forum.example.com',
        profileId: newProfileId(),
        cookiePolicy: CookiePolicy.wipeOnExit,
        lastVisitedAt: ago(const Duration(hours: 2)), sortIndex: 2),
    Site(
        id: 'st-reader', workspaceId: 'ws-personal', name: 'Reader',
        monogram: 'Rd', url: 'https://read.example.io',
        profileId: newProfileId(),
        lastVisitedAt: ago(const Duration(days: 1)), sortIndex: 3),
    Site(
        id: 'st-bank', workspaceId: 'ws-personal', name: 'Bank',
        monogram: 'Bk', url: 'https://bank.example.com', requirePin: true,
        profileId: newProfileId(),
        lastVisitedAt: ago(const Duration(days: 3)), sortIndex: 4),
    Site(
        id: 'st-market', workspaceId: 'ws-personal', name: 'Marketplace',
        monogram: 'Mk', url: 'https://shop.example.com',
        profileId: newProfileId(),
        lastVisitedAt: ago(const Duration(days: 5)), sortIndex: 5),
    Site(
        id: 'st-wiki', workspaceId: 'ws-work', name: 'Wiki',
        monogram: 'Wk', url: 'https://wiki.internal',
        profileId: newProfileId(),
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        lastVisitedAt: ago(const Duration(minutes: 3)), sortIndex: 0),
    Site(
        id: 'st-tickets', workspaceId: 'ws-work', name: 'Tickets',
        monogram: 'Tk', url: 'https://tickets.internal',
        profileId: newProfileId(),
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

UserAgentMode _uaFromName(String name) => switch (name) {
      'desktop' => UserAgentMode.desktop,
      'minimal' => UserAgentMode.minimal,
      _ => UserAgentMode.android,
    };

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
      'profile_id': s.profileId,
      'block_webrtc': s.blockWebRtc ? 1 : 0,
      'block_trackers': s.blockTrackers ? 1 : 0,
      'anti_fingerprinting': s.antiFingerprinting ? 1 : 0,
      'allow_camera': s.allowCamera ? 1 : 0,
      'allow_microphone': s.allowMicrophone ? 1 : 0,
      'allow_location': s.allowLocation ? 1 : 0,
      'allow_clipboard': s.allowClipboard ? 1 : 0,
      'user_agent_mode': s.userAgentMode.name,
      'force_dark': s.forceDark ? 1 : 0,
      'open_in_reader': s.openInReader ? 1 : 0,
      'page_zoom': s.pageZoom,
      'custom_css': s.customCss,
      'custom_js': s.customJs,
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
    profileId: r['profile_id']! as String,
    blockWebRtc: (r['block_webrtc']! as int) == 1,
    blockTrackers: (r['block_trackers']! as int) == 1,
    antiFingerprinting: (r['anti_fingerprinting']! as int) == 1,
    allowCamera: (r['allow_camera']! as int) == 1,
    allowMicrophone: (r['allow_microphone']! as int) == 1,
    allowLocation: (r['allow_location']! as int) == 1,
    allowClipboard: (r['allow_clipboard']! as int) == 1,
    userAgentMode: _uaFromName(r['user_agent_mode']! as String),
    forceDark: (r['force_dark']! as int) == 1,
    openInReader: (r['open_in_reader']! as int) == 1,
    pageZoom: r['page_zoom']! as int,
    customCss: r['custom_css']! as String,
    customJs: r['custom_js']! as String,
  );
}
