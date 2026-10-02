import 'held_download.dart';
import 'permissions.dart';
import 'route_decision.dart' show RouteFailure;

/// A hardware ask the native side is holding open, waiting for the user's
/// decision from `PermissionRequestSheet` (`6a`). [requestId] round-trips
/// through [ContainerEngine.resolvePermission] so the platform can resolve
/// the exact pending Android callback, not just "the most recent one".
class PendingPermissionRequest {
  const PendingPermissionRequest({
    required this.siteId,
    required this.pageId,
    required this.host,
    required this.kind,
    required this.requestId,
  });

  final String siteId;

  /// The page it is about (tabs spec §3.1).
  final String pageId;
  final String host;
  final PermissionKind kind;
  final String requestId;
}

class HeldDownloadEvent {
  const HeldDownloadEvent({
    required this.siteId,
    required this.pageId,
    required this.requestId,
    required this.download,
  });

  final String siteId;

  /// The page it is about (tabs spec §3.1).
  final String pageId;
  final String requestId;
  final HeldDownload download;
}

/// A link that asked for a new window opened [pageId] in [siteId]'s container
/// (tabs spec §5.2). The registry brings it to the front.
class PageOpened {
  const PageOpened({required this.siteId, required this.pageId, this.openerPageId});
  final String siteId;
  final String pageId;
  final String? openerPageId;
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

enum DownloadOutcome { saved, kept, failed }

class DownloadResult {
  const DownloadResult({required this.requestId, required this.outcome, this.reason});
  final String requestId;
  final DownloadOutcome outcome;
  final RouteFailure? reason;
}
