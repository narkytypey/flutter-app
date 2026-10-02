import '../models/site.dart';
import '../models/workspace.dart';

abstract interface class WorkspaceRepository {
  Future<List<Workspace>> all();
  Future<Workspace?> byId(String id);
  Future<void> upsert(Workspace workspace);
  Future<void> delete(String id);
}

abstract interface class SiteRepository {
  Future<List<Site>> inWorkspace(String workspaceId);
  Future<List<Site>> all();
  Future<Site?> byId(String id);
  Future<void> upsert(Site site);
  Future<void> delete(String id);

  /// Records that a site was just opened, which drives its dashboard age.
  Future<void> touch(String id, DateTime at);

  /// When [id] last went live on its own route, for `8b`'s "Last worked";
  /// null if never, or since its data was last wiped.
  Future<DateTime?> lastWorked(String id);

  /// Records [at] as [id]'s last-worked time; null clears it.
  Future<void> setLastWorked(String id, DateTime? at);
}

abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool fallback = false});
  Future<void> setBool(String key, bool value);

  /// `app_settings.value` is text already; this reads it as stored.
  Future<String?> getString(String key, {String? fallback});
  Future<void> setString(String key, String value);
}
