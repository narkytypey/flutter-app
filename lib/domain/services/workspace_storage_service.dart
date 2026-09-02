/// How many bytes a workspace's sites have stored on disk. Real answers need
/// a platform call into Plan 3's per-site `ProfileManager` directories, which
/// this plan does not build — see this plan's Known gaps.
abstract interface class WorkspaceStorageService {
  Future<int> bytesFor(String workspaceId);
}

/// Test and pre-native-wiring stand-in. Returns 0 for any workspace not given
/// an explicit value, never throws.
class FakeWorkspaceStorageService implements WorkspaceStorageService {
  FakeWorkspaceStorageService([this._bytes = const {}]);

  final Map<String, int> _bytes;

  @override
  Future<int> bytesFor(String workspaceId) async => _bytes[workspaceId] ?? 0;
}
