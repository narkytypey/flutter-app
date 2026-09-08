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
}

abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool fallback = false});
  Future<void> setBool(String key, bool value);
}
