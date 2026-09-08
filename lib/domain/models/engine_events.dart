import 'held_download.dart';
import 'permissions.dart';

/// A hardware ask the native side is holding open, waiting for the user's
/// decision from `PermissionRequestSheet` (`6a`). [requestId] round-trips
/// through [ContainerEngine.resolvePermission] so the platform can resolve
/// the exact pending Android callback, not just "the most recent one".
class PendingPermissionRequest {
  const PendingPermissionRequest({
    required this.siteId,
    required this.host,
    required this.kind,
    required this.requestId,
  });

  final String siteId;
  final String host;
  final PermissionKind kind;
  final String requestId;
}

class HeldDownloadEvent {
  const HeldDownloadEvent({required this.siteId, required this.download});

  final String siteId;
  final HeldDownload download;
}

class TunnelDroppedEvent {
  const TunnelDroppedEvent({
    required this.siteId,
    required this.host,
    required this.droppedAt,
  });

  final String siteId;
  final String host;
  final DateTime droppedAt;
}
